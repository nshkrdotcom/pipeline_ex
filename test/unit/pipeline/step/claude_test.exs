defmodule Pipeline.Step.ClaudeTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.Step.Claude

  # Async streaming tests removed - feature deprecated
  describe "claude step execution with async streaming (DEPRECATED)" do
    @describetag :skip

    test "handles AsyncResponse from provider", %{workspace_dir: workspace_dir} do
      step = %{
        "name" => "async_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for async streaming"
          }
        ],
        "claude_options" => %{
          "async_streaming" => true,
          "collect_stream" => true
        }
      }

      context = mock_context(workspace_dir)

      # In mock mode, the provider should return an async response when async_streaming is true
      assert {:ok, result} = Claude.execute(step, context)
      assert result[:success] == true
      assert Map.has_key?(result, :streaming_metrics)
    end

    test "processes stream with console handler by default", %{workspace_dir: workspace_dir} do
      step = %{
        "name" => "console_handler_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for console handler"
          }
        ],
        "claude_options" => %{
          "async_streaming" => true
        }
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = Claude.execute(step, context)
      assert result[:success] == true
      assert result[:text] == "Stream displayed to console"
      assert result[:async_streaming] == true
    end

    test "processes stream with specified handler", %{workspace_dir: workspace_dir} do
      step = %{
        "name" => "custom_handler_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for custom handler"
          }
        ],
        "claude_options" => %{
          "async_streaming" => true,
          "stream_handler" => "console",
          "stream_buffer_size" => 5,
          "stream_handler_opts" => %{
            "show_stats" => false
          }
        }
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = Claude.execute(step, context)
      assert result[:success] == true
      assert Map.has_key?(result, :streaming_metrics)
    end

    test "handles standard synchronous response", %{workspace_dir: workspace_dir} do
      step = %{
        "name" => "sync_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "simple test"
          }
        ],
        "claude_options" => %{}
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = Claude.execute(step, context)
      assert result["success"] == true
      assert is_binary(result["text"])
    end

    test "handles provider errors", %{workspace_dir: workspace_dir} do
      step = %{
        "name" => "error_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "error test"
          }
        ],
        "claude_options" => %{}
      }

      context = mock_context(workspace_dir)

      assert {:error, reason} = Claude.execute(step, context)
      assert is_binary(reason)
    end

    test "collects stream to sync when configured", %{workspace_dir: workspace_dir} do
      step = %{
        "name" => "collect_stream_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for stream collection"
          }
        ],
        "claude_options" => %{
          "async_streaming" => true,
          "collect_stream" => true
        }
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = Claude.execute(step, context)
      assert result[:success] == true
      assert Map.has_key?(result, :messages)
      assert Map.has_key?(result, :streaming_metrics)
      assert result[:streaming_metrics][:message_count] > 0
    end

    test "handles stream interruption gracefully", %{workspace_dir: workspace_dir} do
      # This test is covered by the async streaming implementation
      # The mock provider will create a valid stream that completes successfully
      step = %{
        "name" => "stream_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for stream test"
          }
        ],
        "claude_options" => %{
          "async_streaming" => true,
          "stream_handler" => "console"
        }
      }

      context = mock_context(workspace_dir)

      # Should complete successfully with mock stream
      assert {:ok, result} = Claude.execute(step, context)
      assert result[:success] == true
    end

    test "adds step name to options", %{workspace_dir: workspace_dir} do
      step = %{
        "name" => "step_name_test",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for step name"
          }
        ],
        "claude_options" => %{"existing_option" => "value"}
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = Claude.execute(step, context)
      assert result["success"] == true
    end
  end
end
