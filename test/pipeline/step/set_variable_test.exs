defmodule Pipeline.Step.SetVariableTest do
  use ExUnit.Case, async: true
  alias Pipeline.Step.SetVariable
  alias Pipeline.State.VariableEngine

  describe "execute/2" do
    test "sets variables in global scope by default" do
      step = %{
        "name" => "set_test_vars",
        "type" => "set_variable",
        "variables" => %{
          "counter" => 0,
          "name" => "test_pipeline"
        }
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, result, updated_context} = SetVariable.execute(step, context)

      assert result["variables_set"] == ["counter", "name"]
      assert result["scope"] == "global"
      assert result["variable_count"] == 2

      assert VariableEngine.get_variable(updated_context.variable_state, "counter") == 0

      assert VariableEngine.get_variable(updated_context.variable_state, "name") ==
               "test_pipeline"
    end

    test "sets variables in specified scope" do
      step = %{
        "name" => "set_session_vars",
        "type" => "set_variable",
        "variables" => %{
          "session_id" => "abc123"
        },
        "scope" => "session"
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, result, updated_context} = SetVariable.execute(step, context)

      assert result["scope"] == "session"
      assert updated_context.variable_state.session["session_id"] == "abc123"
      assert updated_context.variable_state.global == %{}
    end

    test "handles variable interpolation when setting" do
      initial_state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"count" => 5}, :global)

      step = %{
        "name" => "increment_counter",
        "type" => "set_variable",
        "variables" => %{
          "count" => "{{state.count + 1}}",
          "doubled" => "{{state.count * 2}}"
        }
      }

      context = %{variable_state: initial_state}

      assert {:ok, _result, updated_context} = SetVariable.execute(step, context)

      assert VariableEngine.get_variable(updated_context.variable_state, "count") == 6
      assert VariableEngine.get_variable(updated_context.variable_state, "doubled") == 10
    end

    test "creates new variable state if none exists" do
      step = %{
        "name" => "set_initial_vars",
        "type" => "set_variable",
        "variables" => %{
          "initialized" => true
        }
      }

      # No variable_state
      context = %{}

      assert {:ok, result, updated_context} = SetVariable.execute(step, context)

      assert result["variables_set"] == ["initialized"]
      assert VariableEngine.get_variable(updated_context.variable_state, "initialized") == true
    end

    test "returns error for empty variables" do
      step = %{
        "name" => "empty_vars",
        "type" => "set_variable",
        "variables" => %{}
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, result} = SetVariable.execute(step, context)
      assert result == %{}
    end

    test "handles missing variables field" do
      step = %{
        "name" => "missing_vars",
        "type" => "set_variable"
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, result} = SetVariable.execute(step, context)
      assert result == %{}
    end

    test "supports complex data structures" do
      step = %{
        "name" => "set_complex_vars",
        "type" => "set_variable",
        "variables" => %{
          "config" => %{
            "database" => %{
              "host" => "localhost",
              "port" => 5432
            },
            "features" => ["auth", "logging"]
          }
        }
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, _result, updated_context} = SetVariable.execute(step, context)

      config = VariableEngine.get_variable(updated_context.variable_state, "config")
      assert config["database"]["host"] == "localhost"
      assert config["database"]["port"] == 5432
      assert config["features"] == ["auth", "logging"]
    end

    test "preserves existing variables when adding new ones" do
      initial_state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"existing" => "value"}, :global)

      step = %{
        "name" => "add_vars",
        "type" => "set_variable",
        "variables" => %{
          "new" => "new_value"
        }
      }

      context = %{variable_state: initial_state}

      assert {:ok, _result, updated_context} = SetVariable.execute(step, context)

      assert VariableEngine.get_variable(updated_context.variable_state, "existing") == "value"
      assert VariableEngine.get_variable(updated_context.variable_state, "new") == "new_value"
    end
  end

  describe "validate_config/1" do
    test "validates valid configuration" do
      step = %{
        "name" => "valid_step",
        "type" => "set_variable",
        "variables" => %{
          "test" => "value"
        }
      }

      assert SetVariable.validate_config(step) == :ok
    end

    test "validates configuration with scope" do
      step = %{
        "name" => "valid_step",
        "type" => "set_variable",
        "variables" => %{
          "test" => "value"
        },
        "scope" => "session"
      }

      assert SetVariable.validate_config(step) == :ok
    end

    test "returns error for missing variables field" do
      step = %{
        "name" => "invalid_step",
        "type" => "set_variable"
      }

      assert {:error, errors} = SetVariable.validate_config(step)
      assert "Missing 'variables' field" in errors
    end

    test "returns error for non-map variables" do
      step = %{
        "name" => "invalid_step",
        "type" => "set_variable",
        "variables" => ["not", "a", "map"]
      }

      assert {:error, errors} = SetVariable.validate_config(step)
      assert "'variables' must be a map" in errors
    end

    test "returns error for invalid scope" do
      step = %{
        "name" => "invalid_step",
        "type" => "set_variable",
        "variables" => %{"test" => "value"},
        "scope" => "invalid_scope"
      }

      assert {:error, errors} = SetVariable.validate_config(step)
      assert "Invalid scope: must be 'global', 'session', or 'loop'" in errors
    end

    test "returns multiple errors for multiple issues" do
      step = %{
        "name" => "invalid_step",
        "type" => "set_variable",
        "variables" => "not a map",
        "scope" => "invalid"
      }

      assert {:error, errors} = SetVariable.validate_config(step)
      assert length(errors) == 2
      assert "'variables' must be a map" in errors
      assert "Invalid scope: must be 'global', 'session', or 'loop'" in errors
    end
  end

  describe "scope parsing" do
    test "defaults to global scope when no scope specified" do
      step = %{
        "name" => "test_step",
        "variables" => %{"test" => "value"}
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, result, updated_context} = SetVariable.execute(step, context)

      assert result["scope"] == "global"
      assert updated_context.variable_state.global["test"] == "value"
    end

    test "handles atom scope values" do
      step = %{
        "name" => "test_step",
        "variables" => %{"test" => "value"},
        "scope" => :session
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, result, updated_context} = SetVariable.execute(step, context)

      assert result["scope"] == "session"
      assert updated_context.variable_state.session["test"] == "value"
    end

    test "falls back to global for invalid scope values" do
      step = %{
        "name" => "test_step",
        "variables" => %{"test" => "value"},
        "scope" => "invalid_scope"
      }

      context = %{variable_state: VariableEngine.new_state()}

      assert {:ok, result, updated_context} = SetVariable.execute(step, context)

      assert result["scope"] == "global"
      assert updated_context.variable_state.global["test"] == "value"
    end
  end
end
