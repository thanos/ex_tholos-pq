defmodule ExTholosPqCoverageTest do
  use ExUnit.Case, async: false

  describe "argument validation" do
    test "gen_recipient_keypair/1 rejects non-binary kid" do
      assert {:error, "kid must be a binary"} = ExTholosPq.gen_recipient_keypair(:alice)
      assert {:error, "kid must be a binary"} = ExTholosPq.gen_recipient_keypair(123)
      assert {:error, "kid must be a binary"} = ExTholosPq.gen_recipient_keypair(nil)
    end

    test "gen_sender_keypair/1 rejects non-binary sid" do
      assert {:error, "sid must be a binary"} = ExTholosPq.gen_sender_keypair(:sender)
      assert {:error, "sid must be a binary"} = ExTholosPq.gen_sender_keypair(42)
      assert {:error, "sid must be a binary"} = ExTholosPq.gen_sender_keypair([])
    end

    test "encrypt/3 rejects invalid argument types" do
      assert {:error, reason} = ExTholosPq.encrypt(:not_binary, "sid", [])
      assert reason =~ "invalid arguments"

      assert {:error, reason} = ExTholosPq.encrypt("msg", :not_binary, [])
      assert reason =~ "invalid arguments"

      assert {:error, reason} = ExTholosPq.encrypt("msg", "sid", "not-a-list")
      assert reason =~ "invalid arguments"
    end

    test "decrypt/3 rejects invalid argument types" do
      assert {:error, reason} = ExTholosPq.decrypt(:not_binary, "kid", [])
      assert reason =~ "invalid arguments"

      assert {:error, reason} = ExTholosPq.decrypt(<<"ct">>, :not_binary, [])
      assert reason =~ "invalid arguments"

      assert {:error, reason} = ExTholosPq.decrypt(<<"ct">>, "kid", "not-a-list")
      assert reason =~ "invalid arguments"
    end

    test "export/import helpers reject invalid argument types" do
      assert {:error, "kid must be a binary"} = ExTholosPq.export_recipient_secret(:bad)

      assert {:error, reason} = ExTholosPq.import_recipient_keypair(:bad, <<"x">>, <<"y">>)
      assert reason =~ "invalid arguments"

      assert {:error, reason} = ExTholosPq.import_sender_keypair(:bad, <<"x">>, <<"y">>)
      assert reason =~ "invalid arguments"
    end
  end

  describe "NIF error paths" do
    setup do
      kid = "cov_recipient_#{System.unique_integer([:positive])}"
      sid = "cov_sender_#{System.unique_integer([:positive])}"

      {:ok, {^kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)
      {:ok, {^sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
      {:ok, ciphertext} = ExTholosPq.encrypt("coverage payload", sid, [recipient_pub])

      %{
        kid: kid,
        sid: sid,
        recipient_pub: recipient_pub,
        sender_pub: sender_pub,
        ciphertext: ciphertext
      }
    end

    test "encrypt fails when sender is unknown", %{recipient_pub: recipient_pub} do
      assert {:error, reason} = ExTholosPq.encrypt("msg", "unknown_sender", [recipient_pub])
      assert reason =~ "Sender unknown_sender not found"
    end

    test "encrypt fails with malformed recipient public keys", %{sid: sid} do
      assert {:error, reason} = ExTholosPq.encrypt("msg", sid, ["not-valid-cbor"])
      assert reason =~ "Failed to deserialize recipients"
    end

    test "encrypt accepts an empty recipient list", %{sid: sid} do
      assert {:ok, ciphertext} = ExTholosPq.encrypt("orphan message", sid, [])
      assert is_binary(ciphertext)
      assert byte_size(ciphertext) > 0
    end

    test "decrypt fails when recipient is unknown", %{
      ciphertext: ciphertext,
      sender_pub: sender_pub
    } do
      assert {:error, reason} = ExTholosPq.decrypt(ciphertext, "unknown_recipient", [sender_pub])
      assert reason =~ "Recipient unknown_recipient not found"
    end

    test "decrypt fails with malformed sender public keys", %{
      ciphertext: ciphertext,
      kid: kid
    } do
      assert {:error, reason} = ExTholosPq.decrypt(ciphertext, kid, ["not-valid-cbor"])
      assert reason =~ "Failed to deserialize sender pub key"
    end

    test "decrypt fails with empty allow-list", %{ciphertext: ciphertext, kid: kid} do
      assert {:error, reason} = ExTholosPq.decrypt(ciphertext, kid, [])
      assert reason =~ "Decryption failed"
    end

    test "decrypt fails with wrong allowed sender", %{ciphertext: ciphertext, kid: kid} do
      other_sid = "other_sender_#{System.unique_integer([:positive])}"
      {:ok, {^other_sid, other_pub}} = ExTholosPq.gen_sender_keypair(other_sid)

      assert {:error, reason} = ExTholosPq.decrypt(ciphertext, kid, [other_pub])
      assert reason =~ "Decryption failed"
    end

    test "decrypt fails with garbage ciphertext", %{kid: kid, sender_pub: sender_pub} do
      assert {:error, reason} = ExTholosPq.decrypt(<<"garbage">>, kid, [sender_pub])
      assert reason =~ "Decryption failed"
    end

    test "encrypt/decrypt roundtrip covers binary messages", %{
      kid: kid,
      sid: sid,
      recipient_pub: recipient_pub,
      sender_pub: sender_pub
    } do
      message = <<0, 1, 2, 255, 0>>
      assert {:ok, ciphertext} = ExTholosPq.encrypt(message, sid, [recipient_pub])
      assert {:ok, ^message} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
    end
  end
end
