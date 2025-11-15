defmodule ExTholosPqTest do
  use ExUnit.Case
  doctest ExTholosPq

  describe "gen_recipient_keypair/1" do
    test "generates a valid recipient keypair" do
      assert {:ok, {kid, public_key}} = ExTholosPq.gen_recipient_keypair("recipient1")
      assert kid == "recipient1"
      assert is_binary(public_key)
      assert byte_size(public_key) > 0
    end

    test "generates different keypairs for different identifiers" do
      assert {:ok, {kid1, pk1}} = ExTholosPq.gen_recipient_keypair("recipient1")
      assert {:ok, {kid2, pk2}} = ExTholosPq.gen_recipient_keypair("recipient2")
      assert kid1 != kid2
      assert pk1 != pk2
    end
  end

  describe "gen_sender_keypair/1" do
    test "generates a valid sender keypair" do
      assert {:ok, {sid, public_key}} = ExTholosPq.gen_sender_keypair("sender1")
      assert sid == "sender1"
      assert is_binary(public_key)
      assert byte_size(public_key) > 0
    end

    test "generates different keypairs for different identifiers" do
      assert {:ok, {sid1, pk1}} = ExTholosPq.gen_sender_keypair("sender1")
      assert {:ok, {sid2, pk2}} = ExTholosPq.gen_sender_keypair("sender2")
      assert sid1 != sid2
      assert pk1 != pk2
    end
  end

  describe "encrypt/3 and decrypt/3" do
    test "encrypts and decrypts a message successfully" do
      # Generate keys
      {:ok, {kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair("Alice")
      {:ok, {sid, sender_pub}} = ExTholosPq.gen_sender_keypair("Sender1")

      # Encrypt
      message = "Hello, post-quantum world!"
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [recipient_pub])
      assert is_binary(ciphertext)
      assert byte_size(ciphertext) > 0

      # Decrypt
      {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
      assert plaintext == message
    end

    test "multiple recipients can decrypt the same message" do
      # Generate keys for two recipients
      {:ok, {kid_a, pub_a}} = ExTholosPq.gen_recipient_keypair("Alice")
      {:ok, {kid_b, pub_b}} = ExTholosPq.gen_recipient_keypair("Bob")
      {:ok, {sid, sender_pub}} = ExTholosPq.gen_sender_keypair("Sender2")

      # Encrypt for both recipients
      message = "Secret for Alice and Bob"
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [pub_a, pub_b])

      # Both can decrypt
      {:ok, plaintext_a} = ExTholosPq.decrypt(ciphertext, kid_a, [sender_pub])
      {:ok, plaintext_b} = ExTholosPq.decrypt(ciphertext, kid_b, [sender_pub])

      assert plaintext_a == message
      assert plaintext_b == message
    end

    test "fails to decrypt with wrong recipient" do
      {:ok, {_kid_a, pub_a}} = ExTholosPq.gen_recipient_keypair("Alice")
      {:ok, {kid_b, _pub_b}} = ExTholosPq.gen_recipient_keypair("Bob")
      {:ok, {sid, sender_pub}} = ExTholosPq.gen_sender_keypair("Sender3")

      # Encrypt only for Alice
      message = "Only for Alice"
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [pub_a])

      # Bob tries to decrypt - should fail
      result = ExTholosPq.decrypt(ciphertext, kid_b, [sender_pub])
      assert {:error, _reason} = result
    end
  end

  describe "complete encryption workflow" do
    test "full multi-recipient encryption with authentication" do
      # Setup: Generate keys for 3 recipients and 2 senders
      {:ok, {kid_a, pub_a}} = ExTholosPq.gen_recipient_keypair("Alice")
      {:ok, {kid_b, pub_b}} = ExTholosPq.gen_recipient_keypair("Bob")
      {:ok, {kid_c, pub_c}} = ExTholosPq.gen_recipient_keypair("Carol")

      {:ok, {sid1, sender_pub1}} = ExTholosPq.gen_sender_keypair("Sender1")
      {:ok, {_sid2, sender_pub2}} = ExTholosPq.gen_sender_keypair("Sender2")

      # Encrypt message from Sender1 for all three recipients
      message = "Post-quantum secure message for A, B, and C"
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid1, [pub_a, pub_b, pub_c])

      # All recipients can decrypt (with sender verification)
      allowed_senders = [sender_pub1, sender_pub2]

      {:ok, plain_a} = ExTholosPq.decrypt(ciphertext, kid_a, allowed_senders)
      {:ok, plain_b} = ExTholosPq.decrypt(ciphertext, kid_b, allowed_senders)
      {:ok, plain_c} = ExTholosPq.decrypt(ciphertext, kid_c, allowed_senders)

      assert plain_a == message
      assert plain_b == message
      assert plain_c == message
    end
  end
end
