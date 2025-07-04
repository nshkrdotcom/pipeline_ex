defmodule Pipeline.Safety.SafetyManager do
  @moduledoc """
  Unified safety management for nested pipeline execution.

  Provides a single interface for all safety checks including recursion limits,
  resource monitoring, and error handling for nested pipeline execution.
  """

  require Logger
  alias Pipeline.Safety.{RecursionGuard, ResourceMonitor}

  @type safety_config :: %{
          max_depth: non_neg_integer(),
          max_total_steps: non_neg_integer(),
          memory_limit_mb: non_neg_integer(),
          timeout_seconds: non_neg_integer(),
          workspace_enabled: boolean(),
          cleanup_on_error: boolean()
        }

  @type execution_context :: %{
          nesting_depth: non_neg_integer(),
          pipeline_id: String.t(),
          parent_context: execution_context() | nil,
          step_count: non_neg_integer(),
          start_time: DateTime.t(),
          workspace_dir: String.t() | nil
        }

  @type safety_result :: :ok | {:error, String.t()}

  @doc """
  Perform comprehensive safety checks before executing a nested pipeline.

  ## Parameters
  - `pipeline_id`: The ID of the pipeline about to be executed
  - `context`: The current execution context
  - `config`: Safety configuration (optional)

  ## Returns
  - `:ok` if all safety checks pass
  - `{:error, message}` if any safety check fails

  ## Examples

      iex> context = create_test_context("test", 2, 5)
      iex> Pipeline.Safety.SafetyManager.check_safety("child", context)
      :ok
      
      iex> context = create_test_context("test", 15, 5)
      iex> Pipeline.Safety.SafetyManager.check_safety("child", context)
      {:error, "Maximum nesting depth (10) exceeded: current depth is 15"}
  """
  @spec check_safety(String.t(), execution_context(), safety_config()) :: safety_result()
  def check_safety(pipeline_id, context, config \\ %{})

  def check_safety(pipeline_id, context, config) do
    # Extract limits for each safety component
    recursion_limits = %{
      max_depth: Map.get(config, :max_depth, 10),
      max_total_steps: Map.get(config, :max_total_steps, 1000)
    }

    resource_limits = %{
      memory_limit_mb: Map.get(config, :memory_limit_mb, 1024),
      timeout_seconds: Map.get(config, :timeout_seconds, 300)
    }

    # Perform all safety checks
    with :ok <- RecursionGuard.check_all_safety(pipeline_id, context, recursion_limits),
         :ok <- ResourceMonitor.monitor_execution(context.start_time, resource_limits) do
      Logger.debug(
        "✅ All safety checks passed for pipeline '#{pipeline_id}' at depth #{context.nesting_depth}"
      )

      :ok
    else
      {:error, message} ->
        Logger.error("🚨 Safety check failed for pipeline '#{pipeline_id}': #{message}")
        {:error, message}
    end
  end

  @doc """
  Create execution context for a nested pipeline with safety tracking.

  ## Parameters
  - `pipeline_id`: The ID of the pipeline
  - `parent_context`: The parent execution context (optional)
  - `step_count`: Number of steps in the pipeline (default: 0)
  - `config`: Safety configuration (optional)

  ## Returns
  - New execution context with safety tracking
  """
  @spec create_safe_context(
          String.t(),
          execution_context() | nil,
          non_neg_integer(),
          safety_config()
        ) :: execution_context()
  def create_safe_context(pipeline_id, parent_context \\ nil, step_count \\ 0, config \\ %{})

  def create_safe_context(pipeline_id, parent_context, step_count, config) do
    # Create base execution context
    base_context =
      RecursionGuard.create_execution_context(pipeline_id, parent_context, step_count)

    # Add resource tracking
    start_time = DateTime.utc_now()

    workspace_dir =
      if Map.get(config, :workspace_enabled, true) do
        create_workspace_if_needed(pipeline_id, config)
      else
        nil
      end

    Map.merge(base_context, %{
      start_time: start_time,
      workspace_dir: workspace_dir
    })
  end

  @doc """
  Monitor ongoing execution and check for safety violations.

  ## Parameters
  - `context`: Current execution context
  - `config`: Safety configuration (optional)

  ## Returns
  - `:ok` if execution is within safety limits
  - `{:error, message}` if safety limits exceeded
  """
  @spec monitor_execution(execution_context(), safety_config()) :: safety_result()
  def monitor_execution(context, config \\ %{})

  def monitor_execution(context, config) do
    resource_limits = %{
      memory_limit_mb: Map.get(config, :memory_limit_mb, 1024),
      timeout_seconds: Map.get(config, :timeout_seconds, 300)
    }

    case ResourceMonitor.monitor_execution(context.start_time, resource_limits) do
      :ok ->
        # Also check memory pressure for warnings
        usage = ResourceMonitor.collect_usage(context.start_time)
        ResourceMonitor.check_memory_pressure(usage, resource_limits)
        :ok

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Clean up resources and perform safety cleanup after execution.

  ## Parameters
  - `context`: Execution context to clean up
  - `config`: Safety configuration (optional)

  ## Returns
  - Cleaned execution context
  """
  @spec cleanup_execution(execution_context(), safety_config()) :: execution_context()
  def cleanup_execution(context, config \\ %{})

  def cleanup_execution(context, config) do
    cleanup_on_error = Map.get(config, :cleanup_on_error, true)

    if cleanup_on_error do
      # Clean workspace if it exists
      if context.workspace_dir do
        _ = ResourceMonitor.cleanup_workspace(context.workspace_dir)
      end

      # Clean context resources
      ResourceMonitor.cleanup_context(context)
    else
      context
    end
  end

  @doc """
  Handle safety violations and perform appropriate cleanup.

  ## Parameters
  - `error`: The safety error that occurred
  - `context`: Current execution context
  - `config`: Safety configuration (optional)

  ## Returns
  - Formatted error with context information
  """
  @spec handle_safety_violation(String.t(), execution_context(), safety_config()) :: String.t()
  def handle_safety_violation(error, context, config \\ %{})

  def handle_safety_violation(error, context, config) do
    # Log the safety violation
    Logger.error("🚨 Safety violation in pipeline '#{context.pipeline_id}': #{error}")

    # Perform cleanup
    _ = cleanup_execution(context, config)

    # Format error with context
    execution_chain = RecursionGuard.build_execution_chain(context)
    chain_display = Enum.join(execution_chain, " → ")

    """
    Safety violation in nested pipeline execution:

    Pipeline: #{context.pipeline_id}
    Error: #{error}
    Execution Chain: #{chain_display}
    Nesting Depth: #{context.nesting_depth}
    Total Steps: #{RecursionGuard.count_total_steps(context)}
    Elapsed Time: #{DateTime.diff(DateTime.utc_now(), context.start_time, :millisecond)}ms
    """
  end

  @doc """
  Get default safety configuration.

  ## Returns
  - Default safety configuration map
  """
  @spec default_config() :: safety_config()
  def default_config do
    %{
      max_depth: Application.get_env(:pipeline, :max_nesting_depth, 10),
      max_total_steps: Application.get_env(:pipeline, :max_total_steps, 1000),
      memory_limit_mb: Application.get_env(:pipeline, :memory_limit_mb, 1024),
      timeout_seconds: Application.get_env(:pipeline, :timeout_seconds, 300),
      workspace_enabled: Application.get_env(:pipeline, :workspace_enabled, true),
      cleanup_on_error: Application.get_env(:pipeline, :cleanup_on_error, true)
    }
  end

  @doc """
  Merge user configuration with defaults.

  ## Parameters
  - `user_config`: User-provided configuration (optional)

  ## Returns
  - Complete safety configuration
  """
  @spec merge_config(map()) :: safety_config()
  def merge_config(user_config \\ %{}) do
    Map.merge(default_config(), user_config)
  end

  # Private helper functions

  defp create_workspace_if_needed(pipeline_id, _config) do
    workspace_root = Application.get_env(:pipeline, :nested_workspace_root, "./nested_workspaces")

    case ResourceMonitor.create_workspace(workspace_root, pipeline_id) do
      {:ok, workspace_path} -> workspace_path
      {:error, _reason} -> nil
    end
  end

  # Helper function for tests (used in doctests)
  defp create_test_context(pipeline_id, nesting_depth, step_count) do
    %{
      nesting_depth: nesting_depth,
      pipeline_id: pipeline_id,
      parent_context: nil,
      step_count: step_count,
      start_time: DateTime.utc_now(),
      workspace_dir: nil
    }
  end
end

