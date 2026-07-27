defmodule ExTholosPq.RustRef do
  @moduledoc false

  def roundtrip(message) when is_binary(message) do
    {output, 0} = System.cmd(bin_path!(), ["roundtrip", message], stderr_to_stdout: true)
    Jason.decode!(output)
  end

  def decrypt(wire, kid, recipient_sk, sender_pub)
      when is_binary(wire) and is_binary(kid) and is_binary(recipient_sk) and
             is_binary(sender_pub) do
    request =
      Jason.encode!(%{
        "wire_b64" => Base.encode64(wire),
        "kid" => kid,
        "recipient_sk_b64" => Base.encode64(recipient_sk),
        "sender_pub_b64" => Base.encode64(sender_pub)
      })

    {output, 0} = System.cmd(bin_path!(), ["decrypt-json", request], stderr_to_stdout: true)
    %{"plaintext_b64" => plaintext_b64} = Jason.decode!(output)
    Base.decode64!(plaintext_b64)
  end

  defp bin_path! do
    path = Application.app_dir(:ex_tholos_pq, "priv/native/tholos_pq_ref")

    if File.exists?(path) do
      path
    else
      raise """
      tholos_pq_ref not found at #{path}.
      Compile the project first (mix compile) so Rustler builds the reference binary.
      """
    end
  end
end
