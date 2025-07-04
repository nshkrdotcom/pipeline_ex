defmodule Pipeline.Step.NestedPipeline do
  @moduledoc """
  Executes another pipeline as a step within the current pipeline.

  This enables pipeline composition where complex workflows can be built
  from smaller, reusable pipeline components.
  """

  require Logger
  alias Pipeline.{Config, Executor}
  alias Pipeline.Context.Nested

  @doc """
  Execute a nested pipeline step.

  Supports three ways to specify the pipeline:
  - pipeline_file: Path to external YAML file
  - pipeline_ref: Reference to registered pipeline (future feature)
  - pipeline: Inline pipeline definition
  """
  def execute(step, context) do
    Logger.info("🔄 Executing nested pipeline step: #{step["name"]}")

    # Resolve templates in step configuration before processing
    resolved_step = resolve_step_templates_with_context(step, context)

    with {:ok, pipeline} <- load_pipeline(resolved_step),
         {:ok, nested_context} <- Nested.create_nested_context(context, resolved_step),
         {:ok, pipeline_results} <- execute_pipeline(pipeline, nested_context, resolved_step),
         {:ok, extracted_outputs} <-
           Nested.extract_outputs(pipeline_results, resolved_step["outputs"]) do
      Logger.info("✅ Nested pipeline completed: #{step["name"]}")
      {:ok, extracted_outputs}
    else
      {:error, reason} = error ->
        Logger.error("❌ Nested pipeline failed: #{step["name"]} - #{reason}")
        error
    end
  end

  # Resolve templates in step configuration using pipeline context
  defp resolve_step_templates_with_context(step, context) do
    require Logger
    Logger.debug("Original step inputs: #{inspect(step["inputs"])}")

    # Use the same template resolution as Context.Nested but with the full pipeline context
    resolved = resolve_data_templates_with_context(step, context)

    Logger.debug("Resolved step inputs: #{inspect(resolved["inputs"])}")
    resolved
  end

  # Recursively resolve templates using pipeline context
  defp resolve_data_templates_with_context(data, context) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, resolve_data_templates_with_context(v, context)} end)
    |> Map.new()
  end

  defp resolve_data_templates_with_context(data, context) when is_list(data) do
    Enum.map(data, &resolve_data_templates_with_context(&1, context))
  end

  defp resolve_data_templates_with_context(data, context) when is_binary(data) do
    # Use the Context.Nested template resolution which understands pipeline patterns
    Nested.resolve_template(data, context)
  end

  defp resolve_data_templates_with_context(data, _context), do: data

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

  # Execute the nested pipeline
  defp execute_pipeline(pipeline, nested_context, _step) do
    pipeline_name = get_in(pipeline, ["workflow", "name"]) || "unnamed_nested_pipeline"

    Logger.info(
      "🚀 Starting nested pipeline execution: #{pipeline_name} (depth: #{nested_context.nesting_depth})"
    )

    # For Phase 2, we'll use the standard executor but resolve inputs in step templates
    # This is simpler and more reliable than trying to customize the executor
    inputs = Map.get(nested_context, :inputs, %{})

    # Pre-resolve any input templates in the pipeline definition
    enhanced_pipeline = resolve_pipeline_inputs(pipeline, inputs)

    # Execute the pipeline using the main Executor
    case Executor.execute(enhanced_pipeline, enable_monitoring: false) do
      {:ok, results} ->
        {:ok, results}

      {:error, reason} ->
        {:error, "Nested pipeline '#{pipeline_name}' failed: #{reason}"}
    end
  end

  # Pre-resolve input templates in the pipeline definition
  defp resolve_pipeline_inputs(pipeline, inputs) do
    # Create a simple context for template resolution
    simple_context = %{inputs: inputs}

    # Resolve templates in the entire pipeline structure
    resolve_data_templates(pipeline, simple_context)
  end

  # Recursively resolve templates in any data structure
  defp resolve_data_templates(data, context) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, resolve_data_templates(v, context)} end)
    |> Map.new()
  end

  defp resolve_data_templates(data, context) when is_list(data) do
    Enum.map(data, &resolve_data_templates(&1, context))
  end

  defp resolve_data_templates(data, context) when is_binary(data) do
    # Only resolve input templates to avoid interfering with other template types
    if String.contains?(data, "{{inputs.") do
      resolve_input_templates(data, context)
    else
      data
    end
  end

  defp resolve_data_templates(data, _context), do: data

  # Resolve only input templates
  defp resolve_input_templates(text, context) do
    # Only replace {{inputs.xxx}} patterns
    Regex.replace(~r/\{\{inputs\.([^}]+)\}\}/, text, fn _, input_key ->
      case get_in(context, [:inputs, input_key]) do
        # Keep original if not found
        nil -> "{{inputs.#{input_key}}}"
        value -> to_string(value)
      end
    end)
  end
end
