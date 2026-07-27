defmodule ExTholosPqRustRefTest do
  use ExUnit.Case, async: false

  alias ExTholosPq.RustRef

  @message "compare nif with pure rust tholos-pq"

  test "pure Rust roundtrip recovers the message" do
    result = RustRef.roundtrip(@message)

    assert result["plaintext_b64"] == Base.encode64(@message)
    assert result["message_b64"] == Base.encode64(@message)
    assert is_binary(result["wire_b64"])
  end

  test "NIF roundtrip recovers the same plaintext as pure Rust" do
    rust = RustRef.roundtrip(@message)
    assert Base.decode64!(rust["plaintext_b64"]) == @message

    kid = "nif_#{System.unique_integer([:positive])}"
    sid = "nif_sender_#{System.unique_integer([:positive])}"

    {:ok, {^kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)
    {:ok, {^sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
    {:ok, ciphertext} = ExTholosPq.encrypt(@message, sid, [recipient_pub])
    {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])

    assert plaintext == @message
    assert plaintext == Base.decode64!(rust["plaintext_b64"])
  end

  test "NIF can decrypt a ciphertext produced by pure Rust" do
    rust = RustRef.roundtrip(@message)

    kid = rust["kid"]
    recipient_pub = Base.decode64!(rust["recipient_pub_b64"])
    recipient_sk = Base.decode64!(rust["recipient_sk_b64"])
    sender_pub = Base.decode64!(rust["sender_pub_b64"])
    wire = Base.decode64!(rust["wire_b64"])

    assert {:ok, {^kid, ^recipient_pub}} =
             ExTholosPq.import_recipient_keypair(kid, recipient_pub, recipient_sk)

    assert {:ok, plaintext} = ExTholosPq.decrypt(wire, kid, [sender_pub])
    assert plaintext == @message
  end

  test "pure Rust can decrypt a ciphertext produced by the NIF" do
    kid = "export_#{System.unique_integer([:positive])}"
    sid = "export_sender_#{System.unique_integer([:positive])}"

    {:ok, {^kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)
    {:ok, {^sid, sender_pub}} = ExTholosPq.gen_sender_keypair(sid)
    {:ok, ciphertext} = ExTholosPq.encrypt(@message, sid, [recipient_pub])
    {:ok, recipient_sk} = ExTholosPq.export_recipient_secret(kid)

    plaintext = RustRef.decrypt(ciphertext, kid, recipient_sk, sender_pub)
    assert plaintext == @message
  end

  test "NIF can encrypt using a sender keypair imported from pure Rust" do
    rust = RustRef.roundtrip("seed")

    kid = "imported_#{System.unique_integer([:positive])}"
    sid = rust["sid"]
    sender_pk = Base.decode64!(rust["sender_pk_b64"])
    sender_sk = Base.decode64!(rust["sender_sk_b64"])

    {:ok, {^sid, sender_pub}} = ExTholosPq.import_sender_keypair(sid, sender_pk, sender_sk)
    {:ok, {^kid, recipient_pub}} = ExTholosPq.gen_recipient_keypair(kid)

    {:ok, ciphertext} = ExTholosPq.encrypt(@message, sid, [recipient_pub])
    {:ok, plaintext} = ExTholosPq.decrypt(ciphertext, kid, [sender_pub])
    assert plaintext == @message

    {:ok, recipient_sk} = ExTholosPq.export_recipient_secret(kid)
    assert RustRef.decrypt(ciphertext, kid, recipient_sk, sender_pub) == @message
  end
end
