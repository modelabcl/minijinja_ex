defmodule MinijinjaEx.MixProject do
  use Mix.Project

  @version "0.1.3"

  def project do
    [
      app: :minijinja_ex,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Elixir wrapper for minijinja template engine using Rustler",
      source_url: "https://github.com/modelabcl/minijinja_ex",
      homepage_url: "https://github.com/modelabcl/minijinja_ex",
      docs: [
        main: "MinijinjaEx",
        extras: ["README.md"]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler_precompiled, "~> 0.9"},
      {:rustler, "~> 0.35", optional: true},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp package do
    [
      name: "minijinja_ex",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/modelabcl/minijinja_ex",
        "minijinja" => "https://github.com/mitsuhiko/minijinja"
      },
      files: [
        "lib",
        "native/minijinja_ex/.cargo",
        "native/minijinja_ex/src",
        "native/minijinja_ex/Cargo*",
        "checksum-*.exs",
        ".rustler.toml",
        "mix.exs",
        "README.md",
        "LICENSE"
      ]
    ]
  end
end
