//! Pure Rust reference tool for comparing NIF results against tholos-pq.

use std::env;
use std::process;

use base64::{engine::general_purpose::STANDARD as B64, Engine as _};
use ml_kem::{EncodedSizeUser, KemCore, MlKem1024};
use pqcrypto_traits::sign::{PublicKey as SigPublicKey, SecretKey as SigSecretKey};
use serde::{Deserialize, Serialize};
use tholos_pq::{decrypt, encrypt, gen_recipient_keypair, gen_sender_keypair, sender_pub};

type DecapsulationKey = <MlKem1024 as KemCore>::DecapsulationKey;

#[derive(Serialize)]
struct RoundtripResult {
    kid: String,
    sid: String,
    message_b64: String,
    plaintext_b64: String,
    wire_b64: String,
    recipient_pub_b64: String,
    recipient_sk_b64: String,
    sender_pub_b64: String,
    sender_pk_b64: String,
    sender_sk_b64: String,
}

#[derive(Serialize)]
struct DecryptResult {
    plaintext_b64: String,
}

#[derive(Deserialize)]
struct DecryptRequest {
    wire_b64: String,
    kid: String,
    recipient_sk_b64: String,
    sender_pub_b64: String,
}

fn b64_encode(bytes: &[u8]) -> String {
    B64.encode(bytes)
}

fn b64_decode(s: &str) -> Result<Vec<u8>, String> {
    B64.decode(s)
        .map_err(|e| format!("base64 decode failed: {e}"))
}

fn roundtrip(message: &[u8]) -> Result<RoundtripResult, String> {
    let kid = "ref_recipient";
    let sid = "ref_sender";

    let (recipient_pub, recipient_priv) = gen_recipient_keypair(kid);
    let sender = gen_sender_keypair(sid);
    let sender_pub = sender_pub(&sender);

    let wire = encrypt(message, &sender, std::slice::from_ref(&recipient_pub))
        .map_err(|e| format!("encrypt failed: {e:?}"))?;

    let allowed = vec![(sender.sid.clone(), sender_pub.pk_dilithium.clone())];
    let plaintext = decrypt(&wire, kid, &recipient_priv.sk_kyber, &allowed)
        .map_err(|e| format!("decrypt failed: {e:?}"))?;

    if plaintext != message {
        return Err("pure Rust roundtrip plaintext mismatch".into());
    }

    let recipient_pub_cbor =
        serde_cbor::to_vec(&recipient_pub).map_err(|e| format!("cbor encode failed: {e}"))?;
    let sender_pub_cbor =
        serde_cbor::to_vec(&sender_pub).map_err(|e| format!("cbor encode failed: {e}"))?;

    Ok(RoundtripResult {
        kid: kid.to_string(),
        sid: sid.to_string(),
        message_b64: b64_encode(message),
        plaintext_b64: b64_encode(&plaintext),
        wire_b64: b64_encode(&wire),
        recipient_pub_b64: b64_encode(&recipient_pub_cbor),
        recipient_sk_b64: b64_encode(recipient_priv.sk_kyber.as_bytes().as_slice()),
        sender_pub_b64: b64_encode(&sender_pub_cbor),
        sender_pk_b64: b64_encode(sender.pk_dilithium.as_bytes()),
        sender_sk_b64: b64_encode(sender.sk_dilithium.as_bytes()),
    })
}

fn decrypt_request(req: DecryptRequest) -> Result<DecryptResult, String> {
    let wire = b64_decode(&req.wire_b64)?;
    let sk_bytes = b64_decode(&req.recipient_sk_b64)?;
    let sender_pub_cbor = b64_decode(&req.sender_pub_b64)?;

    let encoded = sk_bytes
        .as_slice()
        .try_into()
        .map_err(|_| "invalid recipient secret key length".to_string())?;
    let sk_kyber = DecapsulationKey::from_bytes(&encoded);

    let sender_pub: tholos_pq::SenderPub = serde_cbor::from_slice(&sender_pub_cbor)
        .map_err(|e| format!("failed to decode sender pub: {e}"))?;
    let allowed = vec![(sender_pub.sid.clone(), sender_pub.pk_dilithium.clone())];

    let plaintext = decrypt(&wire, &req.kid, &sk_kyber, &allowed)
        .map_err(|e| format!("decrypt failed: {e:?}"))?;

    Ok(DecryptResult {
        plaintext_b64: b64_encode(&plaintext),
    })
}

fn print_json<T: Serialize>(value: &T) {
    println!("{}", serde_json::to_string(value).expect("json encode"));
}

fn usage() -> ! {
    eprintln!(
        "Usage:
  tholos_pq_ref roundtrip <message>
  tholos_pq_ref decrypt-json <json>

roundtrip prints JSON with wire + key material from pure tholos-pq.
decrypt-json decrypts a NIF (or Rust) ciphertext using exported key material."
    );
    process::exit(2);
}

fn main() {
    let mut args = env::args().skip(1);
    let cmd = args.next().unwrap_or_else(|| usage());

    let result = match cmd.as_str() {
        "roundtrip" => {
            let message = args.next().unwrap_or_else(|| usage());
            roundtrip(message.as_bytes()).map(|r| {
                print_json(&r);
            })
        }
        "decrypt-json" => {
            let json = args.next().unwrap_or_else(|| usage());
            let req: DecryptRequest = serde_json::from_str(&json).unwrap_or_else(|e| {
                eprintln!("invalid json: {e}");
                process::exit(1);
            });
            decrypt_request(req).map(|r| {
                print_json(&r);
            })
        }
        _ => usage(),
    };

    if let Err(err) = result {
        eprintln!("error: {err}");
        process::exit(1);
    }
}
