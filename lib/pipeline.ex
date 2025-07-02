defmodule Pipeline do
  @moduledoc """
  AI pipeline orchestration library for Elixir.

  Pipeline provides a robust framework for chaining AI provider calls (Claude, Gemini)
  with advanced features like fault tolerance, session management, and self-improving
  Genesis pipelines.

  ## Quick Start

      # Load and execute a pipeline
      {:ok, config} = Pipeline.load_workflow("my_pipeline.yaml")
      {:ok, results} = Pipeline.execute(config)

      # Execute with custom options
      {:ok, results} = Pipeline.execute(config,
        workspace_dir: "/tmp/pipeline_workspace",
        debug: true
      )

  ## Configuration

  Pipelines can be configured via:

  - Function options: `Pipeline.execute(config, workspace_dir: "/custom/path")`
  - Environment variables: `PIPELINE_WORKSPACE_DIR`, `PIPELINE_OUTPUT_DIR`, etc.
  - YAML configuration: workspace_dir, output_dir settings in the pipeline file

  See `Pipeline.Executor` and `Pipeline.Config` for detailed documentation.
  """

  alias Pipeline.{Config, Executor}

  @doc """
  Load a workflow configuration from a YAML file.

  ## Examples

      {:ok, config} = Pipeline.load_workflow("examples/simple_workflow.yaml")
      {:ok, config} = Pipeline.load_workflow("/path/to/my_pipeline.yaml")

  """
  @spec load_workflow(String.t()) :: {:ok, map()} | {:error, String.t()}
  defdelegate load_workflow(path), to: Config

  @doc """
  Execute a pipeline workflow.

  ## Parameters

  - `workflow` - Pipeline configuration map (from `load_workflow/1`)
  - `opts` - Execution options (optional)

  ## Options

  - `:workspace_dir` - Directory for AI workspace operations (default: "./workspace")
  - `:output_dir` - Directory for saving pipeline outputs (default: "./outputs") 
  - `:checkpoint_dir` - Directory for saving execution checkpoints (default: "./checkpoints")
  - `:debug` - Enable debug logging (default: false)

  ## Examples

      # Basic execution
      {:ok, results} = Pipeline.execute(config)

      # With custom directories
      {:ok, results} = Pipeline.execute(config,
        workspace_dir: "/tmp/ai_workspace",
        output_dir: "/app/pipeline_outputs"
      )

      # With debug logging
      {:ok, results} = Pipeline.execute(config, debug: true)

  ## Returns

  - `{:ok, results}` - Map of step results keyed by step name
  - `{:error, reason}` - Execution failure with error details

  """
  @spec execute(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  defdelegate execute(workflow, opts \\ []), to: Executor

  @doc """
  Execute a single pipeline step for testing or debugging.

  ## Examples

      step = %{"name" => "analyze", "type" => "claude", "prompt" => "Analyze this code"}
      context = %{workspace_dir: "/tmp", results: %{}}
      {:ok, result} = Pipeline.execute_step(step, context)

  """
  @spec execute_step(map(), map()) :: {:ok, map()} | {:error, String.t()}
  defdelegate execute_step(step, context), to: Executor

  @doc """
  Load and execute a workflow in one call.

  Convenience function that combines `load_workflow/1` and `execute/2`.

  ## Examples

      {:ok, results} = Pipeline.run("my_pipeline.yaml")
      {:ok, results} = Pipeline.run("my_pipeline.yaml", debug: true)

  """
  @spec run(String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def run(workflow_path, opts \\ []) do
    case load_workflow(workflow_path) do
      {:ok, config} -> execute(config, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the current pipeline configuration.

  Returns application-level configuration including default directories,
  test mode, and debug settings.

  ## Examples

      config = Pipeline.get_config()
      IO.inspect(config.workspace_dir)

  """
  @spec get_config() :: %{atom() => any()}
  defdelegate get_config(), to: Config, as: :get_app_config

  @doc """
  Check if the pipeline system is properly configured.

  Validates that required dependencies and configurations are available.

  ## Examples

      case Pipeline.health_check() do
        :ok -> IO.puts("Pipeline system ready")
        {:error, _problems} -> IO.puts("Configuration issues found")
      end

  """
  @spec health_check() :: :ok | {:error, [String.t()]}
  def health_check do
    issues = []

    # Check for required environment setup
    issues =
      if System.get_env("GEMINI_API_KEY") || Pipeline.TestMode.mock_mode?() do
        issues
      else
        ["GEMINI_API_KEY not set and not in mock mode" | issues]
      end

    # Check Claude Code SDK availability (only in live mode)
    issues =
      if Pipeline.TestMode.live_mode?() do
        try do
          case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
            {_, 0} -> issues
            _ -> ["Claude CLI not available for live mode" | issues]
          end
        rescue
          ErlangError -> ["Claude CLI not available for live mode" | issues]
        end
      else
        issues
      end

    # Check directory permissions for default paths
    config = get_config()

    issues =
      [config.workspace_dir, config.output_dir, config.checkpoint_dir]
      |> Enum.reduce(issues, fn dir, acc ->
        case File.mkdir_p(dir) do
          :ok -> acc
          {:error, reason} -> ["Cannot create directory #{dir}: #{reason}" | acc]
        end
      end)

    case issues do
      [] -> :ok
      issue_list -> {:error, Enum.reverse(issue_list)}
    end
  end
end
