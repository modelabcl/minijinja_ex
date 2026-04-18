defmodule MinijinjaEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :minijinja_ex,
      version: "0.1.0",
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
      {:rustler, "~> 0.35.0", runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
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
        "native/minijinja_ex/src",
        "native/minijinja_ex/Cargo.toml",
        "native/minijinja_ex/Cargo.lock",
        ".rustler.toml",
        "mix.exs",
        "README.md",
        "LICENSE"
      ]
    ]
  end
end
