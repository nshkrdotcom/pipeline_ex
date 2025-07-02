defmodule Pipeline.Step.LoopPerformanceTest do
  @moduledoc """
  Performance tests for advanced loop features including nested loops,
  parallel execution, and memory management.
  """

  use ExUnit.Case
  alias Pipeline.Step.Loop

  # Mock context for testing
  defp create_test_context(data \\ []) do
    %{
      results: %{
        "test_data" => data
      },
      output_dir: "/tmp/test",
      variable_state: %{},
      workflow_name: "test_workflow",
      checkpoint_dir: "/tmp/test",
      checkpoint_enabled: false,
      execution_log: [],
      start_time: DateTime.utc_now(),
      step_index: 0,
      debug_enabled: false,
      config: %{}
    }
  end

  describe "Performance Tests" do
    test "handles large dataset with empty steps (structure test)" do
      # Create large dataset
      large_data = Enum.map(1..1000, &%{"id" => &1, "value" => "item_#{&1}"})
      
      step = %{
        "name" => "large_loop_test",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "test_data",
        "steps" => []  # Empty steps to test loop structure only
      }

      context = create_test_context(large_data)
      
      {time, result} = :timer.tc(fn -> Loop.execute(step, context) end)
      
      assert {:ok, results} = result
      assert results["success"] == true
      assert results["total_items"] == 1000
      assert results["completed_items"] == 1000
      assert time < 1_000_000 # Should complete within 1 second for empty steps
    end

    test "parallel execution with empty steps" do
      test_data = Enum.map(1..100, &%{"id" => &1, "value" => "item_#{&1}"})
      
      # Sequential execution
      sequential_step = %{
        "name" => "sequential_test",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "test_data",
        "parallel" => false,
        "steps" => []
      }

      # Parallel execution
      parallel_step = %{
        "name" => "parallel_test",
        "type" => "for_loop",
        "iterator" => "item", 
        "data_source" => "test_data",
        "parallel" => true,
        "max_parallel" => 5,
        "steps" => []
      }

      context = create_test_context(test_data)
      
      # Time sequential execution
      {seq_time, seq_result} = :timer.tc(fn -> Loop.execute(sequential_step, context) end)
      
      # Time parallel execution
      {par_time, par_result} = :timer.tc(fn -> Loop.execute(parallel_step, context) end)
      
      assert {:ok, seq_results} = seq_result
      assert {:ok, par_results} = par_result
      
      assert seq_results["success"] == true
      assert par_results["success"] == true
      assert seq_results["total_items"] == 100
      assert par_results["total_items"] == 100
      
      IO.puts("Sequential time: #{seq_time / 1000}ms")
      IO.puts("Parallel time: #{par_time / 1000}ms")
    end

    test "nested loop structure with proper scoping" do
      categories = [
        %{"name" => "cat1", "files" => [%{"path" => "file1.txt"}, %{"path" => "file2.txt"}]},
        %{"name" => "cat2", "files" => [%{"path" => "file3.txt"}, %{"path" => "file4.txt"}]}
      ]
      
      nested_step = %{
        "name" => "nested_processing",
        "type" => "for_loop",
        "iterator" => "category",
        "data_source" => "test_data",
        "steps" => [
          %{
            "name" => "process_files",
            "type" => "for_loop",  
            "iterator" => "file",
            "data_source" => "category:files",
            "steps" => []  # Empty inner steps
          }
        ]
      }

      context = create_test_context(categories)
      
      {time, result} = :timer.tc(fn -> Loop.execute(nested_step, context) end)
      
      assert {:ok, results} = result
      assert results["success"] == true
      assert results["total_items"] == 2 # 2 categories
      
      # Should complete reasonably quickly
      assert time < 5_000_000 # 5 seconds
      
      IO.puts("Nested loop time: #{time / 1000}ms")
    end

    test "memory management during loop execution" do
      # Test basic memory behavior with moderate dataset
      test_data = Enum.map(1..100, &%{"id" => &1, "data" => String.duplicate("x", 100)})
      
      step = %{
        "name" => "memory_test",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "test_data",
        "steps" => []
      }

      context = create_test_context(test_data)
      
      # Record initial memory
      initial_memory = :erlang.memory(:total)
      
      result = Loop.execute(step, context)
      
      # Record final memory
      final_memory = :erlang.memory(:total)
      
      assert {:ok, results} = result
      assert results["success"] == true
      
      # Memory should not grow excessively
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / 1_000_000
      
      IO.puts("Memory growth: #{Float.round(memory_growth_mb, 2)}MB")
      
      # Should not grow more than 50MB for this simple test
      assert memory_growth < 50_000_000
    end

    test "loop control flow structure validation" do
      test_data = Enum.map(1..100, &%{"id" => &1, "value" => &1})
      
      step = %{
        "name" => "controlled_loop",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "test_data",
        "break_condition" => "{{loop.item.id >= 50}}",
        "steps" => []
      }

      context = create_test_context(test_data)
      
      {time, result} = :timer.tc(fn -> Loop.execute(step, context) end)
      
      assert {:ok, results} = result
      
      # Should process items but structure is valid
      assert results["total_items"] == 100
      
      # Should complete quickly
      assert time < 2_000_000 # 2 seconds
      
      IO.puts("Loop control test completed in #{time / 1000}ms")
    end
  end

  describe "Structure Tests" do
    test "validates nested loop context creation" do
      test_data = [%{"id" => 1, "children" => [%{"name" => "child1"}, %{"name" => "child2"}]}]
      
      # Create a context that tests nested structure without execution
      context = create_test_context(test_data)
      
      # Test that we can create nested loop contexts
      parent_context = Pipeline.Step.Loop.create_nested_loop_context("parent", %{"id" => 1}, 0, 1, context)
      
      assert parent_context["loop"]["parent"]["id"] == 1
      assert parent_context["loop"]["level"] == 0
      
      # Test nested context creation
      child_context = Pipeline.Step.Loop.create_nested_loop_context("child", %{"name" => "child1"}, 0, 2, 
        %{context | results: Map.merge(context.results, parent_context)})
      
      assert child_context["loop"]["child"]["name"] == "child1"
      assert child_context["loop"]["level"] == 1
      assert child_context["loop"]["parent"]["parent"]["id"] == 1
    end
    
    test "validates parallel execution parameters" do
      test_data = Enum.map(1..10, &%{"id" => &1})
      
      parallel_step = %{
        "name" => "parallel_validation",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "test_data", 
        "parallel" => true,
        "max_parallel" => 3,
        "steps" => []
      }
      
      context = create_test_context(test_data)
      
      result = Loop.execute(parallel_step, context)
      
      assert {:ok, results} = result
      assert results["parallel"] == true
      assert results["max_parallel"] == 3
      assert results["success"] == true
    end
  end

  describe "Error Handling" do
    test "handles invalid data source gracefully" do
      step = %{
        "name" => "invalid_source",
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => "nonexistent_source",
        "steps" => []
      }
      
      context = create_test_context([])
      
      result = Loop.execute(step, context)
      
      assert {:error, _reason} = result
    end
    
    test "handles missing iterator gracefully" do
      step = %{
        "name" => "missing_iterator", 
        "type" => "for_loop",
        "data_source" => "test_data",
        "steps" => []
      }
      
      context = create_test_context([1, 2, 3])
      
      result = Loop.execute(step, context)
      
      assert {:error, _reason} = result
    end
  end
end