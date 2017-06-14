defmodule Memoizer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :memoizer,
      version: "0.1.0",
      elixir: "~> 1.2",
      build_embedded:  Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),

      description: "",
      aliases: [],
      package: package(),
    ]
  end

  defp package do
    [
      maintainers: ["bsanyi"],
      licenses:    ["MIT"],
      links:       %{"GitHub" => "https://github.com/bsanyi/memoizer"},
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    []
  end
end
