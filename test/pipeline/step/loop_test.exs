defmodule Pipeline.Step.LoopTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.Step.Loop

  describe "for_loop validation" do
    test "validates required fields" do
      context = %{results: %{}}

      # Missing iterator
      step1 = %{"name" => "test", "type" => "for_loop", "data_source" => "list"}
      assert {:error, "For loop requires 'iterator' field"} = Loop.execute(step1, context)

      # Missing steps
      step2 = %{
        "name" => "test",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "list"
      }

      assert {:error, "Loop requires 'steps' field"} = Loop.execute(step2, context)

      # Missing data_source
      step3 = %{"name" => "test", "type" => "for_loop", "iterator" => "item", "steps" => []}
      assert {:error, "For loop requires 'data_source' field"} = Loop.execute(step3, context)
    end

    test "handles missing data source" do
      step = %{
        "name" => "missing_source",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "nonexistent",
        "steps" => []
      }

      context = %{results: %{}}

      assert {:error, reason} = Loop.execute(step, context)
      assert String.contains?(reason, "Step result not found")
    end

    test "handles non-list data source" do
      step = %{
        "name" => "non_list_source",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "not_a_list",
        "steps" => []
      }

      context = %{results: %{"not_a_list" => "this is a string, not a list"}}

      assert {:error, reason} = Loop.execute(step, context)
      assert String.contains?(reason, "Data source must resolve to a list")
    end

    test "handles empty list" do
      step = %{
        "name" => "process_empty",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "empty_list",
        "steps" => [
          %{"name" => "process", "type" => "claude", "prompt" => "Process {{loop.item}}"}
        ]
      }

      context = %{results: %{"empty_list" => []}}

      assert {:ok, result} = Loop.execute(step, context)
      assert result["success"] == true
      assert result["total_items"] == 0
      assert result["completed_items"] == 0
      assert result["iterations"] == []
    end
  end

  describe "while_loop validation" do
    test "validates required fields for while loop" do
      context = %{results: %{}}

      # Missing condition
      step1 = %{"name" => "test", "type" => "while_loop", "steps" => []}
      assert {:error, "While loop requires 'condition' field"} = Loop.execute(step1, context)

      # Missing steps
      step2 = %{"name" => "test", "type" => "while_loop", "condition" => "true"}
      assert {:error, "Loop requires 'steps' field"} = Loop.execute(step2, context)
    end
  end

  describe "data source resolution" do
    test "resolves data from step result" do
      step = %{
        "name" => "test_resolution",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "file_list",
        "steps" => []
      }

      context = %{
        results: %{
          "file_list" => [1, 2, 3]
        }
      }

      assert {:ok, result} = Loop.execute(step, context)
      assert result["total_items"] == 3
    end

    test "resolves data from previous_response" do
      step = %{
        "name" => "test_previous",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "previous_response",
        "steps" => []
      }

      context = %{
        results: %{
          "previous_response" => [1, 2, 3]
        }
      }

      assert {:ok, result} = Loop.execute(step, context)
      assert result["total_items"] == 3
    end

    test "resolves data from previous_response with field path" do
      step = %{
        "name" => "test_nested",
        "type" => "for_loop",
        "iterator" => "user",
        "data_source" => "previous_response:data.users",
        "steps" => []
      }

      context = %{
        results: %{
          "previous_response" => %{
            "data" => %{
              "users" => [
                %{"name" => "Alice", "id" => 1},
                %{"name" => "Bob", "id" => 2}
              ]
            }
          }
        }
      }

      assert {:ok, result} = Loop.execute(step, context)
      assert result["total_items"] == 2
    end

    test "resolves data from specific step with field" do
      step = %{
        "name" => "test_step_field",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "step1:items",
        "steps" => []
      }

      context = %{
        results: %{
          "step1" => %{
            "items" => [1, 2, 3, 4]
          }
        }
      }

      assert {:ok, result} = Loop.execute(step, context)
      assert result["total_items"] == 4
    end
  end

  describe "max_iterations handling" do
    test "uses default max_iterations when not specified" do
      step = %{
        "name" => "default_max",
        "type" => "while_loop",
        # Will be false immediately
        "condition" => "false",
        "steps" => []
      }

      context = %{results: %{}}

      assert {:ok, result} = Loop.execute(step, context)
      assert result["iterations"] == 0
    end

    test "respects custom max_iterations" do
      step = %{
        "name" => "custom_max",
        "type" => "while_loop",
        "condition" => "false",
        "max_iterations" => 5,
        "steps" => []
      }

      context = %{results: %{}}

      assert {:ok, result} = Loop.execute(step, context)
      assert result["iterations"] == 0
    end

    test "caps max_iterations at system limit" do
      step = %{
        "name" => "excessive_max",
        "type" => "while_loop",
        "condition" => "false",
        # Exceeds system limit
        "max_iterations" => 99999,
        "steps" => []
      }

      context = %{results: %{}}

      # Should still work, just with capped limit
      assert {:ok, _result} = Loop.execute(step, context)
    end
  end

  describe "loop type validation" do
    test "handles unknown loop type" do
      step = %{
        "name" => "unknown_loop",
        "type" => "unknown_loop",
        "steps" => []
      }

      context = %{results: %{}}

      assert {:error, "Unknown loop type: unknown_loop"} = Loop.execute(step, context)
    end
  end
end
