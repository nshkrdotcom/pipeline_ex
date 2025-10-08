defmodule Pipeline.ExecutorTest do
  use ExUnit.Case, async: false

  alias Pipeline.{Executor, TestMode}
  alias Pipeline.Test.Mocks

  setup do
    # Set test mode
    System.put_env("TEST_MODE", "mock")
    TestMode.set_test_context(:unit)

    # Reset mocks
    Mocks.ClaudeProvider.reset()
    Mocks.GeminiProvider.reset()

    # Clean up any test directories
    on_exit(fn ->
      File.rm_rf("/tmp/test_workspace")
      File.rm_rf("/tmp/test_outputs")
      File.rm_rf("/tmp/test_checkpoints")
      TestMode.clear_test_context()
    end)

    :ok
  end

  describe "execute/2" do
    test "executes a simple workflow successfully" do
      workflow = %{
        "workflow" => %{
          "name" => "test_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "simple_claude_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Hello world"}]
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(workflow)
      assert Map.has_key?(results, "simple_claude_step")
      assert results["simple_claude_step"]["success"] == true
    end

    test "executes a multi-step workflow with dependencies" do
      workflow = %{
        "workflow" => %{
          "name" => "multi_step_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "gemini_plan",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "Create a plan"}]
            },
            %{
              "name" => "claude_execute",
              "type" => "claude",
              "prompt" => [
                %{"type" => "static", "content" => "Execute this plan:"},
                %{"type" => "previous_response", "step" => "gemini_plan"}
              ]
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(workflow)
      assert Map.has_key?(results, "gemini_plan")
      assert Map.has_key?(results, "claude_execute")
      assert results["gemini_plan"]["success"] == true
      assert results["claude_execute"]["success"] == true
    end

    test "handles step failures gracefully" do
      workflow = %{
        "workflow" => %{
          "name" => "failing_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "failing_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "error test"}]
            }
          ]
        }
      }

      assert {:error, reason} = Executor.execute(workflow)
      assert String.contains?(reason, "failing_step")
    end

    test "creates required directories" do
      workspace_dir = "/tmp/test_workspace_#{System.unique_integer([:positive])}"
      output_dir = "/tmp/test_outputs_#{System.unique_integer([:positive])}"

      workflow = %{
        "workflow" => %{
          "name" => "directory_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => output_dir},
          "steps" => [
            %{
              "name" => "simple_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      refute File.exists?(workspace_dir)
      refute File.exists?(output_dir)

      assert {:ok, _results} = Executor.execute(workflow)

      assert File.exists?(workspace_dir)
      assert File.exists?(output_dir)

      # Cleanup
      File.rm_rf(workspace_dir)
      File.rm_rf(output_dir)
    end

    test "handles unknown step types" do
      workflow = %{
        "workflow" => %{
          "name" => "unknown_step_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "unknown_step",
              "type" => "unknown_type",
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      assert {:error, reason} = Executor.execute(workflow)
      assert String.contains?(reason, "unknown_type")
    end
  end

  describe "execute_step/2" do
    test "executes a single Claude step" do
      step = %{
        "name" => "test_step",
        "type" => "claude",
        "prompt" => [%{"type" => "static", "content" => "simple test"}]
      }

      context = %{results: %{}}

      assert {:ok, result} = Executor.execute_step(step, context)
      assert result["success"] == true
      assert String.contains?(result["text"], "Mock response")
    end

    test "executes a single Gemini step" do
      step = %{
        "name" => "test_step",
        "type" => "gemini",
        "prompt" => [%{"type" => "static", "content" => "analyze this"}]
      }

      context = %{results: %{}}

      assert {:ok, result} = Executor.execute_step(step, context)
      assert result["success"] == true
      assert Map.has_key?(result, "content")
    end
  end

  # Async streaming tests removed - feature deprecated
  describe "async streaming execution (DEPRECATED)" do
    @describetag :skip

    test "handles async streaming response from Claude step" do
      # Set up mock to return async response
      _mock_stream =
        Stream.map(
          [
            %{type: :text, data: %{content: "Test streaming response"}},
            %{type: :result, data: %{session_id: "test_123"}}
          ],
          & &1
        )

      # async_response = AsyncResponse.new(_mock_stream, "test_step")

      # Mocks.ClaudeProvider.set_response_pattern("__async__test async streaming", fn _prompt ->
      #   async_response
      # end)

      workflow = %{
        "workflow" => %{
          "name" => "async_test_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "async_claude_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test async streaming"}],
              "claude_options" => %{
                "async_streaming" => true
              }
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(workflow)
      assert Map.has_key?(results, "async_claude_step")

      result = results["async_claude_step"]
      assert result["success"] == true
      assert result["type"] == "async_stream"
      assert Map.has_key?(result, "stream_info")
    end

    test "resolves async stream when referenced by next step" do
      # Mock async response for first step
      _mock_stream =
        Stream.map(
          [
            %{type: :text, data: %{content: "Async content from step 1"}},
            %{type: :result, data: %{session_id: "test_456"}}
          ],
          & &1
        )

      # async_response = AsyncResponse.new(_mock_stream, "step1")

      # Mocks.ClaudeProvider.set_response_pattern("__async__async step 1", fn _prompt ->
      #   async_response
      # end)

      workflow = %{
        "workflow" => %{
          "name" => "async_chain_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "async step 1"}],
              "claude_options" => %{
                "async_streaming" => true
              }
            },
            %{
              "name" => "step2",
              "type" => "claude",
              "prompt" => [
                %{"type" => "static", "content" => "Process this:"},
                %{"type" => "previous_response", "step" => "step1"}
              ]
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(workflow)

      # First step should have async result
      assert results["step1"]["type"] == "async_stream"

      # Second step should complete successfully
      assert results["step2"]["success"] == true
    end

    test "handles mixed sync and async step execution" do
      # Mock async response
      _mock_stream =
        Stream.map(
          [
            %{type: :text, data: %{content: "Async response"}},
            %{type: :result, data: %{session_id: "test_789"}}
          ],
          & &1
        )

      # async_response = AsyncResponse.new(_mock_stream, "async_step")

      # Mocks.ClaudeProvider.set_response_pattern("__async__async prompt", fn _prompt ->
      #   async_response
      # end)

      workflow = %{
        "workflow" => %{
          "name" => "mixed_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "sync_step",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "sync analysis"}]
            },
            %{
              "name" => "async_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "async prompt"}],
              "claude_options" => %{
                "async_streaming" => true
              }
            },
            %{
              "name" => "final_step",
              "type" => "claude",
              "prompt" => [
                %{"type" => "previous_response", "step" => "sync_step"},
                %{"type" => "previous_response", "step" => "async_step"}
              ]
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(workflow)

      # Sync step should have normal result
      assert results["sync_step"]["success"] == true
      refute Map.has_key?(results["sync_step"], "type")

      # Async step should have async result
      assert results["async_step"]["type"] == "async_stream"

      # Final step should complete successfully
      assert results["final_step"]["success"] == true
    end

    test "tracks streaming metrics in execution" do
      # Mock async response with metrics
      _mock_stream =
        Stream.map(
          [
            %{type: :text, data: %{content: "Content", tokens: 5}},
            %{type: :result, data: %{session_id: "metrics_test"}, tokens: 3}
          ],
          & &1
        )

      # async_response = AsyncResponse.new(_mock_stream, "metrics_step", metadata: %{test: true})

      # Mocks.ClaudeProvider.set_response_pattern("__async__metrics test", fn _prompt ->
      #   async_response
      # end)

      workflow = %{
        "workflow" => %{
          "name" => "metrics_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "metrics_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "metrics test"}],
              "claude_options" => %{
                "async_streaming" => true
              }
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(workflow, enable_monitoring: false)

      result = results["metrics_step"]
      assert result["type"] == "async_stream"
      assert Map.has_key?(result["stream_info"], "started_at")
    end

    test "handles streaming errors gracefully" do
      # Mock error stream
      _error_stream =
        Stream.map(
          [
            %{type: :error, data: %{error: "Stream failed"}}
          ],
          & &1
        )

      # async_response = AsyncResponse.new(_error_stream, "error_step")

      # Mocks.ClaudeProvider.set_response_pattern("__async__error test", fn _prompt ->
      #   async_response
      # end)

      workflow = %{
        "workflow" => %{
          "name" => "error_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "error_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "error test"}],
              "claude_options" => %{
                "async_streaming" => true,
                "collect_stream" => true
              }
            }
          ]
        }
      }

      # The step should handle the error stream when collecting
      assert {:ok, results} = Executor.execute(workflow)
      assert Map.has_key?(results, "error_step")
    end
  end
end
