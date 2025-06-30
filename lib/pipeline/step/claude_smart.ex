defmodule Pipeline.Step.ClaudeSmart do
  @moduledoc """
  Claude Smart step executor - handles claude_smart step type with OptionBuilder preset integration.

  Claude Smart steps automatically apply OptionBuilder presets and environment-aware configuration
  to provide optimized settings for different use cases.
  """

  require Logger
  alias Pipeline.{OptionBuilder, PromptBuilder}

  @doc """
  Execute a claude_smart step with preset integration.
  """
  def execute(step, context) do
    Logger.info("🎯 Executing Claude Smart step: #{step["name"]}")

    try do
      with {:ok, enhanced_options} <- build_enhanced_options(step, context),
           prompt <- PromptBuilder.build(step["prompt"], context.results),
           {:ok, provider} <- get_provider(context),
           {:ok, response} <- execute_with_provider(provider, prompt, enhanced_options) do
        Logger.info("✅ Claude Smart step completed successfully")
        {:ok, response}
      else
        {:error, reason} ->
          Logger.error("❌ Claude Smart step failed: #{reason}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("💥 Claude Smart step crashed: #{inspect(error)}")
        {:error, "Claude Smart step crashed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions

  defp build_enhanced_options(step, context) do
    # Get preset from step configuration
    preset = get_preset(step, context)

    # Merge with step-specific claude_options
    step_options = step["claude_options"] || %{}
    enhanced_options = OptionBuilder.merge(preset, step_options)

    # Apply preset-specific optimizations
    optimized_options = OptionBuilder.apply_preset_optimizations(preset, enhanced_options)

    # Ensure preset is preserved in the final options for metadata
    final_options = Map.put(optimized_options, "preset", preset)

    # Also preserve environment_aware flag if present
    final_options =
      if step["environment_aware"] do
        Map.put(final_options, "environment_aware", step["environment_aware"])
      else
        final_options
      end

    Logger.debug(
      "🎯 Claude Smart preset '#{preset}' applied with #{map_size(final_options)} options"
    )

    {:ok, final_options}
  rescue
    error ->
      Logger.error("💥 Failed to build enhanced options: #{inspect(error)}")
      {:error, "Failed to build enhanced options: #{Exception.message(error)}"}
  end

  defp get_preset(step, context) do
    cond do
      # Step-specific preset takes precedence
      step["preset"] ->
        step["preset"]

      # Workflow default preset
      get_in(context.config, ["workflow", "defaults", "claude_preset"]) ->
        get_in(context.config, ["workflow", "defaults", "claude_preset"])

      # Environment-aware detection
      step["environment_aware"] == true ->
        detect_environment_preset(context)

      # Default fallback
      true ->
        "development"
    end
  end

  defp detect_environment_preset(context) do
    # Try to detect from context
    case get_in(context.config, ["workflow", "environment", "mode"]) do
      "development" ->
        "development"

      "production" ->
        "production"

      "test" ->
        "test"

      _ ->
        # Fall back to application environment
        case Application.get_env(:pipeline, :environment, :development) do
          :development -> "development"
          :production -> "production"
          :test -> "test"
          _ -> "development"
        end
    end
  end

  defp get_provider(context) do
    provider_module = determine_provider_module(context)
    {:ok, provider_module}
  end

  defp determine_provider_module(_context) do
    # Check if we're in test mode
    test_mode = Application.get_env(:pipeline, :test_mode, :live)

    case test_mode do
      :mock ->
        Pipeline.Test.Mocks.ClaudeProvider

      _ ->
        # Use enhanced provider for live mode
        Pipeline.Providers.EnhancedClaudeProvider
    end
  end

  defp execute_with_provider(provider, prompt, options) do
    Logger.debug("🚀 Executing Claude Smart with provider #{inspect(provider)}")
    Logger.debug("📋 Options: #{inspect(options, limit: 3)}")

    case provider.query(prompt, options) do
      {:ok, response} ->
        # Enhance response with preset information
        enhanced_response = add_preset_metadata(response, options)
        {:ok, enhanced_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_preset_metadata(response, options) when is_map(response) do
    preset_info = %{
      "preset_applied" => options["preset"] || "unknown",
      "environment_aware" => Map.has_key?(options, "environment_aware"),
      "optimization_applied" => true
    }

    Map.put(response, "claude_smart_metadata", preset_info)
  end

  defp add_preset_metadata(response, _options), do: response
end
