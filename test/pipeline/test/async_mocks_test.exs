defmodule Pipeline.Test.AsyncMocksTest do
  use ExUnit.Case, async: true

  alias Pipeline.Test.AsyncMocks
  alias Pipeline.Streaming.AsyncResponse

  describe "create_stream/2" do
    test "creates a fast stream with no delays" do
      stream = AsyncMocks.create_stream("Hello world")
      messages = Enum.to_list(stream)

      # At least "Hello", "world", and result
      assert length(messages) >= 3
      assert Enum.any?(messages, &match?(%{type: :text}, &1))
      assert List.last(messages).type == :result
    end

    test "creates a slow stream with delays" do
      start_time = System.monotonic_time(:millisecond)
      stream = AsyncMocks.create_stream("Hello", pattern: :slow, delay_ms: 10)
      _messages = Enum.to_list(stream)
      duration = System.monotonic_time(:millisecond) - start_time

      # Should take at least 20ms (2 messages * 10ms)
      assert duration >= 20
    end

    test "creates a chunked stream" do
      stream =
        AsyncMocks.create_stream("One two three four five",
          pattern: :chunked,
          chunk_size: 2,
          delay_ms: 10
        )

      start_time = System.monotonic_time(:millisecond)
      messages = Enum.to_list(stream)
      duration = System.monotonic_time(:millisecond) - start_time

      # Should have delays between chunks
      # At least 2 chunks with delays
      assert duration >= 20
      # 5 words + result
      assert length(messages) >= 6
    end

    test "creates a realistic stream with variable delays" do
      stream = AsyncMocks.create_stream("Test content", pattern: :realistic, delay_ms: 5)

      start_time = System.monotonic_time(:millisecond)
      _messages = Enum.to_list(stream)
      duration = System.monotonic_time(:millisecond) - start_time

      # Should have some delay, but variable
      assert duration > 0
    end

    test "includes metadata when requested" do
      stream = AsyncMocks.create_stream("Test", include_metadata: true)
      messages = Enum.to_list(stream)

      # First message should be system metadata
      assert List.first(messages).type == :system
      assert Map.has_key?(List.first(messages).data, :info)
    end

    test "distributes tokens across messages" do
      stream = AsyncMocks.create_stream("One two three", total_tokens: 30)
      messages = Enum.to_list(stream)

      token_messages =
        Enum.filter(messages, fn msg ->
          msg.type == :text && Map.has_key?(msg.data, :tokens)
        end)

      assert length(token_messages) > 0

      # Result message should have total tokens
      result = List.last(messages)
      assert result.data.total_tokens == 30
    end
  end

  describe "create_stream/2 with errors" do
    test "injects error after specified message count" do
      stream =
        AsyncMocks.create_stream("One two three four",
          error_after: 2,
          error_type: :network_error
        )

      messages = Enum.to_list(stream)

      # Find the error message
      error_msg = Enum.find(messages, &(&1.type == :error))
      assert error_msg
      assert error_msg.data.error == "Network connection lost"
      assert error_msg.data.code == "ENETDOWN"

      # Error should be after 2 messages
      error_index = Enum.find_index(messages, &(&1.type == :error))
      assert error_index == 2
    end

    test "supports different error types" do
      error_types = [:network_error, :timeout, :invalid_message, :stream_interrupted]

      for error_type <- error_types do
        stream = AsyncMocks.create_stream("Test", error_after: 1, error_type: error_type)
        messages = Enum.to_list(stream)

        error_msg = Enum.find(messages, &(&1.type == :error))
        assert error_msg, "Error type #{error_type} should produce an error message"
        assert is_binary(error_msg.data.error)
        assert is_binary(error_msg.data.code)
      end
    end
  end

  describe "create_async_response/3" do
    test "creates an AsyncResponse wrapper" do
      response = AsyncMocks.create_async_response("Test content", "test_step")

      assert %AsyncResponse{} = response
      assert response.step_name == "test_step"
      assert response.metadata.mock == true
      assert response.metadata.pattern == :fast
    end

    test "passes through options to AsyncResponse" do
      response =
        AsyncMocks.create_async_response("Test", "step",
          handler: SomeHandler,
          buffer_size: 20,
          pattern: :slow
        )

      assert response.options.handler == SomeHandler
      assert response.options.buffer_size == 20
      assert response.metadata.pattern == :slow
    end

    test "stream in AsyncResponse works correctly" do
      response = AsyncMocks.create_async_response("Hello world", "step")
      messages = Enum.to_list(response.stream)

      assert length(messages) >= 3
      assert List.last(messages).type == :result
    end
  end

  describe "create_scenario_stream/2" do
    test "creates simple scenario" do
      stream = AsyncMocks.create_scenario_stream(:simple)
      messages = Enum.to_list(stream)

      content =
        messages
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map(& &1.data.content)
        |> Enum.join("")

      assert content =~ "simple test response"
    end

    test "creates code generation scenario" do
      stream = AsyncMocks.create_scenario_stream(:code_generation)
      messages = Enum.to_list(stream)

      # Should include metadata
      assert Enum.any?(messages, &(&1.type == :system))

      content =
        messages
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map(& &1.data.content)
        |> Enum.join("")

      assert content =~ "def hello_world"
      assert content =~ "```elixir"
    end

    test "creates analysis scenario with chunks" do
      stream = AsyncMocks.create_scenario_stream(:analysis)

      start_time = System.monotonic_time(:millisecond)
      messages = Enum.to_list(stream)
      duration = System.monotonic_time(:millisecond) - start_time

      # Should have chunked delays
      assert duration > 0

      content =
        messages
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map(& &1.data.content)
        |> Enum.join("")

      assert content =~ "Performance Metrics"
      assert content =~ "Recommendations"
    end

    test "creates error scenario" do
      stream = AsyncMocks.create_scenario_stream(:error)
      messages = Enum.to_list(stream)

      assert Enum.any?(messages, &(&1.type == :error))
    end

    test "creates timeout scenario" do
      stream = AsyncMocks.create_scenario_stream(:timeout)
      messages = Enum.to_list(stream)

      error = Enum.find(messages, &(&1.type == :error))
      assert error
      assert error.data.code == "ETIMEDOUT"
    end

    test "creates empty scenario" do
      stream = AsyncMocks.create_scenario_stream(:empty)
      messages = Enum.to_list(stream)

      # Empty scenario with single space creates minimal messages
      text_messages = Enum.filter(messages, &(&1.type == :text))
      result_messages = Enum.filter(messages, &(&1.type == :result))

      # At least one text message
      assert length(text_messages) >= 1
      # Exactly one result message
      assert length(result_messages) == 1
      assert List.last(messages).type == :result
    end

    test "allows overriding scenario options" do
      stream = AsyncMocks.create_scenario_stream(:simple, pattern: :slow, delay_ms: 5)

      start_time = System.monotonic_time(:millisecond)
      _messages = Enum.to_list(stream)
      duration = System.monotonic_time(:millisecond) - start_time

      # Should use slow pattern instead of fast
      assert duration > 0
    end
  end

  describe "inject_error/3" do
    test "injects error into existing stream" do
      # Create a simple stream without errors
      base_stream = Stream.map(1..5, fn i -> %{type: :text, data: %{content: "Message #{i}"}} end)

      # Inject error after 3rd message
      stream_with_error = AsyncMocks.inject_error(base_stream, 3, :network_error)
      messages = Enum.to_list(stream_with_error)

      # 5 original + 1 error
      assert length(messages) == 6
      assert Enum.at(messages, 3).type == :error
      assert Enum.at(messages, 3).data.code == "ENETDOWN"
    end

    test "preserves original messages" do
      base_stream = Stream.map(1..3, fn i -> %{type: :text, data: %{content: "#{i}"}} end)

      stream_with_error = AsyncMocks.inject_error(base_stream, 2, :timeout)
      messages = Enum.to_list(stream_with_error)

      # Original messages should be preserved
      assert Enum.at(messages, 0).data.content == "1"
      assert Enum.at(messages, 1).data.content == "2"
      assert Enum.at(messages, 2).type == :error
      assert Enum.at(messages, 3).data.content == "3"
    end
  end

  describe "setup_async_mock/2" do
    setup do
      # Reset mocks before each test
      AsyncMocks.reset_async_mocks()
      :ok
    end

    test "sets up mock provider for async streaming" do
      AsyncMocks.setup_async_mock("test prompt", content: "Mock response")

      # The mock provider should now return async responses
      response =
        Pipeline.Test.Mocks.ClaudeProvider.query("test prompt", %{
          "async_streaming" => true,
          "step_name" => "test"
        })

      assert {:ok, %AsyncResponse{}} = response
    end

    test "allows pattern matching in mock setup" do
      AsyncMocks.setup_async_mock("calculator",
        content: "def add(a, b), do: a + b",
        pattern: :slow
      )

      {:ok, response} =
        Pipeline.Test.Mocks.ClaudeProvider.query(
          # Use exact pattern for matching
          "calculator",
          %{"async_streaming" => true}
        )

      assert response.metadata.pattern == :slow
    end
  end

  describe "integration with mock provider" do
    setup do
      AsyncMocks.reset_async_mocks()
      :ok
    end

    test "mock provider returns sync response when async not requested" do
      # Setup async mock
      AsyncMocks.setup_async_mock("test", content: "Async content")

      # Query without async_streaming should still return sync
      response = Pipeline.Test.Mocks.ClaudeProvider.query("test")

      # Should get normal sync response, not AsyncResponse
      assert {:ok, result} = response
      assert is_map(result)
      refute match?(%AsyncResponse{}, result)
    end

    test "mock provider returns async response when requested" do
      AsyncMocks.setup_async_mock("async test", content: "Streaming content")

      response =
        Pipeline.Test.Mocks.ClaudeProvider.query("async test", %{
          "async_streaming" => true
        })

      assert {:ok, %AsyncResponse{} = async_resp} = response

      # Verify the stream works
      messages = Enum.to_list(async_resp.stream)
      assert length(messages) > 0
      assert List.last(messages).type == :result
    end
  end

  describe "performance characteristics" do
    test "fast pattern has minimal overhead" do
      stream = AsyncMocks.create_stream("Quick test", pattern: :fast)

      start_time = System.monotonic_time(:millisecond)
      _messages = Enum.to_list(stream)
      duration = System.monotonic_time(:millisecond) - start_time

      # Fast pattern should complete very quickly
      assert duration < 50
    end

    test "memory efficiency for large streams" do
      # Create a large content string
      large_content = Enum.map(1..1000, &"Word#{&1}") |> Enum.join(" ")

      stream = AsyncMocks.create_stream(large_content, pattern: :fast)

      # Stream should be lazy - not consuming memory until enumerated
      assert is_function(stream) or is_struct(stream, Stream)
    end
  end
end
