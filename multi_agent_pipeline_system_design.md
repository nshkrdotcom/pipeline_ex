# MABEAM (Multi-Agent BEAM) Pipeline System Design

## Overview

This document outlines the design for a MABEAM system that leverages both **Jido** autonomous agents and **pipeline_ex** AI pipeline orchestration to create a distributed, intelligent workflow execution platform. The system combines Jido's agent framework with pipeline_ex's robust AI pipeline capabilities to create a powerful, fault-tolerant, and scalable multi-agent architecture.

## System Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                   MABEAM (Multi-Agent BEAM) Pipeline System               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │    Agent    │    │    Agent    │    │    Agent    │     │
│  │  Manager    │    │   Worker    │    │  Monitor    │     │
│  │   (Jido)    │    │   (Jido)    │    │   (Jido)    │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                   │                   │          │
│         └───────────────────┼───────────────────┘          │
│                             │                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Pipeline Engine (pipeline_ex)             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │ │
│  │  │   Claude    │  │   Gemini    │  │    Meta     │    │ │
│  │  │ Pipelines   │  │ Pipelines   │  │  Genesis    │    │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Persistent CLI                          │ │
│  │     (Command Interface & Interactive Dashboard)         │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Agent Definitions

### 1. Pipeline Manager Agent (`pipeline_manager`)

**Purpose**: Orchestrates pipeline execution across multiple worker agents.

```elixir
defmodule PipelineSystem.Agents.PipelineManager do
  use Jido.Agent,
    name: "pipeline_manager",
    description: "Manages pipeline execution across worker agents",
    actions: [
      PipelineSystem.Actions.SchedulePipeline,
      PipelineSystem.Actions.DistributeWork,
      PipelineSystem.Actions.MonitorProgress,
      PipelineSystem.Actions.HandleFailures,
      Jido.Actions.Directives.RegisterAction
    ],
    schema: [
      active_pipelines: [type: {:list, :map}, default: []],
      worker_pool: [type: {:list, :pid}, default: []],
      execution_stats: [type: :map, default: %{}],
      max_concurrent: [type: :pos_integer, default: 5]
    ]

  # Sensors for monitoring system health
  sensors: [
    {PipelineSystem.Sensors.WorkerHealth, interval: 5000},
    {PipelineSystem.Sensors.PipelineQueue, interval: 2000}
  ]
end
```

### 2. Pipeline Worker Agent (`pipeline_worker`)

**Purpose**: Executes individual pipeline_ex workflows with specialized capabilities.

```elixir
defmodule PipelineSystem.Agents.PipelineWorker do
  use Jido.Agent,
    name: "pipeline_worker",
    description: "Executes pipeline_ex workflows",
    actions: [
      PipelineSystem.Actions.ExecutePipeline,
      PipelineSystem.Actions.ReportProgress,
      PipelineSystem.Actions.HandleError,
      PipelineSystem.Actions.ProcessResult,
      Jido.Actions.Directives.RegisterAction
    ],
    schema: [
      worker_id: [type: :string, required: true],
      current_pipeline: [type: :map, default: nil],
      specialization: [type: :atom, default: :general], # :claude, :gemini, :data_processing, :code_gen
      status: [type: :atom, default: :idle], # :idle, :busy, :error
      execution_history: [type: {:list, :map}, default: []],
      performance_metrics: [type: :map, default: %{}]
    ]

  # Sensors for self-monitoring
  sensors: [
    {PipelineSystem.Sensors.ResourceUsage, interval: 10000},
    {PipelineSystem.Sensors.ExecutionMetrics, interval: 5000}
  ]
end
```

### 3. System Monitor Agent (`system_monitor`)

**Purpose**: Monitors overall system health, performance, and provides analytics.

```elixir
defmodule PipelineSystem.Agents.SystemMonitor do
  use Jido.Agent,
    name: "system_monitor",
    description: "Monitors system health and performance",
    actions: [
      PipelineSystem.Actions.CollectMetrics,
      PipelineSystem.Actions.GenerateReport,
      PipelineSystem.Actions.TriggerAlert,
      PipelineSystem.Actions.OptimizeSystem,
      Jido.Actions.Directives.RegisterAction
    ],
    schema: [
      metrics_buffer: [type: {:list, :map}, default: []],
      alert_thresholds: [type: :map, default: %{}],
      system_health: [type: :atom, default: :healthy],
      reports: [type: {:list, :map}, default: []]
    ]

  # Sensors for comprehensive monitoring
  sensors: [
    {PipelineSystem.Sensors.SystemHealth, interval: 3000},
    {PipelineSystem.Sensors.PerformanceMetrics, interval: 5000},
    {PipelineSystem.Sensors.ErrorPatterns, interval: 10000}
  ]
end
```

## Integration with pipeline_ex

### Pipeline Execution Actions

