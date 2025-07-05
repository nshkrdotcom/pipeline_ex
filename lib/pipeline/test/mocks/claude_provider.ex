defmodule Pipeline.Test.Mocks.ClaudeProvider do
  @moduledoc """
  Mock implementation of Claude provider for testing.
  """

  alias Pipeline.Streaming.AsyncResponse

  def query(prompt, options \\ %{}) do
    # Check if async streaming is requested
    if get_option_value(options, "async_streaming", :async_streaming, false) do
      # First try to find async-specific pattern
      case find_matching_pattern("__async__" <> prompt) do
        {:ok, response} when is_function(response) ->
          result = response.(prompt)
          {:ok, result}

        _ ->
          # Fall back to regular async handling
          handle_async_query(prompt, options)
      end
    else
      # Regular sync handling
      case find_matching_pattern(prompt) do
        {:ok, response} when is_function(response) ->
          # Handle function responses (for async mocks returning sync)
          result = response.(prompt)

          case result do
            response when is_map(response) ->
              enhanced_response = enhance_response_with_options(response, options)
              {:ok, enhanced_response}

            other ->
              {:ok, other}
          end

        {:ok, response} ->
          # Handle error responses
          case response do
            %{"success" => false, "error" => error_msg} ->
              {:error, error_msg}

            _ ->
              enhanced_response = enhance_response_with_options(response, options)
              {:ok, enhanced_response}
          end

        :not_found ->
          handle_fallback_patterns(prompt, options)
      end
    end
  end

  defp handle_fallback_patterns(prompt, options) do
    base_response =
      case prompt do
        "simple test" ->
          %{"text" => "Mock response for simple test", "success" => true, "cost" => 0.001}

        "error test" ->
          {:error, "Mock error for testing"}

        prompt when is_binary(prompt) ->
          handle_content_based_patterns(prompt)

        _ ->
          %{"text" => "Mock response", "success" => true, "cost" => 0.001}
      end

    case base_response do
      {:error, _} = error ->
        error

      response when is_map(response) ->
        enhanced_response = enhance_response_with_options(response, options)
        {:ok, enhanced_response}
    end
  end

  defp handle_content_based_patterns(prompt) do
    cond do
      String.contains?(prompt, "Python") ->
        %{"text" => "Mock Python code response", "success" => true, "cost" => 0.002}

      String.contains?(prompt, "calculator") ->
        %{"text" => "Mock calculator implementation", "success" => true, "cost" => 0.004}

      true ->
        %{
          "text" => "Mock response for: #{String.slice(prompt, 0, 50)}...",
          "success" => true,
          "cost" => 0.001
        }
    end
  end

  def set_response_pattern(pattern, response) do
    Process.put({:mock_response, pattern}, response)
  end

  def set_streaming_response_pattern(pattern, response_fn) when is_function(response_fn) do
    # Store async streaming patterns with a special prefix
    Process.put({:mock_response, "__async__" <> pattern}, response_fn)
    :ok
  end

  def reset do
    # Clear all mock responses
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:mock_response, _}, key) end)
    |> Enum.each(&Process.delete/1)

    :ok
  end

  defp find_matching_pattern(prompt) do
    # Get all mock response keys and sort by pattern length (longest first)
    # This ensures more specific patterns are matched before generic ones
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:mock_response, _}, key) end)
    |> Enum.sort_by(fn {_, pattern} -> -String.length(pattern) end)
    |> Enum.find_value(:not_found, fn {_, pattern} ->
      if pattern == "" or String.contains?(prompt, pattern) do
        {:ok, Process.get({:mock_response, pattern})}
      else
        nil
      end
    end)
  end

  # Enhanced response function for claude_smart step support
  defp enhance_response_with_options(response, options) when is_map(response) do
    # Add preset information if available
    enhanced_response =
      if Map.has_key?(options, "preset") do
        preset = options["preset"]

        # Update cost based on preset
        preset_cost = calculate_preset_cost(preset)

        # Add claude_smart_metadata
        metadata = %{
          "preset_applied" => preset,
          "environment_aware" => Map.get(options, "environment_aware", false),
          "optimization_applied" => true
        }

        # Enhance text with preset-specific content
        enhanced_text = enhance_text_for_preset(response["text"], preset)

        response
        |> Map.put("cost", preset_cost)
        |> Map.put("claude_smart_metadata", metadata)
        |> Map.put("text", enhanced_text)
        |> Map.put("enhanced_provider", true)
      else
        response
      end

    # Add session information if available
    enhanced_response =
      if Map.has_key?(options, "session_id") do
        session_info = %{
          "session_id" => options["session_id"],
          "session_name" => options["session_name"] || "default",
          "session_active" => true
        }

        Map.merge(enhanced_response, session_info)
      else
        enhanced_response
      end

    enhanced_response
  end

  defp enhance_response_with_options(response, _options), do: response

  defp calculate_preset_cost(preset) do
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

  defp enhance_text_for_preset(text, preset) do
    base_text = text || "Mock enhanced Claude response"

    preset_suffix =
      case preset do
        "development" -> " with development optimizations applied"
        "production" -> " with production safety constraints"
        "analysis" -> " with detailed analysis capabilities"
        "chat" -> " in conversational mode"
        "test" -> " optimized for testing"
        _ -> " with default settings"
      end

    "#{base_text}#{preset_suffix}"
  end

  # Async streaming support

  defp handle_async_query(prompt, options) do
    # Create a mock stream of messages
    messages = create_mock_message_stream(prompt, options)

    # Extract step name from options if available
    step_name = options["step_name"] || options[:step_name] || "mock_claude_query"

    # Create AsyncResponse wrapper
    async_response =
      AsyncResponse.new(messages, step_name,
        handler: options[:stream_handler] || options["stream_handler"],
        buffer_size: get_option_value(options, "stream_buffer_size", :stream_buffer_size, 10),
        metadata: %{
          prompt_length: String.length(prompt),
          started_at: DateTime.utc_now(),
          mock: true
        }
      )

    {:ok, async_response}
  end

  defp create_mock_message_stream(prompt, options) do
    # Create a stream that simulates Claude messages with realistic timing

    # Determine response characteristics based on prompt
    {message_count, total_tokens, delay_pattern} = determine_stream_characteristics(prompt)

    # Generate messages
    messages = generate_stream_messages(prompt, message_count, total_tokens)

    # Add delays if in benchmark mode
    if options[:benchmark_mode] || options["benchmark_mode"] do
      add_streaming_delays(messages, delay_pattern)
    else
      Stream.map(messages, & &1)
    end
  end

  defp determine_stream_characteristics(prompt) do
    cond do
      String.contains?(prompt, "5 items") ->
        # Small response
        {4, 50, :fast}

      String.contains?(prompt, "25 items") ->
        # Medium response
        {10, 500, :medium}

      String.contains?(prompt, "50 sections") ->
        # Large response
        {20, 2000, :slow}

      true ->
        # Default
        {5, 100, :fast}
    end
  end

  defp generate_stream_messages(prompt, message_count, total_tokens) do
    tokens_per_message = div(total_tokens, message_count)

    # Initial system message
    messages = [
      %{
        type: :system,
        subtype: :init,
        data: %{
          session_id: "mock_session_#{:rand.uniform(9999)}",
          model: "claude-3-opus-20240229"
        }
      }
    ]

    # Content messages
    content_messages =
      Enum.map(1..message_count, fn i ->
        %{
          type: :assistant,
          content: "Part #{i} of response to: #{String.slice(prompt, 0, 30)}...",
          data: %{tokens: tokens_per_message}
        }
      end)

    # Final result message
    result_message = %{
      type: :result,
      subtype: :success,
      data: %{
        session_id: "mock_session_#{:rand.uniform(9999)}",
        total_tokens: total_tokens,
        duration_ms: message_count * 100
      }
    }

    messages ++ content_messages ++ [result_message]
  end

  defp add_streaming_delays(messages, delay_pattern) do
    delays =
      case delay_pattern do
        # Fast response
        :fast -> [50, 20, 20, 20, 10]
        # Medium response
        :medium -> [100, 50, 50, 50, 30]
        # Slow response
        :slow -> [200, 100, 100, 100, 50]
      end

    Stream.unfold({messages, delays, 0}, fn
      {[], _, _} ->
        nil

      {[msg | rest], [delay | rest_delays], _} ->
        Process.sleep(delay)
        {msg, {rest, rest_delays ++ [delay], 0}}

      {[msg | rest], [], _} ->
        # Default delay
        Process.sleep(20)
        {msg, {rest, [], 0}}
    end)
  end

  defp get_option_value(options, string_key, atom_key, default) do
    options[string_key] || options[atom_key] || default
  end
end
