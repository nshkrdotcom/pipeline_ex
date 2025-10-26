# Robustness & Reliability Guide

## Overview

While PipelineEx is designed as a **stateless library** (not a long-running supervised service), it includes comprehensive robustness features for production reliability.

## Architecture for Robustness

### What IS Supervised

```
Pipeline.Supervisor (one_for_one)
  └── Registry (Pipeline.MonitoringRegistry)
      └── Performance GenServers (temporary, per execution)
```

- **Monitoring processes** are supervised
- **Crash isolation** - monitoring crashes don't kill pipelines
- **Clean recovery** - monitoring restarts don't affect execution

### What is NOT Supervised (By Design)

- **Pipeline execution itself** - runs in caller's process
- **Step execution** - blocking, synchronous calls
- **Provider calls** - direct function calls, not GenServers

**Why?**
- Simpler error handling (no distributed state)
- Caller controls retry logic
- Clear failure boundaries
- Easier to integrate with existing supervision trees

## Robustness Features

### 1. Retry Mechanisms

#### Built-in: ClaudeRobust Step Type

```yaml
steps:
  - name: "resilient_analysis"
    type: "claude_robust"  # Special robust step type
    retry_config:
      max_retries: 3
      backoff_strategy: "exponential"  # exponential, linear, or fixed
      base_delay_ms: 1000
      retry_conditions:
        - "timeout"
        - "rate_limit"
        - "temporary_error"
        - "connection_error"
      fallback_action: "graceful_degradation"  # or "use_cached_response", "simplified_prompt", "emergency_response"
    claude_options:
      model: "haiku"
      max_turns: 3
    prompt:
      - type: "static"
        content: "Analyze this code..."
```

**Backoff strategies:**
- **Exponential**: `delay = base_delay * 2^attempt` (1s, 2s, 4s, 8s...)
- **Linear**: `delay = base_delay * (attempt + 1)` (1s, 2s, 3s, 4s...)
- **Fixed**: `delay = base_delay` (1s, 1s, 1s, 1s...)

**Fallback actions:**
- `graceful_degradation` - Returns synthetic response with error details
- `use_cached_response` - Use previous successful response (if available)
- `simplified_prompt` - Retry with simpler prompt
- `emergency_response` - Return minimal safe response

**Retry conditions:**
- `timeout` - Request timeout
- `rate_limit` - API rate limiting
- `temporary_error` - Transient errors
- `connection_error` - Network issues

#### Programmatic Retry Wrapper

```elixir
def execute_with_retry(workflow_path, max_attempts \\ 3) do
  Enum.reduce_while(1..max_attempts, {:error, "No attempts"}, fn attempt, _acc ->
    case Pipeline.run(workflow_path) do
      {:ok, results} ->
        {:halt, {:ok, results}}

      {:error, reason} when attempt < max_attempts ->
        Logger.warning("Attempt #{attempt} failed: #{reason}, retrying...")
        # Exponential backoff
        Process.sleep(:math.pow(2, attempt) * 1000 |> round())
        {:cont, {:error, reason}}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end)
end
```

### 2. Timeout Handling

#### Provider-Level Timeouts

**ClaudeProviderExtended** (with Task.await timeout):

```elixir
# Uses Task.await with configurable timeout
timeout_ms = options["timeout_ms"] || 300_000  # 5 minutes default

task = Task.async(fn -> ClaudeProvider.query(prompt, claude_options) end)

case Task.yield(task, timeout_ms) || Task.shutdown(task) do
  {:ok, result} -> result
  nil -> {:error, "Claude query timed out after #{timeout_ms}ms"}
end
```

**Configuration:**

```yaml
# In YAML
steps:
  - name: "timed_step"
    type: "claude"
    claude_options:
      timeout_ms: 120000  # 2 minutes
      model: "haiku"
```

```elixir
# Programmatic
{:ok, results} = Pipeline.execute(config,
  timeout_ms: 180_000  # 3 minutes
)
```

**Preset defaults:**

| Preset | Timeout |
|--------|---------|
| `development` | 5 minutes (300s) |
| `production` | 2 minutes (120s) |
| `analysis` | 3 minutes (180s) |
| `test` | 30 seconds |
| `chat` | 1 minute (60s) |

#### Pipeline-Level Timeouts