```elixir
defmodule PipelineSystem.Actions.ExecutePipeline do
  use Jido.Action,
    name: "execute_pipeline",
    description: "Executes a pipeline_ex workflow",
    schema: [
      pipeline_file: [type: :string, required: true],
      input_data: [type: :map, default: %{}],
      execution_mode: [type: :atom, default: :normal], # :normal, :test, :debug
      timeout: [type: :pos_integer, default: 300_000]
    ]

  @impl true
  def run(params, context) do
    worker_id = context.agent_state.worker_id
    
    with {:ok, pipeline_config} <- load_pipeline(params.pipeline_file),
         {:ok, execution_context} <- prepare_execution_context(params, context),
         {:ok, result} <- execute_pipeline_ex(pipeline_config, execution_context) do
      
      # Report success back to manager
      notify_manager(worker_id, :pipeline_completed, result)
      
      {:ok, %{
        status: :completed,
        result: result,
        execution_time: result.execution_time,
        worker_id: worker_id
      }}
    else
      {:error, reason} ->
        notify_manager(worker_id, :pipeline_failed, reason)
        {:error, "Pipeline execution failed: #{inspect(reason)}"}
    end
  end

  defp execute_pipeline_ex(config, context) do
    Pipeline.run(config, context.input_data, context.options)
  end
end
```

## Specialized Worker Types

### 1. Claude Specialist Workers
- Optimized for text generation, analysis, and code tasks
- Pre-loaded with Claude-specific pipeline templates
- Enhanced error handling for Claude API limitations

### 2. Gemini Specialist Workers  
- Optimized for structured data processing and function calling
- Specialized in multimodal tasks
- Built-in Gemini function libraries

### 3. Data Processing Workers
- Focus on data transformation pipelines
- High-throughput batch processing capabilities
- Integration with external data sources

### 4. Meta/Genesis Workers
- Specialized in pipeline generation and evolution
- Self-improving pipeline capabilities
- DNA-based pipeline breeding

## Persistent CLI Application

### Mix.exs Dependencies

```elixir
# Add to existing pipeline_ex dependencies
defp deps do
  [
    # Existing deps...
    {:jido, "~> 1.1.0"},
    {:table_rex, "~> 4.0"},      # For CLI tables
    {:progress_bar, "~> 3.0"},   # For progress indicators
    {:observer_cli, "~> 1.7"}    # For system monitoring
  ]
end
```

### CLI Architecture

```elixir
defmodule PipelineSystem.CLI do
  @moduledoc """
  Persistent CLI interface for the multi-agent pipeline system.
  Provides interactive dashboard and command interface.
  """

  use GenServer
  alias PipelineSystem.{AgentSupervisor, Dashboard}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start the agent supervision tree
    {:ok, supervisor_pid} = AgentSupervisor.start_link()
    
    # Initialize CLI state
    state = %{
      supervisor: supervisor_pid,
      agents: %{},
      dashboard_active: false,
      command_history: []
    }

    # Start interactive CLI loop
    spawn_link(&cli_loop/0)
    
    {:ok, state}
  end

  def cli_loop do
    IO.puts("\n🤖 MABEAM (Multi-Agent BEAM) Pipeline System")
    IO.puts("Type 'help' for available commands\n")
    
    Stream.repeatedly(fn -> 
      IO.gets("pipeline> ") |> String.trim() 
    end)
    |> Enum.reduce_while(nil, fn command, _acc ->
      case handle_command(command) do
        :quit -> {:halt, nil}
        _ -> {:cont, nil}
      end
    end)
  end

  defp handle_command("help"), do: show_help()
  defp handle_command("status"), do: show_system_status()
  defp handle_command("agents"), do: list_agents()
  defp handle_command("dashboard"), do: start_dashboard()
  defp handle_command("run " <> pipeline), do: run_pipeline(pipeline)
  defp handle_command("quit"), do: :quit
  defp handle_command(unknown), do: IO.puts("Unknown command: #{unknown}")
end
```

### Interactive Dashboard

```elixir
defmodule PipelineSystem.Dashboard do
  @moduledoc """
  Real-time dashboard for monitoring agent activity and pipeline execution.
  """

  def start do
    spawn(fn -> dashboard_loop() end)
  end

  defp dashboard_loop do
    clear_screen()
    render_header()
    render_agent_status()
    render_pipeline_queue()
    render_performance_metrics()
    render_recent_activity()
    
    :timer.sleep(1000)
    dashboard_loop()
  end

  defp render_agent_status do
    agents = PipelineSystem.AgentRegistry.list_agents()
    
    TableRex.quick_render!(
      agents,
      ["Agent", "Status", "Current Task", "Uptime"],
      "🤖 Agent Status"
    )
    |> IO.puts()
  end

  defp render_pipeline_queue do
    queue = PipelineSystem.PipelineQueue.get_status()
    
    IO.puts("\n📋 Pipeline Queue:")
    IO.puts("  Pending: #{queue.pending}")
    IO.puts("  Running: #{queue.running}")
    IO.puts("  Completed: #{queue.completed}")
    IO.puts("  Failed: #{queue.failed}")
  end
end
```

## System Commands

### CLI Commands

