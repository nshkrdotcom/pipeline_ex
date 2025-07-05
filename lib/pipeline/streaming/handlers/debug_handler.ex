defmodule Pipeline.Streaming.Handlers.DebugHandler do
  @moduledoc """
  Debug handler that shows ALL message types from ClaudeCodeSDK streaming.
  Useful for understanding what messages are being sent.
  """

  @behaviour Pipeline.Streaming.AsyncHandler

  require Logger

  defstruct [:start_time, :message_count]

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      start_time: System.monotonic_time(:millisecond),
      message_count: 0
    }

    IO.puts("\n=== DEBUG STREAM START ===\n")
    {:ok, state}
  end

  @impl true
  def handle_message(%ClaudeCodeSDK.Message{} = message, state) do
    timestamp = format_timestamp()
    type_str = format_type(message.type, message.subtype)

    IO.puts("[#{timestamp}] #{type_str}")

    # Show relevant data based on message type
    case message.type do
      :assistant ->
        content = extract_text_content(message.data)
        if content, do: IO.puts("    Content: #{truncate(content, 100)}")

      :tool_use ->
        IO.puts("    Tool: #{message.data[:name]}")

        if message.data[:input],
          do: IO.puts("    Input: #{inspect(message.data[:input], limit: 3)}")

      :tool_result ->
        IO.puts("    Result: #{truncate(inspect(message.data[:content]), 80)}")

      :system when message.subtype == :init ->
        IO.puts("    Session: #{message.data[:session_id]}")
        IO.puts("    Model: #{message.data[:model]}")

      :result ->
        IO.puts("    Status: #{message.subtype}")
        IO.puts("    Duration: #{message.data[:duration_ms]}ms")

      _ ->
        IO.puts("    Data: #{inspect(message.data, limit: 3)}")
    end

    # Blank line between messages
    IO.puts("")

    {:ok, %{state | message_count: state.message_count + 1}}
  end

  @impl true
  def handle_message(_message, state) do
    # Non-ClaudeCodeSDK messages
    {:ok, state}
  end

  @impl true
  def handle_batch(messages, state) do
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
    IO.puts("=== DEBUG STREAM END ===")
    IO.puts("Total messages: #{state.message_count}")
    IO.puts("Duration: #{duration}ms")
    IO.puts("")
    {:ok, state}
  end

  @impl true
  def handle_stream_error(error, _state) do
    IO.puts("\n=== STREAM ERROR ===")
    IO.puts(inspect(error))
    {:error, "Stream error"}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp format_timestamp do
    {{_, _, _}, {h, m, s}} = :calendar.local_time()
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> List.to_string()
  end

  defp format_type(type, nil), do: "#{String.upcase(to_string(type))}"
  defp format_type(type, subtype), do: "#{String.upcase(to_string(type))}:#{subtype}"

  defp truncate(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0..max_length) <> "..."
    else
      text
    end
  end

  defp truncate(text, max_length), do: truncate(to_string(text), max_length)

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
end
