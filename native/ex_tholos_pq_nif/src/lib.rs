use rustler::types::binary::{Binary, OwnedBinary};
use rustler::{Env, Error, NifResult};
use std::collections::HashMap;
use std::sync::Mutex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

// Store keypairs in a global state (this is a simple approach for demo)
// In production, you'd want better key management
lazy_static::lazy_static! {
    static ref RECIPIENT_KEYS: Mutex<HashMap<String, (tholos_pq::RecipientPub, tholos_pq::RecipientPriv)>> =
        Mutex::new(HashMap::new());
    static ref SENDER_KEYS: Mutex<HashMap<String, tholos_pq::SenderKeypair>> =
        Mutex::new(HashMap::new());
}

// Initialize the NIF module
rustler::init!("Elixir.ExTholosPq");

/// Generate a new recipient keypair and store it
/// Returns {ok, {kid, public_key_cbor}}
#[rustler::nif]
fn gen_recipient_keypair<'a>(
    env: Env<'a>,
    kid: String,
) -> NifResult<(rustler::Atom, (String, Binary<'a>))> {
    let (pub_key, priv_key) = tholos_pq::gen_recipient_keypair(&kid);

    // Serialize public key to CBOR
    let pub_bytes = serde_cbor::to_vec(&pub_key)
        .map_err(|e| Error::Term(Box::new(format!("Serialization failed: {:?}", e))))?;

    // Store the keys
    RECIPIENT_KEYS
        .lock()
        .unwrap()
        .insert(kid.clone(), (pub_key, priv_key));

    let mut pub_bin = OwnedBinary::new(pub_bytes.len()).ok_or(Error::Atom("allocation_failed"))?;
    pub_bin.as_mut_slice().copy_from_slice(&pub_bytes);

    Ok((atoms::ok(), (kid, pub_bin.release(env))))
}

/// Generate a new sender keypair and store it
/// Returns {ok, {sid, public_key_cbor}}
#[rustler::nif]
fn gen_sender_keypair<'a>(
    env: Env<'a>,
    sid: String,
) -> NifResult<(rustler::Atom, (String, Binary<'a>))> {
    let sender = tholos_pq::gen_sender_keypair(&sid);
    let sender_pub = tholos_pq::sender_pub(&sender);

    // Serialize sender public key to CBOR
    let pub_bytes = serde_cbor::to_vec(&sender_pub)
        .map_err(|e| Error::Term(Box::new(format!("Serialization failed: {:?}", e))))?;

    // Store the sender keypair
    SENDER_KEYS.lock().unwrap().insert(sid.clone(), sender);

    let mut pub_bin = OwnedBinary::new(pub_bytes.len()).ok_or(Error::Atom("allocation_failed"))?;
    pub_bin.as_mut_slice().copy_from_slice(&pub_bytes);

    Ok((atoms::ok(), (sid, pub_bin.release(env))))
}

/// Encrypt a message for multiple recipients
/// Returns {ok, ciphertext}
#[rustler::nif]
fn encrypt<'a>(
    env: Env<'a>,
    message: Binary,
    sender_id: String,
    recipient_pub_keys: Vec<Binary>,
) -> NifResult<(rustler::Atom, Binary<'a>)> {
    // Get sender keypair
    let sender_keys = SENDER_KEYS.lock().unwrap();
    let sender = sender_keys
        .get(&sender_id)
        .ok_or_else(|| Error::Term(Box::new(format!("Sender {} not found", sender_id))))?;

    // Deserialize recipient public keys
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

    // Encrypt
    let wire = tholos_pq::encrypt(message.as_slice(), sender, &recipients)
        .map_err(|e| Error::Term(Box::new(format!("Encryption failed: {:?}", e))))?;

    let mut wire_bin = OwnedBinary::new(wire.len()).ok_or(Error::Atom("allocation_failed"))?;
    wire_bin.as_mut_slice().copy_from_slice(&wire);

    Ok((atoms::ok(), wire_bin.release(env)))
}

/// Decrypt a message for a recipient
/// Returns {ok, plaintext}
#[rustler::nif]
fn decrypt<'a>(
    env: Env<'a>,
    wire: Binary,
    kid: String,
    allowed_sender_pub_keys: Vec<Binary>,
) -> NifResult<(rustler::Atom, Binary<'a>)> {
    // Get recipient private key
    let recipient_keys = RECIPIENT_KEYS.lock().unwrap();
    let (_, priv_key) = recipient_keys
        .get(&kid)
        .ok_or_else(|| Error::Term(Box::new(format!("Recipient {} not found", kid))))?;

    // Deserialize allowed sender public keys and build allowed list
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

    // Decrypt
    let plaintext = tholos_pq::decrypt(wire.as_slice(), &kid, &priv_key.sk_kyber, &allowed)
        .map_err(|e| Error::Term(Box::new(format!("Decryption failed: {:?}", e))))?;

    let mut plain_bin =
        OwnedBinary::new(plaintext.len()).ok_or(Error::Atom("allocation_failed"))?;
    plain_bin.as_mut_slice().copy_from_slice(&plaintext);

    Ok((atoms::ok(), plain_bin.release(env)))
}
