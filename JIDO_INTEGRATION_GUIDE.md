# Jido Integration Guide for Pipeline_ex

## Overview

This guide explains how to integrate Jido agent framework with pipeline_ex to create MABEAM (Multi-Agent BEAM) systems. Jido provides a complete agent framework with Actions, Agents, Sensors, and Workflows - we should leverage these built-in capabilities rather than reinventing them.

## Jido Core Capabilities

### 1. Actions - The Building Blocks
Jido Actions are discrete, composable units of work with validation, error handling, and compensation:

```elixir
defmodule Pipeline.Actions.ExecutePipelineYaml do
  use Jido.Action,
    name: "execute_pipeline_yaml",
    description: "Executes a pipeline_ex YAML workflow",
    schema: [
      pipeline_file: [type: :string, required: true],
      workspace_dir: [type: :string, default: "./workspace"],
      output_dir: [type: :string, default: "./outputs"],
      debug: [type: :boolean, default: false]
    ]

  @impl true
  def run(params, _context) do
    case Pipeline.run(params.pipeline_file, 
         workspace_dir: params.workspace_dir,
         output_dir: params.output_dir,
         debug: params.debug) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Pipeline execution failed: #{reason}"}
    end
  end
end
```

### 2. Agents - Stateful Process Orchestrators
Jido Agents are GenServers with built-in state management, instruction processing, and OTP integration:

```elixir
defmodule Pipeline.Agents.PipelineRunner do
  use Jido.Agent,
    name: "pipeline_runner",
    description: "Executes pipeline_ex workflows with state tracking",
    actions: [
      Pipeline.Actions.ExecutePipelineYaml,
      Pipeline.Actions.GetExecutionHistory,
      Pipeline.Actions.ClearHistory
    ],
    schema: [
      execution_history: [type: {:list, :map}, default: []],
      current_execution: [type: :map, default: nil],
      total_executions: [type: :integer, default: 0]
    ]

  # Agent automatically handles action routing, state validation, and error recovery
end
```

### 3. Workflows - Execution Engine
Jido Workflows provide robust execution with timeouts, retries, telemetry, and async support:

```elixir
# Execute with full Jido workflow capabilities
{:ok, result} = Jido.Workflow.run(
  Pipeline.Actions.ExecutePipelineYaml,
  %{pipeline_file: "analysis.yaml"},
  %{user_id: "123"},
  timeout: 30_000,
  max_retries: 3,
  telemetry: :full
)

# Async execution for long-running pipelines
async_ref = Jido.Workflow.run_async(
  Pipeline.Actions.ExecutePipelineYaml,
  %{pipeline_file: "large_analysis.yaml"}
)
{:ok, result} = Jido.Workflow.await(async_ref, 300_000)
```

### 4. Sensors - Event-Driven Monitoring
Jido Sensors provide real-time monitoring and event detection:

```elixir
defmodule Pipeline.Sensors.PipelineQueue do
  use Jido.Sensor,
    name: "pipeline_queue_monitor",
    description: "Monitors pipeline execution queue depth",
    schema: [
      check_interval: [type: :pos_integer, default: 5000],
      alert_threshold: [type: :integer, default: 10]
    ]

  @impl true
  def deliver_signal(state) do
    queue_depth = get_current_queue_depth()
    
    {:ok, Jido.Signal.new(%{
      source: "pipeline_queue_monitor",
      type: "queue.depth_check",
      data: %{
        queue_depth: queue_depth,
        alert: queue_depth > state.config.alert_threshold
      }
    })}
  end
end
```

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MABEAM System                            │
│                  (Jido + pipeline_ex)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  Jido Agents    │    │  Jido Sensors   │                │
│  │  - PipelineRunner│    │  - QueueMonitor │                │
│  │  - WorkDistributor│   │  - HealthCheck  │                │
│  │  - ResultCollector│   │  - Performance  │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           ▼                       ▼                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  Jido Actions   │    │  Jido Signals   │                │
│  │  - ExecutePipe  │    │  - Queue events │                │
│  │  - DistributeWork│   │  - Health alerts │                │
│  │  - CollectResults│   │  - Performance   │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │            Pipeline_ex Engine                           │ │
│  │    (Existing: Claude, Gemini, Genesis, etc.)           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Integration Principles

### 1. Leverage Jido's Built-in Capabilities
- **Don't reinvent**: Use Jido.Agent, Jido.Action, Jido.Sensor, Jido.Workflow
- **Extend, don't replace**: Build Actions that wrap pipeline_ex functionality
- **Use OTP patterns**: Jido already implements proper supervision, registries, etc.

### 2. Minimal Custom Code
- Create Actions that call `Pipeline.run/2` and other existing APIs
- Use Jido's built-in state management and validation
- Leverage Jido's testing utilities and patterns

