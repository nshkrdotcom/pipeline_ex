defmodule Pipeline.Debug do
  @moduledoc """
  Debug logging utilities for the pipeline.
  """

  @doc """
  Log a message to the debug file.
  """
  def log(debug_log_path, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    entry = "[#{timestamp}] #{message}\n"
    File.write!(debug_log_path, entry, [:append])
  end

  @doc """
  Find the latest debug log in the output directory.
  """
  def find_latest_debug_log(output_dir) do
    output_path = Path.expand(output_dir)
    
    case File.ls(output_path) do
      {:ok, files} ->
        debug_logs = 
          files
          |> Enum.filter(&String.starts_with?(&1, "debug_"))
          |> Enum.filter(&String.ends_with?(&1, ".log"))
          |> Enum.map(&Path.join(output_path, &1))
          |> Enum.sort_by(&File.stat!(&1).mtime, :desc)
        
        case debug_logs do
          [latest | _] -> {:ok, latest}
          [] -> {:error, "No debug logs found"}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Find all output files (excluding debug logs) in the output directory.
  """
  def find_output_files(output_dir) do
    output_path = Path.expand(output_dir)
    
    with {:ok, files} <- find_files_recursive(output_path, ".json") do
      files
      |> Enum.reject(&String.contains?(&1, "debug"))
      |> Enum.sort_by(&File.stat!(&1).mtime, :desc)
    end
  end

  @doc """
  Find all files created in the workspace directory.
  """
  def find_workspace_files(workspace_dir \\ "workspace") do
    workspace_path = Path.expand(workspace_dir)
    
    if File.exists?(workspace_path) do
      with {:ok, files} <- find_files_recursive(workspace_path) do
        files
        |> Enum.map(fn file ->
          stat = File.stat!(file)
          %{
            path: file,
            size: stat.size,
            mtime: stat.mtime,
            relative_path: Path.relative_to(file, workspace_path)
          }
        end)
        |> Enum.sort_by(& &1.mtime, :desc)
      end
    else
      []
    end
  end

  defp find_files_recursive(dir, extension \\ nil) do
    if File.exists?(dir) do
      files = 
        Path.wildcard(Path.join(dir, "**/*"))
        |> Enum.filter(&File.regular?/1)
      
      files = if extension do
        Enum.filter(files, &String.ends_with?(&1, extension))
      else
        files
      end
      
      {:ok, files}
    else
      {:ok, []}
    end
  end

  @doc """
  Format file size in human readable format.
  """
  def format_size(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} bytes"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
    end
  end

  @doc """
  Format timestamp in human readable format.
  """
  def format_timestamp({{year, month, day}, {hour, minute, second}}) do
    "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(minute)}:#{pad(second)}"
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
end