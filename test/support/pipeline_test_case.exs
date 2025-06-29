defmodule Pipeline.TestCase do
  @moduledoc """
  Compatibility wrapper for Pipeline.Test.Case to support legacy tests.
  """

  defmacro __using__(opts \\ []) do
    quote do
      use Pipeline.Test.Case, unquote(opts)

      # Import helpers for compatibility
      import Pipeline.Test.Helpers

      # Setup for legacy tests
      setup do
        # Create temporary directories for this test
        test_workspace = "/tmp/pipeline_test/workspace_#{:rand.uniform(999_999)}"
        test_output = "/tmp/pipeline_test/output_#{:rand.uniform(999_999)}"

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
end

defmodule Pipeline.UnitTestCase do
  @moduledoc """
  Test case for unit tests with mocked dependencies.
  """

  defmacro __using__(_opts \\ []) do
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

  defmacro __using__(_opts \\ []) do
    quote do
      use Pipeline.TestCase

      # Integration tests use real file system
      @moduletag :integration

      # Longer timeout for integration tests
      @moduletag timeout: 30_000
    end
  end
end
