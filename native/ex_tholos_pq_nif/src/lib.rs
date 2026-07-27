use rustler::types::binary::{Binary, OwnedBinary};
use rustler::{Env, Error, NifResult};
use std::collections::HashMap;
use std::sync::Mutex;

use ml_kem::{EncodedSizeUser, KemCore, MlKem1024};
use pqcrypto_dilithium::dilithium3 as dilithium;
use pqcrypto_traits::sign::{PublicKey as SigPublicKey, SecretKey as SigSecretKey};

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

type DecapsulationKey = <MlKem1024 as KemCore>::DecapsulationKey;

lazy_static::lazy_static! {
    static ref RECIPIENT_KEYS: Mutex<HashMap<String, (tholos_pq::RecipientPub, tholos_pq::RecipientPriv)>> =
        Mutex::new(HashMap::new());
    static ref SENDER_KEYS: Mutex<HashMap<String, tholos_pq::SenderKeypair>> =
        Mutex::new(HashMap::new());
}

rustler::init!("Elixir.ExTholosPq");

fn owned_bin<'a>(env: Env<'a>, bytes: &[u8]) -> NifResult<Binary<'a>> {
    let mut bin = OwnedBinary::new(bytes.len()).ok_or(Error::Atom("allocation_failed"))?;
    bin.as_mut_slice().copy_from_slice(bytes);
    Ok(bin.release(env))
}

fn decapsulation_key_from_bytes(sk_bytes: &[u8]) -> NifResult<DecapsulationKey> {
    let encoded = sk_bytes
        .try_into()
        .map_err(|_| Error::Term(Box::new("invalid recipient secret key length")))?;
    Ok(DecapsulationKey::from_bytes(&encoded))
}

#[rustler::nif(name = "nif_gen_recipient_keypair")]
fn gen_recipient_keypair<'a>(
    env: Env<'a>,
    kid: String,
) -> NifResult<(rustler::Atom, (String, Binary<'a>))> {
    let (pub_key, priv_key) = tholos_pq::gen_recipient_keypair(&kid);

    let pub_bytes = serde_cbor::to_vec(&pub_key)
        .map_err(|e| Error::Term(Box::new(format!("Serialization failed: {:?}", e))))?;

    RECIPIENT_KEYS
        .lock()
        .unwrap()
        .insert(kid.clone(), (pub_key, priv_key));

    Ok((atoms::ok(), (kid, owned_bin(env, &pub_bytes)?)))
}

#[rustler::nif(name = "nif_gen_sender_keypair")]
fn gen_sender_keypair<'a>(
    env: Env<'a>,
    sid: String,
) -> NifResult<(rustler::Atom, (String, Binary<'a>))> {
    let sender = tholos_pq::gen_sender_keypair(&sid);
    let sender_pub = tholos_pq::sender_pub(&sender);

    let pub_bytes = serde_cbor::to_vec(&sender_pub)
        .map_err(|e| Error::Term(Box::new(format!("Serialization failed: {:?}", e))))?;

    SENDER_KEYS.lock().unwrap().insert(sid.clone(), sender);

    Ok((atoms::ok(), (sid, owned_bin(env, &pub_bytes)?)))
}

#[rustler::nif(name = "nif_export_recipient_secret")]
fn export_recipient_secret<'a>(
    env: Env<'a>,
    kid: String,
) -> NifResult<(rustler::Atom, Binary<'a>)> {
    let recipient_keys = RECIPIENT_KEYS.lock().unwrap();
    let (_, priv_key) = recipient_keys
        .get(&kid)
        .ok_or_else(|| Error::Term(Box::new(format!("Recipient {} not found", kid))))?;

    let sk_bytes = priv_key.sk_kyber.as_bytes().to_vec();
    Ok((atoms::ok(), owned_bin(env, &sk_bytes)?))
}

