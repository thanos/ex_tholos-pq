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
  # Generate recipient keypairs
  {:ok, {pub_a, priv_a}} = ExTholosPq.gen_recipient_keypair("Alice")
  {:ok, {pub_b, priv_b}} = ExTholosPq.gen_recipient_keypair("Bob")

  # Generate sender keypair
  {:ok, sender} = ExTholosPq.gen_sender_keypair("Sender1")

  # Encrypt message for multiple recipients
  message = "Hello, post-quantum world!"
  {:ok, ciphertext} = ExTholosPq.encrypt(message, sender, [pub_a, pub_b])

  # Each recipient can decrypt
  {:ok, plaintext_a} = ExTholosPq.decrypt(ciphertext, "Alice", priv_a, [])
  {:ok, plaintext_b} = ExTholosPq.decrypt(ciphertext, "Bob", priv_b, [])
  ```
  """

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :ex_tholos_pq,
    crate: "ex_tholos_pq_nif",
    base_url: "https://github.com/thanos/ex_tholos-pq/releases/download/v#{version}",
    force_build:
      System.get_env("EX_THOLOS_PQ_BUILD") in ["1", "true"] or
        not File.exists?(Path.expand("../checksum-Elixir.ExTholosPq.exs", __DIR__)),
    version: version

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
  def gen_recipient_keypair(kid) when is_binary(kid), do: nif_gen_recipient_keypair(kid)
  def gen_recipient_keypair(_kid), do: {:error, "kid must be a binary"}

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
  def gen_sender_keypair(sid) when is_binary(sid), do: nif_gen_sender_keypair(sid)
  def gen_sender_keypair(_sid), do: {:error, "sid must be a binary"}

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
  def encrypt(message, sender_id, recipient_pub_keys)
      when is_binary(message) and is_binary(sender_id) and is_list(recipient_pub_keys) do
    nif_encrypt(message, sender_id, recipient_pub_keys)
  end

  def encrypt(_message, _sender_id, _recipient_pub_keys),
    do: {:error, "invalid arguments: expected binary message, binary sender_id, and list of keys"}

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
  def decrypt(ciphertext, kid, allowed_sender_pub_keys)
      when is_binary(ciphertext) and is_binary(kid) and is_list(allowed_sender_pub_keys) do
    nif_decrypt(ciphertext, kid, allowed_sender_pub_keys)
  end

  def decrypt(_ciphertext, _kid, _allowed_sender_pub_keys),
    do: {:error, "invalid arguments: expected binary ciphertext, binary kid, and list of keys"}

  @doc """
  Exports the recipient ML-KEM secret key bytes for a previously generated kid.

  Used for interoperability checks against pure Rust `tholos-pq`.
  """
  @spec export_recipient_secret(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def export_recipient_secret(kid) when is_binary(kid), do: nif_export_recipient_secret(kid)
  def export_recipient_secret(_kid), do: {:error, "kid must be a binary"}

  @doc """
  Imports a recipient keypair (CBOR public key + raw ML-KEM secret) into the NIF store.
  """
  @spec import_recipient_keypair(String.t(), binary(), binary()) ::
          {:ok, {String.t(), binary()}} | {:error, String.t()}
  def import_recipient_keypair(kid, pub_cbor, sk_bytes)
      when is_binary(kid) and is_binary(pub_cbor) and is_binary(sk_bytes) do
    nif_import_recipient_keypair(kid, pub_cbor, sk_bytes)
  end

  def import_recipient_keypair(_kid, _pub_cbor, _sk_bytes),
    do: {:error, "invalid arguments: expected binary kid, pub_cbor, and sk_bytes"}

  @doc """
  Imports a sender keypair (Dilithium public + secret key bytes) into the NIF store.
  """
  @spec import_sender_keypair(String.t(), binary(), binary()) ::
          {:ok, {String.t(), binary()}} | {:error, String.t()}
  def import_sender_keypair(sid, pk_bytes, sk_bytes)
      when is_binary(sid) and is_binary(pk_bytes) and is_binary(sk_bytes) do
    nif_import_sender_keypair(sid, pk_bytes, sk_bytes)
  end

  def import_sender_keypair(_sid, _pk_bytes, _sk_bytes),
    do: {:error, "invalid arguments: expected binary sid, pk_bytes, and sk_bytes"}

  # NIF stubs — overwritten at load time by Rustler.
  # coveralls-ignore-start
  defp nif_gen_recipient_keypair(_kid), do: :erlang.nif_error(:nif_not_loaded)
  defp nif_gen_sender_keypair(_sid), do: :erlang.nif_error(:nif_not_loaded)

  defp nif_encrypt(_message, _sender_id, _recipient_pub_keys),
    do: :erlang.nif_error(:nif_not_loaded)

  defp nif_decrypt(_ciphertext, _kid, _allowed_sender_pub_keys),
    do: :erlang.nif_error(:nif_not_loaded)

  defp nif_export_recipient_secret(_kid), do: :erlang.nif_error(:nif_not_loaded)

  defp nif_import_recipient_keypair(_kid, _pub_cbor, _sk_bytes),
    do: :erlang.nif_error(:nif_not_loaded)

  defp nif_import_sender_keypair(_sid, _pk_bytes, _sk_bytes),
    do: :erlang.nif_error(:nif_not_loaded)

  # coveralls-ignore-stop
end
