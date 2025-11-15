# Quick Start Guide

Get up and running with ExTholosPq in 5 minutes!

## Prerequisites

Make sure you have installed:
- Elixir 1.14+ 
- Erlang/OTP 24+
- Rust (stable)

## Installation

### From Hex.pm (after publishing)

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_tholos_pq, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

### From Source (for development)

```bash
# Clone the repository
git clone https://github.com/yourusername/ex_tholos-pq.git
cd ex_tholos-pq

# Install dependencies
mix deps.get

# Compile (includes Rust NIF)
mix compile
```

## Basic Usage

### 1. Generate a Keypair

```elixir
{:ok, {public_key, secret_key}} = ExTholosPq.keypair()
```

### 2. Encapsulate (Sender Side)

```elixir
# Generate and encapsulate a shared secret
{:ok, {ciphertext, shared_secret}} = ExTholosPq.encapsulate(public_key)
```

### 3. Decapsulate (Receiver Side)

```elixir
# Recover the shared secret
{:ok, recovered_secret} = ExTholosPq.decapsulate(secret_key, ciphertext)

# Verify it matches
^recovered_secret = shared_secret
```

## Complete Example

### Secure Key Exchange

```elixir
defmodule SecureKeyExchange do
  @moduledoc """
  Demonstrates a complete post-quantum key exchange between Alice and Bob.
  """

  def run do
    # Step 1: Bob generates his keypair
    IO.puts("Bob generates keypair...")
    {:ok, {bob_public_key, bob_secret_key}} = ExTholosPq.keypair()
    
    # Step 2: Bob sends his public key to Alice (this can be over insecure channel)
    IO.puts("Bob shares public key with Alice")
    
    # Step 3: Alice generates shared secret and encapsulates it
    IO.puts("Alice generates and encapsulates shared secret...")
    {:ok, {ciphertext, alice_shared_secret}} = ExTholosPq.encapsulate(bob_public_key)
    
    # Step 4: Alice sends ciphertext to Bob (can be over insecure channel)
    IO.puts("Alice sends ciphertext to Bob")
    
    # Step 5: Bob decapsulates to get the same shared secret
    IO.puts("Bob decapsulates ciphertext...")
    {:ok, bob_shared_secret} = ExTholosPq.decapsulate(bob_secret_key, ciphertext)
    
    # Step 6: Verify both have the same shared secret
    if alice_shared_secret == bob_shared_secret do
      IO.puts("Success! Both parties have the same shared secret")
      IO.puts("Shared secret: #{Base.encode16(alice_shared_secret) |> String.slice(0, 32)}...")
      {:ok, alice_shared_secret}
    else
      IO.puts("Error! Shared secrets don't match")
      {:error, :secret_mismatch}
    end
  end
end

# Run it!
SecureKeyExchange.run()
```

### Using in a GenServer

```elixir
defmodule SecureSession do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Generate keypair on startup
    {:ok, {public_key, secret_key}} = ExTholosPq.keypair()
    
    {:ok, %{
      public_key: public_key,
      secret_key: secret_key,
      sessions: %{}
    }}
  end

  def get_public_key do
    GenServer.call(__MODULE__, :get_public_key)
  end

  def establish_session(peer_id, ciphertext) do
    GenServer.call(__MODULE__, {:establish_session, peer_id, ciphertext})
  end

  def handle_call(:get_public_key, _from, state) do
    {:reply, state.public_key, state}
  end

  def handle_call({:establish_session, peer_id, ciphertext}, _from, state) do
    case ExTholosPq.decapsulate(state.secret_key, ciphertext) do
      {:ok, shared_secret} ->
        # Store session
        sessions = Map.put(state.sessions, peer_id, shared_secret)
        {:reply, {:ok, :session_established}, %{state | sessions: sessions}}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end
```

## Testing Your Integration

Create a test file `test/my_crypto_test.exs`:

```elixir
defmodule MyCryptoTest do
  use ExUnit.Case

  test "can perform key exchange" do
    # Generate keypair
    {:ok, {pk, sk}} = ExTholosPq.keypair()
    
    # Encapsulate
    {:ok, {ct, ss1}} = ExTholosPq.encapsulate(pk)
    
    # Decapsulate
    {:ok, ss2} = ExTholosPq.decapsulate(sk, ct)
    
    # Verify
    assert ss1 == ss2
  end
end
```

Run tests:

```bash
mix test
```

## Common Patterns

### 1. Deriving Session Keys

```elixir
def derive_session_keys(shared_secret) do
  # Use HKDF or similar KDF
  :crypto.hash(:sha256, shared_secret <> "encryption")
  |> Base.encode16()
  |> String.slice(0, 32)
end
```

### 2. Hybrid Encryption

```elixir
def hybrid_encrypt(message, recipient_pq_public_key) do
  # 1. Generate symmetric key
  aes_key = :crypto.strong_rand_bytes(32)
  
  # 2. Encrypt message with AES
  encrypted_message = encrypt_aes(message, aes_key)
  
  # 3. Encapsulate AES key with PQ crypto
  {:ok, {ciphertext, _shared_secret}} = ExTholosPq.encapsulate(recipient_pq_public_key)
  
  # 4. Derive key from shared secret
  # (In practice, use the shared_secret to encrypt the aes_key)
  
  {:ok, {ciphertext, encrypted_message}}
end
```

### 3. Key Rotation

```elixir
defmodule KeyRotation do
  use GenServer
  
  @rotation_interval :timer.hours(24)
  
  def init(_) do
    {:ok, {pk, sk}} = ExTholosPq.keypair()
    schedule_rotation()
    {:ok, %{public_key: pk, secret_key: sk}}
  end
  
  def handle_info(:rotate_keys, _state) do
    {:ok, {new_pk, new_sk}} = ExTholosPq.keypair()
    schedule_rotation()
    {:noreply, %{public_key: new_pk, secret_key: new_sk}}
  end
  
  defp schedule_rotation do
    Process.send_after(self(), :rotate_keys, @rotation_interval)
  end
end
```

## Performance Tips

1. **Reuse Keys**: Key generation is fast, but reuse keys within a session
2. **Batch Operations**: If possible, batch multiple operations
3. **Async Processing**: Use Task.async for parallel operations
4. **Caching**: Cache derived keys to avoid repeated KDF operations

## Troubleshooting

### "NIF not loaded" error

```bash
# Clean and recompile
mix clean
mix compile
```

### Keys are different types

```elixir
# Keys are binary data
public_key |> is_binary()  # => true
secret_key |> is_binary()  # => true

# To display as hex:
Base.encode16(public_key)
```

### Performance concerns

```elixir
# Benchmark operations
:timer.tc(fn -> ExTholosPq.keypair() end)
# => {10_000, {:ok, {pk, sk}}}  # 10 microseconds
```

## Next Steps

- 📖 Read the [README.md](README.md) for detailed documentation
- 🔧 Check [SETUP.md](SETUP.md) for development setup
- 🚀 See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for architecture details
- 🤝 Read [CONTRIBUTING.md](CONTRIBUTING.md) to contribute

## Need Help?

- 📝 [Open an issue](https://github.com/yourusername/ex_tholos-pq/issues)
- 💬 [Start a discussion](https://github.com/yourusername/ex_tholos-pq/discussions)
- 📧 Email: your.email@example.com

Happy coding! 🎉

