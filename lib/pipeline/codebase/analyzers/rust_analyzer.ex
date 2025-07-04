defmodule Pipeline.Codebase.Analyzers.RustAnalyzer do
  @moduledoc """
  Specialized analyzer for Rust projects.
  """

  @spec analyze_file(String.t()) :: {:ok, map()} | {:error, String.t()}
  def analyze_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        {:ok, extract_rust_info(content, file_path)}

      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  @spec find_module_dependencies(String.t(), String.t()) :: [String.t()]
  def find_module_dependencies(file_path, _project_root) do
    case analyze_file(file_path) do
      {:ok, info} ->
        info[:uses] || []

      {:error, _} ->
        []
    end
  end

  defp extract_rust_info(content, file_path) do
    %{
      file_path: file_path,
      uses: extract_uses(content),
      structs: extract_structs(content),
      functions: extract_functions(content)
    }
  end

  defp extract_uses(content) do
    use_regex = ~r/use\s+([^;]+);/

    Regex.scan(use_regex, content)
    |> Enum.map(fn [_, use_stmt] -> String.trim(use_stmt) end)
  end

  defp extract_structs(_content), do: []
  defp extract_functions(_content), do: []
end
