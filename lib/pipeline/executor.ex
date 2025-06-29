defmodule Pipeline.Executor do
  @moduledoc """
  Main pipeline execution engine.

  Orchestrates the execution of workflow steps, manages state,
  and coordinates between Brain (Gemini) and Muscle (Claude) operations.
  """

  require Logger
  alias Pipeline.CheckpointManager
  alias Pipeline.Step.{Claude, Gemini}

  @type workflow :: map()
  @type execution_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Execute a complete workflow.

  Takes a workflow configuration and executes all steps in sequence,
  managing state and checkpoints along the way.
  """
  @spec execute(workflow, keyword()) :: execution_result
  def execute(workflow, opts \\ []) do
    Logger.info("🚀 Starting pipeline execution: #{workflow["workflow"]["name"]}")

    # Initialize execution context
    context = initialize_context(workflow, opts)

    # Load checkpoint if enabled and exists
    context = maybe_load_checkpoint(context)

    try do
      # Execute steps
      case execute_steps(workflow["workflow"]["steps"], context) do
        {:ok, final_context} ->
          log_pipeline_completion(final_context)
          {:ok, final_context.results}

        {:error, reason} = error ->
          Logger.error("❌ Pipeline execution failed: #{reason}")
          cleanup_context(context)
          error
      end
    rescue
      error ->
        workflow_name = workflow["workflow"]["name"] || "unnamed"
        step_count = length(workflow["workflow"]["steps"] || [])
        current_step = context.step_index + 1
        
        Logger.error("💥 Pipeline '#{workflow_name}' crashed at step #{current_step}/#{step_count}: #{inspect(error)}")
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

    # Create directories
    workspace_dir = Path.expand(config["workspace_dir"] || "./workspace")
    output_dir = Path.expand(config["defaults"]["output_dir"] || "./outputs")
    checkpoint_dir = Path.expand(config["checkpoint_dir"] || "./checkpoints")

    File.mkdir_p!(workspace_dir)
    File.mkdir_p!(output_dir)
    File.mkdir_p!(checkpoint_dir)

    %{
      workflow_name: config["name"],
      workspace_dir: workspace_dir,
      output_dir: output_dir,
      checkpoint_dir: checkpoint_dir,
      checkpoint_enabled: config["checkpoint_enabled"] || false,
      results: %{},
      execution_log: [],
      start_time: DateTime.utc_now(),
      step_index: 0,
      debug_enabled: Keyword.get(opts, :debug, false)
    }
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
              execution_log: checkpoint_data.execution_log
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
    |> Enum.reduce_while({:ok, context}, fn {step, index}, {:ok, ctx} ->
      # Skip steps if we're resuming from checkpoint
      if index < ctx.step_index do
        Logger.info("⏭️  Skipping step #{index + 1}: #{step["name"]} (already completed)")
        {:cont, {:ok, ctx}}
      else
        case execute_step_with_checkpoint(step, index, ctx) do
          {:ok, updated_ctx} -> {:cont, {:ok, updated_ctx}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end
    end)
  end

  defp execute_step_with_checkpoint(step, index, context) do
    Logger.info("🎯 Executing step #{index + 1}: #{step["name"]} (#{step["type"]})")

    # Check if step should be executed based on condition
    if should_execute_step?(step, context) do
      Logger.info("✅ Condition met, executing step: #{step["name"]}")
      execute_step_unconditionally(step, index, context)
    else
      Logger.info("⏭️  Condition not met, skipping step: #{step["name"]}")
      
      # Create a skipped result
      skipped_result = %{
        "success" => true,
        "skipped" => true,
        "reason" => "Condition not met: #{step["condition"] || "N/A"}"
      }
      
      updated_context = %{
        context
        | results: Map.put(context.results, step["name"], skipped_result),
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
    # Record step start
    step_start = DateTime.utc_now()

    case do_execute_step(step, context) do
      {:ok, result} ->
        # Optimize result for memory usage
        optimized_result = optimize_result_for_memory(result)
        
        # Update context with result
        updated_context = %{
          context
          | results: Map.put(context.results, step["name"], optimized_result),
            step_index: index + 1,
            execution_log: [
              %{
                step: step["name"],
                type: step["type"],
                status: :completed,
                duration_ms: DateTime.diff(DateTime.utc_now(), step_start, :millisecond),
                timestamp: DateTime.utc_now()
              }
              | context.execution_log
            ]
        }

        # Save checkpoint if enabled
        if context.checkpoint_enabled do
          CheckpointManager.save(context.checkpoint_dir, context.workflow_name, updated_context)
        end

        # Save step output if specified
        if step["output_to_file"] do
          save_step_output(step["output_to_file"], result, context.output_dir)
        end

        Logger.info("✅ Step completed: #{step["name"]}")
        {:ok, updated_context}

      {:error, reason} ->
        Logger.error("❌ Step failed: #{step["name"]} - #{reason}")

        # Record failure in log
        updated_context = %{
          context
          | execution_log: [
              %{
                step: step["name"],
                type: step["type"],
                status: :failed,
                error: reason,
                duration_ms: DateTime.diff(DateTime.utc_now(), step_start, :millisecond),
                timestamp: DateTime.utc_now()
              }
              | context.execution_log
            ]
        }

        # Save checkpoint even on failure
        if context.checkpoint_enabled do
          CheckpointManager.save(context.checkpoint_dir, context.workflow_name, updated_context)
        end

        error_context = """
        Step '#{step["name"]}' failed: #{reason}
        Step type: #{step["type"]}
        Execution time: #{DateTime.diff(DateTime.utc_now(), step_start, :millisecond)}ms
        """
        
        {:error, error_context}
    end
  end

  defp do_execute_step(step, context) do
    case step["type"] do
      "claude" ->
        Claude.execute(step, context)

      "gemini" ->
        Gemini.execute(step, context)

      "parallel_claude" ->
        Pipeline.Step.ParallelClaude.execute(step, context)

      "gemini_instructor" ->
        Pipeline.Step.GeminiInstructor.execute(step, context)

      unknown_type ->
        {:error, "Unknown step type: #{unknown_type}"}
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
      condition_expr -> evaluate_condition(condition_expr, context)
    end
  end

  defp evaluate_condition(condition_expr, context) do
    case String.split(condition_expr, ".") do
      [step_name] -> 
        get_in(context.results, [step_name]) |> is_truthy()
      [step_name, field] ->
        get_in(context.results, [step_name, field]) |> is_truthy()
      parts when length(parts) > 2 ->
        get_in(context.results, parts) |> is_truthy()
    end
  end

  defp is_truthy(nil), do: false
  defp is_truthy(false), do: false
  defp is_truthy(""), do: false
  defp is_truthy([]), do: false
  defp is_truthy(_), do: true

  defp optimize_result_for_memory(result) when is_map(result) do
    # Trim very large text fields to prevent memory issues
    max_text_size = 100_000  # 100KB
    
    result
    |> Enum.map(fn {key, value} ->
      optimized_value = case value do
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
    max_text_size = 100_000  # 100KB
    
    if byte_size(result) > max_text_size do
      trimmed = String.slice(result, 0, max_text_size)
      "#{trimmed}... [TRIMMED: #{byte_size(result)} bytes total]"
    else
      result
    end
  end

  defp optimize_result_for_memory(result), do: result

  defp log_pipeline_completion(context) do
    duration = DateTime.diff(DateTime.utc_now(), context.start_time, :millisecond)
    
    # Clear prompt builder cache to free memory
    Pipeline.PromptBuilder.clear_cache()
    
    # Log all completion messages together without blank lines
    Logger.info("✅ Pipeline execution completed successfully")
    Logger.info("🏁 Pipeline execution completed in #{duration}ms")
    Logger.info("🧹 Cleaned up temporary resources and caches")
  end

  defp cleanup_context(context) do
    # Clean up any temporary resources
    duration = DateTime.diff(DateTime.utc_now(), context.start_time, :millisecond)
    
    # Clear prompt builder cache to free memory
    Pipeline.PromptBuilder.clear_cache()
    
    # Log completion with consolidated messages
    Logger.info("🏁 Pipeline execution completed in #{duration}ms")
    Logger.info("🧹 Cleaned up temporary resources and caches")
  end
end
