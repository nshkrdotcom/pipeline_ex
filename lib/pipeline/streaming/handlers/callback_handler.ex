defmodule Pipeline.Streaming.Handlers.CallbackHandler do
  @moduledoc """
  Custom callback handler for async message streams.

  This handler allows users to provide custom functions to process messages with support for:
  - Message filtering by type
  - Asynchronous callback execution
  - Error handling and recovery
  - State management across callbacks
  - Rate limiting and throttling
  """

  @behaviour Pipeline.Streaming.AsyncHandler

  require Logger

  defstruct [
    :callback_fn,
    :error_handler,
    :filter_fn,
    :async_callbacks,
    :rate_limit,
    :last_callback_time,
    :callback_count,
    :error_count,
    :user_state,
    :start_time
  ]

  @type callback_fn :: (Pipeline.Streaming.AsyncHandler.message(), any() ->
                          {:ok, any()} | {:error, any()})
  @type error_handler_fn :: (any(), Pipeline.Streaming.AsyncHandler.message(), any() ->
                               {:ok, any()} | {:error, any()})
  @type filter_fn :: (Pipeline.Streaming.AsyncHandler.message() -> boolean())

  @type t :: %__MODULE__{
          callback_fn: callback_fn(),
          error_handler: error_handler_fn() | nil,
          filter_fn: filter_fn() | nil,
          async_callbacks: boolean(),
          rate_limit: non_neg_integer() | nil,
          last_callback_time: integer() | nil,
          callback_count: non_neg_integer(),
          error_count: non_neg_integer(),
          user_state: any(),
          start_time: integer()
        }

  @impl true
  def init(opts) do
    callback_fn = Map.get(opts, :callback_fn)

    unless is_function(callback_fn, 2) do
      {:error, "callback_fn must be a function with arity 2"}
    else
      error_handler = Map.get(opts, :error_handler)

      if error_handler && !is_function(error_handler, 3) do
        {:error, "error_handler must be a function with arity 3"}
      else
        filter_fn = Map.get(opts, :filter_fn)

        if filter_fn && !is_function(filter_fn, 1) do
          {:error, "filter_fn must be a function with arity 1"}
        else
          init_handler(callback_fn, error_handler, filter_fn, opts)
        end
      end
    end
  end

  defp init_handler(callback_fn, error_handler, filter_fn, opts) do
    state = %__MODULE__{
      callback_fn: callback_fn,
      error_handler: error_handler,
      filter_fn: filter_fn,
      async_callbacks: Map.get(opts, :async_callbacks, false),
      rate_limit: Map.get(opts, :rate_limit_ms),
      last_callback_time: nil,
      callback_count: 0,
      error_count: 0,
      user_state: Map.get(opts, :initial_state),
      start_time: System.monotonic_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_message(message, state) do
    if should_process_message?(message, state) do
      execute_callback(message, state)
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_batch(messages, state) do
    filtered_messages =
      if state.filter_fn do
        Enum.filter(messages, state.filter_fn)
      else
        messages
      end

    if state.async_callbacks do
      # Execute callbacks asynchronously
      execute_async_batch(filtered_messages, state)
    else
      # Execute callbacks synchronously
      execute_sync_batch(filtered_messages, state)
    end
  end

  @impl true
  def handle_stream_end(state) do
    # Wait for any pending async callbacks to complete
    if state.async_callbacks do
      # Give callbacks time to complete
      Process.sleep(100)
    end

    duration = System.monotonic_time(:millisecond) - state.start_time

    Logger.info(
      "CallbackHandler completed: #{state.callback_count} callbacks (#{state.error_count} errors) in #{duration}ms"
    )

    {:ok, state}
  end

  @impl true
  def handle_stream_error(error, state) do
    if state.error_handler do
      try do
        case state.error_handler.(error, nil, state.user_state) do
          {:ok, _new_user_state} ->
            {:error, "Stream error handled by user handler"}

          {:error, handler_error} ->
            {:error, "Stream error and handler error: #{inspect({error, handler_error})}"}
        end
      rescue
        e ->
          {:error, "Stream error and handler exception: #{inspect({error, e})}"}
      end
    else
      {:error, "Stream error: #{inspect(error)}"}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    # Clean up any resources if needed
    :ok
  end

  # Private functions

  defp should_process_message?(message, state) do
    # Check filter function
    passes_filter =
      if state.filter_fn do
        try do
          state.filter_fn.(message)
        rescue
          e ->
            Logger.warning("Filter function error: #{inspect(e)}")
            false
        end
      else
        true
      end

    # Check rate limiting
    within_rate_limit =
      if state.rate_limit do
        current_time = System.monotonic_time(:millisecond)

        case state.last_callback_time do
          nil -> true
          last_time -> current_time - last_time >= state.rate_limit
        end
      else
        true
      end

    passes_filter && within_rate_limit
  end

  defp execute_callback(message, state) do
    if state.async_callbacks do
      execute_async_callback(message, state)
    else
      execute_sync_callback(message, state)
    end
  end

  defp execute_sync_callback(message, state) do
    current_time = System.monotonic_time(:millisecond)

    try do
      case state.callback_fn.(message, state.user_state) do
        {:ok, new_user_state} ->
          new_state = %{
            state
            | callback_count: state.callback_count + 1,
              last_callback_time: current_time,
              user_state: new_user_state
          }

          {:ok, new_state}

        {:error, callback_error} ->
          handle_callback_error(callback_error, message, state)
      end
    rescue
      e ->
        handle_callback_error(e, message, state)
    end
  end

  defp execute_async_callback(message, state) do
    current_time = System.monotonic_time(:millisecond)

    # Spawn async task but don't wait for it
    spawn(fn ->
      try do
        case state.callback_fn.(message, state.user_state) do
          {:ok, _} ->
            :ok

          {:error, error} ->
            Logger.warning("Async callback error: #{inspect(error)}")
        end
      rescue
        e ->
          Logger.warning("Async callback exception: #{inspect(e)}")
      end
    end)

    new_state = %{
      state
      | callback_count: state.callback_count + 1,
        last_callback_time: current_time
    }

    {:ok, new_state}
  end

  defp execute_sync_batch(messages, state) do
    Enum.reduce_while(messages, {:ok, state}, fn message, {:ok, acc_state} ->
      case execute_sync_callback(message, acc_state) do
        {:ok, new_state} ->
          {:cont, {:ok, new_state}}

        {:error, _reason} ->
          # Continue processing but record the error - don't halt the entire batch
          error_state = %{acc_state | error_count: acc_state.error_count + 1}
          {:halt, {:ok, error_state}}
      end
    end)
  end

  defp execute_async_batch(messages, state) do
    # Execute all callbacks asynchronously
    Enum.each(messages, fn message ->
      spawn(fn ->
        try do
          case state.callback_fn.(message, state.user_state) do
            {:ok, _} ->
              :ok

            {:error, error} ->
              Logger.warning("Async batch callback error: #{inspect(error)}")
          end
        rescue
          e ->
            Logger.warning("Async batch callback exception: #{inspect(e)}")
        end
      end)
    end)

    current_time = System.monotonic_time(:millisecond)

    new_state = %{
      state
      | callback_count: state.callback_count + length(messages),
        last_callback_time: current_time
    }

    {:ok, new_state}
  end

  defp handle_callback_error(error, message, state) do
    new_error_count = state.error_count + 1

    if state.error_handler do
      try do
        case state.error_handler.(error, message, state.user_state) do
          {:ok, new_user_state} ->
            Logger.warning("Callback error handled by user handler: #{inspect(error)}")
            new_state = %{state | error_count: new_error_count, user_state: new_user_state}
            {:ok, new_state}

          {:error, handler_error} ->
            Logger.error("Callback error and handler error: #{inspect({error, handler_error})}")
            {:error, "Callback error: #{inspect(error)}"}
        end
      rescue
        e ->
          Logger.error("Callback error and handler exception: #{inspect({error, e})}")
          {:error, "Callback error: #{inspect(error)}"}
      end
    else
      Logger.error("Callback error: #{inspect(error)}")

      # Continue processing despite the error
      new_state = %{state | error_count: new_error_count}
      {:ok, new_state}
    end
  end

  # Utility functions for common use cases

  @doc """
  Create a callback handler that prints messages to the console.
  """
  def console_callback(opts \\ %{}) do
    callback_fn = fn message, state ->
      formatted = format_message_for_console(message, opts)
      IO.puts(formatted)
      {:ok, state}
    end

    Map.put(opts, :callback_fn, callback_fn)
  end

  @doc """
  Create a callback handler that collects messages into a list.
  """
  def collector_callback(opts \\ %{}) do
    callback_fn = fn message, messages ->
      {:ok, [message | messages]}
    end

    opts
    |> Map.put(:callback_fn, callback_fn)
    |> Map.put(:initial_state, [])
  end

  @doc """
  Create a callback handler that filters messages by type.
  """
  def type_filter_callback(types, callback_fn, opts \\ %{}) do
    filter_fn = fn message ->
      message.type in types
    end

    opts
    |> Map.put(:callback_fn, callback_fn)
    |> Map.put(:filter_fn, filter_fn)
  end

  defp format_message_for_console(message, opts) do
    show_timestamp = Map.get(opts, :show_timestamp, false)
    show_type = Map.get(opts, :show_type, true)

    parts = []

    parts =
      if show_timestamp do
        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
        [timestamp | parts]
      else
        parts
      end

    parts =
      if show_type do
        ["[#{message.type}]" | parts]
      else
        parts
      end

    content =
      case message do
        %{type: :text, data: %{content: content}} -> content
        %{type: :tool_use, data: data} -> "Tool: #{data.name}"
        %{type: :error, data: data} -> "Error: #{inspect(data)}"
        _ -> inspect(message.data, limit: 100)
      end

    parts = [content | parts]

    Enum.reverse(parts) |> Enum.join(" ")
  end
end
