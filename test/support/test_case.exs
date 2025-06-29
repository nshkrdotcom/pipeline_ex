defmodule Pipeline.TestCase do
  @moduledoc """
  Base test case for pipeline tests with common setup and utilities.
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      # Import test helpers and assertions
      import Pipeline.Test.Helpers
      import ExUnit.Assertions
      
      # Alias commonly used modules
      alias Pipeline.{Config, Orchestrator, Debug, PromptBuilder}
      alias Pipeline.Step.{Gemini, Claude, ParallelClaude}
      alias Pipeline.Test.Mocks
      
      # Setup and teardown for each test
      setup do
        # Reset mocks before each test
        Pipeline.Test.Helpers.reset_mocks()
        
        # Create temporary directories for this test
        test_workspace = "/tmp/pipeline_test/workspace_#{:rand.uniform(999999)}"
        test_output = "/tmp/pipeline_test/output_#{:rand.uniform(999999)}"
        
        File.mkdir_p!(test_workspace)
        File.mkdir_p!(test_output)
        
        # Provide test context
        %{
          test_workspace: test_workspace,
          test_output: test_output
        }
      end
    end
  end
  
  setup tags do
    # Tag-based setup
    if tags[:with_temp_config] do
      config = Pipeline.Test.Helpers.create_test_config(
        name: "test_workflow",
        steps: [
          Pipeline.Test.Helpers.create_gemini_step(
            name: "test_step",
            prompt: "Test prompt"
          )
        ]
      )
      
      config_file = Pipeline.Test.Helpers.create_temp_config_file(config)
      
      on_exit(fn ->
        File.rm(config_file)
      end)
      
      {:ok, config_file: config_file, config: config}
    else
      :ok
    end
  end
end

defmodule Pipeline.UnitTestCase do
  @moduledoc """
  Test case for unit tests with mocked dependencies.
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      use Pipeline.TestCase
      
      # Additional setup for unit tests
      setup do
        # Reset mocks before each unit test
        Pipeline.Test.Helpers.reset_mocks()
        :ok
      end
    end
  end
end

defmodule Pipeline.IntegrationTestCase do
  @moduledoc """
  Test case for integration tests with real file system but mocked external services.
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      use Pipeline.TestCase
      
      # Integration tests use real file system
      @moduletag :integration
      
      # Longer timeout for integration tests
      @moduletag timeout: 30_000
    end
  end
end