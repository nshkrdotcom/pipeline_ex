defmodule Pipeline.Step.NestedPipeline do
  @moduledoc """
  Executes another pipeline as a step within the current pipeline.

  This enables pipeline composition where complex workflows can be built
  from smaller, reusable pipeline components.
  """

  require Logger
  alias Pipeline.{Config, Executor}

  @doc """
  Execute a nested pipeline step.

  Supports three ways to specify the pipeline:
  - pipeline_file: Path to external YAML file
  - pipeline_ref: Reference to registered pipeline (future feature)
  - pipeline: Inline pipeline definition
  """
  def execute(step, context) do
    Logger.info("🔄 Executing nested pipeline step: #{step["name"]}")

    with {:ok, pipeline} <- load_pipeline(step),
         {:ok, nested_context} <- create_nested_context(context, step),
         {:ok, result} <- execute_pipeline(pipeline, nested_context, step) do
      Logger.info("✅ Nested pipeline completed: #{step["name"]}")
      {:ok, result}
    else
      {:error, reason} = error ->
        Logger.error("❌ Nested pipeline failed: #{step["name"]} - #{reason}")
        error
    end
  end

  # Load the pipeline from various sources
  defp load_pipeline(step) do
    cond do
      # External pipeline file
      step["pipeline_file"] ->
        load_from_file(step["pipeline_file"])

      # Inline pipeline definition
      step["pipeline"] ->
        validate_inline_pipeline(step["pipeline"])

      # Pipeline registry reference (future feature)
      step["pipeline_ref"] ->
        {:error, "Pipeline registry not yet implemented"}

      true ->
        {:error, "No pipeline source specified. Use 'pipeline_file' or 'pipeline' key."}
    end
  end

  # Load pipeline from external YAML file
  defp load_from_file(file_path) do
    Logger.debug("Loading nested pipeline from file: #{file_path}")

    case Config.load_workflow(file_path) do
      {:ok, pipeline} ->
        {:ok, pipeline}

      {:error, reason} ->
        {:error, "Failed to load pipeline file '#{file_path}': #{reason}"}
    end
  end

  # Validate inline pipeline definition
  defp validate_inline_pipeline(pipeline_def) do
    Logger.debug("Using inline pipeline definition")

    # Wrap inline definition in workflow structure if needed
    wrapped_pipeline =
      case pipeline_def do
        %{"workflow" => _} -> pipeline_def
        _ -> %{"workflow" => pipeline_def}
      end

    # Basic validation
    if is_map(wrapped_pipeline["workflow"]) && is_list(wrapped_pipeline["workflow"]["steps"]) do
      {:ok, wrapped_pipeline}
    else
      {:error, "Invalid inline pipeline format. Must include 'steps' array."}
    end
  end

  # Create a nested execution context
  defp create_nested_context(parent_context, step) do
    # For Phase 1, we create a basic nested context
    # Phase 2 will add input mapping and context inheritance

    nested_context =
      parent_context
      # Start with fresh results
      |> Map.put(:results, %{})
      # Reset step counter
      |> Map.put(:step_index, 0)
      # New execution log
      |> Map.put(:execution_log, [])
      |> Map.put(:nesting_depth, Map.get(parent_context, :nesting_depth, 0) + 1)

    # Track the pipeline source for debugging
    nested_context = Map.put(nested_context, :pipeline_source, get_pipeline_source(step))

    {:ok, nested_context}
  end

  # Execute the nested pipeline
  defp execute_pipeline(pipeline, nested_context, _step) do
    pipeline_name = get_in(pipeline, ["workflow", "name"]) || "unnamed_nested_pipeline"

    Logger.info(
      "🚀 Starting nested pipeline execution: #{pipeline_name} (depth: #{nested_context.nesting_depth})"
    )

    # Execute the pipeline using the main Executor
    # We pass the full pipeline structure, not just the workflow part
    case Executor.execute(pipeline, enable_monitoring: false) do
      {:ok, results} ->
        # For Phase 1, return all results from the nested pipeline
        # Phase 2 will add output extraction
        {:ok, results}

      {:error, reason} ->
        {:error, "Nested pipeline '#{pipeline_name}' failed: #{reason}"}
    end
  end

  # Helper to identify pipeline source for debugging
  defp get_pipeline_source(step) do
    cond do
      step["pipeline_file"] -> {:file, step["pipeline_file"]}
      step["pipeline"] -> :inline
      step["pipeline_ref"] -> {:ref, step["pipeline_ref"]}
      true -> :unknown
    end
  end
end
