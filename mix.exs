defmodule Pipeline.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipeline,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  def cli do
    [
      preferred_envs: [
        "pipeline.test.live": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.11"},
      {:req, "~> 0.5"},
      {:instructor_lite, "~> 1.0.0"},
      {:claude_code_sdk, github: "nshkrdotcom/claude_code_sdk_elixir"},
      {:nimble_options, "~> 1.1"},
      {:ecto, "~> 3.12"},

      # Code quality and analysis tools
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :ex_unit],
      ignore_warnings: ".dialyzer_ignore.exs",
      flags: [
        :error_handling,
        :underspecs,
        :unknown,
        :unmatched_returns
      ]
    ]
  end
end
