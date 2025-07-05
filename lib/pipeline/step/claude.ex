defmodule Pipeline.Step.Claude do
  @moduledoc """
  Claude step executor - handles all Claude (Muscle) operations.

  Supports both synchronous and asynchronous streaming modes.
  """

  require Logger
  alias Pipeline.{PromptBuilder, TestMode}
  alias Pipeline.Streaming.{AsyncResponse, AsyncHandler}

  @doc """
  Execute a Claude step.
  """
  def execute(step, context) do
    Logger.info("💪 Executing Claude step: #{step["name"]}")

    # Build prompt from configuration
    prompt = PromptBuilder.build(step["prompt"], context.results)

    # Get Claude options
    options = step["claude_options"] || %{}

    # Add step name to options for better tracking
    options = Map.put(options, "step_name", step["name"])

    # Get provider (mock or live based on test mode)
    provider = TestMode.provider_for(:ai)

    # Execute query
    case provider.query(prompt, options) do
      {:ok, %AsyncResponse{} = async_response} ->
        # Handle async streaming response
        handle_async_response(async_response, step, options)

      {:ok, response} ->
        # Handle standard synchronous response
        Logger.info("✅ Claude step completed successfully")
        {:ok, response}

      {:error, reason} ->
        Logger.error("❌ Claude step failed: #{reason}")
        {:error, reason}
    end
  end

  # Private functions

  defp handle_async_response(async_response, step, options) do
    Logger.info("🌊 Processing async streaming response for step: #{step["name"]}")

    # Determine how to handle the stream based on configuration
    cond do
      # Option to collect stream into sync response
      Map.get(options, "collect_stream", false) ->
        collect_stream_to_sync(async_response)

      # Use configured stream handler
      Map.has_key?(options, "stream_handler") ->
        process_with_stream_handler(async_response, options)

      # Default: use console handler
      true ->
        process_with_default_handler(async_response)
    end
  end

  defp collect_stream_to_sync(async_response) do
    Logger.debug("📦 Collecting async stream into synchronous response")

    case AsyncResponse.to_sync_response(async_response) do
      {:ok, sync_response} ->
        Logger.info("✅ Stream collection completed successfully")
        {:ok, sync_response}

      {:error, reason} ->
        Logger.error("❌ Failed to collect stream: #{reason}")
        {:error, "Stream collection failed: #{reason}"}
    end
  end

  defp process_with_stream_handler(async_response, options) do
    handler_type = Map.get(options, "stream_handler", "console")
    handler_module = get_handler_module(handler_type)

    Logger.debug("🔧 Processing stream with handler: #{handler_type}")

    # Build handler options
    handler_options = %{
      buffer_size: Map.get(options, "stream_buffer_size", 10),
      handler_module: handler_module,
      handler_opts: Map.get(options, "stream_handler_opts", %{})
    }

    # Process the stream through the handler
    case AsyncHandler.process_stream(AsyncResponse.unwrap_stream(async_response), handler_options) do
      {:ok, _result} ->
        # Mark the async response as completed
        completed_response = AsyncResponse.mark_completed(async_response)
        metrics = AsyncResponse.get_metrics(completed_response)

        # Return a result that includes streaming metadata
        result = %{
          success: true,
          text: "Stream processed successfully",
          streaming_metrics: metrics,
          async_streaming: true
        }

        Logger.info("✅ Stream processing completed successfully")
        {:ok, result}

      {:error, reason} ->
        # Mark as interrupted
        _interrupted_response = AsyncResponse.mark_interrupted(async_response)
        Logger.error("❌ Stream processing failed: #{reason}")
        {:error, "Stream processing failed: #{reason}"}
    end
  rescue
    error ->
      Logger.error("💥 Stream handler crashed: #{inspect(error)}")
      _interrupted_response = AsyncResponse.mark_interrupted(async_response)
      {:error, "Stream handler crashed: #{Exception.message(error)}"}
  end

  defp process_with_default_handler(async_response) do
    Logger.debug("🖥️ Processing stream with default console handler")

    # Use the console handler by default
    handler_options =
      AsyncHandler.console_handler_options(%{
        format_options: %{
          show_stats: true,
          show_tool_use: true
        }
      })

    case AsyncHandler.process_stream(AsyncResponse.unwrap_stream(async_response), handler_options) do
      {:ok, _result} ->
        completed_response = AsyncResponse.mark_completed(async_response)
        metrics = AsyncResponse.get_metrics(completed_response)

        result = %{
          success: true,
          text: "Stream displayed to console",
          streaming_metrics: metrics,
          async_streaming: true
        }

        Logger.info("✅ Console streaming completed successfully")
        {:ok, result}

      {:error, reason} ->
        _interrupted_response = AsyncResponse.mark_interrupted(async_response)
        Logger.error("❌ Console streaming failed: #{reason}")
        {:error, "Console streaming failed: #{reason}"}
    end
  end

  defp get_handler_module(handler_type) do
    case handler_type do
      "console" -> AsyncHandler.ConsoleHandler
      "file" -> Pipeline.Streaming.Handlers.FileHandler
      "callback" -> Pipeline.Streaming.Handlers.CallbackHandler
      "buffer" -> Pipeline.Streaming.Handlers.BufferHandler
      custom when is_binary(custom) -> String.to_existing_atom("Elixir.#{custom}")
      module when is_atom(module) -> module
    end
  rescue
    _error ->
      Logger.warning("Unknown handler type: #{inspect(handler_type)}, using console")
      AsyncHandler.ConsoleHandler
  end
end
