defmodule Pipeline.Step.TestEcho do
  @moduledoc """
  Simple test step that echoes its value for testing purposes.
  Only available in test environment.
  """

  def execute(step, _context) do
    if Mix.env() != :test do
      {:error, "test_echo step is only available in test environment"}
    else
      value = step["value"] || "default_echo"

      # Support failure mode for testing error handling
      if step["fail"] == true || value == "__FAIL__" do
        error_message = step["error_message"] || "Test step intentionally failed"
        {:error, error_message}
      else
        {:ok, value}
      end
    end
  end
end
