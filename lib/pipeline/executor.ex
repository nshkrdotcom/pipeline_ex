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
          Logger.info("✅ Pipeline execution completed successfully")
          cleanup_context(final_context)
          {:ok, final_context.results}

        {:error, reason} = error ->
          Logger.error("❌ Pipeline execution failed: #{reason}")
          cleanup_context(context)
          error
      end
    rescue
      error ->
        Logger.error("💥 Pipeline execution crashed: #{inspect(error)}")
        cleanup_context(context)
        {:error, "Pipeline execution crashed: #{Exception.message(error)}"}
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

    # Record step start
    step_start = DateTime.utc_now()

    case do_execute_step(step, context) do
      {:ok, result} ->
        # Update context with result
        updated_context = %{
          context
          | results: Map.put(context.results, step["name"], result),
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

        {:error, "Step '#{step["name"]}' failed: #{reason}"}
    end
  end

  defp do_execute_step(step, context) do
    case step["type"] do
      "claude" ->
        Claude.execute(step, context)

      "gemini" ->
        Gemini.execute(step, context)

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

  defp cleanup_context(context) do
    # Clean up any temporary resources
    # For now, just log completion
    duration = DateTime.diff(DateTime.utc_now(), context.start_time, :millisecond)
    Logger.info("🏁 Pipeline execution completed in #{duration}ms")
  end
end
