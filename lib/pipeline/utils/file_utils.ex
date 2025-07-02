defmodule Pipeline.Utils.FileUtils do
  @moduledoc """
  File utility functions for pipeline file operations.

  Provides comprehensive file manipulation capabilities including:
  - File operations (copy, move, delete)
  - File validation (existence, size, permissions)
  - Format conversion (CSV, JSON, YAML, XML)
  - Path resolution and workspace management
  - Streaming operations for large files (>100MB)
  - Memory-efficient file processing
  """

  require Logger

  @large_file_threshold 100_000_000  # 100MB
  @stream_chunk_size 1024 * 1024     # 1MB chunks

  @doc """
  Resolve a path relative to the workspace directory.
  """
  @spec resolve_path(String.t(), String.t()) :: String.t()
  def resolve_path(path, workspace_dir) do
    if Path.type(path) == :absolute do
      path
    else
      Path.join(workspace_dir, path)
    end
  end

  @doc """
  Copy a file from source to destination with error handling.
  """
  @spec copy_file(String.t(), String.t()) :: :ok | {:error, String.t()}
  def copy_file(source, destination) do
    with :ok <- ensure_source_exists(source),
         :ok <- ensure_destination_dir(destination),
         {:ok, _} <- File.copy(source, destination) do
      Logger.debug("File copied: #{source} -> #{destination}")
      :ok
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "Copy failed: #{:file.format_error(reason)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Move a file from source to destination with error handling.
  """
  @spec move_file(String.t(), String.t()) :: :ok | {:error, String.t()}
  def move_file(source, destination) do
    with :ok <- ensure_source_exists(source),
         :ok <- ensure_destination_dir(destination),
         :ok <- File.rename(source, destination) do
      Logger.debug("File moved: #{source} -> #{destination}")
      :ok
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "Move failed: #{:file.format_error(reason)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete a file or directory with error handling.
  """
  @spec delete_file(String.t()) :: :ok | {:error, String.t()}
  def delete_file(path) do
    cond do
      File.regular?(path) ->
        case File.rm(path) do
          :ok ->
            Logger.debug("File deleted: #{path}")
            :ok

          {:error, reason} ->
            {:error, "Delete failed: #{:file.format_error(reason)}"}
        end

      File.dir?(path) ->
        case File.rm_rf(path) do
          {:ok, _} ->
            Logger.debug("Directory deleted: #{path}")
            :ok

          {:error, reason, _} ->
            {:error, "Delete failed: #{:file.format_error(reason)}"}
        end

      true ->
        {:error, "Path does not exist: #{path}"}
    end
  end

  @doc """
  List files in a directory with optional pattern matching.
  """
  @spec list_files(String.t(), String.t() | nil) :: {:ok, [String.t()]} | {:error, String.t()}
  def list_files(path, pattern \\ nil) do
    cond do
      not File.exists?(path) ->
        {:error, "Path does not exist: #{path}"}

      not File.dir?(path) ->
        {:error, "Path is not a directory: #{path}"}

      true ->
        case File.ls(path) do
          {:ok, files} ->
            filtered_files =
              if pattern do
                Enum.filter(files, &String.match?(&1, ~r/#{pattern}/))
              else
                files
              end

            {:ok, Enum.map(filtered_files, &Path.join(path, &1))}

          {:error, reason} ->
            {:error, "List failed: #{:file.format_error(reason)}"}
        end
    end
  end

  @doc """
  Validate file properties according to given criteria.
  """
  @spec validate_file(String.t(), map()) :: :ok | {:error, String.t()}
  def validate_file(path, criteria) do
    with :ok <- validate_existence(path, criteria),
         :ok <- validate_type(path, criteria),
         :ok <- validate_size(path, criteria),
         :ok <- validate_permissions(path, criteria) do
      :ok
    end
  end

  @doc """
  Convert file format from source to destination.
  """
  @spec convert_format(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def convert_format(source, destination, format) do
    with :ok <- ensure_source_exists(source),
         :ok <- ensure_destination_dir(destination),
         {:ok, content} <- File.read(source),
         {:ok, converted} <- perform_conversion(content, format),
         :ok <- File.write(destination, converted) do
      Logger.debug("File converted: #{source} -> #{destination} (#{format})")
      :ok
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "Conversion failed: #{:file.format_error(reason)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp ensure_source_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Source file does not exist: #{path}"}
    end
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

  defp validate_existence(path, criteria) do
    must_exist = Map.get(criteria, "must_exist", true)
    exists = File.exists?(path)

    cond do
      must_exist and not exists ->
        {:error, "File must exist but does not: #{path}"}

      not must_exist and exists ->
        {:error, "File must not exist but does: #{path}"}

      true ->
        :ok
    end
  end

  defp validate_type(path, criteria) do
    cond do
      Map.get(criteria, "must_be_file", false) and not File.regular?(path) ->
        {:error, "Path must be a file: #{path}"}

      Map.get(criteria, "must_be_dir", false) and not File.dir?(path) ->
        {:error, "Path must be a directory: #{path}"}

      true ->
        :ok
    end
  end

  defp validate_size(path, criteria) do
    if File.regular?(path) do
      case File.stat(path) do
        {:ok, %{size: size}} ->
          cond do
            Map.has_key?(criteria, "min_size") and size < criteria["min_size"] ->
              {:error, "File too small: #{size} < #{criteria["min_size"]} bytes"}

            Map.has_key?(criteria, "max_size") and size > criteria["max_size"] ->
              {:error, "File too large: #{size} > #{criteria["max_size"]} bytes"}

            true ->
              :ok
          end

        {:error, reason} ->
          {:error, "Cannot read file stats: #{:file.format_error(reason)}"}
      end
    else
      :ok
    end
  end

  defp validate_permissions(path, criteria) do
    cond do
      Map.get(criteria, "must_be_readable", false) and not readable?(path) ->
        {:error, "File must be readable: #{path}"}

      Map.get(criteria, "must_be_writable", false) and not writable?(path) ->
        {:error, "File must be writable: #{path}"}

      true ->
        :ok
    end
  end

  defp readable?(path) do
    case File.read(path) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp writable?(path) do
    if File.exists?(path) do
      case File.stat(path) do
        {:ok, %{access: access}} -> access in [:read_write, :write]
        _ -> false
      end
    else
      dir = Path.dirname(path)
      File.dir?(dir) and File.exists?(dir)
    end
  end

  defp perform_conversion(content, format) do
    case format do
      "csv_to_json" -> csv_to_json(content)
      "json_to_csv" -> json_to_csv(content)
      "yaml_to_json" -> yaml_to_json(content)
      "json_to_yaml" -> json_to_yaml(content)
      "xml_to_json" -> xml_to_json(content)
      "json_to_xml" -> json_to_xml(content)
      _ -> {:error, "Unsupported format conversion: #{format}"}
    end
  end

  defp csv_to_json(csv_content) do
    try do
      lines = String.split(csv_content, "\n", trim: true)

      case lines do
        [] ->
          {:ok, "[]"}

        [header | rows] ->
          headers = String.split(header, ",") |> Enum.map(&String.trim/1)

          json_data =
            Enum.map(rows, fn row ->
              values = String.split(row, ",") |> Enum.map(&String.trim/1)
              Enum.zip(headers, values) |> Enum.into(%{})
            end)

          {:ok, Jason.encode!(json_data)}
      end
    rescue
      e -> {:error, "CSV parsing failed: #{Exception.message(e)}"}
    end
  end

  defp json_to_csv(json_content) do
    try do
      case Jason.decode(json_content) do
        {:ok, data} when is_list(data) and length(data) > 0 ->
          first_item = hd(data)
          headers = Map.keys(first_item)

          header_line = Enum.join(headers, ",")

          data_lines =
            Enum.map(data, fn item ->
              Enum.map(headers, fn header ->
                Map.get(item, header, "")
              end)
              |> Enum.join(",")
            end)

          csv_content = [header_line | data_lines] |> Enum.join("\n")
          {:ok, csv_content}

        {:ok, _} ->
          {:error, "JSON must be an array of objects for CSV conversion"}

        {:error, reason} ->
          {:error, "JSON parsing failed: #{inspect(reason)}"}
      end
    rescue
      e -> {:error, "JSON to CSV conversion failed: #{Exception.message(e)}"}
    end
  end

  defp yaml_to_json(yaml_content) do
    try do
      case YamlElixir.read_from_string(yaml_content) do
        {:ok, data} ->
          {:ok, Jason.encode!(data)}

        {:error, reason} ->
          {:error, "YAML parsing failed: #{inspect(reason)}"}
      end
    rescue
      e -> {:error, "YAML to JSON conversion failed: #{Exception.message(e)}"}
    end
  end

  defp json_to_yaml(_json_content) do
    {:error,
     "JSON to YAML conversion not yet implemented - YamlElixir write functionality not available"}
  end

  defp xml_to_json(_xml_content) do
    {:error, "XML to JSON conversion not yet implemented"}
  end

  defp json_to_xml(_json_content) do
    {:error, "JSON to XML conversion not yet implemented"}
  end

  # Streaming Operations

  @doc """
  Copy a large file using streaming to avoid memory issues.
  """
  @spec stream_copy_file(String.t(), String.t()) :: :ok | {:error, String.t()}
  def stream_copy_file(source, destination) do
    with :ok <- ensure_source_exists(source),
         :ok <- ensure_destination_dir(destination),
         {:ok, size} <- get_file_size(source) do
      
      if size > @large_file_threshold do
        Logger.info("📁 Streaming large file copy: #{format_bytes(size)}")
        stream_copy_large_file(source, destination)
      else
        copy_file(source, destination)
      end
    else
      error -> error
    end
  end

  @doc """
  Read a file in chunks using streaming.
  Returns a stream that yields binary chunks.
  """
  @spec stream_read_file(String.t()) :: Stream.t() | {:error, String.t()}
  def stream_read_file(path) do
    case File.exists?(path) do
      true ->
        File.stream!(path, [:read, :binary], @stream_chunk_size)
      false ->
        {:error, "File does not exist: #{path}"}
    end
  end

  @doc """
  Write data to a file using streaming.
  """
  @spec stream_write_file(String.t(), Stream.t()) :: :ok | {:error, String.t()}
  def stream_write_file(path, data_stream) do
    try do
      ensure_destination_dir(path)
      
      File.open!(path, [:write, :binary], fn file ->
        data_stream
        |> Stream.each(&IO.binwrite(file, &1))
        |> Stream.run()
      end)
      
      Logger.debug("Streamed write completed: #{path}")
      :ok
    rescue
      error ->
        {:error, "Stream write failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Process a large file line by line with a given function.
  Memory-efficient for large text files.
  """
  @spec stream_process_lines(String.t(), (String.t() -> String.t())) :: {:ok, String.t()} | {:error, String.t()}
  def stream_process_lines(source_path, processor_fn) do
    temp_path = "#{source_path}.tmp"
    
    try do
      source_path
      |> File.stream!()
      |> Stream.map(processor_fn)
      |> Stream.into(File.stream!(temp_path))
      |> Stream.run()
      
      # Replace original with processed file
      case File.rename(temp_path, source_path) do
        :ok -> {:ok, source_path}
        {:error, reason} -> 
          File.rm(temp_path)
          {:error, "Failed to replace file: #{:file.format_error(reason)}"}
      end
    rescue
      error ->
        File.rm(temp_path)
        {:error, "Stream processing failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Get file size efficiently.
  """
  @spec get_file_size(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def get_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, "Cannot get file size: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Check if a file should be processed using streaming based on size.
  """
  @spec should_use_streaming?(String.t()) :: boolean()
  def should_use_streaming?(path) do
    case get_file_size(path) do
      {:ok, size} -> size > @large_file_threshold
      {:error, _} -> false
    end
  end

  @doc """
  Process a file with automatic streaming decision.
  """
  @spec smart_process_file(String.t(), (String.t() -> any())) :: {:ok, any()} | {:error, String.t()}
  def smart_process_file(path, processor_fn) do
    case should_use_streaming?(path) do
      true ->
        Logger.info("📁 Using streaming for large file: #{path}")
        stream_process_large_file(path, processor_fn)
      false ->
        case File.read(path) do
          {:ok, content} -> {:ok, processor_fn.(content)}
          {:error, reason} -> {:error, "Failed to read file: #{:file.format_error(reason)}"}
        end
    end
  end

  # Private streaming functions

  defp stream_copy_large_file(source, destination) do
    try do
      source
      |> File.stream!([:read, :binary], @stream_chunk_size)
      |> Stream.into(File.stream!(destination, [:write, :binary]))
      |> Stream.run()
      
      Logger.debug("Streamed copy completed: #{source} -> #{destination}")
      :ok
    rescue
      error ->
        {:error, "Stream copy failed: #{Exception.message(error)}"}
    end
  end

  defp stream_process_large_file(path, processor_fn) do
    try do
      content = 
        path
        |> File.stream!([:read, :binary], @stream_chunk_size)
        |> Enum.reduce("", fn chunk, acc -> acc <> chunk end)
      
      {:ok, processor_fn.(content)}
    rescue
      error ->
        {:error, "Stream processing failed: #{Exception.message(error)}"}
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end
