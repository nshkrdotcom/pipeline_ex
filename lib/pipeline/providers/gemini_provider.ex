defmodule Pipeline.Providers.GeminiProvider do
  @moduledoc """
  Live Gemini provider using InstructorLite for structured generation.
  """

  require Logger

  # Simple response schema for text responses
  defmodule TextResponse do
    @moduledoc """
    Simple response schema for Gemini text responses.
    """
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:content, :string)
    end

    @behaviour Access

    def fetch(struct, key) do
      case key do
        :content -> {:ok, struct.content}
        "content" -> {:ok, struct.content}
        _ -> :error
      end
    end

    def get_and_update(struct, key, function) do
      case key do
        :content ->
          {current, new} = function.(struct.content)
          {current, %{struct | content: new}}

        "content" ->
          {current, new} = function.(struct.content)
          {current, %{struct | content: new}}

        _ ->
          {nil, struct}
      end
    end

    def pop(struct, key) do
      case key do
        :content -> {struct.content, %{struct | content: nil}}
        "content" -> {struct.content, %{struct | content: nil}}
        _ -> {nil, struct}
      end
    end
  end

  @doc """
  Query Gemini using InstructorLite for structured responses.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug("🧠 Querying Gemini with prompt: #{String.slice(prompt, 0, 100)}...")

    # Build instruction configuration
    instruction_config = build_instruction_config(options)

    # Format prompt for Gemini adapter - it expects a structured format
    formatted_prompt = %{
      contents: [
        %{
          role: "user",
          parts: [%{text: prompt}]
        }
      ]
    }

    # Execute the instruction
    case InstructorLite.instruct(formatted_prompt, instruction_config) do
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

    case InstructorLite.instruct(%{prompt: function_prompt}, instruction_config) do
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
    model = get_model_from_options(options)
    token_budget = get_token_budget_from_options(options)
    timeout_ms = get_timeout_from_options(options)

    base_config = build_base_config(model, timeout_ms)
    generation_config = build_generation_config(token_budget)

    apply_generation_config(base_config, generation_config)
  end

  defp get_model_from_options(options) do
    options["model"] || options[:model] || "gemini-2.5-flash-lite-preview-06-17"
  end

  defp get_token_budget_from_options(options) do
    options["token_budget"] || options[:token_budget] || %{}
  end

  defp get_timeout_from_options(options) do
    timeout_ms =
      options["timeout_ms"] ||
        options[:timeout_ms] ||
        Application.get_env(:pipeline, :gemini_timeout_ms, 300_000)

    Logger.info("🕒 DEBUG: GeminiProvider received timeout_ms: #{timeout_ms}")
    timeout_ms
  end

  defp build_base_config(model, timeout_ms) do
    Logger.info("🕒 DEBUG: Adding http_options with receive_timeout: #{timeout_ms}")

    adapter_context = [
      model: model,
      api_key: get_api_key(),
      http_options: [receive_timeout: timeout_ms]
    ]

    json_schema = %{
      type: "object",
      required: ["content"],
      properties: %{content: %{type: "string", description: "The response content"}}
    }

    [
      adapter: InstructorLite.Adapters.Gemini,
      adapter_context: adapter_context,
      response_model: Pipeline.Providers.GeminiProvider.TextResponse,
      json_schema: json_schema
    ]
  end

  defp build_generation_config(token_budget) do
    %{
      "temperature" => token_budget["temperature"] || token_budget[:temperature],
      "maxOutputTokens" => token_budget["max_output_tokens"] || token_budget[:max_output_tokens],
      "topP" => token_budget["top_p"] || token_budget[:top_p],
      "topK" => token_budget["top_k"] || token_budget[:top_k]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp apply_generation_config(base_config, generation_config) do
    if map_size(generation_config) > 0 do
      Keyword.put(base_config, :extra, %{generation_config: generation_config})
    else
      base_config
    end
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

  defp format_gemini_response(response) do
    %{
      content: extract_content(response),
      success: true,
      cost: extract_cost(response),
      function_calls: extract_function_calls(response)
    }
  end

  defp extract_content(%Pipeline.Providers.GeminiProvider.TextResponse{content: content}),
    do: content

  defp extract_content(response) when is_binary(response), do: response
  defp extract_content(response) when is_map(response), do: extract_content_from_map(response)
  defp extract_content(response), do: Jason.encode!(response, pretty: true)

  defp extract_content_from_map(response) when is_map(response) do
    response[:content] || response["content"] || response[:text] || response["text"] ||
      Jason.encode!(response, pretty: true)
  end

  defp extract_cost(response) when is_map(response), do: extract_cost_from_map(response)
  defp extract_cost(_response), do: 0.0

  defp extract_cost_from_map(response) when is_map(response) do
    case response[:usage] || response["usage"] do
      nil -> 0.0
      usage -> calculate_cost_from_usage(usage)
    end
  end

  defp extract_function_calls(response) when is_list(response), do: response

  defp extract_function_calls(response) when is_map(response),
    do: extract_function_calls_from_map(response)

  defp extract_function_calls(_response), do: []

  defp extract_function_calls_from_map(response) when is_map(response) do
    response[:function_calls] || response["function_calls"] || []
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
