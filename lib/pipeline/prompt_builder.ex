defmodule Pipeline.PromptBuilder do
  @moduledoc """
  Builds prompts from template configurations.
  """

  @doc """
  Build a prompt from prompt parts and previous results.
  """
  def build(prompt_parts, results) when is_list(prompt_parts) do
    prompt_parts
    |> Enum.map(&build_part(&1, results))
    |> Enum.join("\n")
  end

  def build(nil, _results), do: ""

  defp build_part(%{"type" => "static", "content" => content}, _results) do
    content || ""
  end

  defp build_part(%{type: "static", content: content}, _results) do
    content || ""
  end

  defp build_part(%{"type" => "file", "path" => path}, _results) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> raise "Failed to read file: #{path}"
    end
  end

  defp build_part(%{type: "file", path: path}, _results) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> raise "Failed to read file: #{path}"
    end
  end

  defp build_part(%{"type" => "previous_response", "step" => step_name} = part, results) do
    case Map.get(results, step_name) do
      nil ->
        raise "Step '#{step_name}' not found in results"

      result ->
        if part["extract"] do
          extract_field(result, part["extract"])
        else
          format_result(result)
        end
    end
  end

  defp build_part(%{type: "previous_response", step: step_name} = part, results) do
    case Map.get(results, step_name) do
      nil ->
        raise "Step '#{step_name}' not found in results"

      result ->
        if part[:extract] do
          extract_field(result, part[:extract])
        else
          format_result(result)
        end
    end
  end

  defp build_part(_, _), do: ""

  defp extract_field(result, field) when is_map(result) do
    case Map.get(result, field) || Map.get(result, String.to_atom(field)) do
      nil -> raise "Field '#{field}' not found in result"
      value -> format_value(value)
    end
  end

  defp extract_field(result, _field) do
    format_result(result)
  end

  defp format_result(result) when is_map(result) do
    # For Claude responses, prefer text field
    cond do
      Map.has_key?(result, :text) -> result.text
      Map.has_key?(result, "text") -> result["text"]
      Map.has_key?(result, :content) -> result.content
      Map.has_key?(result, "content") -> result["content"]
      true -> Jason.encode!(result, pretty: true)
    end
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

  defp format_value(value), do: to_string(value)
end