#[rustler::nif(name = "nif_import_recipient_keypair")]
fn import_recipient_keypair<'a>(
    env: Env<'a>,
    kid: String,
    pub_cbor: Binary,
    sk_bytes: Binary,
) -> NifResult<(rustler::Atom, (String, Binary<'a>))> {
    let pub_key: tholos_pq::RecipientPub =
        serde_cbor::from_slice(pub_cbor.as_slice()).map_err(|e| {
            Error::Term(Box::new(format!(
                "Failed to deserialize recipient pub: {:?}",
                e
            )))
        })?;

    if pub_key.kid != kid {
        return Err(Error::Term(Box::new(format!(
            "kid mismatch: argument {}, key {}",
            kid, pub_key.kid
        ))));
    }

    let sk_kyber = decapsulation_key_from_bytes(sk_bytes.as_slice())?;
    let priv_key = tholos_pq::RecipientPriv {
        kid: kid.clone(),
        sk_kyber,
    };

    RECIPIENT_KEYS
        .lock()
        .unwrap()
        .insert(kid.clone(), (pub_key, priv_key));

    Ok((atoms::ok(), (kid, owned_bin(env, pub_cbor.as_slice())?)))
}

#[rustler::nif(name = "nif_import_sender_keypair")]
fn import_sender_keypair<'a>(
    env: Env<'a>,
    sid: String,
    pk_bytes: Binary,
    sk_bytes: Binary,
) -> NifResult<(rustler::Atom, (String, Binary<'a>))> {
    let pk_dilithium = dilithium::PublicKey::from_bytes(pk_bytes.as_slice())
        .map_err(|e| Error::Term(Box::new(format!("Invalid sender public key: {:?}", e))))?;
    let sk_dilithium = dilithium::SecretKey::from_bytes(sk_bytes.as_slice())
        .map_err(|e| Error::Term(Box::new(format!("Invalid sender secret key: {:?}", e))))?;

    let sender = tholos_pq::SenderKeypair {
        sid: sid.clone(),
        pk_dilithium,
        sk_dilithium,
    };
    let sender_pub = tholos_pq::sender_pub(&sender);
    let pub_cbor = serde_cbor::to_vec(&sender_pub)
        .map_err(|e| Error::Term(Box::new(format!("Serialization failed: {:?}", e))))?;

    SENDER_KEYS.lock().unwrap().insert(sid.clone(), sender);

    Ok((atoms::ok(), (sid, owned_bin(env, &pub_cbor)?)))
}

#[rustler::nif(name = "nif_encrypt")]
fn encrypt<'a>(
    env: Env<'a>,
    message: Binary,
    sender_id: String,
    recipient_pub_keys: Vec<Binary>,
) -> NifResult<(rustler::Atom, Binary<'a>)> {
    let sender_keys = SENDER_KEYS.lock().unwrap();
    let sender = sender_keys
        .get(&sender_id)
        .ok_or_else(|| Error::Term(Box::new(format!("Sender {} not found", sender_id))))?;

    let recipients: Result<Vec<tholos_pq::RecipientPub>, _> = recipient_pub_keys
        .iter()
        .map(|b| serde_cbor::from_slice(b.as_slice()))
        .collect();
    let recipients = recipients.map_err(|e| {
        Error::Term(Box::new(format!(
            "Failed to deserialize recipients: {:?}",
            e
        )))
    })?;

    let wire = tholos_pq::encrypt(message.as_slice(), sender, &recipients)
        .map_err(|e| Error::Term(Box::new(format!("Encryption failed: {:?}", e))))?;

    Ok((atoms::ok(), owned_bin(env, &wire)?))
}

#[rustler::nif(name = "nif_decrypt")]
fn decrypt<'a>(
    env: Env<'a>,
    wire: Binary,
    kid: String,
    allowed_sender_pub_keys: Vec<Binary>,
) -> NifResult<(rustler::Atom, Binary<'a>)> {
    let recipient_keys = RECIPIENT_KEYS.lock().unwrap();
    let (_, priv_key) = recipient_keys
        .get(&kid)
        .ok_or_else(|| Error::Term(Box::new(format!("Recipient {} not found", kid))))?;

    let mut allowed = Vec::new();
    for pub_key_bytes in &allowed_sender_pub_keys {
        let sender_pub: tholos_pq::SenderPub = serde_cbor::from_slice(pub_key_bytes.as_slice())
            .map_err(|e| {
                Error::Term(Box::new(format!(
                    "Failed to deserialize sender pub key: {:?}",
                    e
                )))
            })?;
        allowed.push((sender_pub.sid.clone(), sender_pub.pk_dilithium.clone()));
    }

    let plaintext = tholos_pq::decrypt(wire.as_slice(), &kid, &priv_key.sk_kyber, &allowed)
        .map_err(|e| Error::Term(Box::new(format!("Decryption failed: {:?}", e))))?;

    Ok((atoms::ok(), owned_bin(env, &plaintext)?))
}
