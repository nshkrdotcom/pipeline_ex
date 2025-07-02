defmodule Pipeline.Performance.BasicTest do
  @moduledoc """
  Basic performance tests that are more reliable in CI environments.
  """

  use ExUnit.Case, async: false
  require Logger

  alias Pipeline.Executor
  alias Pipeline.Monitoring.Performance
  alias Pipeline.Utils.FileUtils

  @test_output_dir "test/tmp/basic_performance"

  setup do
    File.mkdir_p!(@test_output_dir)
    
    on_exit(fn ->
      File.rm_rf(@test_output_dir)
      cleanup_all_monitoring()
    end)
    
    :ok
  end

  describe "Basic performance features" do
    test "performance monitoring can start and stop" do
      test_name = "basic_monitoring_test"
      
      # Clean up any existing
      safe_stop_monitoring(test_name)
      
      # Start monitoring
      assert {:ok, _pid} = Performance.start_monitoring(test_name, memory_threshold: 10_000_000)
      
      # Check it's running
      assert {:ok, metrics} = Performance.get_metrics(test_name)
      assert is_map(metrics)
      
      # Stop monitoring
      assert {:ok, final_metrics} = Performance.stop_monitoring(test_name)
      assert is_map(final_metrics)
    end

    test "streaming file operations work with small files" do
      # Create a small test file
      test_file = Path.join(@test_output_dir, "test_input.txt")
      File.write!(test_file, "line 1\nline 2\nline 3\n")
      
      dest_file = Path.join(@test_output_dir, "test_copy.txt")
      
      # Test streaming copy
      assert :ok = FileUtils.stream_copy_file(test_file, dest_file)
      assert File.exists?(dest_file)
      
      # Verify content
      assert File.read!(dest_file) == File.read!(test_file)
    end

    test "data transform works with small datasets" do
      small_data = [
        %{"id" => 1, "priority" => "high", "active" => true},
        %{"id" => 2, "priority" => "low", "active" => false},
        %{"id" => 3, "priority" => "high", "active" => true}
      ]

      step = %{
        "name" => "filter_test",
        "type" => "data_transform",
        "input_source" => "previous_response:test_data",
        "operations" => [
          %{
            "operation" => "filter",
            "field" => "priority",
            "condition" => "priority == 'high'"
          }
        ]
      }

      context = %{
        results: %{
          "test_data" => small_data
        }
      }

      assert {:ok, result} = Pipeline.Step.DataTransform.execute(step, context)
      assert length(result["filter_test"]) == 2
    end

    test "file operations support basic operations" do
      # Test file listing
      workflow = %{
        "workflow" => %{
          "name" => "file_ops_test",
          "steps" => [
            %{
              "name" => "list_files",
              "type" => "file_ops",
              "operation" => "list",
              "path" => "."  # Use current directory instead
            }
          ]
        }
      }

      # Disable monitoring for this test
      result = Executor.execute(workflow, 
        output_dir: @test_output_dir, 
        enable_monitoring: false)
      
      assert {:ok, results} = result
      assert Map.has_key?(results, "list_files")
    end

    test "loops work with small datasets" do
      small_data = [%{"id" => 1}, %{"id" => 2}, %{"id" => 3}]

      workflow = %{
        "workflow" => %{
          "name" => "small_loop_test",
          "steps" => [
            %{
              "name" => "create_data",
              "type" => "set_variable",
              "variables" => %{
                "items" => small_data
              }
            },
            %{
              "name" => "process_items",
              "type" => "for_loop",
              "iterator" => "item",
              "data_source" => "previous_response:create_data.variables.items",
              "steps" => [
                %{
                  "name" => "process_item",
                  "type" => "set_variable",
                  "variable" => "processed",
                  "value" => "{{loop.item.id}}_done"
                }
              ]
            }
          ]
        }
      }

      # Disable monitoring for this test
      result = Executor.execute(workflow, 
        output_dir: @test_output_dir,
        enable_monitoring: false)

      assert {:ok, results} = result
      assert results["process_items"]["success"] == true
      assert results["process_items"]["total_items"] == 3
    end
  end

  # Helper functions
  defp safe_stop_monitoring(pipeline_name) do
    try do
      Performance.stop_monitoring(pipeline_name)
    rescue
      _ -> :ok
    catch
      _ -> :ok
    end
  end

  defp cleanup_all_monitoring do
    try do
      Registry.select(Pipeline.MonitoringRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$2"]}])
      |> Enum.each(fn pid ->
        if Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)
    rescue
      _ -> :ok
    end
  end
end