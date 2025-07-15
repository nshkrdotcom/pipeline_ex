defmodule Pipeline.Monitoring.StreamingMetrics do
  @moduledoc """
  Streaming-specific performance metrics collection and analysis.

  Tracks metrics like:
  - Time to First Token (TTFT)
  - Tokens per second throughput
  - Message arrival patterns
  - Buffer efficiency
  """

  require Logger

  defstruct [
    :stream_id,
    :start_time,
    :first_message_time,
    :last_message_time,
    :message_count,
    :total_tokens,
    :message_times,
    :buffer_stats,
    :handler_type
  ]

  @type t :: %__MODULE__{
          stream_id: String.t(),
          start_time: DateTime.t(),
          first_message_time: DateTime.t() | nil,
          last_message_time: DateTime.t() | nil,
          message_count: non_neg_integer(),
          total_tokens: non_neg_integer(),
          message_times: list(DateTime.t()),
          buffer_stats: map(),
          handler_type: atom()
        }

  @doc """
  Initialize streaming metrics for a new stream.
  """
  @spec init(String.t(), atom()) :: t()
  def init(stream_id, handler_type \\ :unknown) do
    %__MODULE__{
      stream_id: stream_id,
      start_time: DateTime.utc_now(),
      first_message_time: nil,
      last_message_time: nil,
      message_count: 0,
      total_tokens: 0,
      message_times: [],
      buffer_stats: %{
        buffer_fills: 0,
        max_buffer_size: 0,
        avg_buffer_size: 0
      },
      handler_type: handler_type
    }
  end

  @doc """
  Record a message arrival in the stream.
  """
  @spec record_message(t(), map()) :: t()
  def record_message(metrics, message) do
    now = DateTime.utc_now()

    updated_metrics = %{
      metrics
      | message_count: metrics.message_count + 1,
        last_message_time: now,
        message_times: [now | metrics.message_times]
    }

    # Set first message time if not set
    updated_metrics =
      if is_nil(metrics.first_message_time) && content_message?(message) do
        %{updated_metrics | first_message_time: now}
      else
        updated_metrics
      end

    # Update token count if available
    if tokens = extract_token_count(message) do
      %{updated_metrics | total_tokens: metrics.total_tokens + tokens}
    else
      updated_metrics
    end
  end

  @doc """
  Record buffer statistics.
  """
  @spec record_buffer_stats(t(), non_neg_integer()) :: t()
  def record_buffer_stats(metrics, current_buffer_size) do
    buffer_stats = metrics.buffer_stats

    updated_stats = %{
      buffer_stats
      | buffer_fills: buffer_stats.buffer_fills + 1,
        max_buffer_size: max(buffer_stats.max_buffer_size, current_buffer_size),
        avg_buffer_size:
          calculate_running_average(
            buffer_stats.avg_buffer_size,
            current_buffer_size,
            buffer_stats.buffer_fills
          )
    }

    %{metrics | buffer_stats: updated_stats}
  end

  @doc """
  Calculate Time to First Token (TTFT) in milliseconds.
  """
  @spec calculate_ttft(t()) :: non_neg_integer() | nil
  def calculate_ttft(%__MODULE__{first_message_time: nil}), do: nil

  def calculate_ttft(%__MODULE__{start_time: start, first_message_time: first}) do
    DateTime.diff(first, start, :millisecond)
  end

  @doc """
  Calculate tokens per second throughput.
  """
  @spec calculate_throughput(t()) :: float() | nil
  def calculate_throughput(%__MODULE__{total_tokens: 0}), do: nil
  def calculate_throughput(%__MODULE__{last_message_time: nil}), do: nil

  def calculate_throughput(metrics) do
    duration_seconds =
      DateTime.diff(metrics.last_message_time, metrics.start_time, :millisecond) / 1000

    if duration_seconds > 0 do
      metrics.total_tokens / duration_seconds
    else
      nil
    end
  end

  @doc """
  Calculate average time between messages.
  """
  @spec calculate_message_interval(t()) :: float() | nil
  def calculate_message_interval(%__MODULE__{message_times: times}) when length(times) < 2,
    do: nil

  def calculate_message_interval(%__MODULE__{message_times: times}) do
    times
    |> Enum.reverse()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [t1, t2] -> DateTime.diff(t2, t1, :millisecond) end)
    |> average()
  end

  @doc """
  Generate a performance summary.
  """
  @spec summarize(t()) :: map()
  def summarize(metrics) do
    total_duration =
      if metrics.last_message_time do
        DateTime.diff(metrics.last_message_time, metrics.start_time, :millisecond)
      else
        0
      end

    %{
      stream_id: metrics.stream_id,
      handler_type: metrics.handler_type,
      time_to_first_token_ms: calculate_ttft(metrics),
      total_duration_ms: total_duration,
      message_count: metrics.message_count,
      total_tokens: metrics.total_tokens,
      tokens_per_second: calculate_throughput(metrics),
      avg_message_interval_ms: calculate_message_interval(metrics),
      buffer_efficiency: calculate_buffer_efficiency(metrics),
      performance_grade: grade_performance(metrics)
    }
  end

  @doc """
  Compare two streaming sessions.
  """
  @spec compare(t(), t()) :: map()
  def compare(metrics1, metrics2) do
    summary1 = summarize(metrics1)
    summary2 = summarize(metrics2)

    %{
      ttft_improvement:
        calculate_improvement(
          summary1.time_to_first_token_ms,
          summary2.time_to_first_token_ms
        ),
      throughput_improvement:
        calculate_improvement(
          summary1.tokens_per_second,
          summary2.tokens_per_second
        ),
      duration_improvement:
        calculate_improvement(
          summary1.total_duration_ms,
          summary2.total_duration_ms
        ),
      recommendation: generate_comparison_recommendation(summary1, summary2)
    }
  end

  # Private functions

  defp content_message?(%{type: :assistant}), do: true
  defp content_message?(%{type: "assistant"}), do: true
  defp content_message?(_), do: false

  defp extract_token_count(%{data: %{token_count: count}}), do: count
  defp extract_token_count(%{tokens: count}) when is_integer(count), do: count
  defp extract_token_count(_), do: nil

  defp calculate_running_average(current_avg, new_value, count) do
    (current_avg * (count - 1) + new_value) / count
  end

  defp average([]), do: nil

  defp average(list) do
    Enum.sum(list) / length(list)
  end

  defp calculate_buffer_efficiency(metrics) do
    if metrics.buffer_stats.buffer_fills > 0 do
      efficiency =
        metrics.buffer_stats.avg_buffer_size / max(metrics.buffer_stats.max_buffer_size, 1)

      Float.round(efficiency * 100, 2)
    else
      100.0
    end
  end

  defp grade_performance(metrics) do
    ttft = calculate_ttft(metrics) || 999_999
    throughput = calculate_throughput(metrics) || 0

    cond do
      ttft < 500 && throughput > 100 -> :excellent
      ttft < 1000 && throughput > 50 -> :good
      ttft < 2000 && throughput > 20 -> :acceptable
      true -> :needs_improvement
    end
  end

  defp calculate_improvement(nil, _), do: nil
  defp calculate_improvement(_, nil), do: nil

  defp calculate_improvement(baseline, current) when baseline > 0 do
    improvement = (baseline - current) / baseline * 100
    Float.round(improvement, 2)
  end

  defp calculate_improvement(_, _), do: nil

  defp generate_comparison_recommendation(summary1, summary2) do
    cond do
      summary1.performance_grade == :excellent && summary2.performance_grade == :excellent ->
        "Both configurations perform excellently. Choose based on other factors."

      summary1.time_to_first_token_ms && summary2.time_to_first_token_ms &&
          summary1.time_to_first_token_ms < summary2.time_to_first_token_ms ->
        "First configuration has better time to first token."

      summary1.tokens_per_second && summary2.tokens_per_second &&
          summary1.tokens_per_second > summary2.tokens_per_second ->
        "First configuration has better throughput."

      true ->
        "Performance is comparable. Consider testing with larger datasets."
    end
  end
end
