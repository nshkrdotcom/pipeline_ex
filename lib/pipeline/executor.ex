defmodule Pipeline.Executor do
  @moduledoc """
  Main pipeline execution engine.

  Orchestrates the execution of workflow steps, manages state,
  and coordinates between Brain (Gemini) and Muscle (Claude) operations.
  """

  require Logger
  alias Pipeline.CheckpointManager
  alias Pipeline.Condition.Engine, as: ConditionEngine
  alias Pipeline.Step.{Claude, Gemini, GeminiInstructor, ParallelClaude}
  alias Pipeline.Step.{ClaudeBatch, ClaudeExtract, ClaudeRobust, ClaudeSession, ClaudeSmart, Loop}
  alias Pipeline.Step.{DataTransform, FileOps, SetVariable, NestedPipeline, TestEcho}
  alias Pipeline.Streaming.{ResultStream, AsyncResponse}
  alias Pipeline.Monitoring.Performance
  alias Pipeline.State.VariableEngine

  @type workflow :: map()
  @type execution_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Execute a complete workflow.

  Takes a workflow configuration and executes all steps in sequence,
  managing state and checkpoints along the way.
  """
  @spec execute(workflow, keyword()) :: execution_result
  def execute(workflow, opts \\ []) do
    pipeline_name = workflow["workflow"]["name"]
    Logger.info("🚀 Starting pipeline execution: #{pipeline_name}")

    # Initialize execution context
    context = initialize_context(workflow, opts)

    # Start performance monitoring if enabled
    monitoring_enabled = Keyword.get(opts, :enable_monitoring, true)

    if monitoring_enabled do
      case Performance.start_monitoring(pipeline_name, opts) do
        {:ok, _pid} ->
          Logger.debug("📊 Performance monitoring started for: #{pipeline_name}")

        {:error, {:already_started, _pid}} ->
          Logger.debug("📊 Performance monitoring already running for: #{pipeline_name}")

        {:error, reason} ->
          Logger.warning("⚠️  Failed to start performance monitoring: #{inspect(reason)}")
      end
    end

    # Load checkpoint if enabled and exists
    context = maybe_load_checkpoint(context)

    try do
      # Execute steps
      case execute_steps(workflow["workflow"]["steps"], context) do
        {:ok, final_context} ->
          log_pipeline_completion(final_context)

          # Stop performance monitoring and log metrics
          if monitoring_enabled do
            case Performance.stop_monitoring(pipeline_name) do
              {:ok, final_metrics} ->
                log_performance_summary(final_metrics)

              {:error, _} ->
                Logger.debug("Performance monitoring already stopped")
            end
          end

          {:ok, final_context.results}

        {:error, reason} = error ->
          Logger.error("❌ Pipeline execution failed: #{reason}")
          cleanup_context(context)

          # Stop monitoring on error
          if monitoring_enabled do
            case Performance.stop_monitoring(pipeline_name) do
              {:ok, _metrics} ->
                :ok

              # Already stopped
              {:error, :not_found} ->
                :ok

              {:error, reason} ->
                Logger.warning("Failed to stop monitoring: #{inspect(reason)}")
            end
          end

          error
      end
    rescue
      error ->
        workflow_name = workflow["workflow"]["name"] || "unnamed"
        step_count = length(workflow["workflow"]["steps"] || [])
        current_step = context.step_index + 1

        Logger.error(
          "💥 Pipeline '#{workflow_name}' crashed at step #{current_step}/#{step_count}: #{inspect(error)}"
        )

        cleanup_context(context)

        error_message = """
        Pipeline execution crashed: #{Exception.message(error)}
        Workflow: #{workflow_name}
        Step: #{current_step}/#{step_count}
        Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}
        """

        {:error, error_message}
    end
  end

  @doc """
  Execute a single step for testing.
  """
  @spec execute_step(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def execute_step(step, context) do
    case do_execute_step(step, context) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions

  defp initialize_context(workflow, opts) do
    config = workflow["workflow"]
    pipeline_name = config["name"]

    # Create directories with configurable defaults
    workspace_dir =
      Path.expand(
        Keyword.get(opts, :workspace_dir) ||
          config["workspace_dir"] ||
          System.get_env("PIPELINE_WORKSPACE_DIR") ||
          "./workspace"
      )

    output_dir =
      Path.expand(
        Keyword.get(opts, :output_dir) ||
          get_in(config, ["defaults", "output_dir"]) ||
          System.get_env("PIPELINE_OUTPUT_DIR") ||
          "./outputs"
      )

    checkpoint_dir =
      Path.expand(
        Keyword.get(opts, :checkpoint_dir) ||
          config["checkpoint_dir"] ||
          System.get_env("PIPELINE_CHECKPOINT_DIR") ||
          "./checkpoints"
      )

    File.mkdir_p!(workspace_dir)
    File.mkdir_p!(output_dir)
    File.mkdir_p!(checkpoint_dir)

    # Add inputs to context if provided
    base_context = %{
      workflow_name: config["name"],
      workspace_dir: workspace_dir,
      output_dir: output_dir,
      checkpoint_dir: checkpoint_dir,
      variable_state: VariableEngine.new_state(),
      checkpoint_enabled: config["checkpoint_enabled"] || false,
      results: %{},
      execution_log: [],
      start_time: DateTime.utc_now(),
      step_index: 0,
      debug_enabled: Keyword.get(opts, :debug, false),
      # Add full config for enhanced step types
      config: workflow,
      # Add pipeline name for performance monitoring
      pipeline_name: pipeline_name
    }

    # Add global vars from workflow config
    context_with_global_vars =
      case config["global_vars"] do
        nil ->
          base_context

        global_vars ->
          Map.put(base_context, :global_vars, global_vars)
      end

    # Add inputs to context if provided (for nested pipeline execution)
    case Keyword.get(opts, :inputs) do
      nil ->
        context_with_global_vars

      inputs ->
        Map.put(context_with_global_vars, :inputs, inputs)
    end
  end

  defp maybe_load_checkpoint(context) do
    if context.checkpoint_enabled do
      case CheckpointManager.load_latest(context.checkpoint_dir, context.workflow_name) do
        {:ok, checkpoint_data} ->
          Logger.info("📦 Loaded checkpoint from #{checkpoint_data.timestamp}")

          %{
            context
            | results: checkpoint_data.results,
              step_index: checkpoint_data.step_index,
              execution_log: checkpoint_data.execution_log,
              variable_state: checkpoint_data.variable_state
          }

        {:error, _reason} ->
          Logger.info("📦 No checkpoint found, starting fresh")
          context
      end
    else
      context
    end
  end

  defp execute_steps(steps, context) do
    steps
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, context}, &execute_single_step/2)
  end

  defp execute_single_step({step, index}, {:ok, ctx}) do
    if should_skip_step?(index, ctx) do
      log_skipped_step(step, index)
      {:cont, {:ok, ctx}}
    else
      execute_step_and_handle_result(step, index, ctx)
    end
  end

  defp should_skip_step?(index, ctx), do: index < ctx.step_index

  defp log_skipped_step(step, index) do
    Logger.info("⏭️  Skipping step #{index + 1}: #{step["name"]} (already completed)")
  end

  defp execute_step_and_handle_result(step, index, ctx) do
    case execute_step_with_checkpoint(step, index, ctx) do
      {:ok, updated_ctx} -> {:cont, {:ok, updated_ctx}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp execute_step_with_checkpoint(step, index, context) do
    Logger.info("🎯 Executing step #{index + 1}: #{step["name"]} (#{step["type"]})")

    # Notify performance monitoring
    pipeline_name = context[:pipeline_name] || "unknown"
    Performance.step_started(pipeline_name, step["name"], step["type"])

    # Interpolate variables in step configuration
    interpolated_step = interpolate_step_variables(step, context)

    # Update variable state with current step info
    updated_context = update_variable_step_info(context, step["name"], index)

    # Resolve any async results that might be referenced by this step
    context_with_resolved_results =
      resolve_async_results_before_execution(updated_context, interpolated_step)

    # Check if step should be executed based on condition
    if should_execute_step?(interpolated_step, context_with_resolved_results) do
      Logger.info("✅ Condition met, executing step: #{step["name"]}")
      execute_step_unconditionally(interpolated_step, index, context_with_resolved_results)
    else
      Logger.info("⏭️  Condition not met, skipping step: #{step["name"]}")

      # Create a skipped result
      skipped_result_content = %{
        "success" => true,
        "skipped" => true,
        "reason" => "Condition not met: #{step["condition"] || "N/A"}"
      }

      # Wrap in result structure for consistency for nested pipeline steps with inputs
      final_skipped_result =
        if step["type"] == "pipeline" && has_inputs?(step) do
          # Nested pipeline step with inputs: wrap in "result" key for template support
          %{"result" => skipped_result_content}
        else
          # Regular step or nested pipeline without inputs: use result directly for backward compatibility
          skipped_result_content
        end

      updated_context = %{
        context
        | results: Map.put(context.results, step["name"], final_skipped_result),
          step_index: index + 1,
          execution_log: [
            %{
              step: step["name"],
              type: step["type"],
              status: :skipped,
              condition: step["condition"],
              timestamp: DateTime.utc_now()
            }
            | context.execution_log
          ]
      }

      {:ok, updated_context}
    end
  end

  defp execute_step_unconditionally(step, index, context) do
    step_start = DateTime.utc_now()

    case do_execute_step(step, context) do
      {:ok, result} ->
        handle_step_success(step, index, context, result, step_start)

      {:ok, result, updated_context} ->
        handle_step_success_with_context(step, index, updated_context, result, step_start)

      {:error, reason} ->
        handle_step_failure(step, context, reason, step_start)
    end
  end

  defp handle_step_success(step, index, context, result, step_start) do
    # Check if result is an AsyncResponse (streaming)
    case result do
      %AsyncResponse{} = async_response ->
        handle_async_response_result(step, index, context, async_response, step_start)

      _ ->
        # Check if result should be streamed
        case maybe_create_result_stream(step, result) do
          {:ok, stream} ->
            # Store stream reference instead of large result
            stream_result = %{
              "success" => true,
              "type" => "stream",
              "stream_id" => stream.id,
              "stream_info" => ResultStream.get_stream_info(stream)
            }

            updated_context =
              update_context_with_success(step, index, context, stream_result, step_start)

            save_checkpoint_if_enabled(context, updated_context)
            save_step_output_if_needed(step, result, context.output_dir)

            Logger.info("✅ Step completed with streaming: #{step["name"]}")

            # Notify performance monitoring
            pipeline_name = context[:pipeline_name] || "unknown"
            Performance.step_completed(pipeline_name, step["name"], stream_result)

            {:ok, updated_context}

          {:no_stream, optimized_result} ->
            # Use normal result handling
            updated_context =
              update_context_with_success(step, index, context, optimized_result, step_start)

            save_checkpoint_if_enabled(context, updated_context)
            save_step_output_if_needed(step, result, context.output_dir)

            Logger.info("✅ Step completed: #{step["name"]}")
            {:ok, updated_context}

          {:error, reason} ->
            Logger.warning("⚠️  Failed to create result stream: #{reason}, using optimized result")
            optimized_result = optimize_result_for_memory(result)

            updated_context =
              update_context_with_success(step, index, context, optimized_result, step_start)

            save_checkpoint_if_enabled(context, updated_context)
            save_step_output_if_needed(step, result, context.output_dir)

            Logger.info("✅ Step completed: #{step["name"]}")
            {:ok, updated_context}
        end
    end
  end

  defp handle_step_success_with_context(step, index, context, result, step_start) do
    # Check if result should be streamed
    case maybe_create_result_stream(step, result) do
      {:ok, stream} ->
        # Store stream reference instead of large result
        stream_result = %{
          "success" => true,
          "type" => "stream",
          "stream_id" => stream.id,
          "stream_info" => ResultStream.get_stream_info(stream)
        }

        updated_context =
          update_context_with_success(step, index, context, stream_result, step_start)

        save_checkpoint_if_enabled(context, updated_context)
        save_step_output_if_needed(step, result, context.output_dir)

        Logger.info("✅ Step completed with streaming: #{step["name"]}")

        # Notify performance monitoring
        pipeline_name = context[:pipeline_name] || "unknown"
        Performance.step_completed(pipeline_name, step["name"], stream_result)

        {:ok, updated_context}

      {:no_stream, optimized_result} ->
        # Use normal result handling
        updated_context =
          update_context_with_success(step, index, context, optimized_result, step_start)

        save_checkpoint_if_enabled(context, updated_context)
        save_step_output_if_needed(step, result, context.output_dir)

        Logger.info("✅ Step completed: #{step["name"]}")
        {:ok, updated_context}

      {:error, reason} ->
        Logger.warning("⚠️  Failed to create result stream: #{reason}, using optimized result")
        optimized_result = optimize_result_for_memory(result)

        updated_context =
          update_context_with_success(step, index, context, optimized_result, step_start)

        save_checkpoint_if_enabled(context, updated_context)
        save_step_output_if_needed(step, result, context.output_dir)

        Logger.info("✅ Step completed: #{step["name"]}")
        {:ok, updated_context}
    end
  end

  defp handle_step_failure(step, context, reason, step_start) do
    Logger.error("❌ Step failed: #{step["name"]} - #{reason}")

    updated_context = update_context_with_failure(step, context, reason, step_start)
    save_checkpoint_if_enabled(context, updated_context)

    error_context = create_error_context(step, reason, step_start)
    {:error, error_context}
  end

  defp update_context_with_success(step, index, context, result, step_start) do
    # Check if the previous step's result is an async stream that needs to be resolved
    resolved_results = resolve_async_results_for_step(context.results, step)

    # Wrap result in a structure that supports template access patterns for nested pipeline steps with inputs
    # For regular steps and nested pipelines without inputs, maintain backward compatibility
    final_result =
      if step["type"] == "pipeline" && has_inputs?(step) do
        # Nested pipeline step with inputs: wrap in "result" key to support template patterns like {{steps.step_name.result.field}}
        %{"result" => result}
      else
        # Regular step or nested pipeline without inputs: use result directly for backward compatibility
        result
      end

    %{
      context
      | results: Map.put(resolved_results, step["name"], final_result),
        step_index: index + 1,
        execution_log: [create_success_log_entry(step, step_start) | context.execution_log]
    }
  end

  defp update_context_with_failure(step, context, reason, step_start) do
    %{
      context
      | execution_log: [
          create_failure_log_entry(step, reason, step_start) | context.execution_log
        ]
    }
  end

  defp create_success_log_entry(step, step_start) do
    %{
      step: step["name"],
      type: step["type"],
      status: :completed,
      duration_ms: DateTime.diff(DateTime.utc_now(), step_start, :millisecond),
      timestamp: DateTime.utc_now()
    }
  end

  defp create_failure_log_entry(step, reason, step_start) do
    %{
      step: step["name"],
      type: step["type"],
      status: :failed,
      error: reason,
      duration_ms: DateTime.diff(DateTime.utc_now(), step_start, :millisecond),
      timestamp: DateTime.utc_now()
    }
  end

  defp save_checkpoint_if_enabled(context, updated_context) do
    if context.checkpoint_enabled do
      case CheckpointManager.save(
             context.checkpoint_dir,
             context.workflow_name,
             updated_context
           ) do
        :ok -> :ok
        {:error, reason} -> Logger.warning("Failed to save checkpoint: #{inspect(reason)}")
      end
    end
  end

  defp save_step_output_if_needed(step, result, output_dir) do
    if step["output_to_file"] do
      save_step_output(step["output_to_file"], result, output_dir)
    end
  end

  defp create_error_context(step, reason, step_start) do
    """
    Step '#{step["name"]}' failed: #{reason}
    Step type: #{step["type"]}
    Execution time: #{DateTime.diff(DateTime.utc_now(), step_start, :millisecond)}ms
    """
  end

  defp do_execute_step(step, context) do
    case step["type"] do
      "set_variable" ->
        SetVariable.execute(step, context)

      "claude" ->
        # Enable pass-through streaming for pipeline execution
        step_with_streaming = update_claude_options_for_streaming(step)
        Claude.execute(step_with_streaming, context)

      "gemini" ->
        Gemini.execute(step, context)

      "parallel_claude" ->
        ParallelClaude.execute(step, context)

      "gemini_instructor" ->
        GeminiInstructor.execute(step, context)

      # Enhanced step types
      "claude_smart" ->
        ClaudeSmart.execute(step, context)

      "claude_session" ->
        ClaudeSession.execute(step, context)

      "claude_extract" ->
        ClaudeExtract.execute(step, context)

      "claude_batch" ->
        ClaudeBatch.execute(step, context)

      "claude_robust" ->
        ClaudeRobust.execute(step, context)

      # Loop step types
      "for_loop" ->
        Loop.execute(step, context)

      "while_loop" ->
        Loop.execute(step, context)

      # Data manipulation step types
      "data_transform" ->
        DataTransform.execute(step, context)

      "file_ops" ->
        FileOps.execute(step, context)

      # Nested pipeline step type
      "pipeline" ->
        NestedPipeline.execute(step, context)

      # Test-only step type
      "test_echo" ->
        if Mix.env() == :test do
          TestEcho.execute(step, context)
        else
          {:error, "test_echo step is only available in test environment"}
        end

      unknown_type ->
        supported_types = [
          "set_variable",
          "claude",
          "gemini",
          "parallel_claude",
          "gemini_instructor",
          "claude_smart",
          "claude_session",
          "claude_extract",
          "claude_batch",
          "claude_robust",
          "for_loop",
          "while_loop",
          "data_transform",
          "file_ops",
          "pipeline"
        ]

        {:error,
         "Invalid workflow: Step '#{step["name"]}' has invalid type '#{unknown_type}'. Supported types: #{Enum.join(supported_types, ", ")}"}
    end
  end

  defp save_step_output(filename, result, output_dir) do
    filepath = Path.join(output_dir, filename)
    File.mkdir_p!(Path.dirname(filepath))

    content =
      case result do
        result when is_binary(result) -> result
        result -> Jason.encode!(result, pretty: true)
      end

    File.write!(filepath, content)
    Logger.info("💾 Saved step output to: #{filepath}")
  end

  defp should_execute_step?(step, context) do
    case step["condition"] do
      nil -> true
      condition_expr -> ConditionEngine.evaluate(condition_expr, context)
    end
  end

  defp optimize_result_for_memory(result) when is_struct(result) do
    # Convert struct to map first to enable enumeration
    result
    |> Map.from_struct()
    |> optimize_result_for_memory()
  end

  defp optimize_result_for_memory(result) when is_map(result) do
    # Trim very large text fields to prevent memory issues
    # 100KB
    max_text_size = 100_000

    result
    |> Enum.map(fn {key, value} ->
      optimized_value =
        case value do
          text when is_binary(text) and byte_size(text) > max_text_size ->
            trimmed = String.slice(text, 0, max_text_size)
            "#{trimmed}... [TRIMMED: #{byte_size(text)} bytes total]"

          other ->
            other
        end

      {key, optimized_value}
    end)
    |> Map.new()
  end

  defp optimize_result_for_memory(result) when is_binary(result) do
    # 100KB
    max_text_size = 100_000

    if byte_size(result) > max_text_size do
      trimmed = String.slice(result, 0, max_text_size)
      "#{trimmed}... [TRIMMED: #{byte_size(result)} bytes total]"
    else
      result
    end
  end

  defp optimize_result_for_memory(result), do: result

  defp maybe_create_result_stream(step, result) do
    # Calculate result size
    result_size = calculate_result_size(result)

    # Check if streaming is enabled for this step and result is large enough
    if should_stream_step_result?(step, result_size) do
      # Check if streaming is explicitly enabled
      streaming_enabled = get_in(step, ["streaming", "enabled"]) || false

      metadata = %{
        step_type: step["type"],
        forced_streaming: streaming_enabled
      }

      case ResultStream.create_stream(step["name"], "result", result, metadata) do
        {:ok, stream} ->
          {:ok, stream}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:no_stream, optimize_result_for_memory(result)}
    end
  end

  defp should_stream_step_result?(step, result_size) do
    # Check if streaming is explicitly enabled
    streaming_enabled = get_in(step, ["streaming", "enabled"]) || false

    # Check if result size exceeds threshold
    large_result = ResultStream.should_stream_result?(result_size)

    # Stream if explicitly enabled or result is large
    streaming_enabled || large_result
  end

  defp calculate_result_size(result) when is_binary(result) do
    byte_size(result)
  end

  defp calculate_result_size(result) do
    result
    |> :erlang.term_to_binary()
    |> byte_size()
  end

  defp log_pipeline_completion(context) do
    duration = DateTime.diff(DateTime.utc_now(), context.start_time, :millisecond)

    # Clear prompt builder cache to free memory
    Pipeline.PromptBuilder.clear_cache()

    # Log all completion messages together without blank lines
    Logger.info("✅ Pipeline execution completed successfully")
    Logger.info("🏁 Pipeline execution completed in #{duration}ms")
    Logger.info("🧹 Cleaned up temporary resources and caches")
  end

  defp log_performance_summary(metrics) do
    Logger.info("📊 Performance Summary:")
    Logger.info("   Duration: #{metrics.total_duration_ms}ms")
    Logger.info("   Steps: #{metrics.successful_steps}/#{metrics.total_steps}")
    Logger.info("   Peak Memory: #{format_bytes(metrics.peak_memory_bytes)}")

    if metrics.total_warnings > 0 do
      Logger.warning("⚠️  Performance Warnings: #{metrics.total_warnings}")
    end

    if length(metrics.recommendations) > 0 do
      Logger.info("💡 Recommendations:")

      Enum.each(metrics.recommendations, fn rec ->
        Logger.info("   - #{rec}")
      end)
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  defp cleanup_context(context) do
    # Clean up any temporary resources
    duration = DateTime.diff(DateTime.utc_now(), context.start_time, :millisecond)

    # Clear prompt builder cache to free memory
    Pipeline.PromptBuilder.clear_cache()

    # Log completion with consolidated messages
    Logger.info("🏁 Pipeline execution completed in #{duration}ms")
    Logger.info("🧹 Cleaned up temporary resources and caches")
  end

  # Variable interpolation helpers

  defp interpolate_step_variables(step, context) do
    case Map.get(context, :variable_state) do
      nil ->
        step

      variable_state ->
        # Check if we're in a nested pipeline context (has inputs)
        # Use type preservation for nested pipelines to preserve arithmetic results
        if Map.has_key?(context, :inputs) do
          VariableEngine.interpolate_data_with_type_preservation(step, variable_state, context)
        else
          # Pass both variable state and execution context for step result resolution
          VariableEngine.interpolate_data_with_context(step, variable_state, context)
        end
    end
  end

  defp update_variable_step_info(context, step_name, step_index) do
    case Map.get(context, :variable_state) do
      nil ->
        context

      variable_state ->
        updated_state = VariableEngine.update_step_info(variable_state, step_name, step_index)
        %{context | variable_state: updated_state}
    end
  end

  # Helper to check if a nested pipeline step has inputs
  defp has_inputs?(step) do
    inputs = step["inputs"]
    is_map(inputs) && map_size(inputs) > 0
  end

  # Async response handling

  defp handle_async_response_result(step, index, context, async_response, step_start) do
    Logger.info("🌊 Step #{step["name"]} returned async streaming response")

    # Store the async response as a special result type
    async_result = %{
      "success" => true,
      "type" => "async_stream",
      "async_response" => async_response,
      "stream_info" => %{
        "step_name" => async_response.step_name,
        "handler" => inspect(async_response.handler),
        "started_at" => async_response.metrics.stream_started_at
      }
    }

    # Update context with the async result
    updated_context =
      update_context_with_success(step, index, context, async_result, step_start)

    # Notify performance monitoring
    pipeline_name = context[:pipeline_name] || "unknown"
    Performance.step_completed(pipeline_name, step["name"], async_result)

    # Save checkpoint if enabled (note: async streams might not be checkpointable)
    save_checkpoint_if_enabled(context, updated_context)

    Logger.info("✅ Step completed with async streaming: #{step["name"]}")
    {:ok, updated_context}
  end

  # Helper to convert async response to sync if needed
  defp maybe_collect_async_response(async_response, step_name) do
    Logger.debug("Collecting async response for step: #{step_name}")

    case AsyncResponse.to_sync_response(async_response) do
      {:ok, sync_result} ->
        sync_result

      {:error, reason} ->
        Logger.error("Failed to collect async response: #{reason}")

        %{
          "success" => false,
          "error" => "Failed to collect async stream: #{reason}"
        }
    end
  end

  # Resolve any async results that need to be accessed by the current step
  defp resolve_async_results_for_step(results, step) do
    # Check if step references any async results
    referenced_steps = find_referenced_steps(step)

    Enum.reduce(referenced_steps, results, fn step_name, acc ->
      case Map.get(acc, step_name) do
        %{"type" => "async_stream", "async_response" => async_response} = async_result ->
          # Need to collect this async stream for use
          Logger.debug("Resolving async stream from step: #{step_name}")
          sync_result = maybe_collect_async_response(async_response, step_name)

          # Preserve the original async result but add the resolved data
          resolved_result =
            Map.merge(async_result, %{
              "resolved_result" => sync_result,
              "resolved_at" => DateTime.utc_now()
            })

          Map.put(acc, step_name, resolved_result)

        _ ->
          # Not an async result or already resolved
          acc
      end
    end)
  end

  # Find which previous steps are referenced in the current step
  defp find_referenced_steps(step) do
    # Extract step references from prompt and other fields
    prompt_refs = extract_prompt_references(step["prompt"] || [])

    # Add references from inputs if it's a nested pipeline
    input_refs =
      case step["inputs"] do
        inputs when is_map(inputs) ->
          inputs
          |> Map.values()
          |> Enum.flat_map(&extract_template_references/1)

        _ ->
          []
      end

    # Combine and deduplicate
    MapSet.new(prompt_refs ++ input_refs) |> MapSet.to_list()
  end

  defp extract_prompt_references(prompt) when is_list(prompt) do
    Enum.flat_map(prompt, fn
      %{"type" => "previous_response", "step" => step_name} ->
        [step_name]

      _ ->
        []
    end)
  end

  defp extract_prompt_references(_), do: []

  defp extract_template_references(value) when is_binary(value) do
    # Extract step references from template strings like {{steps.step_name.field}}
    Regex.scan(~r/\{\{steps\.([^.\}]+)/, value)
    |> Enum.map(fn [_, step_name] -> step_name end)
  end

  defp extract_template_references(_), do: []

  # Resolve async results before step execution  
  defp resolve_async_results_before_execution(context, step) do
    resolved_results = resolve_async_results_for_step(context.results, step)
    %{context | results: resolved_results}
  end

  # Update claude options to enable pass-through streaming in pipeline context
  defp update_claude_options_for_streaming(step) do
    claude_options = Map.get(step, "claude_options", %{})
    updated_options = Map.put(claude_options, "pass_through_streaming", true)
    Map.put(step, "claude_options", updated_options)
  end
end
