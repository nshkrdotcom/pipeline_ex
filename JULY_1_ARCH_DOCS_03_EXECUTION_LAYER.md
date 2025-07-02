# JULY_1_ARCH_DOCS_03: Execution Layer Deep Dive

## Overview

The execution layer is the foundation of ElexirionDSP, built on Elixir/OTP principles. It provides the robust, concurrent, and fault-tolerant runtime that executes AI workflows with production-grade reliability.

## Core Design Principles

### 1. Everything is a Process
Following OTP conventions, every pipeline execution is a supervised process:

```elixir
# Each pipeline runs in its own process
{:ok, pipeline_pid} = DynamicSupervisor.start_child(
  Pipeline.Supervisor,
  {Pipeline.Worker, config}
)

# Failures are isolated and handled gracefully
Process.monitor(pipeline_pid)
```

### 2. Let It Crash Philosophy
Components are designed to fail fast and recover cleanly:

```elixir
defmodule Pipeline.StepExecutor do
  def execute_step(step, context) do
    try do
      case step.type do
        "claude" -> ClaudeProvider.execute(step, context)
        "gemini" -> GeminiProvider.execute(step, context)
        _ -> {:error, "Unknown step type"}
      end
    rescue
      error ->
        # Log the error and let supervisor handle restart
        Logger.error("Step execution failed: #{inspect(error)}")
        reraise error, __STACKTRACE__
    end
  end
end
```

### 3. Observable Behavior
Every operation emits telemetry for monitoring and optimization:

```elixir
# Telemetry events throughout execution
:telemetry.execute([:pipeline, :step, :start], %{}, %{
  pipeline_id: pipeline.id,
  step_name: step.name,
  step_type: step.type
})

:telemetry.execute([:pipeline, :step, :stop], %{
  duration: duration_ms,
  tokens_used: tokens,
  cost_usd: cost
}, metadata)
```

## Supervision Tree Architecture

```
                    Pipeline.Application
                           │
                           ▼
                 ┌─────────────────────┐
                 │ Pipeline.Supervisor │
                 │   (one_for_one)     │
                 └─────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │   Worker    │ │   Worker    │ │   Worker    │
    │ Supervisor  │ │ Supervisor  │ │ Supervisor  │
    │(rest_for_one│ │(rest_for_one│ │(rest_for_one│
    └─────────────┘ └─────────────┘ └─────────────┘
           │               │               │
    ┌──────┼──────┐ ┌──────┼──────┐ ┌──────┼──────┐
    ▼      ▼      ▼ ▼      ▼      ▼ ▼      ▼      ▼
 [Step] [Step] [Step] [Step] [Step] [Step] [Step] [Step]
```

### Supervisor Strategies

#### 1. Application Level: `one_for_one`
```elixir
defmodule Pipeline.Supervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  # Start a new pipeline execution
  def start_pipeline(config) do
    spec = {Pipeline.Worker, config}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
```

#### 2. Pipeline Level: `rest_for_one`
```elixir
defmodule Pipeline.Worker do
  use Supervisor
  
  def start_link(config) do
    Supervisor.start_link(__MODULE__, config)
  end
  
  def init(config) do
    children = [
      {Pipeline.Context, config},
      {Pipeline.StepSupervisor, config},
      {Pipeline.Monitor, config}
    ]
    
    # If Context crashes, restart everything
    # If StepSupervisor crashes, restart Monitor too
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
```

### Process Communication Patterns

#### 1. Pipeline Context (State Management)
```elixir
defmodule Pipeline.Context do
  use GenServer
  
  # Stores execution state and step results
  defstruct [
    :pipeline_id,
    :config,
    :current_step,
    :step_results,
    :variables,
    :start_time,
    :metadata
  ]
  
  def get_variable(context_pid, key) do
    GenServer.call(context_pid, {:get_variable, key})
  end
  
  def set_result(context_pid, step_name, result) do
    GenServer.cast(context_pid, {:set_result, step_name, result})
  end
end
```

#### 2. Step Execution (Task Management)
```elixir
defmodule Pipeline.StepSupervisor do
  use DynamicSupervisor
  
  def execute_step(step, context_pid) do
    task_spec = {
      Task,
      fn -> Pipeline.StepExecutor.execute(step, context_pid) end
    }
    
    {:ok, task_pid} = DynamicSupervisor.start_child(__MODULE__, task_spec)
    
    # Monitor the task with timeout
    case Task.await(task_pid, step.timeout || 300_000) do
      {:ok, result} -> 
        Pipeline.Context.set_result(context_pid, step.name, result)
        
      {:error, reason} ->
        handle_step_failure(step, reason, context_pid)
    end
  end
end
```

## Provider Architecture

### Multi-Provider Interface

```elixir
defmodule Pipeline.Provider do
  @callback execute(step :: map(), context :: pid()) :: 
    {:ok, any()} | {:error, binary()}
    
  @callback supports_feature?(feature :: atom()) :: boolean()
  
  @callback get_capabilities() :: [atom()]
end
```

