defmodule Pipeline.Test.Mocks.GeminiProvider do
  @moduledoc """
  Mock implementation of Gemini provider for testing.
  """

  def query(prompt, options \\ %{}) do
    with :not_found <- find_matching_pattern(prompt),
         :not_found <- find_function_response(prompt) do
      handle_prompt_pattern(prompt, options)
    else
      {:ok, response} -> {:ok, response}
    end
  end

  defp handle_prompt_pattern("simple test", options) do
    response = create_base_response("Mock Gemini analysis", true, 0.001)
    response_with_tools = add_function_calls_if_needed(response, options)
    {:ok, response_with_tools}
  end

  defp handle_prompt_pattern(prompt, options) when is_binary(prompt) do
    handle_prompt_content_patterns(prompt, options)
  end

  defp handle_prompt_pattern(_, _options) do
    {:ok, create_base_response("Mock fallback response", true, 0.001)}
  end

  defp create_base_response(content, success, cost) do
    %{"content" => content, "success" => success, "cost" => cost}
  end

  defp add_function_calls_if_needed(response, options) do
    if options[:tools] && length(options[:tools]) > 0 do
      function_calls = create_mock_function_calls(options[:tools])
      Map.put(response, "function_calls", function_calls)
    else
      response
    end
  end

  defp create_mock_function_calls(tools) do
    Enum.map(tools, fn tool ->
      %{
        "name" => tool["name"] || "mock_function",
        "arguments" => %{
          "result" => "mock_function_result",
          "status" => "completed"
        }
      }
    end)
  end

  defp handle_prompt_content_patterns(prompt, options) do
    cond do
      String.contains?(prompt, "This will fail") ->
        {:error, "Mock function calling error"}

      String.contains?(prompt, "plan") ->
        response = create_plan_response()
        {:ok, add_function_calls_with_empty_default(response, options)}

      String.contains?(String.downcase(prompt), "analyze") ->
        response = create_analysis_response()
        {:ok, add_function_calls_with_empty_default(response, options)}

      true ->
        response = create_generic_response(prompt)
        {:ok, add_function_calls_if_needed(response, options)}
    end
  end

  defp create_plan_response do
    %{
      "content" => ~s({"plan": "Mock implementation plan", "complexity": "medium"}),
      "success" => true,
      "cost" => 0.003
    }
  end

  defp create_analysis_response do
    %{
      "content" => ~s({"analysis": "Mock analysis result", "confidence": 0.9}),
      "success" => true,
      "cost" => 0.004
    }
  end

  defp create_generic_response(prompt) do
    %{
      "content" => "Mock Gemini response for: #{String.slice(prompt, 0, 50)}...",
      "success" => true,
      "cost" => 0.002
    }
  end

  defp add_function_calls_with_empty_default(response, options) do
    if options[:tools] && length(options[:tools]) > 0 do
      function_calls = create_mock_function_calls(options[:tools])
      Map.put(response, "function_calls", function_calls)
    else
      Map.put(response, "function_calls", [])
    end
  end

  def generate_function_calls(prompt, _tools, _options \\ %{}) do
    # Check for function-specific responses
    case find_function_response(prompt) do
      {:ok, response} -> {:ok, response["function_calls"] || []}
      :not_found -> {:ok, []}
    end
  end

  def set_response_pattern(pattern, response) do
    Process.put({:mock_response, pattern}, response)
  end

  def set_function_response(function_name, response) do
    Process.put({:mock_function, function_name}, response)
  end

  def reset do
    # Clear all mock responses
    Process.get_keys()
    |> Enum.filter(fn key ->
      match?({:mock_response, _}, key) or match?({:mock_function, _}, key)
    end)
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

  defp find_function_response(prompt) do
    case find_exact_function_match(prompt) do
      :not_found -> find_keyword_function_match(prompt)
      found -> found
    end
  end

  defp find_exact_function_match(prompt) do
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:mock_function, _}, key) end)
    |> Enum.find_value(:not_found, &check_function_name_match(prompt, &1))
  end

  defp check_function_name_match(prompt, {_, function_name}) do
    if String.contains?(prompt, function_name) do
      {:ok, Process.get({:mock_function, function_name})}
    else
      nil
    end
  end

  defp find_keyword_function_match(prompt) do
    if has_common_keywords?(prompt) do
      get_first_available_function()
    else
      :not_found
    end
  end

  defp has_common_keywords?(prompt) do
    keywords = ["Analyze", "analyze", "Validate", "validate", "Design", "design"]
    Enum.any?(keywords, &String.contains?(prompt, &1))
  end

  defp get_first_available_function do
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:mock_function, _}, key) end)
    |> Enum.take(1)
    |> case do
      [{_, function_name}] -> {:ok, Process.get({:mock_function, function_name})}
      [] -> :not_found
    end
  end
end
