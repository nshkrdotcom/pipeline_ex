defmodule Pipeline.Test.Helpers do
  @moduledoc """
  Common test utilities for pipeline testing.
  """

  @doc """
  Execute a function with a temporary directory that gets cleaned up afterwards.
  
  ## Examples
  
      Pipeline.Test.Helpers.with_temp_dir(fn temp_dir ->
        # Use temp_dir for test operations
        assert File.exists?(temp_dir)
      end)
  """
  def with_temp_dir(fun) do
    temp_dir = System.tmp_dir!()
    |> Path.join("pipeline_test_#{:rand.uniform(999999)}")
    
    try do
      File.mkdir_p!(temp_dir)
      fun.(temp_dir)
    after
      File.rm_rf!(temp_dir)
    end
  end

  @doc """
  Create a test configuration from options.
  
  ## Options
  
    * `:name` - Workflow name (default: "test_workflow")
    * `:steps` - List of step configurations
    * `:workspace_dir` - Workspace directory
    * `:checkpoint_enabled` - Enable checkpoints
    * `:defaults` - Default configuration values
  
  ## Examples
  
      config = Pipeline.Test.Helpers.create_test_config(
        name: "test_pipeline",
        steps: [
          %{name: "test_step", type: "gemini", prompt: [{type: "static", content: "test"}]}
        ]
      )
  """
  def create_test_config(opts \\ []) do
    name = Keyword.get(opts, :name, "test_workflow")
    steps = Keyword.get(opts, :steps, [])
    workspace_dir = Keyword.get(opts, :workspace_dir, "./test_workspace")
    checkpoint_enabled = Keyword.get(opts, :checkpoint_enabled, false)
    defaults = Keyword.get(opts, :defaults, %{})
    
    %{
      workflow: %{
        name: name,
        workspace_dir: workspace_dir,
        checkpoint_enabled: checkpoint_enabled,
        defaults: defaults,
        steps: steps
      }
    }
  end

  @doc """
  Create a simple Gemini step configuration.
  
  ## Options
  
    * `:name` - Step name (required)
    * `:prompt` - Prompt content or configuration
    * `:model` - Gemini model to use
    * `:token_budget` - Token budget configuration
    * `:output_to_file` - Output file name
  """
  def create_gemini_step(opts) do
    name = Keyword.fetch!(opts, :name)
    prompt = Keyword.get(opts, :prompt, "Test prompt")
    
    prompt_config = if is_binary(prompt) do
      [%{type: "static", content: prompt}]
    else
      prompt
    end
    
    step = %{
      name: name,
      type: "gemini",
      prompt: prompt_config
    }
    
    step = if model = Keyword.get(opts, :model) do
      Map.put(step, :model, model)
    else
      step
    end
    
    step = if token_budget = Keyword.get(opts, :token_budget) do
      Map.put(step, :token_budget, token_budget)
    else
      step
    end
    
    step = if output_file = Keyword.get(opts, :output_to_file) do
      Map.put(step, :output_to_file, output_file)
    else
      step
    end
    
    step
  end

  @doc """
  Create a simple Claude step configuration.
  
  ## Options
  
    * `:name` - Step name (required)
    * `:prompt` - Prompt content or configuration
    * `:claude_options` - Claude CLI options
    * `:output_to_file` - Output file name
  """
  def create_claude_step(opts) do
    name = Keyword.fetch!(opts, :name)
    prompt = Keyword.get(opts, :prompt, "Test prompt")
    
    prompt_config = if is_binary(prompt) do
      [%{type: "static", content: prompt}]
    else
      prompt
    end
    
    step = %{
      name: name,
      type: "claude",
      prompt: prompt_config
    }
    
    step = if claude_options = Keyword.get(opts, :claude_options) do
      Map.put(step, :claude_options, claude_options)
    else
      step
    end
    
    step = if output_file = Keyword.get(opts, :output_to_file) do
      Map.put(step, :output_to_file, output_file)
    else
      step
    end
    
    step
  end

  @doc """
  Assert that a step was executed and has results.
  
  ## Examples
  
      orchestrator = %Pipeline.Orchestrator{results: %{"test_step" => %{status: "completed"}}}
      Pipeline.Test.Helpers.assert_step_executed(orchestrator, "test_step")
  """
  def assert_step_executed(orchestrator, step_name) do
    import ExUnit.Assertions
    
    assert Map.has_key?(orchestrator.results, step_name),
           "Step '#{step_name}' was not executed. Available steps: #{inspect(Map.keys(orchestrator.results))}"
    
    result = Map.get(orchestrator.results, step_name)
    refute is_nil(result), "Step '#{step_name}' has nil result"
    
    result
  end

  @doc """
  Assert that a file was created with optional content check.
  
  ## Examples
  
      Pipeline.Test.Helpers.assert_file_created("/tmp/test.txt")
      Pipeline.Test.Helpers.assert_file_created("/tmp/test.txt", "expected content")
  """
  def assert_file_created(path, expected_content \\ nil) do
    import ExUnit.Assertions
    
    assert File.exists?(path), "File does not exist: #{path}"
    
    if expected_content do
      {:ok, actual_content} = File.read(path)
      assert actual_content == expected_content,
             "File content mismatch.\nExpected: #{inspect(expected_content)}\nActual: #{inspect(actual_content)}"
    end
    
    :ok
  end

  @doc """
  Assert that a file was created in the mock file system.
  
  Uses Pipeline.Test.Mocks.FileMock to check file existence.
  """
  def assert_mock_file_created(path, expected_content \\ nil) do
    import ExUnit.Assertions
    alias Pipeline.Test.Mocks.FileMock
    
    assert FileMock.exists?(path), "Mock file does not exist: #{path}"
    
    if expected_content do
      {:ok, actual_content} = FileMock.read(path)
      assert actual_content == expected_content,
             "Mock file content mismatch.\nExpected: #{inspect(expected_content)}\nActual: #{inspect(actual_content)}"
    end
    
    :ok
  end

  @doc """
  Capture Logger output during test execution.
  
  ## Examples
  
      {result, logs} = Pipeline.Test.Helpers.capture_logs(fn ->
        Logger.info("Test message")
        :some_result
      end)
      
      assert result == :some_result
      assert Enum.any?(logs, &String.contains?(&1, "Test message"))
  """
  def capture_logs(fun) do
    # Start capturing logs
    :logger.add_handler(:test_handler, :logger_std_h, %{config: %{type: :standard_io}})
    
    # Create a temporary log buffer
    log_messages = []
    
    # Execute function and capture result
    result = fun.()
    
    # Remove handler
    :logger.remove_handler(:test_handler)
    
    # Return result and captured logs
    {result, log_messages}
  end

  # TODO: Update this to work with Executor pattern instead of Orchestrator
  # @doc """
  # Create a test orchestrator with mock dependencies.
  # 
  # ## Options
  # 
  #   * `:config` - Configuration map
  #   * `:workspace_dir` - Workspace directory (default: "/tmp/test_workspace")
  #   * `:output_dir` - Output directory (default: "/tmp/test_output")
  # """
  # def create_test_orchestrator(opts \\ []) do
  #   config = Keyword.get(opts, :config, create_test_config())
  #   workspace_dir = Keyword.get(opts, :workspace_dir, "/tmp/test_workspace")
  #   output_dir = Keyword.get(opts, :output_dir, "/tmp/test_output")
  #   
  #   %Pipeline.Orchestrator{
  #     config: %{workflow: config.workflow},
  #     results: %{},
  #     debug_log: "/tmp/test_debug.log",
  #     output_dir: output_dir,
  #     workspace_dir: workspace_dir
  #   }
  # end

  @doc """
  Reset all mock state (useful to run between tests).
  """
  def reset_mocks do
    Pipeline.Test.Mocks.FileMock.reset()
    Pipeline.Test.Mocks.LoggerMock.reset()
    :ok
  end

  @doc """
  Assert that a log message was captured.
  
  ## Examples
  
      Pipeline.Test.Helpers.assert_logged(:info, "Starting pipeline")
      Pipeline.Test.Helpers.assert_logged(:error, ~r/Error: .+/)
  """
  def assert_logged(level, message_or_pattern) do
    import ExUnit.Assertions
    alias Pipeline.Test.Mocks.LoggerMock
    
    logs = LoggerMock.get_logs_by_level(level)
    
    found = Enum.any?(logs, fn log ->
      cond do
        is_binary(message_or_pattern) ->
          String.contains?(log.message, message_or_pattern)
        is_struct(message_or_pattern, Regex) ->
          Regex.match?(message_or_pattern, log.message)
        true ->
          false
      end
    end)
    
    assert found, 
           "Expected log message not found.\nLevel: #{level}\nPattern: #{inspect(message_or_pattern)}\nActual logs: #{inspect(Enum.map(logs, & &1.message))}"
  end

  @doc """
  Create a temporary YAML config file for testing.
  
  ## Examples
  
      config_path = Pipeline.Test.Helpers.create_temp_config_file(%{
        workflow: %{
          name: "test",
          steps: [%{name: "step1", type: "gemini", prompt: [{type: "static", content: "test"}]}]
        }
      })
  """
  def create_temp_config_file(config_map) do
    temp_file = System.tmp_dir!()
    |> Path.join("test_config_#{:rand.uniform(999999)}.yaml")
    
    # Simple YAML generation for testing
    yaml_content = inspect(config_map, pretty: true, limit: :infinity)
    File.write!(temp_file, yaml_content)
    
    temp_file
  end
end