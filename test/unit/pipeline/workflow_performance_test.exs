defmodule Pipeline.WorkflowPerformanceTest do
  use ExUnit.Case, async: false

  alias Pipeline.{Config, Executor, TestMode}
  alias Pipeline.Test.Mocks

  # Performance test configuration  
  @moduletag :performance
  # 2 minutes timeout for performance tests
  @moduletag timeout: 120_000
  @moduletag capture_log: true

  setup do
    # Set test mode - performance tests use mocks for consistent measurement
    System.put_env("TEST_MODE", "mock")
    # Performance tests are unit tests
    TestMode.set_test_context(:unit)

    # Reset mocks
    Mocks.ClaudeProvider.reset()
    Mocks.GeminiProvider.reset()

    # Clean up any test directories
    on_exit(fn ->
      File.rm_rf("/tmp/perf_workspace")
      File.rm_rf("/tmp/perf_outputs")
      File.rm_rf("/tmp/perf_files")
      TestMode.clear_test_context()
    end)

    # Create performance test files
    File.mkdir_p!("/tmp/perf_files")

    :ok
  end

  describe "performance benchmarks" do
    @tag :performance
    test "measures execution time for simple workflow" do
      # 5 steps
      workflow = create_simple_workflow(5)

      # Setup mocks for fast responses
      setup_fast_mocks()

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      # Assert performance expectations
      # Should complete under 1 second
      assert execution_time_ms < 1000
      assert map_size(results) == 5

      IO.puts("Simple 5-step workflow execution time: #{execution_time_ms}ms")
    end

    @tag :performance
    test "measures execution time for complex workflow with dependencies" do
      # 10 interconnected steps
      workflow = create_complex_dependency_workflow(10)

      setup_fast_mocks()

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      # Complex workflows should still be reasonably fast
      # Should complete under 3 seconds
      assert execution_time_ms < 3000
      assert map_size(results) == 10

      IO.puts("Complex 10-step workflow execution time: #{execution_time_ms}ms")
    end

    @tag :performance
    test "measures memory usage for large workflow" do
      # 20 steps
      workflow = create_large_workflow(20)

      setup_fast_mocks()

      # Measure memory before
      :erlang.garbage_collect()
      {:memory, memory_before} = :erlang.process_info(self(), :memory)

      {:ok, results} = Executor.execute(workflow)

      # Measure memory after
      :erlang.garbage_collect()
      {:memory, memory_after} = :erlang.process_info(self(), :memory)

      memory_used_kb = (memory_after - memory_before) / 1024

      assert map_size(results) == 20
      # Should use less than 1MB
      assert memory_used_kb < 1024

      IO.puts("Large 20-step workflow memory usage: #{memory_used_kb}KB")
    end

    @tag :performance
    test "stress test with many file operations" do
      # Create multiple test files
      file_count = 50
      test_files = create_test_files(file_count)

      workflow = create_file_heavy_workflow(test_files)

      setup_fast_mocks()

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      # File operations should still be fast with mocks
      # Should complete under 5 seconds
      assert execution_time_ms < 5000
      assert map_size(results) == file_count

      IO.puts("File-heavy workflow (#{file_count} files) execution time: #{execution_time_ms}ms")

      # Cleanup test files
      Enum.each(test_files, &File.rm!/1)
    end

    @tag :performance
    test "measures prompt building performance with large content" do
      # Create large test file
      large_content = String.duplicate("This is a line of content with some data.\n", 10_000)
      large_file = "/tmp/perf_files/large_content.txt"
      File.write!(large_file, large_content)

      workflow = %{
        "workflow" => %{
          "name" => "large_content_test",
          "workspace_dir" => "/tmp/perf_workspace",
          "defaults" => %{"output_dir" => "/tmp/perf_outputs"},
          "steps" => [
            %{
              "name" => "process_large_file",
              "type" => "claude",
              "prompt" => [
                %{"type" => "static", "content" => "Process this large file:"},
                %{"type" => "file", "path" => large_file}
              ]
            }
          ]
        }
      }

      setup_fast_mocks()

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      # Large file processing should complete reasonably quickly
      # Should complete under 2 seconds
      assert execution_time_ms < 2000
      assert results["process_large_file"]["success"] == true

      IO.puts("Large file processing execution time: #{execution_time_ms}ms")
    end

    @tag :performance
    test "concurrent workflow execution simulation" do
      # Create multiple small workflows to simulate concurrent execution
      workflows =
        Enum.map(1..5, fn i ->
          create_simple_workflow(3, "concurrent_workflow_#{i}")
        end)

      setup_fast_mocks()

      # Execute workflows concurrently using tasks
      {time_microseconds, results} =
        :timer.tc(fn ->
          workflows
          |> Enum.map(fn workflow ->
            Task.async(fn -> Executor.execute(workflow) end)
          end)
          |> Enum.map(&Task.await(&1, 10_000))
        end)

      execution_time_ms = time_microseconds / 1000

      # All workflows should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # Concurrent execution should not take much longer than sequential
      # Should complete under 3 seconds
      assert execution_time_ms < 3000

      IO.puts("5 concurrent workflows execution time: #{execution_time_ms}ms")
    end

    @tag :performance
    test "measures configuration loading and validation performance" do
      # Create a complex configuration as YAML string
      config_file = "/tmp/perf_files/complex_config.yaml"
      yaml_content = create_complex_yaml_content()
      File.write!(config_file, yaml_content)

      # Measure configuration loading time
      {load_time_microseconds, {:ok, loaded_config}} =
        :timer.tc(fn ->
          Config.load_workflow(config_file)
        end)

      # Measure validation time
      {validation_time_microseconds, :ok} =
        :timer.tc(fn ->
          Config.validate_workflow(loaded_config)
        end)

      load_time_ms = load_time_microseconds / 1000
      validation_time_ms = validation_time_microseconds / 1000

      # Configuration operations should be fast
      # Should load under 100ms
      assert load_time_ms < 100
      # Should validate under 50ms
      assert validation_time_ms < 50

      IO.puts("Complex config loading time: #{load_time_ms}ms")
      IO.puts("Complex config validation time: #{validation_time_ms}ms")
    end

    @tag :performance
    test "memory leak detection over multiple executions" do
      workflow = create_simple_workflow(5)
      setup_fast_mocks()

      # Get initial memory
      :erlang.garbage_collect()
      {:memory, initial_memory} = :erlang.process_info(self(), :memory)

      # Execute workflow multiple times
      Enum.each(1..10, fn _i ->
        {:ok, _results} = Executor.execute(workflow)
      end)

      # Check final memory
      :erlang.garbage_collect()
      {:memory, final_memory} = :erlang.process_info(self(), :memory)

      memory_growth_kb = (final_memory - initial_memory) / 1024

      # Memory should not grow significantly
      # Should not grow more than 500KB
      assert memory_growth_kb < 500

      IO.puts("Memory growth after 10 executions: #{memory_growth_kb}KB")
    end

    @tag :performance
    test "checkpoint system performance" do
      workflow = %{
        "workflow" => %{
          "name" => "checkpoint_performance_test",
          "workspace_dir" => "/tmp/perf_workspace",
          "checkpoint_enabled" => true,
          "checkpoint_dir" => "/tmp/perf_workspace/.checkpoints",
          "defaults" => %{"output_dir" => "/tmp/perf_outputs"},
          "steps" =>
            Enum.map(1..15, fn i ->
              %{
                "name" => "step_#{i}",
                "type" => "claude",
                "prompt" => [%{"type" => "static", "content" => "Step #{i} content"}]
              }
            end)
        }
      }

      setup_fast_mocks()

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      # Checkpoint-enabled workflow should not be significantly slower
      # Should complete under 4 seconds
      assert execution_time_ms < 4000
      assert map_size(results) == 15

      # Verify checkpoints were created
      assert File.exists?("/tmp/perf_workspace/.checkpoints")

      IO.puts("Checkpoint-enabled workflow (15 steps) execution time: #{execution_time_ms}ms")
    end
  end

  describe "stress tests" do
    @tag :stress
    test "handles very large workflow (50 steps)" do
      workflow = create_large_workflow(50)
      setup_fast_mocks()

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      assert map_size(results) == 50
      # Should complete under 10 seconds
      assert execution_time_ms < 10_000

      IO.puts("Very large workflow (50 steps) execution time: #{execution_time_ms}ms")
    end

    @tag :stress
    test "handles workflow with deep dependency chains" do
      # 20 sequential steps
      workflow = create_deep_dependency_workflow(20)
      setup_fast_mocks()

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      assert map_size(results) == 20
      # Should complete under 5 seconds
      assert execution_time_ms < 5000

      IO.puts(
        "Deep dependency workflow (20 sequential steps) execution time: #{execution_time_ms}ms"
      )
    end

    @tag :stress
    test "handles many function calls in single step" do
      workflow = %{
        "workflow" => %{
          "name" => "many_functions_test",
          "workspace_dir" => "/tmp/perf_workspace",
          "defaults" => %{"output_dir" => "/tmp/perf_outputs"},
          "gemini_functions" => create_many_function_definitions(20),
          "steps" => [
            %{
              "name" => "step_with_many_functions",
              "type" => "gemini",
              "functions" => Enum.map(1..20, fn i -> "function_#{i}" end),
              "prompt" => [%{"type" => "static", "content" => "Use all available functions"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      {time_microseconds, {:ok, results}} =
        :timer.tc(fn ->
          Executor.execute(workflow)
        end)

      execution_time_ms = time_microseconds / 1000

      assert results["step_with_many_functions"]["success"] == true
      # Should complete under 3 seconds
      assert execution_time_ms < 3000

      IO.puts("Many functions workflow (20 functions) execution time: #{execution_time_ms}ms")
    end
  end

  # Helper functions for creating test workflows

  defp create_simple_workflow(step_count, name \\ "simple_perf_test") do
    steps =
      Enum.map(1..step_count, fn i ->
        %{
          "name" => "step_#{i}",
          "type" => if(rem(i, 2) == 0, do: "claude", else: "gemini"),
          "prompt" => [%{"type" => "static", "content" => "Step #{i} content"}]
        }
      end)

    %{
      "workflow" => %{
        "name" => name,
        "workspace_dir" => "/tmp/perf_workspace",
        "defaults" => %{"output_dir" => "/tmp/perf_outputs"},
        "steps" => steps
      }
    }
  end

  defp create_complex_dependency_workflow(step_count) do
    steps =
      Enum.map(1..step_count, fn i ->
        prompt_parts = [%{"type" => "static", "content" => "Step #{i} content"}]

        # Add previous response dependencies for steps after the first few
        prompt_parts =
          if i > 3 do
            dependency_step = "step_#{i - 2}"

            prompt_parts ++
              [
                %{"type" => "static", "content" => " with dependency on:"},
                %{"type" => "previous_response", "step" => dependency_step}
              ]
          else
            prompt_parts
          end

        %{
          "name" => "step_#{i}",
          "type" => if(rem(i, 2) == 0, do: "claude", else: "gemini"),
          "prompt" => prompt_parts
        }
      end)

    %{
      "workflow" => %{
        "name" => "complex_dependency_perf_test",
        "workspace_dir" => "/tmp/perf_workspace",
        "defaults" => %{"output_dir" => "/tmp/perf_outputs"},
        "steps" => steps
      }
    }
  end

  defp create_large_workflow(step_count) do
    create_simple_workflow(step_count, "large_perf_test")
  end

  defp create_deep_dependency_workflow(step_count) do
    steps =
      Enum.map(1..step_count, fn i ->
        prompt_parts = [%{"type" => "static", "content" => "Sequential step #{i}"}]

        # Each step depends on the previous one (except the first)
        prompt_parts =
          if i > 1 do
            dependency_step = "sequential_step_#{i - 1}"

            prompt_parts ++
              [
                %{"type" => "static", "content" => " building on:"},
                %{"type" => "previous_response", "step" => dependency_step}
              ]
          else
            prompt_parts
          end

        %{
          "name" => "sequential_step_#{i}",
          "type" => if(rem(i, 2) == 0, do: "claude", else: "gemini"),
          "prompt" => prompt_parts
        }
      end)

    %{
      "workflow" => %{
        "name" => "deep_dependency_perf_test",
        "workspace_dir" => "/tmp/perf_workspace",
        "defaults" => %{"output_dir" => "/tmp/perf_outputs"},
        "steps" => steps
      }
    }
  end

  defp create_file_heavy_workflow(file_paths) do
    steps =
      Enum.with_index(file_paths, 1)
      |> Enum.map(fn {file_path, i} ->
        %{
          "name" => "file_step_#{i}",
          "type" => if(rem(i, 2) == 0, do: "claude", else: "gemini"),
          "prompt" => [
            %{"type" => "static", "content" => "Process file #{i}:"},
            %{"type" => "file", "path" => file_path}
          ]
        }
      end)

    %{
      "workflow" => %{
        "name" => "file_heavy_perf_test",
        "workspace_dir" => "/tmp/perf_workspace",
        "defaults" => %{"output_dir" => "/tmp/perf_outputs"},
        "steps" => steps
      }
    }
  end

  defp create_test_files(count) do
    Enum.map(1..count, fn i ->
      file_path = "/tmp/perf_files/test_file_#{i}.txt"
      File.write!(file_path, "Test content for file #{i}\nLine 2\nLine 3")
      file_path
    end)
  end

  defp create_complex_yaml_content do
    """
    workflow:
      name: complex_performance_config
      workspace_dir: /tmp/perf_workspace
      checkpoint_enabled: true
      defaults:
        gemini_model: gemini-2.5-flash
        output_dir: /tmp/perf_outputs
      gemini_functions:
        function_1:
          description: Function 1 for testing
          parameters:
            type: object
            properties:
              result:
                type: string
        function_2:
          description: Function 2 for testing
          parameters:
            type: object
            properties:
              result:
                type: string
        function_3:
          description: Function 3 for testing
          parameters:
            type: object
            properties:
              result:
                type: string
        function_4:
          description: Function 4 for testing
          parameters:
            type: object
            properties:
              result:
                type: string
        function_5:
          description: Function 5 for testing
          parameters:
            type: object
            properties:
              result:
                type: string
      steps:
        - name: complex_step_1
          type: gemini
          prompt:
            - type: static
              content: Complex step 1
        - name: complex_step_2
          type: claude
          prompt:
            - type: static
              content: Complex step 2
        - name: complex_step_3
          type: gemini
          prompt:
            - type: static
              content: Complex step 3
        - name: complex_step_4
          type: claude
          prompt:
            - type: static
              content: Complex step 4
        - name: complex_step_5
          type: gemini
          prompt:
            - type: static
              content: Complex step 5
        - name: complex_step_6
          type: claude
          prompt:
            - type: static
              content: Complex step 6
        - name: complex_step_7
          type: gemini
          prompt:
            - type: static
              content: Complex step 7
        - name: complex_step_8
          type: claude
          prompt:
            - type: static
              content: Complex step 8
        - name: complex_step_9
          type: gemini
          prompt:
            - type: static
              content: Complex step 9
        - name: complex_step_10
          type: claude
          prompt:
            - type: static
              content: Complex step 10
    """
  end

  defp create_many_function_definitions(count) do
    Enum.reduce(1..count, %{}, fn i, acc ->
      Map.put(acc, "function_#{i}", %{
        "description" => "Function #{i} for testing",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "result" => %{"type" => "string"}
          }
        }
      })
    end)
  end

  defp setup_fast_mocks do
    # Configure mocks for fast responses
    # Mock responses are handled automatically by pattern matching
  end
end
