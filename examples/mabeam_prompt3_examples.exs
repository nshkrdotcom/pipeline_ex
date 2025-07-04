# MABEAM Prompt 3 Usage Examples
# Demonstrates monitoring sensors and workflow integration features

# Start IEx and run: 
# iex -S mix
# Code.eval_file("examples/mabeam_prompt3_examples.exs")

defmodule MABEAMPrompt3Examples do
  @moduledoc """
  Examples demonstrating MABEAM Prompt 3 features:
  - Monitoring Sensors (Queue and Performance)
  - Enhanced Workflow Actions for async execution
  - Advanced pipeline orchestration
  """

  require Logger

  def run_all_examples do
    IO.puts("\n🤖 MABEAM Prompt 3 - Monitoring & Workflow Examples")
    IO.puts("=" <> String.duplicate("=", 50))

    # Enable MABEAM
    Application.put_env(:pipeline, :mabeam_enabled, true)

    try do
      example_1_basic_sensor_monitoring()
      example_2_async_pipeline_execution()
      example_3_batch_pipeline_execution()
      example_4_performance_monitoring()
      example_5_advanced_workflow_features()
    rescue
      error ->
        IO.puts("❌ Example failed: #{inspect(error)}")
    end

    IO.puts("\n✅ All examples completed!")
  end

  def example_1_basic_sensor_monitoring do
    IO.puts("\n📊 Example 1: Basic Sensor Monitoring")
    IO.puts("-" <> String.duplicate("-", 40))

    # Start sensors manually for demonstration
    {:ok, queue_sensor} = Pipeline.MABEAM.Sensors.QueueMonitor.start_link(
      id: "demo_queue_monitor",
      target: {:pid, target: self()},
      check_interval: 2000,
      alert_threshold: 3
    )

    {:ok, perf_sensor} = Pipeline.MABEAM.Sensors.PerformanceMonitor.start_link(
      id: "demo_performance_monitor", 
      target: {:pid, target: self()},
      emit_interval: 3000
    )

    IO.puts("✅ Started queue and performance sensors")
    IO.puts("📡 Listening for signals...")

    # Listen for a few signals
    for _i <- 1..3 do
      receive do
        {:signal, {:ok, signal}} ->
          IO.puts("📡 Received signal: #{signal.type}")
          IO.puts("   Data: #{inspect(signal.data, limit: :infinity)}")
      after
        5000 ->
          IO.puts("⏰ Timeout waiting for signal")
      end
    end

    # Cleanup
    GenServer.stop(queue_sensor)
    GenServer.stop(perf_sensor)
    IO.puts("✅ Sensor monitoring example completed")
  end

  def example_2_async_pipeline_execution do
    IO.puts("\n🚀 Example 2: Async Pipeline Execution")
    IO.puts("-" <> String.duplicate("-", 40))

    # Start async execution
    IO.puts("🔄 Starting async pipeline execution...")
    
    {:ok, async_result} = Jido.Exec.run(
      Pipeline.MABEAM.Actions.ExecutePipelineAsync,
      %{
        pipeline_file: "examples/simple_test.yaml",
        timeout: 30_000,
        max_retries: 2,
        telemetry_level: :full
      },
      %{user_id: "demo_user"}
    )

    IO.puts("✅ Started async execution: #{inspect(async_result.async_ref)}")
    IO.puts("📅 Started at: #{async_result.started_at}")

    # Check status
    IO.puts("\n📊 Checking pipeline status...")
    {:ok, status_result} = Jido.Exec.run(
      Pipeline.MABEAM.Actions.GetPipelineStatus,
      %{async_ref: async_result.async_ref}
    )

    IO.puts("📊 Status: #{inspect(status_result.status)}")

    # Await completion
    IO.puts("\n⏳ Awaiting pipeline completion...")
    case Jido.Exec.run(
      Pipeline.MABEAM.Actions.AwaitPipelineResult,
      %{async_ref: async_result.async_ref, timeout: 45_000}
    ) do
      {:ok, final_result} ->
        IO.puts("✅ Pipeline completed successfully!")
        IO.puts("📅 Completed at: #{final_result.completed_at}")
        IO.puts("📊 Result: #{inspect(final_result.result, limit: :infinity)}")

      {:error, reason} ->
        IO.puts("❌ Pipeline failed: #{reason}")
    end

    IO.puts("✅ Async pipeline execution example completed")
  end

  def example_3_batch_pipeline_execution do
    IO.puts("\n📦 Example 3: Batch Pipeline Execution")
    IO.puts("-" <> String.duplicate("-", 40))

    # Start batch execution
    pipeline_files = [
      "examples/simple_test.yaml",
      "examples/simple_test.yaml",  # Same file for demo
      "examples/simple_test.yaml"
    ]

    IO.puts("🔄 Starting batch execution of #{length(pipeline_files)} pipelines...")

    {:ok, batch_result} = Jido.Exec.run(
      Pipeline.MABEAM.Actions.BatchExecutePipelines,
      %{
        pipeline_files: pipeline_files,
        timeout: 30_000,
        concurrent_limit: 2
      }
    )

    IO.puts("✅ Started batch execution: #{batch_result.batch_id}")
    IO.puts("📊 Total pipelines: #{batch_result.total_pipelines}")
    IO.puts("🔄 Concurrent executions: #{length(batch_result.pipeline_refs)}")

    # Await batch results
    IO.puts("\n⏳ Awaiting batch completion...")
    {:ok, batch_await_result} = Jido.Exec.run(
      Pipeline.MABEAM.Actions.AwaitBatchResults,
      %{
        pipeline_refs: batch_result.pipeline_refs,
        timeout: 60_000
      }
    )

    IO.puts("✅ Batch execution completed!")
    IO.puts("📊 Summary:")
    IO.puts("   Total: #{batch_await_result.summary.total}")
    IO.puts("   Successful: #{batch_await_result.summary.successful}")
    IO.puts("   Failed: #{batch_await_result.summary.failed}")
    IO.puts("   Success Rate: #{Float.round(batch_await_result.summary.success_rate * 100, 1)}%")

    # Show individual results
    IO.puts("\n📋 Individual Results:")
    Enum.with_index(batch_await_result.results, 1)
    |> Enum.each(fn {{pipeline_file, status, _result}, index} ->
      status_icon = if status == :success, do: "✅", else: "❌"
      IO.puts("   #{index}. #{status_icon} #{Path.basename(pipeline_file)} - #{status}")
    end)

    IO.puts("✅ Batch pipeline execution example completed")
  end

  def example_4_performance_monitoring do
    IO.puts("\n📈 Example 4: Performance Monitoring")
    IO.puts("-" <> String.duplicate("-", 40))

    # Start the MABEAM system with sensors
    {:ok, supervisor} = Pipeline.MABEAM.Supervisor.start_link()
    IO.puts("✅ Started MABEAM system with monitoring")

    # Run several pipelines to generate metrics
    IO.puts("🔄 Running pipelines to generate performance data...")

    tasks = for i <- 1..3 do
      Task.async(fn ->
        Jido.Exec.run(
          Pipeline.MABEAM.Actions.ExecutePipelineYaml,
          %{pipeline_file: "examples/simple_test.yaml"},
          %{execution_id: "perf_test_#{i}"}
        )
      end)
    end

    # Wait for pipelines to complete
    Enum.each(tasks, &Task.await(&1, 30_000))
    IO.puts("✅ Completed performance test pipelines")

    # Listen for performance signals
    IO.puts("\n📊 Collecting performance metrics...")

    # Start our own performance sensor to see the data
    {:ok, monitor} = Pipeline.MABEAM.Sensors.PerformanceMonitor.start_link(
      id: "demo_perf_monitor",
      target: {:pid, target: self()},
      emit_interval: 1000
    )

    # Collect a few performance samples
    for i <- 1..3 do
      receive do
        {:signal, {:ok, signal}} when signal.type == "pipeline.performance_metrics" ->
          IO.puts("\n📊 Performance Sample ##{i}:")
          IO.puts("   Average Execution Time: #{signal.data.avg_execution_time}ms")
          IO.puts("   Throughput/Hour: #{signal.data.throughput_per_hour}")
          IO.puts("   Error Rate: #{Float.round(signal.data.error_rate * 100, 2)}%")
          IO.puts("   Active Pipelines: #{signal.data.active_pipelines}")
          IO.puts("   CPU Usage: #{signal.data.cpu_usage}%")
          IO.puts("   Memory (Total): #{format_bytes(signal.data.memory_usage.total)}")
      after
        5000 ->
          IO.puts("⏰ Timeout waiting for performance signal")
      end
    end

    # Cleanup
    GenServer.stop(monitor)
    Supervisor.stop(supervisor)
    IO.puts("✅ Performance monitoring example completed")
  end

  def example_5_advanced_workflow_features do
    IO.puts("\n⚡ Example 5: Advanced Workflow Features")
    IO.puts("-" <> String.duplicate("-", 40))

    # Demonstrate cancellation
    IO.puts("🔄 Testing pipeline cancellation...")

    {:ok, async_result} = Jido.Exec.run(
      Pipeline.MABEAM.Actions.ExecutePipelineAsync,
      %{
        pipeline_file: "examples/simple_test.yaml",
        timeout: 60_000  # Long timeout
      }
    )

    # Immediately cancel
    {:ok, cancel_result} = Jido.Exec.run(
      Pipeline.MABEAM.Actions.CancelPipelineExecution,
      %{async_ref: async_result.async_ref}
    )

    IO.puts("✅ Pipeline cancelled: #{cancel_result.status}")
    IO.puts("📅 Cancelled at: #{cancel_result.cancelled_at}")

    # Demonstrate error handling and retries
    IO.puts("\n🔄 Testing error handling with retries...")

    case Jido.Exec.run(
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      %{pipeline_file: "nonexistent_file.yaml"},  # This will fail
      %{},
      max_retries: 2,
      timeout: 10_000
    ) do
      {:ok, _result} ->
        IO.puts("🤔 Unexpected success")
      {:error, reason} ->
        IO.puts("✅ Expected error handled: #{inspect(reason)}")
    end

    # Demonstrate telemetry levels
    IO.puts("\n📊 Testing different telemetry levels...")

    for telemetry_level <- [:full, :minimal, :silent] do
      IO.puts("   Testing telemetry level: #{telemetry_level}")
      
      {:ok, _result} = Jido.Exec.run(
        Pipeline.MABEAM.Actions.ExecutePipelineYaml,
        %{pipeline_file: "examples/simple_test.yaml"},
        %{},
        telemetry: telemetry_level,
        timeout: 15_000
      )
    end

    IO.puts("✅ Advanced workflow features example completed")
  end

  # Helper function to format bytes
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end

# Auto-run if called directly
if __ENV__.file == Path.absname(__FILE__) do
  MABEAMPrompt3Examples.run_all_examples()
end