defmodule Pipeline.Step.Gemini do
  @moduledoc """
  Gemini step executor - handles all Gemini (Brain) operations using InstructorLite.
  """

  require Logger
  alias Pipeline.{PromptBuilder, TestMode}

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
        # Handle function calling if functions are specified
        final_response =
          if step["functions"] do
            handle_function_calling(response, step["functions"])
          else
            response
          end

        Logger.info("✅ Gemini step completed successfully")
        {:ok, final_response}

      {:error, reason} ->
        Logger.error("❌ Gemini step failed: #{reason}")
        {:error, reason}
    end
  end

  defp build_options(step) do
    # Convert functions list to tools format for the provider
    tools =
      case step["functions"] do
        functions when is_list(functions) and length(functions) > 0 ->
          # Convert function names to tool objects
          Enum.map(functions, fn func_name -> %{"name" => func_name} end)

        _ ->
          step["tools"] || []
      end

    # Add timeout configuration - use step config, then application config, then fallback
    timeout_ms =
      step["timeout_ms"] ||
        Application.get_env(:pipeline, :gemini_timeout_ms, 300_000)

    Logger.info("🕒 DEBUG: Passing timeout_ms to provider: #{timeout_ms}")

    %{
      model: step["model"] || "gemini-2.5-flash-lite-preview-06-17",
      token_budget: step["token_budget"] || %{},
      tools: tools,
      timeout_ms: timeout_ms
    }
  end

  defp handle_function_calling(response, _functions) do
    # If response contains function_calls, extract the arguments from the first function call
    case response do
      %{"function_calls" => [function_call | _]} when is_map(function_call) ->
        # Extract arguments from function call and merge with response
        case function_call do
          %{"arguments" => arguments} when is_map(arguments) ->
            Map.merge(response, arguments)

          _ ->
            response
        end

      _ ->
        response
    end
  end
end
