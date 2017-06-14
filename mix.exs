defmodule Memoizer.Mixfile do
  use Mix.Project

  def project do
    [
      app:     :memoizer,
      version: "0.1.0",
      elixir:  "~> 1.2",

      build_embedded:  Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),

      # Hex
      description: "OTP app to memoize/cache expensive function calls",
      aliases:     [],
      package:     package(),
    ]
  end

  defp package do
    [
      maintainers: ["bsanyi"],
      licenses:    ["MIT"],
      links:       %{"GitHub" => "https://github.com/bsanyi/memoizer"},
    ]
  end

  def application do
    [
      applications: [:logger],
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
    ]
  end
end
