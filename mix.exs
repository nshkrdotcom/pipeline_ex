defmodule Pipeline.MixProject do
  use Mix.Project

  def project do
    [
      app: :pipeline,
      version: "0.0.1",
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
      {:claude_code_sdk, git: "https://github.com/nshkrdotcom/claude_code_sdk_elixir.git"},
      {:nimble_options, "~> 1.1"},
      {:ecto, "~> 3.12"},

      # Code quality and analysis tools
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Documentation
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
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
      maintainers: ["NSHkr <ZeroTrust@NSHkr.com>"],
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md
                docs/20250704_yaml_format_v2
                docs/architecture
                docs/guides
                docs/patterns
                docs/specifications
                docs/visual_editor
                docs/visual_editor_v2
                docs/schema_validation.md
                ADVANCED_FEATURES.md
                IMPLEMENTATION_CHECKLIST.md
                IMPLEMENTATION_SUMMARY.md
                PIPELINE_CONFIG_GUIDE.md
                PROMPT_SYSTEM_GUIDE.md
                RECURSIVE_PIPELINES_GUIDE.md
                TESTING_ARCHITECTURE.md
                USE_CASES.md
                USE_CASES_2.md),
      exclude_patterns: ["priv/plts/*"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v0.0.1",
      source_url: "https://github.com/nshkrdotcom/pipeline_ex",
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1,
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"],
        "ADVANCED_FEATURES.md": [title: "Advanced Features"],
        "PIPELINE_CONFIG_GUIDE.md": [title: "Pipeline Configuration"],
        "PROMPT_SYSTEM_GUIDE.md": [title: "Prompt System"],
        "RECURSIVE_PIPELINES_GUIDE.md": [title: "Recursive Pipelines"],
        "USE_CASES.md": [title: "Use Cases"],
        "USE_CASES_2.md": [title: "More Use Cases"],
        "TESTING_ARCHITECTURE.md": [title: "Testing Architecture"],
        "docs/20250704_yaml_format_v2/index.md": [title: "YAML Format v2"],
        "docs/20250704_yaml_format_v2/01_complete_schema_reference.md": [
          title: "Schema Reference"
        ],
        "docs/20250704_yaml_format_v2/02_step_types_reference.md": [title: "Step Types"],
        "docs/20250704_yaml_format_v2/03_prompt_system_reference.md": [
          title: "Prompt System Reference"
        ],
        "docs/20250704_yaml_format_v2/04_control_flow_logic.md": [title: "Control Flow"],
        "docs/20250704_yaml_format_v2/05_pipeline_composition.md": [title: "Pipeline Composition"],
        "docs/20250704_yaml_format_v2/06_advanced_features.md": [title: "Advanced YAML Features"],
        "docs/20250704_yaml_format_v2/08_best_practices_patterns.md": [title: "Best Practices"],
        "docs/20250704_yaml_format_v2/10_quick_reference.md": [title: "Quick Reference"],
        "docs/architecture/pipeline_organization.md": [title: "Pipeline Organization"],
        "docs/architecture/META_PIPELINE_SYSTEM.md": [title: "Meta Pipeline System"],
        "docs/architecture/pipeline_flow_diagrams.md": [title: "Pipeline Flow Diagrams"],
        "docs/guides/context_management.md": [title: "Context Management"],
        "docs/guides/safety_features.md": [title: "Safety Features"],
        "docs/specifications/code_generation_pipelines.md": [title: "Code Generation Pipelines"],
        "docs/specifications/data_processing_pipelines.md": [title: "Data Processing Pipelines"],
        "docs/specifications/model_development_pipelines.md": [
          title: "Model Development Pipelines"
        ]
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

  defp before_closing_head_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;

      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }

        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            graphEl.innerHTML = svg;
            bindFunctions?.(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp before_closing_body_tag(:html), do: ""

  defp before_closing_body_tag(:epub), do: ""

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
