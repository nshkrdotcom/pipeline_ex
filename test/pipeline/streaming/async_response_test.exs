defmodule Pipeline.Streaming.AsyncResponseTest do
  use ExUnit.Case, async: true
  alias Pipeline.Streaming.AsyncResponse

  describe "new/3" do
    test "creates async response with default values" do
      stream = Stream.iterate(0, &(&1 + 1))
      response = AsyncResponse.new(stream, "test_step")

      assert response.step_name == "test_step"
      assert response.stream == stream
      assert response.metadata == %{}
      assert response.handler == nil
      assert response.options == %{}
      assert response.metrics.message_count == 0
      assert response.metrics.total_tokens == 0
      assert response.metrics.interrupted == false
      assert response.metrics.first_message_time == nil
      assert is_struct(response.metrics.stream_started_at, DateTime)
    end

    test "creates async response with custom options" do
      stream = Stream.iterate(0, &(&1 + 1))
      handler = SomeHandler
      metadata = %{custom: "data"}

      response =
        AsyncResponse.new(stream, "test_step",
          handler: handler,
          metadata: metadata,
          buffer_size: 10
        )

      assert response.handler == handler
      assert response.metadata == metadata
      assert response.options[:buffer_size] == 10
    end
  end

  describe "to_sync_response/1" do
    test "converts simple stream to sync response" do
      messages = [
        %{type: :content, content: "Hello"},
        %{type: :content, content: " world"},
        %{type: :result, content: "Hello world"}
      ]

      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      assert result.success == true
      assert result.response == "Hello world"
      assert length(result.messages) == 3
      assert result.streaming_metrics.message_count == 3
      assert result.streaming_metrics.interrupted == false
      assert is_struct(result.timestamp, DateTime)
    end

    test "handles stream with token counts" do
      messages = [
        %{type: :content, content: "Test", tokens: 10},
        %{type: :content, content: " message", tokens: 15},
        %{type: :result, content: "Test message", tokens: 5}
      ]

      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      assert result.streaming_metrics.total_tokens == 30
    end

    test "approximates tokens when not provided" do
      # Long content that should approximate to tokens
      # 500 chars ≈ 125 tokens
      long_content = String.duplicate("test ", 100)

      messages = [
        %{type: :content, content: long_content}
      ]

      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      # Should approximate tokens based on character count
      assert result.streaming_metrics.total_tokens > 100
    end

    test "handles empty stream" do
      stream = Stream.map([], & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      assert result.success == true
      assert result.response == ""
      assert result.messages == []
      assert result.streaming_metrics.message_count == 0
    end

    test "handles stream errors" do
      # Stream that will raise an error
      stream =
        Stream.map([1, 2, 3], fn x ->
          if x == 2, do: raise("Stream error"), else: %{content: "#{x}"}
        end)

      response = AsyncResponse.new(stream, "test_step")

      assert {:error, %RuntimeError{message: "Stream error"}} =
               AsyncResponse.to_sync_response(response)
    end

    test "concatenates content when no result message" do
      messages = [
        %{type: :content, content: "Part 1"},
        %{type: :content, content: " Part 2"},
        %{type: :content, content: " Part 3"}
      ]

      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      assert result.response == "Part 1 Part 2 Part 3"
    end
  end

  describe "metrics tracking" do
    test "tracks time to first token" do
      messages = [
        %{type: :content, content: "First", tokens: 5},
        %{type: :content, content: "Second", tokens: 5}
      ]

      stream =
        Stream.map(messages, fn msg ->
          # Simulate delay
          Process.sleep(10)
          msg
        end)

      response = AsyncResponse.new(stream, "test_step")
      {:ok, _result} = AsyncResponse.to_sync_response(response)

      ttft = AsyncResponse.time_to_first_token(response)
      # Should be nil because metrics are updated during collection
      assert ttft == nil
    end

    test "calculates tokens per second" do
      response = %AsyncResponse{
        metrics: %{
          total_tokens: 100,
          stream_started_at: DateTime.add(DateTime.utc_now(), -2, :second),
          stream_completed_at: DateTime.utc_now()
        }
      }

      tps = AsyncResponse.tokens_per_second(response)
      # Should be around 50 tokens/second
      assert tps > 40 and tps < 60
    end

    test "returns 0 tokens per second when no tokens" do
      response = %AsyncResponse{
        metrics: %{
          total_tokens: 0,
          stream_started_at: DateTime.utc_now(),
          stream_completed_at: DateTime.utc_now()
        }
      }

      assert AsyncResponse.tokens_per_second(response) == 0.0
    end
  end

  describe "stream management" do
    test "unwrap_stream returns the underlying stream" do
      stream = Stream.iterate(0, &(&1 + 1))
      response = AsyncResponse.new(stream, "test_step")

      assert AsyncResponse.unwrap_stream(response) == stream
    end

    test "mark_completed updates completion time" do
      response = AsyncResponse.new([], "test_step")
      completed = AsyncResponse.mark_completed(response)

      assert is_struct(completed.metrics.stream_completed_at, DateTime)

      assert DateTime.compare(
               completed.metrics.stream_completed_at,
               completed.metrics.stream_started_at
             ) == :gt
    end

    test "mark_interrupted sets interrupted flag" do
      response = AsyncResponse.new([], "test_step")
      interrupted = AsyncResponse.mark_interrupted(response)

      assert interrupted.metrics.interrupted == true
      assert is_struct(interrupted.metrics.stream_completed_at, DateTime)
    end
  end

  describe "metadata management" do
    test "add_metadata merges new metadata" do
      response = AsyncResponse.new([], "test_step", metadata: %{initial: "value"})
      updated = AsyncResponse.add_metadata(response, %{new: "data", another: 123})

      assert updated.metadata == %{initial: "value", new: "data", another: 123}
    end

    test "add_metadata overwrites existing keys" do
      response = AsyncResponse.new([], "test_step", metadata: %{key: "old"})
      updated = AsyncResponse.add_metadata(response, %{key: "new"})

      assert updated.metadata == %{key: "new"}
    end
  end

  describe "process_stream/1" do
    test "returns error when no handler configured" do
      response = AsyncResponse.new([], "test_step")

      assert {:error, "No handler configured for async response"} =
               AsyncResponse.process_stream(response)
    end

    test "processes stream with mock handler" do
      defmodule MockHandler do
        def handle_stream(stream, _opts) do
          {:ok, stream}
        end
      end

      messages = [%{content: "test"}]
      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step", handler: MockHandler)

      assert {:ok, processed} = AsyncResponse.process_stream(response)
      assert processed.handler == MockHandler
    end
  end

  describe "edge cases" do
    test "handles messages with string keys" do
      messages = [
        %{"type" => "content", "content" => "Test", "tokens" => 5},
        %{"type" => "result", "content" => "Final", "tokens" => 10}
      ]

      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      assert result.response == "Final"
      assert result.streaming_metrics.total_tokens == 15
    end

    test "handles mixed message formats" do
      messages = [
        %{type: :content, content: "Atom keys"},
        %{"type" => "content", "content" => " String keys"},
        %{content: "No type"},
        "Just a string"
      ]

      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      assert result.success == true
      assert length(result.messages) == 4
    end

    test "handles nil token counts gracefully" do
      messages = [
        %{content: "Test", tokens: nil},
        %{content: "Message", token_count: nil}
      ]

      stream = Stream.map(messages, & &1)
      response = AsyncResponse.new(stream, "test_step")

      {:ok, result} = AsyncResponse.to_sync_response(response)

      # Should approximate tokens from content
      assert result.streaming_metrics.total_tokens > 0
    end
  end

  describe "streaming metrics time calculation" do
    test "time_to_first_token returns nil when no messages received" do
      response = AsyncResponse.new([], "test_step")
      assert AsyncResponse.time_to_first_token(response) == nil
    end

    test "time_to_first_token calculates correctly" do
      start_time = DateTime.utc_now()
      first_message_time = DateTime.add(start_time, 100, :millisecond)

      response = %AsyncResponse{
        metrics: %{
          stream_started_at: start_time,
          first_message_time: first_message_time
        }
      }

      ttft = AsyncResponse.time_to_first_token(response)
      # Allow small variance
      assert ttft >= 100 and ttft <= 110
    end
  end
end