### 3. Clean Separation of Concerns
- **Actions**: Individual operations (execute pipeline, collect results, etc.)
- **Agents**: Stateful orchestrators (queue management, result collection)
- **Sensors**: Event detection (queue monitoring, health checks)
- **Workflows**: Execution engine with retry, timeout, telemetry

## Required Jido Extensions

### 1. Pipeline-Specific Actions
Create Actions that integrate with existing pipeline_ex APIs:

- `ExecutePipelineYaml` - Run a YAML pipeline file
- `GeneratePipeline` - Use Genesis to create new pipelines
- `ValidatePipeline` - Validate pipeline configuration
- `GetPipelineHistory` - Retrieve execution history
- `MonitorExecution` - Track running pipeline progress

### 2. Management Agents
Use Jido Agents for orchestration:

- `PipelineManager` - Queue management and work distribution
- `ResultCollector` - Aggregate and store execution results
- `HealthMonitor` - System health and performance tracking

### 3. Monitoring Sensors
Use Jido Sensors for real-time monitoring:

- `QueueDepthSensor` - Monitor pipeline queue
- `ExecutionTimeSensor` - Track performance metrics
- `ErrorRateSensor` - Monitor failure rates
- `ResourceUsageSensor` - Track system resources

## Implementation Benefits

### 1. Minimal Code Required
- ~10 Action modules instead of full agent framework
- Use Jido's built-in GenServer, supervision, and registry patterns
- Leverage existing testing utilities and patterns

### 2. Production-Ready Features
- Built-in timeouts, retries, and error handling
- Comprehensive telemetry and monitoring
- Async execution for long-running operations
- Compensation logic for failure recovery

### 3. OTP Compliance
- Proper supervision trees (Jido handles this)
- Registry-based process discovery (built-in)
- "Let it crash" philosophy (Jido implements)
- No Process.sleep/1 (Jido uses message-based patterns)

## Quick Start Implementation

### Step 1: Add Jido Dependency
```elixir
# mix.exs
{:jido, "~> 1.1.0"}
```

### Step 2: Create Pipeline Action
```elixir
defmodule Pipeline.Actions.ExecuteYaml do
  use Jido.Action,
    name: "execute_yaml",
    schema: [pipeline_file: [type: :string, required: true]]

  def run(params, _context) do
    Pipeline.run(params.pipeline_file)
  end
end
```

### Step 3: Create Pipeline Agent
```elixir
defmodule Pipeline.Agents.Runner do
  use Jido.Agent,
    name: "pipeline_runner",
    actions: [Pipeline.Actions.ExecuteYaml]
end
```

### Step 4: Add to Supervision Tree
```elixir
# application.ex
children = [
  {Pipeline.Agents.Runner, id: "runner_1"}
]
```

### Step 5: Execute Pipelines
```elixir
# Send instruction to agent
{:ok, agent} = Pipeline.Agents.Runner.start_link(id: "runner_1")
{:ok, result} = Pipeline.Agents.Runner.cmd(agent, [
  %Jido.Instruction{
    action: "execute_yaml",
    params: %{pipeline_file: "analysis.yaml"}
  }
])
```

## Testing with Jido

Jido provides comprehensive testing utilities:

```elixir
defmodule Pipeline.Actions.ExecuteYamlTest do
  use ExUnit.Case
  use Jido.TestSupport  # Provides testing helpers

  test "executes pipeline successfully" do
    params = %{pipeline_file: "test/fixtures/simple.yaml"}
    assert {:ok, result} = Pipeline.Actions.ExecuteYaml.run(params, %{})
  end

  test "agent processes instructions" do
    {:ok, agent} = start_supervised({Pipeline.Agents.Runner, id: "test"})
    
    instruction = %Jido.Instruction{
      action: "execute_yaml", 
      params: %{pipeline_file: "test.yaml"}
    }
    
    assert {:ok, _result} = Pipeline.Agents.Runner.cmd(agent, [instruction])
  end
end
```

## Migration Path

### Phase 1: Basic Integration (1-2 days)
- Add Jido dependency
- Create 2-3 basic Actions wrapping Pipeline.run/2
- Create 1 Agent for pipeline execution
- Add to supervision tree

### Phase 2: Enhanced Features (3-5 days)
- Add Sensors for monitoring
- Implement async execution with Workflows
- Add queue management and distribution
- Create CLI interface using Jido agents

### Phase 3: Production Features (1-2 weeks)
- Comprehensive error handling and compensation
- Performance monitoring and alerting
- Multi-node distribution capabilities
- Advanced queue management and prioritization

This approach leverages Jido's mature, production-ready framework instead of building everything from scratch, resulting in cleaner, more maintainable code with fewer custom components.