```elixir
# config/config.exs
config :pipeline,
  timeout_seconds: 300,  # 5 minutes for entire pipeline
  gemini_timeout_ms: 300_000  # 5 minutes for Gemini calls
```

**Resource Monitor** checks execution time:

```elixir
# Automatically checked during execution
usage = %{elapsed_ms: 310_000}  # 5 minutes 10 seconds
limits = %{timeout_seconds: 300}  # 5 minutes

ResourceMonitor.check_limits(usage, limits)
# => {:error, "Execution timeout exceeded: 310.0s > 300s"}
```

### 3. Circuit Breaker Pattern

While not built-in as a library feature, ClaudeRobust provides the foundation:

```elixir
defmodule MyApp.CircuitBreaker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{
      state: :closed,
      failures: 0,
      threshold: 5,
      timeout: 60_000  # 1 minute
    }, name: __MODULE__)
  end

  def call_pipeline(workflow_path) do
    case GenServer.call(__MODULE__, :check_state) do
      :open ->
        {:error, "Circuit breaker open"}

      :closed ->
        case Pipeline.run(workflow_path) do
          {:ok, results} ->
            GenServer.cast(__MODULE__, :success)
            {:ok, results}

          {:error, reason} ->
            GenServer.cast(__MODULE__, :failure)
            {:error, reason}
        end
    end
  end

  # GenServer callbacks implement circuit breaker logic...
end
```

### 4. Safety Guards

#### Recursion Limits

```elixir
# config/config.exs
config :pipeline,
  max_nesting_depth: 10,      # Max nested pipeline depth
  max_total_steps: 1000       # Max total steps across all nests
```

**Checked automatically:**

```elixir
# RecursionGuard.check_all_safety/3
case SafetyManager.check_safety(pipeline_id, context) do
  :ok ->
    # Execute pipeline

  {:error, "Maximum nesting depth exceeded: 11 > 10"} ->
    # Halt execution
end
```

#### Memory Limits

```elixir
# config/config.exs
config :pipeline,
  memory_limit_mb: 1024  # 1GB limit
```

**Monitored during execution:**

```elixir
# ResourceMonitor checks periodically
%{memory_usage_bytes: current_memory} = get_system_metrics()

if current_memory > memory_limit_bytes do
  {:error, "Memory limit exceeded"}
end
```

#### Execution Timeouts (Pipeline-wide)

```elixir
# Checked by ResourceMonitor
start_time = DateTime.utc_now()
elapsed_ms = DateTime.diff(DateTime.utc_now(), start_time, :millisecond)

if elapsed_ms > timeout_seconds * 1000 do
  {:error, "Execution timeout exceeded"}
end
```

### 5. Graceful Degradation

**Example from ClaudeRobust:**

```elixir
# If all retries fail, provide degraded response instead of complete failure
{:ok, %{
  success: true,
  text: """
  This step encountered an error but has gracefully degraded.

  Original error: Rate limit exceeded
  Fallback mode: Graceful degradation

  The system has maintained stability despite the error condition.
  """,
  degraded_mode: true,
  original_error: "Rate limit exceeded",
  cost: 0.0
}}
```

### 6. Error Recovery Statistics

ClaudeRobust tracks recovery metadata:

```elixir
{:ok, %{
  text: "Analysis complete...",
  robustness_metadata: %{
    attempt_number: 3,           # Succeeded on 3rd try
    total_attempts: 3,
    execution_time_ms: 5234,
    error_history: [
      %{attempt: 1, error: "timeout", execution_time_ms: 2100},
      %{attempt: 2, error: "rate_limit", execution_time_ms: 1500}
    ],
    retry_strategy_used: "exponential",
    recovery_successful: true    # Recovered after retries
  }
}}
```

## Production Patterns

### Pattern 1: Supervised Task Execution

