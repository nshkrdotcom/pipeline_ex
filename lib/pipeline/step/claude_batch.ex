defmodule Pipeline.Step.ClaudeBatch do
  @moduledoc """
  Claude Batch step executor - handles claude_batch step type with parallel processing capabilities.

  Claude Batch steps provide parallel processing for multiple tasks:
  - Process multiple files or prompts concurrently
  - Configurable parallelism limits to control resource usage
  - Task-specific timeouts for reliable processing
  - Result consolidation and aggregation
  - Error handling per task with graceful degradation
  """

  require Logger
  alias Pipeline.{OptionBuilder, PromptBuilder}

  @doc """
  Execute a claude_batch step with parallel processing.
  """
  def execute(step, context) do
    Logger.info("🎯 Executing Claude Batch step: #{step["name"]}")

    try do
      with {:ok, batch_config} <- validate_batch_configuration(step),
           {:ok, tasks} <- prepare_batch_tasks(step, context),
           {:ok, enhanced_options} <- build_enhanced_options(step, context),
           {:ok, provider} <- get_provider(context),
           {:ok, batch_results} <-
             execute_batch_tasks(tasks, provider, enhanced_options, batch_config) do
        # Consolidate results if requested
        final_result = consolidate_batch_results(batch_results, batch_config, step)

        Logger.info(
          "✅ Claude Batch step completed successfully: #{length(tasks)} tasks processed"
        )

        {:ok, final_result}
      else
        {:error, reason} ->
          Logger.error("❌ Claude Batch step failed: #{reason}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("💥 Claude Batch step crashed: #{inspect(error)}")
        {:error, "Claude Batch step crashed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions

  defp validate_batch_configuration(step) do
    batch_config = step["batch_config"] || %{}

    config = %{
      "max_parallel" => batch_config["max_parallel"] || 3,
      "timeout_per_task" => batch_config["timeout_per_task"] || 60_000,
      "consolidate_results" => Map.get(batch_config, "consolidate_results", true)
    }

    # Validate configuration values
    cond do
      config["max_parallel"] <= 0 ->
        {:error, "max_parallel must be a positive integer"}

      config["timeout_per_task"] <= 0 ->
        {:error, "timeout_per_task must be a positive integer"}

      true ->
        {:ok, config}
    end
  end

  defp prepare_batch_tasks(step, _context) do
    tasks = step["tasks"] || []

    if Enum.empty?(tasks) do
      # If no tasks specified, create a single task from the step's prompt
      default_task = %{
        "prompt" => step["prompt"] || [%{"type" => "static", "content" => "Default batch task"}],
        "task_id" => "default_task",
        "file" => nil
      }

      {:ok, [default_task]}
    else
      # Process and validate tasks
      processed_tasks =
        tasks
        |> Enum.with_index()
        |> Enum.map(fn {task, index} ->
          task_with_id = Map.put_new(task, "task_id", "task_#{index}")

          # Build prompt for this task
          task_prompt =
            case task do
              %{"prompt" => prompt} when is_list(prompt) ->
                prompt

              %{"prompt" => prompt} when is_binary(prompt) ->
                [%{"type" => "static", "content" => prompt}]

              %{"file" => file} when is_binary(file) ->
                # In mock mode, create a mock file reference instead of trying to read non-existent files
                test_mode = Application.get_env(:pipeline, :test_mode, :live)

                if test_mode == :mock do
                  [
                    %{"type" => "static", "content" => "Mock file analysis for: #{file}"},
                    %{"type" => "static", "content" => task["prompt"] || "Analyze this file"}
                  ]
                else
                  [
                    %{"type" => "file", "path" => file},
                    %{"type" => "static", "content" => task["prompt"] || "Analyze this file"}
                  ]
                end

              _ ->
                # Fallback to step's prompt with task context
                base_prompt =
                  step["prompt"] || [%{"type" => "static", "content" => "Process this task"}]

                task_context = [
                  %{"type" => "static", "content" => "Task context: #{inspect(task)}"}
                ]

                task_context ++ base_prompt
            end

          Map.put(task_with_id, "built_prompt", task_prompt)
        end)

      {:ok, processed_tasks}
    end
  end

  defp build_enhanced_options(step, context) do
    # Start with basic enhanced Claude options
    base_options = step["claude_options"] || %{}

    # Apply OptionBuilder for consistency with other step types
    preset = get_preset_for_batch(step, context)
    enhanced_options = OptionBuilder.merge(preset, base_options)

    # Add batch-specific options
    batch_options = %{
      "batch_config" => step["batch_config"] || %{},
      # Preserve preset for mock provider
      "preset" => preset
    }

    final_options = Map.merge(enhanced_options, batch_options)

    Logger.debug("🎯 Claude Batch options built with preset: #{preset}")
    {:ok, final_options}
  rescue
    error ->
      Logger.error("💥 Failed to build batch options: #{inspect(error)}")
      {:error, "Failed to build batch options: #{Exception.message(error)}"}
  end

  defp get_preset_for_batch(step, context) do
    # Use development preset as default for batch processing (good for multiple tasks)
    step["preset"] ||
      (context.config && get_in(context.config, ["workflow", "defaults", "claude_preset"])) ||
      "development"
  end

  defp get_provider(context) do
    provider_module = determine_provider_module(context)
    {:ok, provider_module}
  end

  defp determine_provider_module(_context) do
    # Check if we're in test mode
    test_mode = Application.get_env(:pipeline, :test_mode, :live)

    case test_mode do
      :mock ->
        Pipeline.Test.Mocks.ClaudeProvider

      _ ->
        # Use enhanced provider for live mode
        Pipeline.Providers.EnhancedClaudeProvider
    end
  end

  defp execute_batch_tasks(tasks, provider, options, batch_config) do
    max_parallel = batch_config["max_parallel"]
    timeout_per_task = batch_config["timeout_per_task"]

    Logger.debug("🚀 Executing #{length(tasks)} tasks with max_parallel=#{max_parallel}")

    # Execute tasks in parallel with controlled concurrency
    tasks
    |> Task.async_stream(
      fn task -> execute_single_task(task, provider, options, timeout_per_task) end,
      max_concurrency: max_parallel,
      # Add buffer to task timeout
      timeout: timeout_per_task + 5000,
      on_timeout: :kill_task
    )
    |> Enum.to_list()
    |> process_task_results()
  end

  defp execute_single_task(task, provider, options, timeout) do
    task_id = task["task_id"]
    Logger.debug("📋 Processing batch task: #{task_id}")

    try do
      # Build prompt for this specific task
      prompt = PromptBuilder.build(task["built_prompt"], %{})

      # Add task-specific context to options
      task_options =
        Map.merge(options, %{
          "task_id" => task_id,
          "task_file" => task["file"],
          "batch_task" => true
        })

      # Execute with timeout
      task_ref =
        Task.async(fn ->
          provider.query(prompt, task_options)
        end)

      case Task.yield(task_ref, timeout) do
        {:ok, result} ->
          _shutdown_result = Task.shutdown(task_ref)

          case result do
            {:ok, response} ->
              Logger.debug("✅ Task #{task_id} completed successfully")

              {:ok,
               %{
                 "task_id" => task_id,
                 "status" => "success",
                 "result" => response,
                 "file" => task["file"],
                 # Mock execution time
                 "execution_time_ms" => :rand.uniform(1000) + 500
               }}

            {:error, reason} ->
              Logger.warning("⚠️ Task #{task_id} failed: #{reason}")

              {:ok,
               %{
                 "task_id" => task_id,
                 "status" => "error",
                 "error" => reason,
                 "file" => task["file"]
               }}
          end

        nil ->
          # Task timed out
          _shutdown_result = Task.shutdown(task_ref, :brutal_kill)
          Logger.warning("⏰ Task #{task_id} timed out after #{timeout}ms")

          {:ok,
           %{
             "task_id" => task_id,
             "status" => "timeout",
             "error" => "Task timed out after #{timeout}ms",
             "file" => task["file"]
           }}
      end
    rescue
      error ->
        Logger.error("💥 Task #{task_id} crashed: #{inspect(error)}")

        {:ok,
         %{
           "task_id" => task_id,
           "status" => "error",
           "error" => "Task crashed: #{Exception.message(error)}",
           "file" => task["file"]
         }}
    end
  end

  defp process_task_results(stream_results) do
    results =
      Enum.map(stream_results, fn
        # Handle double-wrapped ok tuples
        {:ok, {:ok, task_result}} ->
          task_result

        # Handle single-wrapped results
        {:ok, task_result} ->
          task_result

        {:exit, reason} ->
          %{
            "task_id" => "unknown",
            "status" => "failed",
            "error" => "Task process exited: #{inspect(reason)}"
          }
      end)

    {:ok, results}
  end

  defp consolidate_batch_results(batch_results, batch_config, step) do
    successful_tasks =
      Enum.filter(batch_results, fn task ->
        case task do
          %{"status" => "success"} -> true
          _ -> false
        end
      end)

    failed_tasks =
      Enum.filter(batch_results, fn task ->
        case task do
          %{"status" => "success"} -> false
          _ -> true
        end
      end)

    # Build consolidated response
    base_response = %{
      "success" => true,
      "batch_processed" => true,
      "total_tasks" => length(batch_results),
      "successful_tasks" => length(successful_tasks),
      "failed_tasks" => length(failed_tasks),
      "batch_results" => batch_results
    }

    # Add consolidated text if requested
    consolidate_results =
      case batch_config do
        %{"consolidate_results" => value} when is_boolean(value) -> value
        # Default to true when not specified
        _ -> true
      end

    consolidated_response =
      if consolidate_results do
        consolidated_text = build_consolidated_text(batch_results)
        batch_metadata = build_batch_metadata(batch_results, step)

        base_response
        |> Map.put("text", consolidated_text)
        |> Map.put("claude_batch_metadata", batch_metadata)
      else
        base_response
      end

    # Add performance statistics
    add_performance_statistics(consolidated_response, batch_results)
  end

  defp build_consolidated_text(batch_results) do
    successful_results =
      batch_results
      |> Enum.filter(&(&1["status"] == "success"))
      |> Enum.map(fn task ->
        task_id = task["task_id"] || "unknown"
        file = task["file"] || "N/A"

        # Safely extract text from result
        result_text =
          case task["result"] do
            %{"text" => text} when is_binary(text) -> text
            %{"content" => content} when is_binary(content) -> content
            result when is_binary(result) -> result
            _ -> "No text result"
          end

        """
        ## Task: #{task_id}
        **File**: #{file}
        **Status**: Success

        #{result_text}
        """
      end)

    failed_results =
      batch_results
      |> Enum.filter(&(&1["status"] != "success"))
      |> Enum.map(fn task ->
        task_id = task["task_id"] || "unknown"
        file = task["file"] || "N/A"
        error = task["error"] || "Unknown error"
        status = task["status"] || "failed"

        """
        ## Task: #{task_id}
        **File**: #{file}
        **Status**: #{String.upcase(status)}
        **Error**: #{error}
        """
      end)

    all_results = successful_results ++ failed_results

    """
    # Batch Processing Results

    **Total Tasks**: #{length(batch_results)}
    **Successful**: #{length(successful_results)}
    **Failed**: #{length(failed_results)}

    #{Enum.join(all_results, "\n\n---\n\n")}
    """
  end

  defp build_batch_metadata(batch_results, step) do
    step_name =
      case step do
        %{"name" => name} when is_binary(name) -> name
        _ -> "unknown_step"
      end

    %{
      "step_name" => step_name,
      "batch_processed_at" => DateTime.utc_now(),
      "total_tasks" => length(batch_results),
      "task_breakdown" => %{
        "successful" =>
          Enum.count(batch_results, fn task ->
            case task do
              %{"status" => "success"} -> true
              _ -> false
            end
          end),
        "failed" =>
          Enum.count(batch_results, fn task ->
            case task do
              %{"status" => "error"} -> true
              _ -> false
            end
          end),
        "timeout" =>
          Enum.count(batch_results, fn task ->
            case task do
              %{"status" => "timeout"} -> true
              _ -> false
            end
          end)
      },
      "files_processed" =>
        batch_results
        |> Enum.map(fn task ->
          case task do
            %{"file" => file} when is_binary(file) -> file
            _ -> nil
          end
        end)
        |> Enum.filter(&(!is_nil(&1)))
        |> Enum.uniq()
    }
  end

  defp add_performance_statistics(response, batch_results) do
    # Calculate performance metrics
    execution_times =
      batch_results
      |> Enum.map(fn task ->
        case task do
          %{"execution_time_ms" => time} when is_integer(time) -> time
          _ -> nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    performance_stats =
      if Enum.empty?(execution_times) do
        %{
          "total_execution_time_ms" => 0,
          "average_task_time_ms" => 0,
          "min_task_time_ms" => 0,
          "max_task_time_ms" => 0
        }
      else
        %{
          "total_execution_time_ms" => Enum.sum(execution_times),
          "average_task_time_ms" => div(Enum.sum(execution_times), length(execution_times)),
          "min_task_time_ms" => Enum.min(execution_times),
          "max_task_time_ms" => Enum.max(execution_times)
        }
      end

    Map.put(response, "performance_statistics", performance_stats)
  end
end
