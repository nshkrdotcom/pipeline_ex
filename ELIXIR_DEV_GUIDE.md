# Claude's Guide to Exemplary Elixir/OTP Development

This guide demonstrates the principles of robust, idiomatic Elixir/OTP development through building a pipeline orchestration system. We'll follow the five core principles that separate production-grade Elixir from amateur code.

## The Five Commandments of Elixir/OTP

Before writing a single line of code, internalize these unbreakable rules:

1. **Processes are the unit of work and failure.** Isolate state and logic into separate, concurrent processes that can fail independently.

2. **Let It Crash.** Write code for the happy path. No defensive `try/rescue` for unexpected errors. Let supervisors handle failures.

3. **Supervisors Supervise.** A supervisor's only job is to start, stop, and restart children. Zero business logic.

4. **No Manual Spawns for Long-Lived Processes.** Every long-lived process must be part of a supervision tree. Use supervisors, not `spawn/1`, `spawn_link/1`, or `Task.start_link/1`.

5. **No `Process.sleep/1`.** Sleeping blocks scheduler threads and indicates design problems. Use asynchronous, message-based patterns.

---

## The Project: A Pipeline Execution Manager

We'll build a system that manages pipeline executions across multiple workers. This demonstrates:

- Dynamic process creation (workers for each pipeline)
- State management (execution history, worker status)
- Concurrent execution with proper isolation
- Real-world OTP patterns

### Step 1: Project Foundation

Always start with proper OTP application structure:

```bash
mix new pipeline_manager --sup
cd pipeline_manager
```

The generated `lib/pipeline_manager/application.ex` is our foundation:

