defmodule Pipeline.Test.Mocks.GeminiProvider do
  @moduledoc """
  Mock implementation of Gemini provider for testing.
  """

  def query(prompt, _options \\ %{}) do
    case prompt do
      "simple test" ->
        {:ok,
         %{
           "content" => "Mock Gemini analysis",
           "success" => true,
           "cost" => 0.001,
           "function_calls" => []
         }}

      prompt when is_binary(prompt) ->
        cond do
          String.contains?(prompt, "plan") ->
            {:ok,
             %{
               "content" => ~s({"plan": "Mock implementation plan", "complexity": "medium"}),
               "success" => true,
               "cost" => 0.003,
               "function_calls" => []
             }}

          String.contains?(prompt, "analyze") ->
            {:ok,
             %{
               "content" => ~s({"analysis": "Mock analysis result", "confidence": 0.9}),
               "success" => true,
               "cost" => 0.004,
               "function_calls" => []
             }}

          true ->
            {:ok,
             %{
               "content" => "Mock Gemini response for: #{String.slice(prompt, 0, 50)}...",
               "success" => true,
               "cost" => 0.002,
               "function_calls" => []
             }}
        end

      _ ->
        {:ok,
         %{
           "content" => "Mock Gemini response",
           "success" => true,
           "cost" => 0.001,
           "function_calls" => []
         }}
    end
  end

  def generate_function_calls(_prompt, _tools, _options \\ %{}) do
    {:ok, []}
  end

  def reset, do: :ok
end
