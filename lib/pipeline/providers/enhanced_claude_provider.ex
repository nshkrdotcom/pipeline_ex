defmodule Pipeline.Providers.EnhancedClaudeProvider do
  @moduledoc """
  Enhanced Claude provider with full Claude Agent SDK integration.

  Supports:
  - Complete `ClaudeAgentSDK.Options` mapping
  - OptionBuilder preset integration
  - Advanced error handling with retries
  - Session management support
  - Hook configuration and MCP server wiring
  - Performance monitoring and cost tracking
  """

  require Logger

  alias ClaudeAgentSDK
  alias ClaudeAgentSDK.{Agent, Options}
  alias Pipeline.TestMode
  alias ClaudeAgentSDK.Hooks.{Matcher, Output}

  @doc """
  Query Claude using the enhanced SDK integration.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug(
      "💪 Enhanced Claude Provider querying with prompt length: #{String.length(prompt)}"
    )

    Logger.debug("🔧 Enhanced options keys: #{inspect(Map.keys(options))}")

    try do
      sdk_options = build_sdk_options(options)

      case TestMode.get_mode() do
        :mock ->
          execute_mock_query(prompt, options)

        _live_mode ->
          execute_live_query(prompt, sdk_options, options)
      end
    rescue
      error ->
        Logger.error("💥 Enhanced Claude Provider crashed: #{inspect(error)}")
        {:error, "Enhanced Claude Provider crashed: #{Exception.message(error)}"}
    end
  end

  # Option building ----------------------------------------------------------

  defp build_sdk_options(options) do
    max_turns_default =
      Application.get_env(:pipeline, :max_turns_presets, %{})[:chat] ||
        Application.get_env(:pipeline, :max_turns_default, 15)

    attrs =
      [
        max_turns: fetch_integer(options, "max_turns", max_turns_default),
        output_format: get_output_format(options),
        verbose: fetch_boolean(options, "verbose", true),
        system_prompt: fetch_option(options, "system_prompt"),
        append_system_prompt: fetch_option(options, "append_system_prompt"),
        allowed_tools: build_allowed_tools_with_skills(options),
        disallowed_tools: fetch_list(options, "disallowed_tools"),
        cwd: fetch_option(options, "cwd", "./workspace"),
        model: fetch_option(options, "model"),
        fallback_model: fetch_option(options, "fallback_model"),
        permission_mode: fetch_permission_mode(options),
        permission_prompt_tool: fetch_option(options, "permission_prompt_tool"),
        mcp_servers: build_mcp_servers(options),
        hooks: build_hooks(options),
        agents: build_agents(options),
        agent: fetch_option(options, "agent"),
        session_id: fetch_option(options, "session_id"),
        fork_session: fetch_boolean(options, "fork_session"),
        add_dir: fetch_list(options, "add_dir"),
        strict_mcp_config: fetch_boolean(options, "strict_mcp_config"),
        can_use_tool: build_permission_callback(options)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Options.new(attrs)
  end

  defp fetch_option(options, key, default \\ nil)

  defp fetch_option(options, key, default) when is_binary(key) do
    atom_key = String.to_atom(key)

    cond do
      Map.has_key?(options, key) -> Map.get(options, key)
      Map.has_key?(options, atom_key) -> Map.get(options, atom_key)
      true -> default
    end
  end

  defp fetch_option(options, key, default) when is_atom(key) do
    Map.get(options, key, default)
  end

  defp fetch_integer(options, key, default) do
    case fetch_option(options, key, default) do
      nil ->
        nil

      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _} -> parsed
          :error -> default
        end

      other ->
        other
    end
  end

  defp fetch_boolean(options, key, default \\ nil) do
    case fetch_option(options, key, default) do
      nil -> default
      "true" -> true
      "false" -> false
      value when is_boolean(value) -> value
      value -> !!value
    end
  end

  defp fetch_list(options, key) do
    case fetch_option(options, key, nil) do
      nil -> nil
      value when is_list(value) -> value
      value -> List.wrap(value)
    end
  end

  defp fetch_permission_mode(options) do
    case fetch_option(options, "permission_mode") do
      nil ->
        nil

      value when is_atom(value) ->
        value

      value when is_binary(value) ->
        value
        |> String.downcase()
        |> case do
          "accept_edits" -> :accept_edits
          "acceptedits" -> :accept_edits
          "bypass_permissions" -> :bypass_permissions
          "bypasspermissions" -> :bypass_permissions
          "plan" -> :plan
          _ -> :default
        end

      _ ->
        :default
    end
  end

  defp get_output_format(options) do
    case fetch_option(options, "output_format", "stream_json") do
      nil -> nil
      "text" -> :text
      "json" -> :json
      "stream_json" -> :stream_json
      "stream-json" -> :stream_json
      value when is_atom(value) -> value
      _ -> :stream_json
    end
  end

  defp build_allowed_tools_with_skills(options) do
    base_tools = fetch_list(options, "allowed_tools") || []

    if fetch_boolean(options, "enable_skills", false) do
      Enum.uniq(base_tools ++ ["Skill"])
    else
      base_tools
    end
  end

  defp build_mcp_servers(options) do
    case fetch_option(options, "mcp_servers", %{}) do
      servers when servers in [%{}, nil] ->
        nil

      servers when is_map(servers) ->
        servers
        |> Enum.map(fn {name, config} ->
          normalized = normalize_mcp_server_config(config)
          {to_string(name), normalized}
        end)
        |> Enum.reject(fn {_name, config} -> config == %{} end)
        |> Enum.into(%{})

      _ ->
        nil
    end
  end

  defp normalize_mcp_server_config(config) when is_map(config) do
    type = normalize_mcp_type(fetch_option(config, "type", "stdio"))

    %{
      type: type,
      command: fetch_option(config, "command"),
      args: fetch_list(config, "args") || [],
      env: fetch_option(config, "env"),
      headers: fetch_option(config, "headers"),
      url: fetch_option(config, "url")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == [] end)
    |> Enum.into(%{})
  end

  defp normalize_mcp_server_config(_config), do: %{}

  defp normalize_mcp_type(type) when is_atom(type), do: type

  defp normalize_mcp_type(type) when is_binary(type) do
    case String.downcase(type) do
      "stdio" -> :stdio
      "sse" -> :sse
      "http" -> :http
      other -> String.to_atom(other)
    end
  end

  defp normalize_mcp_type(_type), do: :stdio

  defp build_hooks(options) do
    hooks_config = fetch_option(options, "hooks", %{})

    cond do
      hooks_config in [%{}, nil] ->
        nil

      is_map(hooks_config) ->
        hooks_config
        |> Enum.map(fn {event, matchers} ->
          {normalize_hook_event(event), build_matchers(matchers)}
        end)
        |> Enum.reject(fn {_event, matchers} -> matchers == [] end)
        |> Enum.into(%{})

      true ->
        nil
    end
  end

  defp normalize_hook_event(event) when is_atom(event), do: event

  defp normalize_hook_event(event) do
    event
    |> to_string()
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp build_matchers(matchers) when is_list(matchers) do
    Enum.map(matchers, &normalize_hook_matcher/1)
    |> Enum.reject(&is_nil/1)
  end

  defp build_matchers(_), do: []

  defp normalize_hook_matcher(%{} = matcher_config) do
    matcher = fetch_option(matcher_config, "matcher")
    hooks = fetch_list(matcher_config, "hooks") || []

    resolved_hooks =
      hooks
      |> Enum.map(&resolve_hook_function/1)
      |> Enum.reject(&is_nil/1)

    case resolved_hooks do
      [] -> nil
      functions -> Matcher.new(normalize_matcher_pattern(matcher), functions)
    end
  end

  defp normalize_hook_matcher(_), do: nil

  defp normalize_matcher_pattern(nil), do: nil
  defp normalize_matcher_pattern(""), do: "*"
  defp normalize_matcher_pattern(pattern) when is_binary(pattern), do: pattern
  defp normalize_matcher_pattern(pattern), do: to_string(pattern)

  defp resolve_hook_function(fun) when is_function(fun, 3), do: fun

  defp resolve_hook_function(name) when is_binary(name) do
    case String.downcase(name) do
      "log_tool_use" -> &log_tool_use_hook/3
      "log-tool-use" -> &log_tool_use_hook/3
      "validate_bash" -> &validate_bash_hook/3
      "validate-bash" -> &validate_bash_hook/3
      "audit_tool" -> &audit_tool_hook/3
      "audit-tool" -> &audit_tool_hook/3
      _ -> &default_hook/3
    end
  end

  defp resolve_hook_function(_), do: &default_hook/3

  defp build_agents(options) do
    agents_config = fetch_option(options, "agents", %{})

    cond do
      agents_config in [%{}, nil] ->
        nil

      is_map(agents_config) ->
        agents_config
        |> Enum.map(fn {name, config} ->
          case normalize_agent_config(config) do
            nil -> nil
            agent -> {normalize_agent_name(name), agent}
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.into(%{})

      true ->
        nil
    end
  end

  defp normalize_agent_name(name) when is_atom(name), do: name
  defp normalize_agent_name(name) when is_binary(name), do: String.to_atom(name)
  defp normalize_agent_name(name), do: name

  defp normalize_agent_config(%{} = config) do
    description = fetch_option(config, "description")
    prompt = fetch_option(config, "prompt")

    if description && prompt do
      attrs =
        [
          name: fetch_option(config, "name"),
          description: description,
          prompt: prompt,
          allowed_tools: fetch_list(config, "tools"),
          model: fetch_option(config, "model")
        ]
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)

      Agent.new(attrs)
    else
      nil
    end
  end

  defp normalize_agent_config(_), do: nil

  defp build_permission_callback(options) do
    case fetch_option(options, "permission_callback") do
      nil -> nil
      fun when is_function(fun, 3) -> fun
      _ -> nil
    end
  end

  # Execution paths ----------------------------------------------------------

  defp execute_mock_query(prompt, options) do
    preset = fetch_option(options, "preset", "development")

    mock_response = %{
      "text" => generate_mock_response_text(prompt, preset),
      "success" => true,
      "cost" => calculate_mock_cost(preset),
      "session_id" => "mock-enhanced-session-#{:rand.uniform(10_000)}",
      "preset_applied" => preset,
      "enhanced_provider" => true,
      "mock_mode" => true
    }

    if should_simulate_retry(options) do
      add_retry_simulation(mock_response)
    else
      {:ok, mock_response}
    end
  end

  defp execute_live_query(prompt, sdk_options, pipeline_options) do
    Logger.debug("🚀 Executing live Claude SDK query")

    retry_config = fetch_option(pipeline_options, "retry_config", %{})

    if Map.get(retry_config, "max_retries", 0) > 0 do
      execute_with_retry(prompt, sdk_options, pipeline_options, retry_config)
    else
      execute_single_query(prompt, sdk_options, pipeline_options)
    end
  end

  defp execute_single_query(prompt, sdk_options, pipeline_options) do
    Logger.debug("📤 Single Claude SDK query execution")

    timeout = fetch_integer(pipeline_options, "timeout_ms", 300_000)

    task =
      Task.async(fn ->
        messages = ClaudeAgentSDK.query(prompt, sdk_options) |> Enum.to_list()
        Logger.debug("📋 Received #{length(messages)} messages from Claude SDK")
        process_claude_messages(messages, pipeline_options)
      end)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        result

      nil ->
        _shutdown_result = Task.shutdown(task, :brutal_kill)
        Logger.error("⏰ Claude SDK query timed out after #{timeout}ms")
        {:error, "Query timed out after #{timeout}ms"}
    end
  end

  defp execute_with_retry(prompt, sdk_options, pipeline_options, retry_config) do
    max_retries = Map.get(retry_config, "max_retries", 3)
    Logger.debug("🔄 Executing with retry: max_retries=#{max_retries}")

    execute_with_retry_loop(prompt, sdk_options, pipeline_options, retry_config, 1, max_retries)
  end

  defp execute_with_retry_loop(
         prompt,
         sdk_options,
         pipeline_options,
         retry_config,
         attempt,
         max_retries
       ) do
    Logger.debug("🔄 Retry attempt #{attempt}/#{max_retries}")

    case execute_single_query(prompt, sdk_options, pipeline_options) do
      {:ok, response} ->
        retry_metadata = %{
          "retry_info" => %{
            "attempts_made" => attempt,
            "max_retries" => max_retries,
            "final_attempt" => true
          }
        }

        {:ok, Map.merge(response, retry_metadata)}

      {:error, reason} when attempt < max_retries ->
        if should_retry_on_error(reason, retry_config) do
          backoff_delay = calculate_backoff_delay(attempt, retry_config)
          Logger.debug("⏳ Retrying after #{backoff_delay}ms delay due to: #{reason}")
          :timer.sleep(backoff_delay)

          execute_with_retry_loop(
            prompt,
            sdk_options,
            pipeline_options,
            retry_config,
            attempt + 1,
            max_retries
          )
        else
          Logger.debug("🚫 Not retrying for error: #{reason}")
          {:error, reason}
        end

      {:error, reason} ->
        Logger.error("🔄 Max retries (#{max_retries}) reached. Final error: #{reason}")
        {:error, "#{reason} (after #{max_retries} retries)"}
    end
  end

  defp should_retry_on_error(reason, retry_config) do
    retry_conditions = Map.get(retry_config, "retry_on", [])
    reason_str = String.downcase(to_string(reason))

    Enum.any?(retry_conditions, fn condition ->
      String.contains?(reason_str, String.downcase(to_string(condition)))
    end)
  end

  defp calculate_backoff_delay(attempt, retry_config) do
    strategy = Map.get(retry_config, "backoff_strategy", "exponential")
    base_delay = 1000

    case strategy do
      "linear" -> base_delay * attempt
      "exponential" -> round(base_delay * :math.pow(2, attempt - 1))
      _ -> base_delay
    end
  end

  # Message processing -------------------------------------------------------

  defp process_claude_messages([], _pipeline_options) do
    Logger.error("❌ No messages received from Claude SDK")
    {:error, "No response from Claude SDK"}
  end

  defp process_claude_messages(messages, pipeline_options) do
    Logger.debug("📋 Processing #{length(messages)} Claude SDK messages")

    error_msg =
      Enum.find(messages, fn msg ->
        msg.type == :result && msg.subtype != :success
      end)

    if error_msg do
      {:error, extract_error_text(error_msg)}
    else
      text_content = extract_text_from_messages(messages)

      if String.trim(text_content) == "" do
        {:error, "Empty response from Claude"}
      else
        response =
          %{
            "text" => text_content,
            "success" => true,
            "cost" => calculate_cost(messages),
            "session_id" => extract_session_id_from_messages(messages)
          }
          |> add_debug_info(messages, pipeline_options)
          |> add_telemetry_info(messages, pipeline_options)
          |> add_cost_tracking_info(messages, pipeline_options)

        {:ok, response}
      end
    end
  end

  defp extract_error_text(message) do
    data = Map.get(message, :data, %{})
    subtype = Map.get(message, :subtype)

    cond do
      subtype == :error_max_turns ->
        "Task exceeded max_turns limit. Increase max_turns in claude_options for complex tasks."

      subtype == :error_during_execution && Map.get(data, :error) ->
        error_text = Map.get(data, :error, "")

        if String.contains?(error_text, "timed out after 30 seconds") do
          "Claude operation is taking longer than expected. Please wait..."
        else
          error_text
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
    |> Enum.filter(&(&1.type == :assistant))
    |> Enum.map(&extract_message_content/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # Extract content from a message structure
  # The Claude SDK returns messages in format:
  # %{type: :assistant, data: %{message: %{"content" => json_string, ...}, ...}}
  defp extract_message_content(%{data: %{message: %{"content" => content}}})
       when is_binary(content) do
    # The content is a JSON string containing an array of messages or a simple value
    case Jason.decode(content) do
      {:ok, parsed} when is_list(parsed) ->
        extracted = extract_text_from_stream_messages(parsed)
        if String.trim(extracted) == "", do: content, else: extracted

      {:ok, parsed} when is_binary(parsed) ->
        parsed

      {:ok, parsed} when is_number(parsed) ->
        to_string(parsed)

      {:ok, parsed} when is_map(parsed) ->
        cond do
          Map.has_key?(parsed, "text") -> Map.get(parsed, "text")
          Map.has_key?(parsed, :text) -> Map.get(parsed, :text)
          true -> content
        end

      {:ok, _parsed} ->
        content

      {:error, _} ->
        content
    end
  end

  defp extract_message_content(%{data: %{message: %{"content" => content}}})
       when is_list(content) do
    extract_text_from_inner_content(content)
  end

  defp extract_message_content(%{data: %{message: _message}}) do
    ""
  end

  defp extract_message_content(%{message: %{content: content}}) when is_binary(content) do
    content
  end

  defp extract_message_content(%{message: %{content: content}}) when is_list(content) do
    extract_text_from_inner_content(content)
  end

  defp extract_message_content(_other) do
    ""
  end

  # Extract text from streaming message format (JSON array)
  # Format: [{"type": "system", ...}, {"type": "assistant", "message": {...}}, ...]
  defp extract_text_from_stream_messages(messages) when is_list(messages) do
    messages
    |> Enum.filter(&(Map.get(&1, "type") == "assistant"))
    |> Enum.map(fn item ->
      case Map.get(item, "message") do
        %{"content" => content} when is_list(content) ->
          extract_text_from_inner_content(content)

        %{"content" => content} when is_binary(content) ->
          content

        _ ->
          ""
      end
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # Extract text from content blocks
  # Format: [{"type": "text", "text": "..."}, {"type": "tool_use", ...}, ...]
  defp extract_text_from_inner_content(content_list) when is_list(content_list) do
    content_list
    |> Enum.map(fn part ->
      cond do
        is_binary(part) ->
          part

        is_map(part) and Map.get(part, "type") == "text" and Map.has_key?(part, "text") ->
          part["text"]

        is_map(part) and Map.get(part, :type) == :text and Map.has_key?(part, :text) ->
          part[:text]

        # Skip tool_use and other non-text blocks
        true ->
          ""
      end
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp extract_text_from_inner_content(_), do: ""

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

  defp extract_session_id_from_messages(messages) do
    system_msg = Enum.find(messages, &(&1.type == :system))

    case system_msg do
      %{data: %{session_id: session_id}} -> session_id
      _ -> "unknown-session-#{:rand.uniform(10_000)}"
    end
  end

  defp add_debug_info(response, messages, options) do
    if fetch_boolean(options, "debug_mode", false) do
      debug_info = %{
        "debug_info" => %{
          "message_types" =>
            Enum.map(messages, fn msg ->
              %{"type" => msg.type, "subtype" => msg.subtype}
            end),
          "total_messages" => length(messages),
          "options_applied" => Map.keys(options)
        }
      }

      Map.merge(response, debug_info)
    else
      response
    end
  end

  defp add_telemetry_info(response, messages, options) do
    if fetch_boolean(options, "telemetry_enabled", false) do
      result_msg = Enum.find(messages, &(&1.type == :result))

      telemetry_info =
        case result_msg do
          %{data: data} ->
            %{
              "telemetry" => %{
                "duration_ms" => Map.get(data, :duration_ms, 0),
                "num_turns" => Map.get(data, :num_turns, 0),
                "tokens_used" => Map.get(data, :tokens_used, 0)
              }
            }

          _ ->
            %{"telemetry" => %{"duration_ms" => 0, "num_turns" => 0}}
        end

      Map.merge(response, telemetry_info)
    else
      response
    end
  end

  defp add_cost_tracking_info(response, messages, options) do
    if fetch_boolean(options, "cost_tracking", false) do
      cost = Map.get(response, "cost", 0.0)

      cost_info = %{
        "cost_tracking" => %{
          "total_cost_usd" => cost,
          "cost_per_message" => cost / max(length(messages), 1),
          "tracking_enabled" => true
        }
      }

      Map.merge(response, cost_info)
    else
      response
    end
  end

  # Mock helpers -------------------------------------------------------------

  defp generate_mock_response_text(prompt, preset) do
    base_text = "Mock enhanced Claude response"

    preset_suffix =
      case preset do
        "development" -> " with development optimizations applied"
        "production" -> " with production safety constraints"
        "analysis" -> " with detailed analysis capabilities"
        "chat" -> " in conversational mode"
        "test" -> " optimized for testing"
        _ -> " with default settings"
      end

    "#{base_text}#{preset_suffix}. Original prompt length: #{String.length(prompt)} characters."
  end

  defp calculate_mock_cost(preset) do
    case preset do
      "development" -> 0.002
      "production" -> 0.001
      "analysis" -> 0.0015
      "chat" -> 0.0005
      "test" -> 0.0001
      _ -> 0.001
    end
  end

  defp should_simulate_retry(options) do
    retry_config = fetch_option(options, "retry_config", %{})
    max_retries = Map.get(retry_config, "max_retries", 0)

    max_retries > 0 and :rand.uniform(10) == 1
  end

  defp add_retry_simulation(response) do
    retry_info = %{
      "retry_info" => %{
        "attempts_made" => 2,
        "max_retries" => 3,
        "retry_successful" => true,
        "simulated_retry" => true
      }
    }

    {:ok, Map.merge(response, retry_info)}
  end

  # Hook callbacks -----------------------------------------------------------

  defp log_tool_use_hook(event_data, tool_use_id, _context) do
    Logger.info("🔧 Tool used (#{tool_use_id}): #{inspect(event_data)}")
    %{}
  end

  defp validate_bash_hook(event_data, _tool_use_id, _context) do
    command = get_in(event_data, ["tool_input", "command"]) || ""

    dangerous_patterns = ["rm -rf", "sudo", "chmod 777"]

    if Enum.any?(dangerous_patterns, &String.contains?(command, &1)) do
      Logger.warning("🚫 Blocked dangerous command: #{command}")
      Output.deny("Command contains dangerous patterns")
    else
      Output.allow("Command approved")
    end
  end

  defp audit_tool_hook(event_data, tool_use_id, _context) do
    tool_name = Map.get(event_data, "tool_name", "unknown")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    audit_entry = %{
      timestamp: timestamp,
      tool: tool_name,
      tool_use_id: tool_use_id,
      event_data: event_data
    }

    Logger.info("📊 Audit: #{Jason.encode!(audit_entry)}")
    %{}
  end

  defp default_hook(_event_data, _tool_use_id, _context), do: %{}
end