```elixir
defmodule MyApp.PipelineWorker do
  use GenServer

  def start_link(workflow_path) do
    GenServer.start_link(__MODULE__, workflow_path)
  end

  def init(workflow_path) do
    # Execute pipeline in GenServer
    # Supervisor will restart on crash
    send(self(), :execute)
    {:ok, %{workflow_path: workflow_path, retries: 0}}
  end

  def handle_info(:execute, state) do
    case Pipeline.run(state.workflow_path) do
      {:ok, results} ->
        # Store results
        {:stop, :normal, state}

      {:error, _reason} when state.retries < 3 ->
        # Retry with backoff
        Process.send_after(self(), :execute, :math.pow(2, state.retries) * 1000)
        {:noreply, %{state | retries: state.retries + 1}}

      {:error, reason} ->
        # Max retries exceeded
        {:stop, {:error, reason}, state}
    end
  end
end

# Supervised
children = [
  {MyApp.PipelineWorker, "workflows/daily_analysis.yaml"}
]
Supervisor.start_link(children, strategy: :one_for_one)
```

### Pattern 2: Task.Supervisor for Parallel Robustness

```elixir
defmodule MyApp.BatchProcessor do
  def process_files(files) do
    {:ok, supervisor} = Task.Supervisor.start_link()

    tasks = Enum.map(files, fn file ->
      Task.Supervisor.async_nolink(supervisor, fn ->
        execute_with_retry(file, 3)
      end)
    end)

    # Wait for all, handle failures gracefully
    results = Task.yield_many(tasks, timeout: 300_000)

    Enum.map(results, fn {task, result} ->
      case result do
        {:ok, {:ok, data}} -> {:ok, data}
        {:ok, {:error, reason}} -> {:error, reason}
        nil ->
          # Timeout
          Task.shutdown(task, :brutal_kill)
          {:error, :timeout}
      end
    end)
  end

  defp execute_with_retry(file, attempts_left) when attempts_left > 0 do
    workflow = build_workflow(file)

    case Pipeline.execute(workflow) do
      {:ok, results} -> {:ok, results}
      {:error, _} ->
        Process.sleep(1000)
        execute_with_retry(file, attempts_left - 1)
    end
  end

  defp execute_with_retry(_file, 0), do: {:error, :max_retries}
end
```

### Pattern 3: Oban with Automatic Retries

```elixir
defmodule MyApp.PipelineJob do
  use Oban.Worker,
    queue: :pipelines,
    max_attempts: 5,  # Oban handles retries
    unique: [period: 60]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"workflow_path" => path}, attempt: attempt}) do
    # Oban automatically retries on {:error, reason}
    case Pipeline.run(path) do
      {:ok, results} ->
        # Store results
        MyApp.Results.save(results)
        :ok

      {:error, reason} when attempt < 5 ->
        # Will retry with exponential backoff
        {:error, reason}

      {:error, reason} ->
        # Max attempts, send alert
        MyApp.Alerts.send("Pipeline failed after 5 attempts: #{reason}")
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(10)
end
```

### Pattern 4: Health Checks & Monitoring

```elixir
defmodule MyApp.HealthCheck do
  def check_pipeline_health do
    checks = %{
      pipeline_configured: Pipeline.health_check(),
      recent_success_rate: check_recent_executions(),
      provider_availability: check_providers()
    }

    if all_healthy?(checks) do
      {:ok, checks}
    else
      {:error, checks}
    end
  end

  defp check_recent_executions do
    # Check last 10 pipeline runs
    recent = MyApp.Repo.recent_pipeline_runs(10)
    success_count = Enum.count(recent, & &1.status == :success)

    if success_count >= 7 do  # 70% success rate
      :healthy
    else
      {:degraded, "Success rate: #{success_count}/10"}
    end
  end

  defp check_providers do
    # Quick test with mock mode
    System.put_env("TEST_MODE", "mock")

    case Pipeline.run("test/fixtures/health_check.yaml") do
      {:ok, _} -> :healthy
      {:error, reason} -> {:unhealthy, reason}
    end
  end
end
```

## Configuration for Robustness

### Application Config

```elixir
# config/runtime.exs
import Config

config :pipeline,
  # Safety limits
  max_nesting_depth: System.get_env("PIPELINE_MAX_DEPTH", "10") |> String.to_integer(),
  max_total_steps: System.get_env("PIPELINE_MAX_STEPS", "1000") |> String.to_integer(),
  memory_limit_mb: System.get_env("PIPELINE_MEMORY_LIMIT", "1024") |> String.to_integer(),
  timeout_seconds: System.get_env("PIPELINE_TIMEOUT", "300") |> String.to_integer(),

  # Provider timeouts
  gemini_timeout_ms: System.get_env("GEMINI_TIMEOUT_MS", "300000") |> String.to_integer(),

  # Retry defaults
  claude_robust_max_retries: 3,
  claude_robust_base_delay_ms: 1000,

  # Cleanup
  cleanup_on_error: true

# Per-environment overrides
if config_env() == :prod do
  config :pipeline,
    timeout_seconds: 120,  # Stricter in prod
    memory_limit_mb: 512   # Lower limit in prod
end
```

