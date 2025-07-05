defmodule Pipeline.Streaming.Handlers.FileHandler do
  @moduledoc """
  File output handler for async message streams.

  This handler writes streaming messages to a file with support for:
  - Automatic file rotation based on size
  - JSON and plain text output formats
  - Buffered writes for performance
  - Atomic file operations
  - Compression support
  """

  @behaviour Pipeline.Streaming.AsyncHandler

  require Logger

  defstruct [
    :file_path,
    :file,
    :format,
    :buffer,
    :buffer_size,
    :bytes_written,
    :max_file_size,
    :rotation_count,
    :compress_on_rotation,
    :message_count,
    :start_time
  ]

  @type t :: %__MODULE__{
          file_path: String.t(),
          file: File.io_device() | nil,
          format: :json | :text | :jsonl,
          buffer: iolist(),
          buffer_size: non_neg_integer(),
          bytes_written: non_neg_integer(),
          max_file_size: non_neg_integer() | nil,
          rotation_count: non_neg_integer(),
          compress_on_rotation: boolean(),
          message_count: non_neg_integer(),
          start_time: integer()
        }

  @default_buffer_size 4096
  # 100MB
  @default_max_file_size 100 * 1024 * 1024

  @impl true
  def init(opts) do
    file_path = Map.get(opts, :file_path) || generate_default_path()
    format = Map.get(opts, :format, :text) |> validate_format()
    buffer_size = Map.get(opts, :buffer_size, @default_buffer_size)
    max_file_size = Map.get(opts, :max_file_size, @default_max_file_size)
    compress = Map.get(opts, :compress_on_rotation, false)

    # Ensure directory exists
    case ensure_destination_dir(file_path) do
      :ok ->
        case open_file(file_path, format) do
          {:ok, file} ->
            state = %__MODULE__{
              file_path: file_path,
              file: file,
              format: format,
              buffer: [],
              buffer_size: buffer_size,
              bytes_written: 0,
              max_file_size: max_file_size,
              rotation_count: 0,
              compress_on_rotation: compress,
              message_count: 0,
              start_time: System.monotonic_time(:millisecond)
            }

            _ = write_header(state)
            {:ok, state}

          {:error, reason} ->
            {:error, "Failed to open file: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to create directory: #{reason}"}
    end
  end

  @impl true
  def handle_message(message, state) do
    formatted = format_message(message, state.format)
    new_buffer = [state.buffer, formatted]
    buffer_size = IO.iodata_length(new_buffer)

    new_state = %{state | buffer: new_buffer, message_count: state.message_count + 1}

    if buffer_size >= state.buffer_size do
      flush_buffer(new_state)
    else
      {:ok, new_state}
    end
  end

  @impl true
  def handle_batch(messages, state) do
    formatted_messages = Enum.map(messages, &format_message(&1, state.format))
    new_buffer = [state.buffer | formatted_messages]

    new_state = %{
      state
      | buffer: new_buffer,
        message_count: state.message_count + length(messages)
    }

    flush_buffer(new_state)
  end

  @impl true
  def handle_stream_end(state) do
    with {:ok, state} <- flush_buffer(state),
         :ok <- write_footer(state),
         :ok <- close_file(state) do
      duration = System.monotonic_time(:millisecond) - state.start_time

      Logger.info(
        "FileHandler completed: #{state.message_count} messages written to #{state.file_path} in #{duration}ms"
      )

      {:ok, state}
    else
      {:error, reason} ->
        {:error, "Failed to finalize file: #{reason}"}
    end
  end

  @impl true
  def handle_stream_error(error, state) do
    error_msg = format_error_message(error)

    # Try to write error and close cleanly
    _ = IO.write(state.file, error_msg)
    _ = close_file(state)

    {:error, "Stream error: #{inspect(error)}"}
  end

  @impl true
  def terminate(_reason, %__MODULE__{file: file} = state) when not is_nil(file) do
    _ = flush_buffer(state)
    _ = File.close(file)
    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  # Private functions

  defp generate_default_path do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    Path.join(System.tmp_dir!(), "claude_stream_#{timestamp}.txt")
  end

  defp validate_format(format) when format in [:json, :text, :jsonl], do: format
  defp validate_format(_), do: :text

  defp open_file(path, :json) do
    File.open(path, [:write, :utf8])
  end

  defp open_file(path, _format) do
    File.open(path, [:write, :utf8])
  end

  defp write_header(%{format: :json} = state) do
    _ = IO.write(state.file, "{\n  \"messages\": [\n")
    :ok
  end

  defp write_header(_state), do: :ok

  defp write_footer(%{format: :json} = state) do
    # Remove trailing comma if any messages were written
    _ =
      if state.message_count > 0 do
        # Seek back to overwrite the last comma
        case :file.position(state.file, :cur) do
          {:ok, pos} ->
            _ = :file.position(state.file, pos - 2)

          {:error, _reason} ->
            # Continue even if positioning fails
            :ok
        end
      end

    _ = IO.write(state.file, "\n  ],\n  \"metadata\": " <> format_metadata(state) <> "\n}")
    :ok
  end

  defp write_footer(_state), do: :ok

  defp format_metadata(state) do
    metadata = %{
      message_count: state.message_count,
      duration_ms: System.monotonic_time(:millisecond) - state.start_time,
      bytes_written: state.bytes_written,
      rotation_count: state.rotation_count
    }

    Jason.encode!(metadata, pretty: true)
  end

  defp format_message(message, :json) do
    json = Jason.encode!(message_to_map(message), pretty: true)
    json <> ",\n"
  end

  defp format_message(message, :jsonl) do
    json = Jason.encode!(message_to_map(message))
    json <> "\n"
  end

  defp format_message(message, :text) do
    format_text_message(message) <> "\n"
  end

  defp message_to_map(%{type: type, data: data}) do
    %{
      type: type,
      data: data,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp format_text_message(%{type: :text, data: %{content: content}}), do: content

  defp format_text_message(%{type: :tool_use, data: data}) do
    "[Tool Use: #{data.name} (#{data.id})]"
  end

  defp format_text_message(%{type: :tool_result, data: data}) do
    "[Tool Result: #{inspect(data.content, limit: 100)}]"
  end

  defp format_text_message(%{type: :error, data: data}) do
    "[Error: #{inspect(data)}]"
  end

  defp format_text_message(%{type: :token_usage, data: data}) do
    "[Tokens: Input=#{data.input_tokens}, Output=#{data.output_tokens}]"
  end

  defp format_text_message(message) do
    "[#{message.type}: #{inspect(message.data, limit: 100)}]"
  end

  defp format_error_message(error) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    "\n[STREAM ERROR at #{timestamp}]: #{inspect(error)}\n"
  end

  defp flush_buffer(%{buffer: []} = state), do: {:ok, state}

  defp flush_buffer(state) do
    data = IO.iodata_to_binary(state.buffer)
    data_size = byte_size(data)

    try do
      :ok = IO.write(state.file, data)
      new_bytes = state.bytes_written + data_size
      new_state = %{state | buffer: [], bytes_written: new_bytes}

      # Check if rotation is needed
      if state.max_file_size && new_bytes > state.max_file_size do
        rotate_file(new_state)
      else
        {:ok, new_state}
      end
    rescue
      e in File.Error ->
        {:error, "Write failed: #{Exception.message(e)}"}

      e ->
        {:error, "Write failed: #{inspect(e)}"}
    end
  end

  defp rotate_file(state) do
    Logger.info("Rotating file: #{state.file_path} (#{state.bytes_written} bytes)")

    # Close current file
    :ok = File.close(state.file)

    # Generate rotation name
    rotation_path = "#{state.file_path}.#{state.rotation_count}"

    # Rename current file
    case File.rename(state.file_path, rotation_path) do
      :ok ->
        # Optionally compress
        _ =
          if state.compress_on_rotation do
            spawn(fn -> compress_file(rotation_path) end)
          end

        # Open new file
        case open_file(state.file_path, state.format) do
          {:ok, new_file} ->
            new_state = %{
              state
              | file: new_file,
                bytes_written: 0,
                rotation_count: state.rotation_count + 1
            }

            _ = write_header(new_state)
            {:ok, new_state}

          {:error, reason} ->
            {:error, "Failed to open new file after rotation: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to rotate file: #{reason}"}
    end
  end

  defp compress_file(path) do
    Logger.info("Compressing rotated file: #{path}")

    case System.cmd("gzip", [path]) do
      {_, 0} ->
        Logger.info("Successfully compressed: #{path}.gz")

      {error, _} ->
        Logger.warning("Failed to compress #{path}: #{error}")
    end
  end

  defp close_file(%{file: nil}), do: :ok

  defp close_file(%{file: file}) do
    File.close(file)
  end

  defp ensure_destination_dir(path) do
    dir = Path.dirname(path)

    case File.mkdir_p(dir) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "Cannot create destination directory: #{:file.format_error(reason)}"}
    end
  end
end
