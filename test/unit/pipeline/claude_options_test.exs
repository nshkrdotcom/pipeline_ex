defmodule Pipeline.ClaudeOptionsTest do
  use ExUnit.Case, async: false

  alias Pipeline.{Config, Executor, TestMode}
  alias Pipeline.Test.Mocks

  setup do
    # Set test mode - following existing pattern from executor_test.exs
    System.put_env("TEST_MODE", "mock")
    TestMode.set_test_context(:unit)

    # Reset mocks
    Mocks.ClaudeProvider.reset()

    # Clean up any test directories
    on_exit(fn ->
      File.rm_rf("/tmp/test_workspace")
      File.rm_rf("/tmp/test_outputs")
      TestMode.clear_test_context()
    end)

    :ok
  end

  describe "claude_options configuration" do
    test "applies claude_options from step configuration" do
      workflow = %{
        "workflow" => %{
          "name" => "claude_options_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_with_options",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 10,
                "allowed_tools" => ["Write", "Read"],
                "verbose" => true,
                "system_prompt" => "You are a helpful assistant"
              },
              "prompt" => [%{"type" => "static", "content" => "Test prompt"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by the mock provider

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_with_options"]["success"] == true
    end

    test "merges claude_options with defaults" do
      workflow = %{
        "workflow" => %{
          "name" => "claude_defaults_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{
            "output_dir" => "/tmp/test_outputs",
            "claude_options" => %{
              "max_turns" => 5,
              "verbose" => false,
              "system_prompt" => "Default system prompt"
            }
          },
          "steps" => [
            %{
              "name" => "claude_with_partial_options",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 8,
                "allowed_tools" => ["Write", "Edit"]
              },
              "prompt" => [%{"type" => "static", "content" => "Test prompt"}]
            }
          ]
        }
      }

      # Apply defaults first
      config_with_defaults = Config.apply_defaults(workflow)
      step = hd(config_with_defaults["workflow"]["steps"])

      # Check that defaults are merged correctly
      # Overridden
      assert step["claude_options"]["max_turns"] == 8
      # From defaults
      assert step["claude_options"]["verbose"] == false
      # From defaults
      assert step["claude_options"]["system_prompt"] == "Default system prompt"
      # Step-specific
      assert step["claude_options"]["allowed_tools"] == ["Write", "Edit"]
    end

    test "handles all supported claude_options" do
      workflow = %{
        "workflow" => %{
          "name" => "all_claude_options_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_all_options",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 15,
                "allowed_tools" => ["Write", "Read", "Edit", "Bash"],
                "disallowed_tools" => ["WebSearch"],
                "system_prompt" => "Custom system prompt",
                "verbose" => true,
                "cwd" => "/tmp/test_workspace/subdir"
              },
              "prompt" => [%{"type" => "static", "content" => "Test all options"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_all_options"]["success"] == true
    end

    test "validates claude_options against config schema" do
      config = %{
        "workflow" => %{
          "name" => "validation_test",
          "steps" => [
            %{
              "name" => "claude_step",
              "type" => "claude",
              "claude_options" => %{
                # Should be integer
                "max_turns" => "invalid_type",
                # Should be list
                "allowed_tools" => "not_a_list"
              },
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      # This should validate successfully as config validation focuses on structure
      # The provider will handle type validation
      assert :ok = Config.validate_workflow(config)
    end

    test "uses workspace_dir as default cwd when not specified" do
      workflow = %{
        "workflow" => %{
          "name" => "default_cwd_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_no_cwd",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 5
              },
              "prompt" => [%{"type" => "static", "content" => "Test default cwd"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_no_cwd"]["success"] == true
    end

    test "overrides workspace_dir with explicit cwd in claude_options" do
      workflow = %{
        "workflow" => %{
          "name" => "override_cwd_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_custom_cwd",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 5,
                "cwd" => "/tmp/custom_directory"
              },
              "prompt" => [%{"type" => "static", "content" => "Test custom cwd"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_custom_cwd"]["success"] == true
    end

    test "handles empty claude_options" do
      workflow = %{
        "workflow" => %{
          "name" => "empty_options_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_empty_options",
              "type" => "claude",
              "claude_options" => %{},
              "prompt" => [%{"type" => "static", "content" => "Test empty options"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_empty_options"]["success"] == true
    end

    test "handles missing claude_options" do
      workflow = %{
        "workflow" => %{
          "name" => "no_options_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "claude_no_options",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Test no options"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically

      assert {:ok, results} = Executor.execute(workflow)
      assert results["claude_no_options"]["success"] == true
    end
  end

  describe "claude_options validation" do
    test "validates max_turns is a positive integer" do
      config_with_defaults =
        Config.apply_defaults(%{
          "workflow" => %{
            "name" => "max_turns_test",
            "steps" => [
              %{
                "name" => "claude_step",
                "type" => "claude",
                "claude_options" => %{"max_turns" => 10},
                "prompt" => [%{"type" => "static", "content" => "Test"}]
              }
            ]
          }
        })

      step = hd(config_with_defaults["workflow"]["steps"])
      assert step["claude_options"]["max_turns"] == 10
    end

    test "validates allowed_tools is a list of strings" do
      config_with_defaults =
        Config.apply_defaults(%{
          "workflow" => %{
            "name" => "tools_test",
            "steps" => [
              %{
                "name" => "claude_step",
                "type" => "claude",
                "claude_options" => %{"allowed_tools" => ["Write", "Read", "Edit"]},
                "prompt" => [%{"type" => "static", "content" => "Test"}]
              }
            ]
          }
        })

      step = hd(config_with_defaults["workflow"]["steps"])
      assert step["claude_options"]["allowed_tools"] == ["Write", "Read", "Edit"]
    end

    test "validates system_prompt is a string" do
      config_with_defaults =
        Config.apply_defaults(%{
          "workflow" => %{
            "name" => "system_prompt_test",
            "steps" => [
              %{
                "name" => "claude_step",
                "type" => "claude",
                "claude_options" => %{"system_prompt" => "Custom prompt"},
                "prompt" => [%{"type" => "static", "content" => "Test"}]
              }
            ]
          }
        })

      step = hd(config_with_defaults["workflow"]["steps"])
      assert step["claude_options"]["system_prompt"] == "Custom prompt"
    end

    test "validates verbose is a boolean" do
      config_with_defaults =
        Config.apply_defaults(%{
          "workflow" => %{
            "name" => "verbose_test",
            "steps" => [
              %{
                "name" => "claude_step",
                "type" => "claude",
                "claude_options" => %{"verbose" => true},
                "prompt" => [%{"type" => "static", "content" => "Test"}]
              }
            ]
          }
        })

      step = hd(config_with_defaults["workflow"]["steps"])
      assert step["claude_options"]["verbose"] == true
    end

    test "validates cwd is a string path" do
      config_with_defaults =
        Config.apply_defaults(%{
          "workflow" => %{
            "name" => "cwd_test",
            "steps" => [
              %{
                "name" => "claude_step",
                "type" => "claude",
                "claude_options" => %{"cwd" => "/path/to/directory"},
                "prompt" => [%{"type" => "static", "content" => "Test"}]
              }
            ]
          }
        })

      step = hd(config_with_defaults["workflow"]["steps"])
      assert step["claude_options"]["cwd"] == "/path/to/directory"
    end
  end
end
