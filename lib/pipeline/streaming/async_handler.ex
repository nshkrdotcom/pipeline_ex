defmodule Pipeline.Streaming.AsyncHandler do
  @moduledoc """
  Behavior and base implementation for handling async message streams from ClaudeCodeSDK.

  This module provides a behavior for implementing custom stream handlers and includes
  a default console handler implementation. It supports message buffering, batching,
  and proper error handling for stream interruptions.
  """

  require Logger

  @default_buffer_size 10
  @default_flush_interval 100

  @type handler_state :: any()
  @type handler_result :: {:ok, handler_state} | {:error, String.t()}
  @type message :: ClaudeCodeSDK.Message.t()
  @type handler_options :: %{
          optional(:buffer_size) => non_neg_integer(),
          optional(:flush_interval) => non_neg_integer(),
          optional(:handler_module) => module(),
          optional(:handler_opts) => map()
        }

  @doc """
  Callback invoked when starting a stream handler.
  """
  @callback init(opts :: map()) :: {:ok, handler_state} | {:error, String.t()}

  @doc """
  Callback invoked when receiving a message from the stream.
  """
  @callback handle_message(message :: message(), state :: handler_state) ::
              {:ok, handler_state} | {:buffer, handler_state} | {:error, String.t()}

  @doc """
  Callback invoked to handle a batch of buffered messages.
  """
  @callback handle_batch(messages :: [message()], state :: handler_state) ::
              {:ok, handler_state} | {:error, String.t()}

  @doc """
  Callback invoked when the stream ends normally.
  """
  @callback handle_stream_end(state :: handler_state) :: handler_result()

  @doc """
  Callback invoked when the stream encounters an error.
  """
  @callback handle_stream_error(error :: any(), state :: handler_state) :: handler_result()

  @doc """
  Callback invoked to clean up resources when terminating.
  """
  @callback terminate(reason :: any(), state :: handler_state) :: :ok

  @doc """
  Process a stream of messages using the specified handler.
  """
  @spec process_stream(Enumerable.t(), handler_options()) :: {:ok, any()} | {:error, String.t()}
  def process_stream(stream, options \\ %{}) do
    options = build_options(options)
    handler_module = options.handler_module

    case handler_module.init(options.handler_opts) do
      {:ok, initial_state} ->
        do_process_stream(stream, handler_module, initial_state, options)

      {:error, reason} = error ->
        Logger.error("Failed to initialize handler #{handler_module}: #{reason}")
        error
    end
  end

  @doc """
  Create a console handler with default options.
  """
  @spec console_handler_options(map()) :: handler_options()
  def console_handler_options(opts \\ %{}) do
    %{
      buffer_size: Map.get(opts, :buffer_size, @default_buffer_size),
      flush_interval: Map.get(opts, :flush_interval, @default_flush_interval),
      handler_module: __MODULE__.ConsoleHandler,
      handler_opts: Map.get(opts, :handler_opts, %{})
    }
  end

  defp build_options(options) when is_map(options) do
    %{
      buffer_size: Map.get(options, :buffer_size, @default_buffer_size),
      flush_interval: Map.get(options, :flush_interval, @default_flush_interval),
      handler_module: Map.get(options, :handler_module, __MODULE__.ConsoleHandler),
      handler_opts: Map.get(options, :handler_opts, %{})
    }
  end

  defp do_process_stream(stream, handler_module, state, options) do
    # Create a simplified state tracking buffer and handler state
    process_state = %{
      handler_state: state,
      buffer: [],
      handler_module: handler_module,
      options: options
    }

    try do
      final_state =
        stream
        |> Enum.reduce(process_state, &process_message/2)
        |> flush_remaining_buffer()

      handler_module.handle_stream_end(final_state.handler_state)
    catch
      {:handler_error, reason, error_state} ->
        handler_module.handle_stream_error(reason, error_state.handler_state)
    end
  end

  defp process_message(message, %{handler_module: handler_module} = process_state) do
    case handler_module.handle_message(message, process_state.handler_state) do
      {:ok, new_handler_state} ->
        %{process_state | handler_state: new_handler_state}

      {:buffer, new_handler_state} ->
        new_buffer = [message | process_state.buffer]

        new_process_state = %{
          process_state
          | handler_state: new_handler_state,
            buffer: new_buffer
        }

        if length(new_buffer) >= process_state.options.buffer_size do
          flush_buffer(new_process_state)
        else
          new_process_state
        end

      {:error, reason} ->
        Logger.error("Handler error processing message: #{inspect(reason)}")
        throw({:handler_error, reason, process_state})
    end
  end

  defp flush_buffer(%{buffer: []} = process_state), do: process_state

  defp flush_buffer(%{buffer: buffer, handler_module: handler_module} = process_state) do
    messages = Enum.reverse(buffer)

    case handler_module.handle_batch(messages, process_state.handler_state) do
      {:ok, new_handler_state} ->
        %{process_state | handler_state: new_handler_state, buffer: []}

      {:error, reason} ->
        throw({:handler_error, reason, process_state})
    end
  end

  defp flush_remaining_buffer(%{buffer: []} = process_state), do: process_state
  defp flush_remaining_buffer(process_state), do: flush_buffer(process_state)

  defmodule ConsoleHandler do
    @moduledoc """
    Default console handler implementation for streaming messages.
    """

    @behaviour Pipeline.Streaming.AsyncHandler

    defstruct [:start_time, :message_count, :format_options]

    @impl true
    def init(opts) do
      state = %__MODULE__{
        start_time: System.monotonic_time(:millisecond),
        message_count: 0,
        format_options: Map.get(opts, :format_options, %{})
      }

      {:ok, state}
    end

    @impl true
    def handle_message(message, state) do
      formatted = format_message(message, state.format_options)
      IO.write(formatted)

      {:ok, %{state | message_count: state.message_count + 1}}
    end

    @impl true
    def handle_batch(messages, state) do
      Enum.each(messages, fn message ->
        formatted = format_message(message, state.format_options)
        IO.write(formatted)
      end)

      {:ok, %{state | message_count: state.message_count + length(messages)}}
    end

    @impl true
    def handle_stream_end(state) do
      duration = System.monotonic_time(:millisecond) - state.start_time

      if Map.get(state.format_options, :show_stats, true) do
        IO.puts("\n\nStream completed: #{state.message_count} messages in #{duration}ms")
      end

      {:ok, state}
    end

    @impl true
    def handle_stream_error(error, _state) do
      IO.puts("\n\nStream error: #{inspect(error)}")
      {:error, "Stream terminated with error: #{inspect(error)}"}
    end

    @impl true
    def terminate(_reason, _state) do
      :ok
    end

    defp format_message(%{type: :text, data: %{content: content}}, _opts) do
      content
    end

    defp format_message(%{type: :tool_use, data: data}, opts) do
      if Map.get(opts, :show_tool_use, true) do
        "\n[Tool: #{data.name}]\n"
      else
        ""
      end
    end

    defp format_message(%{type: :tool_result, data: data}, opts) do
      if Map.get(opts, :show_tool_results, false) do
        "\n[Tool Result: #{inspect(data.content, limit: 100)}]\n"
      else
        ""
      end
    end

    defp format_message(%{type: :result, data: %{session_id: id}}, opts) do
      if Map.get(opts, :show_session_info, false) do
        "\n[Session: #{id}]\n"
      else
        ""
      end
    end

    defp format_message(%{type: :error, data: data}, _opts) do
      "\n[Error: #{inspect(data)}]\n"
    end

    defp format_message(message, opts) do
      if Map.get(opts, :show_raw_messages, false) do
        "\n[Raw: #{inspect(message, limit: 200)}]\n"
      else
        ""
      end
    end
  end
end
