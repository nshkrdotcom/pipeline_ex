defmodule Pipeline.ConfigTest do
  use ExUnit.Case, async: true

  alias Pipeline.Config

  describe "load_workflow/1" do
    test "loads and validates a simple workflow" do
      yaml_content = """
      workflow:
        name: "test_workflow"
        workspace_dir: "./workspace"
        steps:
          - name: "step1"
            type: "claude"
            prompt:
              - type: "static"
                content: "Hello world"
      """

      file_path = "/tmp/test_workflow_#{System.unique_integer()}.yaml"
      File.write!(file_path, yaml_content)

      assert {:ok, config} = Config.load_workflow(file_path)
      assert config["workflow"]["name"] == "test_workflow"
      assert length(config["workflow"]["steps"]) == 1

      File.rm!(file_path)
    end

    test "returns error for invalid YAML" do
      invalid_yaml = """
      workflow:
        name: "test"
        steps:
          - name: "step1
            invalid yaml here
      """

      file_path = "/tmp/invalid_#{System.unique_integer()}.yaml"
      File.write!(file_path, invalid_yaml)

      assert {:error, reason} = Config.load_workflow(file_path)
      assert String.contains?(reason, "Failed to parse YAML")

      File.rm!(file_path)
    end

    test "returns error for missing file" do
      assert {:error, reason} = Config.load_workflow("/nonexistent/file.yaml")
      assert String.contains?(reason, "Failed to read file")
    end
  end

  describe "validate_workflow/1" do
    test "validates a correct workflow" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [
                %{"type" => "static", "content" => "Hello"}
              ]
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "rejects workflow without name" do
      config = %{
        "workflow" => %{
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "name") and String.contains?(reason, "field")
    end

    test "rejects workflow without steps" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow"
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "steps") and String.contains?(reason, "array")
    end

    test "rejects step with invalid type" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "steps" => [
            %{
              "name" => "step1",
              "type" => "invalid_type",
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "invalid type")
    end

    test "rejects step with invalid prompt parts" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [
                %{"type" => "invalid_prompt_type", "content" => "Hello"}
              ]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "invalid type")
    end

    test "rejects previous_response references to non-existent steps" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [
                %{"type" => "previous_response", "step" => "nonexistent_step"}
              ]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "references non-existent steps")
    end
  end

  describe "get_app_config/0" do
    test "returns default configuration" do
      config = Config.get_app_config()

      assert is_map(config)
      assert Map.has_key?(config, :workspace_dir)
      assert Map.has_key?(config, :output_dir)
      assert Map.has_key?(config, :log_level)
    end

    test "respects environment variables" do
      System.put_env("PIPELINE_WORKSPACE_DIR", "/custom/workspace")
      System.put_env("PIPELINE_DEBUG", "true")

      config = Config.get_app_config()

      assert config[:workspace_dir] == "/custom/workspace"
      assert config[:debug_enabled] == true

      System.delete_env("PIPELINE_WORKSPACE_DIR")
      System.delete_env("PIPELINE_DEBUG")
    end
  end

  describe "get_provider_config/1" do
    test "returns Claude provider configuration" do
      config = Config.get_provider_config(:claude)

      assert is_map(config)
      assert Map.has_key?(config, :model)
      assert Map.has_key?(config, :timeout)
    end

    test "returns Gemini provider configuration" do
      config = Config.get_provider_config(:gemini)

      assert is_map(config)
      assert Map.has_key?(config, :model)
      assert Map.has_key?(config, :timeout)
    end

    test "raises for unknown provider" do
      assert_raise ArgumentError, fn ->
        Config.get_provider_config(:unknown)
      end
    end
  end

  describe "apply_defaults/1" do
    test "applies default values to steps" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "defaults" => %{
            "claude_options" => %{"max_turns" => 5}
          },
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      updated_config = Config.apply_defaults(config)
      step = hd(updated_config["workflow"]["steps"])

      assert step["claude_options"]["max_turns"] == 5
    end

    test "doesn't override existing step options" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "defaults" => %{
            "claude_options" => %{"max_turns" => 5}
          },
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "claude_options" => %{"max_turns" => 3},
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      updated_config = Config.apply_defaults(config)
      step = hd(updated_config["workflow"]["steps"])

      assert step["claude_options"]["max_turns"] == 3
    end

    test "applies claude_output_format default" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "defaults" => %{
            "claude_output_format" => "text"
          },
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      updated_config = Config.apply_defaults(config)
      step = hd(updated_config["workflow"]["steps"])

      assert step["claude_options"]["output_format"] == "text"
    end

    test "uses json as default claude_output_format when not specified" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "defaults" => %{},
          "steps" => [
            %{
              "name" => "step1",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Hello"}]
            }
          ]
        }
      }

      updated_config = Config.apply_defaults(config)
      step = hd(updated_config["workflow"]["steps"])

      assert step["claude_options"]["output_format"] == "json"
    end

    test "applies defaults to parallel_claude tasks" do
      config = %{
        "workflow" => %{
          "name" => "test_workflow",
          "defaults" => %{
            "claude_output_format" => "markdown",
            "claude_options" => %{"max_turns" => 10}
          },
          "steps" => [
            %{
              "name" => "parallel_step",
              "type" => "parallel_claude",
              "parallel_tasks" => [
                %{
                  "id" => "task1",
                  "prompt" => [%{"type" => "static", "content" => "Task 1"}]
                },
                %{
                  "id" => "task2",
                  "prompt" => [%{"type" => "static", "content" => "Task 2"}],
                  "claude_options" => %{"max_turns" => 5}
                }
              ]
            }
          ]
        }
      }

      updated_config = Config.apply_defaults(config)
      step = hd(updated_config["workflow"]["steps"])

      # Check first task gets defaults
      task1 = Enum.find(step["parallel_tasks"], &(&1["id"] == "task1"))
      assert task1["claude_options"]["output_format"] == "markdown"
      assert task1["claude_options"]["max_turns"] == 10

      # Check second task keeps existing options but gets defaults for missing ones
      task2 = Enum.find(step["parallel_tasks"], &(&1["id"] == "task2"))
      assert task2["claude_options"]["output_format"] == "markdown"
      # existing option preserved
      assert task2["claude_options"]["max_turns"] == 5
    end
  end
end
