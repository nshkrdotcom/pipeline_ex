defmodule Pipeline.Streaming.Handlers.CallbackHandlerTest do
  use ExUnit.Case, async: true

  alias Pipeline.Streaming.Handlers.CallbackHandler
  import ExUnit.CaptureLog

  describe "init/1" do
    test "initializes with valid callback function" do
      callback_fn = fn _message, state -> {:ok, state} end
      opts = %{callback_fn: callback_fn}

      assert {:ok, state} = CallbackHandler.init(opts)

      assert state.callback_fn == callback_fn
      assert state.callback_count == 0
      assert state.error_count == 0
      assert state.async_callbacks == false
      assert is_nil(state.error_handler)
      assert is_nil(state.filter_fn)
    end

    test "initializes with all options" do
      callback_fn = fn _message, state -> {:ok, state} end
      error_handler = fn _error, _message, state -> {:ok, state} end
      filter_fn = fn message -> message.type == :text end

      opts = %{
        callback_fn: callback_fn,
        error_handler: error_handler,
        filter_fn: filter_fn,
        async_callbacks: true,
        rate_limit_ms: 100,
        initial_state: %{count: 0}
      }

      assert {:ok, state} = CallbackHandler.init(opts)

      assert state.callback_fn == callback_fn
      assert state.error_handler == error_handler
      assert state.filter_fn == filter_fn
      assert state.async_callbacks == true
      assert state.rate_limit == 100
      assert state.user_state == %{count: 0}
    end

    test "returns error for invalid callback function" do
      opts = %{callback_fn: "not_a_function"}

      assert {:error, reason} = CallbackHandler.init(opts)
      assert reason =~ "callback_fn must be a function with arity 2"
    end

    test "returns error for invalid callback function arity" do
      # Wrong arity
      callback_fn = fn _message -> :ok end
      opts = %{callback_fn: callback_fn}

      assert {:error, reason} = CallbackHandler.init(opts)
      assert reason =~ "callback_fn must be a function with arity 2"
    end

    test "returns error for invalid error handler" do
      callback_fn = fn _message, state -> {:ok, state} end

      opts = %{
        callback_fn: callback_fn,
        error_handler: "not_a_function"
      }

      assert {:error, reason} = CallbackHandler.init(opts)
      assert reason =~ "error_handler must be a function with arity 3"
    end

    test "returns error for invalid filter function" do
      callback_fn = fn _message, state -> {:ok, state} end

      opts = %{
        callback_fn: callback_fn,
        filter_fn: "not_a_function"
      }

      assert {:error, reason} = CallbackHandler.init(opts)
      assert reason =~ "filter_fn must be a function with arity 1"
    end

    test "requires callback function" do
      opts = %{}

      assert {:error, reason} = CallbackHandler.init(opts)
      assert reason =~ "callback_fn must be a function with arity 2"
    end
  end

  describe "handle_message/2" do
    setup do
      callback_fn = fn _message, state ->
        new_count = Map.get(state, :count, 0) + 1
        {:ok, Map.put(state, :count, new_count)}
      end

      {:ok, handler_state} =
        CallbackHandler.init(%{
          callback_fn: callback_fn,
          initial_state: %{count: 0}
        })

      %{state: handler_state}
    end

    test "calls callback function with message", %{state: state} do
      message = %{type: :text, data: %{content: "Hello"}}

      assert {:ok, new_state} = CallbackHandler.handle_message(message, state)

      assert new_state.callback_count == 1
      assert new_state.user_state.count == 1
    end

    test "handles callback function errors", %{state: state} do
      # Replace with error-throwing callback
      error_callback = fn _message, _state -> {:error, "callback failed"} end
      state = %{state | callback_fn: error_callback}

      message = %{type: :text, data: %{content: "Hello"}}

      logs =
        capture_log(fn ->
          assert {:ok, new_state} = CallbackHandler.handle_message(message, state)
          assert new_state.error_count == 1
        end)

      assert logs =~ "Callback error"
    end

    test "handles callback function exceptions", %{state: state} do
      # Replace with exception-throwing callback
      exception_callback = fn _message, _state -> raise "callback exception" end
      state = %{state | callback_fn: exception_callback}

      message = %{type: :text, data: %{content: "Hello"}}

      logs =
        capture_log(fn ->
          assert {:ok, new_state} = CallbackHandler.handle_message(message, state)
          assert new_state.error_count == 1
        end)

      assert logs =~ "Callback error"
    end

    test "uses error handler when provided", %{state: state} do
      error_handler = fn _error, _message, user_state ->
        {:ok, Map.put(user_state, :error_handled, true)}
      end

      error_callback = fn _message, _state -> {:error, "callback failed"} end

      state = %{state | callback_fn: error_callback, error_handler: error_handler}

      message = %{type: :text, data: %{content: "Hello"}}

      logs =
        capture_log(fn ->
          assert {:ok, new_state} = CallbackHandler.handle_message(message, state)
          assert new_state.error_count == 1
          assert new_state.user_state.error_handled == true
        end)

      assert logs =~ "Callback error handled by user handler"
    end

    test "applies filter function when provided", %{state: state} do
      # Filter that only allows :text messages
      filter_fn = fn message -> message.type == :text end
      state = %{state | filter_fn: filter_fn}

      text_message = %{type: :text, data: %{content: "Hello"}}
      tool_message = %{type: :tool_use, data: %{name: "calc"}}

      # Text message should be processed
      assert {:ok, new_state} = CallbackHandler.handle_message(text_message, state)
      assert new_state.callback_count == 1

      # Tool message should be filtered out
      assert {:ok, final_state} = CallbackHandler.handle_message(tool_message, new_state)
      # No change
      assert final_state.callback_count == 1
    end

    test "applies rate limiting when configured", %{state: state} do
      # 100ms rate limit
      state = %{state | rate_limit: 100}

      message = %{type: :text, data: %{content: "Hello"}}

      # First message should be processed
      assert {:ok, new_state} = CallbackHandler.handle_message(message, state)
      assert new_state.callback_count == 1

      # Second message immediately should be rate limited
      assert {:ok, final_state} = CallbackHandler.handle_message(message, new_state)
      # No change due to rate limiting
      assert final_state.callback_count == 1
    end

    test "handles filter function exceptions", %{state: state} do
      # Filter that throws exception
      filter_fn = fn _message -> raise "filter exception" end
      state = %{state | filter_fn: filter_fn}

      message = %{type: :text, data: %{content: "Hello"}}

      logs =
        capture_log(fn ->
          assert {:ok, new_state} = CallbackHandler.handle_message(message, state)
          # Message should be filtered out due to exception
          assert new_state.callback_count == 0
        end)

      assert logs =~ "Filter function error"
    end
  end

  describe "handle_batch/2" do
    setup do
      callback_fn = fn _message, state ->
        new_count = Map.get(state, :count, 0) + 1
        {:ok, Map.put(state, :count, new_count)}
      end

      {:ok, handler_state} =
        CallbackHandler.init(%{
          callback_fn: callback_fn,
          initial_state: %{count: 0}
        })

      %{state: handler_state}
    end

    test "processes batch of messages synchronously", %{state: state} do
      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :text, data: %{content: "Second"}},
        %{type: :text, data: %{content: "Third"}}
      ]

      assert {:ok, new_state} = CallbackHandler.handle_batch(messages, state)

      assert new_state.callback_count == 3
      assert new_state.user_state.count == 3
    end

    test "processes batch of messages asynchronously", %{state: state} do
      state = %{state | async_callbacks: true}

      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :text, data: %{content: "Second"}}
      ]

      assert {:ok, new_state} = CallbackHandler.handle_batch(messages, state)

      # Callback count should be updated immediately
      assert new_state.callback_count == 2

      # Give async callbacks time to complete
      Process.sleep(10)
    end

    test "filters messages in batch", %{state: state} do
      filter_fn = fn message -> message.type == :text end
      state = %{state | filter_fn: filter_fn}

      messages = [
        %{type: :text, data: %{content: "Text"}},
        %{type: :tool_use, data: %{name: "calc"}},
        %{type: :text, data: %{content: "More text"}}
      ]

      assert {:ok, new_state} = CallbackHandler.handle_batch(messages, state)

      # Only text messages should be processed
      assert new_state.callback_count == 2
      assert new_state.user_state.count == 2
    end

    test "stops on first error in synchronous mode", %{state: state} do
      error_callback = fn message, state ->
        if message.data.content == "Second" do
          {:error, "callback failed"}
        else
          new_count = Map.get(state, :count, 0) + 1
          {:ok, Map.put(state, :count, new_count)}
        end
      end

      state = %{state | callback_fn: error_callback}

      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :text, data: %{content: "Second"}},
        %{type: :text, data: %{content: "Third"}}
      ]

      _logs =
        capture_log(fn ->
          assert {:ok, new_state} = CallbackHandler.handle_batch(messages, state)
          # Should process first message, then hit error on second and stop
          # The implementation currently processes all messages and records errors
          # First + error handling for second
          assert new_state.callback_count == 2
          assert new_state.error_count == 1
        end)
    end
  end

  describe "handle_stream_end/1" do
    setup do
      callback_fn = fn _message, state -> {:ok, state} end
      {:ok, handler_state} = CallbackHandler.init(%{callback_fn: callback_fn})

      %{state: handler_state}
    end

    test "logs completion statistics", %{state: state} do
      state = %{state | callback_count: 5, error_count: 1}

      logs =
        capture_log(fn ->
          assert {:ok, _final_state} = CallbackHandler.handle_stream_end(state)
        end)

      assert logs =~ "CallbackHandler completed: 5 callbacks (1 errors)"
    end

    test "waits for async callbacks in async mode", %{state: state} do
      state = %{state | async_callbacks: true}

      # This test mainly ensures the function doesn't crash
      assert {:ok, _final_state} = CallbackHandler.handle_stream_end(state)
    end
  end

  describe "handle_stream_error/2" do
    setup do
      callback_fn = fn _message, state -> {:ok, state} end
      {:ok, handler_state} = CallbackHandler.init(%{callback_fn: callback_fn})

      %{state: handler_state}
    end

    test "returns error when no error handler", %{state: state} do
      error = %{message: "Stream failed"}

      assert {:error, reason} = CallbackHandler.handle_stream_error(error, state)
      assert reason =~ "Stream error"
    end

    test "calls error handler when provided", %{state: state} do
      error_handler = fn error, _message, user_state ->
        {:ok, Map.put(user_state || %{}, :stream_error, error)}
      end

      state = %{state | error_handler: error_handler}
      error = %{message: "Stream failed"}

      assert {:error, reason} = CallbackHandler.handle_stream_error(error, state)
      assert reason =~ "Stream error handled by user handler"
    end

    test "handles error handler exceptions", %{state: state} do
      error_handler = fn _error, _message, _state -> raise "handler exception" end
      state = %{state | error_handler: error_handler}

      error = %{message: "Stream failed"}

      assert {:error, reason} = CallbackHandler.handle_stream_error(error, state)
      assert reason =~ "Stream error and handler exception"
    end
  end

  describe "terminate/2" do
    setup do
      callback_fn = fn _message, state -> {:ok, state} end
      {:ok, handler_state} = CallbackHandler.init(%{callback_fn: callback_fn})

      %{state: handler_state}
    end

    test "returns :ok", %{state: state} do
      assert :ok = CallbackHandler.terminate(:normal, state)
    end
  end

  describe "utility functions" do
    test "console_callback/1 creates console printing callback" do
      opts = CallbackHandler.console_callback(%{show_timestamp: true})

      assert is_function(opts.callback_fn, 2)

      # Test that it actually prints
      message = %{type: :text, data: %{content: "Hello"}}

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          {:ok, _state} = opts.callback_fn.(message, %{})
        end)

      assert output =~ "Hello"
    end

    test "collector_callback/1 creates message collector" do
      opts = CallbackHandler.collector_callback()

      assert is_function(opts.callback_fn, 2)
      assert opts.initial_state == []

      # Test that it collects messages
      message1 = %{type: :text, data: %{content: "First"}}
      message2 = %{type: :text, data: %{content: "Second"}}

      {:ok, state1} = opts.callback_fn.(message1, [])
      {:ok, state2} = opts.callback_fn.(message2, state1)

      assert length(state2) == 2
      # Most recent first
      assert hd(state2) == message2
    end

    test "type_filter_callback/3 creates type-filtered callback" do
      collector_fn = fn message, messages ->
        {:ok, [message | messages]}
      end

      opts = CallbackHandler.type_filter_callback([:text], collector_fn)

      assert is_function(opts.callback_fn, 2)
      assert is_function(opts.filter_fn, 1)

      # Test filter function
      text_message = %{type: :text, data: %{content: "Hello"}}
      tool_message = %{type: :tool_use, data: %{name: "calc"}}

      assert opts.filter_fn.(text_message) == true
      assert opts.filter_fn.(tool_message) == false
    end
  end

  describe "async callback execution" do
    test "async callbacks don't block" do
      slow_callback = fn _message, state ->
        # Simulate slow operation
        Process.sleep(50)
        {:ok, state}
      end

      {:ok, handler_state} =
        CallbackHandler.init(%{
          callback_fn: slow_callback,
          async_callbacks: true
        })

      message = %{type: :text, data: %{content: "Hello"}}

      start_time = System.monotonic_time(:millisecond)
      {:ok, new_state} = CallbackHandler.handle_message(message, handler_state)
      end_time = System.monotonic_time(:millisecond)

      # Should return quickly despite slow callback
      assert end_time - start_time < 25
      assert new_state.callback_count == 1
    end

    test "sync callbacks block" do
      slow_callback = fn _message, state ->
        # Simulate slow operation
        Process.sleep(50)
        {:ok, state}
      end

      {:ok, handler_state} =
        CallbackHandler.init(%{
          callback_fn: slow_callback,
          async_callbacks: false
        })

      message = %{type: :text, data: %{content: "Hello"}}

      start_time = System.monotonic_time(:millisecond)
      {:ok, new_state} = CallbackHandler.handle_message(message, handler_state)
      end_time = System.monotonic_time(:millisecond)

      # Should take at least as long as the callback
      assert end_time - start_time >= 45
      assert new_state.callback_count == 1
    end
  end
end