```bash
# Start the persistent CLI
mix pipeline.multi_agent

# Available commands in CLI:
pipeline> help           # Show all commands
pipeline> status         # System overview
pipeline> agents         # List all agents
pipeline> dashboard      # Start real-time dashboard
pipeline> run <file>     # Execute pipeline file
pipeline> worker add     # Add new worker agent
pipeline> worker remove <id>  # Remove worker agent
pipeline> metrics        # Show performance metrics
pipeline> logs           # Show recent logs
pipeline> quit           # Exit system
```

### Pipeline Distribution Examples

```yaml
# high_priority_analysis.yaml
name: "urgent_data_analysis"
priority: high
required_specialization: "data_processing"
timeout: 600
steps:
  - type: claude_extract
    # ... pipeline definition
```

```yaml
# code_generation_task.yaml  
name: "generate_api_docs"
priority: medium
required_specialization: "claude"
parallel_execution: true
worker_count: 3
steps:
  - type: claude_smart
    # ... pipeline definition
```

## Supervision Strategy

```elixir
defmodule PipelineSystem.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Core pipeline_ex application
      Pipeline.Application,
      
      # Agent supervision tree
      {PipelineSystem.AgentSupervisor, []},
      
      # System services
      {PipelineSystem.PipelineQueue, []},
      {PipelineSystem.AgentRegistry, []},
      {PipelineSystem.MetricsCollector, []},
      
      # CLI interface (optional, based on config)
      cli_child_spec()
    ]

    opts = [strategy: :one_for_one, name: PipelineSystem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp cli_child_spec do
    if Application.get_env(:pipeline_system, :start_cli, false) do
      {PipelineSystem.CLI, []}
    else
      []
    end
  end
end
```

## Configuration

```elixir
# config/config.exs
config :pipeline_system,
  # Agent configuration
  default_worker_count: 3,
  max_worker_count: 10,
  worker_specializations: [:claude, :gemini, :data_processing, :general],
  
  # CLI configuration
  start_cli: true,
  dashboard_refresh_rate: 1000,
  
  # Pipeline execution
  default_timeout: 300_000,
  max_concurrent_pipelines: 5,
  
  # Monitoring
  metrics_retention_days: 7,
  alert_thresholds: %{
    cpu_usage: 80,
    memory_usage: 85,
    error_rate: 0.05
  }

# Integration with existing pipeline_ex config
config :pipeline,
  # Existing pipeline_ex configuration
  providers: %{
    claude: [api_key: System.get_env("ANTHROPIC_API_KEY")],
    gemini: [api_key: System.get_env("GEMINI_API_KEY")]
  }
```

## Key Features

### 1. **Intelligent Work Distribution**
- Agents automatically route pipelines based on specialization
- Load balancing across available workers
- Fault tolerance with automatic retry and failover

### 2. **Real-time Monitoring**
- Live dashboard showing agent status and pipeline execution
- Performance metrics and system health monitoring
- Alert system for failures and performance issues

### 3. **Scalable Architecture**
- Dynamic worker scaling based on load
- Horizontal scaling across multiple nodes
- Efficient resource utilization

### 4. **Advanced Pipeline Capabilities**
- All existing pipeline_ex features (Claude, Gemini, Genesis, etc.)
- Enhanced with multi-agent distribution
- Parallel execution of compatible pipeline steps

### 5. **Persistent CLI Interface**
- Always-running command interface
- Interactive dashboard with real-time updates
- Command history and session persistence

## Usage Examples

### Starting the System

```elixir
# Start with default configuration
mix pipeline.multi_agent

# Start with custom worker count
mix pipeline.multi_agent --workers 5 --specializations claude,gemini,data

# Start in monitoring mode only
mix pipeline.multi_agent --monitor-only
```

### Executing Distributed Pipelines

```elixir
# Via CLI
pipeline> run examples/blog_generation.yaml

# Programmatically
PipelineSystem.execute_pipeline("examples/data_analysis.yaml", %{
  input_file: "data.csv",
  priority: :high,
  required_specialization: :data_processing
})
```

## Benefits

1. **Fault Tolerance**: Individual agent failures don't bring down the entire system
2. **Scalability**: Easy to add/remove agents based on workload
3. **Specialization**: Agents can be optimized for specific types of work
4. **Monitoring**: Real-time visibility into system performance
5. **Flexibility**: Supports both interactive and programmatic usage
6. **Integration**: Seamlessly extends existing pipeline_ex capabilities

## Future Enhancements

1. **Web Interface**: Browser-based dashboard alongside CLI
2. **Agent Learning**: Agents that improve based on execution history
3. **Cluster Support**: Multi-node distributed execution  
4. **Pipeline Marketplace**: Shared library of specialized pipelines
5. **Advanced Scheduling**: Complex pipeline dependencies and timing
6. **Cost Optimization**: Intelligent provider selection based on cost/performance

This design creates a powerful, distributed AI pipeline execution system that combines the best of both Jido's agent framework and pipeline_ex's AI orchestration capabilities.