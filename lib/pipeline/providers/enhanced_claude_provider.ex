defmodule Pipeline.Providers.EnhancedClaudeProvider do
  @moduledoc """
  Enhanced Claude provider with full Claude Code SDK integration.

  Supports all enhanced features:
  - Complete ClaudeCodeSDK.Options mapping
  - OptionBuilder preset integration
  - Advanced error handling with retries
  - Session management support
  - Content extraction integration
  - Performance monitoring and cost tracking
  """

  require Logger
  alias Pipeline.TestMode
  alias Pipeline.Streaming.AsyncResponse

  @doc """
  Query Claude using the enhanced Claude Code SDK integration.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug(
      "💪 Enhanced Claude Provider querying with prompt length: #{String.length(prompt)}"
    )

    Logger.debug("🔧 Enhanced options keys: #{inspect(Map.keys(options))}")

    try do
      # Convert pipeline options to ClaudeCodeSDK.Options
      sdk_options = build_sdk_options(options)

      # Check if we're in mock mode
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

  # Private implementation functions

  defp build_sdk_options(options) do
    ClaudeCodeSDK.Options.new(
      max_turns:
        get_option(
          options,
          "max_turns",
          Application.get_env(:pipeline, :max_turns_presets, %{})[:chat] || 15
        ),
      output_format: get_output_format(options),
      verbose: get_option(options, "verbose", true),
      system_prompt: get_option(options, "system_prompt"),
      append_system_prompt: get_option(options, "append_system_prompt"),
      allowed_tools: get_option(options, "allowed_tools"),
      disallowed_tools: get_option(options, "disallowed_tools"),
      cwd: get_option(options, "cwd", "./workspace"),
      async: get_option(options, "async_streaming", false)
    )
  end

  defp get_option(options, key, default \\ nil) do
    case Map.get(options, key, default) do
      nil -> default
      value -> value
    end
  end

  defp get_output_format(options) do
    case get_option(options, "output_format", "stream_json") do
      "text" -> :text
      "json" -> :json
      "stream_json" -> :stream_json
      "stream-json" -> :stream_json
      _ -> :stream_json
    end
  end

  defp execute_mock_query(prompt, options) do
    # Check if async streaming is enabled
    if get_option(options, "async_streaming", false) do
      execute_mock_async_query(prompt, options)
    else
      # Return enhanced mock response for testing
      preset = get_option(options, "preset", "development")

      mock_response = %{
        "text" => generate_mock_response_text(prompt, preset),
        "success" => true,
        "cost" => calculate_mock_cost(preset),
        "session_id" => "mock-enhanced-session-#{:rand.uniform(10000)}",
        "preset_applied" => preset,
        "enhanced_provider" => true,
        "mock_mode" => true
      }

      # Add retry simulation if enabled
      if should_simulate_retry(options) do
        add_retry_simulation(mock_response)
      else
        {:ok, mock_response}
      end
    end
  end

  defp execute_live_query(prompt, sdk_options, pipeline_options) do
    Logger.debug("🚀 Executing live Claude SDK query")

    # Execute with retry logic if configured
    retry_config = get_option(pipeline_options, "retry_config", %{})

    if Map.get(retry_config, "max_retries", 0) > 0 do
      execute_with_retry(prompt, sdk_options, pipeline_options, retry_config)
    else
      execute_single_query(prompt, sdk_options, pipeline_options)
    end
  end

  defp execute_single_query(prompt, sdk_options, pipeline_options) do
    Logger.debug("📤 Single Claude SDK query execution")

    # Check if async streaming is enabled
    if Map.get(sdk_options, :async) || get_option(pipeline_options, "async_streaming", false) do
      execute_async_streaming_query(prompt, sdk_options, pipeline_options)
    else
      # Set timeout if specified
      timeout = get_option(pipeline_options, "timeout_ms", 300_000)

      task =
        Task.async(fn ->
          messages = ClaudeCodeSDK.query(prompt, sdk_options) |> Enum.to_list()
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
  end

  defp execute_with_retry(prompt, sdk_options, pipeline_options, retry_config) do
    max_retries = Map.get(retry_config, "max_retries", 3)
    backoff_strategy = Map.get(retry_config, "backoff_strategy", "exponential")
    _retry_conditions = Map.get(retry_config, "retry_on", ["timeout", "api_error"])

    Logger.debug(
      "🔄 Executing with retry: max_retries=#{max_retries}, strategy=#{backoff_strategy}"
    )

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
        # Add retry metadata to successful response
        retry_metadata = %{
          "retry_info" => %{
            "attempts_made" => attempt,
            "max_retries" => max_retries,
            "final_attempt" => true
          }
        }

        enhanced_response = Map.merge(response, retry_metadata)
        {:ok, enhanced_response}

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
        # Max retries reached
        Logger.error("🔄 Max retries (#{max_retries}) reached. Final error: #{reason}")

        _retry_metadata = %{
          "retry_info" => %{
            "attempts_made" => attempt,
            "max_retries" => max_retries,
            "final_attempt" => true,
            "retry_exhausted" => true
          }
        }

        {:error, "#{reason} (after #{max_retries} retries)"}
    end
  end

  defp should_retry_on_error(reason, retry_config) do
    retry_conditions = Map.get(retry_config, "retry_on", [])

    reason_str = String.downcase(to_string(reason))

    Enum.any?(retry_conditions, fn condition ->
      String.contains?(reason_str, String.downcase(condition))
    end)
  end

  defp calculate_backoff_delay(attempt, retry_config) do
    strategy = Map.get(retry_config, "backoff_strategy", "exponential")
    # 1 second base
    base_delay = 1000

    case strategy do
      "linear" ->
        base_delay * attempt

      "exponential" ->
        (base_delay * :math.pow(2, attempt - 1)) |> round()

      _ ->
        base_delay
    end
  end

  defp process_claude_messages(messages, pipeline_options) do
    Logger.debug("📋 Processing #{length(messages)} Claude SDK messages")

    # Extract text content
    text_content = extract_text_from_messages(messages)

    # Calculate costs and metadata
    cost = calculate_cost_from_messages(messages)
    session_id = extract_session_id_from_messages(messages)

    # Build enhanced response
    response = %{
      "text" => text_content,
      "success" => true,
      "cost" => cost,
      "session_id" => session_id,
      "message_count" => length(messages),
      "enhanced_provider" => true
    }

    # Add optional enhancements
    enhanced_response =
      response
      |> add_debug_info(messages, pipeline_options)
      |> add_telemetry_info(messages, pipeline_options)
      |> add_cost_tracking_info(messages, pipeline_options)

    {:ok, enhanced_response}
  end

  defp extract_text_from_messages(messages) do
    assistant_messages = Enum.filter(messages, fn msg -> msg.type == :assistant end)

    text_parts =
      Enum.map(assistant_messages, fn msg ->
        case msg.data.message["content"] do
          text when is_binary(text) ->
            text

          [%{"text" => text} | _] ->
            text

          content_array when is_list(content_array) ->
            content_array
            |> Enum.filter(&(Map.has_key?(&1, "text") and &1["type"] == "text"))
            |> Enum.map(& &1["text"])
            |> Enum.join(" ")

          other ->
            inspect(other)
        end
      end)

    Enum.join(text_parts, "\n")
  end

  defp calculate_cost_from_messages(messages) do
    # Extract cost from result message if available
    result_msg = Enum.find(messages, &(&1.type == :result))

    case result_msg do
      %{data: %{total_cost_usd: cost}} -> cost
      # Fallback estimation
      _ -> length(messages) * 0.001
    end
  end

  defp extract_session_id_from_messages(messages) do
    system_msg = Enum.find(messages, &(&1.type == :system))

    case system_msg do
      %{data: %{session_id: session_id}} -> session_id
      _ -> "unknown-session-#{:rand.uniform(10000)}"
    end
  end

  defp add_debug_info(response, messages, options) do
    if get_option(options, "debug_mode", false) do
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
    if get_option(options, "telemetry_enabled", false) do
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
    if get_option(options, "cost_tracking", false) do
      cost_info = %{
        "cost_tracking" => %{
          "total_cost_usd" => response["cost"],
          "cost_per_message" => response["cost"] / max(length(messages), 1),
          "tracking_enabled" => true
        }
      }

      Map.merge(response, cost_info)
    else
      response
    end
  end

  # Async streaming implementation

  defp execute_async_streaming_query(prompt, sdk_options, pipeline_options) do
    Logger.debug("🚀 Starting enhanced async streaming Claude SDK query...")

    # Emit telemetry event for stream start
    :telemetry.execute(
      [:pipeline, :enhanced_claude, :stream, :start],
      %{timestamp: System.monotonic_time()},
      %{
        prompt_length: String.length(prompt),
        options: pipeline_options
      }
    )

    # Get the raw stream from ClaudeCodeSDK
    stream = ClaudeCodeSDK.query(prompt, sdk_options)

    # Extract step name from options if available
    step_name = get_option(pipeline_options, "step_name", "enhanced_claude_query")

    # Create enhanced async response with streaming telemetry
    async_response = create_enhanced_async_response(stream, step_name, prompt, pipeline_options)

    Logger.debug("✅ Created enhanced async response for streaming")
    {:ok, async_response}
  rescue
    error ->
      Logger.error("💥 Failed to create enhanced async stream: #{inspect(error)}")

      # Emit telemetry event for stream error
      :telemetry.execute(
        [:pipeline, :enhanced_claude, :stream, :error],
        %{timestamp: System.monotonic_time()},
        %{error: error}
      )

      {:error, Exception.message(error)}
  end

  defp create_enhanced_async_response(stream, step_name, prompt, pipeline_options) do
    # Wrap the stream with telemetry and cost tracking
    enhanced_stream = wrap_stream_with_telemetry(stream, step_name, pipeline_options)

    # Create AsyncResponse with enhanced metadata
    AsyncResponse.new(enhanced_stream, step_name,
      handler: get_option(pipeline_options, "stream_handler"),
      buffer_size: get_option(pipeline_options, "stream_buffer_size", 10),
      metadata: %{
        prompt_length: String.length(prompt),
        started_at: DateTime.utc_now(),
        enhanced_provider: true,
        telemetry_enabled: get_option(pipeline_options, "telemetry_enabled", false),
        cost_tracking: get_option(pipeline_options, "cost_tracking", false),
        retry_config: get_option(pipeline_options, "retry_config", %{})
      }
    )
  end

  defp wrap_stream_with_telemetry(stream, step_name, options) do
    start_time = System.monotonic_time(:millisecond)
    first_token_ref = make_ref()

    # Initialize accumulator for progressive cost calculation
    initial_acc = %{
      message_count: 0,
      total_tokens: 0,
      cost_accumulator: 0.0,
      first_token_time: nil,
      last_token_time: nil
    }

    Stream.transform(
      stream,
      fn -> {initial_acc, first_token_ref} end,
      fn message, {acc, ref} ->
        # Update metrics
        now = System.monotonic_time(:millisecond)

        new_acc = update_streaming_metrics(acc, message, now, start_time, ref)

        # Emit telemetry for each message if enabled
        if get_option(options, "telemetry_enabled", false) do
          emit_message_telemetry(message, new_acc, step_name)
        end

        # Track progressive cost if enabled
        if get_option(options, "cost_tracking", false) do
          emit_cost_telemetry(new_acc, step_name)
        end

        {[message], {new_acc, ref}}
      end,
      fn {final_acc, _ref} ->
        # Emit final telemetry
        :telemetry.execute(
          [:pipeline, :enhanced_claude, :stream, :complete],
          %{
            duration_ms: System.monotonic_time(:millisecond) - start_time,
            message_count: final_acc.message_count,
            total_tokens: final_acc.total_tokens,
            total_cost: final_acc.cost_accumulator
          },
          %{step_name: step_name}
        )
      end
    )
  end

  defp update_streaming_metrics(acc, message, now, start_time, _first_token_ref) do
    # Check if this is the first token
    first_token_time =
      if is_nil(acc.first_token_time) and acc.message_count == 0 do
        # Emit time to first token telemetry
        time_to_first = now - start_time

        :telemetry.execute(
          [:pipeline, :enhanced_claude, :stream, :first_token],
          %{time_to_first_token_ms: time_to_first},
          %{}
        )

        now
      else
        acc.first_token_time
      end

    # Extract token count from message
    tokens = extract_message_tokens(message)

    # Calculate incremental cost
    incremental_cost = calculate_incremental_cost(message, tokens)

    %{
      acc
      | message_count: acc.message_count + 1,
        total_tokens: acc.total_tokens + tokens,
        cost_accumulator: acc.cost_accumulator + incremental_cost,
        first_token_time: first_token_time,
        last_token_time: now
    }
  end

  defp extract_message_tokens(message) do
    case message do
      %{data: %{tokens: count}} when is_integer(count) ->
        count

      %{data: %{token_count: count}} when is_integer(count) ->
        count

      %{type: :assistant, data: %{message: %{"content" => content}}} when is_binary(content) ->
        # Approximate: 1 token ≈ 4 characters
        div(String.length(content), 4)

      _ ->
        0
    end
  end

  defp calculate_incremental_cost(message, tokens) do
    # Cost per 1K tokens (approximate)
    cost_per_1k = 0.003

    case message.type do
      :assistant -> tokens * cost_per_1k / 1000
      # Tool use is more expensive
      :tool_use -> tokens * cost_per_1k * 1.5 / 1000
      _ -> 0.0
    end
  end

  defp emit_message_telemetry(message, acc, step_name) do
    :telemetry.execute(
      [:pipeline, :enhanced_claude, :stream, :message],
      %{
        message_count: acc.message_count,
        total_tokens: acc.total_tokens,
        timestamp: System.monotonic_time()
      },
      %{
        message_type: message.type,
        step_name: step_name
      }
    )
  end

  defp emit_cost_telemetry(acc, step_name) do
    # Calculate tokens per second if we have timing data
    tokens_per_second =
      if not is_nil(acc.first_token_time) and acc.last_token_time > acc.first_token_time do
        elapsed_seconds = (acc.last_token_time - acc.first_token_time) / 1000
        if elapsed_seconds > 0, do: acc.total_tokens / elapsed_seconds, else: 0.0
      else
        0.0
      end

    :telemetry.execute(
      [:pipeline, :enhanced_claude, :stream, :cost],
      %{
        progressive_cost: acc.cost_accumulator,
        total_tokens: acc.total_tokens,
        tokens_per_second: tokens_per_second
      },
      %{step_name: step_name}
    )
  end

  defp execute_mock_async_query(prompt, options) do
    Logger.debug("🎭 Creating mock async streaming response")

    # Emit telemetry event for stream start (same as live mode)
    :telemetry.execute(
      [:pipeline, :enhanced_claude, :stream, :start],
      %{timestamp: System.monotonic_time()},
      %{
        prompt_length: String.length(prompt),
        options: options
      }
    )

    # Create a mock stream that emits messages over time
    mock_stream = create_mock_message_stream(prompt, options)

    step_name = get_option(options, "step_name", "mock_enhanced_claude")

    # Create enhanced async response with the mock stream
    async_response = create_enhanced_async_response(mock_stream, step_name, prompt, options)

    {:ok, async_response}
  end

  defp create_mock_message_stream(prompt, options) do
    preset = get_option(options, "preset", "development")

    # Create a stream that emits mock messages
    Stream.resource(
      # Start function
      fn ->
        %{
          messages_sent: 0,
          max_messages: 5,
          preset: preset,
          prompt_length: String.length(prompt)
        }
      end,
      # Next function
      fn state ->
        if state.messages_sent < state.max_messages do
          # Simulate processing delay
          :timer.sleep(100)

          message = create_mock_stream_message(state)
          new_state = %{state | messages_sent: state.messages_sent + 1}

          {[message], new_state}
        else
          {:halt, state}
        end
      end,
      # Cleanup function
      fn _state -> :ok end
    )
  end

  defp create_mock_stream_message(state) do
    case state.messages_sent do
      0 ->
        # System message
        %ClaudeCodeSDK.Message{
          type: :system,
          subtype: :info,
          data: %{
            session_id: "mock-session-#{:rand.uniform(10000)}",
            message: "Mock enhanced streaming session started"
          }
        }

      n when n == state.max_messages - 1 ->
        # Result message
        %ClaudeCodeSDK.Message{
          type: :result,
          subtype: :success,
          data: %{
            session_id: "mock-session",
            total_cost_usd: calculate_mock_cost(state.preset),
            num_turns: 1,
            duration_ms: 500
          }
        }

      _ ->
        # Assistant message
        %ClaudeCodeSDK.Message{
          type: :assistant,
          subtype: nil,
          data: %{
            message: %{
              "content" => "Mock chunk #{state.messages_sent} for preset #{state.preset}. ",
              "role" => "assistant"
            },
            tokens: 10 + :rand.uniform(20)
          }
        }
    end
  end

  # Mock-specific helper functions

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
      # Higher cost due to verbose mode
      "development" -> 0.002
      # Lower cost due to restrictions
      "production" -> 0.001
      # Medium cost for analysis
      "analysis" -> 0.0015
      # Lowest cost for simple chat
      "chat" -> 0.0005
      # Minimal cost for testing
      "test" -> 0.0001
      _ -> 0.001
    end
  end

  defp should_simulate_retry(options) do
    retry_config = get_option(options, "retry_config", %{})
    max_retries = Map.get(retry_config, "max_retries", 0)

    # 10% chance of simulating retry scenario if retries are enabled
    max_retries > 0 and :rand.uniform(10) == 1
  end

  defp add_retry_simulation(response) do
    # Simulate a successful retry after initial failure
    retry_info = %{
      "retry_info" => %{
        "attempts_made" => 2,
        "max_retries" => 3,
        "retry_successful" => true,
        "simulated_retry" => true
      }
    }

    enhanced_response = Map.merge(response, retry_info)
    {:ok, enhanced_response}
  end
end
