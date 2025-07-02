defmodule Pipeline.Step.FileOps do
  @moduledoc """
  File operations step executor for comprehensive file management.

  Supports operations:
  - copy: Copy files/directories
  - move: Move/rename files/directories
  - delete: Delete files/directories
  - validate: Validate file properties
  - list: List directory contents
  - convert: Convert between file formats
  """

  require Logger
  alias Pipeline.Utils.FileUtils

  @operations ~w(copy move delete validate list convert stream_copy stream_process)

  @doc """
  Execute a file operations step.
  """
  def execute(step, context) do
    Logger.info("📁 Executing file_ops step: #{step["name"]}")

    operation = step["operation"]

    if operation in @operations do
      result = perform_operation(operation, step, context)

      case result do
        {:ok, data} ->
          Logger.info("✅ File operation completed successfully: #{operation}")
          {:ok, data}

        {:error, reason} ->
          Logger.error("❌ File operation failed: #{reason}")
          {:error, reason}
      end
    else
      Logger.error("❌ Unsupported file operation: #{operation}")
      {:error, "Unsupported operation: #{operation}"}
    end
  end

  # Operation handlers

  defp perform_operation("copy", step, context) do
    source = resolve_path(step["source"], context)
    destination = resolve_path(step["destination"], context)

    case FileUtils.copy_file(source, destination) do
      :ok ->
        {:ok,
         %{
           "operation" => "copy",
           "source" => source,
           "destination" => destination,
           "status" => "completed"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_operation("move", step, context) do
    source = resolve_path(step["source"], context)
    destination = resolve_path(step["destination"], context)

    case FileUtils.move_file(source, destination) do
      :ok ->
        {:ok,
         %{
           "operation" => "move",
           "source" => source,
           "destination" => destination,
           "status" => "completed"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_operation("delete", step, context) do
    path = resolve_path(step["path"], context)

    case FileUtils.delete_file(path) do
      :ok ->
        {:ok,
         %{
           "operation" => "delete",
           "path" => path,
           "status" => "completed"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_operation("validate", step, context) do
    files = step["files"] || []

    validation_results =
      Enum.map(files, fn file_spec ->
        path = resolve_path(file_spec["path"], context)
        criteria = Map.drop(file_spec, ["path"])

        case FileUtils.validate_file(path, criteria) do
          :ok ->
            %{
              "path" => path,
              "status" => "valid",
              "criteria" => criteria
            }

          {:error, reason} ->
            %{
              "path" => path,
              "status" => "invalid",
              "error" => reason,
              "criteria" => criteria
            }
        end
      end)

    failed_validations = Enum.filter(validation_results, &(&1["status"] == "invalid"))

    if Enum.empty?(failed_validations) do
      {:ok,
       %{
         "operation" => "validate",
         "results" => validation_results,
         "status" => "all_valid"
       }}
    else
      {:error,
       "Validation failed for #{length(failed_validations)} file(s): #{inspect(failed_validations)}"}
    end
  end

  defp perform_operation("list", step, context) do
    path = resolve_path(step["path"], context)
    pattern = step["pattern"]

    case FileUtils.list_files(path, pattern) do
      {:ok, files} ->
        {:ok,
         %{
           "operation" => "list",
           "path" => path,
           "pattern" => pattern,
           "files" => files,
           "count" => length(files)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_operation("convert", step, context) do
    source = resolve_path(step["source"], context)
    destination = resolve_path(step["destination"], context)
    format = step["format"]

    if format do
      case FileUtils.convert_format(source, destination, format) do
        :ok ->
          {:ok,
           %{
             "operation" => "convert",
             "source" => source,
             "destination" => destination,
             "format" => format,
             "status" => "completed"
           }}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Format conversion type must be specified"}
    end
  end

  defp perform_operation("stream_copy", step, context) do
    source = resolve_path(step["source"], context)
    destination = resolve_path(step["destination"], context)

    case FileUtils.stream_copy_file(source, destination) do
      :ok ->
        {:ok,
         %{
           "operation" => "stream_copy",
           "source" => source,
           "destination" => destination,
           "status" => "completed",
           "method" => "streaming"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_operation("stream_process", step, context) do
    source = resolve_path(step["source"], context)
    processor = step["processor"] || "identity"

    processor_fn = get_processor_function(processor, step)

    case FileUtils.stream_process_lines(source, processor_fn) do
      {:ok, processed_path} ->
        {:ok,
         %{
           "operation" => "stream_process",
           "source" => source,
           "processed_path" => processed_path,
           "processor" => processor,
           "status" => "completed",
           "method" => "streaming"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper functions

  defp resolve_path(path, context) when is_binary(path) do
    FileUtils.resolve_path(path, context.workspace_dir)
  end

  defp resolve_path(nil, _context) do
    nil
  end

  # Processor functions for stream processing

  defp get_processor_function("identity", _step) do
    fn line -> line end
  end

  defp get_processor_function("uppercase", _step) do
    fn line -> String.upcase(line) end
  end

  defp get_processor_function("lowercase", _step) do
    fn line -> String.downcase(line) end
  end

  defp get_processor_function("trim", _step) do
    fn line -> String.trim(line) <> "\n" end
  end

  defp get_processor_function("replace", step) do
    pattern = step["pattern"] || ""
    replacement = step["replacement"] || ""
    
    fn line -> String.replace(line, pattern, replacement) end
  end

  defp get_processor_function(custom, _step) do
    Logger.warning("Unknown processor: #{custom}, using identity")
    fn line -> line end
  end
end
