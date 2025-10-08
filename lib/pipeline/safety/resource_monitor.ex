defmodule Pipeline.Safety.ResourceMonitor do
  @moduledoc """
  Resource monitoring and management for nested pipeline execution.

  Provides memory usage tracking, resource cleanup, and resource limit enforcement
  to prevent resource exhaustion during nested pipeline execution.
  """

  require Logger

  # Default configuration values
  # 1GB
  @default_memory_limit_mb 1024
  # 5 minutes
  @default_timeout_seconds 300

  @type resource_limits :: %{
          memory_limit_mb: non_neg_integer(),
          timeout_seconds: non_neg_integer()
        }

  @type resource_usage :: %{
          memory_bytes: non_neg_integer(),
          start_time: DateTime.t(),
          elapsed_ms: non_neg_integer()
        }

  @type check_result :: :ok | {:error, String.t()}

  @doc """
  Check if current resource usage exceeds configured limits.

  ## Parameters
  - `usage`: Current resource usage metrics
  - `limits`: Resource limits configuration (optional)

  ## Returns
  - `:ok` if within limits
  - `{:error, message}` if limits exceeded

  ## Examples

      iex> usage = %{memory_bytes: 100_000_000, start_time: DateTime.utc_now(), elapsed_ms: 1000}
      iex> Pipeline.Safety.ResourceMonitor.check_limits(usage)
      :ok
      
      iex> usage = %{memory_bytes: 2_000_000_000, start_time: DateTime.utc_now(), elapsed_ms: 1000}
      iex> limits = %{memory_limit_mb: 1024}
      iex> Pipeline.Safety.ResourceMonitor.check_limits(usage, limits)
      {:error, "Memory limit exceeded: 1907.3 MB > 1024 MB"}
  """
  def check_limits(usage) when is_map(usage) do
    check_limits(usage, %{})
  end

  @spec check_limits(resource_usage(), resource_limits()) :: check_result()
  def check_limits(usage, limits) do
    memory_limit_mb = Map.get(limits, :memory_limit_mb, get_memory_limit_mb())
    timeout_seconds = Map.get(limits, :timeout_seconds, get_timeout_seconds())

    # Convert MB to bytes
    memory_limit_bytes = memory_limit_mb * 1_048_576
    # Convert seconds to ms
    timeout_ms = timeout_seconds * 1000

    cond do
      usage.memory_bytes > memory_limit_bytes ->
        current_mb = Float.round(usage.memory_bytes / 1_048_576, 1)
        {:error, "Memory limit exceeded: #{current_mb} MB > #{memory_limit_mb} MB"}

      usage.elapsed_ms > timeout_ms ->
        current_seconds = Float.round(usage.elapsed_ms / 1000, 1)
        {:error, "Execution timeout exceeded: #{current_seconds}s > #{timeout_seconds}s"}

      true ->
        :ok
    end
  end

  @doc """
  Collect current resource usage metrics.

  ## Parameters
  - `start_time`: When execution started (optional, defaults to now)

  ## Returns
  - Resource usage metrics
  """
  @spec collect_usage(DateTime.t() | nil) :: resource_usage()
  def collect_usage(start_time \\ nil) do
    start_time = start_time || DateTime.utc_now()
    current_time = DateTime.utc_now()
    elapsed_ms = DateTime.diff(current_time, start_time, :millisecond)

    memory_bytes = get_memory_usage()

    %{
      memory_bytes: memory_bytes,
      start_time: start_time,
      elapsed_ms: elapsed_ms
    }
  end

  @doc """
  Monitor resource usage during execution and check limits.

  ## Parameters
  - `start_time`: When execution started
  - `limits`: Resource limits configuration (optional)

  ## Returns
  - `:ok` if within limits
  - `{:error, message}` if limits exceeded
  """
  def monitor_execution(start_time) when is_struct(start_time, DateTime) do
    monitor_execution(start_time, %{})
  end

  @spec monitor_execution(DateTime.t(), resource_limits()) :: check_result()
  def monitor_execution(start_time, limits) do
    usage = collect_usage(start_time)
    check_limits(usage, limits)
  end

  @doc """
  Create workspace directory for nested pipeline execution.

  ## Parameters
  - `workspace_path`: Path to workspace directory
  - `step_name`: Name of the step (for unique directory naming)

  ## Returns
  - `{:ok, full_path}` if directory created successfully
  - `{:error, reason}` if creation failed
  """
  @spec create_workspace(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def create_workspace(workspace_path, step_name) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    unique_dir = "#{step_name}_#{timestamp}_#{:rand.uniform(1000)}"
    full_path = Path.join(workspace_path, unique_dir)

    case File.mkdir_p(full_path) do
      :ok ->
        Logger.debug("📁 Created workspace directory: #{full_path}")
        {:ok, full_path}

      {:error, reason} ->
        error_msg = "Failed to create workspace directory '#{full_path}': #{inspect(reason)}"
        Logger.error("❌ #{error_msg}")
        {:error, error_msg}
    end
  end

  @doc """
  Clean up workspace directory and its contents.

  ## Parameters
  - `workspace_path`: Path to workspace directory to clean up

  ## Returns
  - `:ok` if cleanup successful
  - `{:error, reason}` if cleanup failed
  """
  @spec cleanup_workspace(String.t()) :: :ok | {:error, String.t()}
  def cleanup_workspace(workspace_path) do
    if File.exists?(workspace_path) do
      case File.rm_rf(workspace_path) do
        {:ok, _} ->
          Logger.debug("🧹 Cleaned up workspace directory: #{workspace_path}")
          :ok

        {:error, reason, file} ->
          error_msg =
            "Failed to clean up workspace '#{workspace_path}': #{inspect(reason)} (file: #{file})"

          Logger.warning("⚠️ #{error_msg}")
          {:error, error_msg}
      end
    else
      Logger.debug("🧹 Workspace directory already clean: #{workspace_path}")
      :ok
    end
  end

  @doc """
  Perform resource cleanup on execution context.

  This function cleans up resources associated with nested pipeline execution,
  including workspace directories and large data structures.

  ## Parameters
  - `context`: Execution context containing resource references

  ## Returns
  - Updated context with resources cleaned
  """
  @spec cleanup_context(map()) :: %{
          :execution_log => [],
          :results => %{},
          optional(any()) => any()
        }
  def cleanup_context(context) do
    # Clean workspace if it exists
    if workspace_dir = context[:workspace_dir] do
      _cleanup_result = cleanup_workspace(workspace_dir)
    end

    # Clear large data structures
    cleaned_context =
      context
      |> Map.put(:results, %{})
      |> Map.put(:execution_log, [])
      |> Map.delete(:large_data)
      |> Map.delete(:cached_results)

    # Recursively clean parent contexts if needed
    if parent_context = context[:parent_context] do
      updated_parent = cleanup_context(parent_context)
      Map.put(cleaned_context, :parent_context, updated_parent)
    else
      cleaned_context
    end
  end

  @doc """
  Log resource usage with appropriate detail level.

  ## Parameters
  - `usage`: Current resource usage metrics
  - `level`: Log level (:debug, :info, :warning, :error)
  """
  @spec log_resource_usage(resource_usage(), atom()) :: :ok
  def log_resource_usage(usage, level \\ :debug) do
    memory_mb = Float.round(usage.memory_bytes / 1_048_576, 1)
    elapsed_seconds = Float.round(usage.elapsed_ms / 1000, 1)

    message = "📊 Resource usage: #{memory_mb} MB memory, #{elapsed_seconds}s elapsed"

    case level do
      :debug -> Logger.debug(message)
      :info -> Logger.info(message)
      :warning -> Logger.warning(message)
      :error -> Logger.error(message)
      _ -> Logger.debug(message)
    end
  end

  @doc """
  Check if memory usage is approaching limits and log warnings.

  ## Parameters
  - `usage`: Current resource usage metrics
  - `limits`: Resource limits configuration (optional)

  ## Returns
  - `:ok` always (warnings are logged, not returned as errors)
  """
  def check_memory_pressure(usage) when is_map(usage) do
    check_memory_pressure(usage, %{})
  end

  @spec check_memory_pressure(resource_usage(), resource_limits()) :: :ok
  def check_memory_pressure(usage, limits) do
    memory_limit_mb = Map.get(limits, :memory_limit_mb, get_memory_limit_mb())
    memory_limit_bytes = memory_limit_mb * 1_048_576

    memory_usage_percent = usage.memory_bytes / memory_limit_bytes * 100

    cond do
      memory_usage_percent > 90 ->
        log_resource_usage(usage, :error)
        Logger.error("🚨 Critical memory usage: #{Float.round(memory_usage_percent, 1)}% of limit")

      memory_usage_percent > 75 ->
        log_resource_usage(usage, :warning)
        Logger.warning("⚠️ High memory usage: #{Float.round(memory_usage_percent, 1)}% of limit")

      memory_usage_percent > 50 ->
        log_resource_usage(usage, :info)
        Logger.info("📈 Moderate memory usage: #{Float.round(memory_usage_percent, 1)}% of limit")

      true ->
        log_resource_usage(usage, :debug)
    end

    :ok
  end

  # Private helper functions

  defp get_memory_usage do
    try do
      :erlang.memory(:total)
    rescue
      _ -> 0
    end
  end

  defp get_memory_limit_mb do
    Application.get_env(:pipeline, :memory_limit_mb, @default_memory_limit_mb)
  end

  defp get_timeout_seconds do
    Application.get_env(:pipeline, :timeout_seconds, @default_timeout_seconds)
  end
end