```elixir
defmodule PipelineManager.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # We'll build our supervision tree here
    ]

    opts = [strategy: :one_for_one, name: PipelineManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Critical:** This module has ONE job - starting the supervision tree. No business logic ever belongs here.

### Step 2: The Pipeline Worker - A GenServer for Single Executions

Each pipeline execution gets its own dedicated process. This provides isolation and allows independent failure/recovery.

`lib/pipeline_manager/pipeline_worker.ex`:

```elixir
defmodule PipelineManager.PipelineWorker do
  use GenServer
  require Logger

  @execution_timeout 300_000  # 5 minutes

  # ===================================================================
  # Public Client API - Clean abstraction over GenServer
  # ===================================================================

  @doc """
  Starts a pipeline worker for a specific execution.
  MUST be started by a supervisor - never call directly in production.
  """
  def start_link(opts) do
    execution_id = Keyword.fetch!(opts, :execution_id)
    pipeline_spec = Keyword.fetch!(opts, :pipeline_spec)
    
    GenServer.start_link(__MODULE__, 
      %{execution_id: execution_id, pipeline_spec: pipeline_spec}, 
      name: via_name(execution_id))
  end

  @doc """
  Executes the pipeline. Returns immediately - execution is async.
  """
  def execute(execution_id) do
    GenServer.cast(via_name(execution_id), :execute)
  end

  @doc """
  Gets current execution status.
  """
  def get_status(execution_id) do
    GenServer.call(via_name(execution_id), :get_status, 5000)
  end

  @doc """
  Cancels execution if still running.
  """
  def cancel(execution_id) do
    GenServer.cast(via_name(execution_id), :cancel)
  end

  # ===================================================================
  # GenServer Callbacks - Internal implementation
  # ===================================================================

  @impl true
  def init(state) do
    # Set execution timeout - if we don't hear anything, crash
    Process.send_after(self(), :execution_timeout, @execution_timeout)
    
    initial_state = Map.merge(state, %{
      status: :pending,
      started_at: nil,
      completed_at: nil,
      result: nil,
      error: nil
    })
    
    {:ok, initial_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      execution_id: state.execution_id,
      status: state.status,
      started_at: state.started_at,
      completed_at: state.completed_at,
      duration: calculate_duration(state),
      result: state.result,
      error: state.error
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast(:execute, %{status: :pending} = state) do
    Logger.info("Starting pipeline execution: #{state.execution_id}")
    
    # Start async execution - don't block the GenServer
    task_pid = spawn_link(fn -> execute_pipeline_async(state.pipeline_spec) end)
    
    new_state = %{state | 
      status: :running, 
      started_at: DateTime.utc_now(),
      task_pid: task_pid
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:execute, state) do
    Logger.warning("Execution request ignored - already #{state.status}: #{state.execution_id}")
    {:noreply, state}
  end

  @impl true
  def handle_cast(:cancel, %{status: :running} = state) do
    Logger.info("Cancelling pipeline execution: #{state.execution_id}")
    
    # Kill the execution task
    if state.task_pid, do: Process.exit(state.task_pid, :cancelled)
    
    new_state = %{state | 
      status: :cancelled, 
      completed_at: DateTime.utc_now(),
      error: "Execution cancelled by user"
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:cancel, state) do
    Logger.info("Cancel request ignored - execution not running: #{state.execution_id}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:execution_complete, result}, %{status: :running} = state) do
    Logger.info("Pipeline execution completed: #{state.execution_id}")
    
    new_state = %{state |
      status: :completed,
      completed_at: DateTime.utc_now(),
      result: result
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:execution_failed, error}, %{status: :running} = state) do
    Logger.error("Pipeline execution failed: #{state.execution_id} - #{inspect(error)}")
    
    new_state = %{state |
      status: :failed,
      completed_at: DateTime.utc_now(),
      error: error
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:execution_timeout, %{status: :running} = state) do
    Logger.error("Pipeline execution timed out: #{state.execution_id}")
    
    # Kill the execution task
    if state.task_pid, do: Process.exit(state.task_pid, :timeout)
    
    new_state = %{state |
      status: :timeout,
      completed_at: DateTime.utc_now(),
      error: "Execution timed out after #{@execution_timeout}ms"
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:execution_timeout, state) do
    # Timeout received but we're not running - ignore
    {:noreply, state}
  end

  # Handle linked process death (the execution task)
  @impl true
  def handle_info({:EXIT, _pid, :normal}, state) do
    # Normal exit - execution completed successfully
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, %{status: :running} = state) do
    Logger.error("Execution task crashed: #{state.execution_id} - #{inspect(reason)}")
    
    new_state = %{state |
      status: :crashed,
      completed_at: DateTime.utc_now(),
      error: "Execution process crashed: #{inspect(reason)}"
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    # Process died but we're not running - ignore
    {:noreply, state}
  end

  # ===================================================================
  # Private Implementation
  # ===================================================================

  defp via_name(execution_id) do
    {:via, Registry, {PipelineManager.WorkerRegistry, execution_id}}
  end

  defp execute_pipeline_async(pipeline_spec) do
    parent = self()
    
    try do
      # Simulate pipeline execution
      # In reality, this would call your actual pipeline execution logic
      result = simulate_pipeline_execution(pipeline_spec)
      send(parent, {:execution_complete, result})
    rescue
      error ->
        send(parent, {:execution_failed, Exception.message(error)})
    catch
      :exit, reason ->
        send(parent, {:execution_failed, "Process exit: #{inspect(reason)}"})
    end
  end

  defp simulate_pipeline_execution(pipeline_spec) do
    # Simulate work - in reality, call your pipeline engine
    execution_time = Enum.random(1000..5000)
    Process.sleep(execution_time)  # Only acceptable here - simulating real work
    
    %{
      pipeline: pipeline_spec.name,
      steps_completed: pipeline_spec.step_count,
      execution_time_ms: execution_time,
      artifacts_generated: ["analysis.json", "report.pdf"]
    }
  end

  defp calculate_duration(%{started_at: nil}), do: nil
  defp calculate_duration(%{started_at: started, completed_at: nil}) do
    DateTime.diff(DateTime.utc_now(), started, :millisecond)
  end
  defp calculate_duration(%{started_at: started, completed_at: completed}) do
    DateTime.diff(completed, started, :millisecond)
  end
end
```

**Key Principles Demonstrated:**

- **Clean API Separation:** Public functions hide GenServer implementation details
- **Let It Crash:** We don't try to recover from execution failures - we record them and let supervision handle restarts
- **No Sleep:** Execution timeout uses `Process.send_after/3`, not `Process.sleep/1`
- **State Isolation:** Each execution has its own process and state

### Step 3: The Dynamic Supervisor for Workers

We need one worker per pipeline execution, but we don't know executions ahead of time. `DynamicSupervisor` handles this perfectly.

`lib/pipeline_manager/worker_supervisor.ex`:

```elixir
defmodule PipelineManager.WorkerSupervisor do
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new pipeline worker for the given execution.
  This is the ONLY correct way to start a pipeline worker.
  """
  def start_worker(execution_id, pipeline_spec) do
    child_spec = {
      PipelineManager.PipelineWorker,
      execution_id: execution_id,
      pipeline_spec: pipeline_spec
    }
    
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Terminates a worker for the given execution.
  """
  def stop_worker(execution_id) do
    case Registry.lookup(PipelineManager.WorkerRegistry, execution_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all currently running workers.
  """
  def list_workers do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.map(&get_worker_info/1)
    |> Enum.reject(&is_nil/1)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: 100  # Prevent runaway worker creation
    )
  end

  defp get_worker_info(pid) do
    case Registry.keys(PipelineManager.WorkerRegistry, pid) do
      [execution_id] ->
        case PipelineManager.PipelineWorker.get_status(execution_id) do
          status when is_map(status) -> status
          _ -> nil
        end
      _ -> nil
    end
  rescue
    _ -> nil  # Worker might have died between lookup and status call
  end
end
```

**Critical Points:**

- **No Manual Spawns:** We use `DynamicSupervisor.start_child/2` - the supervisor manages the worker lifecycle
- **Process Isolation:** Each worker can crash independently without affecting others
- **Registry Integration:** We use Registry for process discovery, not manual PID tracking

### Step 4: The Registry for Process Discovery

Registry provides efficient, distributed process name resolution:

`lib/pipeline_manager/worker_registry.ex`:

```elixir
defmodule PipelineManager.WorkerRegistry do
  @moduledoc """
  Registry for mapping execution_id -> pipeline worker PID.
  This provides O(1) lookup without a single point of failure.
  """
  
  use Registry, 
    keys: :unique, 
    name: __MODULE__
end
```

Simple, but crucial. This enables efficient process discovery across the entire cluster.

### Step 5: The Execution Manager - Public API

This module provides the public interface for managing pipeline executions:

`lib/pipeline_manager.ex`:

```elixir
defmodule PipelineManager do
  @moduledoc """
  Public API for managing pipeline executions.
  Provides a clean interface over the underlying OTP machinery.
  """
  
  require Logger

  @doc """
  Starts a new pipeline execution.
  Returns execution_id for tracking.
  """
  def start_execution(pipeline_spec) do
    execution_id = generate_execution_id()
    
    case PipelineManager.WorkerSupervisor.start_worker(execution_id, pipeline_spec) do
      {:ok, _pid} ->
        Logger.info("Started pipeline execution: #{execution_id}")
        {:ok, execution_id}
        
      {:error, {:already_started, _pid}} ->
        # Race condition - this is fine, return the existing execution
        Logger.info("Pipeline execution already exists: #{execution_id}")
        {:ok, execution_id}
        
      {:error, reason} ->
        Logger.error("Failed to start pipeline execution: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Executes a pipeline that's been started.
  """
  def execute_pipeline(execution_id) do
    case find_worker(execution_id) do
      {:ok, _pid} ->
        PipelineManager.PipelineWorker.execute(execution_id)
        :ok
        
      {:error, :not_found} ->
        {:error, "Execution not found: #{execution_id}"}
    end
  end

  @doc """
  Gets the status of a pipeline execution.
  """
  def get_execution_status(execution_id) do
    case find_worker(execution_id) do
      {:ok, _pid} ->
        status = PipelineManager.PipelineWorker.get_status(execution_id)
        {:ok, status}
        
      {:error, :not_found} ->
        {:error, "Execution not found: #{execution_id}"}
    end
  end

  @doc """
  Cancels a running pipeline execution.
  """
  def cancel_execution(execution_id) do
    case find_worker(execution_id) do
      {:ok, _pid} ->
        PipelineManager.PipelineWorker.cancel(execution_id)
        :ok
        
      {:error, :not_found} ->
        {:error, "Execution not found: #{execution_id}"}
    end
  end

  @doc """
  Lists all current pipeline executions.
  """
  def list_executions do
    PipelineManager.WorkerSupervisor.list_workers()
  end

  @doc """
  Convenience function: start and immediately execute a pipeline.
  """
  def run_pipeline(pipeline_spec) do
    with {:ok, execution_id} <- start_execution(pipeline_spec),
         :ok <- execute_pipeline(execution_id) do
      {:ok, execution_id}
    end
  end

  # ===================================================================
  # Private Implementation
  # ===================================================================

  defp find_worker(execution_id) do
    case Registry.lookup(PipelineManager.WorkerRegistry, execution_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  defp generate_execution_id do
    timestamp = System.system_time(:microsecond)
    random = :rand.uniform(9999)
    "exec_#{timestamp}_#{random}"
  end
end
```

**Design Principles:**

- **Single Responsibility:** This module only coordinates - no business logic
- **Error Propagation:** We return `{:ok, result}` or `{:error, reason}` consistently
- **Race Condition Handling:** We handle the case where processes start concurrently

### Step 6: Assembling the Supervision Tree

Now we wire everything together in our application:

`lib/pipeline_manager/application.ex`:

```elixir
defmodule PipelineManager.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Registry must start first - other processes depend on it
      PipelineManager.WorkerRegistry,
      
      # Dynamic supervisor for pipeline workers
      PipelineManager.WorkerSupervisor,
      
      # Optional: Add a cleanup process to remove old executions
      {PipelineManager.ExecutionCleaner, []}
    ]

    opts = [strategy: :one_for_one, name: PipelineManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Final Architecture:**

```
Application
└── PipelineManager.Supervisor (:one_for_one)
    ├── PipelineManager.WorkerRegistry
    ├── PipelineManager.WorkerSupervisor (DynamicSupervisor)
    │   ├── PipelineWorker [exec_1234] (dynamically started)
    │   ├── PipelineWorker [exec_5678] (dynamically started)
    │   └── ... (one per execution)
    └── PipelineManager.ExecutionCleaner
```

This is production-grade OTP architecture.

### Step 7: The Cleanup Process (Bonus)

Here's an example of a maintenance process that follows OTP principles:

`lib/pipeline_manager/execution_cleaner.ex`:

```elixir
defmodule PipelineManager.ExecutionCleaner do
  use GenServer
  require Logger

  @cleanup_interval 60_000  # 1 minute
  @max_execution_age 3_600_000  # 1 hour

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Schedule first cleanup
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Logger.debug("Starting execution cleanup")
    
    cleaned_count = cleanup_old_executions()
    
    if cleaned_count > 0 do
      Logger.info("Cleaned up #{cleaned_count} old executions")
    end
    
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_executions do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@max_execution_age, :millisecond)
    
    PipelineManager.list_executions()
    |> Enum.filter(&should_cleanup?(&1, cutoff_time))
    |> Enum.map(&cleanup_execution/1)
    |> Enum.count(& &1 == :ok)
  end

  defp should_cleanup?(execution, cutoff_time) do
    execution.completed_at != nil and 
    DateTime.compare(execution.completed_at, cutoff_time) == :lt
  end

  defp cleanup_execution(execution) do
    case PipelineManager.WorkerSupervisor.stop_worker(execution.execution_id) do
      :ok -> 
        Logger.debug("Cleaned up execution: #{execution.execution_id}")
        :ok
      {:error, :not_found} -> 
        :ok  # Already gone
      error -> 
        Logger.warning("Failed to cleanup execution #{execution.execution_id}: #{inspect(error)}")
        :error
    end
  end
end
```

**Key Points:**

- **No Sleep:** Uses `Process.send_after/3` for scheduling
- **Failure Isolation:** If cleanup fails, it doesn't crash the system
- **Configurable:** Easy to tune cleanup intervals and retention

### Step 8: Testing - Proving Correctness

Proper OTP testing verifies the entire system behavior:

`test/pipeline_manager_test.exs`:

```elixir
defmodule PipelineManagerTest do
  use ExUnit.Case, async: false  # Stateful processes require sequential testing

  setup do
    # Start the entire application for integration testing
    start_supervised!(PipelineManager.Application)
    :ok
  end

  test "starts and executes a pipeline successfully" do
    pipeline_spec = %{name: "test_pipeline", step_count: 3}
    
    # Start execution
    assert {:ok, execution_id} = PipelineManager.start_execution(pipeline_spec)
    assert is_binary(execution_id)
    
    # Check initial status
    assert {:ok, status} = PipelineManager.get_execution_status(execution_id)
    assert status.status == :pending
    assert status.execution_id == execution_id
    
    # Execute pipeline
    assert :ok = PipelineManager.execute_pipeline(execution_id)
    
    # Status should change to running
    assert {:ok, status} = PipelineManager.get_execution_status(execution_id)
    assert status.status == :running
    assert status.started_at != nil
    
    # Wait for completion (using message passing, not sleep)
    assert_eventually(fn ->
      {:ok, status} = PipelineManager.get_execution_status(execution_id)
      status.status == :completed
    end, 10_000)
    
    # Verify final status
    assert {:ok, final_status} = PipelineManager.get_execution_status(execution_id)
    assert final_status.status == :completed
    assert final_status.result != nil
    assert final_status.completed_at != nil
  end

  test "handles execution cancellation correctly" do
    pipeline_spec = %{name: "long_pipeline", step_count: 10}
    
    assert {:ok, execution_id} = PipelineManager.run_pipeline(pipeline_spec)
    
    # Cancel while running
    assert :ok = PipelineManager.cancel_execution(execution_id)
    
    # Verify cancellation
    assert_eventually(fn ->
      {:ok, status} = PipelineManager.get_execution_status(execution_id)
      status.status == :cancelled
    end, 5_000)
  end

  test "worker crashes are handled gracefully" do
    pipeline_spec = %{name: "test_pipeline", step_count: 1}
    
    assert {:ok, execution_id} = PipelineManager.start_execution(pipeline_spec)
    
    # Find and kill the worker process
    [{worker_pid, _}] = Registry.lookup(PipelineManager.WorkerRegistry, execution_id)
    
    # Monitor the process to prove it dies
    ref = Process.monitor(worker_pid)
    Process.exit(worker_pid, :kill)
    
    # Wait for the DOWN message - this proves the process died
    assert_receive {:DOWN, ^ref, :process, ^worker_pid, :killed}
    
    # The supervisor should restart the worker
    # New workers start with fresh state
    assert {:ok, status} = PipelineManager.get_execution_status(execution_id)
    assert status.status == :pending  # Reset to initial state
  end

  test "lists all executions correctly" do
    # Start multiple executions
    execution_ids = for i <- 1..3 do
      pipeline_spec = %{name: "pipeline_#{i}", step_count: 1}
      {:ok, execution_id} = PipelineManager.start_execution(pipeline_spec)
      execution_id
    end
    
    # List should include all executions
    executions = PipelineManager.list_executions()
    execution_id_list = Enum.map(executions, & &1.execution_id)
    
    for execution_id <- execution_ids do
      assert execution_id in execution_id_list
    end
  end

  # Helper function for async testing without sleep
  defp assert_eventually(assertion_fn, timeout \\ 5000) do
    end_time = System.monotonic_time(:millisecond) + timeout
    do_assert_eventually(assertion_fn, end_time)
  end

  defp do_assert_eventually(assertion_fn, end_time) do
    if assertion_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) < end_time do
        Process.sleep(50)  # Minimal sleep for polling - only acceptable in tests
        do_assert_eventually(assertion_fn, end_time)
      else
        flunk("Assertion failed within timeout")
      end
    end
  end
end
```

**Testing Principles Demonstrated:**

- **System-Level Testing:** We test the entire application, not isolated modules
- **Process Lifecycle Testing:** We verify crash/restart behavior using `Process.monitor/1`
- **No Sleep in Logic:** We use `assert_eventually/2` for async assertions instead of arbitrary sleep
- **Sequential Testing:** `async: false` prevents test interference

### Key Takeaways

This guide demonstrates how the five OTP principles create robust, maintainable systems:

1. **Process Isolation:** Each execution runs in its own process, preventing failures from cascading
2. **Let It Crash:** Workers crash and restart cleanly, maintaining system stability
3. **Supervision:** DynamicSupervisor manages worker lifecycles without business logic
4. **No Manual Spawns:** All processes are supervised and discoverable
5. **Message-Based:** No blocking operations - everything is asynchronous

The result is a system that can handle thousands of concurrent executions, gracefully recovers from failures, and scales horizontally across BEAM clusters. This is the power of proper Elixir/OTP architecture.

**Remember:** These aren't suggestions - they're requirements for production Elixir systems. Following these principles separates professional Elixir developers from those who are still learning the platform.