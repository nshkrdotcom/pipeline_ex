defmodule Pipeline.Test.Mocks.ClaudeProvider do
  @moduledoc """
  Mock implementation of Claude provider for testing.
  """

  def query(prompt, _options \\ %{}) do
    # Check for pattern-specific responses first
    case find_matching_pattern(prompt) do
      {:ok, response} ->
        {:ok, response}

      :not_found ->
        handle_fallback_patterns(prompt)
    end
  end

  defp handle_fallback_patterns(prompt) do
    case prompt do
      "simple test" ->
        {:ok, %{"text" => "Mock response for simple test", "success" => true, "cost" => 0.001}}

      "error test" ->
        {:error, "Mock error for testing"}

      prompt when is_binary(prompt) ->
        handle_content_based_patterns(prompt)

      _ ->
        {:ok, %{"text" => "Mock response", "success" => true, "cost" => 0.001}}
    end
  end

  defp handle_content_based_patterns(prompt) do
    cond do
      String.contains?(prompt, "Python") ->
        {:ok, %{"text" => "Mock Python code response", "success" => true, "cost" => 0.002}}

      String.contains?(prompt, "calculator") ->
        {:ok, %{"text" => "Mock calculator implementation", "success" => true, "cost" => 0.004}}

      true ->
        {:ok,
         %{
           "text" => "Mock response for: #{String.slice(prompt, 0, 50)}...",
           "success" => true,
           "cost" => 0.001
         }}
    end
  end

  def set_response_pattern(pattern, response) do
    Process.put({:mock_response, pattern}, response)
  end

  def reset do
    # Clear all mock responses
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:mock_response, _}, key) end)
    |> Enum.each(&Process.delete/1)

    :ok
  end

  defp find_matching_pattern(prompt) do
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:mock_response, _}, key) end)
    |> Enum.find_value(:not_found, fn {_, pattern} ->
      if String.contains?(prompt, pattern) do
        {:ok, Process.get({:mock_response, pattern})}
      else
        nil
      end
    end)
  end
end
