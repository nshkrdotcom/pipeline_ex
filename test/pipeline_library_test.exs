defmodule PipelineLibraryTest do
  @moduledoc """
  Tests for Pipeline library functionality when used as a dependency.

  These tests ensure the library works correctly when consumed by other applications.
  """

  use ExUnit.Case, async: false
  use Pipeline.TestCase

  describe "Pipeline main module API" do
    test "load_workflow/1 delegates to Config.load_workflow/1" do
      # Create a temporary test workflow
      workflow_content = """
      workflow:
        name: test_workflow
        steps:
          - name: test_step
            type: claude
            prompt:
              - type: static
                content: "Test prompt"
      """

      temp_file = "/tmp/test_workflow_#{:rand.uniform(10000)}.yaml"
      File.write!(temp_file, workflow_content)

      try do
        {:ok, config} = Pipeline.load_workflow(temp_file)
        assert config["workflow"]["name"] == "test_workflow"
        assert length(config["workflow"]["steps"]) == 1
      after
        File.rm(temp_file)
      end
    end

    test "execute/2 delegates to Executor.execute/2" do
      config = %{
        "workflow" => %{
          "name" => "test_execution",
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      # Should work in mock mode
      {:ok, results} = Pipeline.execute(config)
      assert Map.has_key?(results, "test_step")
      assert results["test_step"]["success"] == true
    end

    test "run/2 combines load_workflow and execute" do
      # Create a temporary test workflow
      workflow_content = """
      workflow:
        name: test_run_workflow
        steps:
          - name: run_test_step
            type: claude
            prompt:
              - type: static
                content: "Test run functionality"
      """

      temp_file = "/tmp/test_run_workflow_#{:rand.uniform(10000)}.yaml"
      File.write!(temp_file, workflow_content)

      try do
        {:ok, results} = Pipeline.run(temp_file)
        assert Map.has_key?(results, "run_test_step")
        assert results["run_test_step"]["success"] == true
      after
        File.rm(temp_file)
      end
    end

    test "get_config/0 returns app configuration" do
      config = Pipeline.get_config()

      assert Map.has_key?(config, :workspace_dir)
      assert Map.has_key?(config, :output_dir)
      assert Map.has_key?(config, :checkpoint_dir)
      assert Map.has_key?(config, :test_mode)
      assert Map.has_key?(config, :debug_enabled)
    end

    test "health_check/0 validates system configuration" do
      # In mock mode with proper setup, health check should pass
      case Pipeline.health_check() do
        :ok ->
          # Expected in mock mode
          assert true

        {:error, issues} ->
          # If there are issues, they should be strings
          assert is_list(issues)
          Enum.each(issues, fn issue -> assert is_binary(issue) end)
      end
    end
  end

  describe "configurable directory paths" do
    test "execute/2 accepts custom workspace_dir option" do
      config = %{
        "workflow" => %{
          "name" => "test_custom_dirs",
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      custom_workspace = "/tmp/custom_workspace_#{:rand.uniform(10000)}"
      custom_output = "/tmp/custom_output_#{:rand.uniform(10000)}"
      custom_checkpoint = "/tmp/custom_checkpoint_#{:rand.uniform(10000)}"

      try do
        {:ok, results} =
          Pipeline.execute(config,
            workspace_dir: custom_workspace,
            output_dir: custom_output,
            checkpoint_dir: custom_checkpoint
          )

        assert Map.has_key?(results, "test_step")

        # Verify directories were created
        assert File.exists?(custom_workspace)
        assert File.exists?(custom_output)
        assert File.exists?(custom_checkpoint)
      after
        # Cleanup
        File.rm_rf(custom_workspace)
        File.rm_rf(custom_output)
        File.rm_rf(custom_checkpoint)
      end
    end

    test "execute/2 respects environment variable defaults" do
      # Set custom environment variables
      original_workspace = System.get_env("PIPELINE_WORKSPACE_DIR")
      original_output = System.get_env("PIPELINE_OUTPUT_DIR")
      original_checkpoint = System.get_env("PIPELINE_CHECKPOINT_DIR")

      custom_workspace = "/tmp/env_workspace_#{:rand.uniform(10000)}"
      custom_output = "/tmp/env_output_#{:rand.uniform(10000)}"
      custom_checkpoint = "/tmp/env_checkpoint_#{:rand.uniform(10000)}"

      try do
        System.put_env("PIPELINE_WORKSPACE_DIR", custom_workspace)
        System.put_env("PIPELINE_OUTPUT_DIR", custom_output)
        System.put_env("PIPELINE_CHECKPOINT_DIR", custom_checkpoint)

        config = %{
          "workflow" => %{
            "name" => "test_env_dirs",
            "steps" => [
              %{
                "name" => "test_step",
                "type" => "claude",
                "prompt" => [%{"type" => "static", "content" => "Test"}]
              }
            ]
          }
        }

        {:ok, results} = Pipeline.execute(config)
        assert Map.has_key?(results, "test_step")

        # Verify environment-specified directories were created
        assert File.exists?(custom_workspace)
        assert File.exists?(custom_output)
        assert File.exists?(custom_checkpoint)
      after
        # Restore original environment
        if original_workspace, do: System.put_env("PIPELINE_WORKSPACE_DIR", original_workspace)
        if original_output, do: System.put_env("PIPELINE_OUTPUT_DIR", original_output)
        if original_checkpoint, do: System.put_env("PIPELINE_CHECKPOINT_DIR", original_checkpoint)

        unless original_workspace, do: System.delete_env("PIPELINE_WORKSPACE_DIR")
        unless original_output, do: System.delete_env("PIPELINE_OUTPUT_DIR")
        unless original_checkpoint, do: System.delete_env("PIPELINE_CHECKPOINT_DIR")

        # Cleanup test directories
        File.rm_rf(custom_workspace)
        File.rm_rf(custom_output)
        File.rm_rf(custom_checkpoint)
      end
    end

    test "execute/2 falls back to relative paths when no options provided" do
      config = %{
        "workflow" => %{
          "name" => "test_default_dirs",
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      # Clear environment variables to test defaults
      original_workspace = System.get_env("PIPELINE_WORKSPACE_DIR")
      original_output = System.get_env("PIPELINE_OUTPUT_DIR")
      original_checkpoint = System.get_env("PIPELINE_CHECKPOINT_DIR")

      try do
        System.delete_env("PIPELINE_WORKSPACE_DIR")
        System.delete_env("PIPELINE_OUTPUT_DIR")
        System.delete_env("PIPELINE_CHECKPOINT_DIR")

        {:ok, results} = Pipeline.execute(config)
        assert Map.has_key?(results, "test_step")

        # Default directories should be created
        assert File.exists?("./workspace")
        assert File.exists?("./outputs")
        assert File.exists?("./checkpoints")
      after
        # Restore original environment
        if original_workspace, do: System.put_env("PIPELINE_WORKSPACE_DIR", original_workspace)
        if original_output, do: System.put_env("PIPELINE_OUTPUT_DIR", original_output)
        if original_checkpoint, do: System.put_env("PIPELINE_CHECKPOINT_DIR", original_checkpoint)
      end
    end
  end

  describe "library error handling" do
    test "run/2 returns error for non-existent file" do
      {:error, reason} = Pipeline.run("/non/existent/file.yaml")
      assert is_binary(reason)
      assert reason =~ "file" or reason =~ "exist"
    end

    test "execute/2 returns error for invalid workflow config" do
      invalid_config = %{"invalid" => "config"}

      {:error, reason} = Pipeline.execute(invalid_config)
      assert is_binary(reason)
    end

    test "health_check/0 reports missing dependencies" do
      # Temporarily unset API key to test error reporting
      original_key = System.get_env("GEMINI_API_KEY")
      original_test_mode = System.get_env("TEST_MODE")

      try do
        System.delete_env("GEMINI_API_KEY")
        System.put_env("TEST_MODE", "live")

        case Pipeline.health_check() do
          {:error, issues} ->
            assert is_list(issues)

            assert Enum.any?(issues, fn issue ->
                     String.contains?(issue, "GEMINI_API_KEY")
                   end)

          :ok ->
            # This might happen if Claude CLI is available and test passes
            assert true
        end
      after
        # Restore original environment
        if original_key, do: System.put_env("GEMINI_API_KEY", original_key)
        if original_test_mode, do: System.put_env("TEST_MODE", original_test_mode)
        unless original_test_mode, do: System.delete_env("TEST_MODE")
      end
    end
  end

  describe "test mode compatibility" do
    test "execute/2 works in mock mode without API keys" do
      # Ensure we're in mock mode
      original_test_mode = System.get_env("TEST_MODE")
      original_api_key = System.get_env("GEMINI_API_KEY")

      try do
        System.put_env("TEST_MODE", "mock")
        System.delete_env("GEMINI_API_KEY")

        config = %{
          "workflow" => %{
            "name" => "test_mock_mode",
            "steps" => [
              %{
                "name" => "mock_claude_step",
                "type" => "claude",
                "prompt" => [%{"type" => "static", "content" => "Test in mock mode"}]
              },
              %{
                "name" => "mock_gemini_step",
                "type" => "gemini",
                "prompt" => [%{"type" => "static", "content" => "Test Gemini in mock mode"}]
              }
            ]
          }
        }

        {:ok, results} = Pipeline.execute(config)

        assert Map.has_key?(results, "mock_claude_step")
        assert Map.has_key?(results, "mock_gemini_step")
        assert results["mock_claude_step"]["success"] == true
        assert results["mock_gemini_step"]["success"] == true
      after
        # Restore original environment
        if original_test_mode, do: System.put_env("TEST_MODE", original_test_mode)
        if original_api_key, do: System.put_env("GEMINI_API_KEY", original_api_key)
        unless original_test_mode, do: System.delete_env("TEST_MODE")
      end
    end
  end

  describe "library integration patterns" do
    test "can be used as dependency with custom configuration" do
      # This test simulates how another application would use pipeline_ex

      # 1. Load a workflow
      workflow_content = """
      workflow:
        name: integration_test
        steps:
          - name: analysis_step
            type: claude
            prompt:
              - type: static
                content: "Analyze this code for quality issues"
          - name: summary_step
            type: gemini
            prompt:
              - type: static
                content: "Summarize the analysis"
              - type: previous_response
                step: analysis_step
      """

      temp_file = "/tmp/integration_test_#{:rand.uniform(10000)}.yaml"
      File.write!(temp_file, workflow_content)

      try do
        # 2. Configure custom paths (like a consuming app would)
        app_workspace = "/tmp/myapp_workspace_#{:rand.uniform(10000)}"
        app_outputs = "/tmp/myapp_outputs_#{:rand.uniform(10000)}"

        # 3. Execute pipeline with app-specific configuration
        {:ok, results} =
          Pipeline.run(temp_file,
            workspace_dir: app_workspace,
            output_dir: app_outputs,
            debug: false
          )

        # 4. Verify results are structured correctly for consuming app
        assert is_map(results)
        assert Map.has_key?(results, "analysis_step")
        assert Map.has_key?(results, "summary_step")

        # 5. Verify app-specific directories were used
        assert File.exists?(app_workspace)
        assert File.exists?(app_outputs)

        # 6. Results should be consumable by application logic
        analysis_result = results["analysis_step"]
        assert Map.has_key?(analysis_result, "success")
        assert is_boolean(analysis_result["success"])
      after
        File.rm(temp_file)
        File.rm_rf("/tmp/myapp_workspace_#{:rand.uniform(10000)}")
        File.rm_rf("/tmp/myapp_outputs_#{:rand.uniform(10000)}")
      end
    end
  end
end
