defmodule Pipeline.Test.PerformanceTestCase do
  @moduledoc """
  Test case for performance tests with proper setup and teardown.
  """

  use ExUnit.CaseTemplate
  
  using do
    quote do
      use ExUnit.Case, async: false  # Performance tests should not run async
      
      import Pipeline.Test.PerformanceTestHelper
      alias Pipeline.Test.PerformanceTestHelper
      
      setup do
        # Clean up any leftover processes
        PerformanceTestHelper.cleanup_all_test_resources()
        
        # Create unique test workspace
        test_name = "#{__MODULE__}_#{System.unique_integer([:positive])}"
        workspace_dir = PerformanceTestHelper.create_test_workspace(test_name)
        
        on_exit(fn ->
          PerformanceTestHelper.cleanup_all_test_resources()
        end)
        
        {:ok, test_name: test_name, workspace_dir: workspace_dir}
      end
    end
  end
end