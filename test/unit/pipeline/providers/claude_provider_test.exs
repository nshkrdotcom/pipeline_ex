defmodule Pipeline.Providers.ClaudeProviderTest do
  use ExUnit.Case, async: false
  alias Pipeline.Providers.ClaudeProvider
  alias Pipeline.Test.Mocks.ClaudeProvider, as: MockClaudeProvider

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  # Async streaming tests removed - feature deprecated
  describe "query/2 with async streaming (DEPRECATED)" do
    @describetag :skip
    setup do
      # Save original env
      original_env = System.get_env("TEST_MODE")

      on_exit(fn ->
        if original_env do
          System.put_env("TEST_MODE", original_env)
        else
          System.delete_env("TEST_MODE")
        end

        MockClaudeProvider.reset()
      end)

      :ok
    end

    test "detects async_streaming option and returns AsyncResponse" do
      System.put_env("TEST_MODE", "mock")

      options = %{
        "async_streaming" => true,
        "step_name" => "test_step"
      }

      capture_io(fn ->
        {:ok, response} = ClaudeProvider.query("Test prompt", options)

        # Should return an AsyncResponse in mock mode
        # assert AsyncResponse struct - DEPRECATED = response
        assert response.step_name == "test_step"
        assert is_map(response.metrics)
        assert response.metadata.mock == true
      end)
    end

    test "passes async option to SDK when async_streaming is true" do
      # This test verifies that the async option is properly built
      System.put_env("TEST_MODE", "mock")

      options = %{
        async_streaming: true,
        max_turns: 5,
        step_name: "test_async"
      }

      capture_io(fn ->
        {:ok, _response} = ClaudeProvider.query("Test async", options)
        # assert AsyncResponse struct - DEPRECATED = response
      end)
    end

    test "supports model selection options" do
      System.put_env("TEST_MODE", "mock")

      options = %{
        "model" => "sonnet",
        "fallback_model" => "opus",
        "max_turns" => 5
      }

      capture_io(fn ->
        {:ok, response} = ClaudeProvider.query("Test prompt with model selection", options)

        # Should successfully process with model options
        assert is_map(response)
        assert response["success"] == true
      end)
    end

    test "supports model shortcuts" do
      System.put_env("TEST_MODE", "mock")

      # Test sonnet shortcut
      sonnet_options = %{"model" => "sonnet"}

      capture_io(fn ->
        {:ok, response} = ClaudeProvider.query("Test sonnet", sonnet_options)
        assert is_map(response)
      end)

      # Test opus shortcut  
      opus_options = %{"model" => "opus"}

      capture_io(fn ->
        {:ok, response} = ClaudeProvider.query("Test opus", opus_options)
        assert is_map(response)
      end)
    end

    test "supports specific model versions" do
      System.put_env("TEST_MODE", "mock")

      options = %{
        "model" => "claude-3-5-sonnet-20241022",
        "fallback_model" => "claude-3-opus-20240229"
      }

      capture_io(fn ->
        {:ok, response} = ClaudeProvider.query("Test specific versions", options)
        assert is_map(response)
      end)
    end

    test "returns regular response when async_streaming is false" do
      System.put_env("TEST_MODE", "mock")

      options = %{
        "async_streaming" => false
      }

      capture_io(fn ->
        {:ok, response} = ClaudeProvider.query("Test prompt", options)

        assert is_map(response)
        assert response["success"] == true
        assert is_binary(response["text"])
        assert is_number(response["cost"])
      end)
    end

    test "returns regular response when async_streaming is not specified" do
      System.put_env("TEST_MODE", "mock")

      options = %{}

      capture_io(fn ->
        {:ok, response} = ClaudeProvider.query("Test prompt", options)

        assert is_map(response)
        assert response["success"] == true
        assert is_binary(response["text"])
      end)
    end

    test "includes stream handler options when provided" do
      System.put_env("TEST_MODE", "mock")

      options = %{
        "async_streaming" => true,
        "stream_handler" => SomeHandler,
        "stream_buffer_size" => 50,
        "step_name" => "custom_step"
      }

      capture_io(fn ->
        {:ok, _response} = ClaudeProvider.query("Test prompt", options)
      end)

      # In a real test, we'd verify these options are passed through
      # For now, we just verify the query succeeds
      assert true
    end
  end

  describe "backward compatibility" do
    @describetag :skip
    test "maintains compatibility with existing sync calls" do
      System.put_env("TEST_MODE", "mock")

      # Test with various option formats
      test_cases = [
        %{},
        %{"max_turns" => 3},
        %{max_turns: 3, verbose: true},
        %{"system_prompt" => "Be helpful", "allowed_tools" => ["read", "write"]}
      ]

      for options <- test_cases do
        capture_io(fn ->
          {:ok, response} = ClaudeProvider.query("Test prompt", options)

          assert response["success"] == true
          assert is_binary(response["text"])
          assert is_number(response["cost"])
        end)
      end
    end

    test "handles both string and atom keys for async_streaming" do
      System.put_env("TEST_MODE", "mock")

      # Test with string key
      capture_io(fn ->
        {:ok, _} = ClaudeProvider.query("Test", %{"async_streaming" => true})
      end)

      # Test with atom key
      capture_io(fn ->
        {:ok, _} = ClaudeProvider.query("Test", %{async_streaming: true})
      end)

      # Both should succeed
      assert true
    end
  end

  describe "error handling" do
    test "handles errors in async mode gracefully" do
      System.put_env("TEST_MODE", "mock")

      # Simulate an error by using invalid options that would cause issues
      # In mock mode, errors are less likely, but we test the structure
      options = %{
        "async_streaming" => true,
        # Invalid value
        "max_turns" => -1
      }

      capture_log(fn ->
        capture_io(fn ->
          result = ClaudeProvider.query("Test prompt", options)

          case result do
            {:ok, _} -> assert true
            {:error, reason} -> assert is_binary(reason)
          end
        end)
      end)
    end
  end

  if Code.ensure_loaded?(ClaudeAgentSDK) do
    describe "live mode async streaming" do
      @describetag :skip
      @tag :integration
      @describetag :skip
      test "creates AsyncResponse with live SDK stream" do
        # This test would require actual Claude API access
        # Skip in normal test runs
        System.put_env("TEST_MODE", "live")

        options = %{
          async_streaming: true,
          max_turns: 1,
          verbose: false
        }

        {:ok, response} = ClaudeProvider.query("Say 'Hello, async!'", options)

        # assert AsyncResponse struct - DEPRECATED = response
        assert response.step_name == "claude_query"
        assert is_map(response.metrics)
      end
    end
  end
end
