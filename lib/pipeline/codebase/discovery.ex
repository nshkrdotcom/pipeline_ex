defmodule Pipeline.Codebase.Discovery do
  @moduledoc """
  Core discovery engine for codebase analysis.
  
  Handles project type detection, file scanning, dependency parsing,
  git integration, and structure analysis.
  """

  require Logger

  # Analyzer modules will be imported when needed

  @project_indicators %{
    elixir: ["mix.exs", "lib/", "config/config.exs"],
    javascript: ["package.json", "node_modules/", "src/", "index.js"],
    python: ["requirements.txt", "setup.py", "pyproject.toml", "__pycache__/"],
    rust: ["Cargo.toml", "src/main.rs", "src/lib.rs", "target/"],
    go: ["go.mod", "go.sum", "main.go"]
  }

  @config_files %{
    elixir: ["mix.exs", "config/*.exs"],
    javascript: ["package.json", "*.config.js", "*.config.ts", ".env*"],
    python: ["requirements.txt", "setup.py", "pyproject.toml", "*.ini"],
    rust: ["Cargo.toml", "Cargo.lock"],
    go: ["go.mod", "go.sum"]
  }

  @source_extensions %{
    elixir: [".ex", ".exs"],
    javascript: [".js", ".ts", ".jsx", ".tsx", ".mjs"],
    python: [".py", ".pyw"],
    rust: [".rs"],
    go: [".go"]
  }

  @test_patterns %{
    elixir: ["test/**/*_test.exs", "test/**/test_*.exs"],
    javascript: ["**/*.test.js", "**/*.spec.js", "test/**/*.js", "tests/**/*.js"],
    python: ["**/test_*.py", "**/*_test.py", "tests/**/*.py"],
    rust: ["tests/**/*.rs", "src/**/*_test.rs"],
    go: ["**/*_test.go"]
  }

  @doc """
  Detect project type based on file indicators.
  """
  @spec detect_project_type(String.t()) :: atom()
  def detect_project_type(workspace_dir) do
    @project_indicators
    |> Enum.find(fn {_type, indicators} ->
      Enum.any?(indicators, &file_or_dir_exists?(workspace_dir, &1))
    end)
    |> case do
      {type, _} -> type
      nil -> :unknown
    end
  end

  @doc """
  Scan all files in the workspace directory.
  """
  @spec scan_files(String.t()) :: %{String.t() => map()}
  def scan_files(workspace_dir) do
    Path.wildcard(Path.join(workspace_dir, "**/*"))
    |> Enum.reduce(%{}, fn path, acc ->
      relative_path = Path.relative_to(path, workspace_dir)
      
      case File.stat(path) do
        {:ok, %File.Stat{type: :regular} = stat} ->
          modified_time = case stat.mtime do
            mtime when is_integer(mtime) -> DateTime.from_unix!(mtime, :second)
            _ -> DateTime.utc_now()
          end
          
          Map.put(acc, relative_path, %{
            type: "file",
            size: stat.size,
            modified: modified_time,
            language: detect_language(relative_path),
            full_path: path
          })
        
        {:ok, %File.Stat{type: :directory}} ->
          Map.put(acc, relative_path, %{
            type: "directory",
            size: 0,
            modified: DateTime.utc_now(),
            language: nil,
            full_path: path
          })
        
        {:error, _} ->
          acc
      end
    end)
  end

  @doc """
  Parse project dependencies from configuration files.
  """
  @spec parse_dependencies(String.t()) :: map()
  def parse_dependencies(workspace_dir) do
    project_type = detect_project_type(workspace_dir)
    
    case project_type do
      :elixir -> parse_elixir_dependencies(workspace_dir)
      :javascript -> parse_javascript_dependencies(workspace_dir)
      :python -> parse_python_dependencies(workspace_dir)
      :rust -> parse_rust_dependencies(workspace_dir)
      :go -> parse_go_dependencies(workspace_dir)
      _ -> %{}
    end
  end

  @doc """
  Get git information for the workspace.
  """
  @spec get_git_info(String.t()) :: map()
  def get_git_info(workspace_dir) do
    if File.exists?(Path.join(workspace_dir, ".git")) do
      %{
        branch: get_git_branch(workspace_dir),
        commit: get_git_commit(workspace_dir),
        status: get_git_status(workspace_dir),
        recent_commits: get_recent_commits(workspace_dir)
      }
    else
      %{branch: nil, commit: nil, status: nil, recent_commits: []}
    end
  end

  @doc """
  Analyze project structure and categorize files.
  """
  @spec analyze_structure(String.t()) :: map()
  def analyze_structure(workspace_dir) do
    files = scan_files(workspace_dir)
    project_type = detect_project_type(workspace_dir)
    
    %{
      directories: get_directories(files),
      main_files: get_main_files(files, project_type),
      test_files: get_test_files(files, project_type),
      config_files: get_config_files(files, project_type),
      source_files: get_source_files(files, project_type)
    }
  end

  @doc """
  Extract project metadata.
  """
  @spec extract_metadata(String.t()) :: map()
  def extract_metadata(workspace_dir) do
    project_type = detect_project_type(workspace_dir)
    
    base_metadata = %{
      project_type: project_type,
      discovered_at: DateTime.utc_now(),
      root_path: workspace_dir
    }
    
    case project_type do
      :elixir -> Map.merge(base_metadata, extract_elixir_metadata(workspace_dir))
      :javascript -> Map.merge(base_metadata, extract_javascript_metadata(workspace_dir))
      :python -> Map.merge(base_metadata, extract_python_metadata(workspace_dir))
      :rust -> Map.merge(base_metadata, extract_rust_metadata(workspace_dir))
      :go -> Map.merge(base_metadata, extract_go_metadata(workspace_dir))
      _ -> base_metadata
    end
  end

  @doc """
  Find files related to a given file path.
  """
  @spec find_related_files(Pipeline.Codebase.Context.t(), String.t()) :: [String.t()]
  def find_related_files(context, file_path) do
    # Find test files for source files and vice versa
    # Find files in same directory
    # Find files with similar names
    # Find files that import/require the given file
    
    related = []
    
    # Same directory files
    same_dir = get_same_directory_files(context, file_path)
    
    # Test/source counterparts
    counterparts = find_test_source_counterparts(context, file_path)
    
    # Files with similar names
    similar_names = find_similar_named_files(context, file_path)
    
    (related ++ same_dir ++ counterparts ++ similar_names)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == file_path))
  end

  @doc """
  Query files by various criteria.
  """
  @spec query_files(Pipeline.Codebase.Context.t(), keyword()) :: [String.t()]
  def query_files(context, criteria) do
    context.files
    |> Map.keys()
    |> Enum.filter(fn file_path ->
      file_info = Map.get(context.files, file_path)
      matches_criteria?(file_path, file_info, criteria)
    end)
  end

  # Private helper functions

  defp file_or_dir_exists?(workspace_dir, pattern) do
    case String.contains?(pattern, "*") do
      true ->
        workspace_dir
        |> Path.join(pattern)
        |> Path.wildcard()
        |> length() > 0
      
      false ->
        workspace_dir
        |> Path.join(pattern)
        |> File.exists?()
    end
  end

  defp detect_language(file_path) do
    extension = Path.extname(file_path)
    
    @source_extensions
    |> Enum.find(fn {_lang, exts} -> extension in exts end)
    |> case do
      {lang, _} -> Atom.to_string(lang)
      nil -> nil
    end
  end

  defp get_directories(files) do
    files
    |> Enum.filter(fn {_path, info} -> info.type == "directory" end)
    |> Enum.map(fn {path, _info} -> path end)
    |> Enum.sort()
  end

  defp get_main_files(files, project_type) do
    main_patterns = case project_type do
      :elixir -> ["lib/**/*.ex", "mix.exs"]
      :javascript -> ["src/**/*.{js,ts}", "index.{js,ts}", "package.json"]
      :python -> ["**/*.py", "setup.py", "main.py"]
      :rust -> ["src/**/*.rs", "Cargo.toml"]
      :go -> ["**/*.go", "go.mod"]
      _ -> []
    end
    
    filter_files_by_patterns(files, main_patterns)
  end

  defp get_test_files(files, project_type) do
    test_patterns = Map.get(@test_patterns, project_type, [])
    filter_files_by_patterns(files, test_patterns)
  end

  defp get_config_files(files, project_type) do
    config_patterns = Map.get(@config_files, project_type, [])
    filter_files_by_patterns(files, config_patterns)
  end

  defp get_source_files(files, project_type) do
    extensions = Map.get(@source_extensions, project_type, [])
    
    files
    |> Enum.filter(fn {path, info} ->
      info.type == "file" && Path.extname(path) in extensions
    end)
    |> Enum.map(fn {path, _info} -> path end)
    |> Enum.sort()
  end

  defp filter_files_by_patterns(files, patterns) do
    file_paths = Map.keys(files)
    
    patterns
    |> Enum.flat_map(fn pattern ->
      case String.contains?(pattern, "*") do
        true -> 
          # Use Path.wildcard style matching
          regex = convert_glob_to_regex(pattern)
          Enum.filter(file_paths, fn path ->
            Regex.match?(regex, path)
          end)
        false -> 
          if pattern in file_paths, do: [pattern], else: []
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp convert_glob_to_regex(pattern) do
    pattern
    |> String.replace(".", "\\.")
    |> String.replace("**/", "__GLOBSTAR__")  # Match zero or more path segments
    |> String.replace("**", "__GLOBSTAR__")   # Match zero or more path segments  
    |> String.replace("*", "[^/]*")           # Match anything except path separator
    |> String.replace("__GLOBSTAR__", "(?:[^/]*/?)*") # Zero or more segments with optional trailing slash
    |> String.replace("{", "(")
    |> String.replace("}", ")")
    |> String.replace(",", "|")
    |> then(&Regex.compile!("^#{&1}$"))
  end

  # Git helper functions

  defp get_git_branch(workspace_dir) do
    case System.cmd("git", ["branch", "--show-current"], cd: workspace_dir, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> nil
    end
  end

  defp get_git_commit(workspace_dir) do
    case System.cmd("git", ["rev-parse", "HEAD"], cd: workspace_dir, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output) |> String.slice(0, 8)
      _ -> nil
    end
  end

  defp get_git_status(workspace_dir) do
    case System.cmd("git", ["status", "--porcelain"], cd: workspace_dir, stderr_to_stdout: true) do
      {output, 0} -> 
        case String.trim(output) do
          "" -> "clean"
          _ -> "dirty"
        end
      _ -> nil
    end
  end

  defp get_recent_commits(workspace_dir) do
    case System.cmd("git", ["log", "--oneline", "-5"], cd: workspace_dir, stderr_to_stdout: true) do
      {output, 0} -> 
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))
      _ -> []
    end
  end

  # Dependency parsing functions

  defp parse_elixir_dependencies(workspace_dir) do
    mix_file = Path.join(workspace_dir, "mix.exs")
    
    if File.exists?(mix_file) do
      # Simple regex-based parsing for dependencies
      # This is more reliable than trying to eval the mix.exs file in tests
      content = File.read!(mix_file)
      
      # Extract dependencies from the deps function
      case Regex.run(~r/defp deps do\s*\[(.*?)\]/ms, content) do
        [_, deps_content] ->
          # Parse individual dependency lines
          Regex.scan(~r/\{:(\w+),\s*"([^"]+)"\}/, deps_content)
          |> Enum.reduce(%{}, fn [_, name, version], acc ->
            Map.put(acc, name, version)
          end)
        _ -> %{}
      end
    else
      %{}
    end
  end

  defp parse_javascript_dependencies(workspace_dir) do
    package_file = Path.join(workspace_dir, "package.json")
    
    if File.exists?(package_file) do
      case File.read!(package_file) |> Jason.decode() do
        {:ok, %{"dependencies" => deps}} -> deps
        {:ok, _} -> %{}
        {:error, _} -> %{}
      end
    else
      %{}
    end
  end

  defp parse_python_dependencies(workspace_dir) do
    requirements_file = Path.join(workspace_dir, "requirements.txt")
    
    if File.exists?(requirements_file) do
      requirements_file
      |> File.read!()
      |> String.split("\n")
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ["==", ">=", "<=", ">", "<", "~="], parts: 2) do
          [name, version] -> Map.put(acc, String.trim(name), String.trim(version))
          [name] -> Map.put(acc, String.trim(name), "latest")
          _ -> acc
        end
      end)
    else
      %{}
    end
  end

  defp parse_rust_dependencies(_workspace_dir), do: %{}
  defp parse_go_dependencies(_workspace_dir), do: %{}

  # Metadata extraction functions

  defp extract_elixir_metadata(workspace_dir) do
    mix_file = Path.join(workspace_dir, "mix.exs")
    
    if File.exists?(mix_file) do
      try do
        content = File.read!(mix_file)
        
        %{
          app_name: extract_app_name(content),
          version: extract_version(content),
          elixir_version: extract_elixir_version(content)
        }
      rescue
        _ -> %{}
      end
    else
      %{}
    end
  end

  defp extract_javascript_metadata(_workspace_dir), do: %{}
  defp extract_python_metadata(_workspace_dir), do: %{}
  defp extract_rust_metadata(_workspace_dir), do: %{}
  defp extract_go_metadata(_workspace_dir), do: %{}

  defp extract_app_name(content) do
    case Regex.run(~r/app:\s*:(\w+)/, content) do
      [_, name] -> name
      _ -> nil
    end
  end

  defp extract_version(content) do
    case Regex.run(~r/version:\s*"([^"]+)"/, content) do
      [_, version] -> version
      _ -> nil
    end
  end

  defp extract_elixir_version(content) do
    case Regex.run(~r/elixir:\s*"([^"]+)"/, content) do
      [_, version] -> version
      _ -> nil
    end
  end

  # File relationship functions

  defp get_same_directory_files(context, file_path) do
    dir = Path.dirname(file_path)
    
    context.files
    |> Map.keys()
    |> Enum.filter(&(Path.dirname(&1) == dir))
  end

  defp find_test_source_counterparts(context, file_path) do
    # Logic to find corresponding test/source files
    # This is a simplified implementation
    base_name = Path.basename(file_path, Path.extname(file_path))
    
    context.files
    |> Map.keys()
    |> Enum.filter(fn path ->
      other_base = Path.basename(path, Path.extname(path))
      String.contains?(other_base, base_name) or String.contains?(base_name, other_base)
    end)
  end

  defp find_similar_named_files(context, file_path) do
    base_name = Path.basename(file_path, Path.extname(file_path))
    
    context.files
    |> Map.keys()
    |> Enum.filter(fn path ->
      other_base = Path.basename(path, Path.extname(path))
      String.jaro_distance(base_name, other_base) > 0.7
    end)
  end

  defp matches_criteria?(file_path, file_info, criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :type -> file_info.type == value
        :language -> file_info.language == value
        :extension -> Path.extname(file_path) == value
        :contains -> String.contains?(file_path, value)
        :modified_since -> 
          case Date.from_iso8601(value) do
            {:ok, date} -> Date.compare(DateTime.to_date(file_info.modified), date) != :lt
            _ -> false
          end
        _ -> true
      end
    end)
  end
end