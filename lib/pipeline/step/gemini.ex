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
    IO.puts("DEBUG: Gemini.execute called with step: #{inspect(step)}")

    # Build prompt from configuration
    prompt = PromptBuilder.build(step["prompt"], context.results)
    IO.puts("DEBUG: Built prompt for Gemini: #{String.slice(prompt, 0, 200)}...")

    # Get Gemini options
    options = build_options(step)
    IO.puts("DEBUG: Built options for Gemini: #{inspect(options)}")

    # Get provider (mock or live based on test mode)
    provider = TestMode.provider_for(:gemini)
    IO.puts("DEBUG: Using provider: #{inspect(provider)}")

    # Execute query
    IO.puts("DEBUG: About to call provider.query")

    case provider.query(prompt, options) do
      {:ok, response} ->
        IO.puts("DEBUG: provider.query returned success: #{inspect(response)}")
        Logger.info("✅ Gemini step completed successfully")
        {:ok, response}

      {:error, reason} ->
        IO.puts("DEBUG: provider.query returned error: #{inspect(reason)}")
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
