defmodule JidoHexTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_hex_test,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: deps(),
      dialyzer: [
        plt_core_path: "priv/plts",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:jido, "~> 1.2"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end
end