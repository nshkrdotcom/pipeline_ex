defmodule Pipeline.Codebase.ContextTest do
  use ExUnit.Case, async: true

  alias Pipeline.Codebase.Context
  alias Pipeline.Codebase.Discovery

  @test_workspace Path.join([System.tmp_dir!(), "pipeline_test_workspace"])

  setup do
    # Create a test workspace
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(@test_workspace)

    # Create sample Elixir project structure
    File.mkdir_p!(Path.join(@test_workspace, "lib"))
    File.mkdir_p!(Path.join(@test_workspace, "test"))
    File.mkdir_p!(Path.join(@test_workspace, "config"))

    # Create mix.exs
    mix_content = """
    defmodule TestApp.MixProject do
      use Mix.Project
      
      def project do
        [
          app: :test_app,
          version: "0.1.0",
          elixir: "~> 1.18",
          deps: deps()
        ]
      end
      
      defp deps do
        [
          {:jason, "~> 1.4"},
          {:req, "~> 0.5"}
        ]
      end
    end
    """

    File.write!(Path.join(@test_workspace, "mix.exs"), mix_content)

    # Create sample source file
    lib_content = """
    defmodule TestApp do
      @moduledoc \"\"\"
      Test application module.
      \"\"\"
      
      alias TestApp.User
      import Logger
      
      def hello(name) do
        "Hello, \#{name}!"
      end
      
      defp private_function do
        :ok
      end
    end
    """

    File.write!(Path.join([@test_workspace, "lib", "test_app.ex"]), lib_content)

    # Create sample test file
    test_content = """
    defmodule TestAppTest do
      use ExUnit.Case
      
      test "hello function" do
        assert TestApp.hello("World") == "Hello, World!"
      end
    end
    """

    File.write!(Path.join([@test_workspace, "test", "test_app_test.exs"]), test_content)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
    end)

    {:ok, workspace: @test_workspace}
  end

  describe "discover/1" do
    test "discovers Elixir project structure", %{workspace: workspace} do
      context = Context.discover(workspace)

      assert context.project_type == :elixir
      assert context.root_path == workspace
      assert is_map(context.files)
      assert is_map(context.dependencies)
      assert is_map(context.git_info)
      assert is_map(context.structure)
      assert is_map(context.metadata)
    end

    test "identifies main files correctly", %{workspace: workspace} do
      context = Context.discover(workspace)

      assert "mix.exs" in context.structure.main_files
      assert "lib/test_app.ex" in context.structure.main_files
    end

    test "identifies test files correctly", %{workspace: workspace} do
      context = Context.discover(workspace)

      assert "test/test_app_test.exs" in context.structure.test_files
    end

    test "parses dependencies correctly", %{workspace: workspace} do
      context = Context.discover(workspace)

      assert Map.has_key?(context.dependencies, "jason")
      assert Map.has_key?(context.dependencies, "req")
    end
  end

  describe "to_template_vars/1" do
    test "converts context to template variables", %{workspace: workspace} do
      context = Context.discover(workspace)
      vars = Context.to_template_vars(context)

      assert vars["codebase.project_type"] == "elixir"
      assert vars["codebase.root_path"] == workspace
      assert is_list(vars["codebase.structure.main_files"])
      assert is_list(vars["codebase.structure.test_files"])
      assert is_binary(vars["codebase.dependencies"])
      assert is_integer(vars["codebase.file_count"])
    end
  end

  describe "find_related_files/2" do
    test "finds related files for a source file", %{workspace: workspace} do
      context = Context.discover(workspace)
      related = Context.find_related_files(context, "lib/test_app.ex")

      # Should find the test file
      assert "test/test_app_test.exs" in related
    end
  end

  describe "query_files/2" do
    test "queries files by type", %{workspace: workspace} do
      context = Context.discover(workspace)

      files = Context.query_files(context, type: "file")
      assert length(files) > 0

      dirs = Context.query_files(context, type: "directory")
      assert length(dirs) > 0
    end

    test "queries files by language", %{workspace: workspace} do
      context = Context.discover(workspace)

      elixir_files = Context.query_files(context, language: "elixir")
      assert "lib/test_app.ex" in elixir_files
      assert "test/test_app_test.exs" in elixir_files
    end
  end

  describe "get_summary/1" do
    test "generates a readable summary", %{workspace: workspace} do
      context = Context.discover(workspace)
      summary = Context.get_summary(context)

      assert String.contains?(summary, "Project Type: elixir")
      assert String.contains?(summary, "Root Path: #{workspace}")
      assert String.contains?(summary, "mix.exs")
    end
  end