### Claude Provider Implementation

```elixir
defmodule Pipeline.Providers.ClaudeProvider do
  @behaviour Pipeline.Provider
  
  use GenServer
  require Logger
  
  # Connection pooling for Claude API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def execute(step, context_pid) do
    # Get current execution context
    variables = Pipeline.Context.get_all_variables(context_pid)
    
    # Build prompt with template replacement
    prompt = build_prompt(step.prompt, variables)
    
    # Execute with retries and circuit breaker
    execute_with_resilience(prompt, step.claude_options || %{})
  end
  
  defp execute_with_resilience(prompt, options) do
    case execute_claude_sdk(prompt, options) do
      {:ok, response} -> 
        {:ok, format_response(response)}
        
      {:error, reason} when reason =~ "max_turns" ->
        # Trigger emergent fallback
        Logger.warn("Claude exceeded max_turns, using fallback")
        {:ok, create_emergent_fallback(prompt)}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Gemini Provider Implementation

```elixir
defmodule Pipeline.Providers.GeminiProvider do
  @behaviour Pipeline.Provider
  
  def execute(step, context_pid) do
    variables = Pipeline.Context.get_all_variables(context_pid)
    
    case step.type do
      "gemini_structured" ->
        execute_structured_output(step, variables)
        
      "gemini_function" ->
        execute_function_calling(step, variables)
        
      "gemini" ->
        execute_standard(step, variables)
    end
  end
  
  defp execute_structured_output(step, variables) do
    # Use InstructorLite for structured output
    schema = step.extraction_config.schema
    prompt = build_prompt(step.prompt, variables)
    
    case InstructorLite.generate(prompt, schema) do
      {:ok, structured_data} -> {:ok, structured_data}
      {:error, reason} -> {:error, "Gemini structured output failed: #{reason}"}
    end
  end
end
```

## Fault Tolerance Mechanisms

### 1. Circuit Breaker Pattern

```elixir
defmodule Pipeline.CircuitBreaker do
  use GenServer
  
  defstruct [
    :failure_threshold,
    :recovery_timeout,
    :failure_count,
    :state,  # :closed | :open | :half_open
    :last_failure_time
  ]
  
  def call(circuit_name, fun) when is_function(fun, 0) do
    case get_state(circuit_name) do
      :closed -> 
        execute_and_monitor(circuit_name, fun)
        
      :open ->
        {:error, "Circuit breaker open"}
        
      :half_open ->
        execute_recovery_attempt(circuit_name, fun)
    end
  end
  
  defp execute_and_monitor(circuit_name, fun) do
    try do
      result = fun.()
      record_success(circuit_name)
      {:ok, result}
    rescue
      error ->
        record_failure(circuit_name)
        {:error, Exception.message(error)}
    end
  end
