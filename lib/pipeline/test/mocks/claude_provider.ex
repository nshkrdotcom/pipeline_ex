defmodule Pipeline.Test.Mocks.ClaudeProvider do
  @moduledoc """
  Mock implementation of Claude provider for testing.
  """

  def query(prompt, _options \\ %{}) do
    case prompt do
      "simple test" ->
        {:ok, %{"text" => "Mock response for simple test", "success" => true, "cost" => 0.001}}
      "error test" ->
        {:error, "Mock error for testing"}
      prompt when is_binary(prompt) ->
        cond do
          String.contains?(prompt, "Python") ->
            {:ok, %{"text" => "Mock Python code response", "success" => true, "cost" => 0.002}}
          String.contains?(prompt, "calculator") ->
            {:ok, %{"text" => "Mock calculator implementation", "success" => true, "cost" => 0.004}}
          true ->
            {:ok, %{"text" => "Mock response for: #{String.slice(prompt, 0, 50)}...", "success" => true, "cost" => 0.001}}
        end
      _ ->
        {:ok, %{"text" => "Mock response", "success" => true, "cost" => 0.001}}
    end
  end

  def reset, do: :ok
end