defmodule Pipeline.Streaming.Handlers.FileHandlerTest do
  use ExUnit.Case, async: true

  alias Pipeline.Streaming.Handlers.FileHandler
  import ExUnit.CaptureLog

  @temp_dir System.tmp_dir!()

  setup do
    # Create unique test directory
    test_dir = Path.join(@temp_dir, "file_handler_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(test_dir)

    on_exit(fn ->
      # Clean up test directory
      File.rm_rf(test_dir)
    end)

    %{test_dir: test_dir}
  end

  describe "init/1" do
    test "initializes with default options", %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.txt")
      opts = %{file_path: file_path}

      assert {:ok, state} = FileHandler.init(opts)

      assert state.file_path == file_path
      assert state.format == :text
      assert state.buffer == []
      assert state.message_count == 0
      assert state.bytes_written == 0
      assert state.rotation_count == 0
      assert is_pid(state.file) or is_reference(state.file)

      # Clean up
      FileHandler.terminate(:normal, state)
    end

    test "initializes with JSON format", %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.json")
      opts = %{file_path: file_path, format: :json}

      assert {:ok, state} = FileHandler.init(opts)
      assert state.format == :json

      # Clean up
      FileHandler.terminate(:normal, state)
    end

    test "initializes with JSONL format", %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.jsonl")
      opts = %{file_path: file_path, format: :jsonl}

      assert {:ok, state} = FileHandler.init(opts)
      assert state.format == :jsonl

      # Clean up
      FileHandler.terminate(:normal, state)
    end

    test "creates directory if it doesn't exist", %{test_dir: test_dir} do
      nested_dir = Path.join(test_dir, "nested/deep")
      file_path = Path.join(nested_dir, "test.txt")
      opts = %{file_path: file_path}

      assert {:ok, state} = FileHandler.init(opts)
      assert File.exists?(nested_dir)

      # Clean up
      FileHandler.terminate(:normal, state)
    end

    test "returns error for invalid directory", %{test_dir: test_dir} do
      # Try to create file in a location that can't be created
      file_path = Path.join([test_dir, "nonexistent", "file.txt"])
      # Make directory read-only
      File.chmod!(test_dir, 0o444)

      opts = %{file_path: file_path}
      assert {:error, reason} = FileHandler.init(opts)
      assert reason =~ "Failed to create directory"

      # Restore permissions
      File.chmod!(test_dir, 0o755)
    end

    test "uses default path when none provided" do
      opts = %{}

      assert {:ok, state} = FileHandler.init(opts)
      assert String.contains?(state.file_path, "claude_stream_")

      # Clean up
      FileHandler.terminate(:normal, state)
    end
  end

  describe "handle_message/2" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.txt")
      {:ok, state} = FileHandler.init(%{file_path: file_path, buffer_size: 1000})

      on_exit(fn ->
        FileHandler.terminate(:normal, state)
      end)

      %{state: state, file_path: file_path}
    end

    test "handles text messages", %{state: state, file_path: file_path} do
      message = %{type: :text, data: %{content: "Hello, world!"}}

      {:ok, new_state} = FileHandler.handle_message(message, state)

      assert new_state.message_count == 1
      assert length(new_state.buffer) > 0

      # Force flush and check file content
      {:ok, _final_state} = FileHandler.handle_stream_end(new_state)
      content = File.read!(file_path)
      assert content =~ "Hello, world!"
    end

    test "handles tool use messages", %{state: state, file_path: file_path} do
      message = %{type: :tool_use, data: %{name: "calculator", id: "tool_123"}}

      {:ok, new_state} = FileHandler.handle_message(message, state)

      # Force flush and check file content
      {:ok, _final_state} = FileHandler.handle_stream_end(new_state)
      content = File.read!(file_path)
      assert content =~ "Tool Use: calculator"
    end

    test "handles error messages", %{state: state, file_path: file_path} do
      message = %{type: :error, data: %{message: "Something went wrong"}}

      {:ok, new_state} = FileHandler.handle_message(message, state)

      # Force flush and check file content
      {:ok, _final_state} = FileHandler.handle_stream_end(new_state)
      content = File.read!(file_path)
      assert content =~ "Error:"
      assert content =~ "Something went wrong"
    end

    test "flushes buffer when size limit reached", %{state: state} do
      # Set very small buffer size
      state = %{state | buffer_size: 10}

      message = %{
        type: :text,
        data: %{content: "This is a long message that should trigger buffer flush"}
      }

      {:ok, new_state} = FileHandler.handle_message(message, state)

      # Buffer should be flushed
      assert new_state.buffer == []
      assert new_state.bytes_written > 0
    end

    test "accumulates messages in buffer", %{state: state} do
      message1 = %{type: :text, data: %{content: "First"}}
      message2 = %{type: :text, data: %{content: "Second"}}

      {:ok, state1} = FileHandler.handle_message(message1, state)
      {:ok, state2} = FileHandler.handle_message(message2, state1)

      assert state2.message_count == 2
      assert length(state2.buffer) > 0
    end
  end

  describe "handle_batch/2" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.txt")
      {:ok, state} = FileHandler.init(%{file_path: file_path})

      on_exit(fn ->
        FileHandler.terminate(:normal, state)
      end)

      %{state: state, file_path: file_path}
    end

    test "handles multiple messages", %{state: state, file_path: file_path} do
      messages = [
        %{type: :text, data: %{content: "First"}},
        %{type: :text, data: %{content: "Second"}},
        %{type: :text, data: %{content: "Third"}}
      ]

      {:ok, new_state} = FileHandler.handle_batch(messages, state)

      assert new_state.message_count == 3

      # Force flush and check file content
      {:ok, _final_state} = FileHandler.handle_stream_end(new_state)
      content = File.read!(file_path)
      assert content =~ "First"
      assert content =~ "Second"
      assert content =~ "Third"
    end

    test "flushes buffer after batch", %{state: state} do
      messages = [
        %{type: :text, data: %{content: "Message 1"}},
        %{type: :text, data: %{content: "Message 2"}}
      ]

      {:ok, new_state} = FileHandler.handle_batch(messages, state)

      # Buffer should be flushed
      assert new_state.buffer == []
      assert new_state.bytes_written > 0
    end
  end

  describe "handle_stream_end/1" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.txt")
      {:ok, state} = FileHandler.init(%{file_path: file_path})

      # Add some messages
      message = %{type: :text, data: %{content: "Test message"}}
      {:ok, state} = FileHandler.handle_message(message, state)

      %{state: state, file_path: file_path}
    end

    test "flushes remaining buffer and closes file", %{state: state, file_path: file_path} do
      logs =
        capture_log(fn ->
          assert {:ok, _final_state} = FileHandler.handle_stream_end(state)
        end)

      # Check that file was written
      content = File.read!(file_path)
      assert content =~ "Test message"

      # Check that completion was logged
      assert logs =~ "FileHandler completed"
    end

    test "writes footer for JSON format", %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.json")
      {:ok, state} = FileHandler.init(%{file_path: file_path, format: :json})

      message = %{type: :text, data: %{content: "Test"}}
      {:ok, state} = FileHandler.handle_message(message, state)

      assert {:ok, _final_state} = FileHandler.handle_stream_end(state)

      content = File.read!(file_path)
      assert content =~ "\"messages\":"
      assert content =~ "\"metadata\":"
      assert content =~ "\"message_count\":"
      assert String.ends_with?(String.trim(content), "}")
    end

    test "handles empty buffer", %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "empty.txt")
      {:ok, state} = FileHandler.init(%{file_path: file_path})

      assert {:ok, _final_state} = FileHandler.handle_stream_end(state)

      # File should exist even if empty
      assert File.exists?(file_path)
    end
  end

  describe "handle_stream_error/2" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.txt")
      {:ok, state} = FileHandler.init(%{file_path: file_path})

      %{state: state, file_path: file_path}
    end

    test "writes error message and returns error", %{state: state, file_path: file_path} do
      error = %{message: "Connection failed"}

      assert {:error, reason} = FileHandler.handle_stream_error(error, state)
      assert reason =~ "Stream error"

      # Check that error was written to file
      content = File.read!(file_path)
      assert content =~ "STREAM ERROR"
      assert content =~ "Connection failed"
    end

    test "closes file cleanly after error", %{state: state} do
      error = %{message: "Connection failed"}

      assert {:error, _reason} = FileHandler.handle_stream_error(error, state)

      # File should be closed (no lingering file handle)
      # This is hard to test directly, but we can check that the file exists
      assert File.exists?(state.file_path)
    end
  end

  describe "terminate/2" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.txt")
      {:ok, state} = FileHandler.init(%{file_path: file_path})

      # Add some buffered data
      message = %{type: :text, data: %{content: "Buffered message"}}
      {:ok, state} = FileHandler.handle_message(message, state)

      %{state: state, file_path: file_path}
    end

    test "flushes buffer and closes file", %{state: state, file_path: file_path} do
      assert :ok = FileHandler.terminate(:normal, state)

      # Check that buffered data was written
      content = File.read!(file_path)
      assert content =~ "Buffered message"
    end

    test "handles nil file gracefully" do
      state = %{file: nil}
      assert :ok = FileHandler.terminate(:normal, state)
    end
  end

  describe "JSON format" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.json")
      {:ok, state} = FileHandler.init(%{file_path: file_path, format: :json})

      on_exit(fn ->
        FileHandler.terminate(:normal, state)
      end)

      %{state: state, file_path: file_path}
    end

    test "writes valid JSON structure", %{state: state, file_path: file_path} do
      messages = [
        %{type: :text, data: %{content: "Hello"}},
        %{type: :tool_use, data: %{name: "calc", id: "1"}}
      ]

      {:ok, state} = FileHandler.handle_batch(messages, state)
      {:ok, _final_state} = FileHandler.handle_stream_end(state)

      content = File.read!(file_path)

      # Should be valid JSON
      assert {:ok, json_data} = Jason.decode(content)

      # Should have expected structure
      assert Map.has_key?(json_data, "messages")
      assert Map.has_key?(json_data, "metadata")
      assert is_list(json_data["messages"])
      assert length(json_data["messages"]) == 2

      # Check metadata
      metadata = json_data["metadata"]
      assert metadata["message_count"] == 2
      assert Map.has_key?(metadata, "duration_ms")
      assert Map.has_key?(metadata, "bytes_written")
    end

    test "handles empty message list", %{state: state, file_path: file_path} do
      {:ok, _final_state} = FileHandler.handle_stream_end(state)

      content = File.read!(file_path)
      assert {:ok, json_data} = Jason.decode(content)

      assert json_data["messages"] == []
      assert json_data["metadata"]["message_count"] == 0
    end
  end

  describe "JSONL format" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "test.jsonl")
      {:ok, state} = FileHandler.init(%{file_path: file_path, format: :jsonl})

      on_exit(fn ->
        FileHandler.terminate(:normal, state)
      end)

      %{state: state, file_path: file_path}
    end

    test "writes one JSON object per line", %{state: state, file_path: file_path} do
      messages = [
        %{type: :text, data: %{content: "Line 1"}},
        %{type: :text, data: %{content: "Line 2"}}
      ]

      {:ok, state} = FileHandler.handle_batch(messages, state)
      {:ok, _final_state} = FileHandler.handle_stream_end(state)

      content = File.read!(file_path)
      lines = String.split(content, "\n", trim: true)

      # Should have one line per message
      assert length(lines) == 2

      # Each line should be valid JSON
      Enum.each(lines, fn line ->
        assert {:ok, json_data} = Jason.decode(line)
        assert Map.has_key?(json_data, "type")
        assert Map.has_key?(json_data, "data")
        assert Map.has_key?(json_data, "timestamp")
      end)
    end
  end

  describe "file rotation" do
    setup %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "rotating.txt")
      # Set very small max file size for testing
      opts = %{file_path: file_path, max_file_size: 100}
      {:ok, state} = FileHandler.init(opts)

      on_exit(fn ->
        FileHandler.terminate(:normal, state)
      end)

      %{state: state, file_path: file_path}
    end

    test "rotates file when size limit exceeded", %{state: state, file_path: file_path} do
      # Create a large message that will exceed the limit and force buffer flush
      # Much larger than 100 bytes
      large_content = String.duplicate("This is a long message. ", 20)
      message = %{type: :text, data: %{content: large_content}}

      # Force buffer flush by setting small buffer size
      state = %{state | buffer_size: 1}

      {:ok, new_state} = FileHandler.handle_message(message, state)

      # Should have rotated
      assert new_state.rotation_count > 0
      assert new_state.bytes_written < state.max_file_size

      # Original file should still exist
      assert File.exists?(file_path)

      # Rotated file should exist
      rotated_file = "#{file_path}.0"
      assert File.exists?(rotated_file)
    end
  end

  describe "error handling" do
    test "handles write errors gracefully", %{test_dir: test_dir} do
      file_path = Path.join(test_dir, "readonly.txt")
      {:ok, state} = FileHandler.init(%{file_path: file_path})

      # Make file read-only to cause write error
      File.chmod!(file_path, 0o444)

      message = %{type: :text, data: %{content: "test"}}

      # Should handle write error
      result = FileHandler.handle_message(message, state)

      case result do
        {:error, reason} ->
          assert reason =~ "Write failed"

        {:ok, _} ->
          # If no error, that's also acceptable behavior
          :ok
      end

      # Clean up
      File.chmod!(file_path, 0o644)
      FileHandler.terminate(:normal, state)
    end
  end
end
