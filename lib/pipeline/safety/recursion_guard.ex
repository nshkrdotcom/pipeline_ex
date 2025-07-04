defmodule Pipeline.Safety.RecursionGuard do
  @moduledoc """
  Recursion protection and circular dependency detection for nested pipelines.

  Provides safety mechanisms to prevent infinite recursion and detect circular 
  dependencies in nested pipeline execution chains.
  """

  require Logger

  # Default configuration values
  @default_max_depth 10
  @default_max_total_steps 1000

  @type execution_context :: %{
          nesting_depth: non_neg_integer(),
          pipeline_id: String.t(),
          parent_context: execution_context() | nil,
          step_count: non_neg_integer()
        }

  @type safety_limits :: %{
          max_depth: non_neg_integer(),
          max_total_steps: non_neg_integer()
        }

  @type check_result :: :ok | {:error, String.t()}

  @doc """
  Check if the current execution context violates recursion limits.

  ## Parameters
  - `context`: The current execution context
  - `limits`: Safety limits configuration (optional)

  ## Returns
  - `:ok` if all checks pass
  - `{:error, message}` if limits are exceeded

  ## Examples

      iex> context = %{nesting_depth: 2, pipeline_id: "test", parent_context: nil, step_count: 5}
      iex> Pipeline.Safety.RecursionGuard.check_limits(context)
      :ok
      
      iex> context = %{nesting_depth: 15, pipeline_id: "test", parent_context: nil, step_count: 5}
      iex> Pipeline.Safety.RecursionGuard.check_limits(context)
      {:error, "Maximum nesting depth (10) exceeded: current depth is 15"}
  """
  @spec check_limits(execution_context(), safety_limits()) :: check_result()
  def check_limits(context, limits \\ %{})

  def check_limits(context, limits) do
    max_depth = Map.get(limits, :max_depth, get_max_depth())
    max_total_steps = Map.get(limits, :max_total_steps, get_max_total_steps())

    cond do
      context.nesting_depth > max_depth ->
        {:error,
         "Maximum nesting depth (#{max_depth}) exceeded: current depth is #{context.nesting_depth}"}

      count_total_steps(context) > max_total_steps ->
        total_steps = count_total_steps(context)

        {:error,
         "Maximum total steps (#{max_total_steps}) exceeded: current total is #{total_steps}"}

      true ->
        :ok
    end
  end

  @doc """
  Check for circular dependencies in the execution chain.

  ## Parameters
  - `pipeline_id`: The ID of the pipeline about to be executed
  - `context`: The current execution context

  ## Returns
  - `:ok` if no circular dependency detected
  - `{:error, message}` if circular dependency found

  ## Examples

      iex> context = %{pipeline_id: "parent", parent_context: nil}
      iex> Pipeline.Safety.RecursionGuard.check_circular_dependency("child", context)
      :ok
      
      iex> parent = %{pipeline_id: "parent", parent_context: nil}
      iex> child = %{pipeline_id: "child", parent_context: parent}
      iex> Pipeline.Safety.RecursionGuard.check_circular_dependency("parent", child)
      {:error, "Circular dependency detected: parent → child → parent"}
  """
  @spec check_circular_dependency(String.t(), execution_context()) :: check_result()
  def check_circular_dependency(pipeline_id, context) do
    execution_chain = build_execution_chain(context)

    if pipeline_id in execution_chain do
      full_chain = [pipeline_id | execution_chain]
      chain_display = Enum.join(full_chain, " → ")
      {:error, "Circular dependency detected: #{chain_display}"}
    else
      :ok
    end
  end

  @doc """
  Perform all safety checks for nested pipeline execution.

  ## Parameters
  - `pipeline_id`: The ID of the pipeline about to be executed
  - `context`: The current execution context
  - `limits`: Safety limits configuration (optional)

  ## Returns
  - `:ok` if all checks pass
  - `{:error, message}` if any check fails
  """
  @spec check_all_safety(String.t(), execution_context(), safety_limits()) :: check_result()
  def check_all_safety(pipeline_id, context, limits \\ %{})

  def check_all_safety(pipeline_id, context, limits) do
    with :ok <- check_limits(context, limits),
         :ok <- check_circular_dependency(pipeline_id, context) do
      :ok
    else
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Build the execution chain from the current context up to the root.

  ## Parameters
  - `context`: The current execution context

  ## Returns
  - List of pipeline IDs in the execution chain
  """
  @spec build_execution_chain(execution_context()) :: [String.t()]
  def build_execution_chain(context) do
    case context.parent_context do
      nil -> [context.pipeline_id]
      parent -> [context.pipeline_id | build_execution_chain(parent)]
    end
  end

  @doc """
  Count the total number of steps across all nested pipelines.

  ## Parameters
  - `context`: The current execution context

  ## Returns
  - Total number of steps
  """
  @spec count_total_steps(execution_context()) :: non_neg_integer()
  def count_total_steps(context) do
    case context.parent_context do
      nil -> context.step_count
      parent -> context.step_count + count_total_steps(parent)
    end
  end

  @doc """
  Create a new execution context for a nested pipeline.

  ## Parameters
  - `pipeline_id`: The ID of the pipeline
  - `parent_context`: The parent execution context (optional)
  - `step_count`: The number of steps in this pipeline (default: 0)

  ## Returns
  - New execution context
  """
  @spec create_execution_context(String.t(), execution_context() | nil, non_neg_integer()) ::
          execution_context()
  def create_execution_context(pipeline_id, parent_context \\ nil, step_count \\ 0) do
    nesting_depth =
      case parent_context do
        nil -> 0
        parent -> parent.nesting_depth + 1
      end

    %{
      nesting_depth: nesting_depth,
      pipeline_id: pipeline_id,
      parent_context: parent_context,
      step_count: step_count
    }
  end

  @doc """
  Log safety check results with appropriate log level.

  ## Parameters
  - `check_result`: The result of safety checks
  - `pipeline_id`: The ID of the pipeline being checked
  - `context`: The current execution context
  """
  @spec log_safety_check(check_result(), String.t(), execution_context()) :: :ok
  def log_safety_check(:ok, pipeline_id, context) do
    Logger.debug(
      "✅ Safety checks passed for pipeline '#{pipeline_id}' at depth #{context.nesting_depth}"
    )
  end

  def log_safety_check({:error, message}, pipeline_id, context) do
    Logger.error(
      "🚨 Safety check failed for pipeline '#{pipeline_id}' at depth #{context.nesting_depth}: #{message}"
    )
  end

  # Private helper functions

  defp get_max_depth do
    Application.get_env(:pipeline, :max_nesting_depth, @default_max_depth)
  end

  defp get_max_total_steps do
    Application.get_env(:pipeline, :max_total_steps, @default_max_total_steps)
  end
end

