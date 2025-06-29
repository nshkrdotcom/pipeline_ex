defmodule Pipeline.TestMode do
  @moduledoc """
  Manages test mode configuration for switching between mock and live providers.
  """

  def get_mode do
    case System.get_env("TEST_MODE") do
      "live" ->
        :live

      "mixed" ->
        :mixed

      "mock" ->
        :mock

      nil ->
        if Mix.env() == :test do
          :mock
        else
          :live
        end

      _ ->
        :mock
    end
  end

  def mock_mode?, do: get_mode() == :mock
  def live_mode?, do: get_mode() == :live
  def mixed_mode?, do: get_mode() == :mixed

  def provider_for(:ai) do
    case get_mode() do
      :mock ->
        Pipeline.Test.Mocks.ClaudeProvider

      :live ->
        Pipeline.Providers.ClaudeProvider

      :mixed ->
        if in_unit_test?(),
          do: Pipeline.Test.Mocks.ClaudeProvider,
          else: Pipeline.Providers.ClaudeProvider
    end
  end

  def provider_for(:gemini) do
    case get_mode() do
      :mock ->
        Pipeline.Test.Mocks.GeminiProvider

      :live ->
        Pipeline.Providers.GeminiProvider

      :mixed ->
        if in_unit_test?(),
          do: Pipeline.Test.Mocks.GeminiProvider,
          else: Pipeline.Providers.GeminiProvider
    end
  end

  defp in_unit_test? do
    case Process.get(:test_context) do
      :unit -> true
      :integration -> false
      _ -> false
    end
  end

  def set_test_context(context) when context in [:unit, :integration] do
    Process.put(:test_context, context)
  end

  def clear_test_context do
    Process.delete(:test_context)
  end
end
