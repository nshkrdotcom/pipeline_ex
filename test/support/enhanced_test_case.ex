defmodule Pipeline.Test.EnhancedTestCase do
  @moduledoc """
  Enhanced test case module that provides utilities for testing
  the new Claude Agent SDK integration features.
  """

  use ExUnit.CaseTemplate

  alias Pipeline.Test.EnhancedFactory

  using do
    quote do
      use ExUnit.Case

      import Pipeline.Test.EnhancedTestCase
      import Pipeline.Test.EnhancedFactory
      alias Pipeline.Test.{EnhancedFactory, EnhancedMocks}
      # Make the factory functions available directly
      import Pipeline.Test.EnhancedFactory

      # Ensure mock mode is always enabled for tests
      setup do
        # Set mock mode as default (no environment variables needed)
        Application.put_env(:pipeline, :test_mode, :mock)
        Application.put_env(:claude_code_sdk, :use_mock, true)

        # Start the mock system if not already started
        case Process.whereis(ClaudeAgentSDK.Mock) do
          nil ->
            {:ok, _} = ClaudeAgentSDK.Mock.start_link()

          _pid ->
            # Already started, just continue
            :ok
        end

        # Clear any existing mock responses
        ClaudeAgentSDK.Mock.clear_responses()

        # Create test workspace
        workspace_dir = "./test_workspace_#{:rand.uniform(10000)}"
        File.mkdir_p!(workspace_dir)

        on_exit(fn ->
          # Cleanup test workspace
          File.rm_rf!(workspace_dir)
        end)

        {:ok, workspace_dir: workspace_dir}
      end
    end
  end

  @doc """
  Sets up mock responses for a specific step type.
  """
  def setup_mock_for_step_type(step_type, custom_responses \\ nil) do
    mock_responses = EnhancedFactory.enhanced_mock_responses()

    responses =
      custom_responses || Map.get(mock_responses, step_type, mock_responses["claude_smart"])

    # Create a unique key for this test
    test_key = "#{step_type}_#{:rand.uniform(10000)}"
    ClaudeAgentSDK.Mock.set_response(test_key, responses)

    test_key
  end

  @doc """
  Sets up mock responses for error scenarios.
  """
  def setup_error_mock(error_type) do
    mock_responses = EnhancedFactory.enhanced_mock_responses()
    responses = Map.get(mock_responses, error_type, mock_responses["error_max_turns"])

    test_key = "error_#{error_type}_#{:rand.uniform(10000)}"
    ClaudeAgentSDK.Mock.set_response(test_key, responses)

    test_key
  end

  @doc """
  Creates a temporary workflow configuration file for testing.
  """
  def create_test_workflow_file(config, workspace_dir) do
    config_path = Path.join(workspace_dir, "test_workflow.yaml")
    # YamlElixir doesn't have write_to_string, use Jason for now
    yaml_content = Jason.encode!(config, pretty: true)
    File.write!(config_path, yaml_content)
    config_path
  end

  @doc """
  Validates that a workflow configuration is properly structured.
  """
  def assert_valid_workflow_config(config) do
    assert Map.has_key?(config, "workflow")
    assert Map.has_key?(config["workflow"], "name")
    assert Map.has_key?(config["workflow"], "steps")
    assert is_list(config["workflow"]["steps"])
  end

  @doc """
  Validates that enhanced Claude options are properly formatted.
  """
  def assert_valid_enhanced_claude_options(options) do
    # Core configuration
    if Map.has_key?(options, "max_turns") do
      assert is_integer(options["max_turns"])
      assert options["max_turns"] > 0
    end

    if Map.has_key?(options, "output_format") do
      assert options["output_format"] in ["text", "json", "stream_json"]
    end

    # Tool management
    if Map.has_key?(options, "allowed_tools") do
      assert is_list(options["allowed_tools"])
    end

    if Map.has_key?(options, "disallowed_tools") do
      assert is_list(options["disallowed_tools"])
    end

    # Retry configuration
    if Map.has_key?(options, "retry_config") do
      retry_config = options["retry_config"]
      assert Map.has_key?(retry_config, "max_retries")
      assert is_integer(retry_config["max_retries"])

      if Map.has_key?(retry_config, "backoff_strategy") do
        assert retry_config["backoff_strategy"] in ["linear", "exponential"]
      end

      if Map.has_key?(retry_config, "retry_on") do
        assert is_list(retry_config["retry_on"])
      end
    end
  end

  @doc """
  Validates that a step configuration for new step types is properly formatted.
  """
  def assert_valid_enhanced_step(step) do
    assert Map.has_key?(step, "name")
    assert Map.has_key?(step, "type")

    case step["type"] do
      "claude_smart" ->
        assert_valid_claude_smart_step(step)

      "claude_session" ->
        assert_valid_claude_session_step(step)

      "claude_extract" ->
        assert_valid_claude_extract_step(step)

      "claude_batch" ->
        assert_valid_claude_batch_step(step)

      "claude_robust" ->
        assert_valid_claude_robust_step(step)

      _ ->
        # For existing step types, just validate basic structure
        assert is_binary(step["name"])
        assert is_binary(step["type"])
    end
  end

  @doc """
  Validates claude_smart step configuration.
  """
  def assert_valid_claude_smart_step(step) do
    assert step["type"] == "claude_smart"

    if Map.has_key?(step, "preset") do
      assert step["preset"] in ["development", "production", "analysis", "chat"]
    end

    if Map.has_key?(step, "environment_aware") do
      assert is_boolean(step["environment_aware"])
    end

    if Map.has_key?(step, "claude_options") do
      assert_valid_enhanced_claude_options(step["claude_options"])
    end
  end

  @doc """
  Validates claude_session step configuration.
  """
  def assert_valid_claude_session_step(step) do
    assert step["type"] == "claude_session"

    if Map.has_key?(step, "session_config") do
      session_config = step["session_config"]

      if Map.has_key?(session_config, "persist") do
        assert is_boolean(session_config["persist"])
      end

      if Map.has_key?(session_config, "session_name") do
        assert is_binary(session_config["session_name"])
      end

      if Map.has_key?(session_config, "checkpoint_frequency") do
        assert is_integer(session_config["checkpoint_frequency"])
        assert session_config["checkpoint_frequency"] > 0
      end
    end
  end

  @doc """
  Validates claude_extract step configuration.
  """
  def assert_valid_claude_extract_step(step) do
    assert step["type"] == "claude_extract"

    if Map.has_key?(step, "extraction_config") do
      extraction_config = step["extraction_config"]

      if Map.has_key?(extraction_config, "format") do
        assert extraction_config["format"] in [
                 "text",
                 "json",
                 "structured",
                 "summary",
                 "markdown"
               ]
      end

      if Map.has_key?(extraction_config, "post_processing") do
        assert is_list(extraction_config["post_processing"])
      end

      if Map.has_key?(extraction_config, "max_summary_length") do
        assert is_integer(extraction_config["max_summary_length"])
        assert extraction_config["max_summary_length"] > 0
      end
    end
  end

  @doc """
  Validates claude_batch step configuration.
  """
  def assert_valid_claude_batch_step(step) do
    assert step["type"] == "claude_batch"

    if Map.has_key?(step, "batch_config") do
      batch_config = step["batch_config"]

      if Map.has_key?(batch_config, "max_parallel") do
        assert is_integer(batch_config["max_parallel"])
        assert batch_config["max_parallel"] > 0
      end

      if Map.has_key?(batch_config, "timeout_per_task") do
        assert is_integer(batch_config["timeout_per_task"])
        assert batch_config["timeout_per_task"] > 0
      end
    end

    if Map.has_key?(step, "tasks") do
      assert is_list(step["tasks"])
    end
  end

  @doc """
  Validates claude_robust step configuration.
  """
  def assert_valid_claude_robust_step(step) do
    assert step["type"] == "claude_robust"

    if Map.has_key?(step, "retry_config") do
      retry_config = step["retry_config"]

      if Map.has_key?(retry_config, "retry_conditions") do
        assert is_list(retry_config["retry_conditions"])
      end

      if Map.has_key?(retry_config, "fallback_action") do
        assert is_binary(retry_config["fallback_action"])
      end
    end
  end

  @doc """
  Validates enhanced prompt templates.
  """
  def assert_valid_enhanced_prompt(prompt) do
    assert Map.has_key?(prompt, "type")

    case prompt["type"] do
      "session_context" ->
        assert Map.has_key?(prompt, "session_id")

        if Map.has_key?(prompt, "include_last_n") do
          assert is_integer(prompt["include_last_n"])
          assert prompt["include_last_n"] > 0
        end

      "claude_continue" ->
        assert Map.has_key?(prompt, "session_id")

        if Map.has_key?(prompt, "new_prompt") do
          assert is_binary(prompt["new_prompt"])
        end

      "previous_response" ->
        assert Map.has_key?(prompt, "step")

        if Map.has_key?(prompt, "extract_with") do
          assert prompt["extract_with"] == "content_extractor"
        end

      _ ->
        # Standard prompt types
        assert prompt["type"] in ["static", "file", "previous_response"]
    end
  end

  @doc """
  Simulates a successful step execution result.
  """
  def mock_success_result(step_name, additional_data \\ %{}) do
    default_result = %{
      "success" => true,
      "step_name" => step_name,
      "text" => "Mock success response from #{step_name}",
      "cost" => 0.001,
      "duration_ms" => 1500,
      "session_id" => "mock-session-#{:rand.uniform(10000)}"
    }

    Map.merge(default_result, additional_data)
  end

  @doc """
  Simulates an error step execution result.
  """
  def mock_error_result(step_name, error_reason \\ "Mock error") do
    %{
      "success" => false,
      "step_name" => step_name,
      "error" => error_reason,
      "error_type" => "mock_error"
    }
  end

  @doc """
  Creates a mock context for step execution.
  """
  def mock_context(workspace_dir, config_overrides \\ %{}, previous_results \\ %{}) do
    default_config = %{
      "workflow" => %{
        "name" => "test_workflow",
        "environment" => %{
          "mode" => "test"
        }
      }
    }

    merged_config = deep_merge(default_config, config_overrides)

    %{
      workspace_dir: workspace_dir,
      checkpoint_dir: Path.join(workspace_dir, "checkpoints"),
      results: previous_results,
      config: merged_config
    }
  end

  # Helper function for deep merging maps
  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      deep_merge(v1, v2)
    end)
  end

  defp deep_merge(_left, right), do: right

  @doc """
  Asserts that a result contains expected success indicators.
  """
  def assert_success_result(result) do
    assert Map.has_key?(result, "success")
    assert result["success"] == true
    assert Map.has_key?(result, "text")
    assert is_binary(result["text"])
    assert String.length(result["text"]) > 0
  end

  @doc """
  Asserts that a result contains expected error indicators.
  """
  def assert_error_result(result) do
    assert Map.has_key?(result, "success")
    assert result["success"] == false
    assert Map.has_key?(result, "error")
    assert is_binary(result["error"])
  end

  @doc """
  Creates a temporary test configuration with all enhanced features.
  """
  def create_comprehensive_test_config(workspace_dir) do
    config =
      EnhancedFactory.enhanced_workflow(%{
        "workflow" => %{
          "workspace_dir" => workspace_dir,
          "checkpoint_dir" => Path.join(workspace_dir, "checkpoints"),
          "steps" => [
            EnhancedFactory.claude_smart_step(%{"name" => "smart_analysis"}),
            EnhancedFactory.claude_session_step(%{"name" => "persistent_session"}),
            EnhancedFactory.claude_extract_step(%{"name" => "content_extraction"}),
            EnhancedFactory.claude_batch_step(%{"name" => "batch_processing"}),
            EnhancedFactory.claude_robust_step(%{"name" => "robust_execution"})
          ]
        }
      })

    config_path = create_test_workflow_file(config, workspace_dir)
    {config, config_path}
  end
end
