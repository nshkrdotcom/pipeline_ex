defmodule Pipeline.MABEAM.Sensors.PerformanceMonitor do
  use Jido.Sensor,
    name: "performance_monitor",
    description: "Monitors pipeline execution performance metrics",
    category: :monitoring,
    tags: [:pipeline, :performance, :metrics],
    vsn: "1.0.0",
    schema: [
      metric_window: [
        type: :pos_integer,
        default: 60_000,
        doc: "Metrics collection window in milliseconds"
      ],
      emit_interval: [
        type: :pos_integer,
        default: 30_000,
        doc: "Signal emission interval in milliseconds"
      ]
    ]

  require Logger

  @impl true
  def mount(opts) do
    case :timer.send_interval(opts.emit_interval, self(), :emit_metrics) do
      {:ok, _timer_ref} -> :ok
      {:error, _reason} -> :ok  # Continue even if timer setup fails
    end

    {:ok,
     %{
       id: opts.id,
       target: opts.target,
       config: opts,
       metrics_buffer: [],
       sensor: %{name: "performance_monitor"}
     }}
  end

  @impl true
  def handle_info(:emit_metrics, state) do
    try do
      case deliver_signal(state) do
        {:ok, signal} ->
          case dispatch_signal(signal, state) do
            :ok -> :ok
            {:error, _reason} -> :ok  # Continue even if dispatch fails
          end
          {:noreply, %{state | metrics_buffer: []}}

        {:error, reason} ->
          Logger.error("Performance monitor signal creation failed: #{inspect(reason)}")
          {:noreply, state}
      end
    rescue
      error ->
        Logger.error("Performance monitor error: #{inspect(error)}")
        {:noreply, state}
    end
  end

  @impl true
  def deliver_signal(state) do
    metrics = collect_performance_metrics(state.config.metric_window)

    Jido.Signal.new(%{
      source: "performance_monitor:#{state.id}",
      type: "pipeline.performance_metrics",
      data: %{
        avg_execution_time: metrics.avg_execution_time,
        throughput_per_hour: metrics.throughput_per_hour,
        error_rate: metrics.error_rate,
        active_pipelines: metrics.active_pipelines,
        memory_usage: metrics.memory_usage,
        cpu_usage: metrics.cpu_usage,
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp collect_performance_metrics(_window) do
    # Collect system metrics
    memory_info = :erlang.memory()
    system_info = get_system_metrics()
    pipeline_metrics = get_pipeline_metrics()

    %{
      avg_execution_time: pipeline_metrics.avg_execution_time,
      throughput_per_hour: pipeline_metrics.throughput_per_hour,
      error_rate: pipeline_metrics.error_rate,
      active_pipelines: pipeline_metrics.active_pipelines,
      memory_usage: %{
        total: memory_info[:total],
        processes: memory_info[:processes],
        system: memory_info[:system],
        atom: memory_info[:atom],
        binary: memory_info[:binary],
        code: memory_info[:code],
        ets: memory_info[:ets]
      },
      cpu_usage: system_info.cpu_usage
    }
  end

  defp get_system_metrics() do
    # Get system-level metrics
    {reductions, _} = :erlang.statistics(:reductions)
    run_queue = :erlang.statistics(:run_queue)

    %{
      cpu_usage: calculate_cpu_usage(reductions),
      run_queue: run_queue,
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count)
    }
  end

  defp get_pipeline_metrics() do
    # Get pipeline-specific metrics from agents
    active_count = count_active_pipelines()
    execution_stats = get_execution_statistics()

    %{
      active_pipelines: active_count,
      avg_execution_time: execution_stats.avg_time,
      throughput_per_hour: execution_stats.throughput,
      error_rate: execution_stats.error_rate
    }
  end

  defp count_active_pipelines() do
    # Count active pipelines across all workers
    # Handle case where Registry might not exist
    try do
      workers =
        Registry.select(Pipeline.Registry, [
          {{:"$1", :"$2", :"$3"}, [{:==, :"$1", {:pipeline_worker, :_}}], [:"$2"]}
        ])

      Enum.count(workers, fn pid ->
        try do
          case Process.info(pid, :status) do
            {:status, status} when status in [:running, :runnable] -> true
            _ -> false
          end
        catch
          :exit, _ -> false
        end
      end)
    rescue
      # Registry doesn't exist
      ArgumentError -> 0
    catch
      :exit, _ -> 0
    end
  end

  defp get_execution_statistics() do
    # Get execution stats from pipeline managers
    try do
      case Registry.lookup(Pipeline.Registry, "pipeline_manager") do
        [{pid, _}] ->
          try do
            case Pipeline.MABEAM.Agents.PipelineManager.get_state(pid) do
              {:ok, state} ->
                calculate_stats_from_history(state.execution_history)

              _ ->
                default_stats()
            end
          catch
            :exit, _ -> default_stats()
          end

        [] ->
          default_stats()
      end
    rescue
      # Registry doesn't exist
      ArgumentError -> default_stats()
    catch
      :exit, _ -> default_stats()
    end
  end

  defp calculate_stats_from_history(history) when is_list(history) and length(history) > 0 do
    # Last 10 executions
    recent_history = Enum.take(history, -10)

    # Calculate average execution time
    times =
      Enum.map(recent_history, fn exec ->
        Map.get(exec, :duration, 0)
      end)

    avg_time = if length(times) > 0, do: Enum.sum(times) / length(times), else: 0.0

    # Calculate error rate
    errors =
      Enum.count(recent_history, fn exec ->
        Map.get(exec, :status) == :error
      end)

    error_rate = if length(recent_history) > 0, do: errors / length(recent_history), else: 0.0

    # Estimate throughput (executions per hour based on recent activity)
    # Rough estimate
    throughput = length(recent_history) * 6.0

    %{
      avg_time: avg_time,
      error_rate: error_rate,
      throughput: throughput
    }
  end

  defp calculate_stats_from_history(_), do: default_stats()

  defp default_stats() do
    %{
      avg_time: 0.0,
      error_rate: 0.0,
      throughput: 0.0
    }
  end

  defp calculate_cpu_usage(reductions) do
    # Simple CPU usage estimation based on reductions
    # This is a rough approximation
    case reductions do
      r when r > 1_000_000 -> 80.0
      r when r > 500_000 -> 60.0
      r when r > 100_000 -> 40.0
      r when r > 50_000 -> 20.0
      _ -> 10.0
    end
  end

  defp dispatch_signal(signal, state) do
    # Use Jido's signal dispatch system
    case Jido.Signal.Dispatch.dispatch(signal, state.target) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Signal dispatch failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
