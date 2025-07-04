defmodule Pipeline.WorkspaceIntegrationTest do
  use ExUnit.Case, async: false

  alias Pipeline.{Config, Executor, TestMode}
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
      File.rm_rf("/tmp/test_workspace_main")
      File.rm_rf("/tmp/test_workspace_custom")
      File.rm_rf("/tmp/test_outputs")
      File.rm_rf("/tmp/custom_workspace")
      TestMode.clear_test_context()
    end)

    :ok
  end

  describe "workspace_dir configuration" do
    test "creates workspace directory automatically" do
      workspace_dir = "/tmp/test_workspace_#{System.unique_integer([:positive])}"

      workflow = %{
        "workflow" => %{
          "name" => "workspace_creation_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "simple_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Hello workspace"}]
            }
          ]
        }
      }

      # Ensure directory doesn't exist before test
      File.rm_rf(workspace_dir)
      refute File.exists?(workspace_dir)

      # Mock responses are handled automatically by pattern matching

      assert {:ok, _results} = Executor.execute(workflow)

      # Directory should be created after execution
      assert File.exists?(workspace_dir)
      assert File.dir?(workspace_dir)

      # Cleanup
      File.rm_rf(workspace_dir)
    end

    test "uses workspace_dir as default cwd for Claude steps" do
      workspace_dir = "/tmp/test_workspace_main"

      workflow = %{
        "workflow" => %{
          "name" => "workspace_cwd_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_in_workspace",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 5
                # No explicit cwd - should use workspace_dir
              },
              "prompt" => [%{"type" => "static", "content" => "Work in workspace"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_in_workspace"]["success"] == true
    end

    test "allows claude_options cwd to override workspace_dir" do
      workspace_dir = "/tmp/test_workspace_main"
      custom_cwd = "/tmp/custom_workspace"

      workflow = %{
        "workflow" => %{
          "name" => "workspace_override_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_custom_cwd",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 5,
                "cwd" => custom_cwd
              },
              "prompt" => [%{"type" => "static", "content" => "Work in custom directory"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_custom_cwd"]["success"] == true
    end

    test "handles relative workspace_dir paths" do
      # Test with relative path
      workflow = %{
        "workflow" => %{
          "name" => "relative_workspace_test",
          "workspace_dir" => "./workspace_relative",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_relative",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Relative workspace test"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_relative"]["success"] == true

      # Clean up relative directory
      File.rm_rf("./workspace_relative")
    end

    test "creates nested workspace directories" do
      nested_workspace = "/tmp/test_workspace_main/sub/nested/deep"

      workflow = %{
        "workflow" => %{
          "name" => "nested_workspace_test",
          "workspace_dir" => nested_workspace,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "nested_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Nested workspace"}]
            }
          ]
        }
      }

      # Ensure parent directories don't exist
      refute File.exists?("/tmp/test_workspace_main")

      # Mock responses are handled automatically by pattern matching

      assert {:ok, _results} = Executor.execute(workflow)

      # All nested directories should be created
      assert File.exists?(nested_workspace)
      assert File.dir?(nested_workspace)
    end

    test "handles workspace_dir permissions correctly" do
      workspace_dir = "/tmp/test_workspace_permissions"

      workflow = %{
        "workflow" => %{
          "name" => "permissions_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "permissions_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Test permissions"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, _results} = Executor.execute(workflow)

      # Verify directory was created with correct permissions
      assert File.exists?(workspace_dir)

      # Check basic read/write permissions
      test_file = Path.join(workspace_dir, "test.txt")
      assert :ok = File.write(test_file, "test content")
      assert {:ok, "test content"} = File.read(test_file)

      File.rm_rf(workspace_dir)
    end

    test "supports multiple steps with same workspace" do
      workspace_dir = "/tmp/test_workspace_shared"

      workflow = %{
        "workflow" => %{
          "name" => "shared_workspace_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "First step"}]
            },
            %{
              "name" => "step2",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Second step"}]
            },
            %{
              "name" => "step3",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "Third step"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["step1"]["success"] == true
      assert results["step2"]["success"] == true
      assert results["step3"]["success"] == true

      # All steps should have used the same workspace
      assert File.exists?(workspace_dir)
      File.rm_rf(workspace_dir)
    end

    test "workspace_dir with different cwd per step" do
      workspace_dir = "/tmp/test_workspace_main"
      subdir1 = "/tmp/test_workspace_main/subdir1"
      subdir2 = "/tmp/test_workspace_main/subdir2"

      workflow = %{
        "workflow" => %{
          "name" => "multi_cwd_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "step_in_subdir1",
              "type" => "claude",
              "claude_options" => %{"cwd" => subdir1},
              "prompt" => [%{"type" => "static", "content" => "Work in subdir1"}]
            },
            %{
              "name" => "step_in_subdir2",
              "type" => "claude",
              "claude_options" => %{"cwd" => subdir2},
              "prompt" => [%{"type" => "static", "content" => "Work in subdir2"}]
            },
            %{
              "name" => "step_in_workspace",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Work in main workspace"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["step_in_subdir1"]["success"] == true
      assert results["step_in_subdir2"]["success"] == true
      assert results["step_in_workspace"]["success"] == true
    end

    test "validates workspace_dir in configuration" do
      config = %{
        "workflow" => %{
          "name" => "workspace_validation",
          "workspace_dir" => "/valid/workspace/path",
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      # Should validate successfully
      assert :ok = Config.validate_workflow(config)
    end

    test "applies workspace_dir from defaults" do
      config = %{
        "workflow" => %{
          "name" => "workspace_defaults",
          "defaults" => %{
            "workspace_dir" => "/default/workspace"
          },
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      config_with_defaults = Config.apply_defaults(config)

      # workspace_dir should be applied as a default
      # Note: The actual implementation may handle this differently
      assert :ok = Config.validate_workflow(config_with_defaults)
    end

    test "handles workspace cleanup on failure" do
      workspace_dir = "/tmp/test_workspace_cleanup"

      workflow = %{
        "workflow" => %{
          "name" => "cleanup_test",
          "workspace_dir" => workspace_dir,
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

      # Mock a failure
      # Mock responses are handled automatically by pattern matching

      assert {:error, _reason} = Executor.execute(workflow)

      # Workspace directory should still exist for debugging
      assert File.exists?(workspace_dir)
      File.rm_rf(workspace_dir)
    end
  end

  describe "workspace and file operations integration" do
    test "file prompts work with workspace-relative paths" do
      workspace_dir = "/tmp/test_workspace_files"

      # Create a file in workspace
      File.mkdir_p!(workspace_dir)
      workspace_file = Path.join(workspace_dir, "input.txt")
      File.write!(workspace_file, "File content in workspace")

      workflow = %{
        "workflow" => %{
          "name" => "workspace_file_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "read_workspace_file",
              "type" => "claude",
              "prompt" => [
                %{"type" => "static", "content" => "Process this file:"},
                %{"type" => "file", "path" => workspace_file}
              ]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["read_workspace_file"]["success"] == true

      File.rm_rf(workspace_dir)
    end

    test "output files are created in correct workspace" do
      workspace_dir = "/tmp/test_workspace_output"

      workflow = %{
        "workflow" => %{
          "name" => "workspace_output_test",
          "workspace_dir" => workspace_dir,
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "create_output",
              "type" => "claude",
              "output_to_file" => "result.json",
              "prompt" => [%{"type" => "static", "content" => "Create output"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, _results} = Executor.execute(workflow)

      # Check that output file was created in the output directory
      output_file = "/tmp/test_outputs/result.json"
      assert File.exists?(output_file)

      File.rm_rf(workspace_dir)
      File.rm_rf("/tmp/test_outputs")
    end
  end
end
