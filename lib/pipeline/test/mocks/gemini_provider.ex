defmodule Pipeline.Test.Mocks.GeminiProvider do
  @moduledoc """
  Mock implementation of Gemini provider for testing.
  """

  def query(prompt, options \\ %{}) do
    # Check for pattern-specific responses first
    case find_matching_pattern(prompt) do
      {:ok, response} ->
        {:ok, response}

      :not_found ->
        # Check for function responses
        case find_function_response(prompt) do
          {:ok, function_response} ->
            {:ok, function_response}

          :not_found ->
            # Fall back to existing pattern matching
            case prompt do
              "simple test" ->
                response = %{
                  "content" => "Mock Gemini analysis",
                  "success" => true,
                  "cost" => 0.001
                }

                # Only add function_calls if tools are provided
                response =
                  if options[:tools] && length(options[:tools]) > 0 do
                    function_calls =
                      Enum.map(options["tools"], fn tool ->
                        %{
                          "name" => tool["name"] || "mock_function",
                          "arguments" => %{
                            "result" => "mock_function_result",
                            "status" => "completed"
                          }
                        }
                      end)

                    Map.put(response, "function_calls", function_calls)
                  else
                    response
                  end

                {:ok, response}

              prompt when is_binary(prompt) ->
                cond do
                  String.contains?(prompt, "This will fail") ->
                    {:error, "Mock function calling error"}

                  String.contains?(prompt, "plan") ->
                    response = %{
                      "content" =>
                        ~s({"plan": "Mock implementation plan", "complexity": "medium"}),
                      "success" => true,
                      "cost" => 0.003
                    }

                    response =
                      if options[:tools] && length(options[:tools]) > 0 do
                        function_calls =
                          Enum.map(options[:tools], fn tool ->
                            %{
                              "name" => tool["name"] || "mock_function",
                              "arguments" => %{
                                "result" => "mock_function_result",
                                "status" => "completed"
                              }
                            }
                          end)

                        Map.put(response, "function_calls", function_calls)
                      else
                        Map.put(response, "function_calls", [])
                      end

                    {:ok, response}

                  String.contains?(String.downcase(prompt), "analyze") ->
                    response = %{
                      "content" => ~s({"analysis": "Mock analysis result", "confidence": 0.9}),
                      "success" => true,
                      "cost" => 0.004
                    }

                    response =
                      if options[:tools] && length(options[:tools]) > 0 do
                        function_calls =
                          Enum.map(options[:tools], fn tool ->
                            %{
                              "name" => tool["name"] || "mock_function",
                              "arguments" => %{
                                "result" => "mock_function_result",
                                "status" => "completed"
                              }
                            }
                          end)

                        Map.put(response, "function_calls", function_calls)
                      else
                        Map.put(response, "function_calls", [])
                      end

                    {:ok, response}

                  true ->
                    response = %{
                      "content" => "Mock Gemini response for: #{String.slice(prompt, 0, 50)}...",
                      "success" => true,
                      "cost" => 0.002
                    }

                    # Only add function_calls if tools are provided
                    response =
                      if options[:tools] && length(options[:tools]) > 0 do
                        function_calls =
                          Enum.map(options[:tools], fn tool ->
                            %{
                              "name" => tool["name"] || "mock_function",
                              "arguments" => %{
                                "result" => "mock_function_result",
                                "status" => "completed"
                              }
                            }
                          end)

                        Map.put(response, "function_calls", function_calls)
                      else
                        response
                      end

                    {:ok, response}
                end

              _ ->
                response = %{
                  "content" => "Mock Gemini response",
                  "success" => true,
                  "cost" => 0.001
                }

                # Only add function_calls if tools are provided
                response =
                  if options[:tools] && length(options[:tools]) > 0 do
                    function_calls =
                      Enum.map(options[:tools], fn tool ->
                        %{
                          "name" => tool["name"] || "mock_function",
                          "arguments" => %{
                            "result" => "mock_function_result",
                            "status" => "completed"
                          }
                        }
                      end)

                    Map.put(response, "function_calls", function_calls)
                  else
                    response
                  end

                {:ok, response}
            end
        end
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
    # First try to match by function name in prompt
    result =
      Process.get_keys()
      |> Enum.filter(fn key -> match?({:mock_function, _}, key) end)
      |> Enum.find_value(:not_found, fn {_, function_name} ->
        if String.contains?(prompt, function_name) do
          {:ok, Process.get({:mock_function, function_name})}
        else
          nil
        end
      end)

    # If no direct match and we have common function keywords, return the first function response
    case result do
      :not_found ->
        if String.contains?(prompt, "Analyze") or String.contains?(prompt, "analyze") or
             String.contains?(prompt, "Validate") or String.contains?(prompt, "validate") or
             String.contains?(prompt, "Design") or String.contains?(prompt, "design") do
          # Return the first available function response
          Process.get_keys()
          |> Enum.filter(fn key -> match?({:mock_function, _}, key) end)
          |> Enum.take(1)
          |> case do
            [{_, function_name}] -> {:ok, Process.get({:mock_function, function_name})}
            [] -> :not_found
          end
        else
          :not_found
        end

      found ->
        found
    end
  end
end
