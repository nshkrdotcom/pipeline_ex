defmodule Pipeline.Codebase.Analyzers.GoAnalyzer do
  @moduledoc """
  Specialized analyzer for Go projects.
  """

  @spec analyze_file(String.t()) :: {:ok, map()} | {:error, String.t()}
  def analyze_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        {:ok, extract_go_info(content, file_path)}

      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  @spec find_module_dependencies(String.t(), String.t()) :: [String.t()]
  def find_module_dependencies(file_path, _project_root) do
    case analyze_file(file_path) do
      {:ok, info} ->
        info[:imports] || []

      {:error, _} ->
        []
    end
  end

  defp extract_go_info(content, file_path) do
    %{
      file_path: file_path,
      package: extract_package(content),
      imports: extract_imports(content),
      functions: extract_functions(content)
    }
  end

  defp extract_package(content) do
    case Regex.run(~r/package\s+(\w+)/, content) do
      [_, package] -> package
      _ -> nil
    end
  end

  defp extract_imports(content) do
    import_regex = ~r/import\s+(?:\(\s*([^)]+)\s*\)|"([^"]+)")/

    Regex.scan(import_regex, content)
    |> Enum.flat_map(fn
      [_, multi_imports, ""] ->
        multi_imports
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.trim(&1, "\""))

      [_, "", single_import] ->
        [single_import]

      _ ->
        []
    end)
  end

  defp extract_functions(_content), do: []
end
