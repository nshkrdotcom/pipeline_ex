defmodule Pipeline.State.VariableEngineTest do
  use ExUnit.Case, async: true
  alias Pipeline.State.VariableEngine

  describe "new_state/0" do
    test "creates empty state with proper structure" do
      state = VariableEngine.new_state()

      assert state.global == %{}
      assert state.session == %{}
      assert state.loop == %{}
      assert state.current_step == nil
      assert state.step_index == 0
    end
  end

  describe "set_variables/3" do
    test "sets variables in global scope by default" do
      state = VariableEngine.new_state()
      variables = %{"count" => 1, "name" => "test"}

      updated_state = VariableEngine.set_variables(state, variables)

      assert updated_state.global["count"] == 1
      assert updated_state.global["name"] == "test"
      assert updated_state.session == %{}
      assert updated_state.loop == %{}
    end

    test "sets variables in specified scope" do
      state = VariableEngine.new_state()
      variables = %{"session_var" => "value"}

      updated_state = VariableEngine.set_variables(state, variables, :session)

      assert updated_state.global == %{}
      assert updated_state.session["session_var"] == "value"
      assert updated_state.loop == %{}
    end

    test "merges with existing variables in scope" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"existing" => "value"}, :global)

      updated_state = VariableEngine.set_variables(state, %{"new" => "value2"}, :global)

      assert updated_state.global["existing"] == "value"
      assert updated_state.global["new"] == "value2"
    end

    test "resolves variable expressions when setting" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"count" => 5}, :global)

      updated_state =
        VariableEngine.set_variables(state, %{"next_count" => "{{state.count + 1}}"}, :global)

      assert updated_state.global["next_count"] == 6
    end
  end

  describe "get_variable/2" do
    test "retrieves variable from global scope" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"test_var" => "global_value"}, :global)

      assert VariableEngine.get_variable(state, "test_var") == "global_value"
    end

    test "returns nil for non-existent variable" do
      state = VariableEngine.new_state()

      assert VariableEngine.get_variable(state, "nonexistent") == nil
    end

    test "follows scope precedence: loop > session > global" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"var" => "global"}, :global)
        |> VariableEngine.set_variables(%{"var" => "session"}, :session)
        |> VariableEngine.set_variables(%{"var" => "loop"}, :loop)

      assert VariableEngine.get_variable(state, "var") == "loop"
    end

    test "falls back to lower scopes when variable not in higher scope" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"global_var" => "global"}, :global)
        |> VariableEngine.set_variables(%{"session_var" => "session"}, :session)

      assert VariableEngine.get_variable(state, "global_var") == "global"
      assert VariableEngine.get_variable(state, "session_var") == "session"
    end
  end

  describe "get_all_variables/1" do
    test "returns flattened variables with scope precedence" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(
          %{"global_var" => "global", "shared" => "global_val"},
          :global
        )
        |> VariableEngine.set_variables(
          %{"session_var" => "session", "shared" => "session_val"},
          :session
        )
        |> VariableEngine.set_variables(%{"loop_var" => "loop", "shared" => "loop_val"}, :loop)

      all_vars = VariableEngine.get_all_variables(state)

      assert all_vars["global_var"] == "global"
      assert all_vars["session_var"] == "session"
      assert all_vars["loop_var"] == "loop"
      # Loop scope takes precedence
      assert all_vars["shared"] == "loop_val"
    end
  end

  describe "clear_scope/2" do
    test "clears variables in specified scope only" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"global_var" => "global"}, :global)
        |> VariableEngine.set_variables(%{"session_var" => "session"}, :session)
        |> VariableEngine.set_variables(%{"loop_var" => "loop"}, :loop)

      cleared_state = VariableEngine.clear_scope(state, :session)

      assert cleared_state.global["global_var"] == "global"
      assert cleared_state.session == %{}
      assert cleared_state.loop["loop_var"] == "loop"
    end
  end

  describe "update_step_info/3" do
    test "updates current step and index information" do
      state = VariableEngine.new_state()

      updated_state = VariableEngine.update_step_info(state, "test_step", 5)

      assert updated_state.current_step == "test_step"
      assert updated_state.step_index == 5
    end
  end

  describe "interpolate_string/2" do
    test "interpolates simple variables" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"name" => "Alice", "count" => 42}, :global)

      result = VariableEngine.interpolate_string("Hello {{name}}, count: {{count}}", state)

      assert result == "Hello Alice, count: 42"
    end

    test "interpolates state references" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"user" => %{"name" => "Bob", "age" => 30}}, :global)

      result =
        VariableEngine.interpolate_string(
          "User: {{state.user.name}}, Age: {{state.user.age}}",
          state
        )

      assert result == "User: Bob, Age: 30"
    end

    test "handles arithmetic expressions" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"count" => 5}, :global)

      result = VariableEngine.interpolate_string("Next: {{state.count + 1}}", state)

      assert result == "Next: 6"
    end

    test "returns original string if no variables to interpolate" do
      state = VariableEngine.new_state()

      result = VariableEngine.interpolate_string("Plain text", state)

      assert result == "Plain text"
    end

    test "handles missing variables gracefully" do
      state = VariableEngine.new_state()

      result = VariableEngine.interpolate_string("Hello {{missing}}", state)

      assert result == "Hello "
    end
  end

  describe "interpolate_data/2" do
    test "interpolates variables in maps" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"name" => "Alice", "port" => 8080}, :global)

      data = %{
        "host" => "{{name}}.example.com",
        "port" => "{{port}}",
        "nested" => %{
          "path" => "/api/{{name}}"
        }
      }

      result = VariableEngine.interpolate_data(data, state)

      assert result["host"] == "Alice.example.com"
      assert result["port"] == "8080"
      assert result["nested"]["path"] == "/api/Alice"
    end

    test "interpolates variables in lists" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"env" => "prod"}, :global)

      data = ["server-{{env}}-1", "server-{{env}}-2"]

      result = VariableEngine.interpolate_data(data, state)

      assert result == ["server-prod-1", "server-prod-2"]
    end

    test "preserves non-string values" do
      state = VariableEngine.new_state()

      data = %{
        "number" => 42,
        "boolean" => true,
        "nil_value" => nil
      }

      result = VariableEngine.interpolate_data(data, state)

      assert result == data
    end
  end

  describe "serialize_state/1 and deserialize_state/1" do
    test "serializes and deserializes state correctly" do
      original_state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"global_var" => "global"}, :global)
        |> VariableEngine.set_variables(%{"session_var" => "session"}, :session)
        |> VariableEngine.update_step_info("test_step", 3)

      serialized = VariableEngine.serialize_state(original_state)
      deserialized = VariableEngine.deserialize_state(serialized)

      assert deserialized.global["global_var"] == "global"
      assert deserialized.session["session_var"] == "session"
      assert deserialized.current_step == "test_step"
      assert deserialized.step_index == 3
      assert deserialized.loop == %{}
    end

    test "handles empty serialized data" do
      deserialized = VariableEngine.deserialize_state(%{})

      assert deserialized.global == %{}
      assert deserialized.session == %{}
      assert deserialized.loop == %{}
      assert deserialized.current_step == nil
      assert deserialized.step_index == 0
    end

    test "handles invalid serialized data" do
      deserialized = VariableEngine.deserialize_state("invalid")

      # Should return new_state() for invalid input
      expected = VariableEngine.new_state()
      assert deserialized == expected
    end
  end

  describe "complex variable operations" do
    test "supports nested variable references" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(
          %{
            "config" => %{
              "database" => %{
                "host" => "localhost",
                "port" => 5432
              }
            }
          },
          :global
        )

      template = "Database: {{state.config.database.host}}:{{state.config.database.port}}"
      result = VariableEngine.interpolate_string(template, state)

      assert result == "Database: localhost:5432"
    end

    test "handles mixed scopes in variable resolution" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"base_url" => "https://api.example.com"}, :global)
        |> VariableEngine.set_variables(%{"version" => "v1"}, :session)
        |> VariableEngine.set_variables(%{"endpoint" => "users"}, :loop)

      template = "{{base_url}}/{{version}}/{{endpoint}}"
      result = VariableEngine.interpolate_string(template, state)

      assert result == "https://api.example.com/v1/users"
    end

    test "supports arithmetic with multiple variables" do
      state =
        VariableEngine.new_state()
        |> VariableEngine.set_variables(%{"start" => 10, "increment" => 5}, :global)

      # Test addition
      result = VariableEngine.interpolate_string("{{state.start + state.increment}}", state)
      assert result == "15"

      # Test subtraction
      result = VariableEngine.interpolate_string("{{state.start - state.increment}}", state)
      assert result == "5"
    end
  end
end
