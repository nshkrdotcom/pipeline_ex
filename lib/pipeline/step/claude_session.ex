defmodule Pipeline.Step.ClaudeSession do
  @moduledoc """
  Claude Session step executor - handles claude_session step type with session management integration.

  Claude Session steps provide persistent conversational sessions that can:
  - Maintain conversation context across multiple interactions
  - Persist sessions for later continuation
  - Checkpoint session state at regular intervals
  - Resume sessions after restarts
  """

  require Logger
  alias Pipeline.{OptionBuilder, PromptBuilder, TestMode}

  @doc """
  Execute a claude_session step with session management.
  """
  def execute(step, context) do
    Logger.info("🎯 Executing Claude Session step: #{step["name"]}")

    try do
      with {:ok, session_manager} <- get_session_manager(context),
           {:ok, session_info} <- ensure_session_exists(step, session_manager),
           {:ok, enhanced_options} <- build_enhanced_options(step, context, session_info),
           prompt <- PromptBuilder.build(step["prompt"], context.results),
           {:ok, provider} <- get_provider(context),
           {:ok, response} <-
             execute_with_session(provider, prompt, enhanced_options, session_info, step) do
        # Handle checkpointing if needed
        maybe_checkpoint_session(session_manager, session_info, response, step)

        Logger.info("✅ Claude Session step completed successfully")
        {:ok, response}
      else
        {:error, reason} ->
          Logger.error("❌ Claude Session step failed: #{reason}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("💥 Claude Session step crashed: #{inspect(error)}")
        {:error, "Claude Session step crashed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions

  defp get_session_manager(_context) do
    # In mock mode, use the mock session manager
    case TestMode.get_mode() do
      :mock ->
        {:ok, Pipeline.Test.Mocks.SessionManager}

      _ ->
        # In live mode, would use real session manager
        {:ok, Pipeline.SessionManager}
    end
  end

  defp ensure_session_exists(step, session_manager) do
    session_config = step["session_config"]
    session_name = session_config["session_name"] || step["name"]

    case session_manager.get_session(session_name) do
      nil ->
        # Create new session
        Logger.debug("🆕 Creating new session: #{session_name}")
        create_new_session(session_manager, session_name, session_config)

      existing_session ->
        # Use existing session
        Logger.debug("🔄 Using existing session: #{session_name}")
        {:ok, existing_session}
    end
  end

  defp create_new_session(session_manager, session_name, session_config) do
    session_options = %{
      "persist" => session_config["persist"] || false,
      "continue_on_restart" => session_config["continue_on_restart"] || false,
      "checkpoint_frequency" => session_config["checkpoint_frequency"] || 5,
      "description" => session_config["description"] || "Automated session"
    }

    case session_manager.create_session(session_name, session_options) do
      {:ok, session} -> {:ok, session}
      session when is_map(session) -> {:ok, session}
      error -> {:error, "Failed to create session: #{inspect(error)}"}
    end
  end

  defp build_enhanced_options(step, context, session_info) do
    # Start with basic enhanced Claude options
    base_options = step["claude_options"] || %{}

    # Apply OptionBuilder for consistency with other step types
    preset = get_preset_for_session(step, context)
    enhanced_options = OptionBuilder.merge(preset, base_options)

    # Add session-specific options
    session_options = %{
      "session_id" => session_info["session_id"],
      "session_name" => session_info["session_name"],
      "session_config" => step["session_config"],
      # Preserve preset for mock provider
      "preset" => preset
    }

    final_options = Map.merge(enhanced_options, session_options)

    Logger.debug("🎯 Claude Session options built with session: #{session_info["session_id"]}")
    {:ok, final_options}
  rescue
    error ->
      Logger.error("💥 Failed to build session options: #{inspect(error)}")
      {:error, "Failed to build session options: #{Exception.message(error)}"}
  end

  defp get_preset_for_session(step, context) do
    # Use analysis preset as default for sessions (good for conversation analysis)
    step["preset"] ||
      get_in(context.config, ["workflow", "defaults", "claude_preset"]) ||
      "analysis"
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

  defp execute_with_session(provider, prompt, options, session_info, step) do
    Logger.debug("🚀 Executing Claude Session with provider #{inspect(provider)}")
    Logger.debug("📋 Session: #{session_info["session_id"]}")

    case provider.query(prompt, options) do
      {:ok, response} ->
        # Enhance response with session information
        enhanced_response = add_session_metadata(response, session_info, step)
        {:ok, enhanced_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_session_metadata(response, session_info, step) when is_map(response) do
    session_metadata = %{
      "session_id" => session_info["session_id"],
      "session_name" => session_info["session_name"],
      "session_persisted" => get_in(step, ["session_config", "persist"]) || false,
      "checkpoint_frequency" => get_in(step, ["session_config", "checkpoint_frequency"]) || 5,
      "continue_on_restart" => get_in(step, ["session_config", "continue_on_restart"]) || false
    }

    Map.put(response, "claude_session_metadata", session_metadata)
  end

  defp add_session_metadata(response, _session_info, _step), do: response

  defp maybe_checkpoint_session(session_manager, session_info, response, step) do
    session_config = step["session_config"]
    checkpoint_frequency = session_config["checkpoint_frequency"] || 5

    # For simplicity, always checkpoint for now
    # In a real implementation, this would track interaction count
    if checkpoint_frequency > 0 do
      Logger.debug("💾 Checkpointing session: #{session_info["session_id"]}")

      checkpoint_data = %{
        "last_response" => response,
        "step_name" => step["name"],
        "timestamp" => DateTime.utc_now()
      }

      case session_manager.checkpoint_session(session_info["session_id"], checkpoint_data) do
        {:ok, _checkpoint} ->
          Logger.debug("✅ Session checkpointed successfully")

        error ->
          Logger.warning("⚠️ Failed to checkpoint session: #{inspect(error)}")
      end
    end
  end
end
