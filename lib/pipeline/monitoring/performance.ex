defmodule Pipeline.Monitoring.Performance do
  @moduledoc """
  Performance monitoring and metrics collection for pipeline execution.

  Provides real-time performance tracking, memory usage monitoring,
  bottleneck identification, and performance optimization recommendations.
  """

  require Logger
  use GenServer

  # 500MB
  @default_memory_threshold 500_000_000
  # 30 seconds
  @default_execution_threshold 30_000
  # 1 second
  @sample_interval 1_000

  defstruct [
    :start_time,
    :pipeline_name,
    :memory_threshold,
    :execution_threshold,
    :metrics,
    :samples,
    :warnings,
    :step_metrics
  ]

  @type t :: %__MODULE__{}
  @type metric_value :: number()
  @type metrics :: %{
          memory_usage: metric_value,
          cpu_usage: metric_value,
          execution_time: metric_value,
          step_count: non_neg_integer(),
          error_count: non_neg_integer()
        }

  # Client API

  @doc """
  Start performance monitoring for a pipeline.
  """
  @spec start_monitoring(String.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_monitoring(pipeline_name, opts \\ []) do
    GenServer.start_link(__MODULE__, {pipeline_name, opts}, name: via_tuple(pipeline_name))
  end

  @doc """
  Stop performance monitoring and return final metrics.
  """
  @spec stop_monitoring(String.t()) :: {:ok, map()} | {:error, term()}
  def stop_monitoring(pipeline_name) do
    case GenServer.whereis(via_tuple(pipeline_name)) do
      nil ->
        {:error, :not_found}

      pid ->
        try do
          # 1 second timeout
          metrics = GenServer.call(pid, :get_final_metrics, 1000)
          # 1 second timeout
          GenServer.stop(pid, :normal, 1000)
          {:ok, metrics}
        catch
          :exit, {:timeout, _} ->
            # Force kill if timeout
            Process.exit(pid, :kill)
            {:error, :timeout}

          :exit, {:noproc, _} ->
            {:error, :not_found}
        end
    end
  end

  @doc """
  Record step start event.
  """
  @spec step_started(String.t(), String.t(), String.t()) :: :ok
  def step_started(pipeline_name, step_name, step_type) do
    case GenServer.whereis(via_tuple(pipeline_name)) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:step_started, step_name, step_type})
    end
  end

  @doc """
  Record step completion event.
  """
  @spec step_completed(String.t(), String.t(), map()) :: :ok
  def step_completed(pipeline_name, step_name, result) do
    case GenServer.whereis(via_tuple(pipeline_name)) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:step_completed, step_name, result})
    end
  end

  @doc """
  Record step failure event.
  """
  @spec step_failed(String.t(), String.t(), String.t()) :: :ok
  def step_failed(pipeline_name, step_name, error) do
    case GenServer.whereis(via_tuple(pipeline_name)) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:step_failed, step_name, error})
    end
  end

  @doc """
  Get current performance metrics.
  """
  @spec get_metrics(String.t()) :: {:ok, map()} | {:error, term()}
  def get_metrics(pipeline_name) do
    case GenServer.whereis(via_tuple(pipeline_name)) do
      nil -> {:error, :not_found}
      pid -> {:ok, GenServer.call(pid, :get_metrics)}
    end
  end

  @doc """
  Check if performance thresholds are being exceeded.
  """
  @spec check_thresholds(String.t()) :: {:ok, list()} | {:error, term()}
  def check_thresholds(pipeline_name) do
    case GenServer.whereis(via_tuple(pipeline_name)) do
      nil -> {:error, :not_found}
      pid -> {:ok, GenServer.call(pid, :check_thresholds)}
    end
  end

  # GenServer Callbacks

  @impl true
  def init({pipeline_name, opts}) do
    memory_threshold = Keyword.get(opts, :memory_threshold, @default_memory_threshold)
    execution_threshold = Keyword.get(opts, :execution_threshold, @default_execution_threshold)

    state = %__MODULE__{
      start_time: DateTime.utc_now(),
      pipeline_name: pipeline_name,
      memory_threshold: memory_threshold,
      execution_threshold: execution_threshold,
      metrics: %{
        memory_usage: 0,
        cpu_usage: 0.0,
        execution_time: 0,
        step_count: 0,
        error_count: 0
      },
      samples: [],
      warnings: [],
      step_metrics: %{}
    }

    # Start periodic sampling
    schedule_sample()

    Logger.info("🔍 Started performance monitoring for pipeline: #{pipeline_name}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:step_started, step_name, step_type}, state) do
    step_start_time = DateTime.utc_now()

    step_metric = %{
      name: step_name,
      type: step_type,
      start_time: step_start_time,
      status: :running
    }

    updated_step_metrics = Map.put(state.step_metrics, step_name, step_metric)
    updated_metrics = %{state.metrics | step_count: state.metrics.step_count + 1}

    {:noreply, %{state | step_metrics: updated_step_metrics, metrics: updated_metrics}}
  end

  @impl true
  def handle_cast({:step_completed, step_name, result}, state) do
    completion_time = DateTime.utc_now()

    case Map.get(state.step_metrics, step_name) do
      nil ->
        {:noreply, state}

      step_metric ->
        duration = DateTime.diff(completion_time, step_metric.start_time, :millisecond)

        updated_step_metric = %{
          step_metric
          | end_time: completion_time,
            duration_ms: duration,
            status: :completed,
            result_size: calculate_result_size(result)
        }

        updated_step_metrics = Map.put(state.step_metrics, step_name, updated_step_metric)

        # Check for performance warnings
        warnings = check_step_performance(updated_step_metric, state.warnings)

        {:noreply, %{state | step_metrics: updated_step_metrics, warnings: warnings}}
    end
  end

  @impl true
  def handle_cast({:step_failed, step_name, error}, state) do
    completion_time = DateTime.utc_now()

    case Map.get(state.step_metrics, step_name) do
      nil ->
        {:noreply, state}

      step_metric ->
        duration = DateTime.diff(completion_time, step_metric.start_time, :millisecond)

        updated_step_metric = %{
          step_metric
          | end_time: completion_time,
            duration_ms: duration,
            status: :failed,
            error: error
        }

        updated_step_metrics = Map.put(state.step_metrics, step_name, updated_step_metric)
        updated_metrics = %{state.metrics | error_count: state.metrics.error_count + 1}

        {:noreply, %{state | step_metrics: updated_step_metrics, metrics: updated_metrics}}
    end
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    current_metrics = calculate_current_metrics(state)
    {:reply, current_metrics, state}
  end

  @impl true
  def handle_call(:get_final_metrics, _from, state) do
    final_metrics = calculate_final_metrics(state)
    {:reply, final_metrics, state}
  end

  @impl true
  def handle_call(:check_thresholds, _from, state) do
    warnings = check_all_thresholds(state)
    {:reply, warnings, %{state | warnings: warnings}}
  end

  @impl true
  def handle_info(:sample_metrics, state) do
    sample = collect_system_metrics()
    # Keep last 100 samples
    updated_samples = [sample | Enum.take(state.samples, 99)]

    updated_metrics = %{
      state.metrics
      | memory_usage: sample.memory_usage,
        cpu_usage: sample.cpu_usage,
        execution_time: DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    }

    # Check thresholds
    warnings = check_system_thresholds(sample, state)

    schedule_sample()
    {:noreply, %{state | samples: updated_samples, metrics: updated_metrics, warnings: warnings}}
  end

  # Private Functions

  defp via_tuple(pipeline_name) do
    {:via, Registry, {Pipeline.MonitoringRegistry, "performance_#{pipeline_name}"}}
  end

  defp schedule_sample do
    Process.send_after(self(), :sample_metrics, @sample_interval)
  end

  defp collect_system_metrics do
    # Use Erlang's built-in memory info as fallback
    memory_usage = :erlang.memory(:total)

    %{
      timestamp: DateTime.utc_now(),
      memory_usage: memory_usage,
      # Rough estimate
      memory_total: memory_usage * 2,
      memory_available: memory_usage,
      cpu_usage: get_cpu_usage(),
      process_count: :erlang.system_info(:process_count)
    }
  rescue
    _ ->
      %{
        timestamp: DateTime.utc_now(),
        memory_usage: 0,
        memory_total: 0,
        memory_available: 0,
        cpu_usage: 0.0,
        process_count: 0
      }
  end

  defp get_cpu_usage do
    # CPU monitoring is not available without :os_mon application
    # Return a placeholder value
    0.0
  end

  defp calculate_result_size(result) when is_binary(result) do
    byte_size(result)
  end

  defp calculate_result_size(result) when is_map(result) do
    result
    |> :erlang.term_to_binary()
    |> byte_size()
  end

  defp calculate_result_size(_result), do: 0

  defp check_step_performance(step_metric, existing_warnings) do
    warnings = []

    # Check execution time
    warnings =
      if step_metric.duration_ms > 60_000 do
        warning = %{
          type: :slow_step,
          step: step_metric.name,
          duration_ms: step_metric.duration_ms,
          timestamp: DateTime.utc_now()
        }

        [warning | warnings]
      else
        warnings
      end

    # Check result size
    # 10MB
    warnings =
      if step_metric[:result_size] && step_metric.result_size > 10_000_000 do
        warning = %{
          type: :large_result,
          step: step_metric.name,
          size_bytes: step_metric.result_size,
          timestamp: DateTime.utc_now()
        }

        [warning | warnings]
      else
        warnings
      end

    warnings ++ existing_warnings
  end

  defp check_system_thresholds(sample, state) do
    warnings = state.warnings

    # Check memory threshold
    warnings =
      if sample.memory_usage > state.memory_threshold do
        warning = %{
          type: :memory_threshold,
          current: sample.memory_usage,
          threshold: state.memory_threshold,
          timestamp: DateTime.utc_now()
        }

        Logger.warning(
          "🚨 Memory usage exceeded threshold: #{format_bytes(sample.memory_usage)} > #{format_bytes(state.memory_threshold)}"
        )

        [warning | warnings]
      else
        warnings
      end

    # Check execution time threshold
    # Convert to ms
    warnings =
      if state.metrics.execution_time > state.execution_threshold * 1000 do
        warning = %{
          type: :execution_threshold,
          current_ms: state.metrics.execution_time,
          threshold_ms: state.execution_threshold * 1000,
          timestamp: DateTime.utc_now()
        }

        Logger.warning(
          "🚨 Execution time exceeded threshold: #{state.metrics.execution_time}ms > #{state.execution_threshold * 1000}ms"
        )

        [warning | warnings]
      else
        warnings
      end

    warnings
  end

  defp check_all_thresholds(state) do
    case List.last(state.samples) do
      nil -> state.warnings
      sample -> check_system_thresholds(sample, state)
    end
  end

  defp calculate_current_metrics(state) do
    %{
      pipeline_name: state.pipeline_name,
      start_time: state.start_time,
      current_time: DateTime.utc_now(),
      execution_time_ms: state.metrics.execution_time,
      memory_usage_bytes: state.metrics.memory_usage,
      cpu_usage_percent: state.metrics.cpu_usage,
      step_count: state.metrics.step_count,
      error_count: state.metrics.error_count,
      active_steps: count_active_steps(state.step_metrics),
      completed_steps: count_completed_steps(state.step_metrics),
      failed_steps: count_failed_steps(state.step_metrics),
      # Last 10 warnings
      warnings: Enum.take(state.warnings, 10)
    }
  end

  defp calculate_final_metrics(state) do
    total_duration = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)

    step_summary =
      state.step_metrics
      |> Map.values()
      |> Enum.map(fn step ->
        %{
          name: step.name,
          type: step.type,
          duration_ms: step[:duration_ms] || 0,
          status: step.status,
          result_size_bytes: step[:result_size] || 0
        }
      end)

    slowest_step =
      step_summary
      |> Enum.max_by(& &1.duration_ms, fn -> nil end)

    largest_result_step =
      step_summary
      |> Enum.max_by(& &1.result_size_bytes, fn -> nil end)

    %{
      pipeline_name: state.pipeline_name,
      total_duration_ms: total_duration,
      total_steps: state.metrics.step_count,
      successful_steps: count_completed_steps(state.step_metrics),
      failed_steps: state.metrics.error_count,
      peak_memory_bytes: get_peak_memory(state.samples),
      average_memory_bytes: get_average_memory(state.samples),
      peak_cpu_percent: get_peak_cpu(state.samples),
      slowest_step: slowest_step,
      largest_result_step: largest_result_step,
      total_warnings: length(state.warnings),
      warnings_by_type: group_warnings_by_type(state.warnings),
      step_details: step_summary,
      recommendations: generate_recommendations(state)
    }
  end

  defp count_active_steps(step_metrics) do
    step_metrics
    |> Map.values()
    |> Enum.count(&(&1.status == :running))
  end

  defp count_completed_steps(step_metrics) do
    step_metrics
    |> Map.values()
    |> Enum.count(&(&1.status == :completed))
  end

  defp count_failed_steps(step_metrics) do
    step_metrics
    |> Map.values()
    |> Enum.count(&(&1.status == :failed))
  end

  defp get_peak_memory(samples) do
    samples
    |> Enum.map(& &1.memory_usage)
    |> Enum.max(fn -> 0 end)
  end

  defp get_average_memory(samples) when length(samples) > 0 do
    total = samples |> Enum.map(& &1.memory_usage) |> Enum.sum()
    div(total, length(samples))
  end

  defp get_average_memory(_samples), do: 0

  defp get_peak_cpu(samples) do
    samples
    |> Enum.map(& &1.cpu_usage)
    |> Enum.max(fn -> 0.0 end)
  end

  defp group_warnings_by_type(warnings) do
    warnings
    |> Enum.group_by(& &1.type)
    |> Map.new(fn {type, warns} -> {type, length(warns)} end)
  end

  defp generate_recommendations(state) do
    recommendations = []

    # Check memory usage
    recommendations =
      if get_peak_memory(state.samples) > state.memory_threshold * 0.8 do
        ["Consider enabling streaming for large data operations" | recommendations]
      else
        recommendations
      end

    # Check slow steps
    slow_steps =
      state.step_metrics
      |> Map.values()
      |> Enum.filter(&(&1[:duration_ms] && &1.duration_ms > 30_000))

    recommendations =
      if length(slow_steps) > 0 do
        [
          "Optimize slow steps: #{slow_steps |> Enum.map(& &1.name) |> Enum.join(", ")}"
          | recommendations
        ]
      else
        recommendations
      end

    # Check large results
    large_results =
      state.step_metrics
      |> Map.values()
      |> Enum.filter(&(&1[:result_size] && &1.result_size > 5_000_000))

    recommendations =
      if length(large_results) > 0 do
        ["Enable result streaming for steps with large outputs" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end
