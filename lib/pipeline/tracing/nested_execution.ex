defmodule Pipeline.Tracing.NestedExecution do
  @moduledoc """
  Execution tracing and monitoring for nested pipeline execution.

  Provides comprehensive tracing capabilities including span tracking,
  execution trees, performance metrics, and debugging information
  for nested pipeline workflows.
  """

  require Logger

  @type span_id :: String.t()
  @type trace_id :: String.t()

  @type execution_span :: %{
          id: span_id(),
          trace_id: trace_id(),
          parent_span: span_id() | nil,
          pipeline_id: String.t(),
          step_name: String.t() | nil,
          step_type: String.t() | nil,
          depth: non_neg_integer(),
          start_time: DateTime.t(),
          end_time: DateTime.t() | nil,
          duration_ms: non_neg_integer() | nil,
          status: :running | :completed | :failed,
          error: String.t() | nil,
          metadata: map()
        }

  @type execution_tree :: %{
          pipeline_id: String.t(),
          spans: [execution_span()],
          children: [execution_tree()],
          total_duration_ms: non_neg_integer(),
          step_count: non_neg_integer(),
          max_depth: non_neg_integer()
        }

  @type trace_context :: %{
          trace_id: trace_id(),
          current_span: span_id() | nil,
          spans: %{span_id() => execution_span()},
          start_time: DateTime.t()
        }

  @doc """
  Start tracing a nested pipeline execution.

  ## Parameters
  - `pipeline_id`: The ID of the pipeline being executed
  - `context`: Current execution context
  - `step`: Current step configuration (optional)
  - `parent_trace`: Parent trace context (optional)

  ## Returns
  - New trace context with initial span
  """
  @spec start_nested_trace(String.t(), map(), map() | nil, trace_context() | nil) ::
          trace_context()
  def start_nested_trace(pipeline_id, context, step \\ nil, parent_trace \\ nil) do
    trace_id = parent_trace[:trace_id] || generate_trace_id()
    span_id = generate_span_id()
    parent_span = parent_trace[:current_span]

    span = %{
      id: span_id,
      trace_id: trace_id,
      parent_span: parent_span,
      pipeline_id: pipeline_id,
      step_name: get_step_name(step),
      step_type: get_step_type(step),
      depth: Map.get(context, :nesting_depth, 0),
      start_time: DateTime.utc_now(),
      end_time: nil,
      duration_ms: nil,
      status: :running,
      error: nil,
      metadata: collect_span_metadata(context, step)
    }

    # Log span start
    log_span_event(:start, span)

    # Emit telemetry event
    emit_telemetry_event([:pipeline, :span, :start], %{}, span)

    trace_context = %{
      trace_id: trace_id,
      current_span: span_id,
      spans: %{span_id => span},
      start_time: span.start_time
    }

    # Merge with parent trace if exists
    if parent_trace do
      %{
        trace_context
        | spans: Map.merge(parent_trace.spans, trace_context.spans),
          start_time: parent_trace.start_time
      }
    else
      trace_context
    end
  end

  @doc """
  Complete a span in the trace.

  ## Parameters
  - `trace_context`: Current trace context
  - `result`: Execution result (:ok, {:ok, value}, or {:error, reason})

  ## Returns
  - Updated trace context
  """
  @spec complete_span(trace_context(), any()) :: trace_context()
  def complete_span(trace_context, result) do
    span_id = trace_context.current_span

    if span_id && Map.has_key?(trace_context.spans, span_id) do
      span = trace_context.spans[span_id]
      end_time = DateTime.utc_now()
      duration_ms = DateTime.diff(end_time, span.start_time, :millisecond)

      {status, error_msg} =
        case result do
          :ok -> {:completed, nil}
          {:ok, _value} -> {:completed, nil}
          {:error, reason} -> {:failed, format_error(reason)}
          _ -> {:completed, nil}
        end

      updated_span =
        span
        |> Map.put(:end_time, end_time)
        |> Map.put(:duration_ms, duration_ms)
        |> Map.put(:status, status)
        |> Map.put(:error, error_msg)

      # Log span completion
      log_span_event(:complete, updated_span)

      # Emit telemetry event
      emit_telemetry_event(
        [:pipeline, :span, :stop],
        %{duration: duration_ms},
        updated_span
      )

      %{
        trace_context
        | spans: Map.put(trace_context.spans, span_id, updated_span),
          current_span: updated_span.parent_span
      }
    else
      trace_context
    end
  end

  @doc """
  Generate an execution tree from trace spans.

  ## Parameters
  - `trace_context`: Trace context containing all spans

  ## Returns
  - Hierarchical execution tree
  """
  @spec build_execution_tree(trace_context()) :: execution_tree()
  def build_execution_tree(trace_context) do
    spans = Map.values(trace_context.spans)
    root_spans = Enum.filter(spans, fn span -> span.parent_span == nil end)

    case root_spans do
      [root_span] ->
        build_tree_from_span(root_span, spans)

      multiple_roots ->
        # Multiple root spans - create virtual root
        total_duration = calculate_total_duration(spans)
        max_depth = Enum.map(spans, & &1.depth) |> Enum.max(fn -> 0 end)

        %{
          pipeline_id: "multiple_roots",
          spans: multiple_roots,
          children: Enum.map(multiple_roots, &build_tree_from_span(&1, spans)),
          total_duration_ms: total_duration,
          step_count: length(spans),
          max_depth: max_depth
        }
    end
  end

  @doc """
  Generate a visual representation of the execution tree.

  ## Parameters
  - `execution_tree`: The execution tree to visualize
  - `options`: Visualization options (optional)

  ## Returns
  - String representation of the execution tree
  """
  @spec visualize_execution_tree(execution_tree(), map()) :: String.t()
  def visualize_execution_tree(execution_tree, options \\ %{}) do
    show_timings = Map.get(options, :show_timings, true)
    show_status = Map.get(options, :show_status, true)
    max_depth = Map.get(options, :max_depth, 10)

    header = """
    Execution Tree:
    ===============
    Pipeline: #{execution_tree.pipeline_id}
    Total Duration: #{execution_tree.total_duration_ms}ms
    Step Count: #{execution_tree.step_count}
    Max Depth: #{execution_tree.max_depth}

    """

    tree_visualization =
      visualize_tree_recursive(execution_tree, 0, show_timings, show_status, max_depth)

    header <> tree_visualization
  end

  @doc """
  Generate performance summary from execution tree.

  ## Parameters
  - `execution_tree`: The execution tree to analyze

  ## Returns
  - Performance summary with metrics by depth
  """
  @spec generate_performance_summary(execution_tree()) :: map()
  def generate_performance_summary(execution_tree) do
    all_spans = collect_all_spans(execution_tree)

    # Group spans by depth
    spans_by_depth = Enum.group_by(all_spans, & &1.depth)

    depth_metrics =
      spans_by_depth
      |> Enum.map(fn {depth, spans} ->
        durations = Enum.map(spans, & &1.duration_ms) |> Enum.reject(&is_nil/1)

        {depth,
         %{
           span_count: length(spans),
           total_duration_ms: Enum.sum(durations),
           avg_duration_ms:
             if(length(durations) > 0, do: Enum.sum(durations) / length(durations), else: 0),
           min_duration_ms: Enum.min(durations, fn -> 0 end),
           max_duration_ms: Enum.max(durations, fn -> 0 end),
           failed_spans: Enum.count(spans, &(&1.status == :failed)),
           success_rate: calculate_success_rate(spans)
         }}
      end)
      |> Map.new()

    # Calculate overall metrics
    total_spans = length(all_spans)
    completed_spans = Enum.filter(all_spans, &(&1.status in [:completed, :failed]))
    failed_spans = Enum.count(all_spans, &(&1.status == :failed))

    %{
      total_duration_ms: execution_tree.total_duration_ms,
      total_spans: total_spans,
      completed_spans: length(completed_spans),
      failed_spans: failed_spans,
      success_rate: calculate_success_rate(all_spans),
      max_depth: execution_tree.max_depth,
      depth_metrics: depth_metrics,
      pipeline_count: count_unique_pipelines(all_spans)
    }
  end

  @doc """
  Create debug information for troubleshooting.

  ## Parameters
  - `trace_context`: Current trace context
  - `error`: Error that occurred (optional)

  ## Returns
  - Debug information map
  """
  @spec create_debug_info(trace_context(), any()) :: map()
  def create_debug_info(trace_context, error \\ nil) do
    execution_tree = build_execution_tree(trace_context)
    performance_summary = generate_performance_summary(execution_tree)

    %{
      trace_id: trace_context.trace_id,
      total_spans: map_size(trace_context.spans),
      execution_tree: execution_tree,
      performance_summary: performance_summary,
      error_context: if(error, do: format_error(error), else: nil),
      debug_timestamp: DateTime.utc_now(),
      trace_visualization: visualize_execution_tree(execution_tree)
    }
  end

  # Private helper functions

  defp generate_trace_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end

  defp get_step_name(nil), do: nil
  defp get_step_name(step), do: Map.get(step, "name")

  defp get_step_type(nil), do: nil
  defp get_step_type(step), do: Map.get(step, "type")

  defp collect_span_metadata(context, step) do
    %{
      nesting_depth: Map.get(context, :nesting_depth, 0),
      pipeline_id: context.pipeline_id,
      step_index: Map.get(context, :step_index),
      has_parent: context[:parent_context] != nil,
      step_config: sanitize_step_config(step),
      context_size: map_size(context)
    }
  end

  defp sanitize_step_config(nil), do: nil

  defp sanitize_step_config(step) do
    Map.take(step, ["name", "type", "condition"])
  end

  defp log_span_event(:start, span) do
    Logger.debug(
      "🔄 Starting span [#{span.id}] for pipeline '#{span.pipeline_id}' at depth #{span.depth}"
    )
  end

  defp log_span_event(:complete, span) do
    status_emoji =
      case span.status do
        :completed -> "✅"
        :failed -> "❌"
        _ -> "🔄"
      end

    pipeline_id = Map.get(span, :pipeline_id, "unknown")
    duration_ms = Map.get(span, :duration_ms, 0)

    Logger.debug(
      "#{status_emoji} Completed span [#{span.id}] for pipeline '#{pipeline_id}' in #{duration_ms}ms"
    )
  end

  defp emit_telemetry_event(event, measurements, metadata) do
    try do
      :telemetry.execute(event, measurements, metadata)
    rescue
      # Silently fail if telemetry is not available
      _ -> :ok
    end
  end

  defp format_error({:error, message}), do: to_string(message)
  defp format_error(message) when is_binary(message), do: message
  defp format_error(other), do: inspect(other)

  defp build_tree_from_span(span, all_spans) do
    children_spans = Enum.filter(all_spans, &(&1.parent_span == span.id))
    children_trees = Enum.map(children_spans, &build_tree_from_span(&1, all_spans))

    # Calculate metrics for this subtree
    total_duration = span.duration_ms || 0
    # Step count should be 1 (this span) + sum of children's step counts
    step_count = 1 + Enum.sum(Enum.map(children_trees, & &1.step_count))

    max_depth =
      if Enum.empty?(children_trees) do
        span.depth
      else
        Enum.map(children_trees, & &1.max_depth) |> Enum.max()
      end

    %{
      pipeline_id: span.pipeline_id,
      spans: [span],
      children: children_trees,
      total_duration_ms: total_duration,
      step_count: step_count,
      max_depth: max_depth
    }
  end

  defp calculate_total_duration(spans) do
    spans
    |> Enum.map(& &1.duration_ms)
    |> Enum.reject(&is_nil/1)
    |> Enum.sum()
  end

  defp visualize_tree_recursive(_tree, current_depth, _show_timings, _show_status, max_depth)
       when current_depth >= max_depth do
    indent = String.duplicate("  ", current_depth)
    "#{indent}... (max depth reached)\n"
  end

  defp visualize_tree_recursive(tree, current_depth, show_timings, show_status, max_depth) do
    indent = String.duplicate("  ", current_depth)

    # Format root span
    root_span = List.first(tree.spans)

    status_indicator =
      if show_status && root_span do
        case Map.get(root_span, :status, :unknown) do
          :completed -> "✅"
          :failed -> "❌"
          :running -> "🔄"
          _ -> "❓"
        end
      else
        ""
      end

    timing_info =
      if show_timings && root_span && Map.get(root_span, :duration_ms) do
        " (#{root_span.duration_ms}ms)"
      else
        ""
      end

    step_info =
      if root_span && Map.get(root_span, :step_name) do
        " → #{root_span.step_name}"
      else
        ""
      end

    line = "#{indent}├─ #{status_indicator} #{tree.pipeline_id}#{step_info}#{timing_info}\n"

    # Format children
    children_output =
      tree.children
      |> Enum.map(
        &visualize_tree_recursive(&1, current_depth + 1, show_timings, show_status, max_depth)
      )
      |> Enum.join("")

    line <> children_output
  end

  defp collect_all_spans(tree) do
    tree.spans ++ Enum.flat_map(tree.children, &collect_all_spans/1)
  end

  defp calculate_success_rate(spans) do
    total = length(spans)

    if total == 0 do
      0.0
    else
      successful = Enum.count(spans, &(&1.status == :completed))
      successful / total * 100
    end
  end

  defp count_unique_pipelines(spans) do
    spans
    |> Enum.map(&Map.get(&1, :pipeline_id, "unknown"))
    |> Enum.uniq()
    |> length()
  end
end
