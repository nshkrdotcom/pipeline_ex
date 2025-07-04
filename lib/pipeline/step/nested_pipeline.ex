defmodule Pipeline.Step.NestedPipeline do
  @moduledoc """
  Executes another pipeline as a step within the current pipeline.

  This enables pipeline composition where complex workflows can be built
  from smaller, reusable pipeline components.
  """

  require Logger
  alias Pipeline.{Config, Executor}
  alias Pipeline.Context.Nested
  alias Pipeline.Safety.SafetyManager

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
         {:ok, safety_context} <- create_safety_context(pipeline, nested_context, resolved_step),
         :ok <- perform_safety_checks(pipeline, safety_context, resolved_step),
         {:ok, pipeline_results} <-
           execute_pipeline_safely(pipeline, nested_context, resolved_step, safety_context),
         {:ok, extracted_outputs} <-
           Nested.extract_outputs(pipeline_results, resolved_step["outputs"]) do
      # Clean up resources
      cleanup_safety_context(safety_context, resolved_step)

      Logger.info("✅ Nested pipeline completed: #{step["name"]}")
      {:ok, extracted_outputs}
    else
      {:error, reason} = error ->
        Logger.error("❌ Nested pipeline failed: #{step["name"]} - #{reason}")

        # Clean up on error if safety context was created
        case context[:safety_context] do
          nil -> :ok
          safety_ctx -> cleanup_safety_context(safety_ctx, resolved_step)
        end

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

  # Create safety context for nested pipeline execution
  defp create_safety_context(pipeline, nested_context, step) do
    pipeline_name = get_in(pipeline, ["workflow", "name"]) || "unnamed_nested_pipeline"
    step_count = length(get_in(pipeline, ["workflow", "steps"]) || [])

    # Extract safety configuration from step config
    step_config = step["config"] || %{}
    safety_config = extract_safety_config(step_config)

    # Create execution context for safety tracking  
    # The parent safety context comes from the nested_context if it has one,
    # otherwise this is a root level nested pipeline
    parent_safety_context = Map.get(nested_context, :safety_context)

    safety_context =
      SafetyManager.create_safe_context(
        pipeline_name,
        parent_safety_context,
        step_count,
        safety_config
      )

    {:ok, safety_context}
  end

  # Perform all safety checks before execution
  defp perform_safety_checks(pipeline, safety_context, step) do
    pipeline_name = get_in(pipeline, ["workflow", "name"]) || "unnamed_nested_pipeline"
    step_config = step["config"] || %{}
    safety_config = extract_safety_config(step_config)

    # For root-level nested pipelines (no parent context), skip circular dependency check
    # since they can't be circular by definition
    case safety_context.parent_context do
      nil ->
        # Only check resource limits for root-level pipelines
        resource_limits = %{
          memory_limit_mb: Map.get(safety_config, :memory_limit_mb, 1024),
          timeout_seconds: Map.get(safety_config, :timeout_seconds, 300)
        }

        case Pipeline.Safety.ResourceMonitor.monitor_execution(
               safety_context.start_time,
               resource_limits
             ) do
          :ok -> :ok
          {:error, message} -> {:error, message}
        end

      _parent ->
        # For nested pipelines, do full safety checks
        case SafetyManager.check_safety(pipeline_name, safety_context, safety_config) do
          :ok ->
            :ok

          {:error, message} ->
            formatted_error =
              SafetyManager.handle_safety_violation(message, safety_context, safety_config)

            {:error, formatted_error}
        end
    end
  end

  # Execute the nested pipeline with safety monitoring
  defp execute_pipeline_safely(pipeline, nested_context, step, safety_context) do
    pipeline_name = get_in(pipeline, ["workflow", "name"]) || "unnamed_nested_pipeline"
    step_config = step["config"] || %{}
    safety_config = extract_safety_config(step_config)

    Logger.info(
      "🚀 Starting nested pipeline execution: #{pipeline_name} (depth: #{safety_context.nesting_depth})"
    )

    # Pre-resolve any input templates in the pipeline definition
    inputs = Map.get(nested_context, :inputs, %{})
    enhanced_pipeline = resolve_pipeline_inputs(pipeline, inputs)

    # Monitor execution with periodic safety checks
    execution_start = DateTime.utc_now()

    # Execute the pipeline using the main Executor
    result =
      case Executor.execute(enhanced_pipeline, enable_monitoring: false) do
        {:ok, results} ->
          # Perform final safety check
          case SafetyManager.monitor_execution(safety_context, safety_config) do
            :ok ->
              {:ok, results}

            {:error, safety_error} ->
              {:error, "Safety violation during execution: #{safety_error}"}
          end

        {:error, reason} ->
          {:error, "Nested pipeline '#{pipeline_name}' failed: #{reason}"}
      end

    # Log execution metrics
    execution_time = DateTime.diff(DateTime.utc_now(), execution_start, :millisecond)
    Logger.info("⏱️ Nested pipeline '#{pipeline_name}' executed in #{execution_time}ms")

    result
  end

  # Clean up safety context and resources
  defp cleanup_safety_context(safety_context, step) do
    step_config = step["config"] || %{}
    safety_config = extract_safety_config(step_config)

    _ = SafetyManager.cleanup_execution(safety_context, safety_config)
    Logger.debug("🧹 Cleaned up safety context for nested pipeline")
  end

  # Extract safety configuration from step config
  defp extract_safety_config(step_config) do
    config = SafetyManager.default_config()

    # Override with step-specific configuration
    config
    |> put_if_present(:max_depth, step_config["max_depth"])
    |> put_if_present(:memory_limit_mb, step_config["memory_limit_mb"])
    |> put_if_present(:timeout_seconds, step_config["timeout_seconds"])
    |> put_if_present(:workspace_enabled, step_config["workspace_enabled"])
    |> put_if_present(:cleanup_on_error, step_config["cleanup_on_error"])
  end

  # Helper to conditionally put values in map
  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

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
