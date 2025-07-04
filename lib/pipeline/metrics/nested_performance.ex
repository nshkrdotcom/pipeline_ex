defmodule Pipeline.Metrics.NestedPerformance do
  @moduledoc """
  Performance metrics collection and analysis for nested pipeline execution.

  Provides detailed performance tracking, metrics aggregation, and
  performance analysis capabilities for nested pipeline workflows.
  """

  require Logger

  @type performance_metrics :: %{
          execution_id: String.t(),
          trace_id: String.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t() | nil,
          total_duration_ms: non_neg_integer() | nil,
          pipeline_metrics: [pipeline_metric()],
          depth_metrics: %{non_neg_integer() => depth_metric()},
          resource_metrics: resource_metric(),
          summary: performance_summary()
        }

  @type pipeline_metric :: %{
          pipeline_id: String.t(),
          depth: non_neg_integer(),
          duration_ms: non_neg_integer() | nil,
          step_count: non_neg_integer(),
          success: boolean(),
          error: String.t() | nil,
          memory_usage_mb: float() | nil,
          child_pipelines: [String.t()]
        }

  @type depth_metric :: %{
          depth: non_neg_integer(),
          pipeline_count: non_neg_integer(),
          total_duration_ms: non_neg_integer(),
          avg_duration_ms: float(),
          min_duration_ms: non_neg_integer(),
          max_duration_ms: non_neg_integer(),
          success_rate: float(),
          step_count: non_neg_integer()
        }

  @type resource_metric :: %{
          peak_memory_mb: float(),
          avg_memory_mb: float(),
          total_memory_allocated_mb: float(),
          gc_collections: non_neg_integer(),
          process_count_peak: non_neg_integer()
        }

  @type performance_summary :: %{
          total_pipelines: non_neg_integer(),
          total_steps: non_neg_integer(),
          max_depth: non_neg_integer(),
          overall_success_rate: float(),
          performance_grade: atom(),
          bottlenecks: [String.t()],
          recommendations: [String.t()]
        }

  @doc """
  Start performance tracking for a nested pipeline execution.

  ## Parameters
  - `trace_id`: The trace ID for this execution
  - `pipeline_id`: The root pipeline ID

  ## Returns
  - Performance tracking context
  """
  @spec start_performance_tracking(String.t(), String.t()) :: performance_metrics()
  def start_performance_tracking(trace_id, _pipeline_id) do
    execution_id = generate_execution_id()

    Logger.debug("📊 Started performance tracking [#{execution_id}] for trace #{trace_id}")

    %{
      execution_id: execution_id,
      trace_id: trace_id,
      start_time: DateTime.utc_now(),
      end_time: nil,
      total_duration_ms: nil,
      pipeline_metrics: [],
      depth_metrics: %{},
      resource_metrics: collect_initial_resource_metrics(),
      summary: %{
        total_pipelines: 0,
        total_steps: 0,
        max_depth: 0,
        overall_success_rate: 0.0,
        performance_grade: :unknown,
        bottlenecks: [],
        recommendations: []
      }
    }
  end

  @doc """
  Record metrics for a single pipeline execution.

  ## Parameters
  - `performance_context`: Current performance tracking context
  - `pipeline_id`: Pipeline that was executed
  - `depth`: Nesting depth of the pipeline
  - `duration_ms`: Execution duration in milliseconds
  - `step_count`: Number of steps in the pipeline
  - `success`: Whether execution was successful
  - `error`: Error message if execution failed
  - `metadata`: Additional metadata

  ## Returns
  - Updated performance context
  """
  @spec record_pipeline_metric(
          performance_metrics(),
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          boolean(),
          String.t() | nil,
          map()
        ) :: performance_metrics()
  def record_pipeline_metric(
        performance_context,
        pipeline_id,
        depth,
        duration_ms,
        step_count,
        success,
        error \\ nil,
        metadata \\ %{}
      ) do
    pipeline_metric = %{
      pipeline_id: pipeline_id,
      depth: depth,
      duration_ms: duration_ms,
      step_count: step_count,
      success: success,
      error: error,
      memory_usage_mb: get_current_memory_mb(),
      child_pipelines: Map.get(metadata, :child_pipelines, [])
    }

    updated_pipeline_metrics = [pipeline_metric | performance_context.pipeline_metrics]

    performance_context
    |> Map.put(:pipeline_metrics, updated_pipeline_metrics)
    |> update_depth_metrics(pipeline_metric)
    |> update_summary_metrics()
  end

  @doc """
  Complete performance tracking and generate final metrics.

  ## Parameters
  - `performance_context`: Current performance tracking context

  ## Returns
  - Completed performance metrics with analysis
  """
  @spec complete_performance_tracking(performance_metrics()) :: performance_metrics()
  def complete_performance_tracking(performance_context) do
    end_time = DateTime.utc_now()
    total_duration_ms = DateTime.diff(end_time, performance_context.start_time, :millisecond)

    final_resource_metrics = collect_final_resource_metrics(performance_context.resource_metrics)

    completed_context =
      performance_context
      |> Map.put(:end_time, end_time)
      |> Map.put(:total_duration_ms, total_duration_ms)
      |> Map.put(:resource_metrics, final_resource_metrics)
      |> finalize_summary_metrics()

    Logger.info(
      "📊 Completed performance tracking [#{completed_context.execution_id}] - #{total_duration_ms}ms total"
    )

    completed_context
  end

  @doc """
  Analyze performance metrics and identify issues.

  ## Parameters
  - `performance_metrics`: Completed performance metrics

  ## Returns
  - Performance analysis with insights and recommendations
  """
  @spec analyze_performance(performance_metrics()) :: map()
  def analyze_performance(performance_metrics) do
    bottlenecks = identify_bottlenecks(performance_metrics)
    performance_issues = detect_performance_issues(performance_metrics)
    resource_analysis = analyze_resource_usage(performance_metrics)

    recommendations =
      generate_performance_recommendations(performance_metrics, bottlenecks, performance_issues)

    %{
      performance_grade: calculate_performance_grade(performance_metrics),
      bottlenecks: bottlenecks,
      performance_issues: performance_issues,
      resource_analysis: resource_analysis,
      recommendations: recommendations,
      efficiency_score: calculate_efficiency_score(performance_metrics),
      scalability_assessment: assess_scalability(performance_metrics)
    }
  end

  @doc """
  Generate a performance report.

  ## Parameters
  - `performance_metrics`: Performance metrics to report on
  - `options`: Report generation options

  ## Returns
  - Formatted performance report
  """
  @spec generate_performance_report(performance_metrics(), map()) :: String.t()
  def generate_performance_report(performance_metrics, options \\ %{}) do
    analysis = analyze_performance(performance_metrics)
    include_details = Map.get(options, :include_details, true)
    include_recommendations = Map.get(options, :include_recommendations, true)

    sections = [
      format_report_header(performance_metrics),
      format_execution_overview(performance_metrics),
      format_depth_analysis(performance_metrics),
      format_resource_analysis(performance_metrics),
      format_performance_analysis(analysis)
    ]

    sections =
      if include_details do
        sections ++ [format_detailed_metrics(performance_metrics)]
      else
        sections
      end

    sections =
      if include_recommendations do
        sections ++ [format_recommendations(analysis)]
      else
        sections
      end

    Enum.join(sections, "\n\n" <> String.duplicate("=", 80) <> "\n\n")
  end

  @doc """
  Compare performance between multiple executions.

  ## Parameters
  - `performance_metrics_list`: List of performance metrics to compare
  - `options`: Comparison options

  ## Returns
  - Performance comparison report
  """
  @spec compare_performance([performance_metrics()], map()) :: String.t()
  def compare_performance(performance_metrics_list, options \\ %{}) do
    if length(performance_metrics_list) < 2 do
      "At least 2 performance metrics required for comparison"
    else
      comparisons = calculate_performance_comparisons(performance_metrics_list)
      format_comparison_report(comparisons, options)
    end
  end

  @doc """
  Emit telemetry events for performance metrics.

  ## Parameters
  - `performance_metrics`: Performance metrics to emit
  - `event_type`: Type of telemetry event
  """
  @spec emit_performance_telemetry(performance_metrics(), atom()) :: :ok
  def emit_performance_telemetry(performance_metrics, event_type \\ :completion) do
    measurements = %{
      total_duration_ms: performance_metrics.total_duration_ms || 0,
      total_pipelines: performance_metrics.summary.total_pipelines,
      total_steps: performance_metrics.summary.total_steps,
      max_depth: performance_metrics.summary.max_depth,
      success_rate: performance_metrics.summary.overall_success_rate
    }

    metadata = %{
      execution_id: performance_metrics.execution_id,
      trace_id: performance_metrics.trace_id,
      performance_grade: performance_metrics.summary.performance_grade,
      event_type: event_type
    }

    try do
      :telemetry.execute([:pipeline, :nested, :performance], measurements, metadata)
    rescue
      # Silently fail if telemetry is not available
      _ -> :ok
    end
  end

  # Private helper functions

  defp generate_execution_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end

  defp collect_initial_resource_metrics do
    %{
      peak_memory_mb: get_current_memory_mb(),
      avg_memory_mb: get_current_memory_mb(),
      total_memory_allocated_mb: 0.0,
      gc_collections: get_gc_count(),
      process_count_peak: length(Process.list())
    }
  end

  defp get_current_memory_mb do
    try do
      :erlang.memory(:total) / 1_048_576
    rescue
      _ -> 0.0
    end
  end

  defp get_gc_count do
    try do
      {gc_count, _, _} = :erlang.statistics(:garbage_collection)
      gc_count
    rescue
      _ -> 0
    end
  end

  defp update_depth_metrics(performance_context, pipeline_metric) do
    depth = pipeline_metric.depth

    current_depth_metrics =
      Map.get(performance_context.depth_metrics, depth, create_initial_depth_metric(depth))

    updated_depth_metric =
      current_depth_metrics
      |> Map.update!(:pipeline_count, &(&1 + 1))
      |> Map.update!(:total_duration_ms, &(&1 + pipeline_metric.duration_ms))
      |> Map.update!(:step_count, &(&1 + pipeline_metric.step_count))
      |> update_depth_duration_stats(pipeline_metric.duration_ms)
      |> update_depth_success_rate(pipeline_metric.success)

    Map.put(
      performance_context,
      :depth_metrics,
      Map.put(performance_context.depth_metrics, depth, updated_depth_metric)
    )
  end

  defp create_initial_depth_metric(depth) do
    %{
      depth: depth,
      pipeline_count: 0,
      total_duration_ms: 0,
      avg_duration_ms: 0.0,
      min_duration_ms: 999_999_999,
      max_duration_ms: 0,
      success_rate: 100.0,
      step_count: 0
    }
  end

  defp update_depth_duration_stats(depth_metric, duration_ms) do
    new_avg = depth_metric.total_duration_ms / depth_metric.pipeline_count

    depth_metric
    |> Map.put(:avg_duration_ms, new_avg)
    |> Map.update!(:min_duration_ms, &min(&1, duration_ms))
    |> Map.update!(:max_duration_ms, &max(&1, duration_ms))
  end

  defp update_depth_success_rate(depth_metric, success) do
    # This is a simplified calculation - in a real implementation,
    # you'd want to track successes and failures separately
    current_success_count = depth_metric.pipeline_count * depth_metric.success_rate / 100
    new_success_count = if success, do: current_success_count + 1, else: current_success_count
    new_success_rate = new_success_count / (depth_metric.pipeline_count + 1) * 100

    Map.put(depth_metric, :success_rate, new_success_rate)
  end

  defp update_summary_metrics(performance_context) do
    total_pipelines = length(performance_context.pipeline_metrics)
    total_steps = Enum.sum(Enum.map(performance_context.pipeline_metrics, & &1.step_count))

    max_depth =
      if total_pipelines > 0 do
        Enum.map(performance_context.pipeline_metrics, & &1.depth) |> Enum.max()
      else
        0
      end

    successful_pipelines = Enum.count(performance_context.pipeline_metrics, & &1.success)

    success_rate =
      if total_pipelines > 0, do: successful_pipelines / total_pipelines * 100, else: 100.0

    updated_summary = %{
      performance_context.summary
      | total_pipelines: total_pipelines,
        total_steps: total_steps,
        max_depth: max_depth,
        overall_success_rate: success_rate
    }

    Map.put(performance_context, :summary, updated_summary)
  end

  defp collect_final_resource_metrics(initial_metrics) do
    current_memory = get_current_memory_mb()
    current_gc_count = get_gc_count()
    current_process_count = length(Process.list())

    peak_memory = max(initial_metrics.peak_memory_mb, current_memory)
    avg_memory = (initial_metrics.avg_memory_mb + current_memory) / 2

    %{
      initial_metrics
      | peak_memory_mb: peak_memory,
        # Ensure avg <= peak
        avg_memory_mb: min(avg_memory, peak_memory),
        total_memory_allocated_mb: max(current_memory - initial_metrics.avg_memory_mb, 0),
        gc_collections: current_gc_count - initial_metrics.gc_collections,
        process_count_peak: max(initial_metrics.process_count_peak, current_process_count)
    }
  end

  defp finalize_summary_metrics(performance_context) do
    analysis = analyze_performance(performance_context)

    updated_summary = %{
      performance_context.summary
      | performance_grade: analysis.performance_grade,
        bottlenecks: analysis.bottlenecks,
        recommendations: analysis.recommendations
    }

    Map.put(performance_context, :summary, updated_summary)
  end

  defp identify_bottlenecks(performance_metrics) do
    bottlenecks = []

    # Identify slow pipelines
    summary = Map.get(performance_metrics, :summary, %{})
    total_pipelines = Map.get(summary, :total_pipelines, 0)

    avg_duration =
      if total_pipelines > 0 do
        (Map.get(performance_metrics, :total_duration_ms, 0) || 0) / total_pipelines
      else
        0
      end

    slow_pipelines =
      Enum.filter(performance_metrics.pipeline_metrics, fn metric ->
        Map.get(metric, :duration_ms, 0) > avg_duration * 2
      end)

    bottlenecks =
      if Enum.any?(slow_pipelines) do
        slow_pipeline_ids = Enum.map(slow_pipelines, &Map.get(&1, :pipeline_id, "unknown"))
        ["Slow pipelines: #{Enum.join(slow_pipeline_ids, ", ")}" | bottlenecks]
      else
        bottlenecks
      end

    # Identify depth-related bottlenecks
    max_depth = Map.get(performance_metrics.summary, :max_depth, 0)

    bottlenecks =
      if max_depth > 5 do
        ["Deep nesting (depth: #{max_depth})" | bottlenecks]
      else
        bottlenecks
      end

    # Identify memory bottlenecks
    resource_metrics = Map.get(performance_metrics, :resource_metrics, %{})
    peak_memory = Map.get(resource_metrics, :peak_memory_mb, 0)

    bottlenecks =
      if peak_memory > 1000 do
        [
          "High memory usage (#{:erlang.float_to_binary(peak_memory, [{:decimals, 1}])} MB)"
          | bottlenecks
        ]
      else
        bottlenecks
      end

    bottlenecks
  end

  defp detect_performance_issues(performance_metrics) do
    issues = []

    # Low success rate - handle different structures
    success_rate =
      case performance_metrics do
        %{summary: %{overall_success_rate: rate}} -> rate
        %{overall_success_rate: rate} -> rate
        _ -> 100.0
      end

    issues =
      if success_rate < 95 do
        [
          %{
            type: :low_success_rate,
            severity: :error,
            description: "Success rate is #{Float.round(success_rate, 1)}%"
          }
          | issues
        ]
      else
        issues
      end

    # Long execution time
    duration = Map.get(performance_metrics, :total_duration_ms, 0) || 0
    # 1 minute
    issues =
      if duration > 60_000 do
        [
          %{
            type: :long_execution,
            severity: :warning,
            description: "Total execution time exceeds 1 minute"
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp analyze_resource_usage(performance_metrics) do
    resource_metrics = Map.get(performance_metrics, :resource_metrics, %{})

    %{
      memory_efficiency: calculate_memory_efficiency(performance_metrics),
      process_overhead: Map.get(resource_metrics, :process_count_peak, 0),
      gc_pressure: Map.get(resource_metrics, :gc_collections, 0),
      resource_grade: calculate_resource_grade(performance_metrics)
    }
  end

  defp calculate_memory_efficiency(performance_metrics) do
    resource_metrics = Map.get(performance_metrics, :resource_metrics, %{})
    peak_memory = Map.get(resource_metrics, :peak_memory_mb, 0)
    pipeline_count = performance_metrics.summary.total_pipelines

    if pipeline_count > 0 do
      memory_per_pipeline = peak_memory / pipeline_count

      cond do
        memory_per_pipeline < 10 -> :excellent
        memory_per_pipeline < 50 -> :good
        memory_per_pipeline < 100 -> :fair
        true -> :poor
      end
    else
      :unknown
    end
  end

  defp calculate_resource_grade(performance_metrics) do
    memory_score =
      case calculate_memory_efficiency(performance_metrics) do
        :excellent -> 4
        :good -> 3
        :fair -> 2
        :poor -> 1
        _ -> 2
      end

    resource_metrics = Map.get(performance_metrics, :resource_metrics, %{})
    gc_score = if Map.get(resource_metrics, :gc_collections, 0) < 10, do: 4, else: 2
    process_score = if Map.get(resource_metrics, :process_count_peak, 0) < 100, do: 4, else: 2

    avg_score = (memory_score + gc_score + process_score) / 3

    cond do
      avg_score >= 3.5 -> :excellent
      avg_score >= 2.5 -> :good
      avg_score >= 1.5 -> :fair
      true -> :poor
    end
  end

  defp generate_performance_recommendations(performance_metrics, bottlenecks, performance_issues) do
    recommendations = []

    # Recommendations based on bottlenecks
    recommendations =
      if Enum.any?(bottlenecks, &String.contains?(&1, "Deep nesting")) do
        ["Consider flattening deeply nested pipeline structures" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Enum.any?(bottlenecks, &String.contains?(&1, "memory")) do
        ["Optimize memory usage in pipeline steps" | recommendations]
      else
        recommendations
      end

    # Recommendations based on performance issues
    recommendations =
      if Enum.any?(performance_issues, &(&1.type == :low_success_rate)) do
        ["Implement retry logic for failed pipeline steps" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Enum.any?(performance_issues, &(&1.type == :long_execution)) do
        ["Consider parallel execution for independent operations" | recommendations]
      else
        recommendations
      end

    # General recommendations
    total_steps = Map.get(performance_metrics.summary, :total_steps, 0)

    recommendations =
      if total_steps > 100 do
        ["Consider breaking large pipelines into smaller, reusable components" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Performance appears optimal for current workload"]
    else
      recommendations
    end
  end

  defp calculate_performance_grade(performance_metrics) do
    success_rate =
      Map.get(performance_metrics.summary || performance_metrics, :overall_success_rate, 100.0)

    success_rate_score = success_rate / 100 * 4

    duration_score =
      case Map.get(performance_metrics, :total_duration_ms, 0) || 0 do
        # < 1s
        d when d < 1000 -> 4
        # < 5s  
        d when d < 5000 -> 3
        # < 30s
        d when d < 30000 -> 2
        # > 30s
        _ -> 1
      end

    depth_score =
      case Map.get(performance_metrics.summary || %{}, :max_depth, 0) do
        d when d <= 2 -> 4
        d when d <= 5 -> 3
        d when d <= 8 -> 2
        _ -> 1
      end

    resource_score =
      case calculate_resource_grade(performance_metrics) do
        :excellent -> 4
        :good -> 3
        :fair -> 2
        :poor -> 1
        _ -> 2
      end

    avg_score = (success_rate_score + duration_score + depth_score + resource_score) / 4

    cond do
      avg_score >= 3.5 -> :excellent
      avg_score >= 2.5 -> :good
      avg_score >= 1.5 -> :fair
      true -> :poor
    end
  end

  defp calculate_efficiency_score(performance_metrics) do
    # Efficiency = successful work done / resources consumed
    summary = Map.get(performance_metrics, :summary, %{})
    total_steps = Map.get(summary, :total_steps, 0)
    success_rate = Map.get(summary, :overall_success_rate, 100.0)
    successful_steps = total_steps * success_rate / 100
    # Convert to seconds
    time_factor = max(1, (Map.get(performance_metrics, :total_duration_ms, 1) || 1) / 1000)
    resource_metrics = Map.get(performance_metrics, :resource_metrics, %{})
    peak_memory = Map.get(resource_metrics, :peak_memory_mb, 100)
    # Normalize memory
    memory_factor = max(1, peak_memory / 100)

    efficiency = successful_steps / (time_factor * memory_factor)
    Float.round(efficiency, 2)
  end

  defp assess_scalability(performance_metrics) do
    depth_scalability =
      case Map.get(performance_metrics.summary || %{}, :max_depth, 0) do
        d when d <= 3 -> :excellent
        d when d <= 6 -> :good
        d when d <= 10 -> :fair
        _ -> :poor
      end

    memory_scalability =
      case Map.get(performance_metrics.resource_metrics || %{}, :peak_memory_mb, 0) do
        m when m < 100 -> :excellent
        m when m < 500 -> :good
        m when m < 1000 -> :fair
        _ -> :poor
      end

    %{
      depth_scalability: depth_scalability,
      memory_scalability: memory_scalability,
      overall: min(depth_scalability, memory_scalability)
    }
  end

  defp calculate_performance_comparisons(performance_metrics_list) do
    # Implementation for comparing multiple performance metrics
    %{
      execution_count: length(performance_metrics_list),
      avg_duration: calculate_average_duration(performance_metrics_list),
      duration_variance: calculate_duration_variance(performance_metrics_list),
      success_rate_trend: calculate_success_rate_trend(performance_metrics_list)
    }
  end

  defp calculate_average_duration(performance_metrics_list) do
    durations = Enum.map(performance_metrics_list, &(&1.total_duration_ms || 0))
    if Enum.any?(durations), do: Enum.sum(durations) / length(durations), else: 0
  end

  defp calculate_duration_variance(performance_metrics_list) do
    durations = Enum.map(performance_metrics_list, &(&1.total_duration_ms || 0))

    if length(durations) > 1 do
      avg = calculate_average_duration(performance_metrics_list)

      variance =
        (Enum.map(durations, fn d -> (d - avg) * (d - avg) end) |> Enum.sum()) / length(durations)

      Float.round(:math.sqrt(variance), 2)
    else
      0.0
    end
  end

  defp calculate_success_rate_trend(performance_metrics_list) do
    success_rates = Enum.map(performance_metrics_list, & &1.summary.overall_success_rate)

    if length(success_rates) > 1 do
      first_half = Enum.take(success_rates, div(length(success_rates), 2))
      second_half = Enum.drop(success_rates, div(length(success_rates), 2))

      first_avg = Enum.sum(first_half) / length(first_half)
      second_avg = Enum.sum(second_half) / length(second_half)

      cond do
        second_avg > first_avg + 5 -> :improving
        second_avg < first_avg - 5 -> :declining
        true -> :stable
      end
    else
      :insufficient_data
    end
  end

  # Report formatting functions

  defp format_report_header(performance_metrics) do
    """
    📊 NESTED PIPELINE PERFORMANCE REPORT
    ====================================

    Execution ID: #{performance_metrics.execution_id}
    Trace ID: #{performance_metrics.trace_id}
    Generated: #{DateTime.utc_now() |> DateTime.to_string()}
    Performance Grade: #{performance_metrics.summary.performance_grade}
    """
  end

  defp format_execution_overview(performance_metrics) do
    """
    🎯 EXECUTION OVERVIEW
    ====================

    Total Duration: #{performance_metrics.total_duration_ms || 0}ms
    Total Pipelines: #{performance_metrics.summary.total_pipelines}
    Total Steps: #{performance_metrics.summary.total_steps}
    Maximum Depth: #{performance_metrics.summary.max_depth}
    Overall Success Rate: #{Float.round(performance_metrics.summary.overall_success_rate, 1)}%
    """
  end

  defp format_depth_analysis(performance_metrics) do
    depth_lines =
      performance_metrics.depth_metrics
      |> Enum.sort_by(fn {depth, _} -> depth end)
      |> Enum.map_join("\n", fn {depth, metrics} ->
        "    Depth #{depth}: #{metrics.pipeline_count} pipelines, avg #{Float.round(metrics.avg_duration_ms, 1)}ms"
      end)

    """
    📏 DEPTH ANALYSIS
    ================

    Performance by Depth:
    #{depth_lines}
    """
  end

  defp format_resource_analysis(performance_metrics) do
    """
    💾 RESOURCE ANALYSIS
    ===================

    Peak Memory: #{Float.round(performance_metrics.resource_metrics.peak_memory_mb, 1)} MB
    Average Memory: #{Float.round(performance_metrics.resource_metrics.avg_memory_mb, 1)} MB
    GC Collections: #{performance_metrics.resource_metrics.gc_collections}
    Peak Process Count: #{performance_metrics.resource_metrics.process_count_peak}
    """
  end

  defp format_performance_analysis(analysis) do
    bottlenecks_text =
      if Enum.any?(analysis.bottlenecks) do
        Enum.map_join(analysis.bottlenecks, "\n", fn bottleneck -> "    • #{bottleneck}" end)
      else
        "    ✅ No bottlenecks identified"
      end

    """
    ⚡ PERFORMANCE ANALYSIS
    ======================

    Efficiency Score: #{analysis.efficiency_score}
    Scalability: #{analysis.scalability_assessment.overall}

    Bottlenecks:
    #{bottlenecks_text}
    """
  end

  defp format_detailed_metrics(performance_metrics) do
    pipeline_lines =
      performance_metrics.pipeline_metrics
      |> Enum.sort_by(& &1.depth)
      |> Enum.map_join("\n", fn metric ->
        status = if metric.success, do: "✅", else: "❌"

        "    #{status} #{metric.pipeline_id} (depth #{metric.depth}): #{metric.duration_ms}ms, #{metric.step_count} steps"
      end)

    """
    📋 DETAILED METRICS
    ==================

    Pipeline Execution Details:
    #{pipeline_lines}
    """
  end

  defp format_recommendations(analysis) do
    recommendations_text =
      if Enum.any?(analysis.recommendations) do
        Enum.map_join(analysis.recommendations, "\n", fn rec -> "    • #{rec}" end)
      else
        "    ✅ No specific recommendations"
      end

    """
    💡 RECOMMENDATIONS
    ==================

    #{recommendations_text}
    """
  end

  defp format_comparison_report(comparisons, _options) do
    """
    📊 PERFORMANCE COMPARISON
    ========================

    Executions Compared: #{comparisons.execution_count}
    Average Duration: #{Float.round(comparisons.avg_duration, 1)}ms
    Duration Variance: #{comparisons.duration_variance}ms
    Success Rate Trend: #{comparisons.success_rate_trend}
    """
  end
end