end
```

### 2. Retry Logic with Exponential Backoff

```elixir
defmodule Pipeline.Retry do
  def with_retry(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay = Keyword.get(opts, :base_delay, 1000)
    max_delay = Keyword.get(opts, :max_delay, 30000)
    
    do_retry(fun, 1, max_attempts, base_delay, max_delay)
  end
  
  defp do_retry(fun, attempt, max_attempts, base_delay, max_delay) do
    case fun.() do
      {:ok, result} -> 
        {:ok, result}
        
      {:error, reason} when attempt < max_attempts ->
        delay = min(base_delay * :math.pow(2, attempt - 1), max_delay)
        :timer.sleep(trunc(delay))
        do_retry(fun, attempt + 1, max_attempts, base_delay, max_delay)
        
      {:error, reason} ->
        {:error, "Max retries exceeded: #{reason}"}
    end
  end
end
```

### 3. Bulkhead Pattern (Resource Isolation)

```elixir
defmodule Pipeline.Bulkhead do
  # Separate resource pools for different providers
  
  def start_link(_) do
    children = [
      # Claude API pool (limited connections)
      {Finch, 
        name: ClaudeHTTP,
        pools: %{
          "https://api.anthropic.com" => [size: 10, count: 1]
        }
      },
      
      # Gemini API pool (separate from Claude)
      {Finch,
        name: GeminiHTTP, 
        pools: %{
          "https://generativelanguage.googleapis.com" => [size: 15, count: 1]
        }
      }
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Concurrency Patterns

### 1. Parallel Step Execution

```yaml
# YAML configuration for parallel steps
steps:
  - name: parallel_analysis
    type: claude_batch
    parallel: true
    batch_size: 5
    max_parallel: 10
    items: "{{ source_files }}"
    step_template:
      type: claude
      prompt: "Analyze this file: {{ item }}"
```

```elixir
defmodule Pipeline.ParallelExecutor do
  def execute_parallel_steps(items, step_template, opts) do
    batch_size = opts[:batch_size] || 5
    max_parallel = opts[:max_parallel] || 10
    
    items
    |> Enum.chunk_every(batch_size)
    |> Task.async_stream(
      fn batch -> execute_batch(batch, step_template) end,
      max_concurrency: max_parallel,
      timeout: 300_000
    )
    |> Enum.reduce([], fn {:ok, results}, acc -> acc ++ results end)
  end
end
```

### 2. Pipeline Chaining

```elixir
defmodule Pipeline.Chain do
  def execute_chain(pipeline_configs, initial_input) do
    Enum.reduce_while(pipeline_configs, initial_input, fn config, input ->
      case Pipeline.Executor.execute(config, input) do
        {:ok, output} -> {:cont, output}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
```

### 3. Distributed Execution

```elixir
defmodule Pipeline.Distributed do
  # Execute pipelines across multiple nodes
  
  def execute_on_cluster(config, input) do
    available_nodes = [Node.self() | Node.list()]
    
    # Select node based on current load
    target_node = select_least_loaded_node(available_nodes)
    
    case :rpc.call(target_node, Pipeline.Executor, :execute, [config, input]) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> fallback_to_local_execution(config, input)
    end
  end
  
  defp select_least_loaded_node(nodes) do
    nodes
    |> Enum.map(fn node -> 
      load = :rpc.call(node, :cpu_sup, :avg1, [])
      {node, load}
    end)
    |> Enum.min_by(fn {_node, load} -> load end)
    |> elem(0)
  end
end
```

## Performance Optimization

### 1. Connection Pooling

```elixir
defmodule Pipeline.ConnectionPool do
  use GenServer
  
  # Maintain persistent connections to AI providers
  defstruct [
    :claude_pool,
    :gemini_pool, 
    :pool_size,
    :max_overflow
  ]
  
  def get_connection(provider) do
    GenServer.call(__MODULE__, {:get_connection, provider})
  end
  
  def return_connection(provider, conn) do
    GenServer.cast(__MODULE__, {:return_connection, provider, conn})
  end
end
```

### 2. Result Caching

```elixir
defmodule Pipeline.Cache do
  use GenServer
  
  # Cache expensive AI operations
  def get_cached_result(cache_key) do
    case :ets.lookup(:pipeline_cache, cache_key) do
      [{^cache_key, result, timestamp}] ->
        if fresh?(timestamp), do: {:ok, result}, else: :miss
      [] -> 
        :miss
    end
  end
  
  def cache_result(cache_key, result) do
    :ets.insert(:pipeline_cache, {cache_key, result, :os.system_time(:second)})
  end
  
  defp fresh?(timestamp) do
    now = :os.system_time(:second)
    (now - timestamp) < 3600  # 1 hour TTL
  end
end
```

### 3. Streaming Responses

```elixir
defmodule Pipeline.Streaming do
  # Stream large responses to avoid memory issues
  
  def execute_streaming_step(step, context_pid) do
    stream = ClaudeCodeSDK.query_stream(prompt, options)
    
    stream
    |> Stream.map(&process_chunk/1)
    |> Stream.each(fn chunk ->
      # Send intermediate results to context
      Pipeline.Context.append_chunk(context_pid, step.name, chunk)
    end)
    |> Stream.run()
  end
end
```

## Monitoring and Observability

### 1. Telemetry Integration

```elixir
defmodule Pipeline.Telemetry do
  def setup() do
    events = [
      [:pipeline, :execution, :start],
      [:pipeline, :execution, :stop],
      [:pipeline, :step, :start],
      [:pipeline, :step, :stop],
      [:pipeline, :provider, :request],
      [:pipeline, :provider, :response]
    ]
    
    :telemetry.attach_many(
      "pipeline-telemetry",
      events,
      &handle_event/4,
      %{}
    )
  end
  
  def handle_event([:pipeline, :step, :stop], measurements, metadata, _config) do
    # Record metrics
    :telemetry.execute([:prometheus, :counter, :inc], %{}, %{
      name: :pipeline_steps_total,
      labels: [step_type: metadata.step_type, status: metadata.status]
    })
    
    :telemetry.execute([:prometheus, :histogram, :observe], %{
      value: measurements.duration
    }, %{
      name: :pipeline_step_duration_seconds,
      labels: [step_type: metadata.step_type]
    })
  end
end
```

### 2. Health Checks

```elixir
defmodule Pipeline.HealthCheck do
  def system_health() do
    checks = [
      {:database, check_database()},
      {:claude_api, check_claude_api()},
      {:gemini_api, check_gemini_api()},
      {:memory, check_memory_usage()},
      {:process_count, check_process_count()}
    ]
    
    overall_status = if Enum.all?(checks, fn {_, status} -> status == :ok end),
      do: :healthy,
      else: :degraded
      
    %{
      status: overall_status,
      checks: checks,
      timestamp: DateTime.utc_now()
    }
  end
end
```

The execution layer provides the rock-solid foundation that enables ElexirionDSP to run complex AI workflows reliably in production. Its OTP-based architecture ensures that failures are contained, resources are managed efficiently, and the system can scale to handle concurrent workloads.