defmodule Pipeline.MABEAM.Sensors.QueueMonitor do
  use Jido.Sensor,
    name: "pipeline_queue_monitor",
    description: "Monitors pipeline execution queue depth and processing rates",
    category: :monitoring,
    tags: [:pipeline, :queue, :monitoring],
    vsn: "1.0.0",
    schema: [
      check_interval: [type: :pos_integer, default: 5000, doc: "Check interval in milliseconds"],
      alert_threshold: [type: :integer, default: 10, doc: "Queue depth alert threshold"]
    ]

  require Logger

  @impl true
  def mount(opts) do
    # Schedule periodic checks using timer, not Process.sleep
    case :timer.send_interval(opts.check_interval, self(), :check_queue) do
      {:ok, _timer_ref} -> :ok
      {:error, _reason} -> :ok  # Continue even if timer setup fails
    end

    {:ok,
     %{
       id: opts.id,
       target: opts.target,
       config: opts,
       last_check: DateTime.utc_now(),
       sensor: %{name: "pipeline_queue_monitor"}
     }}
  end

  @impl true
  def handle_info(:check_queue, state) do
    try do
      case deliver_signal(state) do
        {:ok, signal} ->
          case dispatch_signal(signal, state) do
            :ok -> :ok
            {:error, _reason} -> :ok  # Continue even if dispatch fails
          end
          {:noreply, %{state | last_check: DateTime.utc_now()}}

        {:error, reason} ->
          Logger.error("Queue monitor signal creation failed: #{inspect(reason)}")
          {:noreply, %{state | last_check: DateTime.utc_now()}}
      end
    rescue
      error ->
        Logger.error("Queue monitor error: #{inspect(error)}")
        {:noreply, state}
    end
  end

  @impl true
  def deliver_signal(state) do
    # Get queue stats from pipeline manager agents
    queue_depth = get_total_queue_depth()
    processing_rate = calculate_processing_rate()

    Jido.Signal.new(%{
      source: "#{state.sensor.name}:#{state.id}",
      type: "pipeline.queue_status",
      data: %{
        queue_depth: queue_depth,
        processing_rate: processing_rate,
        alert: queue_depth > state.config.alert_threshold,
        timestamp: DateTime.utc_now()
      }
    })
  end

  defp get_total_queue_depth() do
    # Query pipeline manager agents for queue stats
    # Using Registry to find pipeline manager agents
    try do
      case Registry.lookup(Pipeline.Registry, "pipeline_manager") do
        [{pid, _}] ->
          try do
            case Pipeline.MABEAM.Agents.PipelineManager.get_state(pid) do
              {:ok, state} -> length(state.queue)
              _ -> 0
            end
          catch
            :exit, _ -> 0
          end

        [] ->
          0
      end
    rescue
      # Registry doesn't exist
      ArgumentError -> 0
    catch
      :exit, _ -> 0
    end
  end

  defp calculate_processing_rate() do
    # Calculate pipelines processed per minute
    # This would typically be calculated from historical data
    # For now, we'll use a simple estimation based on system load
    case :erlang.statistics(:run_queue) do
      # High processing rate
      run_queue when run_queue < 10 -> 12.0
      # Medium processing rate  
      run_queue when run_queue < 50 -> 8.0
      # Low processing rate
      _ -> 4.0
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
