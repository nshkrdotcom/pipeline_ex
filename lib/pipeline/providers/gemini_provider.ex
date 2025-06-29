defmodule Pipeline.Providers.GeminiProvider do
  @moduledoc """
  Live Gemini provider using InstructorLite for structured generation.
  """

  require Logger

  @doc """
  Query Gemini using InstructorLite for structured responses.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug("🧠 Querying Gemini with prompt: #{String.slice(prompt, 0, 100)}...")
    
    # Build instruction configuration
    instruction_config = build_instruction_config(options)
    
    # Execute the instruction
    case InstructorLite.instruct(prompt, instruction_config) do
      {:ok, response} ->
        formatted_response = format_gemini_response(response)
        Logger.debug("✅ Gemini query successful")
        {:ok, formatted_response}
        
      {:error, reason} ->
        Logger.error("❌ Gemini query failed: #{inspect(reason)}")
        {:error, format_error(reason)}
    end
  rescue
    error ->
      Logger.error("💥 Gemini query crashed: #{inspect(error)}")
      {:error, "Gemini query crashed: #{Exception.message(error)}"}
  end

  @doc """
  Generate function calls using Gemini and InstructorLite.
  """
  def generate_function_calls(prompt, tools, options \\ %{}) do
    Logger.debug("🔧 Generating function calls for tools: #{inspect(tools)}")
    
    # Build function calling instruction
    function_prompt = build_function_calling_prompt(prompt, tools)
    instruction_config = build_function_calling_config(options)
    
    case InstructorLite.instruct(function_prompt, instruction_config) do
      {:ok, response} ->
        function_calls = extract_function_calls(response)
        Logger.debug("✅ Function call generation successful: #{length(function_calls)} calls")
        {:ok, function_calls}
        
      {:error, reason} ->
        Logger.error("❌ Function call generation failed: #{inspect(reason)}")
        {:error, format_error(reason)}
    end
  rescue
    error ->
      Logger.error("💥 Function call generation crashed: #{inspect(error)}")
      {:error, "Function call generation crashed: #{Exception.message(error)}"}
  end

  # Private helper functions

  defp build_instruction_config(options) do
    model = options["model"] || options[:model] || "gemini-2.5-flash-lite-preview-06-17"
    token_budget = options["token_budget"] || options[:token_budget] || %{}
    
    base_config = %{
      adapter: :gemini,
      model: model,
      api_key: get_api_key(),
      stream: false
    }
    
    # Add token budget parameters if specified
    config_with_budget = case token_budget do
      %{} when map_size(token_budget) == 0 -> base_config
      budget ->
        base_config
        |> maybe_add_param(:max_output_tokens, budget["max_output_tokens"] || budget[:max_output_tokens])
        |> maybe_add_param(:temperature, budget["temperature"] || budget[:temperature])
        |> maybe_add_param(:top_p, budget["top_p"] || budget[:top_p])
        |> maybe_add_param(:top_k, budget["top_k"] || budget[:top_k])
    end
    
    config_with_budget
  end

  defp build_function_calling_config(options) do
    base_config = build_instruction_config(options)
    
    # Add schema for function calling response
    function_call_schema = %{
      type: "array",
      items: %{
        type: "object",
        properties: %{
          name: %{type: "string"},
          arguments: %{type: "object"}
        },
        required: ["name", "arguments"]
      }
    }
    
    Map.put(base_config, :response_schema, function_call_schema)
  end

  defp build_function_calling_prompt(prompt, tools) do
    tool_descriptions = Enum.map(tools, &describe_tool/1)
    
    """
    #{prompt}

    Available tools:
    #{Enum.join(tool_descriptions, "\n")}

    Generate function calls as needed to accomplish the task. Return a JSON array of function calls.
    Each function call should have a "name" and "arguments" field.
    """
  end

  defp describe_tool(tool_name) do
    case tool_name do
      "file_creator" ->
        "- file_creator: Create or write files. Arguments: {filename: string, content: string}"
      "code_analyzer" ->
        "- code_analyzer: Analyze code quality and structure. Arguments: {file_path: string, analysis_type: string}"
      "test_runner" ->
        "- test_runner: Run tests and return results. Arguments: {test_file: string, verbose: boolean}"
      _ ->
        "- #{tool_name}: Custom tool (see documentation for usage)"
    end
  end

  defp maybe_add_param(config, _key, nil), do: config
  defp maybe_add_param(config, key, value), do: Map.put(config, key, value)

  defp format_gemini_response(response) do
    %{
      content: extract_content(response),
      success: true,
      cost: extract_cost(response),
      function_calls: extract_function_calls(response)
    }
  end

  defp extract_content(response) do
    cond do
      is_binary(response) -> response
      is_map(response) and Map.has_key?(response, :content) -> response.content
      is_map(response) and Map.has_key?(response, "content") -> response["content"]
      is_map(response) and Map.has_key?(response, :text) -> response.text
      is_map(response) and Map.has_key?(response, "text") -> response["text"]
      true -> Jason.encode!(response, pretty: true)
    end
  end

  defp extract_cost(response) do
    cond do
      is_map(response) and Map.has_key?(response, :usage) ->
        calculate_cost_from_usage(response.usage)
      is_map(response) and Map.has_key?(response, "usage") ->
        calculate_cost_from_usage(response["usage"])
      true -> 0.0
    end
  end

  defp extract_function_calls(response) do
    cond do
      is_list(response) -> response
      is_map(response) and Map.has_key?(response, :function_calls) -> response.function_calls || []
      is_map(response) and Map.has_key?(response, "function_calls") -> response["function_calls"] || []
      true -> []
    end
  end

  defp calculate_cost_from_usage(usage) do
    # Simplified cost calculation - in production, use actual Gemini pricing
    input_tokens = usage["input_tokens"] || usage[:input_tokens] || 0
    output_tokens = usage["output_tokens"] || usage[:output_tokens] || 0
    
    # Approximate Gemini pricing (update with actual rates)
    input_cost = input_tokens * 0.000001  # $1 per 1M input tokens
    output_cost = output_tokens * 0.000002  # $2 per 1M output tokens
    
    input_cost + output_cost
  end

  defp format_error(reason) do
    case reason do
      %{message: message} -> message
      reason when is_binary(reason) -> reason
      reason -> inspect(reason)
    end
  end

  defp get_api_key do
    System.get_env("GEMINI_API_KEY") || 
    Application.get_env(:pipeline, :gemini_api_key) ||
    raise "GEMINI_API_KEY environment variable not set"
  end
end