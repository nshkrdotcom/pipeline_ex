defmodule Pipeline.Streaming.PerformanceAnalyzer do
  @moduledoc """
  Analyzes streaming performance and provides optimization recommendations.

  This module hooks into the streaming pipeline to collect detailed metrics
  and identify bottlenecks or optimization opportunities.
  """

  require Logger
  alias Pipeline.Monitoring.StreamingMetrics

  @optimization_thresholds %{
    # ms
    ttft_excellent: 500,
    # ms
    ttft_good: 1000,
    # ms
    ttft_acceptable: 2000,
    # tokens/sec
    throughput_excellent: 150,
    # tokens/sec
    throughput_good: 75,
    # tokens/sec
    throughput_acceptable: 30,
    # %
    buffer_efficiency_min: 70
  }

  defstruct [
    :active_streams,
    :completed_streams,
    :performance_issues,
    :recommendations
  ]

  @type t :: %__MODULE__{
          active_streams: map(),
          completed_streams: list(StreamingMetrics.t()),
          performance_issues: list(map()),
          recommendations: list(String.t())
        }

  @doc """
  Start a new performance analyzer.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      active_streams: %{},
      completed_streams: [],
      performance_issues: [],
      recommendations: []
    }
  end

  @doc """
  Start tracking a new stream.
  """
  @spec start_stream(t(), String.t(), atom()) :: t()
  def start_stream(analyzer, stream_id, handler_type) do
    metrics = StreamingMetrics.init(stream_id, handler_type)
    put_in(analyzer.active_streams[stream_id], metrics)
  end

  @doc """
  Record a message in an active stream.
  """
  @spec record_message(t(), String.t(), map()) :: t()
  def record_message(analyzer, stream_id, message) do
    case analyzer.active_streams[stream_id] do
      nil ->
        Logger.warning("Attempted to record message for unknown stream: #{stream_id}")
        analyzer

      metrics ->
        updated_metrics = StreamingMetrics.record_message(metrics, message)
        put_in(analyzer.active_streams[stream_id], updated_metrics)
    end
  end

  @doc """
  Complete a stream and move it to completed list.
  """
  @spec complete_stream(t(), String.t()) :: t()
  def complete_stream(analyzer, stream_id) do
    case Map.pop(analyzer.active_streams, stream_id) do
      {nil, _} ->
        analyzer

      {metrics, remaining_active} ->
        issues = identify_performance_issues(metrics)

        %{
          analyzer
          | active_streams: remaining_active,
            completed_streams: [metrics | analyzer.completed_streams],
            performance_issues: issues ++ analyzer.performance_issues
        }
    end
  end

  @doc """
  Analyze all completed streams and generate recommendations.
  """
  @spec analyze(t()) :: t()
  def analyze(analyzer) do
    recommendations = generate_recommendations(analyzer)
    %{analyzer | recommendations: recommendations}
  end

  @doc """
  Get performance report for all streams.
  """
  @spec get_report(t()) :: map()
  def get_report(analyzer) do
    completed_summaries = Enum.map(analyzer.completed_streams, &StreamingMetrics.summarize/1)

    %{
      total_streams: length(analyzer.completed_streams),
      active_streams: map_size(analyzer.active_streams),
      average_ttft_ms: calculate_average_metric(completed_summaries, :time_to_first_token_ms),
      average_throughput: calculate_average_metric(completed_summaries, :tokens_per_second),
      performance_distribution: calculate_performance_distribution(completed_summaries),
      issues_found: length(analyzer.performance_issues),
      top_issues: Enum.take(analyzer.performance_issues, 5),
      recommendations: analyzer.recommendations,
      detailed_metrics: completed_summaries
    }
  end

  @doc """
  Identify bottlenecks in streaming performance.
  """
  @spec identify_bottlenecks(t()) :: list(map())
  def identify_bottlenecks(analyzer) do
    analyzer.completed_streams
    |> Enum.flat_map(&analyze_stream_bottlenecks/1)
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, issues} ->
      %{
        bottleneck_type: type,
        occurrence_count: length(issues),
        severity: calculate_severity(issues),
        examples: Enum.take(issues, 3)
      }
    end)
    |> Enum.sort_by(& &1.severity, :desc)
  end

  @doc """
  Compare streaming vs non-streaming performance.
  """
  @spec compare_modes(list(StreamingMetrics.t()), list(map())) :: map()
  def compare_modes(streaming_results, sync_results) do
    streaming_avg_ttft =
      streaming_results
      |> Enum.map(&StreamingMetrics.calculate_ttft/1)
      |> Enum.reject(&is_nil/1)
      |> average()

    sync_avg_duration =
      sync_results
      |> Enum.map(& &1[:duration_ms])
      |> Enum.reject(&is_nil/1)
      |> average()

    %{
      streaming_ttft_ms: streaming_avg_ttft,
      sync_total_duration_ms: sync_avg_duration,
      ttft_improvement_percent:
        if(sync_avg_duration && streaming_avg_ttft,
          do: Float.round((sync_avg_duration - streaming_avg_ttft) / sync_avg_duration * 100, 2),
          else: nil
        ),
      recommendation: determine_mode_recommendation(streaming_avg_ttft, sync_avg_duration)
    }
  end

  # Private functions

  defp identify_performance_issues(metrics) do
    summary = StreamingMetrics.summarize(metrics)
    issues = []

    # Check TTFT
    issues =
      if summary.time_to_first_token_ms &&
           summary.time_to_first_token_ms > @optimization_thresholds.ttft_acceptable do
        [
          %{
            type: :slow_ttft,
            stream_id: metrics.stream_id,
            value: summary.time_to_first_token_ms,
            threshold: @optimization_thresholds.ttft_acceptable,
            severity: :high
          }
          | issues
        ]
      else
        issues
      end

    # Check throughput
    issues =
      if summary.tokens_per_second &&
           summary.tokens_per_second < @optimization_thresholds.throughput_acceptable do
        [
          %{
            type: :low_throughput,
            stream_id: metrics.stream_id,
            value: summary.tokens_per_second,
            threshold: @optimization_thresholds.throughput_acceptable,
            severity: :medium
          }
          | issues
        ]
      else
        issues
      end

    # Check buffer efficiency
    issues =
      if summary.buffer_efficiency != nil &&
           summary.buffer_efficiency < @optimization_thresholds.buffer_efficiency_min do
        [
          %{
            type: :inefficient_buffering,
            stream_id: metrics.stream_id,
            value: summary.buffer_efficiency,
            threshold: @optimization_thresholds.buffer_efficiency_min,
            severity: :low
          }
          | issues
        ]
      else
        issues
      end

    issues
  end

  defp generate_recommendations(analyzer) do
    recommendations = []

    # Analyze TTFT patterns
    avg_ttft =
      calculate_average_metric(
        Enum.map(analyzer.completed_streams, &StreamingMetrics.summarize/1),
        :time_to_first_token_ms
      )

    recommendations =
      if avg_ttft && avg_ttft > @optimization_thresholds.ttft_good do
        ["Consider enabling connection pooling to reduce TTFT" | recommendations]
      else
        recommendations
      end

    # Analyze throughput patterns
    throughput_issues = Enum.filter(analyzer.performance_issues, &(&1.type == :low_throughput))

    recommendations =
      if length(throughput_issues) > 3 do
        ["Increase stream buffer size to improve throughput" | recommendations]
      else
        recommendations
      end

    # Analyze buffer efficiency
    buffer_issues = Enum.filter(analyzer.performance_issues, &(&1.type == :inefficient_buffering))

    recommendations =
      if length(buffer_issues) > 2 do
        ["Optimize buffer size based on message patterns" | recommendations]
      else
        recommendations
      end

    # Handler-specific recommendations
    handler_distribution =
      analyzer.completed_streams
      |> Enum.group_by(& &1.handler_type)
      |> Enum.map(fn {handler, streams} -> {handler, length(streams)} end)
      |> Map.new()

    recommendations =
      if handler_distribution[:console] && handler_distribution[:console] > 10 do
        ["Consider using 'simple' handler for better performance in production" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp analyze_stream_bottlenecks(metrics) do
    summary = StreamingMetrics.summarize(metrics)
    bottlenecks = []

    # Message interval analysis
    bottlenecks =
      if summary.avg_message_interval_ms && summary.avg_message_interval_ms > 1000 do
        [
          %{
            type: :message_delay,
            description: "Large gaps between messages",
            impact: "Reduced perceived performance",
            value: summary.avg_message_interval_ms
          }
          | bottlenecks
        ]
      else
        bottlenecks
      end

    # Token rate analysis
    bottlenecks =
      if summary.tokens_per_second && summary.tokens_per_second < 50 do
        [
          %{
            type: :token_generation,
            description: "Slow token generation rate",
            impact: "Extended wait times",
            value: summary.tokens_per_second
          }
          | bottlenecks
        ]
      else
        bottlenecks
      end

    bottlenecks
  end

  defp calculate_average_metric(summaries, key) do
    values =
      summaries
      |> Enum.map(&Map.get(&1, key))
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(values), do: nil, else: average(values)
  end

  defp calculate_performance_distribution(summaries) do
    summaries
    |> Enum.map(& &1.performance_grade)
    |> Enum.frequencies()
  end

  defp calculate_severity(issues) do
    severity_scores = %{high: 3, medium: 2, low: 1}

    total_score =
      issues
      |> Enum.map(&(severity_scores[&1.severity] || 1))
      |> Enum.sum()

    avg_score = total_score / max(length(issues), 1)

    cond do
      avg_score >= 2.5 -> :high
      avg_score >= 1.5 -> :medium
      true -> :low
    end
  end

  defp average([]), do: nil
  defp average(list), do: Enum.sum(list) / length(list)

  defp determine_mode_recommendation(nil, _), do: "Insufficient data for recommendation"
  defp determine_mode_recommendation(_, nil), do: "Insufficient data for recommendation"

  defp determine_mode_recommendation(streaming_ttft, sync_duration) do
    improvement_ratio = streaming_ttft / sync_duration

    cond do
      improvement_ratio < 0.3 ->
        "Strongly recommend streaming mode for significant TTFT improvement"

      improvement_ratio < 0.6 ->
        "Streaming mode recommended for better user experience"

      improvement_ratio < 0.9 ->
        "Streaming provides modest benefits, use based on requirements"

      true ->
        "Sync mode may be preferable for this use case"
    end
  end
end
