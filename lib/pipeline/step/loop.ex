defmodule Pipeline.Step.Loop do
  @moduledoc """
  Loop step executor - handles for_loop and while_loop operations.

  Provides iteration capabilities with sub-step execution and loop context management.
  """

  require Logger
  alias Pipeline.Condition.Engine, as: ConditionEngine

  @max_iterations 1000
  @default_max_iterations 100

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
      execute_for_loop_iterations(data, iterator_name, sub_steps, step, context)
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
  defp execute_for_loop_iterations(data, iterator_name, sub_steps, _step, context)
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
      |> Enum.reduce({initial_results, context}, fn {item, index}, {acc_results, acc_context} ->
        Logger.info("🔄 Processing item #{index + 1}/#{length(data)}")

        # Create loop context
        loop_context = create_loop_context(iterator_name, item, index, length(data))
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

            {updated_results, merge_context_results(acc_context, iteration_context)}

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

            {updated_results, acc_context}
        end
      end)

    # Reverse iterations to maintain order
    final_results = %{final_results | "iterations" => Enum.reverse(final_results["iterations"])}

    Logger.info(
      "✅ For loop completed: #{final_results["completed_items"]}/#{final_results["total_items"]} items"
    )

    {:ok, final_results}
  end

  defp execute_for_loop_iterations(data, _iterator_name, _sub_steps, _step, _context) do
    {:error, "For loop data must be a list, got: #{inspect(data)}"}
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
        case get_in(context.results, [step_name]) do
          nil ->
            {:error, "Step result not found: #{step_name}"}

          step_result ->
            case get_nested_value(step_result, field) do
              nil -> {:error, "Field not found in step result: #{field}"}
              value -> {:ok, value}
            end
        end

      [step_name] ->
        case get_in(context.results, [step_name]) do
          nil -> {:error, "Step result not found: #{step_name}"}
          value -> {:ok, value}
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

  defp create_loop_context(iterator_name, item, index, total) do
    %{
      "loop" => %{
        iterator_name => item,
        "index" => index,
        "total" => total,
        "first" => index == 0,
        "last" => index == total - 1
      }
    }
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

      # Nested loops are supported
      "for_loop" ->
        execute_for_loop(step, context)

      "while_loop" ->
        execute_while_loop(step, context)

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
    case ConditionEngine.evaluate(condition, context) do
      true -> true
      false -> false
      {:error, reason} -> {:error, reason}
      _ -> false
    end
  end
end
