# Test helper configuration for pipeline tests
ExUnit.start()

# Configure application for test environment
Application.put_env(:pipeline, :test_mode, true)

# Configure logger for tests
Logger.configure(level: :warning)

# Load test support modules
Code.require_file("support/test_case.exs", __DIR__)

# Set up global test configuration
defmodule Pipeline.TestConfig do
  @moduledoc """
  Global test configuration and setup.
  """
  
  def setup_test_env do
    # Create test directories
    File.mkdir_p!("/tmp/pipeline_test")
    File.mkdir_p!("/tmp/pipeline_test/workspace")
    File.mkdir_p!("/tmp/pipeline_test/output")
    
    # Reset any global state
    Pipeline.Test.Helpers.reset_mocks()
  end
  
  def cleanup_test_env do
    # Clean up test directories
    File.rm_rf("/tmp/pipeline_test")
    
    # Reset mocks
    Pipeline.Test.Helpers.reset_mocks()
  end
end

# Set up test environment
Pipeline.TestConfig.setup_test_env()

# Clean up after all tests
ExUnit.after_suite(fn _ ->
  Pipeline.TestConfig.cleanup_test_env()
end)
