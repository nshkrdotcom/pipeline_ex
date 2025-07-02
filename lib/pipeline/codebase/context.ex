defmodule Pipeline.Codebase.Context do
  @moduledoc """
  Codebase discovery and context analysis system.
  
  Automatically analyzes project structure and provides intelligent context
  to pipeline steps including project type detection, file structure analysis,
  dependency parsing, and git information integration.
  """

  alias Pipeline.Codebase.Discovery
  
  @type project_type :: :elixir | :javascript | :python | :rust | :go | :unknown
  @type file_info :: %{
    type: String.t(),
    size: non_neg_integer(),
    modified: DateTime.t(),
    language: String.t() | nil
  }
  @type git_info :: %{
    branch: String.t() | nil,
    commit: String.t() | nil,
    status: String.t() | nil,
    recent_commits: [String.t()]
  }
  @type structure_info :: %{
    directories: [String.t()],
    main_files: [String.t()],
    test_files: [String.t()],
    config_files: [String.t()],
    source_files: [String.t()]
  }

  @type t :: %__MODULE__{
    root_path: String.t(),
    project_type: project_type(),
    files: %{String.t() => file_info()},
    dependencies: map(),
    git_info: git_info(),
    structure: structure_info(),
    metadata: map()
  }

  defstruct [
    :root_path,
    :project_type,
    :files,
    :dependencies,
    :git_info,
    :structure,
    :metadata
  ]

  @doc """
  Discover and analyze codebase context for a given workspace directory.
  
  ## Examples
  
      iex> context = Pipeline.Codebase.Context.discover("/path/to/project")
      %Pipeline.Codebase.Context{
        project_type: :elixir,
        root_path: "/path/to/project",
        ...
      }
  """
  @spec discover(String.t()) :: t()
  def discover(workspace_dir) do
    workspace_dir = Path.expand(workspace_dir)
    
    %__MODULE__{
      root_path: workspace_dir,
      project_type: Discovery.detect_project_type(workspace_dir),
      files: Discovery.scan_files(workspace_dir),
      dependencies: Discovery.parse_dependencies(workspace_dir),
      git_info: Discovery.get_git_info(workspace_dir),
      structure: Discovery.analyze_structure(workspace_dir),
      metadata: Discovery.extract_metadata(workspace_dir)
    }
  end

  @doc """
  Convert context to template variables for use in pipeline steps.
  
  ## Examples
  
      iex> context |> Pipeline.Codebase.Context.to_template_vars()
      %{
        "codebase.project_type" => "elixir",
        "codebase.structure.main_files" => ["lib/my_app.ex"],
        ...
      }
  """
  @spec to_template_vars(t()) :: map()
  def to_template_vars(%__MODULE__{} = context) do
    %{
      "codebase.project_type" => Atom.to_string(context.project_type),
      "codebase.root_path" => context.root_path,
      "codebase.structure.main_files" => context.structure.main_files,
      "codebase.structure.test_files" => context.structure.test_files,
      "codebase.structure.config_files" => context.structure.config_files,
      "codebase.structure.directories" => context.structure.directories,
      "codebase.dependencies" => format_dependencies(context.dependencies),
      "codebase.git_info.branch" => context.git_info.branch,
      "codebase.git_info.commit" => context.git_info.commit,
      "codebase.git_info.recent_commits" => Enum.join(context.git_info.recent_commits, "\n"),
      "codebase.file_count" => map_size(context.files),
      "codebase.metadata" => Jason.encode!(context.metadata)
    }
  end

  @doc """
  Find files related to a given file path using various heuristics.
  """
  @spec find_related_files(t(), String.t()) :: [String.t()]
  def find_related_files(%__MODULE__{} = context, file_path) do
    Discovery.find_related_files(context, file_path)
  end

  @doc """
  Query files by various criteria.
  """
  @spec query_files(t(), keyword()) :: [String.t()]
  def query_files(%__MODULE__{} = context, criteria) do
    Discovery.query_files(context, criteria)
  end

  @doc """
  Get a summary of the codebase for use in prompts.
  """
  @spec get_summary(t()) :: String.t()
  def get_summary(%__MODULE__{} = context) do
    """
    Project Type: #{context.project_type}
    Root Path: #{context.root_path}
    
    Structure:
    - Directories: #{length(context.structure.directories)}
    - Source files: #{length(context.structure.source_files)}
    - Test files: #{length(context.structure.test_files)}
    - Config files: #{length(context.structure.config_files)}
    
    Main Files:
    #{context.structure.main_files |> Enum.take(10) |> Enum.join("\n")}
    
    Dependencies: #{map_size(context.dependencies)}
    
    Git Info:
    - Branch: #{context.git_info.branch || "unknown"}
    - Latest commit: #{context.git_info.commit || "unknown"}
    """
  end

  # Private helper functions

  defp format_dependencies(deps) when is_map(deps) do
    deps
    |> Enum.map(fn {name, version} -> "#{name}: #{version}" end)
    |> Enum.join(", ")
  end

  defp format_dependencies(_), do: ""
end