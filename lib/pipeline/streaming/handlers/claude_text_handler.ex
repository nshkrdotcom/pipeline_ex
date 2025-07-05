defmodule Pipeline.Streaming.Handlers.ClaudeTextHandler do
  @moduledoc """
  A specialized handler for ClaudeCodeSDK messages that extracts and displays
  only the text content from assistant messages.
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

    {:ok, state}
  end

  @impl true
  def handle_message(message, state) do
    # Extract and display text from ClaudeCodeSDK messages
    case extract_text_content(message) do
      {:ok, text} when text != "" ->
        IO.write(text)
        {:ok, %{state | message_count: state.message_count + 1}}

      _ ->
        # Skip non-text messages
        {:ok, state}
    end
  end

  @impl true
  def handle_batch(messages, state) do
    new_count =
      Enum.reduce(messages, state.message_count, fn message, count ->
        case extract_text_content(message) do
          {:ok, text} when text != "" ->
            IO.write(text)
            count + 1

          _ ->
            count
        end
      end)

    {:ok, %{state | message_count: new_count}}
  end

  @impl true
  def handle_stream_end(state) do
    duration = System.monotonic_time(:millisecond) - state.start_time
    IO.puts("\n\nStream completed in #{duration}ms")
    {:ok, state}
  end

  @impl true
  def handle_stream_error(error, _state) do
    IO.puts("\n\nStream error: #{inspect(error)}")
    {:error, "Stream terminated with error"}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  # Extract text content from various message formats
  defp extract_text_content(%ClaudeCodeSDK.Message{type: :assistant, data: data}) do
    case data[:message] do
      %{"content" => content} when is_binary(content) ->
        {:ok, content}

      %{"content" => [%{"text" => text} | _]} when is_binary(text) ->
        {:ok, text}

      %{"content" => content_list} when is_list(content_list) ->
        text =
          content_list
          |> Enum.filter(&(Map.get(&1, "type") == "text"))
          |> Enum.map(&Map.get(&1, "text", ""))
          |> Enum.join("")

        {:ok, text}

      _ ->
        {:error, :no_text}
    end
  end

  defp extract_text_content(_), do: {:error, :not_assistant_message}
end
