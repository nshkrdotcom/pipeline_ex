defmodule Pipeline.Streaming.ResultStream do
  @moduledoc """
  Result streaming capabilities for pipeline execution.
  
  Provides memory-efficient result passing between steps by streaming
  large results instead of keeping them in memory.
  """

  require Logger

  @large_result_threshold 10_000_000  # 10MB
  @stream_chunk_size 1_000_000        # 1MB chunks

  defstruct [
    :id,
    :source_step,
    :data_type,
    :stream_ref,
    :metadata,
    :created_at
  ]

  @type t :: %__MODULE__{}

  @doc """
  Create a result stream from a large result.
  """
  @spec create_stream(String.t(), String.t(), any(), map()) :: {:ok, t()} | {:error, String.t()}
  def create_stream(step_name, result_key, data, metadata \\ %{}) do
    result_size = calculate_result_size(data)
    
    if should_stream_result?(result_size) do
      Logger.info("📊 Creating result stream for #{step_name}:#{result_key} (#{format_bytes(result_size)})")
      do_create_stream(step_name, result_key, data, metadata, result_size)
    else
      {:error, "Result too small for streaming: #{format_bytes(result_size)}"}
    end
  end

  @doc """
  Check if a result should be streamed based on size.
  """
  @spec should_stream_result?(non_neg_integer()) :: boolean()
  def should_stream_result?(size) do
    size > @large_result_threshold
  end

  @doc """
  Read data from a result stream.
  """
  @spec read_stream(t()) :: {:ok, any()} | {:error, String.t()}
  def read_stream(%__MODULE__{} = stream) do
    case stream.data_type do
      :binary ->
        read_binary_stream(stream)
      :json ->
        read_json_stream(stream)
      :list ->
        read_list_stream(stream)
      :map ->
        read_map_stream(stream)
      _ ->
        {:error, "Unsupported stream data type: #{stream.data_type}"}
    end
  end

  @doc """
  Stream data from a result stream in chunks.
  """
  @spec stream_chunks(t()) :: {:ok, Stream.t()} | {:error, String.t()}
  def stream_chunks(%__MODULE__{} = stream) do
    case stream.data_type do
      :binary ->
        {:ok, stream_binary_chunks(stream)}
      :list ->
        {:ok, stream_list_chunks(stream)}
      _ ->
        {:error, "Chunk streaming not supported for data type: #{stream.data_type}"}
    end
  end

  @doc """
  Transform a stream with a function.
  """
  @spec transform_stream(t(), (any() -> any())) :: {:ok, t()} | {:error, String.t()}
  def transform_stream(%__MODULE__{} = stream, transform_fn) do
    case read_stream(stream) do
      {:ok, data} ->
        try do
          transformed_data = transform_fn.(data)
          create_stream(
            "#{stream.source_step}_transformed",
            "transformed",
            transformed_data,
            Map.put(stream.metadata, :transformed, true)
          )
        rescue
          error ->
            {:error, "Stream transformation failed: #{Exception.message(error)}"}
        end
      
      error ->
        error
    end
  end

  @doc """
  Clean up a result stream and free resources.
  """
  @spec cleanup_stream(t()) :: :ok
  def cleanup_stream(%__MODULE__{} = stream) do
    case stream.stream_ref do
      {:file, path} ->
        File.rm(path)
        Logger.debug("🗑️  Cleaned up stream file: #{path}")
      
      {:memory, _pid} ->
        # Memory-based streams are cleaned up by GC
        :ok
        
      _ ->
        :ok
    end
  end

  @doc """
  Get metadata about a stream.
  """
  @spec get_stream_info(t()) :: map()
  def get_stream_info(%__MODULE__{} = stream) do
    %{
      id: stream.id,
      source_step: stream.source_step,
      data_type: stream.data_type,
      created_at: stream.created_at,
      metadata: stream.metadata
    }
  end

  # Private Functions

  defp do_create_stream(step_name, result_key, data, metadata, result_size) do
    stream_id = generate_stream_id(step_name, result_key)
    data_type = detect_data_type(data)
    
    case create_stream_storage(data, data_type, stream_id) do
      {:ok, stream_ref} ->
        stream = %__MODULE__{
          id: stream_id,
          source_step: step_name,
          data_type: data_type,
          stream_ref: stream_ref,
          metadata: Map.merge(metadata, %{
            size_bytes: result_size,
            result_key: result_key
          }),
          created_at: DateTime.utc_now()
        }
        
        {:ok, stream}
        
      {:error, reason} ->
        {:error, "Failed to create stream storage: #{reason}"}
    end
  end

  defp create_stream_storage(data, data_type, stream_id) do
    temp_dir = System.tmp_dir!()
    stream_file = Path.join(temp_dir, "pipeline_stream_#{stream_id}")
    
    case data_type do
      :binary ->
        File.write(stream_file, data)
        {:ok, {:file, stream_file}}
        
      :json ->
        case Jason.encode(data) do
          {:ok, json_data} ->
            File.write(stream_file, json_data)
            {:ok, {:file, stream_file}}
          {:error, reason} ->
            {:error, "JSON encoding failed: #{inspect(reason)}"}
        end
        
      :list ->
        serialized = :erlang.term_to_binary(data)
        File.write(stream_file, serialized)
        {:ok, {:file, stream_file}}
        
      :map ->
        serialized = :erlang.term_to_binary(data)
        File.write(stream_file, serialized)
        {:ok, {:file, stream_file}}
        
      _ ->
        {:error, "Unsupported data type for streaming: #{data_type}"}
    end
  rescue
    error ->
      {:error, "Stream storage creation failed: #{Exception.message(error)}"}
  end

  defp read_binary_stream(%__MODULE__{stream_ref: {:file, path}}) do
    case File.read(path) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Failed to read binary stream: #{:file.format_error(reason)}"}
    end
  end

  defp read_json_stream(%__MODULE__{stream_ref: {:file, path}}) do
    case File.read(path) do
      {:ok, json_data} ->
        case Jason.decode(json_data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, "JSON decode failed: #{inspect(reason)}"}
        end
      {:error, reason} ->
        {:error, "Failed to read JSON stream: #{:file.format_error(reason)}"}
    end
  end

  defp read_list_stream(%__MODULE__{stream_ref: {:file, path}}) do
    case File.read(path) do
      {:ok, serialized} ->
        try do
          data = :erlang.binary_to_term(serialized)
          {:ok, data}
        rescue
          error ->
            {:error, "Failed to deserialize list: #{Exception.message(error)}"}
        end
      {:error, reason} ->
        {:error, "Failed to read list stream: #{:file.format_error(reason)}"}
    end
  end

  defp read_map_stream(%__MODULE__{stream_ref: {:file, path}}) do
    case File.read(path) do
      {:ok, serialized} ->
        try do
          data = :erlang.binary_to_term(serialized)
          {:ok, data}
        rescue
          error ->
            {:error, "Failed to deserialize map: #{Exception.message(error)}"}
        end
      {:error, reason} ->
        {:error, "Failed to read map stream: #{:file.format_error(reason)}"}
    end
  end

  defp stream_binary_chunks(%__MODULE__{stream_ref: {:file, path}}) do
    File.stream!(path, [:read, :binary], @stream_chunk_size)
  end

  defp stream_list_chunks(%__MODULE__{} = stream) do
    case read_list_stream(stream) do
      {:ok, list} when is_list(list) ->
        list
        |> Stream.chunk_every(1000)  # Chunk lists into smaller sublists
      {:ok, _} ->
        Stream.cycle([]) |> Stream.take(0)
      {:error, _} ->
        Stream.cycle([]) |> Stream.take(0)
    end
  end

  defp calculate_result_size(data) when is_binary(data) do
    byte_size(data)
  end

  defp calculate_result_size(data) do
    data
    |> :erlang.term_to_binary()
    |> byte_size()
  end

  defp detect_data_type(data) when is_binary(data), do: :binary
  defp detect_data_type(data) when is_list(data), do: :list
  defp detect_data_type(data) when is_map(data) do
    # Try to determine if it's JSON-serializable
    case Jason.encode(data) do
      {:ok, _} -> :json
      {:error, _} -> :map
    end
  end
  defp detect_data_type(_data), do: :unknown

  defp generate_stream_id(step_name, result_key) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    hash = :crypto.hash(:md5, "#{step_name}_#{result_key}_#{timestamp}") |> Base.encode16(case: :lower)
    String.slice(hash, 0, 16)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end