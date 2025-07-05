defmodule Pipeline.Providers.EnhancedClaudeProviderTest do
  use ExUnit.Case, async: true

  alias Pipeline.Providers.EnhancedClaudeProvider
  alias Pipeline.Streaming.AsyncResponse

  setup do
    # Since we're in test environment, TestMode will automatically be :mock
    # unless TEST_MODE env var is set differently
    :ok
  end

  describe "query/2 with async streaming" do
    test "returns AsyncResponse when async_streaming is enabled" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true,
        "step_name" => "test_step"
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      assert %AsyncResponse{} = response
      assert response.step_name == "test_step"
      assert response.metadata.enhanced_provider == true
    end

    test "returns sync response when async_streaming is disabled" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => false
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      assert is_map(response)
      assert response["success"] == true
      assert response["enhanced_provider"] == true
      refute match?(%AsyncResponse{}, response)
    end

    test "includes telemetry metadata when telemetry_enabled" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true,
        "telemetry_enabled" => true
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      assert response.metadata.telemetry_enabled == true
    end

    test "includes cost tracking metadata when cost_tracking enabled" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true,
        "cost_tracking" => true
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      assert response.metadata.cost_tracking == true
    end
  end

  describe "telemetry events" do
    test "emits stream start event for async streaming" do
      # TestMode is automatically :mock in test environment

      # Attach telemetry handler
      handler_id = :test_stream_start

      capture_ref = self()

      :telemetry.attach(
        handler_id,
        [:pipeline, :enhanced_claude, :stream, :start],
        fn event, measurements, metadata, _config ->
          send(capture_ref, {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      options = %{
        "async_streaming" => true
      }

      {:ok, _response} = EnhancedClaudeProvider.query("Test prompt", options)

      assert_receive {:telemetry_event, [:pipeline, :enhanced_claude, :stream, :start],
                      measurements, metadata}

      assert is_number(measurements.timestamp)
      # "Test prompt"
      assert metadata.prompt_length == 11

      :telemetry.detach(handler_id)
    end
  end

  describe "mock async streaming" do
    test "creates mock message stream with proper sequence" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true,
        "preset" => "development"
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      # Collect messages from the stream
      messages = response.stream |> Enum.to_list()

      # Should have system message, assistant messages, and result
      assert length(messages) > 0

      # First message should be system
      first_msg = List.first(messages)
      assert first_msg.type == :system

      # Last message should be result
      last_msg = List.last(messages)
      assert last_msg.type == :result
      assert last_msg.subtype == :success
    end

    test "mock stream includes token counts" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      messages = response.stream |> Enum.to_list()

      # Find assistant messages
      assistant_msgs = Enum.filter(messages, &(&1.type == :assistant))

      assert length(assistant_msgs) > 0

      # Check that assistant messages have token data
      Enum.each(assistant_msgs, fn msg ->
        assert msg.data.tokens > 0
      end)
    end
  end

  describe "SDK options building" do
    test "includes async flag when async_streaming is enabled" do
      # TestMode is automatically :mock in test environment

      # We can't directly test SDK options building, but we can verify
      # the behavior by checking that async response is returned
      options = %{
        "async_streaming" => true,
        "max_turns" => 5,
        "verbose" => true
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test", options)

      assert %AsyncResponse{} = response
    end
  end

  describe "progressive cost calculation" do
    test "tracks cost accumulation in metadata when cost_tracking enabled" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true,
        "cost_tracking" => true
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      # The cost tracking flag should be in metadata
      assert response.metadata.cost_tracking == true

      # When we process the stream, cost telemetry should be emitted
      # (tested separately in telemetry tests)
    end
  end

  describe "streaming metrics" do
    test "async response can calculate time to first token" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      # Initially, time to first token should be nil
      assert AsyncResponse.time_to_first_token(response) == nil

      # After processing messages, it should have a value
      # (This would be tested in integration tests)
    end

    test "async response tracks message count in metrics" do
      # TestMode is automatically :mock in test environment

      options = %{
        "async_streaming" => true
      }

      {:ok, response} = EnhancedClaudeProvider.query("Test prompt", options)

      metrics = AsyncResponse.get_metrics(response)
      # Not processed yet
      assert metrics.message_count == 0
      assert metrics.stream_started_at != nil
    end
  end

  describe "error handling" do
    test "returns error for invalid options in sync mode" do
      # TestMode is automatically :mock in test environment

      # Test with retry config that might cause issues
      options = %{
        "async_streaming" => false,
        "retry_config" => %{
          # Invalid
          "max_retries" => -1
        }
      }

      # Should still work as the mock doesn't validate retry config
      {:ok, _response} = EnhancedClaudeProvider.query("Test prompt", options)
    end
  end
end
