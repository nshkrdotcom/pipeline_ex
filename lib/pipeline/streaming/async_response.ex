defmodule Pipeline.Streaming.AsyncResponse do
  @moduledoc """
  Wraps async streaming responses from Claude for use in the pipeline system.

  This module provides a wrapper around message streams from ClaudeCodeSDK,
  adding metadata tracking, lazy evaluation support, and conversion capabilities
  between streaming and synchronous responses.

  ## Features

  - Lazy stream evaluation with metadata
  - Streaming metrics collection (time to first token, message count)
  - Conversion to synchronous response format
  - Stream interruption handling
  - Integration with ResultManager
  """

  require Logger

  @type stream_metrics :: %{
          first_message_time: DateTime.t() | nil,
          last_message_time: DateTime.t() | nil,
          message_count: non_neg_integer(),
          total_tokens: non_neg_integer(),
          stream_started_at: DateTime.t(),
          stream_completed_at: DateTime.t() | nil,
          interrupted: boolean()
        }

  @type t :: %__MODULE__{
          stream: Enumerable.t(),
          step_name: String.t(),
          metadata: map(),
          metrics: stream_metrics(),
          handler: module() | nil,
          options: map()
        }

  defstruct [
    :stream,
    :step_name,
    metadata: %{},
    metrics: nil,
    handler: nil,
    options: %{}
  ]

  @doc """
  Creates a new AsyncResponse wrapping a Claude message stream.

  ## Options

  - `:handler` - The async handler module to use for processing messages
  - `:buffer_size` - Number of messages to buffer before processing
  - `:metadata` - Additional metadata to attach to the response
  """
  @spec new(Enumerable.t(), String.t(), keyword()) :: t()
  def new(stream, step_name, opts \\ []) do
    %__MODULE__{
      stream: stream,
      step_name: step_name,
      metadata: Keyword.get(opts, :metadata, %{}),
      handler: Keyword.get(opts, :handler),
      options: Map.new(opts),
      metrics: %{
        first_message_time: nil,
        last_message_time: nil,
        message_count: 0,
        total_tokens: 0,
        stream_started_at: DateTime.utc_now(),
        stream_completed_at: nil,
        interrupted: false
      }
    }
  end

  @doc """
  Evaluates the stream and collects all messages into a synchronous response.

  This consumes the entire stream and returns a standard pipeline result
  compatible with non-streaming steps.
  """
  @spec to_sync_response(t()) :: {:ok, map()} | {:error, term()}
  def to_sync_response(%__MODULE__{} = async_response) do
    Logger.debug("Converting async stream to sync response for step: #{async_response.step_name}")

    start_time = System.monotonic_time(:millisecond)

    try do
      {messages, metrics} = collect_stream_with_metrics(async_response)

      # Build the final result from collected messages
      result = build_sync_result(messages, metrics, start_time)

      {:ok, result}
    catch
      :error, reason ->
        Logger.error("Stream collection failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Processes the stream through the configured handler.

  Returns the async response with updated metrics after processing.
  """
  @spec process_stream(t()) :: {:ok, t()} | {:error, term()}
  def process_stream(%__MODULE__{handler: nil}) do
    {:error, "No handler configured for async response"}
  end

  def process_stream(%__MODULE__{} = async_response) do
    Logger.debug("Processing stream with handler: #{inspect(async_response.handler)}")

    updated_response =
      async_response
      |> update_metrics_during_streaming()
      |> handle_stream_with_handler()

    {:ok, updated_response}
  end

  @doc """
  Returns the current streaming metrics.
  """
  @spec get_metrics(t()) :: stream_metrics()
  def get_metrics(%__MODULE__{metrics: metrics}), do: metrics

  @doc """
  Updates metrics with stream completion information.
  """
  @spec mark_completed(t()) :: t()
  def mark_completed(%__MODULE__{} = async_response) do
    updated_metrics = %{
      async_response.metrics
      | stream_completed_at: DateTime.utc_now()
    }

    %{async_response | metrics: updated_metrics}
  end

  @doc """
  Marks the stream as interrupted.
  """
  @spec mark_interrupted(t()) :: t()
  def mark_interrupted(%__MODULE__{} = async_response) do
    updated_metrics = %{
      async_response.metrics
      | interrupted: true,
        stream_completed_at: DateTime.utc_now()
    }

    %{async_response | metrics: updated_metrics}
  end

  @doc """
  Extracts the underlying stream for direct access.
  """
  @spec unwrap_stream(t()) :: Enumerable.t()
  def unwrap_stream(%__MODULE__{stream: stream}), do: stream

  @doc """
  Adds metadata to the async response.
  """
  @spec add_metadata(t(), map()) :: t()
  def add_metadata(%__MODULE__{} = async_response, new_metadata) do
    %{async_response | metadata: Map.merge(async_response.metadata, new_metadata)}
  end

  @doc """
  Calculates time to first token in milliseconds.

  Returns nil if no messages have been received yet.
  """
  @spec time_to_first_token(t()) :: non_neg_integer() | nil
  def time_to_first_token(%__MODULE__{metrics: metrics}) do
    case metrics.first_message_time do
      nil ->
        nil

      first_time ->
        DateTime.diff(first_time, metrics.stream_started_at, :millisecond)
    end
  end

  @doc """
  Calculates tokens per second throughput.

  Returns 0 if no tokens or insufficient time has elapsed.
  """
  @spec tokens_per_second(t()) :: float()
  def tokens_per_second(%__MODULE__{metrics: metrics}) do
    end_time = metrics.stream_completed_at || DateTime.utc_now()
    elapsed_seconds = DateTime.diff(end_time, metrics.stream_started_at, :second)

    if elapsed_seconds > 0 and metrics.total_tokens > 0 do
      metrics.total_tokens / elapsed_seconds
    else
      0.0
    end
  end

  # Private functions

  defp collect_stream_with_metrics(%__MODULE__{} = async_response) do
    initial_acc = {[], async_response.metrics}

    result =
      async_response.stream
      |> Enum.reduce(initial_acc, fn message, {messages, metrics} ->
        updated_metrics = update_metrics_for_message(metrics, message)
        {[message | messages], updated_metrics}
      end)

    case result do
      {messages, final_metrics} ->
        # Reverse to maintain original order
        {Enum.reverse(messages), final_metrics}
    end
  end

  defp update_metrics_for_message(metrics, message) do
    now = DateTime.utc_now()

    updated_metrics = %{
      metrics
      | message_count: metrics.message_count + 1,
        last_message_time: now
    }

    # Set first message time if this is the first message
    updated_metrics =
      if is_nil(metrics.first_message_time) do
        %{updated_metrics | first_message_time: now}
      else
        updated_metrics
      end

    # Update token count if message contains token information
    case extract_token_count(message) do
      nil -> updated_metrics
      count -> %{updated_metrics | total_tokens: metrics.total_tokens + count}
    end
  end

  defp extract_token_count(message) when is_map(message) do
    # Try different possible token count fields
    message[:tokens] || message["tokens"] ||
      message[:token_count] || message["token_count"] ||
      calculate_approximate_tokens(message)
  end

  defp extract_token_count(_), do: nil

  defp calculate_approximate_tokens(message) when is_map(message) do
    # Approximate token count based on content length
    content = message[:content] || message["content"] || ""

    if is_binary(content) do
      # Rough approximation: 1 token ≈ 4 characters
      div(String.length(content), 4)
    else
      nil
    end
  end

  defp build_sync_result(messages, metrics, start_time) do
    # Extract the actual response content from messages
    response_content = extract_response_content(messages)

    # Calculate duration
    duration_ms = System.monotonic_time(:millisecond) - start_time

    %{
      success: true,
      response: response_content,
      messages: messages,
      streaming_metrics: %{
        message_count: metrics.message_count,
        total_tokens: metrics.total_tokens,
        time_to_first_token_ms: time_to_first_token_ms(metrics),
        duration_ms: duration_ms,
        interrupted: metrics.interrupted
      },
      timestamp: DateTime.utc_now()
    }
  end

  defp extract_response_content(messages) do
    # Find the result message or concatenate content messages
    result_message =
      Enum.find(messages, fn msg ->
        is_map(msg) and (Map.get(msg, :type) == :result or Map.get(msg, "type") == "result")
      end)

    if result_message do
      # Use the result message content
      result_message[:content] || result_message["content"] || ""
    else
      # Concatenate all content from non-system messages
      messages
      |> Enum.filter(fn msg ->
        is_map(msg) and Map.get(msg, :type) in [:content, "content", nil]
      end)
      |> Enum.map(fn msg ->
        msg[:content] || msg["content"] || ""
      end)
      |> Enum.join("")
    end
  end

  defp time_to_first_token_ms(metrics) do
    case metrics.first_message_time do
      nil ->
        nil

      first_time ->
        DateTime.diff(first_time, metrics.stream_started_at, :millisecond)
    end
  end

  defp update_metrics_during_streaming(%__MODULE__{} = async_response) do
    # Transform the stream to update metrics as messages flow through
    updated_stream =
      Stream.transform(
        async_response.stream,
        fn -> async_response.metrics end,
        fn message, metrics ->
          updated_metrics = update_metrics_for_message(metrics, message)
          {[message], updated_metrics}
        end,
        fn metrics ->
          # Final metrics update when stream ends
          final_metrics = %{metrics | stream_completed_at: DateTime.utc_now()}
          # Store the final metrics in the process dictionary temporarily
          Process.put({:async_response_metrics, async_response.step_name}, final_metrics)
        end
      )

    %{async_response | stream: updated_stream}
  end

  defp handle_stream_with_handler(%__MODULE__{} = async_response) do
    # Let the handler process the stream
    case async_response.handler.handle_stream(
           async_response.stream,
           async_response.options
         ) do
      {:ok, processed_stream} ->
        # Retrieve final metrics if available
        final_metrics =
          case Process.get({:async_response_metrics, async_response.step_name}) do
            nil -> async_response.metrics
            metrics -> metrics
          end

        %{async_response | stream: processed_stream, metrics: final_metrics}

      {:error, reason} ->
        Logger.error("Handler failed to process stream: #{inspect(reason)}")
        mark_interrupted(async_response)
    end
  end
end
