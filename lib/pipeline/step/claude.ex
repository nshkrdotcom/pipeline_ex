defmodule Pipeline.Step.Claude do
  @moduledoc """
  Claude step executor - handles all Claude (Muscle) operations.
  """

  require Logger
  alias Pipeline.{TestMode, PromptBuilder}

  @doc """
  Execute a Claude step.
  """
  def execute(step, context) do
    Logger.info("💪 Executing Claude step: #{step["name"]}")

    # Build prompt from configuration
    prompt = PromptBuilder.build(step["prompt"], context.results)

    # Get Claude options
    options = step["claude_options"] || %{}

    # Get provider (mock or live based on test mode)
    provider = TestMode.provider_for(:ai)

    # Execute query
    case provider.query(prompt, options) do
      {:ok, response} ->
        Logger.info("✅ Claude step completed successfully")
        {:ok, response}

      {:error, reason} ->
        Logger.error("❌ Claude step failed: #{reason}")
        {:error, reason}
    end
  end
end
