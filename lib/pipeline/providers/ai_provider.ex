defmodule Pipeline.Providers.AIProvider do
  @moduledoc """
  Behavior for AI service providers (Claude, Gemini, etc.)

  This interface allows swapping between live and mock implementations
  for testing and development.
  """

  @type prompt :: String.t()
  @type options :: map()
  @type response :: %{
          text: String.t(),
          success: boolean(),
          cost: float()
        }
  @type error_reason :: String.t()

  @doc """
  Query the AI service with a prompt and options.

  Returns either a successful response with text, success status and cost,
  or an error with a reason string.
  """
  @callback query(prompt, options) :: {:ok, response} | {:error, error_reason}

  @doc """
  Get the provider implementation based on configuration.
  """
  def get_provider do
    case Pipeline.TestMode.get_mode() do
      :mock ->
        Pipeline.Test.Mocks.ClaudeProvider

      :live ->
        Pipeline.Providers.ClaudeProvider

      :mixed ->
        if in_unit_test?() do
          Pipeline.Test.Mocks.ClaudeProvider
        else
          Pipeline.Providers.ClaudeProvider
        end
    end
  end

  defp in_unit_test? do
    # Check if we're running unit tests specifically
    case ExUnit.configuration()[:include] do
      nil -> false
      includes -> :unit in includes
    end
  rescue
    _ -> false
  end
end
