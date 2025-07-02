defmodule Pipeline.Step.Loop do
  @moduledoc """
  Advanced loop step executor - handles for_loop and while_loop operations.

  Provides iteration capabilities with:
  - Nested loop support with proper variable scoping
  - Parallel execution for independent iterations
  - Loop control flow (break, continue, early termination)
  - Performance optimization for large datasets
  - Memory management for long-running loops
  """

  require Logger
  alias Pipeline.Condition.Engine, as: ConditionEngine

  @max_iterations 1000
  @default_max_iterations 100
  @default_max_parallel 5
  @memory_check_interval 50
  @large_dataset_threshold 500
  # 400MB
  @memory_threshold 400_000_000
  @gc_interval 100

  @doc """
  Execute a loop step (for_loop or while_loop).
  """
  def execute(step, context) do
    case step["type"] do
      "for_loop" ->
        execute_for_loop(step, context)

      "while_loop" ->
        execute_while_loop(step, context)

      _ ->
        {:error, "Unknown loop type: #{step["type"]}"}
    end
  end

  # For Loop Implementation
  defp execute_for_loop(step, context) do
    Logger.info("🔄 Executing for_loop step: #{step["name"]}")

    with {:ok, iterator_name} <- get_iterator_name(step),
         {:ok, sub_steps} <- get_sub_steps(step),
         {:ok, data} <- get_loop_data(step, context) do
      # Use optimized execution based on data size and configuration
      optimize_loop_execution(data, iterator_name, sub_steps, step, context)
    else
      error -> error
    end
  end

  # While Loop Implementation
  defp execute_while_loop(step, context) do
    Logger.info("🔄 Executing while_loop step: #{step["name"]}")

    with {:ok, condition} <- get_while_condition(step),
         {:ok, sub_steps} <- get_sub_steps(step) do
      max_iterations = get_max_iterations(step)
      execute_while_loop_iterations(condition, sub_steps, step, context, max_iterations, 0)
    else
      error -> error
    end
  end

  # For Loop Iteration Execution
  defp execute_for_loop_iterations(data, iterator_name, sub_steps, step, context)
       when is_list(data) do
    Logger.info("🔄 Processing #{length(data)} items in for_loop")

    initial_results = %{
      "iterations" => [],
      "success" => true,
      "total_items" => length(data),
      "completed_items" => 0
    }

    {final_results, _final_context} =
      data
      |> Enum.with_index()
      |> Enum.reduce_while({initial_results, context}, fn {item, index},
                                                          {acc_results, acc_context} ->
        Logger.info("🔄 Processing item #{index + 1}/#{length(data)}")

        # Memory check for large datasets
        if rem(index, @memory_check_interval) == 0 do
          case check_memory_usage(index, length(data)) do
            :ok -> :ok
            {:error, reason} -> 
              Logger.warning("Memory check failed: #{inspect(reason)}")
          end
        end

        # Create nested loop context with parent reference
        loop_context =
          create_nested_loop_context(iterator_name, item, index, length(data), acc_context)

        updated_context = add_loop_context(acc_context, loop_context)

        case execute_sub_steps(sub_steps, updated_context) do
          {:ok, iteration_context} ->
            iteration_result = %{
              "index" => index,
              "item" => item,
              "success" => true,
              "results" => extract_sub_step_results(sub_steps, iteration_context)
            }

            updated_results = %{
              acc_results
              | "iterations" => [iteration_result | acc_results["iterations"]],
                "completed_items" => acc_results["completed_items"] + 1
            }

            merged_context = merge_context_results(acc_context, iteration_context)

            # Check for break/continue conditions
            case check_loop_control(step, iteration_context) do
              :break ->
                Logger.info("🔄 Loop break condition met at iteration #{index + 1}")
                {:halt, {updated_results, merged_context}}

              :continue ->
                Logger.info("🔄 Loop continue condition met at iteration #{index + 1}")
                {:cont, {updated_results, merged_context}}

              :normal ->
                {:cont, {updated_results, merged_context}}
            end

          {:error, reason} ->
            Logger.error("❌ For loop iteration #{index + 1} failed: #{reason}")

            iteration_result = %{
              "index" => index,
              "item" => item,
              "success" => false,
              "error" => reason
            }

            updated_results = %{
              acc_results
              | "iterations" => [iteration_result | acc_results["iterations"]],
                "success" => false
            }

            # Check if we should halt on error
            if step["break_on_error"] != false do
              {:halt, {updated_results, acc_context}}
            else
              {:cont, {updated_results, acc_context}}
            end
        end
      end)

    # Reverse iterations to maintain order
    final_results = %{final_results | "iterations" => Enum.reverse(final_results["iterations"])}

    Logger.info(
      "✅ For loop completed: #{final_results["completed_items"]}/#{final_results["total_items"]} items"
    )

    {:ok, final_results}
  end


  # Parallel For Loop Execution
  defp execute_parallel_for_loop(data, iterator_name, sub_steps, step, context)
       when is_list(data) do
    Logger.info("🚀 Processing #{length(data)} items in parallel for_loop")

    max_parallel = get_max_parallel(step)

    initial_results = %{
      "iterations" => [],
      "success" => true,
      "total_items" => length(data),
      "completed_items" => 0,
      "parallel" => true,
      "max_parallel" => max_parallel
    }

    # Create tasks for parallel execution
    async_tasks =
      data
      |> Enum.with_index()
      |> Enum.chunk_every(max_parallel)
      |> Enum.map(fn chunk ->
        Task.async(fn ->
          process_parallel_chunk(chunk, iterator_name, sub_steps, step, context)
        end)
      end)

    # Wait for all tasks to complete
    chunk_results = Task.await_many(async_tasks, :infinity)

    # Combine results from all chunks
    final_results = combine_parallel_results(chunk_results, initial_results)

    Logger.info(
      "✅ Parallel for loop completed: #{final_results["completed_items"]}/#{final_results["total_items"]} items"
    )

    {:ok, final_results}
  end


  defp process_parallel_chunk(chunk, iterator_name, sub_steps, _step, context) do
    chunk
    |> Enum.map(fn {item, index} ->
      # Create loop context for this item
      loop_context =
        create_nested_loop_context(iterator_name, item, index, length(chunk), context)

      updated_context = add_loop_context(context, loop_context)

      case execute_sub_steps(sub_steps, updated_context) do
        {:ok, iteration_context} ->
          %{
            "index" => index,
            "item" => item,
            "success" => true,
            "results" => extract_sub_step_results(sub_steps, iteration_context)
          }

        {:error, reason} ->
          Logger.error("❌ Parallel iteration #{index + 1} failed: #{reason}")

          %{
            "index" => index,
            "item" => item,
            "success" => false,
            "error" => reason
          }
      end
    end)
  end

  defp combine_parallel_results(chunk_results, initial_results) do
    all_iterations =
      chunk_results
      |> List.flatten()
      |> Enum.sort_by(& &1["index"])

    completed_count = Enum.count(all_iterations, & &1["success"])
    all_successful = Enum.all?(all_iterations, & &1["success"])

    %{
      initial_results
      | "iterations" => all_iterations,
        "completed_items" => completed_count,
        "success" => all_successful
    }
  end

  # While Loop Iteration Execution
  defp execute_while_loop_iterations(
         condition,
         sub_steps,
         step,
         context,
         max_iterations,
         iteration_count
       ) do
    if iteration_count >= max_iterations do
      Logger.warning("⚠️  While loop reached maximum iterations (#{max_iterations})")

      {:ok,
       %{
         "success" => false,
         "iterations" => iteration_count,
         "max_iterations_reached" => true,
         "reason" => "Maximum iterations exceeded"
       }}
    else
      # Evaluate condition
      case evaluate_condition(condition, context) do
        true ->
          Logger.info("🔄 While loop iteration #{iteration_count + 1} (condition: true)")

          # Create loop context with iteration info
          loop_context = create_while_loop_context(iteration_count)
          updated_context = add_loop_context(context, loop_context)

          case execute_sub_steps(sub_steps, updated_context) do
            {:ok, iteration_context} ->
              # Merge results and continue
              merged_context = merge_context_results(context, iteration_context)

              execute_while_loop_iterations(
                condition,
                sub_steps,
                step,
                merged_context,
                max_iterations,
                iteration_count + 1
              )

            {:error, reason} ->
              Logger.error("❌ While loop iteration #{iteration_count + 1} failed: #{reason}")
              {:error, "While loop failed at iteration #{iteration_count + 1}: #{reason}"}
          end

        false ->
          Logger.info(
            "✅ While loop completed after #{iteration_count} iterations (condition: false)"
          )

          {:ok,
           %{
             "success" => true,
             "iterations" => iteration_count,
             "condition_met" => false
           }}

        {:error, reason} ->
          Logger.error("❌ While loop condition evaluation failed: #{reason}")
          {:error, "While loop condition evaluation failed: #{reason}"}
      end
    end
  end

  # Helper Functions
  defp get_loop_data(step, context) do
    case step["data_source"] do
      nil ->
        {:error, "For loop requires 'data_source' field"}

      data_source ->
        case resolve_data_source(data_source, context) do
          {:ok, data} when is_list(data) -> {:ok, data}
          {:ok, data} -> {:error, "Data source must resolve to a list, got: #{inspect(data)}"}
          error -> error
        end
    end
  end

  defp get_iterator_name(step) do
    case step["iterator"] do
      nil -> {:error, "For loop requires 'iterator' field"}
      iterator when is_binary(iterator) -> {:ok, iterator}
      _ -> {:error, "Iterator must be a string"}
    end
  end

  defp get_while_condition(step) do
    case step["condition"] do
      nil -> {:error, "While loop requires 'condition' field"}
      condition when is_binary(condition) -> {:ok, condition}
      _ -> {:error, "Condition must be a string"}
    end
  end

  defp get_sub_steps(step) do
    case step["steps"] do
      nil -> {:error, "Loop requires 'steps' field"}
      steps when is_list(steps) -> {:ok, steps}
      _ -> {:error, "Steps must be a list"}
    end
  end

  defp get_max_iterations(step) do
    case step["max_iterations"] do
      nil ->
        @default_max_iterations

      max when is_integer(max) and max > 0 and max <= @max_iterations ->
        max

      max when is_integer(max) and max > @max_iterations ->
        Logger.warning(
          "⚠️  Requested max_iterations #{max} exceeds limit, using #{@max_iterations}"
        )

        @max_iterations

      _ ->
        @default_max_iterations
    end
  end

  defp resolve_data_source(data_source, context) do
    case String.split(data_source, ":", parts: 2) do
      ["previous_response", field] ->
        case get_in(context.results, ["previous_response"]) do
          nil ->
            {:error, "No previous_response found"}

          previous_result ->
            case get_nested_value(previous_result, field) do
              nil -> {:error, "Data source field not found: #{field}"}
              value -> {:ok, value}
            end
        end

      ["previous_response"] ->
        case Map.get(context.results, "previous_response") do
          nil -> {:error, "No previous_response found"}
          value -> {:ok, value}
        end

      [step_name, field] ->
        # First try to get from current loop context
        case get_in(context.results, ["loop", step_name]) do
          nil ->
            # Fall back to step results
            case get_in(context.results, [step_name]) do
              nil ->
                {:error, "Step result not found: #{step_name}"}

              step_result ->
                case get_nested_value(step_result, field) do
                  nil -> {:error, "Field not found in step result: #{field}"}
                  value -> {:ok, value}
                end
            end

          loop_value ->
            case get_nested_value(loop_value, field) do
              nil -> {:error, "Field not found in loop context: #{field}"}
              value -> {:ok, value}
            end
        end

      [step_name] ->
        # First try to get from variable state
        case Map.get(context, :variable_state) do
          nil ->
            # Fall back to step results
            case get_in(context.results, [step_name]) do
              nil -> {:error, "Step result not found: #{step_name}"}
              value -> {:ok, value}
            end

          variable_state ->
            # Check if it's a variable - handle case where variable state doesn't have expected structure
            try do
              case Pipeline.State.VariableEngine.get_variable(variable_state, step_name) do
                nil ->
                  # Fall back to step results
                  case get_in(context.results, [step_name]) do
                    nil -> {:error, "Step result not found: #{step_name}"}
                    value -> {:ok, value}
                  end

                variable_value ->
                  {:ok, variable_value}
              end
            rescue
              _ ->
                # Variable state access failed, fall back to step results
                case get_in(context.results, [step_name]) do
                  nil -> {:error, "Step result not found: #{step_name}"}
                  value -> {:ok, value}
                end
            end
        end

      _ ->
        {:error, "Invalid data_source format: #{data_source}"}
    end
  end

  defp get_nested_value(map, field_path) when is_map(map) do
    fields = String.split(field_path, ".")
    get_in(map, fields)
  end

  defp get_nested_value(_value, _field_path), do: nil

  # Enhanced loop context with nested support
  def create_nested_loop_context(iterator_name, item, index, total, context) do
    # Check if we're already in a loop (nested scenario)
    case get_in(context.results, ["loop"]) do
      nil ->
        # First level loop
        %{
          "loop" => %{
            iterator_name => item,
            "index" => index,
            "total" => total,
            "first" => index == 0,
            "last" => index == total - 1,
            "level" => 0
          }
        }

      parent_loop ->
        # Nested loop - preserve parent context
        %{
          "loop" => %{
            iterator_name => item,
            "index" => index,
            "total" => total,
            "first" => index == 0,
            "last" => index == total - 1,
            "level" => (parent_loop["level"] || 0) + 1,
            "parent" => parent_loop
          }
        }
    end
  end

  defp create_while_loop_context(iteration_count) do
    %{
      "loop" => %{
        "iteration" => iteration_count,
        "count" => iteration_count
      }
    }
  end

  defp add_loop_context(context, loop_context) do
    # Merge loop context into the context results for template access
    updated_results = Map.merge(context.results, loop_context)
    %{context | results: updated_results}
  end

  defp execute_sub_steps(sub_steps, context) do
    # Execute sub-steps similar to main pipeline execution
    sub_steps
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, context}, fn {sub_step, index}, {:ok, acc_context} ->
      Logger.info("  🔗 Executing sub-step #{index + 1}: #{sub_step["name"]}")

      case do_execute_step(sub_step, acc_context) do
        {:ok, result} ->
          # Update context with sub-step result
          updated_context = %{
            acc_context
            | results: Map.put(acc_context.results, sub_step["name"], result)
          }

          {:cont, {:ok, updated_context}}

        {:ok, result, updated_context} ->
          # Handle 3-tuple return (e.g., from set_variable)
          final_context = %{
            updated_context
            | results: Map.put(updated_context.results, sub_step["name"], result)
          }

          {:cont, {:ok, final_context}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  # Execute a single step - similar to executor logic but simplified
  defp do_execute_step(step, context) do
    case step["type"] do
      "claude" ->
        Pipeline.Step.Claude.execute(step, context)

      "gemini" ->
        Pipeline.Step.Gemini.execute(step, context)

      "parallel_claude" ->
        Pipeline.Step.ParallelClaude.execute(step, context)

      "gemini_instructor" ->
        Pipeline.Step.GeminiInstructor.execute(step, context)

      "claude_smart" ->
        Pipeline.Step.ClaudeSmart.execute(step, context)

      "claude_session" ->
        Pipeline.Step.ClaudeSession.execute(step, context)

      "claude_extract" ->
        Pipeline.Step.ClaudeExtract.execute(step, context)

      "claude_batch" ->
        Pipeline.Step.ClaudeBatch.execute(step, context)

      "claude_robust" ->
        Pipeline.Step.ClaudeRobust.execute(step, context)

      "set_variable" ->
        Pipeline.Step.SetVariable.execute(step, context)

      # Nested loops are supported
      "for_loop" ->
        execute_for_loop(step, context)

      "while_loop" ->
        execute_while_loop(step, context)

      # Loop control steps
      "break" ->
        {:break, "Loop break requested"}

      "continue" ->
        {:continue, "Loop continue requested"}

      unknown_type ->
        {:error, "Unsupported step type in loop: #{unknown_type}"}
    end
  end

  defp extract_sub_step_results(sub_steps, context) do
    sub_steps
    |> Enum.map(fn step ->
      step_name = step["name"]
      {step_name, Map.get(context.results, step_name)}
    end)
    |> Map.new()
  end

  defp merge_context_results(base_context, iteration_context) do
    # Merge iteration results back into base context, excluding loop context
    iteration_results = Map.drop(iteration_context.results, ["loop"])
    merged_results = Map.merge(base_context.results, iteration_results)
    %{base_context | results: merged_results}
  end

  defp evaluate_condition(condition, context) do
    try do
      ConditionEngine.evaluate(condition, context)
    rescue
      error ->
        Logger.error("❌ Condition evaluation error: #{inspect(error)}")
        {:error, "Condition evaluation failed: #{inspect(error)}"}
    end
  end

  # Loop Control Functions
  defp check_loop_control(step, context) do
    cond do
      step["break_condition"] && evaluate_simple_condition(step["break_condition"], context) ->
        :break

      step["continue_condition"] && evaluate_simple_condition(step["continue_condition"], context) ->
        :continue

      true ->
        :normal
    end
  end

  defp evaluate_simple_condition(condition, context) do
    case evaluate_condition(condition, context) do
      true -> true
      false -> false
      _ -> false
    end
  end

  # Parallel Execution Helpers
  defp get_max_parallel(step) do
    case step["max_parallel"] do
      nil -> @default_max_parallel
      max when is_integer(max) and max > 0 -> min(max, 10)
      _ -> @default_max_parallel
    end
  end

  # Memory Management
  defp check_memory_usage(current_index, total_items) do
    memory = :erlang.memory(:total)
    memory_mb = div(memory, 1_000_000)
    threshold_mb = div(@memory_threshold, 1_000_000)

    cond do
      memory > @memory_threshold ->
        Logger.warning(
          "🚨 High memory usage detected at iteration #{current_index}/#{total_items}: #{memory_mb}MB > #{threshold_mb}MB"
        )

        # Force garbage collection
        :erlang.garbage_collect()

        # Optional: pause for memory to be freed
        Process.sleep(10)

        # Check memory again after GC
        new_memory = :erlang.memory(:total)
        new_memory_mb = div(new_memory, 1_000_000)

        if new_memory > @memory_threshold * 0.9 do
          Logger.error("❌ Memory usage still high after GC: #{new_memory_mb}MB")
          {:error, "Memory threshold exceeded: #{new_memory_mb}MB"}
        else
          Logger.info("✅ Memory freed by GC: #{memory_mb}MB -> #{new_memory_mb}MB")
          :ok
        end

      memory > @memory_threshold * 0.7 ->
        Logger.info(
          "⚠️  Memory usage approaching threshold at iteration #{current_index}/#{total_items}: #{memory_mb}MB"
        )

        :ok

      rem(current_index, @gc_interval) == 0 ->
        # Periodic GC for long-running loops
        :erlang.garbage_collect()
        Logger.debug("🧹 Periodic garbage collection at iteration #{current_index}")
        :ok

      true ->
        :ok
    end
  end

  defp should_use_streaming_mode?(data_size) do
    data_size > @large_dataset_threshold
  end

  defp optimize_loop_execution(data, iterator_name, sub_steps, step, context) do
    data_size = length(data)

    cond do
      should_use_streaming_mode?(data_size) ->
        Logger.info("📊 Using streaming mode for large dataset: #{data_size} items")
        execute_streaming_for_loop(data, iterator_name, sub_steps, step, context)

      step["parallel"] && data_size > 10 ->
        Logger.info("🚀 Using parallel execution for #{data_size} items")
        execute_parallel_for_loop(data, iterator_name, sub_steps, step, context)

      true ->
        execute_for_loop_iterations(data, iterator_name, sub_steps, step, context)
    end
  end

  # Streaming execution for very large datasets
  defp execute_streaming_for_loop(data, iterator_name, sub_steps, step, context) do
    batch_size = get_batch_size(step, length(data))

    Logger.info("📊 Processing #{length(data)} items in batches of #{batch_size}")

    initial_results = %{
      "iterations" => [],
      "success" => true,
      "total_items" => length(data),
      "completed_items" => 0,
      "batches_processed" => 0
    }

    data
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, initial_results, context}, fn {batch, batch_index},
                                                             {:ok, acc_results, acc_context} ->
      Logger.info("📊 Processing batch #{batch_index + 1}/#{div(length(data), batch_size) + 1}")

      case process_streaming_batch(
             batch,
             iterator_name,
             sub_steps,
             step,
             acc_context,
             batch_index * batch_size
           ) do
        {:ok, batch_results, updated_context} ->
          # Merge batch results
          merged_results = merge_batch_results(acc_results, batch_results)

          # Memory check after each batch
          case check_memory_usage(batch_index * batch_size, length(data)) do
            :ok ->
              {:cont, {:ok, merged_results, updated_context}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end
      end
    end)
    |> case do
      {:ok, final_results, _final_context} -> {:ok, final_results}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_streaming_batch(batch, iterator_name, sub_steps, _step, context, start_index) do
    batch_results =
      batch
      |> Enum.with_index()
      |> Enum.map(fn {item, rel_index} ->
        abs_index = start_index + rel_index

        # Create loop context
        loop_context =
          create_nested_loop_context(iterator_name, item, abs_index, length(batch), context)

        updated_context = add_loop_context(context, loop_context)

        case execute_sub_steps(sub_steps, updated_context) do
          {:ok, iteration_context} ->
            %{
              "index" => abs_index,
              "item" => item,
              "success" => true,
              "results" => extract_sub_step_results(sub_steps, iteration_context)
            }

          {:error, reason} ->
            Logger.error("❌ Batch iteration #{abs_index + 1} failed: #{reason}")

            %{
              "index" => abs_index,
              "item" => item,
              "success" => false,
              "error" => reason
            }
        end
      end)

    completed_count = Enum.count(batch_results, & &1["success"])
    all_successful = Enum.all?(batch_results, & &1["success"])

    batch_summary = %{
      "iterations" => batch_results,
      "success" => all_successful,
      "completed_items" => completed_count,
      "batches_processed" => 1
    }

    {:ok, batch_summary, context}
  end

  defp merge_batch_results(acc_results, batch_results) do
    %{
      acc_results
      | "iterations" => acc_results["iterations"] ++ batch_results["iterations"],
        "completed_items" => acc_results["completed_items"] + batch_results["completed_items"],
        "batches_processed" =>
          acc_results["batches_processed"] + batch_results["batches_processed"],
        "success" => acc_results["success"] && batch_results["success"]
    }
  end

  defp get_batch_size(step, total_items) do
    configured_size = step["batch_size"] || nil

    cond do
      is_integer(configured_size) && configured_size > 0 ->
        min(configured_size, total_items)

      total_items > 10000 ->
        # Large datasets
        100

      total_items > 1000 ->
        # Medium datasets
        50

      true ->
        # Small datasets
        25
    end
  end
end
