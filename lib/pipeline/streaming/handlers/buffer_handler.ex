defmodule Pipeline.Streaming.Handlers.BufferHandler do
  @moduledoc """
  Memory buffer handler for async message streams.

  This handler collects streaming messages into memory buffers with support for:
  - Configurable buffer size limits
  - Automatic buffer rotation when full
  - Message deduplication
  - Circular buffer option for fixed memory usage
  - Memory usage monitoring
  """

  @behaviour Pipeline.Streaming.AsyncHandler

  require Logger

  defstruct [
    :buffer,
    :buffer_size,
    :max_buffer_size,
    :circular_buffer,
    :deduplicate,
    :memory_limit,
    :rotation_callback,
    :rotated_buffers,
    :message_count,
    :dropped_count,
    :memory_usage,
    :start_time
  ]

  @type buffer_entry :: %{
          message: Pipeline.Streaming.AsyncHandler.message(),
          timestamp: integer(),
          sequence: non_neg_integer()
        }

  @type t :: %__MODULE__{
          buffer: [buffer_entry()],
          buffer_size: non_neg_integer(),
          max_buffer_size: non_neg_integer(),
          circular_buffer: boolean(),
          deduplicate: boolean(),
          memory_limit: non_neg_integer() | nil,
          rotation_callback: function() | nil,
          rotated_buffers: [buffer_entry()],
          message_count: non_neg_integer(),
          dropped_count: non_neg_integer(),
          memory_usage: non_neg_integer(),
          start_time: integer()
        }

  @default_max_buffer_size 1000
  # 50MB
  @default_memory_limit 50 * 1024 * 1024

  @impl true
  def init(opts) do
    max_buffer_size = Map.get(opts, :max_buffer_size, @default_max_buffer_size)
    memory_limit = Map.get(opts, :memory_limit, @default_memory_limit)
    circular_buffer = Map.get(opts, :circular_buffer, false)
    deduplicate = Map.get(opts, :deduplicate, false)
    rotation_callback = Map.get(opts, :rotation_callback)

    # Validate rotation callback
    if rotation_callback && !is_function(rotation_callback, 1) do
      {:error, "rotation_callback must be a function with arity 1"}
    else
      init_buffer_handler(
        max_buffer_size,
        memory_limit,
        circular_buffer,
        deduplicate,
        rotation_callback
      )
    end
  end

  defp init_buffer_handler(
         max_buffer_size,
         memory_limit,
         circular_buffer,
         deduplicate,
         rotation_callback
       ) do
    state = %__MODULE__{
      buffer: [],
      buffer_size: 0,
      max_buffer_size: max_buffer_size,
      circular_buffer: circular_buffer,
      deduplicate: deduplicate,
      memory_limit: memory_limit,
      rotation_callback: rotation_callback,
      rotated_buffers: [],
      message_count: 0,
      dropped_count: 0,
      memory_usage: 0,
      start_time: System.monotonic_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_message(message, state) do
    entry = create_buffer_entry(message, state.message_count)

    # Check for duplicates if enabled
    if state.deduplicate && is_duplicate?(entry, state.buffer) do
      {:ok, state}
    else
      add_to_buffer(entry, state)
    end
  end

  @impl true
  def handle_batch(messages, state) do
    entries =
      messages
      |> Enum.with_index(state.message_count)
      |> Enum.map(fn {message, index} -> create_buffer_entry(message, index) end)

    # Filter duplicates if enabled
    filtered_entries =
      if state.deduplicate do
        filter_duplicates(entries, state.buffer)
      else
        entries
      end

    add_batch_to_buffer(filtered_entries, state)
  end

  @impl true
  def handle_stream_end(state) do
    duration = System.monotonic_time(:millisecond) - state.start_time

    Logger.info(
      "BufferHandler completed: #{state.message_count} messages buffered " <>
        "(#{state.dropped_count} dropped) in #{duration}ms, " <>
        "memory usage: #{format_bytes(state.memory_usage)}"
    )

    {:ok, state}
  end

  @impl true
  def handle_stream_error(error, state) do
    # Add error to buffer as special entry
    error_entry = %{
      message: %{type: :stream_error, data: error},
      timestamp: System.monotonic_time(:millisecond),
      sequence: state.message_count
    }

    case add_to_buffer(error_entry, state) do
      {:ok, _new_state} ->
        {:error, "Stream error buffered: #{inspect(error)}"}

      {:error, reason} ->
        {:error, "Stream error and buffer error: #{inspect({error, reason})}"}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    # Buffers are in memory, no cleanup needed
    :ok
  end

  # Public API for accessing buffer contents

  @doc """
  Get all messages from the buffer.
  """
  @spec get_messages(t()) :: [Pipeline.Streaming.AsyncHandler.message()]
  def get_messages(state) do
    state.buffer
    |> Enum.reverse()
    |> Enum.map(& &1.message)
  end

  @doc """
  Get messages from the buffer with metadata.
  """
  @spec get_entries(t()) :: [buffer_entry()]
  def get_entries(state) do
    Enum.reverse(state.buffer)
  end

  @doc """
  Get messages of a specific type.
  """
  @spec get_messages_by_type(t(), atom()) :: [Pipeline.Streaming.AsyncHandler.message()]
  def get_messages_by_type(state, type) do
    state.buffer
    |> Enum.filter(fn entry -> entry.message.type == type end)
    |> Enum.reverse()
    |> Enum.map(& &1.message)
  end

  @doc """
  Get buffer statistics.
  """
  @spec get_stats(t()) :: map()
  def get_stats(state) do
    duration = System.monotonic_time(:millisecond) - state.start_time

    %{
      message_count: state.message_count,
      buffer_size: state.buffer_size,
      max_buffer_size: state.max_buffer_size,
      dropped_count: state.dropped_count,
      memory_usage: state.memory_usage,
      memory_limit: state.memory_limit,
      duration_ms: duration,
      rotated_buffers: length(state.rotated_buffers)
    }
  end

  @doc """
  Clear the buffer.
  """
  @spec clear_buffer(t()) :: t()
  def clear_buffer(state) do
    %{state | buffer: [], buffer_size: 0, memory_usage: 0}
  end

  # Private functions

  defp create_buffer_entry(message, sequence) do
    %{
      message: message,
      timestamp: System.monotonic_time(:millisecond),
      sequence: sequence
    }
  end

  defp is_duplicate?(entry, buffer) do
    Enum.any?(buffer, fn existing ->
      messages_equal?(entry.message, existing.message)
    end)
  end

  defp messages_equal?(%{type: type, data: data1}, %{type: type, data: data2}) do
    # Simple equality check - could be enhanced for specific message types
    data1 == data2
  end

  defp messages_equal?(_, _), do: false

  defp filter_duplicates(entries, existing_buffer) do
    # Build set of unique entries from the list itself, then filter against existing buffer
    {unique_entries, _seen} =
      Enum.reduce(entries, {[], MapSet.new()}, fn entry, {acc, seen} ->
        message_key = {entry.message.type, entry.message.data}

        if MapSet.member?(seen, message_key) or is_duplicate?(entry, existing_buffer) do
          {acc, seen}
        else
          {[entry | acc], MapSet.put(seen, message_key)}
        end
      end)

    Enum.reverse(unique_entries)
  end

  defp add_to_buffer(entry, state) do
    entry_size = estimate_entry_size(entry)
    new_memory = state.memory_usage + entry_size

    # Check memory limit
    if state.memory_limit && new_memory > state.memory_limit do
      handle_memory_limit_exceeded(entry, state)
    else
      # Check buffer size limit
      if state.buffer_size >= state.max_buffer_size do
        handle_buffer_full(entry, state)
      else
        # Add to buffer
        new_buffer = [entry | state.buffer]

        new_state = %{
          state
          | buffer: new_buffer,
            buffer_size: state.buffer_size + 1,
            message_count: state.message_count + 1,
            memory_usage: new_memory
        }

        {:ok, new_state}
      end
    end
  end

  defp add_batch_to_buffer(entries, state) do
    Enum.reduce_while(entries, {:ok, state}, fn entry, {:ok, acc_state} ->
      case add_to_buffer(entry, acc_state) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp handle_buffer_full(entry, state) do
    if state.circular_buffer do
      # Remove oldest entry and add new one
      [oldest | rest] = Enum.reverse(state.buffer)
      oldest_size = estimate_entry_size(oldest)
      entry_size = estimate_entry_size(entry)

      new_buffer = [entry | Enum.reverse(rest)]
      new_memory = state.memory_usage - oldest_size + entry_size

      new_state = %{
        state
        | buffer: new_buffer,
          message_count: state.message_count + 1,
          memory_usage: new_memory,
          dropped_count: state.dropped_count + 1
      }

      {:ok, new_state}
    else
      # Rotate buffer if callback provided
      if state.rotation_callback do
        rotate_buffer(entry, state)
      else
        # Drop the message
        new_state = %{
          state
          | dropped_count: state.dropped_count + 1,
            message_count: state.message_count + 1
        }

        Logger.warning("Buffer full, dropping message: #{inspect(entry.message.type)}")
        {:ok, new_state}
      end
    end
  end

  defp handle_memory_limit_exceeded(entry, state) do
    if state.circular_buffer do
      # Remove oldest entries until we have space
      free_memory_for_entry(entry, state)
    else
      # Drop the message
      new_state = %{
        state
        | dropped_count: state.dropped_count + 1,
          message_count: state.message_count + 1
      }

      Logger.warning("Memory limit exceeded, dropping message: #{inspect(entry.message.type)}")
      {:ok, new_state}
    end
  end

  defp free_memory_for_entry(entry, state) do
    entry_size = estimate_entry_size(entry)
    available_memory = state.memory_limit - state.memory_usage

    if entry_size <= available_memory do
      add_to_buffer(entry, state)
    else
      # Remove oldest entries until we have space
      {new_buffer, new_memory, dropped} =
        remove_oldest_entries(state.buffer, state.memory_usage, entry_size, state.memory_limit, 0)

      new_state = %{
        state
        | buffer: new_buffer,
          buffer_size: length(new_buffer),
          memory_usage: new_memory,
          dropped_count: state.dropped_count + dropped
      }

      add_to_buffer(entry, new_state)
    end
  end

  defp remove_oldest_entries(buffer, current_memory, needed_size, limit, dropped_count) do
    available = limit - current_memory

    if available >= needed_size or buffer == [] do
      {buffer, current_memory, dropped_count}
    else
      [oldest | rest] = Enum.reverse(buffer)
      oldest_size = estimate_entry_size(oldest)
      new_memory = current_memory - oldest_size

      remove_oldest_entries(
        Enum.reverse(rest),
        new_memory,
        needed_size,
        limit,
        dropped_count + 1
      )
    end
  end

  defp rotate_buffer(entry, state) do
    # Call rotation callback with current buffer
    try do
      state.rotation_callback.(state.buffer)

      # Clear buffer and add new entry
      entry_size = estimate_entry_size(entry)

      new_state = %{
        state
        | buffer: [entry],
          buffer_size: 1,
          message_count: state.message_count + 1,
          memory_usage: entry_size,
          rotated_buffers: state.rotated_buffers ++ [length(state.buffer)]
      }

      {:ok, new_state}
    rescue
      e ->
        Logger.error("Buffer rotation callback error: #{inspect(e)}")
        {:error, "Buffer rotation failed: #{inspect(e)}"}
    end
  end

  defp estimate_entry_size(entry) do
    # Rough estimate of memory usage
    message_size = estimate_message_size(entry.message)
    # 32 bytes for the entry struct overhead
    32 + message_size
  end

  defp estimate_message_size(%{type: type, data: data}) do
    type_size = byte_size(Atom.to_string(type))
    data_size = estimate_data_size(data)
    # 16 bytes for message struct overhead
    16 + type_size + data_size
  end

  defp estimate_data_size(data) when is_binary(data), do: byte_size(data)

  defp estimate_data_size(data) when is_map(data) do
    data
    |> Map.values()
    |> Enum.reduce(0, fn
      val, acc when is_binary(val) -> acc + byte_size(val)
      val, acc when is_atom(val) -> acc + byte_size(Atom.to_string(val))
      val, acc when is_integer(val) -> acc + 8
      val, acc when is_float(val) -> acc + 8
      # rough estimate for other types
      _val, acc -> acc + 32
    end)
  end

  # rough estimate for unknown types
  defp estimate_data_size(_), do: 32

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end
