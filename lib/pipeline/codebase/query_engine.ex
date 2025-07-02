defmodule Pipeline.Codebase.QueryEngine do
  @moduledoc """
  Core query engine for intelligent codebase analysis.

  Provides high-level query operations that combine discovery, analysis,
  and relationship mapping to answer complex questions about code structure
  and dependencies.
  """

  require Logger
  alias Pipeline.Codebase.Context
  alias Pipeline.Codebase.Discovery

  @doc """
  Find files based on various criteria.

  ## Criteria Options
  - `type`: "main", "test", "config", "source"
  - `pattern`: Glob pattern to match
  - `language`: Programming language
  - `extension`: File extension
  - `contains`: String that must be in file path
  - `exclude_tests`: Boolean to exclude test files
  - `related_to`: Find files related to given file
  - `modified_since`: Date string (ISO format)
  - `size_min`: Minimum file size in bytes
  - `size_max`: Maximum file size in bytes
  """
  @spec find_files(Context.t(), keyword()) :: [String.t()]
  def find_files(context, criteria) do
    Logger.debug("🔍 Finding files with criteria: #{inspect(criteria)}")
    
    base_files = get_base_file_set(context, criteria)
    
    base_files
    |> apply_type_filter(context, criteria)
    |> apply_pattern_filter(criteria)
    |> apply_language_filter(criteria)
    |> apply_extension_filter(criteria)
    |> apply_contains_filter(criteria)
    |> apply_size_filter(context, criteria)
    |> apply_modified_filter(context, criteria)
    |> apply_exclude_tests_filter(context, criteria)
    |> apply_related_to_filter(context, criteria)
    |> Enum.sort()
  end

  @doc """
  Find dependencies for a given file or the entire project.

  ## Config Options
  - `for_file`: Specific file to analyze dependencies for
  - `include_transitive`: Include transitive dependencies
  - `type`: "direct", "transitive", "all"
  - `language`: Filter by programming language
  """
  @spec find_dependencies(Context.t(), keyword()) :: %{
    direct: [String.t()],
    transitive: [String.t()],
    file_specific: %{String.t() => [String.t()]}
  }
  def find_dependencies(context, config) do
    Logger.debug("🔍 Finding dependencies with config: #{inspect(config)}")
    
    case Keyword.get(config, :for_file) do
      nil ->
        # Project-wide dependencies
        %{
          direct: get_direct_dependencies(context),
          transitive: get_transitive_dependencies(context, config),
          file_specific: %{}
        }
      
      file_path ->
        # File-specific dependencies
        file_deps = get_file_dependencies(context, file_path, config)
        
        %{
          direct: file_deps.direct,
          transitive: file_deps.transitive,
          file_specific: %{file_path => file_deps.all}
        }
    end
  end

  @doc """
  Find functions, classes, and other code constructs.

  ## Config Options
  - `name`: Function/class name to search for
  - `pattern`: Regex pattern to match
  - `type`: "function", "class", "module", "constant"
  - `in_file`: Specific file to search in
  - `in_files`: List of files to search in
  - `language`: Programming language filter
  """
  @spec find_functions(Context.t(), keyword()) :: [%{
    name: String.t(),
    type: String.t(),
    file: String.t(),
    line: non_neg_integer() | nil,
    signature: String.t() | nil
  }]
  def find_functions(context, config) do
    Logger.debug("🔍 Finding functions with config: #{inspect(config)}")
    
    target_files = get_target_files_for_function_search(context, config)
    
    target_files
    |> Enum.flat_map(fn file_path ->
      search_functions_in_file(context, file_path, config)
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Find files related to a given file.

  ## Config Options
  - `file`: File to find relations for
  - `types`: List of relation types ["test", "source", "similar", "directory"]
  - `max_results`: Maximum number of results
  """
  @spec find_related_files(Context.t(), keyword()) :: [%{
    file: String.t(),
    relation_type: String.t(),
    confidence: float()
  }]
  def find_related_files(context, config) do
    Logger.debug("🔍 Finding related files with config: #{inspect(config)}")
    
    target_file = Keyword.get(config, :file)
    relation_types = Keyword.get(config, :types, ["test", "source", "similar", "directory"])
    max_results = Keyword.get(config, :max_results, 20)
    
    if target_file do
      relation_types
      |> Enum.flat_map(fn type ->
        find_relations_by_type(context, target_file, type)
      end)
      |> Enum.sort_by(& &1.confidence, :desc)
      |> Enum.take(max_results)
    else
      []
    end
  end

  @doc """
  Analyze the impact of changes to a file.

  ## Config Options
  - `file`: File to analyze impact for
  - `include_tests`: Include test files in impact analysis
  - `max_depth`: Maximum depth for dependency traversal
  """
  @spec analyze_impact(Context.t(), keyword()) :: %{
    directly_affected: [String.t()],
    potentially_affected: [String.t()],
    test_files: [String.t()],
    impact_score: non_neg_integer()
  }
  def analyze_impact(context, config) do
    Logger.debug("🔍 Analyzing impact with config: #{inspect(config)}")
    
    target_file = Keyword.get(config, :file)
    include_tests = Keyword.get(config, :include_tests, true)
    max_depth = Keyword.get(config, :max_depth, 3)
    
    if target_file do
      directly_affected = find_direct_dependents(context, target_file)
      potentially_affected = find_transitive_dependents(context, target_file, max_depth)
      test_files = if include_tests, do: find_test_files_for(context, target_file), else: []
      
      %{
        directly_affected: directly_affected,
        potentially_affected: potentially_affected,
        test_files: test_files,
        impact_score: calculate_impact_score(directly_affected, potentially_affected, test_files)
      }
    else
      %{directly_affected: [], potentially_affected: [], test_files: [], impact_score: 0}
    end
  end

  # Private helper functions

  defp get_base_file_set(context, criteria) do
    case Keyword.get(criteria, :related_to) do
      nil ->
        Map.keys(context.files)
      
      file_path ->
        Discovery.find_related_files(context, file_path)
    end
  end

  defp apply_type_filter(files, context, criteria) do
    case Keyword.get(criteria, :type) do
      nil -> files
      "main" -> Enum.filter(files, &(&1 in context.structure.main_files))
      "test" -> Enum.filter(files, &(&1 in context.structure.test_files))
      "config" -> Enum.filter(files, &(&1 in context.structure.config_files))
      "source" -> Enum.filter(files, &(&1 in context.structure.source_files))
      _ -> files
    end
  end

  defp apply_pattern_filter(files, criteria) do
    case Keyword.get(criteria, :pattern) do
      nil -> files
      pattern -> Enum.filter(files, &matches_glob_pattern?(&1, pattern))
    end
  end

  defp apply_language_filter(files, criteria) do
    case Keyword.get(criteria, :language) do
      nil -> files
      language -> Enum.filter(files, &has_language?(&1, language))
    end
  end

  defp apply_extension_filter(files, criteria) do
    case Keyword.get(criteria, :extension) do
      nil -> files
      ext -> Enum.filter(files, &(Path.extname(&1) == ext))
    end
  end

  defp apply_contains_filter(files, criteria) do
    case Keyword.get(criteria, :contains) do
      nil -> files
      substring -> Enum.filter(files, &String.contains?(&1, substring))
    end
  end

  defp apply_size_filter(files, context, criteria) do
    min_size = Keyword.get(criteria, :size_min)
    max_size = Keyword.get(criteria, :size_max)
    
    case {min_size, max_size} do
      {nil, nil} -> files
      _ -> Enum.filter(files, &meets_size_criteria?(&1, context, min_size, max_size))
    end
  end

  defp apply_modified_filter(files, context, criteria) do
    case Keyword.get(criteria, :modified_since) do
      nil -> files
      date_string -> Enum.filter(files, &modified_since?(&1, context, date_string))
    end
  end

  defp apply_exclude_tests_filter(files, context, criteria) do
    case Keyword.get(criteria, :exclude_tests) do
      true -> 
        test_files = context.structure.test_files
        Enum.reject(files, fn file ->
          file in test_files or String.contains?(file, "test")
        end)
      _ -> files
    end
  end

  defp apply_related_to_filter(files, context, criteria) do
    case Keyword.get(criteria, :related_to) do
      nil -> files
      file_path -> 
        related = Discovery.find_related_files(context, file_path)
        Enum.filter(files, &(&1 in related))
    end
  end

  defp matches_glob_pattern?(path, pattern) do
    # Convert glob pattern to regex and match
    regex = convert_glob_to_regex(pattern)
    Regex.match?(regex, path)
  end

  defp convert_glob_to_regex(pattern) do
    pattern
    |> String.replace(".", "\\.")
    |> String.replace("**/", "__GLOBSTAR__")
    |> String.replace("**", "__GLOBSTAR__")
    |> String.replace("*", "[^/]*")
    |> String.replace("__GLOBSTAR__", "(?:[^/]*/?)*")
    |> String.replace("{", "(")
    |> String.replace("}", ")")
    |> String.replace(",", "|")
    |> then(&Regex.compile!("^#{&1}$"))
  end

  defp has_language?(path, language) do
    # Simple language detection based on file extension
    case Path.extname(path) do
      ".ex" -> language in ["elixir", "ex"]
      ".exs" -> language in ["elixir", "ex"]
      ".js" -> language in ["javascript", "js"]
      ".ts" -> language in ["typescript", "ts"]
      ".py" -> language in ["python", "py"]
      ".rs" -> language in ["rust", "rs"]
      ".go" -> language in ["go"]
      _ -> false
    end
  end

  defp meets_size_criteria?(path, context, min_size, max_size) do
    case Map.get(context.files, path) do
      nil -> false
      file_info ->
        size = file_info.size
        (min_size == nil or size >= min_size) and
        (max_size == nil or size <= max_size)
    end
  end

  defp modified_since?(path, context, date_string) do
    case Map.get(context.files, path) do
      nil -> false
      file_info ->
        case Date.from_iso8601(date_string) do
          {:ok, date} -> 
            file_date = DateTime.to_date(file_info.modified)
            Date.compare(file_date, date) != :lt
          _ -> false
        end
    end
  end

  # Dependency analysis functions

  defp get_direct_dependencies(context) do
    context.dependencies
    |> Map.keys()
    |> Enum.map(&to_string/1)
  end

  defp get_transitive_dependencies(context, config) do
    # Simplified - in real implementation would traverse dependency graph
    case Keyword.get(config, :include_transitive, false) do
      true -> get_direct_dependencies(context)
      false -> []
    end
  end

  defp get_file_dependencies(context, file_path, config) do
    # Analyze file content for imports/requires
    # This is a simplified implementation
    file_content = read_file_safely(Path.join(context.root_path, file_path))
    
    direct_deps = extract_imports_from_content(file_content, context.project_type)
    
    transitive_deps = case Keyword.get(config, :include_transitive, false) do
      true -> get_transitive_for_file(context, direct_deps)
      false -> []
    end
    
    %{
      direct: direct_deps,
      transitive: transitive_deps,
      all: direct_deps ++ transitive_deps
    }
  end

  defp read_file_safely(file_path) do
    case File.read(file_path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  defp extract_imports_from_content(content, project_type) do
    case project_type do
      :elixir -> extract_elixir_imports(content)
      :javascript -> extract_javascript_imports(content)
      :python -> extract_python_imports(content)
      _ -> []
    end
  end

  defp extract_elixir_imports(content) do
    # Extract alias, import, use statements
    import_regex = ~r/(?:alias|import|use)\s+([A-Z][A-Za-z0-9_.]*)/
    
    Regex.scan(import_regex, content)
    |> Enum.map(fn [_, module] -> module end)
    |> Enum.uniq()
  end

  defp extract_javascript_imports(content) do
    # Extract import statements
    import_regex = ~r/import\s+.*?from\s+['"](.*?)['"]/
    
    Regex.scan(import_regex, content)
    |> Enum.map(fn [_, module] -> module end)
    |> Enum.uniq()
  end

  defp extract_python_imports(content) do
    # Extract import and from statements
    import_regex = ~r/(?:import|from)\s+([a-zA-Z_][a-zA-Z0-9_]*)/
    
    Regex.scan(import_regex, content)
    |> Enum.map(fn [_, module] -> module end)
    |> Enum.uniq()
  end

  defp get_transitive_for_file(_context, _direct_deps) do
    # Simplified - would need more sophisticated dependency analysis
    []
  end

  # Function search functions

  defp get_target_files_for_function_search(context, config) do
    cond do
      in_file = Keyword.get(config, :in_file) ->
        [in_file]
      
      in_files = Keyword.get(config, :in_files) ->
        in_files
      
      language = Keyword.get(config, :language) ->
        context.structure.source_files
        |> Enum.filter(&has_language?(&1, language))
      
      true ->
        context.structure.source_files
    end
  end

  defp search_functions_in_file(context, file_path, config) do
    file_content = read_file_safely(Path.join(context.root_path, file_path))
    
    case context.project_type do
      :elixir -> search_elixir_functions(file_content, file_path, config)
      :javascript -> search_javascript_functions(file_content, file_path, config)
      :python -> search_python_functions(file_content, file_path, config)
      _ -> []
    end
  end

  defp search_elixir_functions(content, file_path, config) do
    # Simple regex-based function detection
    function_regex = ~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
    
    Regex.scan(function_regex, content)
    |> Enum.map(fn [_, name] -> 
      %{
        name: name,
        type: "function",
        file: file_path,
        line: nil,
        signature: nil
      }
    end)
    |> filter_functions_by_config(config)
  end

  defp search_javascript_functions(content, file_path, config) do
    # Simple regex-based function detection
    function_regex = ~r/(?:function\s+([a-zA-Z_][a-zA-Z0-9_]*)|([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(?:function|\([^)]*\)\s*=>))/
    
    Regex.scan(function_regex, content)
    |> Enum.map(fn 
      [_, name, ""] -> 
        %{name: name, type: "function", file: file_path, line: nil, signature: nil}
      [_, "", name] -> 
        %{name: name, type: "function", file: file_path, line: nil, signature: nil}
      [_, name] -> 
        %{name: name, type: "function", file: file_path, line: nil, signature: nil}
    end)
    |> filter_functions_by_config(config)
  end

  defp search_python_functions(content, file_path, config) do
    # Simple regex-based function detection
    function_regex = ~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/
    
    Regex.scan(function_regex, content)
    |> Enum.map(fn [_, name] -> 
      %{
        name: name,
        type: "function",
        file: file_path,
        line: nil,
        signature: nil
      }
    end)
    |> filter_functions_by_config(config)
  end

  defp filter_functions_by_config(functions, config) do
    name_filter = Keyword.get(config, :name)
    pattern_filter = Keyword.get(config, :pattern)
    type_filter = Keyword.get(config, :type)
    
    functions
    |> Enum.filter(fn func ->
      (name_filter == nil or func.name == name_filter) and
      (pattern_filter == nil or Regex.match?(Regex.compile!(pattern_filter), func.name)) and
      (type_filter == nil or func.type == type_filter)
    end)
  end

  # Relationship analysis functions

  defp find_relations_by_type(context, target_file, "test") do
    # Find test files for the target file
    test_files = find_test_files_for(context, target_file)
    
    Enum.map(test_files, fn file ->
      %{file: file, relation_type: "test", confidence: 0.9}
    end)
  end

  defp find_relations_by_type(context, target_file, "source") do
    # Find source files for the target test file
    source_files = find_source_files_for(context, target_file)
    
    Enum.map(source_files, fn file ->
      %{file: file, relation_type: "source", confidence: 0.9}
    end)
  end

  defp find_relations_by_type(context, target_file, "similar") do
    # Find files with similar names
    similar_files = find_similar_files(context, target_file)
    
    Enum.map(similar_files, fn {file, confidence} ->
      %{file: file, relation_type: "similar", confidence: confidence}
    end)
  end

  defp find_relations_by_type(context, target_file, "directory") do
    # Find files in the same directory
    dir = Path.dirname(target_file)
    
    # Only return directory relations if the target file actually exists
    if Map.has_key?(context.files, target_file) do
      context.files
      |> Map.keys()
      |> Enum.filter(&(Path.dirname(&1) == dir and &1 != target_file))
      |> Enum.map(fn file ->
        %{file: file, relation_type: "directory", confidence: 0.7}
      end)
    else
      []
    end
  end

  defp find_relations_by_type(_context, _target_file, _type), do: []

  defp find_test_files_for(context, target_file) do
    base_name = Path.basename(target_file, Path.extname(target_file))
    
    context.structure.test_files
    |> Enum.filter(fn test_file ->
      test_base = Path.basename(test_file, Path.extname(test_file))
      String.contains?(test_base, base_name) or String.contains?(base_name, test_base)
    end)
  end

  defp find_source_files_for(context, target_file) do
    base_name = Path.basename(target_file, Path.extname(target_file))
    
    context.structure.source_files
    |> Enum.filter(fn source_file ->
      source_base = Path.basename(source_file, Path.extname(source_file))
      String.contains?(base_name, source_base) or String.contains?(source_base, base_name)
    end)
  end

  defp find_similar_files(context, target_file) do
    base_name = Path.basename(target_file, Path.extname(target_file))
    
    context.files
    |> Map.keys()
    |> Enum.filter(&(&1 != target_file))
    |> Enum.map(fn file ->
      other_base = Path.basename(file, Path.extname(file))
      confidence = String.jaro_distance(base_name, other_base)
      {file, confidence}
    end)
    |> Enum.filter(fn {_file, confidence} -> confidence > 0.7 end)
  end

  # Impact analysis functions

  defp find_direct_dependents(context, target_file) do
    # Find files that directly import/require the target file
    # This is a simplified implementation
    context.structure.source_files
    |> Enum.filter(fn file ->
      file != target_file and file_depends_on?(context, file, target_file)
    end)
  end

  defp find_transitive_dependents(context, target_file, max_depth) do
    # Find files that transitively depend on the target file
    # This is a simplified implementation
    direct = find_direct_dependents(context, target_file)
    
    if max_depth > 1 do
      transitive = 
        direct
        |> Enum.flat_map(&find_transitive_dependents(context, &1, max_depth - 1))
        |> Enum.uniq()
      
      (direct ++ transitive) |> Enum.uniq()
    else
      direct
    end
  end

  defp file_depends_on?(context, file, target_file) do
    # Check if file imports/requires target_file
    file_content = read_file_safely(Path.join(context.root_path, file))
    target_module = path_to_module_name(target_file, context.project_type)
    
    case context.project_type do
      :elixir -> String.contains?(file_content, target_module)
      :javascript -> String.contains?(file_content, target_file) or String.contains?(file_content, target_module)
      :python -> String.contains?(file_content, target_module)
      _ -> false
    end
  end

  defp path_to_module_name(file_path, project_type) do
    case project_type do
      :elixir ->
        file_path
        |> String.replace(~r/^lib\//, "")
        |> String.replace(~r/\.ex$/, "")
        |> String.split("/")
        |> Enum.map(&Macro.camelize/1)
        |> Enum.join(".")
      
      :javascript ->
        file_path
        |> String.replace(~r/^src\//, "")
        |> String.replace(~r/\.(js|ts)$/, "")
      
      :python ->
        file_path
        |> String.replace(~r/\.py$/, "")
        |> String.replace("/", ".")
      
      _ ->
        file_path
    end
  end

  defp calculate_impact_score(directly_affected, potentially_affected, test_files) do
    length(directly_affected) * 3 + 
    length(potentially_affected) * 1 + 
    length(test_files) * 2
  end
end