end

defmodule Pipeline.Codebase.DiscoveryTest do
  use ExUnit.Case, async: true

  alias Pipeline.Codebase.Discovery

  @test_workspace Path.join([System.tmp_dir!(), "pipeline_discovery_test"])

  setup do
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(@test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
    end)

    {:ok, workspace: @test_workspace}
  end

  describe "detect_project_type/1" do
    test "detects Elixir project", %{workspace: workspace} do
      File.write!(Path.join(workspace, "mix.exs"), "defmodule Test.MixProject, do: nil")

      assert Discovery.detect_project_type(workspace) == :elixir
    end

    test "detects JavaScript project", %{workspace: workspace} do
      File.write!(Path.join(workspace, "package.json"), "{}")

      assert Discovery.detect_project_type(workspace) == :javascript
    end

    test "detects Python project", %{workspace: workspace} do
      File.write!(Path.join(workspace, "requirements.txt"), "requests==2.25.1")

      assert Discovery.detect_project_type(workspace) == :python
    end

    test "returns unknown for unrecognized projects", %{workspace: workspace} do
      File.write!(Path.join(workspace, "random.txt"), "content")

      assert Discovery.detect_project_type(workspace) == :unknown
    end
  end

  describe "scan_files/1" do
    test "scans files and directories", %{workspace: workspace} do
      File.write!(Path.join(workspace, "test.ex"), "content")
      File.mkdir_p!(Path.join(workspace, "subdir"))
      File.write!(Path.join([workspace, "subdir", "nested.ex"]), "content")

      files = Discovery.scan_files(workspace)

      assert Map.has_key?(files, "test.ex")
      assert Map.has_key?(files, "subdir")
      assert Map.has_key?(files, "subdir/nested.ex")

      assert files["test.ex"].type == "file"
      assert files["subdir"].type == "directory"
      assert files["test.ex"].language == "elixir"
    end
  end

  describe "parse_dependencies/1" do
    test "parses Elixir dependencies from mix.exs", %{workspace: workspace} do
      mix_content = """
      defmodule Test.MixProject do
        use Mix.Project
        
        def project do
          [deps: deps()]
        end
        
        defp deps do
          [
            {:jason, "~> 1.4"},
            {:req, "~> 0.5"}
          ]
        end
      end
      """

      File.write!(Path.join(workspace, "mix.exs"), mix_content)

      deps = Discovery.parse_dependencies(workspace)

      assert Map.has_key?(deps, "jason")
      assert Map.has_key?(deps, "req")
    end

    test "parses JavaScript dependencies from package.json", %{workspace: workspace} do
      package_content = """
      {
        "dependencies": {
          "express": "^4.18.0",
          "lodash": "^4.17.21"
        }
      }
      """

      File.write!(Path.join(workspace, "package.json"), package_content)

      deps = Discovery.parse_dependencies(workspace)

      assert deps["express"] == "^4.18.0"
      assert deps["lodash"] == "^4.17.21"
    end
  end

  describe "analyze_structure/1" do
    test "analyzes project structure", %{workspace: workspace} do
      # Create structure
      File.mkdir_p!(Path.join(workspace, "lib"))
      File.mkdir_p!(Path.join(workspace, "test"))
      File.write!(Path.join(workspace, "mix.exs"), "content")
      File.write!(Path.join([workspace, "lib", "app.ex"]), "content")
      File.write!(Path.join([workspace, "test", "app_test.exs"]), "content")

      structure = Discovery.analyze_structure(workspace)

      assert "lib" in structure.directories
      assert "test" in structure.directories
      assert "mix.exs" in structure.main_files
      assert "lib/app.ex" in structure.main_files
      assert "test/app_test.exs" in structure.test_files
      assert "lib/app.ex" in structure.source_files
    end
  end
end
