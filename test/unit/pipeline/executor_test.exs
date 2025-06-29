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
      workspace_dir = "/tmp/test_workspace_#{System.unique_integer()}"
      output_dir = "/tmp/test_outputs_#{System.unique_integer()}"

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
      assert String.contains?(reason, "Unknown step type")
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
end