### YAML Workflow Config

```yaml
workflow:
  name: "production_analysis"

  # Safety configuration
  safety_config:
    max_depth: 5
    timeout_seconds: 180
    memory_limit_mb: 512

  # Checkpoint for recovery
  checkpoint_enabled: true
  checkpoint_interval: 5

  steps:
    - name: "resilient_step"
      type: "claude_robust"
      retry_config:
        max_retries: 5
        backoff_strategy: "exponential"
        base_delay_ms: 2000
        retry_conditions: ["timeout", "rate_limit", "temporary_error"]
        fallback_action: "graceful_degradation"
```

## Monitoring & Observability

### Built-in Performance Monitoring

```elixir
# Automatically enabled
{:ok, results} = Pipeline.execute(config, enable_monitoring: true)

# Logs show:
# [info] 📊 Performance Summary:
# [info]    Duration: 4739ms
# [info]    Steps: 2/2
# [info]    Peak Memory: 82.4 MB
```

### Custom Telemetry

```elixir
defmodule MyApp.Telemetry do
  def handle_event([:pipeline, :execute, :start], measurements, metadata, _config) do
    # Log start
    MyApp.Metrics.increment("pipeline.executions.started")
  end

  def handle_event([:pipeline, :execute, :stop], measurements, metadata, _config) do
    # Log completion
    MyApp.Metrics.timing("pipeline.execution.duration", measurements.duration)
    MyApp.Metrics.increment("pipeline.executions.completed")
  end

  def handle_event([:pipeline, :execute, :exception], measurements, metadata, _config) do
    # Log failure
    MyApp.Metrics.increment("pipeline.executions.failed")
    MyApp.Alerts.send("Pipeline failed: #{metadata.reason}")
  end
end
```

## Best Practices

1. **Always use `claude_robust` for critical steps**
2. **Set appropriate timeouts** based on expected execution time
3. **Monitor success rates** - alert if < 95%
4. **Use checkpoints** for long-running pipelines
5. **Implement circuit breakers** for external dependencies
6. **Test failure modes** explicitly
7. **Set memory limits** to prevent OOM
8. **Use Oban/Task.Supervisor** for background work
9. **Health check** before production deployments
10. **Log robustness metadata** for analysis

## Testing Robustness

```elixir
defmodule MyApp.RobustnessTest do
  use ExUnit.Case

  test "handles provider timeout gracefully" do
    # Force timeout by using very short limit
    config = build_config(timeout_ms: 1)

    assert {:error, reason} = Pipeline.execute(config)
    assert reason =~ "timeout"
  end

  test "retries on failure" do
    # Use claude_robust with retry config
    config = build_robust_config(max_retries: 3)

    {:ok, results} = Pipeline.execute(config)

    # Check metadata shows recovery
    assert results["step"]["robustness_metadata"]["recovery_successful"]
  end

  test "respects memory limits" do
    config = build_config()

    {:ok, _results} = Pipeline.execute(config,
      memory_limit_mb: 2048  # Plenty of headroom
    )
  end
end
```

## Summary

| Feature | Implementation | Use Case |
|---------|----------------|----------|
| **Retries** | `claude_robust` step type | Transient API failures |
| **Timeouts** | Provider-level Task.await | Prevent hanging |
| **Circuit Breaker** | Custom wrapper | Protect downstream services |
| **Safety Guards** | RecursionGuard, ResourceMonitor | Prevent runaway execution |
| **Graceful Degradation** | Fallback actions | Maintain service |
| **Checkpoints** | File-based state | Resume on failure |
| **Monitoring** | Performance GenServer | Track metrics |
| **Supervision** | Caller's choice | Background jobs |

**Key Insight:** PipelineEx provides **robustness primitives** but delegates **supervision strategy** to the caller - giving you full control over how to handle failures in your application's context.
