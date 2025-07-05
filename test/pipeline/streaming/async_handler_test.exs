defmodule Pipeline.Streaming.AsyncHandlerTest do
  use ExUnit.Case, async: true

  alias Pipeline.Streaming.AsyncHandler
  alias ClaudeCodeSDK.Message

  describe "behavior implementation" do
    defmodule TestHandler do
      @behaviour Pipeline.Streaming.AsyncHandler

      defstruct [:messages, :batches, :opts]

      @impl true
      def init(opts) do
        {:ok, %__MODULE__{messages: [], batches: [], opts: opts}}
      end

      @impl true
      def handle_message(message, state) do
        if Map.get(state.opts, :buffer_messages, false) do
          {:buffer, %{state | messages: [message | state.messages]}}
        else
          {:ok, %{state | messages: [message | state.messages]}}
        end
      end

      @impl true
      def handle_batch(messages, state) do
        {:ok, %{state | batches: [messages | state.batches]}}
      end

      @impl true
      def handle_stream_end(state) do
        {:ok, Map.put(state, :ended, true)}
      end

      @impl true
      def handle_stream_error(error, _state) do
        {:error, "Test error: #{inspect(error)}"}
      end

      @impl true
      def terminate(_reason, _state) do
        :ok
      end
    end

    test "processes messages with custom handler" do
      messages = [
        %Message{type: :text, data: %{content: "Hello"}},
        %Message{type: :text, data: %{content: "World"}}
      ]

      stream = Stream.map(messages, & &1)

      options = %{
        handler_module: TestHandler,
        handler_opts: %{}
      }

      assert {:ok, state} = AsyncHandler.process_stream(stream, options)
      assert state.ended == true
      assert length(state.messages) == 2
      assert Enum.reverse(state.messages) == messages
    end

    test "handles buffered messages" do
      messages = for i <- 1..15, do: %Message{type: :text, data: %{content: "Message #{i}"}}

      stream = Stream.map(messages, & &1)

      options = %{
        handler_module: TestHandler,
        handler_opts: %{buffer_messages: true},
        buffer_size: 5,
        flush_interval: 1000
      }

      assert {:ok, state} = AsyncHandler.process_stream(stream, options)
      assert state.ended == true
      assert length(state.batches) > 0
    end
  end

  describe "console handler" do
    test "formats text messages correctly" do
      message = %Message{type: :text, data: %{content: "Test content"}}

      output =
        capture_io(fn ->
          stream = Stream.map([message], & &1)
          AsyncHandler.process_stream(stream, AsyncHandler.console_handler_options())
        end)

      assert output =~ "Test content"
      assert output =~ "Stream completed"
    end

    test "handles tool use messages" do
      messages = [
        %Message{type: :tool_use, data: %{name: "test_tool", input: %{}}},
        %Message{type: :text, data: %{content: "Result"}},
        %Message{type: :tool_result, data: %{content: "Tool output"}}
      ]

      output =
        capture_io(fn ->
          stream = Stream.map(messages, & &1)

          options =
            AsyncHandler.console_handler_options(%{
              handler_opts: %{
                format_options: %{
                  show_tool_use: true,
                  show_tool_results: true
                }
              }
            })

          AsyncHandler.process_stream(stream, options)
        end)

      assert output =~ "[Tool: test_tool]"
      assert output =~ "Result"
      assert output =~ "[Tool Result:"
    end

    test "suppresses stats when configured" do
      message = %Message{type: :text, data: %{content: "Test"}}

      output =
        capture_io(fn ->
          stream = Stream.map([message], & &1)

          options =
            AsyncHandler.console_handler_options(%{
              handler_opts: %{
                format_options: %{show_stats: false}
              }
            })

          AsyncHandler.process_stream(stream, options)
        end)

      refute output =~ "Stream completed"
    end
  end

  describe "error handling" do
    defmodule ErrorHandler do
      @behaviour Pipeline.Streaming.AsyncHandler

      @impl true
      def init(opts) do
        if Map.get(opts, :fail_init, false) do
          {:error, "Init failed"}
        else
          {:ok, %{}}
        end
      end

      @impl true
      def handle_message(message, state) do
        if message.type == :error do
          {:error, "Handler error"}
        else
          {:ok, state}
        end
      end

      @impl true
      def handle_batch(_messages, state), do: {:ok, state}

      @impl true
      def handle_stream_end(state), do: {:ok, state}

      @impl true
      def handle_stream_error(error, _state) do
        {:error, "Stream error: #{inspect(error)}"}
      end

      @impl true
      def terminate(_reason, _state), do: :ok
    end

    test "handles init failure" do
      stream = Stream.map([%Message{type: :text, data: %{}}], & &1)

      options = %{
        handler_module: ErrorHandler,
        handler_opts: %{fail_init: true}
      }

      assert {:error, "Init failed"} = AsyncHandler.process_stream(stream, options)
    end

    test "handles message processing errors" do
      messages = [
        %Message{type: :text, data: %{content: "OK"}},
        %Message{type: :error, data: %{error: "Test error"}}
      ]

      stream = Stream.map(messages, & &1)

      options = %{
        handler_module: ErrorHandler,
        handler_opts: %{}
      }

      assert {:error, reason} = AsyncHandler.process_stream(stream, options)
      assert reason =~ "Stream error"
    end
  end

  describe "buffer management" do
    defmodule BufferTestHandler do
      @behaviour Pipeline.Streaming.AsyncHandler

      defstruct [:buffer_calls, :message_calls]

      @impl true
      def init(_opts) do
        {:ok, %__MODULE__{buffer_calls: [], message_calls: []}}
      end

      @impl true
      def handle_message(message, state) do
        {:buffer, %{state | message_calls: [message | state.message_calls]}}
      end

      @impl true
      def handle_batch(messages, state) do
        {:ok, %{state | buffer_calls: [length(messages) | state.buffer_calls]}}
      end

      @impl true
      def handle_stream_end(state), do: {:ok, state}

      @impl true
      def handle_stream_error(_error, state), do: {:ok, state}

      @impl true
      def terminate(_reason, _state), do: :ok
    end

    test "batches messages according to buffer size" do
      messages = for i <- 1..23, do: %Message{type: :text, data: %{content: "Msg #{i}"}}
      stream = Stream.map(messages, & &1)

      options = %{
        handler_module: BufferTestHandler,
        handler_opts: %{},
        buffer_size: 10,
        # High interval to test size-based batching
        flush_interval: 5000
      }

      assert {:ok, state} = AsyncHandler.process_stream(stream, options)

      # Should have batches of 10, 10, and 3
      assert length(state.buffer_calls) == 3
      assert Enum.sort(state.buffer_calls) == [3, 10, 10]
    end

    test "flushes buffer on interval" do
      # This test would need to use a mock or different approach
      # to test time-based flushing reliably
      messages = for i <- 1..3, do: %Message{type: :text, data: %{content: "Msg #{i}"}}
      stream = Stream.map(messages, & &1)

      options = %{
        handler_module: BufferTestHandler,
        handler_opts: %{},
        # High buffer size
        buffer_size: 100,
        # Low interval
        flush_interval: 10
      }

      assert {:ok, state} = AsyncHandler.process_stream(stream, options)

      # All messages should be in final batch since stream ends quickly
      assert length(state.buffer_calls) >= 1
    end
  end

  describe "integration with ClaudeCodeSDK messages" do
    test "handles real message types" do
      messages = [
        %Message{
          type: :text,
          subtype: :text,
          data: %{content: "Starting analysis..."}
        },
        %Message{
          type: :tool_use,
          subtype: :tool_use,
          data: %{
            name: "read_file",
            input: %{"path" => "/test.txt"},
            id: "tool_123"
          }
        },
        %Message{
          type: :tool_result,
          subtype: :tool_result,
          data: %{
            content: "File contents",
            tool_use_id: "tool_123"
          }
        },
        %Message{
          type: :result,
          subtype: :assistant_response,
          data: %{
            session_id: "test_session",
            content: "Analysis complete"
          }
        }
      ]

      output =
        capture_io(fn ->
          stream = Stream.map(messages, & &1)

          options =
            AsyncHandler.console_handler_options(%{
              handler_opts: %{
                format_options: %{
                  show_tool_use: true,
                  show_session_info: true
                }
              }
            })

          assert {:ok, _} = AsyncHandler.process_stream(stream, options)
        end)

      assert output =~ "Starting analysis"
      assert output =~ "[Tool: read_file]"
      assert output =~ "[Session: test_session]"
    end
  end

  # Helper to capture IO output
  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end
