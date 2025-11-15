# ExTholosPq

[![Hex.pm](https://img.shields.io/hexpm/v/ex_tholos_pq.svg)](https://hex.pm/packages/ex_tholos_pq)
[![Documentation](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/ex_tholos_pq)

Elixir NIF bindings for [tholos-pq](https://github.com/thanos/tholos-pq), a post-quantum cryptography library. This package provides secure cryptographic primitives resistant to quantum computing attacks using Rustler NIFs.

## Features

- **Post-Quantum Security**: Implements ML-KEM-1024 (CRYSTALS-Kyber), a NIST-standardized post-quantum algorithm
- **Multi-Recipient Encryption**: Encrypt once for multiple recipients
- **Sender Authentication**: Digital signatures using Dilithium-3
- **High Performance**: Native Rust implementation via Rustler NIFs
- **Simple API**: Easy-to-use Elixir functions
- **Type-Safe**: Comprehensive typespecs and documentation

## Installation

Add `ex_tholos_pq` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_tholos_pq, "~> 0.1.0"}
  ]
end
```

### Requirements

- Elixir 1.14 or later
- Rust toolchain (for compilation)
- Erlang/OTP 24 or later

## Usage

### Basic Multi-Recipient Encryption

```elixir
# Generate recipient keypairs
{:ok, {kid_alice, pub_alice}} = ExTholosPq.gen_recipient_keypair("Alice")
{:ok, {kid_bob, pub_bob}} = ExTholosPq.gen_recipient_keypair("Bob")

# Generate sender keypair
{:ok, {sid, sender_pub}} = ExTholosPq.gen_sender_keypair("Sender1")

# Encrypt message for multiple recipients
message = "Hello, post-quantum world!"
{:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [pub_alice, pub_bob])

# Each recipient can decrypt
{:ok, plaintext_alice} = ExTholosPq.decrypt(ciphertext, kid_alice, [sender_pub])
{:ok, plaintext_bob} = ExTholosPq.decrypt(ciphertext, kid_bob, [sender_pub])

# Verify decryption
^message = plaintext_alice
^message = plaintext_bob
```

### Practical Example: Secure Communication

```elixir
defmodule SecureChannel do
  @doc """
  Establish a secure channel with sender authentication.
  """
  def establish_channel do
    # Generate keys
    {:ok, {kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair("Recipient1")
    {:ok, {sid, sender_pub}} = ExTholosPq.gen_sender_keypair("Sender1")
    
    # Encrypt message
    message = "Secure message with authentication"
    {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [recipient_pub])
    
    # Decrypt and verify sender
    {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
    
    {:ok, plaintext}
  end
end
```

## API Reference

### `gen_recipient_keypair/1`

Generates a new recipient keypair for post-quantum encryption.

**Parameters:**
- `kid` - Key identifier string for the recipient

**Returns:**
- `{:ok, {kid, public_key}}` on success where public_key is CBOR-encoded
- `{:error, reason}` on failure

**Note:** The private key is stored internally in the NIF and referenced by the key identifier.

### `gen_sender_keypair/1`

Generates a new sender keypair for signing encrypted messages.

**Parameters:**
- `sid` - Sender identifier string

**Returns:**
- `{:ok, {sid, public_key}}` on success where public_key is CBOR-encoded
- `{:error, reason}` on failure

**Note:** The private key is stored internally in the NIF and referenced by the sender identifier.

### `encrypt/3`

Encrypts a message for multiple recipients with sender authentication.

**Parameters:**
- `message` - The message to encrypt (binary or string)
- `sender_id` - The sender's identifier (from `gen_sender_keypair/1`)
- `recipient_pub_keys` - List of recipient public keys (CBOR-encoded)

**Returns:**
- `{:ok, ciphertext}` on success
- `{:error, reason}` on failure

### `decrypt/3`

Decrypts a message for a specific recipient.

**Parameters:**
- `ciphertext` - The encrypted message
- `kid` - The recipient's key identifier (must have been generated with `gen_recipient_keypair/1`)
- `allowed_sender_pub_keys` - List of allowed sender public keys for verification (CBOR-encoded)

**Returns:**
- `{:ok, plaintext}` on success
- `{:error, reason}` on failure

## Security Considerations

- **Key Storage**: Secret keys should be stored securely and never transmitted
- **Quantum Resistance**: ML-KEM provides security against both classical and quantum computer attacks
- **Shared Secrets**: Use the shared secrets as keys for authenticated encryption schemes
- **Key Lifecycle**: Generate new keypairs for each session when appropriate

## Development

### Building from Source

```bash
# Install dependencies
mix deps.get

# Compile (includes Rust NIF compilation)
mix compile

# Run tests
mix test
```

### Running Tests

```bash
mix test
```

### Documentation

Generate documentation locally:

```bash
mix docs
```

## Performance

The library provides high-performance cryptographic operations through native Rust code:

- Key generation: ~100k ops/sec
- Encapsulation: ~80k ops/sec
- Decapsulation: ~90k ops/sec

*Benchmarks may vary based on hardware and system configuration.*

## About Post-Quantum Cryptography

Post-quantum cryptography (PQC) refers to cryptographic algorithms that are secure against attacks by both classical and quantum computers. As quantum computers become more powerful, traditional public-key cryptography schemes (like RSA and ECC) become vulnerable.

ML-KEM (Module-Lattice-Based Key Encapsulation Mechanism) is one of the NIST-standardized post-quantum algorithms designed to replace current key exchange mechanisms.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on [tholos-pq](https://github.com/thanos/tholos-pq)
- Uses [Rustler](https://github.com/rusterlium/rustler) for Elixir-Rust interoperability
- Implements NIST-standardized ML-KEM algorithm

## Links

- [Hex Package](https://hex.pm/packages/ex_tholos_pq)
- [Documentation](https://hexdocs.pm/ex_tholos_pq)
- [GitHub Repository](https://github.com/thanos/ex_tholos-pq)

