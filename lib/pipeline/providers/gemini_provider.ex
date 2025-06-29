defmodule Pipeline.Providers.GeminiProvider do
  @moduledoc """
  Live Gemini provider using InstructorLite for structured generation.
  """

  use Ecto.Schema
  require Logger

  # Simple response schema for text responses
  defmodule TextResponse do
    use Ecto.Schema

    @derive Jason.Encoder
    @primary_key false
    embedded_schema do
      field(:content, :string)
    end
  end

  @doc """
  Query Gemini using InstructorLite for structured responses.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug("🧠 Querying Gemini with prompt: #{String.slice(prompt, 0, 100)}...")
    IO.puts("DEBUG: GeminiProvider.query called with prompt length: #{String.length(prompt)}")
    IO.puts("DEBUG: Options: #{inspect(options)}")

    # Build instruction configuration
    instruction_config = build_instruction_config(options)
    IO.puts("DEBUG: Built instruction_config: #{inspect(instruction_config)}")

    # Format prompt for Gemini adapter - it expects a structured format
    formatted_prompt = %{
      contents: [
        %{
          role: "user",
          parts: [%{text: prompt}]
        }
      ]
    }

    IO.puts("DEBUG: Formatted prompt: #{inspect(formatted_prompt)}")

    # Execute the instruction
    IO.puts("DEBUG: About to call InstructorLite.instruct")

    case InstructorLite.instruct(formatted_prompt, instruction_config) do
      {:ok, response} ->
        IO.puts("DEBUG: InstructorLite.instruct returned success: #{inspect(response)}")
        formatted_response = format_gemini_response(response)
        IO.puts("DEBUG: Formatted response: #{inspect(formatted_response)}")
        Logger.debug("✅ Gemini query successful")
        {:ok, formatted_response}

      {:error, reason} ->
        IO.puts("DEBUG: InstructorLite.instruct returned error: #{inspect(reason)}")
        Logger.error("❌ Gemini query failed: #{inspect(reason)}")
        {:error, format_error(reason)}
    end
  rescue
    error ->
      IO.puts("DEBUG: Exception in GeminiProvider.query: #{inspect(error)}")
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

    # InstructorLite adapter context for Gemini - only include supported parameters
    adapter_context = [
      model: model,
      api_key: get_api_key()
    ]

    # Create JSON schema for Gemini adapter
    json_schema = %{
      type: "object",
      required: ["content"],
      properties: %{
        content: %{type: "string", description: "The response content"}
      }
    }

    base_config = [
      adapter: InstructorLite.Adapters.Gemini,
      adapter_context: adapter_context,
      response_model: Pipeline.Providers.GeminiProvider.TextResponse,
      json_schema: json_schema
    ]

    # Add token budget parameters to adapter context if specified
    # Note: Gemini adapter may not support all these parameters, but we'll let it validate
    config_with_budget =
      case token_budget do
        %{} when map_size(token_budget) == 0 ->
          base_config

        budget ->
          updated_adapter_context =
            adapter_context
            |> add_if_present(
              :max_output_tokens,
              budget["max_output_tokens"] || budget[:max_output_tokens]
            )
            |> add_if_present(:temperature, budget["temperature"] || budget[:temperature])
            |> add_if_present(:top_p, budget["top_p"] || budget[:top_p])
            |> add_if_present(:top_k, budget["top_k"] || budget[:top_k])

          Keyword.put(base_config, :adapter_context, updated_adapter_context)
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

    Keyword.put(base_config, :response_schema, function_call_schema)
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

  defp add_if_present(list, _key, nil), do: list
  defp add_if_present(list, key, value), do: Keyword.put(list, key, value)

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
      is_struct(response, Pipeline.Providers.GeminiProvider.TextResponse) -> response.content
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

      true ->
        0.0
    end
  end

  defp extract_function_calls(response) do
    cond do
      is_list(response) ->
        response

      is_map(response) and Map.has_key?(response, :function_calls) ->
        response.function_calls || []

      is_map(response) and Map.has_key?(response, "function_calls") ->
        response["function_calls"] || []

      true ->
        []
    end
  end

  defp calculate_cost_from_usage(usage) do
    # Simplified cost calculation - in production, use actual Gemini pricing
    input_tokens = usage["input_tokens"] || usage[:input_tokens] || 0
    output_tokens = usage["output_tokens"] || usage[:output_tokens] || 0

    # Approximate Gemini pricing (update with actual rates)
    # $1 per 1M input tokens
    input_cost = input_tokens * 0.000001
    # $2 per 1M output tokens
    output_cost = output_tokens * 0.000002

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
