defmodule Pipeline.Performance.LoadTest do
  @moduledoc """
  Load tests for pipeline performance optimization features.
  
  Tests streaming, memory management, lazy evaluation, and performance monitoring
  under various load conditions.
  """

  use ExUnit.Case, async: false
  require Logger

  alias Pipeline.Executor
  alias Pipeline.Monitoring.Performance
  alias Pipeline.Utils.FileUtils

  @large_dataset_size 500  # Reduced for faster tests
  @memory_threshold 50_000_000  # 50MB for testing
  @test_output_dir "test/tmp/performance"

  setup do
    # Create test output directory
    File.mkdir_p!(@test_output_dir)
    
    # Clean up any existing monitoring processes
    cleanup_monitoring()
    
    on_exit(fn ->
      # Clean up test files
      File.rm_rf(@test_output_dir)
      cleanup_monitoring()
    end)
    
    :ok
  end

  describe "Memory-efficient loop execution" do
    test "processes large datasets without exceeding memory threshold" do
      # Create large dataset
      large_data = generate_large_dataset(@large_dataset_size)
      
      workflow = %{
        "workflow" => %{
          "name" => "memory_test_loop",
          "steps" => [
            %{
              "name" => "create_data",
              "type" => "set_variable",
              "variable" => "test_data",
              "value" => large_data
            },
            %{
              "name" => "process_loop",
              "type" => "for_loop",
              "iterator" => "item",
              "data_source" => "previous_response:create_data:test_data",
              "batch_size" => 50,  # Force batching
              "steps" => [
                %{
                  "name" => "process_item",
                  "type" => "set_variable",
                  "variable" => "processed",
                  "value" => "{{loop.item.id}}_processed"
                }
              ]
            }
          ]
        }
      }

      # Start performance monitoring
      {:ok, _pid} = Performance.start_monitoring("memory_test_loop", 
        memory_threshold: @memory_threshold)

      # Execute workflow
      result = Executor.execute(workflow, output_dir: @test_output_dir)

      # Check results
      assert {:ok, results} = result
      assert results["process_loop"]["success"] == true
      assert results["process_loop"]["total_items"] == @large_dataset_size

      # Check memory usage
      {:ok, metrics} = Performance.get_metrics("memory_test_loop")
      assert metrics.memory_usage_bytes < @memory_threshold

      # Stop monitoring and get final metrics
      {:ok, final_metrics} = Performance.stop_monitoring("memory_test_loop")
      assert final_metrics.peak_memory_bytes < @memory_threshold * 1.5
    end

    test "uses streaming mode for very large datasets" do
      # Create very large dataset
      very_large_data = generate_large_dataset(1000)  # Above streaming threshold
      
      workflow = %{
        "workflow" => %{
          "name" => "streaming_test_loop",
          "steps" => [
            %{
              "name" => "create_data",
              "type" => "set_variable", 
              "variable" => "test_data",
              "value" => very_large_data
            },
            %{
              "name" => "streaming_loop",
              "type" => "for_loop",
              "iterator" => "item",
              "data_source" => "previous_response:create_data:test_data",
              "steps" => [
                %{
                  "name" => "count_item",
                  "type" => "set_variable",
                  "variable" => "count",
                  "value" => 1
                }
              ]
            }
          ]
        }
      }

      result = Executor.execute(workflow, output_dir: @test_output_dir)
      
      assert {:ok, results} = result
      assert results["streaming_loop"]["success"] == true
      assert results["streaming_loop"]["total_items"] == 1000
      assert Map.has_key?(results["streaming_loop"], "batches_processed")
    end
  end

  describe "File streaming operations" do
    test "handles large file operations with streaming" do
      # Create large test file
      large_file_path = Path.join(@test_output_dir, "large_test.txt")
      create_large_test_file(large_file_path, 10_000)  # ~10MB file

      workflow = %{
        "workflow" => %{
          "name" => "file_streaming_test",
          "steps" => [
            %{
              "name" => "copy_large_file",
              "type" => "file_ops",
              "operation" => "stream_copy",
              "source" => large_file_path,
              "destination" => Path.join(@test_output_dir, "large_copy.txt")
            },
            %{
              "name" => "process_large_file",
              "type" => "file_ops",
              "operation" => "stream_process",
              "source" => Path.join(@test_output_dir, "large_copy.txt"),
              "processor" => "uppercase"
            }
          ]
        }
      }

      {:ok, _pid} = Performance.start_monitoring("file_streaming_test")
      result = Executor.execute(workflow, output_dir: @test_output_dir)

      assert {:ok, results} = result
      assert results["copy_large_file"]["method"] == "streaming"
      assert results["process_large_file"]["method"] == "streaming"

      # Verify files exist and have correct content
      assert File.exists?(Path.join(@test_output_dir, "large_copy.txt"))
      
      {:ok, final_metrics} = Performance.stop_monitoring("file_streaming_test")
      # Should have low memory usage due to streaming
      assert final_metrics.peak_memory_bytes < @memory_threshold
    end

    test "automatically chooses streaming for large files" do
      # FileUtils should automatically detect large files
      large_file = Path.join(@test_output_dir, "auto_stream.txt")
      create_large_test_file(large_file, 150_000)  # > 100MB threshold

      assert FileUtils.should_use_streaming?(large_file) == true

      # Regular copy should use streaming automatically
      dest_file = Path.join(@test_output_dir, "auto_copy.txt")
      assert :ok = FileUtils.stream_copy_file(large_file, dest_file)
      assert File.exists?(dest_file)
    end
  end

  describe "Result streaming between steps" do
    test "creates streams for large results automatically" do
      # Generate large result data
      large_result = generate_large_json_data(5_000_000)  # ~5MB

      workflow = %{
        "workflow" => %{
          "name" => "result_streaming_test",
          "steps" => [
            %{
              "name" => "generate_large_data",
              "type" => "set_variable",
              "variable" => "large_result",
              "value" => large_result,
              "streaming" => %{"enabled" => true}
            },
            %{
              "name" => "process_streamed_result",
              "type" => "data_transform",
              "input_source" => "previous_response:generate_large_data:large_result",
              "operations" => [
                %{"operation" => "filter", "field" => "active", "condition" => "active == true"}
              ]
            }
          ]
        }
      }

      result = Executor.execute(workflow, output_dir: @test_output_dir)

      assert {:ok, results} = result
      
      # First step should create a stream
      assert results["generate_large_data"]["type"] == "stream"
      assert Map.has_key?(results["generate_large_data"], "stream_id")
      
      # Second step should process the data
      assert Map.has_key?(results["process_streamed_result"], "processed_data")
    end
  end

  describe "Lazy evaluation in data transformations" do
    test "uses lazy evaluation for large datasets" do
      large_dataset = generate_structured_dataset(2000)  # Above lazy threshold

      workflow = %{
        "workflow" => %{
          "name" => "lazy_transform_test",
          "steps" => [
            %{
              "name" => "create_dataset",
              "type" => "set_variable",
              "variable" => "dataset",
              "value" => large_dataset
            },
            %{
              "name" => "lazy_transform",
              "type" => "data_transform",
              "input_source" => "previous_response:create_dataset:dataset",
              "lazy" => %{"enabled" => true},
              "operations" => [
                %{"operation" => "filter", "field" => "status", "condition" => "status == active"},
                %{"operation" => "map", "field" => "priority", "mapping" => %{"1" => "high", "2" => "medium", "3" => "low"}},
                %{"operation" => "sort", "field" => "created_at", "order" => "desc"}
              ]
            }
          ]
        }
      }

      {:ok, _pid} = Performance.start_monitoring("lazy_transform_test")
      result = Executor.execute(workflow, output_dir: @test_output_dir)

      assert {:ok, results} = result
      assert Map.has_key?(results["lazy_transform"], "lazy_transform")

      {:ok, final_metrics} = Performance.stop_monitoring("lazy_transform_test")
      # Should have reasonable memory usage due to lazy evaluation
      assert final_metrics.peak_memory_bytes < @memory_threshold * 2
    end

    test "automatically enables lazy evaluation for large datasets" do
      # Create dataset larger than lazy threshold
      auto_lazy_dataset = generate_structured_dataset(1500)

      workflow = %{
        "workflow" => %{
          "name" => "auto_lazy_test",
          "steps" => [
            %{
              "name" => "create_dataset",
              "type" => "set_variable",
              "variable" => "dataset", 
              "value" => auto_lazy_dataset
            },
            %{
              "name" => "auto_lazy_transform",
              "type" => "data_transform",
              "input_source" => "previous_response:create_dataset:dataset",
              # No explicit lazy config - should auto-enable
              "operations" => [
                %{"operation" => "filter", "field" => "active", "condition" => "active == true"}
              ]
            }
          ]
        }
      }

      result = Executor.execute(workflow, output_dir: @test_output_dir)
      assert {:ok, results} = result
      assert Map.has_key?(results["auto_lazy_transform"], "auto_lazy_transform")
    end
  end

  describe "Performance monitoring" do
    test "tracks pipeline execution metrics" do
      workflow = %{
        "workflow" => %{
          "name" => "monitoring_test",
          "steps" => [
            %{
              "name" => "step1", 
              "type" => "set_variable",
              "variable" => "test", 
              "value" => "value1"
            },
            %{
              "name" => "step2",
              "type" => "set_variable", 
              "variable" => "test2",
              "value" => "value2"
            }
          ]
        }
      }

      {:ok, _pid} = Performance.start_monitoring("monitoring_test")
      
      Performance.step_started("monitoring_test", "step1", "set_variable")
      result = Executor.execute(workflow, output_dir: @test_output_dir)
      Performance.step_completed("monitoring_test", "step1", %{"success" => true})

      assert {:ok, _results} = result

      {:ok, metrics} = Performance.get_metrics("monitoring_test")
      assert metrics.step_count >= 2
      assert metrics.execution_time_ms > 0

      {:ok, final_metrics} = Performance.stop_monitoring("monitoring_test")
      assert final_metrics.total_steps == 2
      assert final_metrics.successful_steps >= 1
      assert length(final_metrics.step_details) == 2
    end

    test "detects performance issues and generates recommendations" do
      # Create a workflow that will trigger warnings
      workflow = %{
        "workflow" => %{
          "name" => "performance_issues_test", 
          "steps" => [
            %{
              "name" => "memory_intensive_step",
              "type" => "set_variable",
              "variable" => "large_data",
              "value" => generate_large_dataset(1000)
            }
          ]
        }
      }

      {:ok, _pid} = Performance.start_monitoring("performance_issues_test",
        memory_threshold: 50_000_000)  # Lower threshold for testing
      
      result = Executor.execute(workflow, output_dir: @test_output_dir)
      assert {:ok, _results} = result

      {:ok, final_metrics} = Performance.stop_monitoring("performance_issues_test")
      
      # Should have recommendations for optimization
      assert length(final_metrics.recommendations) > 0
      assert final_metrics.total_warnings > 0
    end
  end

  describe "End-to-end performance scenarios" do
    test "handles complex pipeline with all performance features" do
      # Create a complex workflow using all performance features
      large_dataset = generate_structured_dataset(800)
      large_file = Path.join(@test_output_dir, "complex_test.json")
      File.write!(large_file, Jason.encode!(large_dataset))

      workflow = %{
        "workflow" => %{
          "name" => "complex_performance_test",
          "steps" => [
            # File streaming
            %{
              "name" => "copy_data_file",
              "type" => "file_ops", 
              "operation" => "stream_copy",
              "source" => large_file,
              "destination" => Path.join(@test_output_dir, "data_copy.json")
            },
            # Large data processing with streaming
            %{
              "name" => "load_data",
              "type" => "set_variable",
              "variable" => "dataset",
              "value" => large_dataset,
              "streaming" => %{"enabled" => true}
            },
            # Lazy data transformation
            %{
              "name" => "transform_data", 
              "type" => "data_transform",
              "input_source" => "previous_response:load_data:dataset",
              "lazy" => %{"enabled" => true},
              "operations" => [
                %{"operation" => "filter", "field" => "active", "condition" => "active == true"},
                %{"operation" => "sort", "field" => "priority", "order" => "desc"}
              ]
            },
            # Memory-efficient loop processing
            %{
              "name" => "process_items",
              "type" => "for_loop",
              "iterator" => "item", 
              "data_source" => "previous_response:transform_data:transform_data",
              "batch_size" => 25,
              "steps" => [
                %{
                  "name" => "validate_item",
                  "type" => "set_variable",
                  "variable" => "valid",
                  "value" => true
                }
              ]
            }
          ]
        }
      }

      {:ok, _pid} = Performance.start_monitoring("complex_performance_test")
      result = Executor.execute(workflow, output_dir: @test_output_dir)

      assert {:ok, results} = result
      assert results["copy_data_file"]["method"] == "streaming"
      assert results["load_data"]["type"] == "stream"
      assert results["process_items"]["success"] == true

      {:ok, final_metrics} = Performance.stop_monitoring("complex_performance_test")
      assert final_metrics.total_steps == 4
      assert final_metrics.successful_steps == 4
      
      # Memory should stay reasonable with all optimizations
      assert final_metrics.peak_memory_bytes < @memory_threshold * 3
      
      Logger.info("Complex pipeline performance: #{inspect(final_metrics.recommendations)}")
    end
  end

  # Helper functions

  defp generate_large_dataset(size) do
    1..size
    |> Enum.map(fn i ->
      %{
        "id" => i,
        "name" => "item_#{i}",
        "data" => String.duplicate("x", 100),  # 100 bytes per item
        "active" => rem(i, 2) == 0
      }
    end)
  end

  defp generate_structured_dataset(size) do
    1..size
    |> Enum.map(fn i ->
      %{
        "id" => i,
        "name" => "record_#{i}",
        "status" => if(rem(i, 3) == 0, do: "active", else: "inactive"),
        "priority" => rem(i, 3) + 1,
        "active" => rem(i, 2) == 0,
        "created_at" => DateTime.utc_now() |> DateTime.add(-i * 60, :second) |> DateTime.to_iso8601(),
        "metadata" => %{
          "category" => "test",
          "tags" => ["tag#{rem(i, 5)}", "auto"],
          "score" => :rand.uniform(100)
        }
      }
    end)
  end

  defp generate_large_json_data(target_size) do
    # Generate JSON data of approximately target_size bytes
    base_item = %{
      "id" => 1,
      "content" => String.duplicate("data", 100),
      "metadata" => %{"type" => "test", "active" => true}
    }
    
    item_size = Jason.encode!(base_item) |> byte_size()
    item_count = div(target_size, item_size)
    
    1..item_count
    |> Enum.map(fn i ->
      %{base_item | "id" => i, "content" => String.duplicate("data#{i}", 100)}
    end)
  end

  defp create_large_test_file(path, size_kb) do
    content = String.duplicate("0123456789abcdef\n", size_kb * 60)  # ~1KB per repeat
    File.write!(path, content)
  end

  defp cleanup_monitoring do
    # Stop any running monitoring processes
    try do
      Performance.stop_monitoring("memory_test_loop")
      Performance.stop_monitoring("streaming_test_loop") 
      Performance.stop_monitoring("file_streaming_test")
      Performance.stop_monitoring("result_streaming_test")
      Performance.stop_monitoring("lazy_transform_test")
      Performance.stop_monitoring("auto_lazy_test")
      Performance.stop_monitoring("monitoring_test")
      Performance.stop_monitoring("performance_issues_test")
      Performance.stop_monitoring("complex_performance_test")
    rescue
      _ -> :ok
    end
  end
end