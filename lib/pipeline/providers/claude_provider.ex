defmodule Pipeline.Providers.ClaudeProvider do
  @moduledoc """
  Live Claude provider using the existing Claude SDK integration.

  Supports both synchronous and asynchronous streaming modes.
  """

  require Logger
  alias Pipeline.Streaming.AsyncResponse

  @doc """
  Query Claude using the existing Claude SDK integration.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug("💪 Querying Claude with prompt: #{String.slice(prompt, 0, 100)}...")
    IO.puts("DEBUG: ClaudeProvider.query called with prompt length: #{String.length(prompt)}")
    IO.puts("DEBUG: Options: #{inspect(options)}")

    # For now, delegate to the existing Claude step implementation
    # This maintains compatibility with the working Claude SDK integration

    try do
      # Build Claude options from the provider options
      claude_options = build_claude_options(options)
      IO.puts("DEBUG: Built claude_options: #{inspect(claude_options)}")

      # Use the existing Claude SDK via the step module
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

  # Private helper functions

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
      verbose: get_option_value(options, "verbose", :verbose, false),
      cwd: get_option_value(options, "cwd", :cwd, "./workspace"),
      timeout_ms: get_option_value(options, "timeout_ms", :timeout_ms, get_default_timeout_ms()),
      async_streaming: get_option_value(options, "async_streaming", :async_streaming, false),
      model: get_option_value(options, "model", :model, nil),
      fallback_model: get_option_value(options, "fallback_model", :fallback_model, nil)
    }
  end

  defp get_option_value(options, string_key, atom_key, default) do
    options[string_key] || options[atom_key] || default
  end

  defp get_default_timeout_ms do
    Application.get_env(:pipeline, :timeout_seconds, 300) * 1000
  end

  defp execute_claude_sdk(prompt, claude_options, original_options) do
    # Use the actual Claude Code SDK for live API calls
    case Pipeline.TestMode.get_mode() do
      :mock ->
        # Use the mock provider to support async streaming
        provider = Pipeline.TestMode.provider_for(:ai)
        provider.query(prompt, original_options)

      _live_or_mixed ->
        execute_live_claude_query(prompt, claude_options)
    end
  end

  defp execute_live_claude_query(prompt, options) do
    sdk_options = build_sdk_options(options)
    log_debug_info(prompt, sdk_options)

    if options[:async_streaming] do
      execute_async_query(prompt, sdk_options, options)
    else
      messages = collect_claude_messages(prompt, sdk_options)
      process_claude_messages(messages)
    end
  rescue
    error ->
      Logger.error("ClaudeCodeSDK error: #{inspect(error)}")
      {:error, Exception.message(error)}
  end

  defp build_sdk_options(options) do
    ClaudeCodeSDK.Options.new(
      max_turns: options[:max_turns] || Application.get_env(:pipeline, :max_turns_sdk_default, 1),
      verbose: options[:verbose] || true,
      allowed_tools: options[:allowed_tools],
      disallowed_tools: options[:disallowed_tools],
      system_prompt: options[:system_prompt],
      cwd: options[:cwd],
      timeout_ms: options[:timeout_ms] || get_default_timeout_ms(),
      async: options[:async_streaming] || false,
      model: options[:model],
      fallback_model: options[:fallback_model]
    )
  end

  defp log_debug_info(prompt, sdk_options) do
    IO.puts("DEBUG: Calling ClaudeCodeSDK.query with prompt length: #{String.length(prompt)}")
    IO.puts("DEBUG: SDK options: #{inspect(sdk_options)}")
    Logger.debug("🚀 Starting Claude SDK query...")
  end

  defp collect_claude_messages(prompt, sdk_options) do
    Logger.debug("📥 Collecting messages from Claude SDK stream...")
    stream = ClaudeCodeSDK.query(prompt, sdk_options)

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
    Logger.debug("ClaudeCodeSDK messages: #{inspect(messages, limit: :infinity)}")

    message_types =
      Enum.map(messages, fn msg ->
        "#{msg.type}:#{msg.subtype || "nil"}"
      end)
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
           cost: calculate_cost(messages)
         }}
    end
  end

  defp extract_text_from_messages(messages) do
    Logger.debug("📋 Extracting text from #{length(messages)} Claude SDK messages")

    # Check if we have a result message - this tells us if the conversation completed
    result_msg = Enum.find(messages, fn msg -> msg.type == :result end)

    validate_result_message(result_msg, messages)
    extract_assistant_messages_text(messages)
  end

  defp validate_result_message(nil, messages) do
    # No explicit result message found, but check if we have successful assistant messages with content
    assistant_messages = Enum.filter(messages, fn msg -> msg.type == :assistant end)

    if length(assistant_messages) > 0 and has_meaningful_content?(assistant_messages) do
      Logger.debug(
        "✅ Claude SDK conversation completed with assistant messages (no explicit result)"
      )

      :ok
    else
      Logger.error("❌ Claude SDK conversation incomplete - no result message found")

      Logger.debug(
        "Available message types: #{inspect(Enum.map(messages, &{&1.type, &1.subtype}))}"
      )

      throw({:error, "Claude SDK conversation incomplete"})
    end
  end

  defp validate_result_message(%{subtype: :success}, _messages) do
    Logger.debug("✅ Claude SDK conversation completed successfully")
    :ok
  end

  defp validate_result_message(%{subtype: subtype} = result_msg, _messages)
       when subtype != :success do
    error_text = extract_error_text(result_msg.data, subtype)
    throw({:error, error_text})
  end

  defp extract_error_text(data, subtype) do
    cond do
      subtype == :error_max_turns ->
        "Task exceeded max_turns limit. Increase max_turns in claude_options for complex tasks."

      Map.has_key?(data, :error) and data.error not in [nil, ""] ->
        data.error

      Map.has_key?(data, :message) and data.message not in [nil, ""] ->
        data.message

      Map.has_key?(data, :result) and data.result not in [nil, ""] ->
        data.result

      true ->
        "Claude SDK error (#{subtype}): No error details available"
    end
  end

  defp extract_assistant_messages_text(messages) do
    assistant_messages = Enum.filter(messages, fn msg -> msg.type == :assistant end)
    Logger.debug("🔍 Found #{length(assistant_messages)} assistant messages")

    text_parts = Enum.map(assistant_messages, &extract_message_content/1)
    result = Enum.join(text_parts, "\n")
    Logger.debug("✅ Extracted #{String.length(result)} characters from Claude response")
    result
  end

  defp extract_message_content(msg) do
    case msg.data.message["content"] do
      text when is_binary(text) ->
        text

      [%{"text" => text} | _] ->
        text

      content_array when is_list(content_array) ->
        extract_text_from_content_array(content_array)

      other ->
        Logger.warning("⚠️ Unknown Claude content format: #{inspect(other, limit: 100)}")
        inspect(other)
    end
  end

  defp extract_text_from_content_array(content_array) do
    text_items =
      Enum.filter(content_array, fn item ->
        Map.has_key?(item, "text") and item["type"] == "text"
      end)

    texts = Enum.map(text_items, fn item -> item["text"] end)
    Enum.join(texts, " ")
  end

  defp has_meaningful_content?(assistant_messages) do
    # Check if any assistant message has substantial content
    Enum.any?(assistant_messages, fn msg ->
      content = extract_message_content(msg)
      # At least 10 meaningful characters
      String.length(String.trim(content)) > 10
    end)
  end

  defp calculate_cost(messages) do
    # Simple cost calculation based on message count
    # In reality, this would be based on token usage
    length(messages) * 0.0001
  end

  # Async streaming support

  defp execute_async_query(prompt, sdk_options, options) do
    Logger.debug("🚀 Starting async Claude SDK query...")

    # Get the raw stream from ClaudeCodeSDK
    stream = ClaudeCodeSDK.query(prompt, sdk_options)

    # Extract step name from options if available
    step_name = options[:step_name] || options["step_name"] || "claude_query"

    # Create AsyncResponse wrapper
    async_response =
      AsyncResponse.new(stream, step_name,
        handler: options[:stream_handler],
        buffer_size: options[:stream_buffer_size],
        metadata: %{
          prompt_length: String.length(prompt),
          started_at: DateTime.utc_now()
        }
      )

    Logger.debug("✅ Created async response for streaming")
    {:ok, async_response}
  rescue
    error ->
      Logger.error("💥 Failed to create async stream: #{inspect(error)}")
      {:error, Exception.message(error)}
  end
end
