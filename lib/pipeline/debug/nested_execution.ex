defmodule Pipeline.Debug.NestedExecution do
  @moduledoc """
  Debugging tools and utilities for nested pipeline execution.

  Provides interactive debugging capabilities, execution analysis,
  and troubleshooting tools for complex nested pipeline workflows.
  """

  require Logger
  alias Pipeline.Safety.RecursionGuard
  alias Pipeline.Tracing.NestedExecution
  alias Pipeline.Error.NestedPipeline

  @type debug_session :: %{
          trace_context: map(),
          execution_tree: map(),
          debug_options: map(),
          session_id: String.t(),
          start_time: DateTime.t(),
          commands_history: [String.t()]
        }

  @type analysis_result :: %{
          performance_issues: [map()],
          potential_optimizations: [String.t()],
          error_patterns: [map()],
          resource_usage: map(),
          recommendations: [String.t()]
        }

  @doc """
  Start an interactive debugging session for a trace context.

  ## Parameters
  - `trace_context`: The trace context to debug
  - `options`: Debug session options

  ## Returns
  - Debug session context
  """
  @spec start_debug_session(map(), map()) :: debug_session()
  def start_debug_session(trace_context, options \\ %{}) do
    session_id = generate_session_id()
    execution_tree = NestedExecution.build_execution_tree(trace_context)

    session = %{
      trace_context: trace_context,
      execution_tree: execution_tree,
      debug_options: Map.merge(default_debug_options(), options),
      session_id: session_id,
      start_time: DateTime.utc_now(),
      commands_history: []
    }

    Logger.info("🐛 Started debug session [#{session_id}] for trace #{trace_context.trace_id}")

    session
  end

  @doc """
  Print comprehensive execution tree with debugging information.

  ## Parameters
  - `context`: Execution context or debug session
  - `options`: Display options

  ## Returns
  - Formatted debug output
  """
  @spec debug_execution_tree(map(), map()) :: String.t()
  def debug_execution_tree(context, options \\ %{}) do
    execution_tree =
      cond do
        Map.has_key?(context, :execution_tree) ->
          context.execution_tree

        # Check if this is already an execution tree structure FIRST
        Map.has_key?(context, :pipeline_id) && Map.has_key?(context, :children) &&
          Map.has_key?(context, :total_duration_ms) && Map.has_key?(context, :step_count) ->
          context

        Map.has_key?(context, :spans) && is_map(context.spans) ->
          NestedExecution.build_execution_tree(context)

        Map.has_key?(context, :spans) && is_list(context.spans) ->
          build_tree_from_spans_list(context.spans)

        true ->
          build_tree_from_context(context)
      end

    show_metadata = Map.get(options, :show_metadata, false)
    show_errors = Map.get(options, :show_errors, true)
    show_performance = Map.get(options, :show_performance, true)
    max_depth = Map.get(options, :max_depth, 10)

    output = [
      format_tree_header(execution_tree),
      format_tree_recursive(
        execution_tree,
        0,
        show_metadata,
        show_errors,
        show_performance,
        max_depth
      ),
      format_tree_summary(execution_tree)
    ]

    Enum.join(output, "\n")
  end

  @doc """
  Analyze execution for performance issues and optimization opportunities.

  ## Parameters
  - `execution_tree`: The execution tree to analyze
  - `options`: Analysis options

  ## Returns
  - Analysis results with issues and recommendations
  """
  @spec analyze_execution(map(), map()) :: analysis_result()
  def analyze_execution(execution_tree, options \\ %{}) do
    all_spans = collect_all_spans(execution_tree)
    performance_summary = NestedExecution.generate_performance_summary(execution_tree)

    # Analyze for various issues
    performance_issues = detect_performance_issues(all_spans, performance_summary)
    error_patterns = analyze_error_patterns(all_spans)
    resource_usage = analyze_resource_usage(all_spans, performance_summary)
    optimizations = suggest_optimizations(execution_tree, performance_summary, options)
    recommendations = generate_recommendations(performance_issues, error_patterns, resource_usage)

    %{
      performance_issues: performance_issues,
      potential_optimizations: optimizations,
      error_patterns: error_patterns,
      resource_usage: resource_usage,
      recommendations: recommendations
    }
  end

  @doc """
  Generate a debugging report for troubleshooting.

  ## Parameters
  - `trace_context`: The trace context to analyze
  - `error`: Optional error that occurred
  - `options`: Report generation options

  ## Returns
  - Comprehensive debugging report
  """
  @spec generate_debug_report(map(), any(), map()) :: String.t()
  def generate_debug_report(trace_context, error \\ nil, options \\ %{}) do
    execution_tree = NestedExecution.build_execution_tree(trace_context)
    analysis = analyze_execution(execution_tree, options)

    sections = [
      format_report_header(trace_context, error),
      format_execution_summary(execution_tree),
      format_performance_analysis(analysis),
      format_error_analysis(error, analysis),
      format_recommendations(analysis),
      format_debug_commands()
    ]

    Enum.join(sections, "\n\n" <> String.duplicate("=", 80) <> "\n\n")
  end

  @doc """
  Show context information at a specific point in execution.

  ## Parameters
  - `context`: Execution context to inspect
  - `step`: Optional step information

  ## Returns
  - Formatted context information
  """
  @spec inspect_context(map(), map()) :: String.t()
  def inspect_context(context, step \\ nil) do
    """
    Context Inspection:
    ==================

    Pipeline: #{context.pipeline_id || "unknown"}
    Nesting Depth: #{Map.get(context, :nesting_depth, 0)}
    Step Index: #{Map.get(context, :step_index, "unknown")}

    #{if step, do: format_step_info(step), else: ""}

    Context Keys: #{inspect(Map.keys(context))}

    Results Available:
    #{format_results_summary(context)}

    Global Variables:
    #{format_global_vars(context)}

    Execution Chain:
    #{format_execution_chain(context)}

    Memory Usage: #{format_memory_usage()}
    """
  end

  @doc """
  Compare execution performance between different traces.

  ## Parameters
  - `trace_contexts`: List of trace contexts to compare
  - `options`: Comparison options

  ## Returns
  - Formatted comparison report
  """
  @spec compare_executions([map()], map()) :: String.t()
  def compare_executions(trace_contexts, _options \\ %{}) do
    if length(trace_contexts) < 2 do
      "At least 2 performance metrics required for comparison"
    else
      summaries =
        Enum.map(trace_contexts, fn context ->
          tree = NestedExecution.build_execution_tree(context)

          {Map.get(context, :trace_id, "unknown"),
           NestedExecution.generate_performance_summary(tree)}
        end)

      format_comparison_report(summaries)
    end
  end

  defp format_comparison_report(summaries) do
    """
    📊 PERFORMANCE COMPARISON
    ========================

    Executions Compared: #{length(summaries)}

    #{format_comparison_table(summaries)}

    Performance Insights:
    #{format_performance_insights(summaries)}

    Recommendations:
    #{format_comparison_recommendations(summaries)}
    """
  end

  @doc """
  Search for specific patterns in execution traces.

  ## Parameters
  - `trace_context`: Trace context to search
  - `pattern`: Search pattern (string or regex)
  - `search_in`: What to search in (:pipeline_ids, :step_names, :errors, :all)

  ## Returns
  - List of matching spans with context
  """
  @spec search_execution(map(), String.t() | Regex.t(), atom()) :: [map()]
  def search_execution(trace_context, pattern, search_in \\ :all) do
    all_spans = Map.values(trace_context.spans)

    matching_spans =
      Enum.filter(all_spans, fn span ->
        case search_in do
          :pipeline_ids ->
            matches_pattern?(span.pipeline_id, pattern)

          :step_names ->
            matches_pattern?(span.step_name, pattern)

          :errors ->
            matches_pattern?(span.error, pattern)

          :all ->
            matches_pattern?(span.pipeline_id, pattern) ||
              matches_pattern?(span.step_name, pattern) ||
              matches_pattern?(span.error, pattern)

          _ ->
            false
        end
      end)

    Enum.map(matching_spans, fn span ->
      %{
        span: span,
        context: format_span_context(span, trace_context),
        match_info: determine_match_info(span, pattern, search_in)
      }
    end)
  end

  # Private helper functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end

  defp default_debug_options do
    %{
      show_metadata: false,
      show_errors: true,
      show_performance: true,
      max_depth: 10,
      include_successful_spans: true,
      include_failed_spans: true
    }
  end

  defp build_tree_from_context(context) do
    # For contexts that don't have tracing info, build a minimal tree
    # Handle cases where we have execution context but not tracing spans
    duration =
      case Map.get(context, :total_duration_ms) do
        nil ->
          case {Map.get(context, :start_time), Map.get(context, :end_time)} do
            {start_time, end_time} when not is_nil(start_time) and not is_nil(end_time) ->
              DateTime.diff(end_time, start_time, :millisecond)

            # Default 1 second for unknown
            _ ->
              1000
          end

        duration ->
          duration
      end

    %{
      pipeline_id: context.pipeline_id || "unknown",
      spans: [create_minimal_span_from_context(context)],
      children: [],
      total_duration_ms: duration,
      step_count: 1,
      max_depth: Map.get(context, :nesting_depth, 0)
    }
  end

  defp create_minimal_span_from_context(context) do
    %{
      id: "context_span",
      pipeline_id: context.pipeline_id || "unknown",
      step_name: nil,
      status: :completed,
      duration_ms:
        case Map.get(context, :total_duration_ms) do
          # Default duration
          nil -> 1000
          duration -> duration
        end,
      depth: Map.get(context, :nesting_depth, 0),
      start_time: Map.get(context, :start_time, DateTime.utc_now()),
      error: nil
    }
  end

  defp build_tree_from_spans_list(spans) do
    # Handle test contexts where spans is a list instead of a map
    first_span = List.first(spans) || %{}
    total_duration = Enum.sum(Enum.map(spans, &Map.get(&1, :duration_ms, 0)))
    max_depth = Enum.map(spans, &Map.get(&1, :depth, 0)) |> Enum.max(fn -> 0 end)

    %{
      pipeline_id: Map.get(first_span, :pipeline_id, "unknown"),
      spans: spans,
      children: [],
      total_duration_ms: total_duration,
      step_count: length(spans),
      max_depth: max_depth
    }
  end

  defp format_tree_header(execution_tree) do
    """
    🌳 Execution Tree Debug View
    ============================
    Pipeline: #{execution_tree.pipeline_id}
    Total Duration: #{execution_tree.total_duration_ms}ms
    Total Steps: #{execution_tree.step_count}
    Max Depth: #{execution_tree.max_depth}

    Tree Structure:
    """
  end

  defp format_tree_recursive(
         _tree,
         depth,
         _show_metadata,
         _show_errors,
         _show_performance,
         max_depth
       )
       when depth >= max_depth do
    indent = String.duplicate("  ", depth)
    "#{indent}... (max depth #{max_depth} reached)\n"
  end

  defp format_tree_recursive(tree, depth, show_metadata, show_errors, show_performance, max_depth) do
    indent = String.duplicate("  ", depth)

    # Format current node
    root_span = List.first(tree.spans)

    node_output =
      format_tree_node(root_span, tree, indent, show_metadata, show_errors, show_performance)

    # Format children
    children_output =
      tree.children
      |> Enum.map(
        &format_tree_recursive(
          &1,
          depth + 1,
          show_metadata,
          show_errors,
          show_performance,
          max_depth
        )
      )
      |> Enum.join("")

    node_output <> children_output
  end

  defp format_tree_node(span, tree, indent, show_metadata, show_errors, show_performance) do
    status_icon =
      case span && span.status do
        :completed -> "✅"
        :failed -> "❌"
        :running -> "🔄"
        _ -> "❓"
      end

    pipeline_name = tree.pipeline_id
    step_info = if span && span.step_name, do: " → #{span.step_name}", else: ""

    performance_info =
      if show_performance && span && span.duration_ms do
        " (#{span.duration_ms}ms)"
      else
        ""
      end

    base_line = "#{indent}├─ #{status_icon} #{pipeline_name}#{step_info}#{performance_info}\n"

    metadata_lines =
      if show_metadata && span do
        format_span_metadata(span, indent)
      else
        ""
      end

    error_lines =
      if show_errors && span && Map.get(span, :error) do
        "#{indent}│  ❌ Error: #{span.error}\n"
      else
        ""
      end

    base_line <> metadata_lines <> error_lines
  end

  defp format_span_metadata(span, indent) do
    step_type = Map.get(span, :step_type, "pipeline")
    start_time = Map.get(span, :start_time, DateTime.utc_now())
    span_id = Map.get(span, :id, "unknown")
    depth = Map.get(span, :depth, 0)

    """
    #{indent}│  📊 Depth: #{depth}, Type: #{step_type}
    #{indent}│  🕐 Started: #{format_timestamp(start_time)}
    #{indent}│  📍 Span ID: #{span_id}
    """
  end

  defp format_tree_summary(execution_tree) do
    performance_summary = NestedExecution.generate_performance_summary(execution_tree)

    """

    📊 Execution Summary:
    ====================
    Total Pipelines: #{performance_summary.pipeline_count}
    Success Rate: #{Float.round(performance_summary.success_rate, 1)}%
    Failed Spans: #{performance_summary.failed_spans}

    Performance by Depth:
    #{format_depth_performance(performance_summary.depth_metrics)}
    """
  end

  defp format_depth_performance(depth_metrics) do
    depth_metrics
    |> Enum.sort_by(fn {depth, _} -> depth end)
    |> Enum.map_join("\n", fn {depth, metrics} ->
      "  Depth #{depth}: #{metrics.span_count} spans, avg #{Float.round(metrics.avg_duration_ms, 1)}ms"
    end)
  end

  defp collect_all_spans(tree) do
    tree.spans ++ Enum.flat_map(tree.children, &collect_all_spans/1)
  end

  defp detect_performance_issues(spans, performance_summary) do
    issues = []

    # Detect slow spans
    # 5 seconds
    slow_threshold = 5000

    slow_spans =
      Enum.filter(spans, fn span ->
        span.duration_ms && span.duration_ms > slow_threshold
      end)

    issues =
      if Enum.any?(slow_spans) do
        [
          %{
            type: :slow_execution,
            description: "Found #{length(slow_spans)} spans slower than #{slow_threshold}ms",
            spans: slow_spans,
            severity: :warning
          }
          | issues
        ]
      else
        issues
      end

    # Detect high failure rate  
    success_rate = Map.get(performance_summary, :success_rate, 100.0)

    issues =
      if success_rate < 90 do
        [
          %{
            type: :high_failure_rate,
            description: "Success rate is #{Float.round(success_rate, 1)}% (< 90%)",
            severity: :error
          }
          | issues
        ]
      else
        issues
      end

    # Detect deep nesting
    max_depth = Map.get(performance_summary, :max_depth, 0)

    issues =
      if max_depth > 5 do
        [
          %{
            type: :deep_nesting,
            description: "Maximum nesting depth is #{max_depth} (> 5)",
            severity: :warning
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp analyze_error_patterns(spans) do
    failed_spans = Enum.filter(spans, &(&1.status == :failed))

    # Group errors by type/message
    error_groups = Enum.group_by(failed_spans, &extract_error_type/1)

    Enum.map(error_groups, fn {error_type, error_spans} ->
      %{
        error_type: error_type,
        count: length(error_spans),
        spans: error_spans,
        pattern: analyze_error_pattern(error_spans)
      }
    end)
  end

  defp analyze_resource_usage(spans, performance_summary) do
    completed_spans = Enum.filter(spans, &(&1.status in [:completed, :failed]))
    durations = Enum.map(completed_spans, & &1.duration_ms) |> Enum.reject(&is_nil/1)

    %{
      total_execution_time: performance_summary.total_duration_ms,
      span_count: length(spans),
      avg_span_duration:
        if(Enum.any?(durations), do: Enum.sum(durations) / length(durations), else: 0),
      longest_span: Enum.max(durations, fn -> 0 end),
      depth_distribution: Map.keys(performance_summary.depth_metrics)
    }
  end

  defp suggest_optimizations(_execution_tree, performance_summary, _options) do
    optimizations = []

    # Suggest parallel execution for independent pipelines
    max_depth = Map.get(performance_summary, :max_depth, 0)

    optimizations =
      if max_depth > 3 do
        ["Consider parallel execution for independent nested pipelines" | optimizations]
      else
        optimizations
      end

    # Suggest caching for repeated operations
    pipeline_count = Map.get(performance_summary, :pipeline_count, 0)

    optimizations =
      if pipeline_count > 10 do
        ["Consider caching pipeline definitions for repeated executions" | optimizations]
      else
        optimizations
      end

    # Suggest reducing nesting depth
    optimizations =
      if max_depth > 5 do
        ["Consider flattening deeply nested pipeline structures" | optimizations]
      else
        optimizations
      end

    optimizations
  end

  defp generate_recommendations(performance_issues, error_patterns, resource_usage) do
    recommendations = []

    # Performance recommendations
    recommendations =
      if Enum.any?(performance_issues, &(&1.type == :slow_execution)) do
        ["Optimize slow-running pipeline steps" | recommendations]
      else
        recommendations
      end

    # Error handling recommendations
    recommendations =
      if Enum.any?(error_patterns) do
        ["Implement retry logic for common error patterns" | recommendations]
      else
        recommendations
      end

    # Resource usage recommendations
    avg_duration = Map.get(resource_usage, :avg_span_duration, 0)

    recommendations =
      if avg_duration > 1000 do
        ["Consider breaking down long-running operations" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Execution appears to be running efficiently"]
    else
      recommendations
    end
  end

  defp format_report_header(trace_context, error) do
    error_section =
      if error do
        "\nError Context:\n#{NestedPipeline.extract_base_error_message(error)}"
      else
        ""
      end

    """
    🐛 NESTED PIPELINE DEBUG REPORT
    ===============================

    Trace ID: #{Map.get(trace_context, :trace_id, "unknown")}
    Generated: #{DateTime.utc_now() |> DateTime.to_string()}#{error_section}
    """
  end

  defp format_execution_summary(execution_tree) do
    """
    🎯 EXECUTION OVERVIEW
    ====================

    Pipeline: #{execution_tree.pipeline_id}
    Total Duration: #{execution_tree.total_duration_ms}ms
    Step Count: #{execution_tree.step_count}
    Max Depth: #{execution_tree.max_depth}
    """
  end

  defp format_performance_analysis(analysis) do
    issues_text =
      if Enum.any?(analysis.performance_issues) do
        Enum.map_join(analysis.performance_issues, "\n", fn issue ->
          "  • #{issue.description} (#{issue.severity})"
        end)
      else
        "  ✅ No performance issues detected"
      end

    """
    🚀 PERFORMANCE ANALYSIS
    ======================

    Issues Found:
    #{issues_text}

    Resource Usage:
      • Total Execution Time: #{analysis.resource_usage.total_execution_time}ms
      • Average Span Duration: #{Float.round(analysis.resource_usage.avg_span_duration, 1)}ms
      • Longest Span: #{analysis.resource_usage.longest_span}ms
      • Span Count: #{analysis.resource_usage.span_count}
    """
  end

  defp format_error_analysis(error, analysis) do
    error_text =
      if error do
        "Primary Error: #{NestedPipeline.extract_base_error_message(error)}\n\n"
      else
        ""
      end

    patterns_text =
      if Enum.any?(analysis.error_patterns) do
        Enum.map_join(analysis.error_patterns, "\n", fn pattern ->
          "  • #{pattern.error_type}: #{pattern.count} occurrences"
        end)
      else
        "  ✅ No error patterns detected"
      end

    """
    ⚠️ ERROR ANALYSIS
    ================

    #{error_text}Error Patterns:
    #{patterns_text}
    """
  end

  defp format_recommendations(analysis) do
    recommendations_text =
      Enum.map_join(analysis.recommendations, "\n", fn rec ->
        "  • #{rec}"
      end)

    optimizations_text =
      if Enum.any?(analysis.potential_optimizations) do
        Enum.map_join(analysis.potential_optimizations, "\n", fn opt ->
          "  • #{opt}"
        end)
      else
        "  ✅ No obvious optimizations needed"
      end

    """
    💡 RECOMMENDATIONS
    ==================

    General Recommendations:
    #{recommendations_text}

    Potential Optimizations:
    #{optimizations_text}
    """
  end

  defp format_debug_commands do
    """
    🔧 DEBUG COMMANDS
    =================

    Available debugging functions:
      • debug_execution_tree/2 - Show detailed execution tree
      • inspect_context/2 - Inspect execution context at any point
      • analyze_execution/2 - Perform performance analysis
      • search_execution/3 - Search for patterns in execution
      • compare_executions/2 - Compare multiple execution traces

    Example usage:
      Pipeline.Debug.NestedExecution.debug_execution_tree(trace_context, %{show_metadata: true})
    """
  end

  defp format_step_info(step) do
    """
    Current Step:
      Name: #{Map.get(step, "name", "unknown")}
      Type: #{Map.get(step, "type", "unknown")}
      Config: #{inspect(Map.get(step, "config", %{}))}
    """
  end

  defp format_results_summary(context) do
    case Map.get(context, :results) do
      nil ->
        "  No results available"

      results when map_size(results) == 0 ->
        "  No results yet"

      results ->
        keys = Map.keys(results) |> Enum.take(5)

        if length(keys) == length(Map.keys(results)) do
          "  Available: #{Enum.join(keys, ", ")}"
        else
          "  Available: #{Enum.join(keys, ", ")} (+ #{map_size(results) - 5} more)"
        end
    end
  end

  defp format_global_vars(context) do
    case Map.get(context, :global_vars) do
      nil ->
        "  No global variables"

      vars when map_size(vars) == 0 ->
        "  No global variables set"

      vars ->
        keys = Map.keys(vars) |> Enum.take(3)

        "  Available: #{Enum.join(keys, ", ")}" <>
          if length(keys) < map_size(vars), do: " (+ #{map_size(vars) - 3} more)", else: ""
    end
  end

  defp format_execution_chain(context) do
    # Ensure context has required fields for RecursionGuard
    safe_context = ensure_safe_context_for_recursion_guard(context)
    chain = RecursionGuard.build_execution_chain(safe_context)
    "  #{Enum.join(Enum.reverse(chain), " → ")}"
  end

  defp ensure_safe_context_for_recursion_guard(context) do
    %{
      pipeline_id: Map.get(context, :pipeline_id, "unknown"),
      nesting_depth: Map.get(context, :nesting_depth, 0),
      parent_context: Map.get(context, :parent_context)
    }
  end

  defp format_memory_usage do
    try do
      memory_bytes = :erlang.memory(:total)
      memory_mb = Float.round(memory_bytes / 1_048_576, 1)
      "#{memory_mb} MB"
    rescue
      _ -> "Unknown"
    end
  end

  defp format_comparison_table(summaries) do
    header = "Execution | Duration | Success Rate | Pipelines\n"
    separator = "----------|----------|--------------|----------\n"

    rows =
      Enum.with_index(summaries, 1)
      |> Enum.map_join("\n", fn {{_trace_id, summary}, index} ->
        duration = Map.get(summary, :total_duration_ms, 0)
        success_rate = Map.get(summary, :success_rate, 100.0)
        pipeline_count = Map.get(summary, :pipeline_count, 1)

        "#{index}         | #{duration}ms   | #{Float.round(success_rate, 1)}%      | #{pipeline_count}"
      end)

    header <> separator <> rows
  end

  defp format_performance_insights(summaries) do
    if length(summaries) >= 2 do
      durations =
        Enum.map(summaries, fn {_id, summary} -> Map.get(summary, :total_duration_ms, 0) end)

      avg_duration = Enum.sum(durations) / length(durations)

      variance =
        Enum.reduce(durations, 0, fn d, acc -> acc + abs(d - avg_duration) end) /
          length(durations)

      "Average Duration: #{Float.round(avg_duration, 1)}ms\nDuration Variance: #{Float.round(variance, 1)}ms"
    else
      "Insufficient data for insights"
    end
  end

  defp format_comparison_recommendations(summaries) do
    trend_analysis =
      if length(summaries) >= 2 do
        success_rates =
          Enum.map(summaries, fn {_id, summary} -> Map.get(summary, :success_rate, 100.0) end)

        first_half = Enum.take(success_rates, div(length(success_rates), 2))
        second_half = Enum.drop(success_rates, div(length(success_rates), 2))

        if length(first_half) > 0 && length(second_half) > 0 do
          first_avg = Enum.sum(first_half) / length(first_half)
          second_avg = Enum.sum(second_half) / length(second_half)

          cond do
            second_avg > first_avg + 5 -> "improving"
            second_avg < first_avg - 5 -> "declining"
            true -> "stable"
          end
        else
          "stable"
        end
      else
        "insufficient_data"
      end

    performance_rec =
      if length(summaries) >= 2 do
        durations =
          Enum.map(summaries, fn {_id, summary} -> Map.get(summary, :total_duration_ms, 0) end)

        max_duration = Enum.max(durations)
        min_duration = Enum.min(durations)

        if max_duration > min_duration * 2 do
          "Consider investigating performance differences between executions"
        else
          "Performance appears consistent across executions"
        end
      else
        "Need more executions to compare"
      end

    "Success Rate Trend: #{trend_analysis}\n#{performance_rec}"
  end

  defp matches_pattern?(nil, _pattern), do: false

  defp matches_pattern?(text, pattern) when is_binary(pattern) do
    String.contains?(String.downcase(text), String.downcase(pattern))
  end

  defp matches_pattern?(text, %Regex{} = pattern) do
    Regex.match?(pattern, text)
  end

  defp format_span_context(span, trace_context) do
    parent_span_id = Map.get(span, :parent_span)

    parent_span =
      if parent_span_id && Map.get(trace_context, :spans) do
        Map.get(trace_context.spans, parent_span_id)
      else
        nil
      end

    %{
      span_id: Map.get(span, :id, "unknown"),
      parent_pipeline: if(parent_span, do: Map.get(parent_span, :pipeline_id), else: nil),
      depth: Map.get(span, :depth, 0),
      duration: Map.get(span, :duration_ms),
      status: Map.get(span, :status, :unknown)
    }
  end

  defp determine_match_info(span, pattern, search_in) do
    %{
      search_in: search_in,
      pattern: pattern,
      matched_field: determine_matched_field(span, pattern, search_in)
    }
  end

  defp determine_matched_field(span, pattern, :all) do
    cond do
      matches_pattern?(Map.get(span, :pipeline_id), pattern) -> :pipeline_id
      matches_pattern?(Map.get(span, :step_name), pattern) -> :step_name
      matches_pattern?(Map.get(span, :error), pattern) -> :error
      true -> :unknown
    end
  end

  defp determine_matched_field(_span, _pattern, search_in), do: search_in

  defp extract_error_type(span) do
    error_msg = Map.get(span, :error)

    case error_msg do
      nil ->
        :no_error

      error_msg when is_binary(error_msg) ->
        cond do
          String.contains?(error_msg, "timeout") -> :timeout
          String.contains?(error_msg, "circular") -> :circular_dependency
          String.contains?(error_msg, "limit") -> :resource_limit
          String.contains?(error_msg, "not found") -> :not_found
          true -> :unknown_error
        end
    end
  end

  defp analyze_error_pattern(error_spans) do
    depths = Enum.map(error_spans, & &1.depth)

    %{
      common_depth: Enum.frequencies(depths) |> Enum.max_by(fn {_depth, count} -> count end),
      occurs_at_depth: Enum.uniq(depths),
      timing_pattern: analyze_timing_pattern(error_spans)
    }
  end

  defp analyze_timing_pattern(error_spans) do
    durations = Enum.map(error_spans, & &1.duration_ms) |> Enum.reject(&is_nil/1)

    if Enum.any?(durations) do
      %{
        avg_duration_before_failure: Enum.sum(durations) / length(durations),
        min_duration: Enum.min(durations),
        max_duration: Enum.max(durations)
      }
    else
      %{no_timing_data: true}
    end
  end

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end
end
