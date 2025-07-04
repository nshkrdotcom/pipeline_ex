# MABEAM Usage Examples
# Demonstrating Pipeline Management Agent instruction processing

# Basic Agent Usage Example
defmodule MABEAMUsageExamples do
  @moduledoc """
  Examples demonstrating how to use MABEAM (Multi-Agent BEAM) pipeline system
  with Jido Agents for pipeline execution and management.
  """

  def example_basic_agent_usage do
    # Start the MABEAM system
    Application.put_env(:pipeline, :mabeam_enabled, true)
    {:ok, _} = Pipeline.Application.start(:normal, [])

    # Send instruction to pipeline manager
    {:ok, manager} = Pipeline.MABEAM.Agents.PipelineManager.start_link(id: "manager")

    instruction = %Jido.Instruction{
      action: "execute_pipeline_yaml",
      params: %{pipeline_file: "examples/simple_test.yaml"}
    }

    {:ok, result} = Pipeline.MABEAM.Agents.PipelineManager.cmd(manager, [instruction])
    IO.puts("Pipeline execution result: #{inspect(result)}")
  end

  def example_workflow_integration do
    # Execute through Jido Workflow system
    {:ok, result} = Jido.Workflow.run(
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      %{pipeline_file: "analysis.yaml"},
      %{user_id: "123"},
      timeout: 30_000,
      max_retries: 3
    )

    IO.puts("Workflow execution result: #{inspect(result)}")
  end

  def example_health_check do
    # Check system health using the health check action
    instruction = %Jido.Instruction{
      action: "health_check",
      params: %{}
    }

    {:ok, manager} = Pipeline.MABEAM.Agents.PipelineManager.start_link(id: "health_manager")
    {:ok, health_result} = Pipeline.MABEAM.Agents.PipelineManager.cmd(manager, [instruction])
    
    IO.puts("System health: #{inspect(health_result)}")
  end

  def example_worker_execution do
    # Start a pipeline worker and execute a pipeline
    {:ok, worker} = Pipeline.MABEAM.Agents.PipelineWorker.start_link(
      id: "example_worker", 
      worker_id: "worker_example_1"
    )

    instruction = %Jido.Instruction{
      action: "execute_pipeline_yaml",
      params: %{
        pipeline_file: "examples/simple_test.yaml",
        workspace_dir: "./workspace",
        output_dir: "./outputs",
        debug: false
      }
    }

    {:ok, result} = Pipeline.MABEAM.Agents.PipelineWorker.cmd(worker, [instruction])
    IO.puts("Worker execution result: #{inspect(result)}")
  end

  def example_pipeline_generation do
    # Generate a new pipeline using Genesis integration
    {:ok, manager} = Pipeline.MABEAM.Agents.PipelineManager.start_link(id: "generator")

    instruction = %Jido.Instruction{
      action: "generate_pipeline",
      params: %{
        description: "Create a data analysis pipeline that processes CSV files",
        output_file: "generated_analysis_pipeline.yaml"
      }
    }

    {:ok, result} = Pipeline.MABEAM.Agents.PipelineManager.cmd(manager, [instruction])
    IO.puts("Pipeline generation result: #{inspect(result)}")
  end

  def example_concurrent_workers do
    # Demonstrate multiple workers running concurrently
    worker_configs = [
      %{id: "worker_1", worker_id: "concurrent_worker_1"},
      %{id: "worker_2", worker_id: "concurrent_worker_2"},
      %{id: "worker_3", worker_id: "concurrent_worker_3"}
    ]

    # Start workers
    workers = Enum.map(worker_configs, fn config ->
      {:ok, worker} = Pipeline.MABEAM.Agents.PipelineWorker.start_link(config)
      worker
    end)

    # Create instructions for each worker
    instructions = [
      %Jido.Instruction{
        action: "execute_pipeline_yaml",
        params: %{pipeline_file: "examples/pipeline_1.yaml"}
      },
      %Jido.Instruction{
        action: "execute_pipeline_yaml", 
        params: %{pipeline_file: "examples/pipeline_2.yaml"}
      },
      %Jido.Instruction{
        action: "health_check",
        params: %{}
      }
    ]

    # Execute instructions concurrently
    tasks = Enum.zip(workers, instructions)
    |> Enum.map(fn {worker, instruction} ->
      Task.async(fn ->
        Pipeline.MABEAM.Agents.PipelineWorker.cmd(worker, [instruction])
      end)
    end)

    # Collect results
    results = Task.await_many(tasks, 30_000)
    IO.puts("Concurrent execution results: #{inspect(results)}")
  end

  def example_agent_state_management do
    # Demonstrate agent state tracking
    {:ok, manager} = Pipeline.MABEAM.Agents.PipelineManager.start_link(id: "state_manager")

    # Check initial state
    {:ok, initial_state} = Pipeline.MABEAM.Agents.PipelineManager.get_state(manager)
    IO.puts("Initial state: #{inspect(initial_state)}")

    # Execute a pipeline (this should update state)
    instruction = %Jido.Instruction{
      action: "execute_pipeline_yaml",
      params: %{pipeline_file: "examples/simple_test.yaml"}
    }

    {:ok, _result} = Pipeline.MABEAM.Agents.PipelineManager.cmd(manager, [instruction])

    # Check updated state
    {:ok, updated_state} = Pipeline.MABEAM.Agents.PipelineManager.get_state(manager)
    IO.puts("Updated state: #{inspect(updated_state)}")
  end

  def example_error_handling do
    # Demonstrate error handling in agent instruction processing
    {:ok, worker} = Pipeline.MABEAM.Agents.PipelineWorker.start_link(
      id: "error_worker",
      worker_id: "error_test_worker"
    )

    # Try to execute a non-existent pipeline
    instruction = %Jido.Instruction{
      action: "execute_pipeline_yaml",
      params: %{pipeline_file: "nonexistent_pipeline.yaml"}
    }

    case Pipeline.MABEAM.Agents.PipelineWorker.cmd(worker, [instruction]) do
      {:ok, result} ->
        IO.puts("Unexpected success: #{inspect(result)}")
      {:error, reason} ->
        IO.puts("Expected error handled gracefully: #{inspect(reason)}")
    end
  end

  def example_supervisor_integration do
    # Demonstrate OTP supervision integration
    IO.puts("MABEAM Supervisor children:")
    children = Supervisor.which_children(Pipeline.MABEAM.Supervisor)
    
    Enum.each(children, fn {id, pid, type, modules} ->
      IO.puts("  - #{id}: #{inspect(pid)} (#{type})")
    end)

    # Check that all children are alive
    all_alive = Enum.all?(children, fn {_id, pid, _type, _modules} ->
      Process.alive?(pid)
    end)

    IO.puts("All children alive: #{all_alive}")
  end

  def run_all_examples do
    IO.puts("=== MABEAM Usage Examples ===\n")

    IO.puts("1. Basic Agent Usage:")
    example_basic_agent_usage()

    IO.puts("\n2. Workflow Integration:")
    example_workflow_integration()

    IO.puts("\n3. Health Check:")
    example_health_check()

    IO.puts("\n4. Worker Execution:")
    example_worker_execution()

    IO.puts("\n5. Pipeline Generation:")
    example_pipeline_generation()

    IO.puts("\n6. Concurrent Workers:")
    example_concurrent_workers()

    IO.puts("\n7. State Management:")
    example_agent_state_management()

    IO.puts("\n8. Error Handling:")
    example_error_handling()

    IO.puts("\n9. Supervisor Integration:")
    example_supervisor_integration()

    IO.puts("\n=== Examples Complete ===")
  end
end

# Uncomment to run examples:
# MABEAMUsageExamples.run_all_examples()