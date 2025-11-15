defmodule ExTholosPqPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  import StreamData

  # Helper to generate unique identifiers
  defp unique_id, do: string(:alphanumeric, min_length: 1, max_length: 255)

  # Helper to generate message data
  defp message_data do
    one_of([
      string(:printable, min_length: 0, max_length: 10_000),
      binary(min_length: 0, max_length: 1000)
    ])
  end

  property "encrypt/decrypt roundtrip preserves message" do
    check all(
            kid <- unique_id(),
            sid <- unique_id(),
            message <- message_data(),
            max_runs: 200
          ) do
      # Generate keys
      {:ok, {returned_kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)
      {:ok, {returned_sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)

      assert returned_kid == kid
      assert returned_sid == sid

      # Encrypt
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [recipient_pub])
      assert is_binary(ciphertext)
      assert byte_size(ciphertext) > 0

      # Decrypt
      {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
      assert plaintext == message
    end
  end

  property "encrypt/decrypt works with multiple recipients" do
    check all(
            num_recipients <- integer(1..5),
            sid <- unique_id(),
            message <- message_data(),
            max_runs: 100
          ) do
      # Generate recipient keys
      recipients =
        Enum.map(1..num_recipients, fn i ->
          kid = "recipient_#{i}"
          {:ok, {returned_kid, pub}} = ExTholosPq.gen_recipient_keypair(kid)
          assert returned_kid == kid
          {kid, pub}
        end)

      recipient_pubs = Enum.map(recipients, fn {_kid, pub} -> pub end)

      # Generate sender key
      {:ok, {returned_sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
      assert returned_sid == sid

      # Encrypt for all recipients
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, recipient_pubs)
      assert is_binary(ciphertext)

      # All recipients can decrypt
      Enum.each(recipients, fn {kid, _pub} ->
        {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
        assert plaintext == message
      end)
    end
  end

  property "ciphertext is different for same message" do
    check all(
            kid <- unique_id(),
            sid <- unique_id(),
            message <- message_data(),
            max_runs: 100
          ) do
      {:ok, {returned_kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)
      assert returned_kid == kid
      {:ok, {returned_sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
      assert returned_sid == sid

      # Encrypt same message twice
      {:ok, ciphertext1} = ExTholosPq.encrypt(message, sid, [recipient_pub])
      {:ok, ciphertext2} = ExTholosPq.encrypt(message, sid, [recipient_pub])

      # Ciphertexts should be different (due to nonce/randomness)
      assert ciphertext1 != ciphertext2

      # But both should decrypt to the same message
      {:ok, plaintext1} = ExTholosPq.decrypt(ciphertext1, kid, [sender_pub])
      {:ok, plaintext2} = ExTholosPq.decrypt(ciphertext2, kid, [sender_pub])
      assert plaintext1 == message
      assert plaintext2 == message
    end
  end

  property "decrypt fails with wrong recipient" do
    check all(
            kid1 <- unique_id(),
            kid2 <- unique_id(),
            sid <- unique_id(),
            message <- message_data(),
            max_runs: 100
          ) do
      # Generate keys for two different recipients
      {:ok, {returned_kid1, pub1}} = ExTholosPq.gen_recipient_keypair(kid1)
      assert returned_kid1 == kid1
      {:ok, {returned_kid2, _pub2}} = ExTholosPq.gen_recipient_keypair(kid2)
      assert returned_kid2 == kid2
      {:ok, {returned_sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
      assert returned_sid == sid

      # Encrypt only for recipient 1
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [pub1])

      # Recipient 2 cannot decrypt
      result = ExTholosPq.decrypt(ciphertext, kid2, [sender_pub])
      assert {:error, _reason} = result
    end
  end

  property "keypair generation produces valid keys" do
    check all(kid <- unique_id(), max_runs: 50) do
      {:ok, {returned_kid, public_key}} = ExTholosPq.gen_recipient_keypair(kid)
      assert returned_kid == kid

      assert is_binary(public_key)
      assert byte_size(public_key) > 0
      assert kid != ""
    end
  end

  property "sender keypair generation produces valid keys" do
    check all(sid <- unique_id(), max_runs: 50) do
      {:ok, {returned_sid, public_key}} = ExTholosPq.gen_sender_keypair(sid)
      assert returned_sid == sid

      assert is_binary(public_key)
      assert byte_size(public_key) > 0
      assert sid != ""
    end
  end

  property "different identifiers produce different keypairs" do
    check all(
            id1 <- unique_id(),
            id2 <- unique_id(),
            max_runs: 100
          ) do
      # Ensure different IDs
      if id1 != id2 do
        {:ok, {returned_id1, pub1}} = ExTholosPq.gen_recipient_keypair(id1)
        assert returned_id1 == id1
        {:ok, {returned_id2, pub2}} = ExTholosPq.gen_recipient_keypair(id2)
        assert returned_id2 == id2

        assert pub1 != pub2
      end
    end
  end

  property "encrypt handles empty message" do
    check all(
            kid <- unique_id(),
            sid <- unique_id(),
            max_runs: 100
          ) do
      {:ok, {returned_kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)
      assert returned_kid == kid
      {:ok, {returned_sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
      assert returned_sid == sid

      # Encrypt empty message
      {:ok, ciphertext} = ExTholosPq.encrypt("", sid, [recipient_pub])
      assert is_binary(ciphertext)

      # Decrypt
      {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
      assert plaintext == ""
    end
  end

  property "encrypt handles large messages" do
    check all(
            kid <- unique_id(),
            sid <- unique_id(),
            message <- binary(min_length: 0, max_length: 10_000),
            max_runs: 100
          ) do
      {:ok, {returned_kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)
      assert returned_kid == kid
      {:ok, {returned_sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
      assert returned_sid == sid

      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [recipient_pub])
      {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])

      assert plaintext == message
    end
  end

  property "multi-recipient: all recipients get same message" do
    check all(
            num_recipients <- integer(1..100),
            sid <- unique_id(),
            message <- message_data(),
            max_runs: 100
          ) do
      # Generate multiple recipients
      recipients =
        Enum.map(1..num_recipients, fn i ->
          kid = "r_#{i}"
          {:ok, {returned_kid, pub}} = ExTholosPq.gen_recipient_keypair(kid)
          assert returned_kid == kid
          {kid, pub}
        end)

      recipient_pubs = Enum.map(recipients, fn {_kid, pub} -> pub end)
      {:ok, {returned_sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
      assert returned_sid == sid

      # Encrypt for all
      {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, recipient_pubs)

      # Verify all can decrypt to same message
      Enum.each(recipients, fn {kid, _pub} ->
        {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
        assert plaintext == message
      end)
    end
  end
end
