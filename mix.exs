defmodule Hubspot.MixProject do
  use Mix.Project

  require Logger

  @default_version "1.0.0"

  def project do
    [
      app: :hubspot,
      version: "1.0.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # ExDoc configurations
      name: "Hubspot",
      source_url: "https://github.com/userpilot/hubspot",
      homepage_url: "https://userpilot.com",
      docs: [
        main: "README",
        extras: ["README.md"]
      ],

      # Dialyzer configurations
      dialyzer: [
        list_unused_filters: true,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ]
    ]
  end

  defdelegate version, to: Versioning

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Hubspot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cachex,
       git: "https://github.com/whitfin/cachex.git",
       ref: "a0ef5788859b340831bd4b491464f9ce34fdb1dc"},
      {:jason, "~> 1.2.2"},
      {:finch, "~> 0.13"}
    ]
  end
end
