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
      {:ok, value}
    end
  end
end
