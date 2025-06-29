defmodule Pipeline.Step.Gemini do
  @moduledoc """
  Gemini step executor - handles all Gemini (Brain) operations using InstructorLite.
  """

  require Logger
  alias Pipeline.{TestMode, PromptBuilder}

  @doc """
  Execute a Gemini step.
  """
  def execute(step, context) do
    Logger.info("🧠 Executing Gemini step: #{step["name"]}")
    
    # Build prompt from configuration
    prompt = PromptBuilder.build(step["prompt"], context.results)
    
    # Get Gemini options
    options = build_options(step)
    
    # Get provider (mock or live based on test mode)
    provider = TestMode.provider_for(:gemini)
    
    # Execute query
    case provider.query(prompt, options) do
      {:ok, response} ->
        Logger.info("✅ Gemini step completed successfully")
        {:ok, response}
        
      {:error, reason} ->
        Logger.error("❌ Gemini step failed: #{reason}")
        {:error, reason}
    end
  end

  defp build_options(step) do
    %{
      model: step["model"] || "gemini-2.5-flash-lite-preview-06-17",
      token_budget: step["token_budget"] || %{},
      tools: step["tools"] || []
    }
  end
end