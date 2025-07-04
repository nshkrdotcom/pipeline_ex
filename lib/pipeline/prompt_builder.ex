defmodule Pipeline.PromptBuilder do
  @moduledoc """
  Builds prompts from template configurations.
  Includes file caching for improved performance.
  """

  # File cache for repeated reads
  @file_cache_name :prompt_builder_file_cache

  @doc """
  Build a prompt from prompt parts and previous results.
  """
  def build(prompt_parts, results) when is_list(prompt_parts) do
    _ = ensure_cache_started()

    prompt_parts
    |> Enum.map(&build_part(&1, results))
    |> Enum.join("\n")
  end

  def build(nil, _results), do: ""

  @doc """
  Clear the file cache (useful for testing and memory management).
  """
  def clear_cache do
    case :ets.whereis(@file_cache_name) do
      :undefined ->
        :ok

      _tid ->
        :ets.delete_all_objects(@file_cache_name)
        :ok
    end
  end

  defp ensure_cache_started do
    case :ets.whereis(@file_cache_name) do
      :undefined ->
        try do
          :ets.new(@file_cache_name, [:named_table, :public, :set])
        rescue
          ArgumentError ->
            # Table was created by another process in the meantime
            :ok
        end

      _tid ->
        :ok
    end
  end

  # Static content build_part functions
  defp build_part(%{"type" => "static", "content" => content}, _results) do
    content || ""
  end

  defp build_part(%{type: "static", content: content}, _results) do
    content || ""
  end

  # File content build_part functions
  defp build_part(%{"type" => "file", "path" => path}, _results) do
    read_file_with_cache(path)
  end

  defp build_part(%{type: "file", path: path}, _results) do
    read_file_with_cache(path)
  end

  # Previous response build_part functions
  defp build_part(%{"type" => "previous_response", "step" => step_name} = part, context) do
    results = get_results_from_context(context)

    case Map.get(results, step_name) do
      nil ->
        raise KeyError, key: step_name, term: results

      result ->
        if part["extract"] do
          # Default to strict mode
          strict = Map.get(part, "strict", true)
          extract_field(result, part["extract"], strict)
        else
          format_result(result)
        end
    end
  end

  defp build_part(%{type: "previous_response", step: step_name} = part, context) do
    results = get_results_from_context(context)

    case Map.get(results, step_name) do
      nil ->
        raise KeyError, key: step_name, term: results

      result ->
        try do
          if part[:extract] do
            # Default to strict mode
            strict = Map.get(part, :strict, true)
            extract_field(result, part[:extract], strict)
          else
            format_result(result)
          end
        rescue
          e ->
            reraise "Failed to process result from step '#{step_name}': #{Exception.message(e)}",
                    __STACKTRACE__
        end
    end
  end

  # Catch-all build_part function
  defp build_part(_, _), do: ""

  defp read_file_with_cache(path) do
    # Get file modification time for cache invalidation
    case File.stat(path) do
      {:ok, %File.Stat{mtime: mtime}} ->
        cache_key = {path, mtime}

        case :ets.lookup(@file_cache_name, cache_key) do
          [{^cache_key, content}] ->
            # Cache hit
            content

          [] ->
            # Cache miss - read file and cache
            content = read_file_with_error_handling(path)
            :ets.insert(@file_cache_name, {cache_key, content})
            content
        end

      {:error, :enoent} ->
        raise "File not found: #{path}. Please check the file path and ensure the file exists."

      {:error, :eacces} ->
        raise "Permission denied accessing file: #{path}. Please check file permissions."

      {:error, reason} ->
        raise "Failed to access file #{path}: #{:file.format_error(reason)}"
    end
  end

  defp read_file_with_error_handling(path) do
    case File.read(path) do
      {:ok, content} ->
        content

      {:error, :enoent} ->
        raise "File not found: #{path}. Please check the file path and ensure the file exists."

      {:error, :eacces} ->
        raise "Permission denied reading file: #{path}. Please check file permissions."

      {:error, reason} ->
        raise "Failed to read file #{path}: #{:file.format_error(reason)}"
    end
  rescue
    e in File.Error ->
      reraise "File operation failed for #{path}: #{Exception.message(e)}", __STACKTRACE__
  end

  defp get_results_from_context(%{results: results}), do: results
  defp get_results_from_context(results) when is_map(results), do: results

  defp extract_field(result, field_path, strict) do
    case get_nested_field_with_presence(result, field_path) do
      {:found, value} ->
        format_value(value)

      :not_found ->
        if strict do
          # In strict mode, provide helpful error message
          available_fields = get_available_fields(result)

          raise ArgumentError,
                "Field '#{field_path}' not found in previous response. " <>
                  "Available fields: #{available_fields}. " <>
                  "Response structure: #{inspect(result, limit: 200)}"
        else
          # In non-strict mode, return nil (which formats to "nil")
          format_value(nil)
        end
    end
  end

  defp get_nested_field_with_presence(map, field_path) when is_map(map) do
    fields = String.split(field_path, ".")

    {result, status} =
      Enum.reduce(fields, {map, :found}, &reduce_field_path/2)

    case status do
      :found -> {:found, result}
      :not_found -> :not_found
    end
  end

  defp get_nested_field_with_presence(_, _), do: :not_found

  defp reduce_field_path(field, {acc, status}) do
    case {acc, status} do
      {%{}, :found} -> get_field_from_map(acc, field)
      {_, :not_found} -> {nil, :not_found}
      _ -> {nil, :not_found}
    end
  end

  defp get_field_from_map(map, field) do
    cond do
      Map.has_key?(map, field) -> {Map.get(map, field), :found}
      Map.has_key?(map, String.to_atom(field)) -> {Map.get(map, String.to_atom(field)), :found}
      true -> {nil, :not_found}
    end
  end

  defp format_result(result) when is_map(result) do
    # Return full JSON representation when no specific field is requested
    Jason.encode!(result, pretty: true)
  end

  defp format_result(result) when is_binary(result) do
    result
  end

  defp format_result(result) do
    inspect(result)
  end

  defp format_value(value) when is_binary(value), do: value

  defp format_value(value) when is_map(value) or is_list(value) do
    Jason.encode!(value, pretty: true)
  end

  defp format_value(nil), do: "nil"

  defp format_value(value), do: to_string(value)

  defp get_available_fields(result) when is_map(result) do
    Map.keys(result) |> Enum.join(", ")
  end

  defp get_available_fields(_result) do
    "none (response is not a map/object)"
  end
end
