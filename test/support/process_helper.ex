defmodule Pipeline.Test.ProcessHelper do
  @moduledoc """
  Helper utilities for managing processes in tests.
  """

  alias Pipeline.Monitoring.Performance

  def safe_start_monitoring(name, opts \\ []) do
    case Performance.start_monitoring(name, opts) do
      {:ok, pid} -> {:ok, pid}
      {:already_started, pid} -> {:ok, pid}
      error -> error
    end
  end

  def safe_get_metrics(name) do
    case Performance.get_metrics(name) do
      {:ok, metrics} ->
        {:ok, metrics}

      {:error, :not_found} ->
        {:ok,
         %{
           step_count: 0,
           execution_time_ms: 0,
           memory_usage_bytes: 0
         }}

      error ->
        error
    end
  end

  def ensure_stopped(name) do
    case Performance.stop_monitoring(name) do
      {:ok, metrics} ->
        {:ok, metrics}

      {:error, :not_found} ->
        # Return empty metrics structure when monitoring wasn't found
        {:ok,
         %{
           total_steps: 0,
           successful_steps: 0,
           peak_memory_bytes: 0,
           execution_time_ms: 0,
           step_details: [],
           recommendations: [],
           total_warnings: 0
         }}

      error ->
        error
    end
  end

  def cleanup_all_monitoring do
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
