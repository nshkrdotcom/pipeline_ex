defmodule Pipeline.Providers.ClaudeProvider do
  @moduledoc """
  Live Claude provider built on top of `ClaudeAgentSDK`.
  """

  require Logger

  @doc """
  Execute a prompt against Claude using the SDK integration.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug("💪 Querying Claude with prompt: #{String.slice(prompt, 0, 100)}…")

    try do
      claude_options = build_claude_options(options)

      case execute_claude_sdk(prompt, claude_options, options) do
        {:ok, response} ->
          Logger.debug("✅ Claude query successful")
          {:ok, response}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("💥 Claude query crashed: #{inspect(error)}")
        {:error, "Claude query crashed: #{Exception.message(error)}"}
    end
  end

  # Internal helpers ---------------------------------------------------------

  defp build_claude_options(options) do
    %{
      max_turns:
        get_option_value(
          options,
          "max_turns",
          :max_turns,
          Application.get_env(:pipeline, :max_turns_default, 3)
        ),
      allowed_tools: get_option_value(options, "allowed_tools", :allowed_tools, []),
      disallowed_tools: get_option_value(options, "disallowed_tools", :disallowed_tools, []),
      system_prompt: get_option_value(options, "system_prompt", :system_prompt, nil),
      append_system_prompt:
        get_option_value(options, "append_system_prompt", :append_system_prompt, nil),
      verbose: get_option_value(options, "verbose", :verbose, nil),
      cwd: get_option_value(options, "cwd", :cwd, "./workspace"),
      model: get_option_value(options, "model", :model, nil),
      fallback_model: get_option_value(options, "fallback_model", :fallback_model, nil),
      output_format: normalize_output_format(options)
    }
  end

  defp get_option_value(options, string_key, atom_key, default) do
    cond do
      Map.has_key?(options, string_key) -> options[string_key]
      Map.has_key?(options, atom_key) -> options[atom_key]
      true -> default
    end
  end

  defp normalize_output_format(options) do
    format = options["output_format"] || options[:output_format]

    case format do
      nil -> nil
      "text" -> :text
      "json" -> :json
      "stream_json" -> :stream_json
      "stream-json" -> :stream_json
      atom when is_atom(atom) -> atom
      other -> other |> to_string() |> String.to_atom()
    end
  end

  defp execute_claude_sdk(prompt, claude_options, original_options) do
    case Pipeline.TestMode.get_mode() do
      :mock ->
        provider = Pipeline.TestMode.provider_for(:ai)
        provider.query(prompt, original_options)

      _live_or_mixed ->
        execute_live_claude_query(prompt, claude_options)
    end
  end

  defp execute_live_claude_query(prompt, options) do
    sdk_options = build_sdk_options(options)
    log_debug_info(prompt, sdk_options)

    messages = collect_claude_messages(prompt, sdk_options)
    process_claude_messages(messages)
  rescue
    error ->
      Logger.error("ClaudeAgentSDK error: #{inspect(error)}")
      {:error, Exception.message(error)}
  end

  defp build_sdk_options(options) do
    verbose =
      case Map.fetch(options, :verbose) do
        {:ok, value} -> value
        :error -> true
      end

    [
      max_turns: options[:max_turns] || Application.get_env(:pipeline, :max_turns_sdk_default, 1),
      verbose: verbose,
      allowed_tools: options[:allowed_tools],
      disallowed_tools: options[:disallowed_tools],
      system_prompt: options[:system_prompt],
      append_system_prompt: options[:append_system_prompt],
      output_format: options[:output_format],
      cwd: options[:cwd],
      model: options[:model],
      fallback_model: options[:fallback_model]
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> ClaudeAgentSDK.Options.new()
  end

  defp log_debug_info(prompt, sdk_options) do
    Logger.debug("🚀 Starting Claude SDK query (prompt length: #{String.length(prompt)})")
    Logger.debug("🔧 SDK options: #{inspect(sdk_options)}")
  end

  defp collect_claude_messages(prompt, sdk_options) do
    Logger.debug("📥 Collecting messages from Claude SDK stream…")

    stream = ClaudeAgentSDK.query(prompt, sdk_options)

    messages =
      try do
        Enum.to_list(stream)
      rescue
        error ->
          Logger.error("💥 Failed to collect Claude SDK stream: #{inspect(error)}")
          reraise error, __STACKTRACE__
      end

    Logger.debug("📋 Collected #{length(messages)} messages from Claude SDK")
    messages
  end

  defp process_claude_messages([]) do
    Logger.error("❌ No messages received from Claude SDK")
    {:error, "No response from Claude SDK"}
  end

  defp process_claude_messages(messages) do
    log_message_debug_info(messages)

    try do
      text_content = extract_text_from_messages(messages)
      format_claude_response(text_content, messages)
    catch
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp log_message_debug_info(messages) do
    Logger.debug("ClaudeAgentSDK messages: #{inspect(messages, limit: :infinity)}")

    message_types =
      Enum.map(messages, fn msg -> "#{msg.type}:#{msg.subtype || "nil"}" end)
      |> Enum.join(", ")

    Logger.debug("📋 Message types: #{message_types}")
  end

  defp format_claude_response("", _messages) do
    Logger.warning("⚠️ Extracted empty text from Claude response")
    {:error, "Empty response from Claude"}
  end

  defp format_claude_response(text_content, messages) when is_binary(text_content) do
    case String.trim(text_content) do
      "" ->
        Logger.warning("⚠️ Extracted empty text from Claude response")
        {:error, "Empty response from Claude"}

      _ ->
        Logger.debug("✅ Successfully extracted Claude response")

        {:ok,
         %{
           text: text_content,
           success: true,
           cost: calculate_cost(messages),
           model: extract_model(messages)
         }}
    end
  end

  defp extract_text_from_messages(messages) do
    Logger.debug("📋 Extracting text from #{length(messages)} Claude SDK messages")

    result_msg = Enum.find(messages, fn msg -> msg.type == :result end)

    validate_result_message(result_msg, messages)
    extract_assistant_messages_text(messages)
  end

  defp validate_result_message(nil, messages) do
    assistant_messages = Enum.filter(messages, &(&1.type == :assistant))

    if assistant_messages != [] and has_meaningful_content?(assistant_messages) do
      Logger.debug(
        "✅ Claude SDK conversation completed with assistant messages (no explicit result)"
      )
    else
      Logger.error("❌ No result message received from Claude SDK")
      throw({:error, "Claude SDK response missing result message"})
    end
  end

  defp validate_result_message(%{subtype: :success}, messages) do
    Logger.debug("✅ Claude SDK result message indicates success (#{length(messages)} messages)")
  end

  defp validate_result_message(%{subtype: other}, _messages) do
    Logger.error("❌ Claude SDK result message indicates failure: #{inspect(other)}")
    throw({:error, "Claude SDK reported failure: #{inspect(other)}"})
  end

  defp has_meaningful_content?(assistant_messages) do
    assistant_messages
    |> Enum.map(&extract_message_content/1)
    |> Enum.any?(fn content -> String.trim(content) != "" end)
  end

  defp extract_assistant_messages_text(messages) do
    messages
    |> Enum.filter(&(&1.type == :assistant))
    |> Enum.map(&extract_message_content/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # Extract from ClaudeAgentSDK.Message struct with data.message.content
  defp extract_message_content(%{data: %{message: message}}) when is_map(message) do
    content = message["content"] || message[:content]
    extract_content_text(content)
  end

  # Legacy pattern for atom-keyed messages
  defp extract_message_content(%{message: %{content: content}}) do
    extract_content_text(content)
  end

  defp extract_message_content(_other), do: ""

  # Extract text from content (handles string, list, or map)
  defp extract_content_text(content) when is_binary(content), do: content

  defp extract_content_text(content) when is_list(content) do
    content
    |> Enum.map(fn part ->
      cond do
        is_binary(part) -> part
        is_map(part) and Map.has_key?(part, "text") -> part["text"]
        is_map(part) and Map.has_key?(part, :text) -> part[:text]
        true -> inspect(part)
      end
    end)
    |> Enum.join("\n")
  end

  defp extract_content_text(content) when is_map(content) do
    cond do
      Map.has_key?(content, "text") -> content["text"]
      Map.has_key?(content, :text) -> content[:text]
      true -> inspect(content)
    end
  end

  defp extract_content_text(_other), do: ""

  defp calculate_cost(messages) do
    result_msg = Enum.find(messages, fn msg -> msg.type == :result end)

    case result_msg do
      %{data: %{total_cost_usd: cost}} -> cost
      %{total_cost_usd: cost} -> cost
      %{data: %{cost: cost}} -> cost
      %{cost: cost} -> cost
      _ -> 0
    end
  end

  defp extract_model(messages) do
    # Try to find model from assistant message
    assistant_msg = Enum.find(messages, fn msg -> msg.type == :assistant end)

    case assistant_msg do
      %{data: %{message: %{"model" => model}}} when is_binary(model) ->
        model

      _ ->
        # Try to find from system init message
        system_msg = Enum.find(messages, fn msg -> msg.type == :system end)

        case system_msg do
          %{data: %{model: model}} when is_binary(model) -> model
          _ -> nil
        end
    end
  end
end
