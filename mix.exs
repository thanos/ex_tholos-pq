defmodule ExTholosPq.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/thanos/ex_tholos-pq"

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
      source_url: @source_url,
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.37.1", runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false, warn_if_outdated: true},
      {:stream_data, "~> 1.2.0", only: :test},
      {:excoveralls, "~> 0.18", only: :test}
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
      maintainers: ["Thanos Vassilakis"]
    ]
  end

  defp docs do
    [
      main: "ExTholosPq",
      extras: [
        "README.md",
        "QUICKSTART.md",
        "SETUP.md",
        "PUBLISHING.md",
        "PROJECT_OVERVIEW.md",
        "CONTRIBUTING.md",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      groups_for_modules: [
        API: [
          ExTholosPq
        ]
      ],
      nest_modules_by_prefix: [ExTholosPq]
    ]
  end

  defp aliases do
    [
      format: [
        "format",
        "cmd cargo fmt --manifest-path native/ex_tholos_pq_nif/Cargo.toml"
      ],
      credo: [
        "credo --strict",
        "cmd cargo clippy --manifest-path native/ex_tholos_pq_nif/Cargo.toml -- -D warnings"
      ]
    ]
  end
end
