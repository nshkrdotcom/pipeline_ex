defmodule Pipeline.Step.CodebaseQueryTest do
  use ExUnit.Case, async: true

  alias Pipeline.Step.CodebaseQuery
  alias Pipeline.Codebase.Context

  @test_workspace_dir "/tmp/test_codebase_query"

  setup do
    # Create test workspace
    File.mkdir_p!(@test_workspace_dir)
    File.mkdir_p!(Path.join(@test_workspace_dir, "lib"))
    File.mkdir_p!(Path.join(@test_workspace_dir, "test"))
    File.mkdir_p!(Path.join(@test_workspace_dir, "config"))

    # Create test files
    create_test_files()

    # Create test context
    context = %{
      workspace_dir: @test_workspace_dir,
      codebase_context: Context.discover(@test_workspace_dir)
    }

    on_exit(fn ->
      File.rm_rf!(@test_workspace_dir)
    end)

    {:ok, context: context}
  end

  describe "execute/2" do
    test "executes find_files query successfully", %{context: context} do
      step = %{
        "name" => "find_elixir_files",
        "type" => "codebase_query",
        "queries" => %{
          "main_files" => %{
            "find_files" => [
              %{"type" => "main"},
              %{"extension" => ".ex"}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      assert Map.has_key?(result, "main_files")
      assert Map.has_key?(result["main_files"], :files)
      assert Map.has_key?(result["main_files"], :count)
      assert is_list(result["main_files"][:files])
      assert is_integer(result["main_files"][:count])
    end

    test "executes find_dependencies query successfully", %{context: context} do
      step = %{
        "name" => "find_deps",
        "type" => "codebase_query",
        "queries" => %{
          "project_deps" => %{
            "find_dependencies" => [
              %{"include_transitive" => false}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      assert Map.has_key?(result, "project_deps")
      assert Map.has_key?(result["project_deps"], :dependencies)
      assert Map.has_key?(result["project_deps"][:dependencies], :direct)
      assert Map.has_key?(result["project_deps"][:dependencies], :transitive)
    end

    test "executes find_functions query successfully", %{context: context} do
      step = %{
        "name" => "find_funcs",
        "type" => "codebase_query",
        "queries" => %{
          "all_functions" => %{
            "find_functions" => [
              %{"language" => "elixir"}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      assert Map.has_key?(result, "all_functions")
      assert Map.has_key?(result["all_functions"], :functions)
      assert is_list(result["all_functions"][:functions])
    end

    test "executes find_related query successfully", %{context: context} do
      step = %{
        "name" => "find_related",
        "type" => "codebase_query",
        "queries" => %{
          "related_to_user" => %{
            "find_related" => [
              %{"file" => "lib/user.ex"},
              %{"types" => ["test", "similar"]}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      assert Map.has_key?(result, "related_to_user")
      assert Map.has_key?(result["related_to_user"], :related_files)
      assert is_list(result["related_to_user"][:related_files])
    end

    test "executes analyze_impact query successfully", %{context: context} do
      step = %{
        "name" => "analyze_impact",
        "type" => "codebase_query",
        "queries" => %{
          "user_impact" => %{
            "analyze_impact" => [
              %{"file" => "lib/user.ex"},
              %{"include_tests" => true}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      assert Map.has_key?(result, "user_impact")
      impact = result["user_impact"][:impact_analysis]

      assert Map.has_key?(impact, :directly_affected)
      assert Map.has_key?(impact, :potentially_affected)
      assert Map.has_key?(impact, :test_files)
      assert Map.has_key?(impact, :impact_score)
      assert is_integer(impact[:impact_score])
    end

    test "handles multiple queries in single step", %{context: context} do
      step = %{
        "name" => "multi_query",
        "type" => "codebase_query",
        "queries" => %{
          "files" => %{
            "find_files" => [%{"type" => "main"}]
          },
          "functions" => %{
            "find_functions" => [%{"language" => "elixir"}]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      assert Map.has_key?(result, "files")
      assert Map.has_key?(result, "functions")
    end

    test "handles template variable resolution", %{context: context} do
      context_with_vars =
        Map.merge(context, %{
          target_file: "lib/user.ex",
          previous_response: %{"target_file" => "lib/account.ex"}
        })

      step = %{
        "name" => "template_test",
        "type" => "codebase_query",
        "queries" => %{
          "related" => %{
            "find_related" => [
              %{"file" => "{{target_file}}"}
            ]
          },
          "prev_related" => %{
            "find_related" => [
              %{"file" => "{{previous_response:target_file}}"}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context_with_vars)

      assert Map.has_key?(result, "related")
      assert Map.has_key?(result, "prev_related")
    end

    test "returns error for invalid query type" do
      step = %{
        "name" => "invalid_query",
        "type" => "codebase_query",
        "queries" => %{
          "invalid" => %{
            "unknown_query_type" => []
          }
        }
      }

      context = %{workspace_dir: @test_workspace_dir}

      assert {:ok, result} = CodebaseQuery.execute(step, context)
      assert Map.has_key?(result, "invalid")
      assert Map.has_key?(result["invalid"], :error)
    end

    test "returns error for non-map queries" do
      step = %{
        "name" => "invalid_format",
        "type" => "codebase_query",
        "queries" => "not a map"
      }

      context = %{workspace_dir: @test_workspace_dir}

      assert {:error, reason} = CodebaseQuery.execute(step, context)
      assert String.contains?(reason, "Queries must be a map")
    end
  end

  describe "find_files criteria" do
    test "filters by file type", %{context: context} do
      step = %{
        "name" => "filter_test",
        "type" => "codebase_query",
        "queries" => %{
          "test_files" => %{
            "find_files" => [%{"type" => "test"}]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      files = result["test_files"][:files]
      assert Enum.all?(files, &String.contains?(&1, "test"))
    end

    test "filters by pattern", %{context: context} do
      step = %{
        "name" => "pattern_test",
        "type" => "codebase_query",
        "queries" => %{
          "lib_files" => %{
            "find_files" => [%{"pattern" => "lib/**/*.ex"}]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      files = result["lib_files"][:files]
      assert Enum.all?(files, &String.starts_with?(&1, "lib/"))
    end

    test "filters by extension", %{context: context} do
      step = %{
        "name" => "ext_test",
        "type" => "codebase_query",
        "queries" => %{
          "ex_files" => %{
            "find_files" => [%{"extension" => ".ex"}]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      files = result["ex_files"][:files]
      assert Enum.all?(files, &String.ends_with?(&1, ".ex"))
    end

    test "excludes test files when requested", %{context: context} do
      step = %{
        "name" => "exclude_test",
        "type" => "codebase_query",
        "queries" => %{
          "no_tests" => %{
            "find_files" => [
              %{"type" => "source"},
              %{"exclude_tests" => true}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      files = result["no_tests"][:files]
      assert Enum.all?(files, &(not String.contains?(&1, "test")))
    end
  end

  describe "dependencies analysis" do
    test "finds file-specific dependencies", %{context: context} do
      step = %{
        "name" => "file_deps",
        "type" => "codebase_query",
        "queries" => %{
          "user_deps" => %{
            "find_dependencies" => [
              %{"for_file" => "lib/user.ex"}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      deps = result["user_deps"][:dependencies]
      assert Map.has_key?(deps, :file_specific)
      assert Map.has_key?(deps[:file_specific], "lib/user.ex")
    end

    test "includes transitive dependencies when requested", %{context: context} do
      step = %{
        "name" => "transitive_deps",
        "type" => "codebase_query",
        "queries" => %{
          "all_deps" => %{
            "find_dependencies" => [
              %{"include_transitive" => true}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      deps = result["all_deps"][:dependencies]
      assert Map.has_key?(deps, :direct)
      assert Map.has_key?(deps, :transitive)
    end
  end

  describe "function analysis" do
    test "finds functions by name", %{context: context} do
      step = %{
        "name" => "named_func",
        "type" => "codebase_query",
        "queries" => %{
          "create_user" => %{
            "find_functions" => [
              %{"name" => "create_user"}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      functions = result["create_user"][:functions]
      assert Enum.all?(functions, &(&1.name == "create_user"))
    end

    test "finds functions in specific file", %{context: context} do
      step = %{
        "name" => "file_funcs",
        "type" => "codebase_query",
        "queries" => %{
          "user_funcs" => %{
            "find_functions" => [
              %{"in_file" => "lib/user.ex"}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      functions = result["user_funcs"][:functions]
      assert Enum.all?(functions, &(&1.file == "lib/user.ex"))
    end
  end

  describe "impact analysis" do
    test "calculates impact score", %{context: context} do
      step = %{
        "name" => "impact_score",
        "type" => "codebase_query",
        "queries" => %{
          "user_impact" => %{
            "analyze_impact" => [
              %{"file" => "lib/user.ex"},
              %{"max_depth" => 2}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      impact = result["user_impact"][:impact_analysis]
      assert is_integer(impact[:impact_score])
      assert impact[:impact_score] >= 0
    end

    test "finds test files in impact analysis", %{context: context} do
      step = %{
        "name" => "test_impact",
        "type" => "codebase_query",
        "queries" => %{
          "with_tests" => %{
            "analyze_impact" => [
              %{"file" => "lib/user.ex"},
              %{"include_tests" => true}
            ]
          }
        }
      }

      assert {:ok, result} = CodebaseQuery.execute(step, context)

      impact = result["with_tests"][:impact_analysis]
      assert is_list(impact[:test_files])
    end
  end

  describe "error handling" do
    test "handles invalid criteria gracefully" do
      step = %{
        "name" => "invalid_criteria",
        "type" => "codebase_query",
        "queries" => %{
          "bad_query" => %{
            "find_files" => "not a list"
          }
        }
      }

      context = %{workspace_dir: @test_workspace_dir}

      assert {:ok, result} = CodebaseQuery.execute(step, context)
      assert Map.has_key?(result, "bad_query")
      assert Map.has_key?(result["bad_query"], :error)
    end

    test "handles missing workspace directory" do
      step = %{
        "name" => "no_workspace",
        "type" => "codebase_query",
        "queries" => %{
          "files" => %{
            "find_files" => [%{"type" => "main"}]
          }
        }
      }

      context = %{}

      # Should still work with default "." directory
      File.cd!(@test_workspace_dir, fn ->
        assert {:ok, _result} = CodebaseQuery.execute(step, context)
      end)
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
      def create_account(user_id) do
        {:ok, %{id: 1, user_id: user_id}}
      end
    end
    """

    File.write!(Path.join([@test_workspace_dir, "lib", "account.ex"]), account_content)

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
    end
    """

    File.write!(Path.join([@test_workspace_dir, "test", "user_test.exs"]), test_content)

    # Create config/config.exs
    config_content = """
    import Config

    config :test_project,
      env: :test
    """

    File.write!(Path.join([@test_workspace_dir, "config", "config.exs"]), config_content)
  end
end
