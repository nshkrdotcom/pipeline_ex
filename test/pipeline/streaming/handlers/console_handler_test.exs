defmodule Pipeline.Streaming.Handlers.ConsoleHandlerTest do
  use ExUnit.Case, async: true

  alias Pipeline.Streaming.Handlers.ConsoleHandler
  import ExUnit.CaptureIO

  describe "init/1" do
    test "initializes with default options" do
      assert {:ok, state} = ConsoleHandler.init(%{})

      assert is_integer(state.start_time)
      assert state.message_count == 0
      assert state.token_count == 0
      assert is_map(state.format_options)
      assert state.format_options.show_header == true
      assert state.format_options.show_stats == true
      assert state.tool_use_depth == 0
    end

    test "initializes with custom format options" do
      opts = %{
        show_header: false,
        show_stats: false,
        use_colors: false
      }

      assert {:ok, state} = ConsoleHandler.init(opts)

      assert state.format_options.show_header == false
      assert state.format_options.show_stats == false
      assert state.format_options.use_colors == false
    end

    test "prints header when enabled" do
      output =
        capture_io(fn ->
          ConsoleHandler.init(%{show_header: true})
        end)

      assert output =~ "Claude Streaming Response"
      assert output =~ "╭─────────────────────────────────────────╮"
    end

    test "does not print header when disabled" do
      output =
        capture_io(fn ->
          ConsoleHandler.init(%{show_header: false})
        end)

      assert output == ""
    end
  end

  describe "handle_message/2" do
    setup do
      {:ok, state} = ConsoleHandler.init(%{show_header: false})
      %{state: state}
    end

    test "handles text messages", %{state: state} do
      message = %{
        type: :text,
        data: %{content: "Hello, world!"}
      }

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      assert output == "Hello, world!"
    end

    test "handles tool use messages", %{state: state} do
      message = %{
        type: :tool_use,
        data: %{name: "calculator", id: "tool_123"}
      }

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      assert output =~ "Tool: calculator"
      assert output =~ "ID: tool_123"
    end

    test "handles error messages", %{state: state} do
      message = %{
        type: :error,
        data: %{message: "Something went wrong"}
      }

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      assert output =~ "Error:"
      assert output =~ "Something went wrong"
    end

    test "handles token usage messages", %{state: state} do
      message = %{
        type: :token_usage,
        data: %{input_tokens: 100, output_tokens: 50, total_tokens: 150}
      }

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      assert output =~ "Tokens - Input: 100, Output: 50"
    end

    test "updates message count", %{state: state} do
      message = %{type: :text, data: %{content: "test"}}

      {:ok, new_state} = ConsoleHandler.handle_message(message, state)

      assert new_state.message_count == 1
    end

    test "updates token count for token usage messages", %{state: state} do
      message = %{
        type: :token_usage,
        data: %{total_tokens: 150}
      }

      {:ok, new_state} = ConsoleHandler.handle_message(message, state)

      assert new_state.token_count == 150
    end

    test "updates tool use depth", %{state: state} do
      tool_use = %{type: :tool_use, data: %{name: "test", id: "1"}}
      tool_result = %{type: :tool_result, data: %{content: "result"}}

      {:ok, state_after_use} = ConsoleHandler.handle_message(tool_use, state)
      assert state_after_use.tool_use_depth == 1

      {:ok, state_after_result} = ConsoleHandler.handle_message(tool_result, state_after_use)
      assert state_after_result.tool_use_depth == 0
    end

    test "includes timestamps when enabled", %{state: state} do
      state = %{state | format_options: %{state.format_options | show_timestamps: true}}
      message = %{type: :text, data: %{content: "test"}}

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      assert output =~ ~r/\[\d{2}:\d{2}:\d{2}\]/
    end

    test "hides tool use when disabled", %{state: state} do
      state = %{state | format_options: %{state.format_options | show_tool_use: false}}
      message = %{type: :tool_use, data: %{name: "test", id: "1"}}

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      assert output == ""
    end
  end

  describe "handle_batch/2" do
    setup do
      {:ok, state} = ConsoleHandler.init(%{show_header: false})
      %{state: state}
    end

    test "handles multiple messages", %{state: state} do
      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :text, data: %{content: "Second"}},
        %{type: :text, data: %{content: "Third"}}
      ]

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_batch(messages, state)
        end)

      assert output =~ "First"
      assert output =~ "Second"
      assert output =~ "Third"
    end

    test "updates message count for batch", %{state: state} do
      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :text, data: %{content: "Second"}}
      ]

      {:ok, new_state} = ConsoleHandler.handle_batch(messages, state)

      assert new_state.message_count == 2
    end

    test "updates token count for batch with token messages", %{state: state} do
      messages = [
        %{type: :token_usage, data: %{total_tokens: 100}},
        %{type: :token_usage, data: %{total_tokens: 50}}
      ]

      {:ok, new_state} = ConsoleHandler.handle_batch(messages, state)

      assert new_state.token_count == 150
    end
  end

  describe "handle_stream_end/1" do
    setup do
      {:ok, state} = ConsoleHandler.init(%{show_header: false})
      %{state: state}
    end

    test "prints statistics when enabled", %{state: state} do
      state = %{state | message_count: 5, token_count: 100}

      output =
        capture_io(fn ->
          {:ok, _final_state} = ConsoleHandler.handle_stream_end(state)
        end)

      assert output =~ "Stream Statistics"
      assert output =~ "Messages: 5"
      assert output =~ "Tokens:   100"
      assert output =~ "Duration:"
      assert output =~ "Avg/msg:"
    end

    test "does not print statistics when disabled", %{state: state} do
      state = %{state | format_options: %{state.format_options | show_stats: false}}

      output =
        capture_io(fn ->
          {:ok, _final_state} = ConsoleHandler.handle_stream_end(state)
        end)

      assert output == ""
    end
  end

  describe "handle_stream_error/2" do
    setup do
      {:ok, state} = ConsoleHandler.init(%{show_header: false})
      %{state: state}
    end

    test "prints error when enabled", %{state: state} do
      error = %{message: "Connection failed"}

      output =
        capture_io(fn ->
          {:error, _reason} = ConsoleHandler.handle_stream_error(error, state)
        end)

      assert output =~ "Stream Error"
      assert output =~ "Connection failed"
    end

    test "does not print error when disabled", %{state: state} do
      state = %{state | format_options: %{state.format_options | show_errors: false}}
      error = %{message: "Connection failed"}

      output =
        capture_io(fn ->
          {:error, _reason} = ConsoleHandler.handle_stream_error(error, state)
        end)

      assert output == ""
    end

    test "returns error tuple", %{state: state} do
      error = %{message: "Connection failed"}

      assert {:error, reason} = ConsoleHandler.handle_stream_error(error, state)
      assert reason =~ "Stream terminated with error"
    end
  end

  describe "terminate/2" do
    setup do
      {:ok, state} = ConsoleHandler.init(%{show_header: false})
      %{state: state}
    end

    test "resets ANSI colors", %{state: state} do
      output =
        capture_io(fn ->
          ConsoleHandler.terminate(:normal, state)
        end)

      # The output should contain ANSI reset sequence
      assert output =~ "\e[0m"
    end

    test "returns :ok", %{state: state} do
      assert :ok = ConsoleHandler.terminate(:normal, state)
    end
  end

  describe "color formatting" do
    setup do
      # Enable ANSI for this test
      old_ansi = Application.get_env(:pipeline, :test_ansi_enabled, false)
      Application.put_env(:pipeline, :test_ansi_enabled, true)

      {:ok, state} = ConsoleHandler.init(%{show_header: false, use_colors: true})

      on_exit(fn ->
        Application.put_env(:pipeline, :test_ansi_enabled, old_ansi)
      end)

      %{state: state}
    end

    test "uses colors when enabled", %{state: state} do
      message = %{type: :error, data: %{message: "test error"}}

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      # Should contain ANSI color codes
      assert output =~ "\e["
    end

    test "does not use colors when disabled", %{state: state} do
      # Disable ANSI for this test
      Application.put_env(:pipeline, :test_ansi_enabled, false)

      state = %{state | format_options: %{state.format_options | use_colors: false}}
      message = %{type: :error, data: %{message: "test error"}}

      output =
        capture_io(fn ->
          {:ok, _new_state} = ConsoleHandler.handle_message(message, state)
        end)

      # Should not contain ANSI color codes
      refute String.contains?(output, "\e[")
    end
  end
end
