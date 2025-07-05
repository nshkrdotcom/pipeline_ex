defmodule Pipeline.Streaming.Handlers.BufferHandlerTest do
  use ExUnit.Case, async: true

  alias Pipeline.Streaming.Handlers.BufferHandler
  import ExUnit.CaptureLog

  describe "init/1" do
    test "initializes with default options" do
      assert {:ok, state} = BufferHandler.init(%{})

      assert state.buffer == []
      assert state.buffer_size == 0
      assert state.max_buffer_size == 1000
      assert state.circular_buffer == false
      assert state.deduplicate == false
      assert state.memory_limit == 50 * 1024 * 1024
      assert state.message_count == 0
      assert state.dropped_count == 0
      assert state.memory_usage == 0
      assert is_nil(state.rotation_callback)
    end

    test "initializes with custom options" do
      rotation_callback = fn _buffer -> :ok end

      opts = %{
        max_buffer_size: 500,
        memory_limit: 10 * 1024 * 1024,
        circular_buffer: true,
        deduplicate: true,
        rotation_callback: rotation_callback
      }

      assert {:ok, state} = BufferHandler.init(opts)

      assert state.max_buffer_size == 500
      assert state.memory_limit == 10 * 1024 * 1024
      assert state.circular_buffer == true
      assert state.deduplicate == true
      assert state.rotation_callback == rotation_callback
    end

    test "returns error for invalid rotation callback" do
      opts = %{rotation_callback: "not_a_function"}

      assert {:error, reason} = BufferHandler.init(opts)
      assert reason =~ "rotation_callback must be a function with arity 1"
    end

    test "accepts nil rotation callback" do
      opts = %{rotation_callback: nil}

      assert {:ok, state} = BufferHandler.init(opts)
      assert is_nil(state.rotation_callback)
    end
  end

  describe "handle_message/2" do
    setup do
      {:ok, state} = BufferHandler.init(%{})
      %{state: state}
    end

    test "adds message to buffer", %{state: state} do
      message = %{type: :text, data: %{content: "Hello"}}

      assert {:ok, new_state} = BufferHandler.handle_message(message, state)

      assert new_state.buffer_size == 1
      assert new_state.message_count == 1
      assert length(new_state.buffer) == 1
      assert new_state.memory_usage > 0

      [entry] = new_state.buffer
      assert entry.message == message
      assert entry.sequence == 0
      assert is_integer(entry.timestamp)
    end

    test "adds multiple messages to buffer", %{state: state} do
      message1 = %{type: :text, data: %{content: "First"}}
      message2 = %{type: :text, data: %{content: "Second"}}

      {:ok, state1} = BufferHandler.handle_message(message1, state)
      {:ok, state2} = BufferHandler.handle_message(message2, state1)

      assert state2.buffer_size == 2
      assert state2.message_count == 2
      assert length(state2.buffer) == 2

      # Messages should be in reverse order (newest first)
      [newest, oldest] = state2.buffer
      assert newest.message == message2
      assert oldest.message == message1
      assert newest.sequence == 1
      assert oldest.sequence == 0
    end

    test "deduplicates messages when enabled", %{state: state} do
      state = %{state | deduplicate: true}
      message = %{type: :text, data: %{content: "Duplicate"}}

      {:ok, state1} = BufferHandler.handle_message(message, state)
      # Same message
      {:ok, state2} = BufferHandler.handle_message(message, state1)

      assert state2.buffer_size == 1
      # Only one unique message
      assert state2.message_count == 1
      assert length(state2.buffer) == 1
    end

    test "does not deduplicate when disabled", %{state: state} do
      state = %{state | deduplicate: false}
      message = %{type: :text, data: %{content: "Duplicate"}}

      {:ok, state1} = BufferHandler.handle_message(message, state)
      {:ok, state2} = BufferHandler.handle_message(message, state1)

      assert state2.buffer_size == 2
      assert state2.message_count == 2
      assert length(state2.buffer) == 2
    end

    test "handles buffer overflow with circular buffer", %{state: state} do
      state = %{state | max_buffer_size: 2, circular_buffer: true}

      message1 = %{type: :text, data: %{content: "First"}}
      message2 = %{type: :text, data: %{content: "Second"}}
      message3 = %{type: :text, data: %{content: "Third"}}

      {:ok, state1} = BufferHandler.handle_message(message1, state)
      {:ok, state2} = BufferHandler.handle_message(message2, state1)
      {:ok, state3} = BufferHandler.handle_message(message3, state2)

      # Buffer size should remain at max
      assert state3.buffer_size == 2
      assert state3.message_count == 3
      assert state3.dropped_count == 1

      # Oldest message should be replaced
      messages = BufferHandler.get_messages(state3)
      assert length(messages) == 2
      # First was dropped
      assert hd(messages).data.content == "Second"
      assert List.last(messages).data.content == "Third"
    end

    test "handles buffer overflow without circular buffer", %{state: state} do
      state = %{state | max_buffer_size: 2, circular_buffer: false}

      message1 = %{type: :text, data: %{content: "First"}}
      message2 = %{type: :text, data: %{content: "Second"}}
      message3 = %{type: :text, data: %{content: "Third"}}

      {:ok, state1} = BufferHandler.handle_message(message1, state)
      {:ok, state2} = BufferHandler.handle_message(message2, state1)

      logs =
        capture_log(fn ->
          {:ok, state3} = BufferHandler.handle_message(message3, state2)

          # Buffer size should remain at max
          assert state3.buffer_size == 2
          assert state3.message_count == 3
          assert state3.dropped_count == 1
        end)

      assert logs =~ "Buffer full, dropping message"
    end

    test "calls rotation callback when buffer is full", %{state: state} do
      {:ok, rotated_buffers} = Agent.start_link(fn -> [] end)

      rotation_callback = fn buffer ->
        Agent.update(rotated_buffers, fn buffers -> [buffer | buffers] end)
      end

      state = %{
        state
        | max_buffer_size: 2,
          circular_buffer: false,
          rotation_callback: rotation_callback
      }

      message1 = %{type: :text, data: %{content: "First"}}
      message2 = %{type: :text, data: %{content: "Second"}}
      message3 = %{type: :text, data: %{content: "Third"}}

      {:ok, state1} = BufferHandler.handle_message(message1, state)
      {:ok, state2} = BufferHandler.handle_message(message2, state1)
      {:ok, state3} = BufferHandler.handle_message(message3, state2)

      # Buffer should be rotated
      assert state3.buffer_size == 1
      assert state3.message_count == 3
      assert state3.dropped_count == 0
      assert length(state3.rotated_buffers) == 1

      # Check that rotation callback was called
      rotated = Agent.get(rotated_buffers, & &1)
      assert length(rotated) == 1

      Agent.stop(rotated_buffers)
    end

    test "handles memory limit exceeded", %{state: state} do
      # Set very small memory limit
      state = %{state | memory_limit: 100, circular_buffer: false}

      # Create large message
      large_content = String.duplicate("x", 200)
      message = %{type: :text, data: %{content: large_content}}

      logs =
        capture_log(fn ->
          {:ok, new_state} = BufferHandler.handle_message(message, state)

          # Message should be dropped due to memory limit
          assert new_state.buffer_size == 0
          assert new_state.dropped_count == 1
        end)

      assert logs =~ "Memory limit exceeded"
    end
  end

  describe "handle_batch/2" do
    setup do
      {:ok, state} = BufferHandler.init(%{})
      %{state: state}
    end

    test "adds multiple messages to buffer", %{state: state} do
      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :text, data: %{content: "Second"}},
        %{type: :text, data: %{content: "Third"}}
      ]

      assert {:ok, new_state} = BufferHandler.handle_batch(messages, state)

      assert new_state.buffer_size == 3
      assert new_state.message_count == 3
      assert length(new_state.buffer) == 3

      buffered_messages = BufferHandler.get_messages(new_state)
      assert length(buffered_messages) == 3
      assert hd(buffered_messages).data.content == "First"
      assert List.last(buffered_messages).data.content == "Third"
    end

    test "handles empty batch", %{state: state} do
      assert {:ok, new_state} = BufferHandler.handle_batch([], state)

      assert new_state.buffer_size == 0
      assert new_state.message_count == 0
      assert new_state == state
    end

    test "deduplicates within batch when enabled", %{state: state} do
      state = %{state | deduplicate: true}

      messages = [
        %{type: :text, data: %{content: "Unique"}},
        %{type: :text, data: %{content: "Duplicate"}},
        # Same as previous
        %{type: :text, data: %{content: "Duplicate"}},
        %{type: :text, data: %{content: "Another unique"}}
      ]

      assert {:ok, new_state} = BufferHandler.handle_batch(messages, state)

      # Should only have 3 unique messages
      assert new_state.buffer_size == 3
      assert new_state.message_count == 3
    end
  end

  describe "handle_stream_end/1" do
    setup do
      {:ok, state} = BufferHandler.init(%{})
      %{state: state}
    end

    test "logs completion statistics", %{state: state} do
      state = %{state | message_count: 5, dropped_count: 1}

      logs =
        capture_log(fn ->
          assert {:ok, _final_state} = BufferHandler.handle_stream_end(state)
        end)

      assert logs =~ "BufferHandler completed: 5 messages buffered (1 dropped)"
    end

    test "returns final state unchanged", %{state: state} do
      original_count = state.message_count

      assert {:ok, final_state} = BufferHandler.handle_stream_end(state)
      assert final_state.message_count == original_count
    end
  end

  describe "handle_stream_error/2" do
    setup do
      {:ok, state} = BufferHandler.init(%{})
      %{state: state}
    end

    test "adds error to buffer and returns error", %{state: state} do
      error = %{message: "Stream failed"}

      assert {:error, reason} = BufferHandler.handle_stream_error(error, state)
      assert reason =~ "Stream error buffered"

      # Error should be added to buffer (we can't easily test this without access to final state)
    end

    test "handles buffer error during error handling", %{state: state} do
      # Create a state that will fail when adding to buffer
      # Set memory limit to 0 so any addition will fail
      # Very small memory limit
      state = %{state | memory_limit: 1}
      error = %{message: "Stream failed"}

      result = BufferHandler.handle_stream_error(error, state)

      case result do
        {:error, reason} ->
          if String.contains?(reason, "Stream error and buffer error") or
               String.contains?(reason, "Stream error buffered") do
            :ok
          else
            flunk("Expected stream error but got: #{reason}")
          end

        other ->
          flunk("Expected error but got: #{inspect(other)}")
      end
    end
  end

  describe "terminate/2" do
    setup do
      {:ok, state} = BufferHandler.init(%{})
      %{state: state}
    end

    test "returns :ok", %{state: state} do
      assert :ok = BufferHandler.terminate(:normal, state)
    end
  end

  describe "public API functions" do
    setup do
      {:ok, state} = BufferHandler.init(%{})

      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :tool_use, data: %{name: "calc"}},
        %{type: :text, data: %{content: "Second"}}
      ]

      {:ok, state} = BufferHandler.handle_batch(messages, state)

      %{state: state}
    end

    test "get_messages/1 returns all messages in order", %{state: state} do
      messages = BufferHandler.get_messages(state)

      assert length(messages) == 3
      assert hd(messages).data.content == "First"
      assert List.last(messages).data.content == "Second"
    end

    test "get_entries/1 returns entries with metadata", %{state: state} do
      entries = BufferHandler.get_entries(state)

      assert length(entries) == 3

      Enum.each(entries, fn entry ->
        assert Map.has_key?(entry, :message)
        assert Map.has_key?(entry, :timestamp)
        assert Map.has_key?(entry, :sequence)
        assert is_integer(entry.timestamp)
        assert is_integer(entry.sequence)
      end)
    end

    test "get_messages_by_type/2 filters by message type", %{state: state} do
      text_messages = BufferHandler.get_messages_by_type(state, :text)
      tool_messages = BufferHandler.get_messages_by_type(state, :tool_use)

      assert length(text_messages) == 2
      assert length(tool_messages) == 1

      Enum.each(text_messages, fn message ->
        assert message.type == :text
      end)

      Enum.each(tool_messages, fn message ->
        assert message.type == :tool_use
      end)
    end

    test "get_stats/1 returns buffer statistics", %{state: state} do
      stats = BufferHandler.get_stats(state)

      assert stats.message_count == 3
      assert stats.buffer_size == 3
      assert stats.max_buffer_size == 1000
      assert stats.dropped_count == 0
      assert stats.memory_usage > 0
      assert is_integer(stats.duration_ms)
      assert stats.rotated_buffers == 0
    end

    test "clear_buffer/1 empties the buffer", %{state: state} do
      cleared_state = BufferHandler.clear_buffer(state)

      assert cleared_state.buffer == []
      assert cleared_state.buffer_size == 0
      assert cleared_state.memory_usage == 0
      # Message count should remain unchanged
      assert cleared_state.message_count == state.message_count
    end
  end

  describe "memory management" do
    setup do
      {:ok, state} = BufferHandler.init(%{memory_limit: 1000, circular_buffer: true})
      %{state: state}
    end

    test "estimates message memory usage", %{state: state} do
      small_message = %{type: :text, data: %{content: "Hi"}}
      large_message = %{type: :text, data: %{content: String.duplicate("x", 500)}}

      {:ok, state1} = BufferHandler.handle_message(small_message, state)
      {:ok, state2} = BufferHandler.handle_message(large_message, state1)

      # Large message should use more memory
      small_usage = state1.memory_usage
      large_usage = state2.memory_usage - state1.memory_usage

      assert large_usage > small_usage
    end

    test "frees memory when removing old entries", %{state: state} do
      # Add messages until memory limit is exceeded
      large_content = String.duplicate("x", 200)

      {:ok, state_ref} = Agent.start_link(fn -> state end)

      # Add several large messages
      for i <- 1..10 do
        message = %{type: :text, data: %{content: "#{large_content}_#{i}"}}

        Agent.update(state_ref, fn current_state ->
          {:ok, new_state} = BufferHandler.handle_message(message, current_state)
          new_state
        end)
      end

      final_state = Agent.get(state_ref, & &1)

      # Memory should be kept under limit
      assert final_state.memory_usage <= state.memory_limit
      assert final_state.dropped_count > 0

      Agent.stop(state_ref)
    end
  end

  describe "circular buffer behavior" do
    setup do
      {:ok, state} = BufferHandler.init(%{max_buffer_size: 3, circular_buffer: true})
      %{state: state}
    end

    test "maintains fixed buffer size", %{state: state} do
      messages =
        for i <- 1..10 do
          %{type: :text, data: %{content: "Message #{i}"}}
        end

      final_state =
        Enum.reduce(messages, state, fn message, acc_state ->
          {:ok, new_state} = BufferHandler.handle_message(message, acc_state)
          new_state
        end)

      # Buffer size should never exceed max
      assert final_state.buffer_size == 3
      assert final_state.message_count == 10
      assert final_state.dropped_count == 7

      # Should contain the last 3 messages
      buffered_messages = BufferHandler.get_messages(final_state)
      assert length(buffered_messages) == 3
      assert hd(buffered_messages).data.content == "Message 8"
      assert List.last(buffered_messages).data.content == "Message 10"
    end
  end

  describe "error handling" do
    test "handles rotation callback errors" do
      failing_callback = fn _buffer -> raise "rotation failed" end

      {:ok, state} =
        BufferHandler.init(%{
          max_buffer_size: 1,
          rotation_callback: failing_callback
        })

      message1 = %{type: :text, data: %{content: "First"}}
      message2 = %{type: :text, data: %{content: "Second"}}

      {:ok, state1} = BufferHandler.handle_message(message1, state)

      logs =
        capture_log(fn ->
          assert {:error, reason} = BufferHandler.handle_message(message2, state1)
          assert reason =~ "Buffer rotation failed"
        end)

      assert logs =~ "Buffer rotation callback error"
    end
  end
end
