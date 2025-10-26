defmodule Pipeline.Providers.GeminiProvider do
  @moduledoc """
  Live Gemini provider backed by the `gemini_ex` client.
  """

  require Logger

  alias Gemini.Error
  alias Gemini.Types.Response.GenerateContentResponse, as: GeminiResponse

  @default_model "gemini-flash-lite-latest"

  @doc """
  Query Gemini and return a structured response map.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug("🧠 Querying Gemini with prompt: #{String.slice(prompt, 0, 100)}…")

    request_opts = build_request_opts(options)

    case Gemini.generate(prompt, request_opts) do
      {:ok, response} ->
        case format_gemini_response(response, options) do
          {:ok, formatted} ->
            Logger.debug("✅ Gemini query successful")
            {:ok, formatted}

          {:error, reason} ->
            {:error, reason}
        end

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
  Ask Gemini to emit function calls described in `tools`.

  The model is instructed to respond with a JSON array of function call objects.
  """
  def generate_function_calls(prompt, tools, options \\ %{}) do
    Logger.debug("🔧 Generating function calls for tools: #{inspect(tools)}")

    request_prompt = build_function_calling_prompt(prompt, tools)

    request_opts =
      build_request_opts(options)
      |> Keyword.put(:response_mime_type, "application/json")
      |> Keyword.put_new(:temperature, 0.0)

    case Gemini.generate(request_prompt, request_opts) do
      {:ok, response} ->
        with {:ok, json_text} <- Gemini.extract_text(response),
             {:ok, function_calls} <- decode_function_calls(json_text) do
          Logger.debug("✅ Function call generation produced #{length(function_calls)} call(s)")
          {:ok, function_calls}
        else
          {:error, reason} ->
            Logger.error("❌ Failed to decode function calls: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("❌ Function call generation failed: #{inspect(reason)}")
        {:error, format_error(reason)}
    end
  rescue
    error ->
      Logger.error("💥 Function call generation crashed: #{inspect(error)}")
      {:error, "Function call generation crashed: #{Exception.message(error)}"}
  end

  # Request option helpers ---------------------------------------------------

  defp build_request_opts(options) do
    model = get_model_from_options(options)

    [
      model: model,
      api_key: get_api_key(),
      system_instruction: get_system_instruction(options)
    ]
    |> Keyword.merge(build_generation_opts(options))
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp get_model_from_options(options) do
    options["model"] || options[:model] || @default_model
  end

  defp get_system_instruction(options) do
    options["system_instruction"] || options[:system_instruction]
  end

  defp build_generation_opts(options) do
    token_budget = get_token_budget_from_options(options)

    [
      temperature: fetch_number(token_budget, "temperature"),
      max_output_tokens: fetch_integer(token_budget, "max_output_tokens"),
      top_p: fetch_number(token_budget, "top_p"),
      top_k: fetch_integer(token_budget, "top_k"),
      response_mime_type: options["response_mime_type"] || options[:response_mime_type],
      stop_sequences: options["stop_sequences"] || options[:stop_sequences],
      candidate_count: fetch_integer(options, "candidate_count"),
      presence_penalty: fetch_number(options, "presence_penalty"),
      frequency_penalty: fetch_number(options, "frequency_penalty")
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp get_token_budget_from_options(options) do
    options["token_budget"] || options[:token_budget] || %{}
  end

  defp fetch_number(source, key) do
    value = fetch_option(source, key)

    cond do
      is_number(value) ->
        value

      is_binary(value) ->
        case Float.parse(value) do
          {parsed, _} -> parsed
          :error -> nil
        end

      true ->
        nil
    end
  end

  defp fetch_integer(source, key) do
    value = fetch_option(source, key)

    cond do
      is_integer(value) ->
        value

      is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _} -> parsed
          :error -> nil
        end

      true ->
        nil
    end
  end

  defp fetch_option(source, key) when is_map(source) do
    source[key] || source[String.to_atom(to_string(key))]
  rescue
    ArgumentError -> source[key]
  end

  defp fetch_option(_source, _key), do: nil

  defp get_api_key do
    System.get_env("GEMINI_API_KEY") ||
      Application.get_env(:pipeline, :gemini_api_key) ||
      raise "GEMINI_API_KEY environment variable not set"
  end

  # Response helpers ---------------------------------------------------------

  defp format_gemini_response(response, options) do
    with {:ok, text} <- Gemini.extract_text(response) do
      usage = GeminiResponse.token_usage(response) || %{}

      {:ok,
       %{
         text: text,
         success: true,
         cost: estimate_cost(usage),
         tokens: usage,
         model: get_model_from_options(options)
       }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp estimate_cost(%{input: input_tokens, output: output_tokens}) do
    input = input_tokens || 0
    output = output_tokens || 0

    # Approximate public pricing (update as needed)
    input * 0.000001 + output * 0.000002
  end

  defp estimate_cost(_), do: 0.0

  defp format_error(%Error{message: message, type: type, http_status: status}) do
    base = "[#{type}] #{message}"
    if status, do: "#{base} (HTTP #{status})", else: base
  end

  defp format_error(other), do: inspect(other)

  # Function calling helpers -------------------------------------------------

  defp build_function_calling_prompt(prompt, tools) do
    tool_descriptions =
      tools
      |> List.wrap()
      |> Enum.map(&describe_tool/1)
      |> Enum.join("\n")

    """
    #{prompt}

    Available tools:
    #{tool_descriptions}

    Respond with a JSON array of function call objects. Each object must include:
      - "name": the function to invoke
      - "arguments": an object containing the arguments for the function
    Do not include any additional text outside the JSON array.
    """
  end

  defp describe_tool(%{"name" => name} = tool) do
    description = Map.get(tool, "description") || "No description provided"
    parameters = Map.get(tool, "parameters") || %{}
    "- #{name}: #{description} — Parameters: #{Jason.encode!(parameters)}"
  end

  defp describe_tool(%{name: name} = tool) do
    description = Map.get(tool, :description) || "No description provided"
    parameters = Map.get(tool, :parameters) || %{}
    "- #{name}: #{description} — Parameters: #{Jason.encode!(parameters)}"
  end

  defp describe_tool(name) when is_binary(name),
    do: "- #{name}: Refer to documentation for arguments"

  defp describe_tool(other), do: "- #{inspect(other)}"

  defp decode_function_calls(json_text) when is_binary(json_text) do
    cleaned =
      json_text
      |> String.trim()
      |> strip_code_fence()

    case Jason.decode(cleaned) do
      {:ok, %{"function_calls" => calls}} when is_list(calls) ->
        {:ok, calls}

      {:ok, list} when is_list(list) ->
        {:ok, list}

      {:ok, other} ->
        {:error, "Expected JSON array of function calls, got: #{inspect(other)}"}

      {:error, reason} ->
        {:error, "Failed to decode function calls JSON: #{inspect(reason)}"}
    end
  end

  defp decode_function_calls(_other), do: {:error, "Gemini response did not contain JSON output"}

  defp strip_code_fence("```json" <> rest), do: rest |> strip_trailing_fence()
  defp strip_code_fence("```" <> rest), do: rest |> strip_trailing_fence()
  defp strip_code_fence(text), do: text

  defp strip_trailing_fence(text) do
    text
    |> String.trim()
    |> String.replace(~r/```$/, "")
    |> String.trim()
  end
end
