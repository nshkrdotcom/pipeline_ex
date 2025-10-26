defmodule Pipeline.Providers.ClaudeProviderExtended do
  @moduledoc """
  Extended Claude provider with configurable timeout support.
  This module works around the hardcoded 30-second timeout in ClaudeAgentSDK.
  """

  require Logger
  alias ClaudeAgentSDK.{Options, Message}

  # Extra buffer for process cleanup
  @timeout_buffer_ms 5_000

  def query(prompt, options \\ %{}) do
    timeout_ms = get_timeout_ms(options)
    Logger.debug("💪 Querying Claude with timeout: #{timeout_ms}ms")

    # Spawn a separate process to handle the Claude query
    task =
      Task.async(fn ->
        execute_claude_query(prompt, options)
      end)

    # Wait for the task with our custom timeout
    case Task.yield(task, timeout_ms) || Task.shutdown(task, @timeout_buffer_ms) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("❌ Claude query timed out after #{timeout_ms}ms")
        {:error, "Claude query timed out after #{timeout_ms / 1000} seconds"}

      {:exit, reason} ->
        Logger.error("💥 Claude query crashed: #{inspect(reason)}")
        {:error, "Claude query crashed: #{inspect(reason)}"}
    end
  end

  defp get_timeout_ms(options) do
    cond do
      options["timeout_ms"] ->
        options["timeout_ms"]

      options[:timeout_ms] ->
        options[:timeout_ms]

      options["timeout_seconds"] ->
        options["timeout_seconds"] * 1000

      options[:timeout_seconds] ->
        options[:timeout_seconds] * 1000

      true ->
        # Get from application config or use default
        Application.get_env(:pipeline, :timeout_seconds, 300) * 1000
    end
  end

  defp execute_claude_query(prompt, options) do
    try do
      claude_options = build_claude_options(options)

      case Pipeline.TestMode.get_mode() do
        :mock ->
          {:ok,
           %{
             text: "Mock Claude response for: #{String.slice(prompt, 0, 50)}...",
             success: true,
             cost: 0.001
           }}

        _live_or_mixed ->
          execute_live_claude_query_with_custom_timeout(prompt, claude_options)
      end
    rescue
      error ->
        Logger.error("💥 Claude query error: #{inspect(error)}")
        {:error, Exception.message(error)}
    end
  end

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
      cwd: get_option_value(options, "cwd", :cwd, "./workspace")
    }
  end

  defp get_option_value(options, string_key, atom_key, default) do
    options[string_key] || options[atom_key] || default
  end

  defp execute_live_claude_query_with_custom_timeout(prompt, options) do
    verbose =
      case options[:verbose] do
        nil -> true
        value -> value
      end

    sdk_options =
      Options.new(
        max_turns:
          options[:max_turns] || Application.get_env(:pipeline, :max_turns_sdk_default, 1),
        verbose: verbose,
        allowed_tools: options[:allowed_tools],
        disallowed_tools: options[:disallowed_tools],
        system_prompt: options[:system_prompt],
        cwd: options[:cwd],
        model: options[:model],
        fallback_model: options[:fallback_model]
      )

    Logger.debug("🚀 Starting Claude SDK query with extended timeout...")

    # Use our custom stream collector that doesn't have a fixed timeout
    messages = collect_claude_messages_no_timeout(prompt, sdk_options)
    process_claude_messages(messages)
  end

  defp collect_claude_messages_no_timeout(prompt, sdk_options) do
    Logger.debug("📥 Collecting messages from Claude SDK stream (no timeout)...")

    # Create the stream
    stream = ClaudeAgentSDK.query(prompt, sdk_options)

    # Collect all messages - the stream itself should complete when done
    # This avoids the 30-second timeout in the SDK
    try do
      Enum.to_list(stream)
    rescue
      error ->
        Logger.error("💥 Failed to collect Claude SDK stream: #{inspect(error)}")
        reraise error, __STACKTRACE__
    end
  end

  defp process_claude_messages([]) do
    Logger.error("❌ No messages received from Claude SDK")
    {:error, "No response from Claude SDK"}
  end

  defp process_claude_messages(messages) do
    Logger.debug("📋 Processing #{length(messages)} Claude SDK messages")

    # Check for errors in messages
    error_msg =
      Enum.find(messages, fn msg ->
        msg.type == :result && msg.subtype != :success
      end)

    if error_msg do
      error_text = extract_error_text(error_msg)
      {:error, error_text}
    else
      text_content = extract_text_from_messages(messages)

      if text_content == "" do
        {:error, "Empty response from Claude"}
      else
        {:ok,
         %{
           text: text_content,
           success: true,
           cost: calculate_cost(messages)
         }}
      end
    end
  end

  defp extract_error_text(%Message{subtype: subtype, data: data}) do
    cond do
      subtype == :error_max_turns ->
        "Task exceeded max_turns limit. Increase max_turns in claude_options for complex tasks."

      subtype == :error_during_execution && data[:error] ->
        # Don't propagate the 30-second timeout error from the SDK
        if String.contains?(data.error, "timed out after 30 seconds") do
          "Claude operation is taking longer than expected. Please wait..."
        else
          data.error
        end

      Map.has_key?(data, :error) && data.error not in [nil, ""] ->
        data.error

      Map.has_key?(data, :message) && data.message not in [nil, ""] ->
        data.message

      true ->
        "Claude SDK error (#{subtype})"
    end
  end

  defp extract_text_from_messages(messages) do
    messages
    |> Enum.filter(fn msg -> msg.type == :assistant end)
    |> Enum.map(&extract_message_content/1)
    |> Enum.join("\n")
  end

  defp extract_message_content(msg) do
    case msg.data.message["content"] do
      text when is_binary(text) ->
        text

      [%{"text" => text} | _] ->
        text

      content_array when is_list(content_array) ->
        content_array
        |> Enum.filter(fn item ->
          Map.has_key?(item, "text") && item["type"] == "text"
        end)
        |> Enum.map(fn item -> item["text"] end)
        |> Enum.join(" ")

      _ ->
        ""
    end
  end

  defp calculate_cost(messages) do
    # Simple cost calculation based on message count
    length(messages) * 0.0001
  end
end
