defmodule Pipeline.Streaming.Handlers.SimpleMessageHandler do
  @moduledoc """
  Simple handler that displays each message as it arrives from ClaudeCodeSDK.
  Shows complete messages line by line, not character streaming.
  """

  @behaviour Pipeline.Streaming.AsyncHandler

  require Logger

  defstruct [:start_time, :message_count, :show_timestamps]

  @impl true
  def init(opts) do
    state = %__MODULE__{
      start_time: System.monotonic_time(:millisecond),
      message_count: 0,
      show_timestamps: Map.get(opts, :show_timestamps, true)
    }

    {:ok, state}
  end

  @impl true
  def handle_message(%ClaudeCodeSDK.Message{type: :assistant, data: data}, state) do
    # Extract text content from assistant messages
    content = extract_text_content(data)

    if content && content != "" do
      # Format and display the message
      if state.show_timestamps do
        timestamp = format_timestamp()
        IO.puts("[#{timestamp}] ASSISTANT: #{content}")
      else
        IO.puts("ASSISTANT: #{content}")
      end

      {:ok, %{state | message_count: state.message_count + 1}}
    else
      # Skip messages without content
      {:ok, state}
    end
  end

  @impl true
  def handle_message(%ClaudeCodeSDK.Message{type: :tool_use, data: data}, state) do
    # Show tool usage
    tool_name = data[:name] || "unknown"

    if state.show_timestamps do
      timestamp = format_timestamp()
      IO.puts("[#{timestamp}] TOOL USE: #{tool_name}")
    else
      IO.puts("TOOL USE: #{tool_name}")
    end

    {:ok, %{state | message_count: state.message_count + 1}}
  end

  @impl true
  def handle_message(%ClaudeCodeSDK.Message{type: :tool_result, data: data}, state) do
    # Show tool results briefly
    if state.show_timestamps do
      timestamp = format_timestamp()
      IO.puts("[#{timestamp}] TOOL RESULT: #{get_brief_result(data)}")
    else
      IO.puts("TOOL RESULT: #{get_brief_result(data)}")
    end

    {:ok, %{state | message_count: state.message_count + 1}}
  end

  @impl true
  def handle_message(_message, state) do
    # Ignore other message types (system, result, etc.)
    {:ok, state}
  end

  @impl true
  def handle_batch(messages, state) do
    # Process each message individually
    new_state =
      Enum.reduce(messages, state, fn msg, acc ->
        case handle_message(msg, acc) do
          {:ok, new_acc} -> new_acc
        end
      end)

    {:ok, new_state}
  end

  @impl true
  def handle_stream_end(state) do
    duration = System.monotonic_time(:millisecond) - state.start_time
    IO.puts("\n✓ Stream completed: #{state.message_count} messages in #{duration}ms")
    {:ok, state}
  end

  @impl true
  def handle_stream_error(error, _state) do
    IO.puts("\n✗ Stream error: #{inspect(error)}")
    {:error, "Stream error"}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp extract_text_content(data) when is_map(data) do
    case data[:message] do
      %{"content" => content} when is_binary(content) ->
        content

      %{"content" => [%{"text" => text} | _]} when is_binary(text) ->
        text

      %{"content" => content_list} when is_list(content_list) ->
        content_list
        |> Enum.filter(&(Map.get(&1, "type") == "text"))
        |> Enum.map(&Map.get(&1, "text", ""))
        |> Enum.join("")

      _ ->
        nil
    end
  end

  defp extract_text_content(_), do: nil

  defp format_timestamp do
    {{_, _, _}, {h, m, s}} = :calendar.local_time()
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> List.to_string()
  end

  defp get_brief_result(data) do
    case data[:content] do
      content when is_binary(content) ->
        # Truncate long results
        if String.length(content) > 50 do
          String.slice(content, 0..50) <> "..."
        else
          content
        end

      _ ->
        "completed"
    end
  end
end
