defmodule Pipeline.Streaming.Handlers.ConsoleHandler do
  @moduledoc """
  Real-time console output handler for async message streams.

  This handler provides formatted console output with support for:
  - Colored output based on message type
  - Progress indicators
  - Tool use visualization
  - Error highlighting
  - Performance metrics
  """

  @behaviour Pipeline.Streaming.AsyncHandler

  require Logger

  defstruct [
    :start_time,
    :message_count,
    :token_count,
    :format_options,
    :last_message_time,
    :tool_use_depth
  ]

  @type t :: %__MODULE__{
          start_time: integer(),
          message_count: non_neg_integer(),
          token_count: non_neg_integer(),
          format_options: map(),
          last_message_time: integer() | nil,
          tool_use_depth: non_neg_integer()
        }

  @impl true
  def init(opts) do
    state = %__MODULE__{
      start_time: System.monotonic_time(:millisecond),
      message_count: 0,
      token_count: 0,
      format_options: Map.merge(default_format_options(), opts),
      last_message_time: nil,
      tool_use_depth: 0
    }

    if state.format_options.show_header do
      print_header()
    end

    {:ok, state}
  end

  @impl true
  def handle_message(message, state) do
    formatted = format_message(message, state)
    IO.write(formatted)

    new_state = update_state(message, state)
    {:ok, new_state}
  end

  @impl true
  def handle_batch(messages, state) do
    new_state =
      Enum.reduce(messages, state, fn message, acc_state ->
        formatted = format_message(message, acc_state)
        IO.write(formatted)
        update_state(message, acc_state)
      end)

    {:ok, new_state}
  end

  @impl true
  def handle_stream_end(state) do
    if state.format_options.show_stats do
      print_stats(state)
    end

    {:ok, state}
  end

  @impl true
  def handle_stream_error(error, state) do
    if state.format_options.show_errors do
      print_error(error, state)
    end

    {:error, "Stream terminated with error: #{inspect(error)}"}
  end

  @impl true
  def terminate(_reason, _state) do
    # Reset any terminal colors
    IO.write(IO.ANSI.reset())
    :ok
  end

  # Private functions

  defp default_format_options do
    %{
      show_header: true,
      show_stats: true,
      show_errors: true,
      show_tool_use: true,
      show_tool_results: false,
      show_timestamps: false,
      show_tokens: true,
      use_colors: true,
      indent_size: 2
    }
  end

  defp print_header do
    IO.puts(color(:cyan, "╭─────────────────────────────────────────╮"))
    IO.puts(color(:cyan, "│      Claude Streaming Response          │"))
    IO.puts(color(:cyan, "╰─────────────────────────────────────────╯"))
    IO.puts("")
  end

  defp print_stats(state) do
    duration = System.monotonic_time(:millisecond) - state.start_time
    avg_time = if state.message_count > 0, do: duration / state.message_count, else: 0

    IO.puts("")
    IO.puts(color(:green, "╭─── Stream Statistics ───╮"))
    IO.puts(color(:green, "│ Messages: #{pad_number(state.message_count, 13)} │"))
    IO.puts(color(:green, "│ Tokens:   #{pad_number(state.token_count, 13)} │"))
    IO.puts(color(:green, "│ Duration: #{pad_duration(duration, 13)} │"))
    IO.puts(color(:green, "│ Avg/msg:  #{pad_duration(round(avg_time), 13)} │"))
    IO.puts(color(:green, "╰─────────────────────────╯"))
  end

  defp print_error(error, state) do
    IO.puts("")
    IO.puts(color(:red, "╭─── Stream Error ───╮"))
    IO.puts(color(:red, "│ #{format_error(error)} │"))
    IO.puts(color(:red, "│ After #{state.message_count} messages │"))
    IO.puts(color(:red, "╰────────────────────╯"))
  end

  defp format_message(%ClaudeCodeSDK.Message{type: :assistant, data: data}, state) do
    # Handle ClaudeCodeSDK assistant messages
    content = extract_assistant_content(data)

    if content != "" do
      # Replace escaped newlines with actual newlines
      formatted_content = String.replace(content, "\\n", "\n")

      if state.format_options.show_timestamps do
        timestamp = format_timestamp()
        color(:gray, "[#{timestamp}] ") <> formatted_content
      else
        formatted_content
      end
    else
      ""
    end
  end

  defp format_message(%{type: :text, data: %{content: content}}, state) do
    if state.format_options.show_timestamps do
      timestamp = format_timestamp()
      color(:gray, "[#{timestamp}] ") <> content
    else
      content
    end
  end

  defp format_message(%{type: :tool_use, data: data}, state) do
    if state.format_options.show_tool_use do
      indent = String.duplicate(" ", state.tool_use_depth * state.format_options.indent_size)

      lines = [
        "",
        color(:yellow, "#{indent}╭─ Tool: #{data.name} ─╮"),
        color(:gray, "#{indent}│ ID: #{String.slice(data.id || "unknown", 0..7)}... │")
      ]

      lines =
        if data[:input] && state.format_options.show_tool_results do
          lines ++ [color(:gray, "#{indent}│ Input: #{inspect(data.input, limit: 50)} │")]
        else
          lines
        end

      lines = lines ++ [color(:yellow, "#{indent}╰────────────────────╯"), ""]

      Enum.join(lines, "\n")
    else
      ""
    end
  end

  defp format_message(%{type: :tool_result, data: data}, state) do
    if state.format_options.show_tool_results do
      indent =
        String.duplicate(" ", (state.tool_use_depth - 1) * state.format_options.indent_size)

      result_preview =
        case data.content do
          content when is_binary(content) -> String.slice(content, 0..100)
          content -> inspect(content, limit: 50)
        end

      lines = [
        "",
        color(:blue, "#{indent}╭─ Result ─╮"),
        color(:gray, "#{indent}│ #{result_preview}... │"),
        color(:blue, "#{indent}╰──────────╯"),
        ""
      ]

      Enum.join(lines, "\n")
    else
      ""
    end
  end

  defp format_message(%{type: :error, data: data}, _state) do
    "\n" <> color(:red, "⚠ Error: #{inspect(data)}") <> "\n"
  end

  defp format_message(%{type: :token_usage, data: data}, state) do
    if state.format_options.show_tokens do
      input = Map.get(data, :input_tokens, 0)
      output = Map.get(data, :output_tokens, 0)
      "\n" <> color(:gray, "📊 Tokens - Input: #{input}, Output: #{output}") <> "\n"
    else
      ""
    end
  end

  defp format_message(%{type: :metadata, data: data}, state) do
    if state.format_options.show_timestamps do
      "\n" <> color(:gray, "ℹ #{inspect(data, limit: 100)}") <> "\n"
    else
      ""
    end
  end

  defp format_message(%ClaudeCodeSDK.Message{} = message, state) do
    # Handle any other ClaudeCodeSDK message types
    case message.type do
      :system ->
        if state.format_options.show_timestamps do
          "\n" <> color(:gray, "[System: #{message.subtype}]") <> "\n"
        else
          ""
        end

      :result ->
        if state.format_options.show_stats do
          "\n" <> color(:green, "[Completed]") <> "\n"
        else
          ""
        end

      _ ->
        if state.format_options.show_raw_messages do
          "\n[Raw ClaudeCodeSDK: #{inspect(message, limit: 200)}]\n"
        else
          ""
        end
    end
  end

  defp format_message(_message, _state), do: ""

  defp update_state(message, state) do
    current_time = System.monotonic_time(:millisecond)

    state
    |> Map.put(:message_count, state.message_count + 1)
    |> Map.put(:last_message_time, current_time)
    |> update_token_count(message)
    |> update_tool_depth(message)
  end

  defp update_token_count(state, %{type: :token_usage, data: data}) do
    total = Map.get(data, :total_tokens, 0)
    %{state | token_count: state.token_count + total}
  end

  defp update_token_count(state, _), do: state

  defp update_tool_depth(state, %{type: :tool_use}) do
    %{state | tool_use_depth: state.tool_use_depth + 1}
  end

  defp update_tool_depth(state, %{type: :tool_result}) do
    %{state | tool_use_depth: max(0, state.tool_use_depth - 1)}
  end

  defp update_tool_depth(state, _), do: state

  defp color(color, text) do
    if io_ansi_enabled?() do
      apply(IO.ANSI, color, []) <> text <> IO.ANSI.reset()
    else
      text
    end
  end

  defp io_ansi_enabled? do
    # Check both elixir config and if we're in a test environment
    ansi_enabled = Application.get_env(:elixir, :ansi_enabled, true)
    # In tests, we might want to explicitly enable ANSI for some tests
    test_ansi = Application.get_env(:pipeline, :test_ansi_enabled, false)
    is_test = Mix.env() == :test
    (ansi_enabled and not is_test) or test_ansi
  end

  defp format_timestamp do
    {{_, _, _}, {h, m, s}} = :calendar.local_time()
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> List.to_string()
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error, limit: 50)

  defp pad_number(num, width) do
    str = Integer.to_string(num)
    String.pad_trailing(str, width)
  end

  defp pad_duration(ms, width) when ms < 1000 do
    str = "#{ms}ms"
    String.pad_trailing(str, width)
  end

  defp pad_duration(ms, width) do
    seconds = ms / 1000
    str = :io_lib.format("~.1fs", [seconds]) |> List.to_string()
    String.pad_trailing(str, width)
  end

  defp extract_assistant_content(data) when is_map(data) do
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
        ""
    end
  end

  defp extract_assistant_content(_), do: ""
end
