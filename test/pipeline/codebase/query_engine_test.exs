defmodule Pipeline.Codebase.QueryEngineTest do
  use ExUnit.Case, async: true

  alias Pipeline.Codebase.QueryEngine
  alias Pipeline.Codebase.Context

  @test_workspace_dir "/tmp/test_query_engine"

  setup do
    # Create test workspace
    File.mkdir_p!(@test_workspace_dir)
    File.mkdir_p!(Path.join(@test_workspace_dir, "lib"))
    File.mkdir_p!(Path.join(@test_workspace_dir, "test"))
    File.mkdir_p!(Path.join(@test_workspace_dir, "src"))

    # Create test files
    create_test_files()

    # Create test context
    context = Context.discover(@test_workspace_dir)

    on_exit(fn ->
      File.rm_rf!(@test_workspace_dir)
    end)

    {:ok, context: context}
  end

  describe "find_files/2" do
    test "finds files by type", %{context: context} do
      files = QueryEngine.find_files(context, type: "source")

      assert is_list(files)
      assert length(files) > 0
      assert Enum.any?(files, &String.ends_with?(&1, ".ex"))
    end

    test "finds files by pattern", %{context: context} do
      files = QueryEngine.find_files(context, pattern: "lib/**/*.ex")

      assert is_list(files)
      assert Enum.all?(files, &String.starts_with?(&1, "lib/"))
      assert Enum.all?(files, &String.ends_with?(&1, ".ex"))
    end

    test "finds files by extension", %{context: context} do
      files = QueryEngine.find_files(context, extension: ".ex")

      assert is_list(files)
      assert Enum.all?(files, &String.ends_with?(&1, ".ex"))
    end

    test "finds files by language", %{context: context} do
      files = QueryEngine.find_files(context, language: "elixir")

      assert is_list(files)
      assert Enum.all?(files, &(String.ends_with?(&1, ".ex") or String.ends_with?(&1, ".exs")))
    end

    test "finds files containing substring", %{context: context} do
      files = QueryEngine.find_files(context, contains: "user")

      assert is_list(files)
      assert Enum.all?(files, &String.contains?(&1, "user"))
    end

    test "excludes test files when requested", %{context: context} do
      files = QueryEngine.find_files(context, exclude_tests: true)

      assert is_list(files)
      assert Enum.all?(files, &(not String.contains?(&1, "test")))
    end

    test "finds files by size criteria", %{context: context} do
      files = QueryEngine.find_files(context, size_min: 10)

      assert is_list(files)
      # All files should have at least 10 bytes
    end

    test "combines multiple criteria", %{context: context} do
      files =
        QueryEngine.find_files(context,
          type: "source",
          extension: ".ex",
          exclude_tests: true
        )

      assert is_list(files)
      assert Enum.all?(files, &String.ends_with?(&1, ".ex"))
      assert Enum.all?(files, &(not String.contains?(&1, "test")))
    end
  end

  describe "find_dependencies/2" do
    test "finds project dependencies", %{context: context} do
      result = QueryEngine.find_dependencies(context, [])

      assert Map.has_key?(result, :direct)
      assert Map.has_key?(result, :transitive)
      assert Map.has_key?(result, :file_specific)
      assert is_list(result[:direct])
      assert is_list(result[:transitive])
      assert is_map(result[:file_specific])
    end

    test "finds dependencies for specific file", %{context: context} do
      result = QueryEngine.find_dependencies(context, for_file: "lib/user.ex")

      assert Map.has_key?(result, :file_specific)
      assert Map.has_key?(result[:file_specific], "lib/user.ex")
    end

    test "includes transitive dependencies when requested", %{context: context} do
      result =
        QueryEngine.find_dependencies(context,
          for_file: "lib/user.ex",
          include_transitive: true
        )

      file_deps = result[:file_specific]["lib/user.ex"]
      assert is_list(file_deps)
    end
  end

  describe "find_functions/2" do
    test "finds all functions in project", %{context: context} do
      functions = QueryEngine.find_functions(context, [])

      assert is_list(functions)
      assert Enum.all?(functions, &is_map/1)
      assert Enum.all?(functions, &Map.has_key?(&1, :name))
      assert Enum.all?(functions, &Map.has_key?(&1, :file))
    end

    test "finds functions by name", %{context: context} do
      functions = QueryEngine.find_functions(context, name: "create_user")

      assert is_list(functions)
      assert Enum.all?(functions, &(&1.name == "create_user"))
    end

    test "finds functions in specific file", %{context: context} do
      functions = QueryEngine.find_functions(context, in_file: "lib/user.ex")

      assert is_list(functions)
      assert Enum.all?(functions, &(&1.file == "lib/user.ex"))
    end

    test "finds functions by language", %{context: context} do
      functions = QueryEngine.find_functions(context, language: "elixir")

      assert is_list(functions)
      # Should find functions in .ex files
    end

    test "finds functions by pattern", %{context: context} do
      functions = QueryEngine.find_functions(context, pattern: "create_.*")

      assert is_list(functions)
      assert Enum.all?(functions, &String.match?(&1.name, ~r/create_.*/))
    end
  end

  describe "find_related_files/2" do
    test "finds related files", %{context: context} do
      related = QueryEngine.find_related_files(context, file: "lib/user.ex")

      assert is_list(related)
      assert Enum.all?(related, &is_map/1)
      assert Enum.all?(related, &Map.has_key?(&1, :file))
      assert Enum.all?(related, &Map.has_key?(&1, :relation_type))
      assert Enum.all?(related, &Map.has_key?(&1, :confidence))
    end

    test "finds test files for source file", %{context: context} do
      related =
        QueryEngine.find_related_files(context,
          file: "lib/user.ex",
          types: ["test"]
        )

      assert is_list(related)
      test_relations = Enum.filter(related, &(&1.relation_type == "test"))
      assert length(test_relations) > 0
    end

    test "finds similar files", %{context: context} do
      related =
        QueryEngine.find_related_files(context,
          file: "lib/user.ex",
          types: ["similar"]
        )

      assert is_list(related)
      similar_relations = Enum.filter(related, &(&1.relation_type == "similar"))
      assert Enum.all?(similar_relations, &(&1.confidence > 0.0))
    end

    test "finds files in same directory", %{context: context} do
      related =
        QueryEngine.find_related_files(context,
          file: "lib/user.ex",
          types: ["directory"]
        )

      assert is_list(related)
      directory_relations = Enum.filter(related, &(&1.relation_type == "directory"))
      assert Enum.all?(directory_relations, &String.starts_with?(&1.file, "lib/"))
    end

    test "limits results when max_results specified", %{context: context} do
      related =
        QueryEngine.find_related_files(context,
          file: "lib/user.ex",
          max_results: 2
        )

      assert is_list(related)
      assert length(related) <= 2
    end

    test "returns empty list for non-existent file", %{context: context} do
      related = QueryEngine.find_related_files(context, file: "non_existent.ex")

      assert related == []
    end
  end

  describe "analyze_impact/2" do
    test "analyzes impact of file changes", %{context: context} do
      impact = QueryEngine.analyze_impact(context, file: "lib/user.ex")

      assert Map.has_key?(impact, :directly_affected)
      assert Map.has_key?(impact, :potentially_affected)
      assert Map.has_key?(impact, :test_files)
      assert Map.has_key?(impact, :impact_score)

      assert is_list(impact[:directly_affected])
      assert is_list(impact[:potentially_affected])
      assert is_list(impact[:test_files])
      assert is_integer(impact[:impact_score])
      assert impact[:impact_score] >= 0
    end

    test "includes test files in impact analysis", %{context: context} do
      impact =
        QueryEngine.analyze_impact(context,
          file: "lib/user.ex",
          include_tests: true
        )

      assert is_list(impact[:test_files])
    end

    test "excludes test files when requested", %{context: context} do
      impact =
        QueryEngine.analyze_impact(context,
          file: "lib/user.ex",
          include_tests: false
        )

      assert impact[:test_files] == []
    end

    test "respects max_depth parameter", %{context: context} do
      impact1 =
        QueryEngine.analyze_impact(context,
          file: "lib/user.ex",
          max_depth: 1
        )

      impact2 =
        QueryEngine.analyze_impact(context,
          file: "lib/user.ex",
          max_depth: 3
        )

      # Higher depth should potentially find more affected files
      assert impact1[:impact_score] <= impact2[:impact_score]
    end

    test "returns empty analysis for non-existent file", %{context: context} do
      impact = QueryEngine.analyze_impact(context, file: "non_existent.ex")

      assert impact[:directly_affected] == []
      assert impact[:potentially_affected] == []
      assert impact[:test_files] == []
      assert impact[:impact_score] == 0
    end
  end

  describe "error handling" do
    test "handles empty criteria gracefully", %{context: context} do
      files = QueryEngine.find_files(context, [])

      assert is_list(files)
      assert length(files) > 0
    end

    test "handles invalid criteria gracefully", %{context: context} do
      files = QueryEngine.find_files(context, invalid_criterion: "value")

      assert is_list(files)
      # Invalid criteria should be ignored
    end
  end

  # Helper functions

  defp create_test_files do
    # Create mix.exs
    mix_content = """
    defmodule TestProject.MixProject do
      use Mix.Project

      def project do
        [
          app: :test_project,
          version: "0.1.0",
          elixir: "~> 1.12",
          deps: deps()
        ]
      end

      defp deps do
        [
          {:jason, "~> 1.2"},
          {:plug, "~> 1.12"}
        ]
      end
    end
    """

    File.write!(Path.join(@test_workspace_dir, "mix.exs"), mix_content)

    # Create lib/user.ex
    user_content = """
    defmodule TestProject.User do
      @moduledoc "User management module"

      alias TestProject.Account
      import TestProject.Utils

      def create_user(params) do
        # Create user logic
        {:ok, params}
      end

      def update_user(id, params) do
        # Update user logic
        {:ok, params}
      end

      def delete_user(id) do
        # Delete user logic
        :ok
      end

      defp validate_user(params) do
        # Validation logic
        {:ok, params}
      end
    end
    """

    File.write!(Path.join([@test_workspace_dir, "lib", "user.ex"]), user_content)

    # Create lib/account.ex
    account_content = """
    defmodule TestProject.Account do
      alias TestProject.User

      def create_account(user_id) do
        case User.create_user(%{id: user_id}) do
          {:ok, user} -> {:ok, %{id: 1, user_id: user_id}}
          error -> error
        end
      end

      def get_account(id) do
        {:ok, %{id: id}}
      end
    end
    """

    File.write!(Path.join([@test_workspace_dir, "lib", "account.ex"]), account_content)

    # Create lib/utils.ex
    utils_content = """
    defmodule TestProject.Utils do
      def format_date(date) do
        Date.to_string(date)
      end

      def validate_email(email) do
        String.contains?(email, "@")
      end
    end
    """

    File.write!(Path.join([@test_workspace_dir, "lib", "utils.ex"]), utils_content)

    # Create test/user_test.exs
    test_content = """
    defmodule TestProject.UserTest do
      use ExUnit.Case

      alias TestProject.User

      test "creates user successfully" do
        assert {:ok, _} = User.create_user(%{name: "John"})
      end

      test "updates user successfully" do
        assert {:ok, _} = User.update_user(1, %{name: "Jane"})
      end

      test "deletes user successfully" do
        assert :ok = User.delete_user(1)
      end
    end
    """

    File.write!(Path.join([@test_workspace_dir, "test", "user_test.exs"]), test_content)

    # Create test/account_test.exs
    account_test_content = """
    defmodule TestProject.AccountTest do
      use ExUnit.Case

      alias TestProject.Account

      test "creates account successfully" do
        assert {:ok, _} = Account.create_account(1)
      end

      test "gets account successfully" do
        assert {:ok, _} = Account.get_account(1)
      end
    end
    """

    File.write!(
      Path.join([@test_workspace_dir, "test", "account_test.exs"]),
      account_test_content
    )

    # Create src/main.js (for multi-language testing)
    js_content = """
    import { createUser } from './user.js';

    function main() {
      const user = createUser({ name: 'John' });
      console.log('User created:', user);
    }

    export { main };
    """

    File.write!(Path.join([@test_workspace_dir, "src", "main.js"]), js_content)

    # Create src/user.js
    user_js_content = """
    function createUser(params) {
      return { id: 1, ...params };
    }

    function updateUser(id, params) {
      return { id, ...params };
    }

    class UserManager {
      constructor() {
        this.users = [];
      }

      addUser(user) {
        this.users.push(user);
      }
    }

    export { createUser, updateUser, UserManager };
    """

    File.write!(Path.join([@test_workspace_dir, "src", "user.js"]), user_js_content)
  end
end
