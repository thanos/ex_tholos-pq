defmodule ExTholosPq.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/yourusername/ex_tholos-pq"

  def project do
    [
      app: :ex_tholos_pq,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "ExTholosPq",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.34.0", runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir NIF bindings for tholos-pq, a post-quantum cryptography library.
    Provides secure cryptographic primitives resistant to quantum computing attacks.
    """
  end

  defp package do
    [
      name: "ex_tholos_pq",
      files: ~w(lib native .formatter.exs mix.exs README.md LICENSE),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      },
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "ExTholosPq",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
