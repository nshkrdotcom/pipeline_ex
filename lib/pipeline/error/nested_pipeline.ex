defmodule Pipeline.Error.NestedPipeline do
  @moduledoc """
  Enhanced error formatting and context tracking for nested pipeline execution.

  Provides comprehensive error messages with full execution stack traces,
  pipeline hierarchy, and relevant context information for debugging
  nested pipeline failures.
  """

  require Logger
  alias Pipeline.Safety.RecursionGuard

  @type error_context :: %{
          pipeline_id: String.t(),
          step_name: String.t() | nil,
          nesting_depth: non_neg_integer(),
          execution_chain: [String.t()],
          start_time: DateTime.t(),
          elapsed_ms: non_neg_integer(),
          total_steps: non_neg_integer(),
          step_index: non_neg_integer() | nil,
          parent_context: error_context() | nil
        }

  @type formatted_error :: %{
          message: String.t(),
          context: error_context(),
          stack_trace: [String.t()],
          hierarchy: String.t(),
          debug_info: map()
        }

  @doc """
  Format a nested pipeline error with comprehensive context information.

  ## Parameters
  - `error`: The original error (string, exception, or error tuple)
  - `context`: Current execution context
  - `step`: Current step configuration (optional)

  ## Returns
  - Formatted error with full context information

  ## Examples

      iex> context = %{nesting_depth: 1, pipeline_id: "child", parent_context: %{pipeline_id: "parent", nesting_depth: 0}}
      iex> formatted = Pipeline.Error.NestedPipeline.format_nested_error("API timeout", context)
      iex> String.contains?(formatted.message, "parent → child")
      true
  """
  @spec format_nested_error(any(), map(), map() | nil) :: formatted_error()
  def format_nested_error(error, context, step \\ nil) do
    error_context = build_error_context(context, step)
    execution_chain = RecursionGuard.build_execution_chain(context)
    hierarchy = format_pipeline_hierarchy(execution_chain, context)

    base_message = extract_base_error_message(error)

    formatted_message = """
    Pipeline execution failed in nested pipeline:

    #{hierarchy}

    Error: #{base_message}

    Execution Context:
      - Pipeline: #{error_context.pipeline_id}
      - Step: #{error_context.step_name || "unknown"}
      - Nesting Depth: #{error_context.nesting_depth}
      - Total Steps Executed: #{error_context.total_steps}
      - Elapsed Time: #{error_context.elapsed_ms}ms
      - Step Index: #{error_context.step_index || "unknown"}

    Execution Stack:
    #{format_execution_stack(execution_chain, context)}
    """

    debug_info = collect_debug_info(error, context, step)

    %{
      message: String.trim(formatted_message),
      context: error_context,
      stack_trace: execution_chain,
      hierarchy: hierarchy,
      debug_info: debug_info
    }
  end

  @doc """
  Format a timeout error with execution context.

  ## Parameters
  - `timeout_seconds`: The timeout that was exceeded
  - `context`: Current execution context
  - `elapsed_ms`: Actual elapsed time in milliseconds

  ## Returns
  - Formatted timeout error message
  """
  @spec format_timeout_error(non_neg_integer(), map(), non_neg_integer()) :: String.t()
  def format_timeout_error(timeout_seconds, context, elapsed_ms) do
    safe_context = ensure_safe_context(context)
    execution_chain = RecursionGuard.build_execution_chain(safe_context)
    hierarchy = format_pipeline_hierarchy(execution_chain, context)
    elapsed_seconds = Float.round(elapsed_ms / 1000, 1)

    """
    Pipeline execution timeout in nested pipeline:

    #{hierarchy}

    Timeout Details:
      - Limit: #{timeout_seconds}s
      - Actual: #{elapsed_seconds}s
      - Exceeded by: #{elapsed_seconds - timeout_seconds}s

    Execution Context:
      - Pipeline: #{context.pipeline_id}
      - Nesting Depth: #{Map.get(context, :nesting_depth, 0)}
      - Total Steps: #{RecursionGuard.count_total_steps(safe_context)}

    This timeout may indicate:
      - Long-running AI model calls
      - Network connectivity issues
      - Inefficient pipeline design
      - Need for timeout configuration adjustment
    """
    |> String.trim()
  end

  @doc """
  Format a circular dependency error with the detected cycle.

  ## Parameters
  - `circular_chain`: List of pipeline IDs forming the circular dependency
  - `context`: Current execution context

  ## Returns
  - Formatted circular dependency error message
  """
  @spec format_circular_dependency_error([String.t()], map()) :: String.t()
  def format_circular_dependency_error(circular_chain, context) do
    cycle_display = Enum.join(circular_chain, " → ")
    safe_context = ensure_safe_context(context)
    execution_chain = RecursionGuard.build_execution_chain(safe_context)
    hierarchy = format_pipeline_hierarchy(execution_chain, context)

    """
    Circular dependency detected in nested pipeline execution:

    #{hierarchy}

    Circular Chain:
      #{cycle_display}

    Resolution Steps:
      1. Review pipeline dependencies in the chain above
      2. Remove or restructure circular references
      3. Consider using conditional logic to break cycles
      4. Verify pipeline_file and pipeline_ref configurations

    Execution Context:
      - Current Pipeline: #{context.pipeline_id}
      - Nesting Depth: #{Map.get(context, :nesting_depth, 0)}
      - Detection Point: Attempting to call '#{List.first(circular_chain)}'
    """
    |> String.trim()
  end

  @doc """
  Format a resource limit error with current usage information.

  ## Parameters
  - `limit_type`: Type of limit exceeded (:memory, :depth, :steps)
  - `current_value`: Current resource usage
  - `limit_value`: The limit that was exceeded
  - `context`: Current execution context

  ## Returns
  - Formatted resource limit error message
  """
  @spec format_resource_limit_error(atom(), any(), any(), map()) :: String.t()
  def format_resource_limit_error(limit_type, current_value, limit_value, context) do
    safe_context = ensure_safe_context(context)
    execution_chain = RecursionGuard.build_execution_chain(safe_context)
    hierarchy = format_pipeline_hierarchy(execution_chain, context)

    limit_description =
      case limit_type do
        :memory -> "Memory usage: #{current_value}MB > #{limit_value}MB limit"
        :depth -> "Nesting depth: #{current_value} > #{limit_value} levels"
        :steps -> "Total steps: #{current_value} > #{limit_value} steps"
        _ -> "Resource limit exceeded: #{current_value} > #{limit_value}"
      end

    recommendations =
      case limit_type do
        :memory ->
          [
            "Review pipeline for memory-intensive operations",
            "Consider breaking large pipelines into smaller chunks",
            "Increase memory_limit_mb in configuration if appropriate",
            "Check for memory leaks in custom step implementations"
          ]

        :depth ->
          [
            "Reduce pipeline nesting levels",
            "Consider flattening nested pipeline structures",
            "Increase max_depth in configuration if deep nesting is required",
            "Review pipeline composition for optimization opportunities"
          ]

        :steps ->
          [
            "Optimize pipeline step count",
            "Remove unnecessary steps or combine related operations",
            "Increase max_total_steps in configuration if needed",
            "Consider parallel execution for independent operations"
          ]

        _ ->
          ["Review resource usage and configuration"]
      end

    """
    Resource limit exceeded in nested pipeline execution:

    #{hierarchy}

    Limit Violation:
      #{limit_description}

    Recommendations:
    #{Enum.map_join(recommendations, "\n", fn rec -> "  • #{rec}" end)}

    Execution Context:
      - Pipeline: #{context.pipeline_id}
      - Nesting Depth: #{Map.get(context, :nesting_depth, 0)}
      - Total Steps: #{RecursionGuard.count_total_steps(safe_context)}
    """
    |> String.trim()
  end

  @doc """
  Create a structured error log entry for debugging.

  ## Parameters
  - `error`: The error that occurred
  - `context`: Current execution context
  - `step`: Current step configuration (optional)

  ## Returns
  - Structured log entry map
  """
  @spec create_debug_log_entry(any(), map(), map() | nil) :: map()
  def create_debug_log_entry(error, context, step \\ nil) do
    safe_context = ensure_safe_context(context)

    %{
      timestamp: DateTime.utc_now(),
      error_type: classify_error_type(error),
      error_message: extract_base_error_message(error),
      pipeline_id: context.pipeline_id || "unknown",
      nesting_depth: Map.get(context, :nesting_depth, 0),
      step_name: get_step_name(step),
      step_type: get_step_type(step),
      execution_chain: RecursionGuard.build_execution_chain(safe_context),
      total_steps: RecursionGuard.count_total_steps(safe_context),
      elapsed_ms: calculate_elapsed_time(context),
      context_summary: summarize_context(context),
      step_config: sanitize_step_config(step)
    }
  end

  # Private helper functions

  defp build_error_context(context, step) do
    # Create a safe context structure for RecursionGuard functions
    safe_context = ensure_safe_context(context)

    %{
      pipeline_id: context.pipeline_id || "unknown",
      step_name: get_step_name(step),
      nesting_depth: Map.get(context, :nesting_depth, 0),
      execution_chain: RecursionGuard.build_execution_chain(safe_context),
      start_time: Map.get(context, :start_time, DateTime.utc_now()),
      elapsed_ms: calculate_elapsed_time(context),
      total_steps: RecursionGuard.count_total_steps(safe_context),
      step_index: Map.get(context, :step_index),
      parent_context: context[:parent_context]
    }
  end

  defp format_pipeline_hierarchy(execution_chain, context) do
    depth = Map.get(context, :nesting_depth, 0)

    case execution_chain do
      [single] when depth == 0 ->
        "Main Pipeline: #{single}"

      chain ->
        formatted_chain =
          chain
          |> Enum.reverse()
          |> Enum.with_index()
          |> Enum.map_join("\n", fn {pipeline, index} ->
            indent = String.duplicate("  ", index)

            if index == 0 do
              "#{indent}Main Pipeline: #{pipeline}"
            else
              arrow = if index == length(chain) - 1, do: "└─", else: "├─"
              "#{indent}#{arrow} Nested Pipeline: #{pipeline} (depth: #{index})"
            end
          end)

        formatted_chain
    end
  end

  defp format_execution_stack(execution_chain, _context) do
    chain = Enum.reverse(execution_chain)

    chain
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {pipeline, index} ->
      depth = index - 1
      "    #{index}. #{pipeline} (depth: #{depth})"
    end)
  end

  def extract_base_error_message(error) do
    case error do
      {:error, message} when is_binary(message) -> message
      {:error, %{message: message}} -> message
      {:error, reason} -> inspect(reason)
      %{message: message} -> message
      message when is_binary(message) -> message
      other -> inspect(other)
    end
  end

  defp collect_debug_info(error, context, step) do
    %{
      error_classification: classify_error_type(error),
      context_keys: Map.keys(context),
      step_configuration: sanitize_step_config(step),
      memory_usage: get_memory_usage(),
      system_info: get_system_info(),
      pipeline_metadata: extract_pipeline_metadata(context)
    }
  end

  defp classify_error_type(error) do
    error_message = extract_base_error_message(error)

    cond do
      String.contains?(error_message, "timeout") or String.contains?(error_message, "Timeout") ->
        :timeout

      String.contains?(error_message, "circular dependency") or
          String.contains?(error_message, "Circular") ->
        :circular_dependency

      String.contains?(error_message, "limit exceeded") or
          String.contains?(error_message, "Maximum") ->
        :resource_limit

      String.contains?(error_message, "not found") or String.contains?(error_message, "missing") ->
        :not_found

      String.contains?(error_message, "invalid") or String.contains?(error_message, "Invalid") ->
        :validation

      true ->
        :unknown
    end
  end

  defp get_step_name(nil), do: nil
  defp get_step_name(step), do: Map.get(step, "name")

  defp get_step_type(nil), do: nil
  defp get_step_type(step), do: Map.get(step, "type")

  defp calculate_elapsed_time(context) do
    case Map.get(context, :start_time) do
      nil -> 0
      start_time -> DateTime.diff(DateTime.utc_now(), start_time, :millisecond)
    end
  end

  defp summarize_context(context) do
    %{
      has_parent: context[:parent_context] != nil,
      context_size: map_size(context),
      key_count: length(Map.keys(context)),
      nesting_depth: Map.get(context, :nesting_depth, 0)
    }
  end

  defp sanitize_step_config(nil), do: nil

  defp sanitize_step_config(step) do
    step
    |> Map.take(["name", "type", "condition", "config"])
    |> Map.update("config", %{}, fn config ->
      if is_map(config) do
        Map.take(config, ["inherit_context", "max_depth", "timeout_seconds"])
      else
        config
      end
    end)
  end

  defp get_memory_usage do
    try do
      :erlang.memory(:total)
    rescue
      _ -> nil
    end
  end

  defp get_system_info do
    %{
      node: Node.self(),
      process_count: length(Process.list()),
      version: System.version()
    }
  end

  defp extract_pipeline_metadata(context) do
    %{
      pipeline_id: context.pipeline_id,
      has_results: Map.has_key?(context, :results),
      results_count: if(Map.has_key?(context, :results), do: map_size(context.results), else: 0),
      has_global_vars: Map.has_key?(context, :global_vars)
    }
  end

  defp ensure_safe_context(context) do
    %{
      pipeline_id: context.pipeline_id || "unknown",
      nesting_depth: Map.get(context, :nesting_depth, 0),
      step_count: Map.get(context, :step_count, 0),
      parent_context:
        case Map.get(context, :parent_context) do
          nil -> nil
          parent -> ensure_safe_context(parent)
        end
    }
  end
end
