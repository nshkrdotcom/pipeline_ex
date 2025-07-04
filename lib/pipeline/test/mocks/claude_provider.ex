defmodule Pipeline.Test.Mocks.ClaudeProvider do
  @moduledoc """
  Mock implementation of Claude provider for testing.
  """

  def query(prompt, options \\ %{}) do
    # Check for pattern-specific responses first
    case find_matching_pattern(prompt) do
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
end
