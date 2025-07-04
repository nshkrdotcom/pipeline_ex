defmodule Pipeline.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipeline,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # Library package configuration
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/nshkrdotcom/pipeline_ex",
      homepage_url: "https://github.com/nshkrdotcom/pipeline_ex"
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
      extra_applications: [:logger],
      mod: {Pipeline.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.11"},
      {:req, "~> 0.5"},
      {:instructor_lite, "~> 1.0.0"},
      {:claude_code_sdk, github: "nshkrdotcom/claude_code_sdk_elixir", ref: "main"},
      {:nimble_options, "~> 1.1"},
      {:ecto, "~> 3.12"},
      {:jido, github: "nshkrdotcom/jido", branch: "fix/agent-server-terminate-race-condition-v2"},

      # Code quality and analysis tools
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "AI pipeline orchestration library for Elixir. Chain Claude and Gemini APIs with robust execution, fault tolerance, and self-improving Genesis pipelines."
  end

  defp package do
    [
      name: "pipeline_ex",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/nshkrdotcom/pipeline_ex",
        "Docs" => "https://hexdocs.pm/pipeline_ex"
      },
      maintainers: ["nshkr"],
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md),
      exclude_patterns: ["priv/plts/*"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v0.1.0",
      source_url: "https://github.com/nshkrdotcom/pipeline_ex",
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"],
        "JULY_1_ARCH_DOCS_01_VISION.md": [title: "System Vision"],
        "JULY_1_ARCH_DOCS_02_HYBRID_ARCHITECTURE.md": [title: "Architecture"]
      ],
      groups_for_modules: [
        Core: [Pipeline, Pipeline.Config, Pipeline.Executor],
        Providers: [Pipeline.Providers.ClaudeProvider, Pipeline.Providers.GeminiProvider],
        Steps: [Pipeline.Step.Claude, Pipeline.Step.Gemini, Pipeline.Step.ClaudeSmart],
        Meta: [Pipeline.Meta.Generator, Pipeline.Meta.DNA],
        Testing: [Pipeline.TestMode, Pipeline.Test.Mocks]
      ]
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
