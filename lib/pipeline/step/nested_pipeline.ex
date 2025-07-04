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
         {:ok, enhanced_nested_context} <- add_parent_safety_context(nested_context, context),
         {:ok, safety_context} <-
           create_safety_context(pipeline, enhanced_nested_context, resolved_step),
         :ok <- perform_safety_checks(pipeline, safety_context, resolved_step),
         {:ok, pipeline_results} <-
           execute_pipeline_safely(
             pipeline,
             enhanced_nested_context,
             resolved_step,
             safety_context
           ),
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

    # Only resolve templates in the inputs field, not in the nested pipeline definition
    # The nested pipeline's steps should be resolved by its own executor
    resolved =
      if step["inputs"] do
        resolved_inputs = resolve_data_templates_with_context(step["inputs"], context)
        Map.put(step, "inputs", resolved_inputs)
      else
        step
      end

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

  # Add parent safety context to nested context
  defp add_parent_safety_context(nested_context, parent_context) do
    parent_safety_context = Map.get(parent_context, :safety_context)
    enhanced_context = Map.put(nested_context, :safety_context, parent_safety_context)
    {:ok, enhanced_context}
  end

  # Create parent safety context from nested context information
  defp create_parent_safety_context(nested_context) do
    case Map.get(nested_context, :parent_context) do
      nil ->
        # No parent context, this is a root level nested pipeline
        nil

      parent_ctx ->
        parent_pipeline_name =
          Map.get(parent_ctx, :workflow_name) ||
            Map.get(parent_ctx, :pipeline_name) ||
            "parent_pipeline"

        # Check if we have a stored safety context for the parent pipeline
        case Process.get({:safety_context, parent_pipeline_name}) do
          nil ->
            # Parent doesn't have a safety context, create a basic one
            # This is for when a regular pipeline calls a nested pipeline
            # Try to get the step count from the parent context
            parent_step_count = Map.get(parent_ctx, :total_steps, 0)

            %{
              # Parent is the root pipeline 
              nesting_depth: 0,
              pipeline_id: parent_pipeline_name,
              parent_context: nil,
              step_count: parent_step_count,
              start_time: DateTime.utc_now(),
              workspace_dir: nil
            }

          existing_safety_context ->
            # Use the existing parent safety context 
            existing_safety_context
        end
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

  # Create safety context for nested pipeline execution
  defp create_safety_context(pipeline, nested_context, step) do
    pipeline_name = get_in(pipeline, ["workflow", "name"]) || "unnamed_nested_pipeline"
    step_count = length(get_in(pipeline, ["workflow", "steps"]) || [])

    # Extract safety configuration from step config
    step_config = step["config"] || %{}
    safety_config = extract_safety_config(step_config)

    # Create parent safety context from the nested context's parent information
    parent_safety_context = create_parent_safety_context(nested_context)

    # Track cumulative step count across nested pipeline executions
    parent_pipeline_name = Map.get(nested_context, :pipeline_name, "parent_pipeline")
    cumulative_key = {:cumulative_steps, parent_pipeline_name}
    current_cumulative = Process.get(cumulative_key, 0)
    new_cumulative = current_cumulative + step_count
    Process.put(cumulative_key, new_cumulative)

    # Use cumulative step count for safety context if parent context exists
    effective_step_count =
      if parent_safety_context do
        new_cumulative
      else
        step_count
      end

    safety_context =
      SafetyManager.create_safe_context(
        pipeline_name,
        parent_safety_context,
        effective_step_count,
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
    # since they can't be circular by definition, but still check step count limits
    case safety_context.parent_context do
      nil ->
        # Check resource limits AND step count limits for root-level pipelines
        resource_limits = %{
          memory_limit_mb: Map.get(safety_config, :memory_limit_mb, 1024),
          timeout_seconds: Map.get(safety_config, :timeout_seconds, 300)
        }

        with :ok <-
               Pipeline.Safety.ResourceMonitor.monitor_execution(
                 safety_context.start_time,
                 resource_limits
               ),
             :ok <- check_limits_for_current(safety_context, safety_config) do
          :ok
        else
          {:error, message} ->
            formatted_error =
              SafetyManager.handle_safety_violation(message, safety_context, safety_config)

            {:error, formatted_error}
        end

      _parent ->
        # For nested pipelines, check circular dependency against parent context,
        # then check other limits against current context

        # Inline circular dependency check to avoid dialyzer warning
        circular_check_result =
          case safety_context.parent_context do
            nil ->
              :ok

            parent_ctx ->
              # Ensure parent_context has the right structure for RecursionGuard
              safe_parent = %{
                nesting_depth: Map.get(parent_ctx, :nesting_depth, 0),
                pipeline_id: Map.get(parent_ctx, :pipeline_id, "unknown"),
                parent_context: Map.get(parent_ctx, :parent_context),
                step_count: Map.get(parent_ctx, :step_count, 0)
              }

              Pipeline.Safety.RecursionGuard.check_circular_dependency(pipeline_name, safe_parent)
          end

        with :ok <- circular_check_result,
             :ok <- check_limits_for_current(safety_context, safety_config) do
          :ok
        else
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

    # Get inputs from nested context to pass to the executor
    inputs = Map.get(nested_context, :inputs, %{})
    # Get global_vars if context was inherited
    global_vars = Map.get(nested_context, :global_vars, %{})

    # Add global_vars to the pipeline workflow if they were inherited and not empty
    enhanced_pipeline =
      if map_size(global_vars) > 0 do
        put_in(pipeline, ["workflow", "global_vars"], global_vars)
      else
        pipeline
      end

    # Store the safety context in a global registry so it can be accessed by child pipelines
    # This is a simple approach: store it in the process dictionary for this pipeline execution
    Process.put({:safety_context, pipeline_name}, safety_context)

    # Monitor execution with periodic safety checks
    execution_start = DateTime.utc_now()

    # Execute the pipeline using the main Executor, passing the inputs
    execution_opts = [
      enable_monitoring: false,
      inputs: inputs
    ]

    result =
      case Executor.execute(enhanced_pipeline, execution_opts) do
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
    |> put_if_present(:max_total_steps, step_config["max_total_steps"])
    |> put_if_present(:memory_limit_mb, step_config["memory_limit_mb"])
    |> put_if_present(:timeout_seconds, step_config["timeout_seconds"])
    |> put_if_present(:workspace_enabled, step_config["workspace_enabled"])
    |> put_if_present(:cleanup_on_error, step_config["cleanup_on_error"])
  end

  # Helper to conditionally put values in map
  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  # Check resource limits for current context only
  defp check_limits_for_current(safety_context, safety_config) do
    alias Pipeline.Safety.RecursionGuard

    recursion_limits = %{
      max_depth: Map.get(safety_config, :max_depth, 10),
      max_total_steps: Map.get(safety_config, :max_total_steps, 1000)
    }

    # Ensure safety_context has the right structure for RecursionGuard
    safe_context = %{
      nesting_depth: Map.get(safety_context, :nesting_depth, 0),
      pipeline_id: Map.get(safety_context, :pipeline_id, "unknown"),
      parent_context: Map.get(safety_context, :parent_context),
      step_count: Map.get(safety_context, :step_count, 0)
    }

    case RecursionGuard.check_limits(safe_context, recursion_limits) do
      :ok -> :ok
      {:error, message} -> {:error, message}
    end
  end
end
