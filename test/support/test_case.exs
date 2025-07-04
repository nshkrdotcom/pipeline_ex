defmodule Pipeline.Test.Case do
  @moduledoc """
  Base test case for Pipeline tests with mock/live mode support.
  """

  defmacro __using__(opts \\ []) do
    mode = Keyword.get(opts, :mode, :mock)

    quote do
      use ExUnit.Case, async: false

      alias Pipeline.Test.Mocks

      setup do
        # Set test mode for this test
        original_mode = System.get_env("TEST_MODE")

        case unquote(mode) do
          :mock ->
            System.put_env("TEST_MODE", "mock")
            Pipeline.TestMode.set_test_context(:unit)

          :live ->
            System.put_env("TEST_MODE", "live")
            Pipeline.TestMode.set_test_context(:integration)

          :mixed ->
            # Keep current TEST_MODE setting
            if String.contains?(to_string(__ENV__.file), "/unit/") do
              Pipeline.TestMode.set_test_context(:unit)
            else
              Pipeline.TestMode.set_test_context(:integration)
            end
        end

        # Reset all mocks
        Mocks.ClaudeProvider.reset()
        Mocks.GeminiProvider.reset()

        on_exit(fn ->
          Pipeline.TestMode.clear_test_context()

          # Restore original TEST_MODE
          case original_mode do
            nil -> System.delete_env("TEST_MODE")
            mode -> System.put_env("TEST_MODE", mode)
          end
        end)

        :ok
      end
    end
  end
end
