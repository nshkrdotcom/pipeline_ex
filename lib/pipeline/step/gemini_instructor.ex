defmodule Pipeline.Step.GeminiInstructor do
  @moduledoc """
  Executes Gemini (Brain) steps using InstructorLite for structured output and function calling.
  """

  alias Pipeline.PromptBuilder
  alias Pipeline.Tools.Adapters.InstructorLiteAdapter
  require Logger

  def execute(step, context) do
    log_execution_start(step)

    prompt = PromptBuilder.build(step["prompt"], context.results)
    log_prompt_preview(prompt)

    model = step["model"] || "gemini-2.5-flash"
    start_time = System.monotonic_time(:millisecond)
    Logger.info("🚀 Debug: Starting LLM call to Gemini NOW at #{DateTime.utc_now()}")

    result = execute_gemini_call(step, prompt, model, start_time)
    save_output_if_needed(step, context, result)

    {:ok, result}
  end

  defp log_execution_start(step) do
    Logger.info("🧠 Gemini Brain analyzing: #{step["name"] || "task"}")
    Logger.info("🔍 Debug: LLM call type: SYNCHRONOUS (blocking)")
  end

  defp log_prompt_preview(prompt) do
    prompt_preview =
      if String.length(prompt) > 200, do: String.slice(prompt, 0, 200) <> "...", else: prompt

    Logger.info("📝 Prompt preview: #{prompt_preview}")
  end

  defp execute_gemini_call(step, prompt, model, start_time) do
    case step["functions"] do
      nil ->
        execute_regular_generation(prompt, model, start_time)

      functions when is_list(functions) ->
        execute_function_calling(prompt, functions, model, start_time)
    end
  end

  defp execute_regular_generation(prompt, model, start_time) do
    case call_instructor_lite(prompt, Pipeline.Schemas.AnalysisResponse, model) do
      {:ok, response} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        Logger.info("📤 Raw Gemini response (took #{elapsed / 1000}s):")
        Logger.info("  Response received")
        response

      {:error, error} ->
        Logger.error("❌ Gemini call failed: #{inspect(error)}")
        raise "Gemini call failed: #{inspect(error)}"
    end
  end

  defp execute_function_calling(prompt, functions, model, start_time) do
    Logger.info("🔧 Function calling enabled with #{length(functions)} tools")

    tool_schema = InstructorLiteAdapter.create_function_schema(functions)

    case call_instructor_lite_with_tools(prompt, tool_schema, model) do
      {:ok, response} -> handle_tool_response(response, start_time)
      {:error, error} -> handle_tool_error(error)
    end
  end

  defp save_output_if_needed(step, context, result) do
    if step["output_to_file"] do
      save_output(context.output_dir, step["output_to_file"], result)
    end
  end

  defp call_instructor_lite(prompt, response_model, model) do
    # Get API key from environment
    api_key =
      System.get_env("GEMINI_API_KEY") ||
        Application.get_env(:pipeline, :gemini_api_key) ||
        raise "GEMINI_API_KEY environment variable not set"

    # Format the prompt for Gemini's content structure
    contents = [
      %{
        role: "user",
        parts: [%{text: prompt}]
      }
    ]

    params = %{
      contents: contents
    }

    # Add generation config for better control
    generation_config = %{
      temperature: 0.7,
      maxOutputTokens: 2048
    }

    params = Map.put(params, :generationConfig, generation_config)

    # Create a simple Gemini-compatible schema
    simple_schema = %{
      type: "object",
      properties: %{
        text: %{type: "string", description: "The response text"},
        analysis: %{type: "string", description: "Analysis or reasoning"},
        summary: %{type: "string", description: "Brief summary"}
      },
      required: ["text"]
    }

    # Call InstructorLite with Gemini adapter using custom schema
    case InstructorLite.instruct(
           params,
           response_model: response_model,
           json_schema: simple_schema,
           adapter: InstructorLite.Adapters.Gemini,
           adapter_context: [
             model: model,
             api_key: api_key
           ]
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp call_instructor_lite_with_tools(prompt, schema, model) do
    # Get API key from environment
    api_key =
      System.get_env("GEMINI_API_KEY") ||
        Application.get_env(:pipeline, :gemini_api_key) ||
        raise "GEMINI_API_KEY environment variable not set"

    # Format the prompt for Gemini's content structure
    contents = [
      %{
        role: "user",
        parts: [%{text: prompt}]
      }
    ]

    params = %{
      contents: contents
    }

    # Add generation config for better control
    generation_config = %{
      # Lower temperature for function calling
      temperature: 0.3,
      maxOutputTokens: 2048
    }

    params = Map.put(params, :generationConfig, generation_config)

    # Create a simple response model for tool calling
    response_model = %{text: :string, reasoning: :string}

    # Call InstructorLite with Gemini adapter using custom schema
    case InstructorLite.instruct(
           params,
           response_model: response_model,
           json_schema: schema,
           adapter: InstructorLite.Adapters.Gemini,
           adapter_context: [
             model: model,
             api_key: api_key
           ]
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_output(output_dir, filename, data) do
    filepath = Path.join(output_dir, filename)
    File.mkdir_p!(Path.dirname(filepath))

    content =
      if is_binary(data) do
        data
      else
        Jason.encode!(data, pretty: true)
      end

    File.write!(filepath, content)
    Logger.info("📁 Saved output to: #{filepath}")
  end

  defp handle_tool_response(response, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    Logger.info("📤 Raw Gemini response with tool calls (took #{elapsed / 1000}s):")
    Logger.info("  Tool calling completed")

    case InstructorLiteAdapter.execute_function_calls(response) do
      {:ok, enhanced_response} -> enhanced_response
    end
  end

  @spec handle_tool_error(any()) :: no_return()
  defp handle_tool_error(error) do
    Logger.error("❌ Gemini tool calling failed: #{inspect(error)}")
    raise "Gemini tool calling failed: #{inspect(error)}"
  end
end
