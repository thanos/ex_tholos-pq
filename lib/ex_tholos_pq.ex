# coveralls-ignore-start
defmodule ExTholosPq.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]

  checksum_path =
    __DIR__
    |> Path.join("../checksum-Elixir.ExTholosPq.Native.exs")
    |> Path.expand()

  checksum_missing? = not File.exists?(checksum_path)

  use RustlerPrecompiled,
    otp_app: :ex_tholos_pq,
    crate: "ex_tholos_pq_nif",
    base_url: "https://github.com/thanos/ex_tholos-pq/releases/download/v#{version}",
    version: version,
    nif_versions: ["2.16", "2.17"],
    targets: [
      "aarch64-apple-darwin",
      "x86_64-apple-darwin",
      "x86_64-unknown-linux-gnu",
      "x86_64-unknown-linux-musl",
      "aarch64-unknown-linux-gnu",
      "aarch64-unknown-linux-musl",
      "x86_64-pc-windows-msvc",
      "aarch64-pc-windows-msvc"
    ],
    force_build: System.get_env("EX_THOLOS_PQ_BUILD") in ["1", "true"] or checksum_missing?

  def gen_recipient_keypair(_kid), do: :erlang.nif_error(:nif_not_loaded)

  def gen_sender_keypair(_sid), do: :erlang.nif_error(:nif_not_loaded)

  def encrypt(_message, _sender_id, _recipient_pub_keys), do: :erlang.nif_error(:nif_not_loaded)

  def decrypt(_ciphertext, _kid, _allowed_sender_pub_keys),
    do: :erlang.nif_error(:nif_not_loaded)
end

# coveralls-ignore-stop

defmodule ExTholosPq do
  @moduledoc """
  Elixir NIF bindings for tholos-pq, a post-quantum multi-recipient encryption library.

  This module provides access to post-quantum secure cryptographic primitives
  through Native Implemented Functions (NIFs) written in Rust using the
  tholos-pq library.

  ## Algorithm Suite

  - **Key Encapsulation:** ML-KEM-1024 (Kyber-1024) for per-recipient key wrapping
  - **Symmetric Encryption:** XChaCha20-Poly1305 for payload encryption
  - **Digital Signatures:** Dilithium-3 for sender authentication
  - **Wire Format:** Canonical CBOR with versioning

  ## Installation

  Add `ex_tholos_pq` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:ex_tholos_pq, "~> 0.1.0"}
    ]
  end
  ```

  ## Usage

  The library provides functions for multi-recipient encryption with sender authentication.

  ### Example

  ```elixir
  # Recipient keypairs: `{:ok, {kid, public_key}}`
  {:ok, {alice_kid, pub_a}} = ExTholosPq.gen_recipient_keypair("Alice")
  {:ok, {bob_kid, pub_b}} = ExTholosPq.gen_recipient_keypair("Bob")

  # Sender: `{:ok, {sender_id, sender_public}}`
  {:ok, {sender_id, sender_pub}} = ExTholosPq.gen_sender_keypair("Sender1")

  message = "Hello, post-quantum world!"
  {:ok, ciphertext} = ExTholosPq.encrypt(message, sender_id, [pub_a, pub_b])

  # Decrypt with recipient `kid` and allowed sender public keys
  {:ok, plaintext_a} = ExTholosPq.decrypt(ciphertext, alice_kid, [sender_pub])
  {:ok, plaintext_b} = ExTholosPq.decrypt(ciphertext, bob_kid, [sender_pub])
  ```
  """

  alias ExTholosPq.Native

  @doc """
  Generates a new recipient keypair for post-quantum encryption.

  The keypair is stored internally in the NIF and referenced by the key identifier.

  ## Parameters

    * `kid` - Key identifier string for the recipient

  ## Returns

    * `{:ok, {kid, public_key}}` on success where public_key is CBOR-encoded
    * `{:error, reason}` on failure

  ## Examples

      iex> {:ok, {kid, pub_key}} = ExTholosPq.gen_recipient_keypair("recipient1")
      iex> is_binary(kid) and is_binary(pub_key)
      true

  """
  @spec gen_recipient_keypair(String.t()) :: {:ok, {String.t(), binary()}} | {:error, String.t()}
  def gen_recipient_keypair(kid), do: Native.gen_recipient_keypair(kid)

  @doc """
  Generates a new sender keypair for signing encrypted messages.

  The keypair is stored internally in the NIF and referenced by the sender identifier.

  ## Parameters

    * `sid` - Sender identifier string

  ## Returns

    * `{:ok, {sid, public_key}}` on success where public_key is CBOR-encoded
    * `{:error, reason}` on failure

  ## Examples

      iex> {:ok, {sid, pub_key}} = ExTholosPq.gen_sender_keypair("sender1")
      iex> is_binary(sid) and is_binary(pub_key)
      true

  """
  @spec gen_sender_keypair(String.t()) :: {:ok, {String.t(), binary()}} | {:error, String.t()}
  def gen_sender_keypair(sid), do: Native.gen_sender_keypair(sid)

  @doc """
  Encrypts a message for multiple recipients with sender authentication.

  This function encrypts a message that can be decrypted by any of the
  specified recipients. The sender's signature ensures authenticity.

  ## Parameters

    * `message` - The message to encrypt (binary or string)
    * `sender_id` - The sender's identifier (from `gen_sender_keypair/1`)
    * `recipient_pub_keys` - List of recipient public keys (CBOR-encoded)

  ## Returns

    * `{:ok, ciphertext}` on success
    * `{:error, reason}` on failure

  ## Examples

      iex> {:ok, {_kid, pub_a}} = ExTholosPq.gen_recipient_keypair("Alice")
      iex> {:ok, {sid, _pub}} = ExTholosPq.gen_sender_keypair("Sender")
      iex> {:ok, ct} = ExTholosPq.encrypt("secret", sid, [pub_a])
      iex> is_binary(ct)
      true

  """
  @spec encrypt(binary(), String.t(), list(binary())) ::
          {:ok, binary()} | {:error, String.t()}
  def encrypt(message, sender_id, recipient_pub_keys),
    do: Native.encrypt(message, sender_id, recipient_pub_keys)

  @doc """
  Decrypts a message for a specific recipient.

  ## Parameters

    * `ciphertext` - The encrypted message
    * `kid` - The recipient's key identifier (must have been generated with `gen_recipient_keypair/1`)
    * `allowed_sender_pub_keys` - List of allowed sender public keys for verification (CBOR-encoded)

  ## Returns

    * `{:ok, plaintext}` on success
    * `{:error, reason}` on failure

  ## Examples

      iex> {:ok, {kid, pub}} = ExTholosPq.gen_recipient_keypair("Alice")
      iex> {:ok, {sid, sender_pub}} = ExTholosPq.gen_sender_keypair("Sender")
      iex> {:ok, ct} = ExTholosPq.encrypt("secret", sid, [pub])
      iex> {:ok, plain} = ExTholosPq.decrypt(ct, kid, [sender_pub])
      iex> plain == "secret"
      true

  """
  @spec decrypt(binary(), String.t(), list(binary())) ::
          {:ok, binary()} | {:error, String.t()}
  def decrypt(ciphertext, kid, allowed_sender_pub_keys),
    do: Native.decrypt(ciphertext, kid, allowed_sender_pub_keys)
end
