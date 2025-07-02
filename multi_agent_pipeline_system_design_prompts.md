# MABEAM (MABEAM BEAM) Pipeline System Implementation Prompts

This file contains 100% self-contained prompts for implementing the MABEAM (MABEAM BEAM) pipeline system design. Each prompt includes all necessary documentation, file references, and implementation guidance.

---

## Prompt 1: Add Jido Dependency and Basic Integration Setup

### Context Files to Read First

**MANDATORY - Read these files to understand the current system:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles and patterns for all development
- `/home/home/p/g/n/pipeline_ex/README.md` - Complete API overview, library usage patterns, configuration
- `/home/home/p/g/n/pipeline_ex/mix.exs` - Current dependencies and project structure
- `/home/home/p/g/n/pipeline_ex/lib/pipeline.ex` - Main public API functions
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/application.ex` - Current OTP supervision tree
- `/home/home/p/g/n/pipeline_ex/ADVANCED_FEATURES.md` - All current pipeline capabilities
- `/home/home/p/g/n/pipeline_ex/LIBRARY_build.md` - Library integration patterns

**Jido Documentation Reference:**
- `/home/home/p/g/n/agentjido/jido/README.md` - Jido core concepts and installation
- `/home/home/p/g/n/agentjido/jido/guides/agents/overview.md` - Agent architecture
- `/home/home/p/g/n/agentjido/jido/guides/actions/overview.md` - Action system

### Task Description

Add Jido as a dependency to the pipeline_ex project and create the basic integration foundation for MABEAM (MABEAM BEAM) system. This includes updating mix.exs, creating the basic agent supervisor structure following OTP principles from ELIXIR_DEV_GUIDE.md, and establishing the integration points between pipeline_ex and Jido.

**Critical OTP Requirements from ELIXIR_DEV_GUIDE.md:**
- Use proper supervision trees - no manual spawns for long-lived processes
- Follow "Let It Crash" philosophy - no defensive try/rescue in workers
- Supervisors only supervise - no business logic in supervisors
- No Process.sleep/1 anywhere - use message-based async patterns
- All processes must be part of supervision tree

### Implementation Requirements

1. **Update Dependencies in mix.exs:**
   ```elixir
   # Add to existing deps in /home/home/p/g/n/pipeline_ex/mix.exs
   {:jido, "~> 1.1.0"},
   {:table_rex, "~> 4.0"},      # For CLI tables
   {:progress_bar, "~> 3.0"},   # For progress indicators
   {:observer_cli, "~> 1.7"}    # For system monitoring
   ```

2. **Create MABEAM Module Structure:**
   - `lib/pipeline/mabeam/` - MABEAM system modules
   - `lib/pipeline/mabeam/agents/` - Agent definitions
   - `lib/pipeline/mabeam/cli/` - CLI interface components

3. **Extend Application Supervision Tree:**
   Update `lib/pipeline/application.ex` to include agent supervision as an optional component based on configuration.

4. **Create Configuration Integration:**
   Add configuration options for MABEAM mode in the existing config system.

### Key Integration Points from Current System

**From lib/pipeline.ex analysis:**
- Main API: `Pipeline.load_workflow/1`, `Pipeline.execute/2`, `Pipeline.run/2`
- Health check: `Pipeline.health_check/0`
- **Integration Point**: Agents should use these same APIs to execute pipelines

**From lib/pipeline/application.ex analysis:**
- Current supervision: Just Registry for monitoring
- **Integration Point**: Add agent supervisor as optional child

**From README.md analysis:**
- Library usage pattern: `{:ok, config} = Pipeline.load_workflow("file.yaml")` then `Pipeline.execute(config, opts)`
- Configuration: workspace_dir, output_dir, debug options
- **Integration Point**: Agents need to use same configuration patterns

### Expected Deliverables

1. Updated `mix.exs` with Jido and CLI dependencies
2. Basic directory structure for agent components
3. Modified `lib/pipeline/application.ex` with optional agent supervision
4. Basic configuration module `lib/pipeline/mabeam/config.ex`
5. Integration test showing Jido agents can execute existing pipeline_ex workflows

### Success Criteria

- `mix deps.get` successfully installs Jido
- Application starts with and without MABEAM mode enabled
- Basic agent can load and execute a simple pipeline_ex workflow using the existing API
- No breaking changes to existing pipeline_ex functionality

---

## Prompt 2: Implement Core Agent Definitions

### Context Files to Read First

**MANDATORY - Read these files to understand integration points:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles and patterns for all development
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/executor.ex` - Core pipeline execution logic (730 lines)
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/config.ex` - Configuration management (449 lines)
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/result_manager.ex` - Result handling patterns
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/session_manager.ex` - Session management (325 lines)
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/checkpoint_manager.ex` - Checkpointing system

**Jido Documentation Reference:**
- `/home/home/p/g/n/agentjido/jido/guides/agents/overview.md` - Complete agent implementation guide
- `/home/home/p/g/n/agentjido/jido/guides/agents/stateful.md` - Stateful agent patterns
- `/home/home/p/g/n/agentjido/jido/guides/actions/overview.md` - Action implementation patterns

### Task Description

Implement the three core agent types for MABEAM: PipelineManager, PipelineWorker, and SystemMonitor. These agents must integrate with the existing pipeline_ex execution system while providing MABEAM coordination capabilities, following OTP principles from ELIXIR_DEV_GUIDE.md.

**Critical OTP Requirements from ELIXIR_DEV_GUIDE.md:**
- All agents must be GenServers under proper supervision
- Use proper supervision strategies (:one_for_one, :one_for_all, :rest_for_one)
- No defensive try/rescue in worker processes - let them crash and restart
- Use Registry for process discovery instead of process names
- All state must be isolated within processes

### Implementation Requirements

1. **Pipeline Manager Agent** (`lib/pipeline/mabeam/agents/pipeline_manager.ex`):
   - Manages pipeline execution queue
   - Distributes work to available workers
   - Tracks execution status and metrics
   - Handles worker failures and redistribution

2. **Pipeline Worker Agent** (`lib/pipeline/mabeam/agents/pipeline_worker.ex`):
   - Executes individual pipeline_ex workflows
   - Supports specialization (claude, gemini, data_processing, general)
   - Reports progress back to manager
   - Maintains execution history and performance metrics

3. **System Monitor Agent** (`lib/pipeline/mabeam/agents/system_monitor.ex`):
   - Collects system health metrics
   - Monitors agent performance
   - Generates alerts for issues
   - Provides system analytics

### Key Integration Requirements

**Executor Integration:**
From `lib/pipeline/executor.ex`:
- Pipeline execution: `execute_workflow(config, context)`
- Context management: workspace_dir, output_dir, checkpoint handling
- **Agent Integration**: Workers must use `Pipeline.Executor.execute_workflow/2` directly

**Configuration Integration:**
From `lib/pipeline/config.ex`:
- YAML loading: `load_and_validate/1`
- Provider configuration validation
- **Agent Integration**: Agents must validate pipeline configs before execution

**Session Management Integration:**
From `lib/pipeline/session_manager.ex`:
- Session persistence for claude_session steps
- **Agent Integration**: Workers need session coordination for multi-step pipelines

### Agent Schema Definitions

```elixir
# Pipeline Manager Schema
schema: [
  active_pipelines: [type: {:list, :map}, default: []],
  worker_pool: [type: {:list, :pid}, default: []],
  execution_stats: [type: :map, default: %{}],
  max_concurrent: [type: :pos_integer, default: 5],
  queue: [type: {:list, :map}, default: []]
]

# Pipeline Worker Schema  
schema: [
  worker_id: [type: :string, required: true],
  current_pipeline: [type: :map, default: nil],
  specialization: [type: :atom, default: :general],
  status: [type: :atom, default: :idle],
  execution_history: [type: {:list, :map}, default: []],
  performance_metrics: [type: :map, default: %{}]
]

# System Monitor Schema
schema: [
  metrics_buffer: [type: {:list, :map}, default: []],
  alert_thresholds: [type: :map, default: %{}],
  system_health: [type: :atom, default: :healthy],
  reports: [type: {:list, :map}, default: []]
]
```

### Action Implementation Pattern

Based on Jido actions, each agent needs these actions:

**Pipeline Manager Actions:**
- `SchedulePipeline` - Queue new pipeline for execution
- `DistributeWork` - Assign pipeline to available worker
- `MonitorProgress` - Track execution status
- `HandleFailures` - Manage worker failures

**Pipeline Worker Actions:**
- `ExecutePipeline` - Run pipeline_ex workflow using existing executor
- `ReportProgress` - Send status updates to manager
- `HandleError` - Process execution failures
- `ProcessResult` - Handle successful completions

### Expected Deliverables

1. Three agent modules in `lib/pipeline/mabeam/agents/`
2. Action modules in `lib/pipeline/mabeam/actions/`
3. Agent supervisor in `lib/pipeline/mabeam/agents/supervisor.ex`
4. Integration tests showing agents can execute existing pipeline workflows
5. Documentation showing how agents use existing pipeline_ex APIs

### Success Criteria

- All three agents start successfully under supervision
- Worker agents can execute existing YAML pipeline files using Pipeline.Executor
- Manager can distribute work to multiple workers
- System monitor collects basic metrics
- No modifications to existing pipeline_ex core modules required

---

## Prompt 3: Implement Pipeline Execution Actions and Integration

### Context Files to Read First

**MANDATORY - Read these files for execution integration:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles and patterns for all development
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/executor.ex` - Complete execution logic
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/step.ex` - Step coordination patterns
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/step/claude.ex` - Claude step implementation
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/step/gemini.ex` - Gemini step implementation
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/providers/ai_provider.ex` - Provider behavior
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/providers/claude_provider.ex` - Claude integration
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/providers/gemini_provider.ex` - Gemini integration

**Jido Documentation Reference:**
- `/home/home/p/g/n/agentjido/jido/guides/actions/overview.md` - Complete action implementation guide
- `/home/home/p/g/n/agentjido/jido/guides/actions/workflows.md` - Action execution patterns

### Task Description

Implement the core actions that allow Jido agents to execute pipeline_ex workflows in the MABEAM system. These actions must integrate seamlessly with the existing pipeline execution system while providing MABEAM coordination capabilities, following OTP principles from ELIXIR_DEV_GUIDE.md.

**Critical OTP Requirements from ELIXIR_DEV_GUIDE.md:**
- Actions must be pure functions without side effects in GenServer callbacks
- Use message passing for coordination between agents
- No blocking operations in GenServer handle_call/3 - delegate to separate processes
- Proper error handling with {:error, reason} returns, not exceptions
- Use Registry for dynamic process discovery and coordination

### Implementation Requirements

1. **ExecutePipeline Action** (`lib/pipeline/mabeam/actions/execute_pipeline.ex`):
   - Load pipeline YAML using existing Config module
   - Execute using existing Executor module
   - Handle all existing step types (claude, gemini, claude_smart, etc.)
   - Report progress and results back to manager agent

2. **Pipeline Distribution Actions**:
   - `SchedulePipeline` - Queue management with priority handling
   - `DistributeWork` - Worker selection based on specialization
   - `MonitorProgress` - Execution tracking and status updates

3. **Error Handling and Recovery Actions**:
   - `HandleError` - Process execution failures with retry logic
   - `CompensateFailure` - Rollback and recovery mechanisms

### Key Integration Points

**Executor Integration Pattern:**
From `lib/pipeline/executor.ex` analysis:
```elixir
# Current execution flow
def execute_workflow(config, context) do
  with {:ok, context} <- initialize_context(context, config),
       {:ok, results} <- execute_steps(config.workflow.steps, context) do
    {:ok, finalize_results(results, context)}
  end
end

# Agent integration must use same pattern:
def execute_pipeline_in_agent(config, agent_context) do
  pipeline_context = convert_agent_to_pipeline_context(agent_context)
  Pipeline.Executor.execute_workflow(config, pipeline_context)
end
```

**Step Type Support:**
From step analysis, agents must support all existing step types:
- Basic: `claude`, `gemini`, `parallel_claude`
- Enhanced: `claude_smart`, `claude_session`, `claude_extract`, `claude_batch`, `claude_robust`
- Utility: `loop`, `data_transform`, `file_ops`, `set_variable`, `codebase_query`

**Provider Integration:**
From provider analysis, agents must work with existing provider system:
- Mock mode support for testing
- Live mode for production
- Mixed mode for hybrid scenarios

### Action Schema Definitions

```elixir
# ExecutePipeline Action Schema
schema: [
  pipeline_file: [type: :string, required: true],
  input_data: [type: :map, default: %{}],
  execution_mode: [type: :atom, default: :normal],
  timeout: [type: :pos_integer, default: 300_000],
  workspace_dir: [type: :string],
  output_dir: [type: :string],
  specialization_required: [type: :atom, default: :any]
]

# SchedulePipeline Action Schema
schema: [
  pipeline_config: [type: :map, required: true],
  priority: [type: :atom, default: :normal],
  required_specialization: [type: :atom, default: :general],
  execution_options: [type: :map, default: %{}]
]
```

### Worker Specialization Logic

Based on existing step types, implement specialization matching:

```elixir
# Worker specialization determination
def determine_required_specialization(config) do
  step_types = extract_step_types(config.workflow.steps)
  
  cond do
    Enum.any?(step_types, &claude_step?/1) -> :claude
    Enum.any?(step_types, &gemini_step?/1) -> :gemini
    Enum.any?(step_types, &data_processing_step?/1) -> :data_processing
    true -> :general
  end
end

defp claude_step?(type) do
  type in ["claude", "claude_smart", "claude_session", "claude_extract", "claude_batch", "claude_robust", "parallel_claude"]
end
```

### Configuration Integration

Must work with existing configuration system from `lib/pipeline/config.ex`:

```elixir
# Agent actions must use existing config loading
def load_pipeline_for_agent(pipeline_file) do
  case Pipeline.Config.load_and_validate(pipeline_file) do
    {:ok, config} -> {:ok, config}
    {:error, reason} -> {:error, "Failed to load pipeline: #{reason}"}
  end
end
```

### Expected Deliverables

1. **Core Actions** in `lib/pipeline/mabeam/actions/`:
   - `execute_pipeline.ex` - Main pipeline execution action
   - `schedule_pipeline.ex` - Pipeline queuing
   - `distribute_work.ex` - Work distribution logic
   - `monitor_progress.ex` - Execution tracking
   - `handle_error.ex` - Error processing

2. **Integration Utilities** in `lib/pipeline/mabeam/`:
   - `context_converter.ex` - Convert between agent and pipeline contexts
   - `specialization_matcher.ex` - Match pipelines to worker types
   - `result_coordinator.ex` - Coordinate results across agents

3. **Test Coverage**:
   - Actions work with existing pipeline YAML files
   - All step types execute correctly through agents
   - Mock and live modes work through agent system

### Success Criteria

- Agent can execute any existing pipeline YAML file from examples/
- All existing step types (claude, gemini, claude_smart, etc.) work through agents
- Results are identical whether pipeline runs directly or through agent
- Worker specialization correctly matches pipeline requirements
- Error handling maintains existing pipeline error patterns

---

## Prompt 4: Implement System Monitoring and Sensors

### Context Files to Read First

**MANDATORY - Read these files for monitoring integration:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles and patterns for all development
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/monitoring/performance.ex` - Existing performance monitoring
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/monitoring/registry.ex` - Process monitoring registry
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/debug.ex` - Debug and logging patterns
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/result_stream.ex` - Result streaming patterns
- `/home/home/p/g/n/pipeline_ex/README.md` - Debug configuration (lines 610-625)

**Jido Documentation Reference:**
- `/home/home/p/g/n/agentjido/jido/guides/sensors/overview.md` - Complete sensor implementation guide
- `/home/home/p/g/n/agentjido/jido/guides/sensors/cron-heartbeat.md` - Built-in sensor examples

### Task Description

Implement comprehensive system monitoring using Jido sensors to track agent health, pipeline execution metrics, and system performance in MABEAM. This must integrate with existing pipeline_ex monitoring capabilities while providing MABEAM visibility, following OTP principles from ELIXIR_DEV_GUIDE.md.

**Critical OTP Requirements from ELIXIR_DEV_GUIDE.md:**
- Sensors must be GenServers under supervision, not standalone processes
- Use timer-based message sending instead of Process.sleep/1 for periodic tasks
- Monitoring data collection must be non-blocking and asynchronous
- Use Registry for sensor discovery and coordination
- Follow "Let It Crash" - if a sensor fails, supervisor restarts it

### Implementation Requirements

1. **System Health Sensors**:
   - Agent status monitoring (idle, busy, error, crashed)
   - Pipeline queue depth and processing rates
   - Resource usage tracking (memory, CPU)
   - Error pattern detection

2. **Performance Monitoring Sensors**:
   - Pipeline execution times by type and worker
   - Step-level performance metrics
   - Provider API latency and success rates
   - Cost tracking for AI API usage

3. **Integration with Existing Monitoring**:
   - Extend existing `Pipeline.Monitoring.Performance` module
   - Use existing `Pipeline.Monitoring.Registry` for process tracking
   - Integrate with existing debug output patterns

### Key Integration Points

**Existing Performance Monitoring:**
From `lib/pipeline/monitoring/performance.ex`:
- Current metrics: execution_time, step_count, token_usage
- **Sensor Integration**: Extend to include agent-specific metrics

**Debug Output Integration:**
From README.md debug configuration:
```bash
# Existing debug patterns
DEBUG=true elixir run_example.exs
VERBOSE=true elixir run_example.exs
PIPELINE_DEBUG=true mix pipeline.run example.yaml
```
**Sensor Integration**: Sensors should respect same debug levels

**Registry Integration:**
From `lib/pipeline/monitoring/registry.ex`:
- Process monitoring and lifecycle tracking
- **Sensor Integration**: Monitor agent processes in same registry

### Sensor Implementation Specifications

1. **Agent Health Sensor** (`lib/pipeline/mabeam/sensors/agent_health.ex`):
```elixir
defmodule Pipeline.Sensors.AgentHealth do
  use Jido.Sensor,
    name: "agent_health",
    description: "Monitors agent status and availability",
    category: :monitoring,
    schema: [
      check_interval: [type: :pos_integer, default: 5000],
      health_threshold: [type: :float, default: 0.8]
    ]

  def deliver_signal(state) do
    agents = get_all_agents()
    health_data = collect_health_metrics(agents)
    
    {:ok, Jido.Signal.new(%{
      source: "agent_health_sensor",
      type: "agent.health_report",
      data: health_data
    })}
  end
end
```

2. **Pipeline Queue Sensor** (`lib/pipeline/mabeam/sensors/pipeline_queue.ex`):
```elixir
schema: [
  queue_threshold: [type: :pos_integer, default: 10],
  processing_rate_window: [type: :pos_integer, default: 60_000]
]
```

3. **Performance Metrics Sensor** (`lib/pipeline/mabeam/sensors/performance_metrics.ex`):
```elixir
schema: [
  metrics_window: [type: :pos_integer, default: 300_000],
  cost_tracking_enabled: [type: :boolean, default: true]
]
```

### Metrics Collection Integration

**Extend Existing Performance Module:**
```elixir
# In lib/pipeline/monitoring/performance.ex
defmodule Pipeline.Monitoring.Performance do
  # Existing functions...
  
  # New agent-specific metrics
  def collect_agent_metrics(agent_pid) do
    %{
      agent_id: get_agent_id(agent_pid),
      current_pipeline: get_current_pipeline(agent_pid),
      execution_count: get_execution_count(agent_pid),
      average_execution_time: get_average_execution_time(agent_pid),
      error_rate: get_error_rate(agent_pid),
      specialization: get_specialization(agent_pid)
    }
  end
end
```

### Dashboard Data Integration

**Real-time Metrics for CLI Dashboard:**
```elixir
# Sensor data structure for dashboard consumption
%{
  timestamp: DateTime.utc_now(),
  system_health: :healthy | :degraded | :critical,
  agents: [
    %{
      id: "worker_1",
      status: :busy,
      current_pipeline: "data_analysis.yaml",
      uptime: 3600,
      executions_completed: 45,
      error_rate: 0.02
    }
  ],
  queue: %{
    pending: 3,
    running: 2,
    completed_today: 156,
    failed_today: 4
  },
  performance: %{
    average_execution_time: 45.2,
    throughput_per_hour: 34,
    api_costs_today: "$12.45"
  }
}
```

### Alert and Notification System

**Alert Thresholds Configuration:**
```elixir
# Integration with existing config system
config :pipeline, :multi_agent,
  monitoring: %{
    alert_thresholds: %{
      queue_depth: 20,
      agent_error_rate: 0.1,
      average_execution_time: 300_000,  # 5 minutes
      system_health_degraded: 0.7
    },
    notification_channels: [:log, :signal]  # Future: :email, :slack
  }
```

### Integration with Existing Debug Output

**Extend Debug Patterns:**
```elixir
# Respect existing debug configuration
defp maybe_log_debug(message, context) do
  if Application.get_env(:pipeline, :debug, false) or
     System.get_env("PIPELINE_DEBUG") == "true" do
    Logger.info("[AGENT_DEBUG] #{message}", context)
  end
end
```

### Expected Deliverables

1. **Sensor Modules** in `lib/pipeline/mabeam/sensors/`:
   - `agent_health.ex` - Agent status monitoring
   - `pipeline_queue.ex` - Queue depth and processing rates
   - `performance_metrics.ex` - Execution performance tracking
   - `error_patterns.ex` - Error detection and analysis

2. **Monitoring Extensions** in `lib/pipeline/monitoring/`:
   - Extend `performance.ex` with agent-specific metrics
   - Add `multi_agent_metrics.ex` for cross-agent analytics

3. **Integration Utilities**:
   - `sensor_coordinator.ex` - Coordinate sensor data collection
   - `alert_manager.ex` - Handle threshold violations and notifications

4. **Test Coverage**:
   - Sensors collect accurate data during pipeline execution
   - Metrics integrate with existing monitoring system
   - Debug output includes agent-specific information

### Success Criteria

- Sensors accurately track agent health and performance
- Metrics collection doesn't impact pipeline execution performance
- Dashboard receives real-time data for display
- Alert system detects and reports threshold violations
- Integration maintains compatibility with existing debug/monitoring patterns
- All sensor data is available for CLI dashboard display

---

## Prompt 5: Implement Persistent CLI Interface and Dashboard

### Context Files to Read First

**MANDATORY - Read these files for CLI integration:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles and patterns for all development
- `/home/home/p/g/n/pipeline_ex/lib/mix/tasks/pipeline.run.ex` - Existing CLI patterns
- `/home/home/p/g/n/pipeline_ex/lib/mix/tasks/pipeline.generate.ex` - CLI argument handling
- `/home/home/p/g/n/pipeline_ex/lib/mix/tasks/showcase.ex` - Interactive CLI examples
- `/home/home/p/g/n/pipeline_ex/README.md` - CLI usage patterns (lines 180-260)
- `/home/home/p/g/n/pipeline_ex/ADVANCED_FEATURES.md` - All available pipeline features for CLI

**Environment Configuration:**
- `/home/home/p/g/n/pipeline_ex/README.md` lines 540-560 - Environment variables
- Debug patterns from README.md lines 610-625

### Task Description

Implement a persistent CLI interface with real-time dashboard for the MABEAM pipeline system. This must integrate with existing Mix tasks while providing a persistent, interactive interface for managing the MABEAM system, following OTP principles from ELIXIR_DEV_GUIDE.md.

**Critical OTP Requirements from ELIXIR_DEV_GUIDE.md:**
- CLI application must be a proper OTP Application with supervision tree
- No Process.sleep/1 for dashboard updates - use timer-based messages
- Interactive input handling must be in separate process to avoid blocking
- Use GenServer for CLI state management under supervision
- All long-running processes must be properly supervised

### Implementation Requirements

1. **Persistent CLI Application** (`lib/pipeline/mabeam/cli/application.ex`):
   - Always-running command interface
   - Interactive command processing
   - Command history and tab completion
   - Graceful shutdown handling

2. **Real-time Dashboard** (`lib/pipeline/mabeam/cli/dashboard.ex`):
   - Live agent status display
   - Pipeline execution monitoring
   - Performance metrics visualization
   - System health indicators

3. **Command Processing System** (`lib/pipeline/mabeam/cli/commands/`):
   - Modular command structure
   - Help system integration
   - Error handling and user feedback

### Key Integration Points

**Existing Mix Task Patterns:**
From `lib/mix/tasks/pipeline.run.ex`:
```elixir
# Current CLI pattern
def run(args) do
  {opts, [file], _} = OptionParser.parse(args, switches: [
    live: :boolean,
    debug: :boolean,
    output_dir: :string,
    workspace_dir: :string
  ])
  
  # Agent CLI must support same options
end
```

**Configuration Integration:**
From README.md environment variables:
```bash
export PIPELINE_WORKSPACE_DIR="./workspace"
export PIPELINE_OUTPUT_DIR="./outputs"
export PIPELINE_DEBUG="true"
export TEST_MODE="live"
```

**Debug Output Integration:**
From existing debug patterns:
- Respect `PIPELINE_DEBUG` environment variable
- Use same logging patterns as existing CLI tools
- Maintain compatibility with existing verbose output

### CLI Architecture Implementation

1. **Main CLI Module** (`lib/pipeline/mabeam/cli.ex`):
```elixir
defmodule Pipeline.CLI do
  use GenServer
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    # Start agent supervision tree
    {:ok, supervisor_pid} = Pipeline.MABEAM.Agents.Supervisor.start_link()
    
    # Initialize CLI state with existing config patterns
    state = %{
      supervisor: supervisor_pid,
      agents: %{},
      dashboard_active: false,
      config: load_cli_config(opts)
    }
    
    # Start interactive loop
    spawn_link(&cli_loop/0)
    {:ok, state}
  end

  defp load_cli_config(opts) do
    # Use existing config patterns from Pipeline.Config
    %{
      workspace_dir: opts[:workspace_dir] || System.get_env("PIPELINE_WORKSPACE_DIR", "./workspace"),
      output_dir: opts[:output_dir] || System.get_env("PIPELINE_OUTPUT_DIR", "./outputs"),
      debug: opts[:debug] || System.get_env("PIPELINE_DEBUG") == "true",
      test_mode: System.get_env("TEST_MODE", "mock")
    }
  end
end
```

2. **Command Processing** (`lib/pipeline/mabeam/cli/commands/`):
```elixir
# Base command behavior
defmodule Pipeline.CLI.Command do
  @callback run(args :: list(String.t()), state :: map()) :: 
    {:ok, String.t(), map()} | {:error, String.t()}
  @callback help() :: String.t()
end

# Run command - integrate with existing execution
defmodule Pipeline.CLI.Commands.Run do
  @behaviour Pipeline.CLI.Command
  
  def run([pipeline_file | args], state) do
    # Use existing Pipeline.run/2 function
    case Pipeline.run(pipeline_file, 
      workspace_dir: state.config.workspace_dir,
      output_dir: state.config.output_dir,
      debug: state.config.debug) do
      {:ok, results} -> 
        {:ok, format_results(results), state}
      {:error, reason} -> 
        {:error, "Pipeline failed: #{reason}"}
    end
  end
end
```

### Dashboard Implementation

**Real-time Dashboard** (`lib/pipeline/mabeam/cli/dashboard.ex`):
```elixir
defmodule Pipeline.CLI.Dashboard do
  # Integration with TableRex for consistent table formatting
  def render_agent_status(agents) do
    agents
    |> Enum.map(&format_agent_row/1)
    |> TableRex.quick_render!(
      ["Agent ID", "Status", "Current Task", "Uptime", "Completed"],
      "🤖 Agent Status"
    )
  end

  def render_pipeline_queue(queue_stats) do
    [
      "📋 Pipeline Queue:",
      "  Pending: #{queue_stats.pending}",
      "  Running: #{queue_stats.running}",
      "  Completed: #{queue_stats.completed}",
      "  Failed: #{queue_stats.failed}"
    ]
    |> Enum.join("\n")
  end

  def render_performance_metrics(metrics) do
    # Use ProgressBar for throughput indicators
    throughput_bar = ProgressBar.render(
      metrics.current_throughput, 
      metrics.max_throughput,
      bar_width: 40
    )
    
    [
      "📊 Performance Metrics:",
      "  Throughput: #{throughput_bar}",
      "  Avg Execution Time: #{metrics.avg_execution_time}ms",
      "  Success Rate: #{metrics.success_rate}%",
      "  API Costs Today: $#{metrics.api_costs}"
    ]
    |> Enum.join("\n")
  end
end
```

### Mix Task Integration

**New Mix Task** (`lib/mix/tasks/pipeline.mabeam.ex`):
```elixir
defmodule Mix.Tasks.Pipeline.Mabeam do
  use Mix.Task
  
  @shortdoc "Start persistent MABEAM pipeline system"
  
  @moduledoc """
  Start the persistent MABEAM pipeline system with CLI interface.
  
  ## Examples
  
      # Start with default configuration
      mix pipeline.mabeam
      
      # Start with custom worker count
      mix pipeline.mabeam --workers 5
      
      # Start in monitoring mode only
      mix pipeline.mabeam --monitor-only
      
  ## Options
  
    * `--workers` - Number of worker agents to start (default: 3)
    * `--specializations` - Comma-separated list of specializations
    * `--workspace-dir` - Custom workspace directory
    * `--output-dir` - Custom output directory
    * `--monitor-only` - Start only monitoring, no workers
    * `--debug` - Enable debug output
    * `--live` - Use live AI providers (default: mock)
  """
  
  def run(args) do
    # Parse options using same patterns as existing tasks
    {opts, [], _} = OptionParser.parse(args, switches: [
      workers: :integer,
      specializations: :string,
      workspace_dir: :string,
      output_dir: :string,
      monitor_only: :boolean,
      debug: :boolean,
      live: :boolean
    ])
    
    # Start the CLI application
    {:ok, _pid} = Pipeline.CLI.start_link(opts)
    
    # Keep the task running
    Process.sleep(:infinity)
  end
end
```

### Command System Integration

**Available Commands:**
```elixir
# Commands that integrate with existing functionality
commands = %{
  "help" => Pipeline.CLI.Commands.Help,
  "status" => Pipeline.CLI.Commands.Status,
  "agents" => Pipeline.CLI.Commands.Agents,
  "run" => Pipeline.CLI.Commands.Run,           # Use Pipeline.run/2
  "dashboard" => Pipeline.CLI.Commands.Dashboard,
  "workers" => Pipeline.CLI.Commands.Workers,
  "metrics" => Pipeline.CLI.Commands.Metrics,
  "logs" => Pipeline.CLI.Commands.Logs,
  "config" => Pipeline.CLI.Commands.Config,     # Show current config
  "quit" => Pipeline.CLI.Commands.Quit
}
```

### Configuration Integration

**CLI Configuration** (`lib/pipeline/mabeam/cli/config.ex`):
```elixir
defmodule Pipeline.CLI.Config do
  # Integrate with existing Pipeline.Config patterns
  
  def load_cli_config(opts \\ []) do
    base_config = %{
      # Use existing environment variable patterns
      workspace_dir: get_config_value(:workspace_dir, opts, "./workspace"),
      output_dir: get_config_value(:output_dir, opts, "./outputs"),
      checkpoint_dir: get_config_value(:checkpoint_dir, opts, "./checkpoints"),
      debug: get_config_value(:debug, opts, false),
      test_mode: System.get_env("TEST_MODE", "mock"),
      
      # Multi-agent specific configuration
      default_worker_count: 3,
      max_worker_count: 10,
      worker_specializations: [:claude, :gemini, :data_processing, :general],
      dashboard_refresh_rate: 1000,
      max_concurrent_pipelines: 5
    }
    
    merge_application_config(base_config)
  end
  
  defp get_config_value(key, opts, default) do
    env_key = "PIPELINE_#{String.upcase(to_string(key))}"
    opts[key] || System.get_env(env_key, default)
  end
end
```

### Expected Deliverables

1. **CLI Core** in `lib/pipeline/mabeam/cli/`:
   - `application.ex` - Main CLI application
   - `dashboard.ex` - Real-time dashboard
   - `config.ex` - CLI configuration management
   - `command_processor.ex` - Command parsing and routing

2. **Commands** in `lib/pipeline/mabeam/cli/commands/`:
   - Individual command modules for each CLI function
   - Help system with integrated documentation
   - Error handling and user feedback

3. **Mix Task Integration**:
   - `lib/mix/tasks/pipeline.mabeam.ex` - Main CLI launcher
   - Integration with existing task patterns and options

4. **Configuration and Documentation**:
   - CLI usage documentation
   - Integration examples showing CLI controlling pipeline execution

### Success Criteria

- CLI starts successfully and shows interactive prompt
- Dashboard displays real-time agent and pipeline status
- Commands integrate with existing Pipeline.run/2 and other APIs
- Configuration system works with existing environment variables
- Mix task follows same patterns as existing pipeline tasks
- CLI can execute any existing pipeline YAML file through agents
- Real-time updates show agent activity and pipeline progress
- Graceful shutdown and error handling throughout

---

## Prompt 6: Create Agent Supervisor and System Integration

### Context Files to Read First

**MANDATORY - Read these files for supervision integration:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles and patterns for all development
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/application.ex` - Current OTP supervision tree
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/monitoring/registry.ex` - Process monitoring patterns
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/session_manager.ex` - Session supervision patterns (325 lines)
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/test/mocks.ex` - Mock implementations for testing

**Jido Documentation Reference:**
- `/home/home/p/g/n/agentjido/jido/guides/agents/overview.md` - Agent supervision patterns
- `/home/home/p/g/n/agentjido/jido/guides/agents/child-processes.md` - Child process management

### Task Description

Implement the agent supervision tree that integrates with the existing pipeline_ex OTP application for MABEAM. This supervisor must manage agent lifecycles, handle failures gracefully, and coordinate with the existing monitoring and session management systems, following OTP principles from ELIXIR_DEV_GUIDE.md.

**Critical OTP Requirements from ELIXIR_DEV_GUIDE.md:**
- Supervision tree must follow proper OTP patterns with clear restart strategies
- Use DynamicSupervisor for worker agents, Supervisor for fixed agents
- Registry must be used for process discovery, not manual process tracking
- Supervisors must contain NO business logic - only child specifications
- Proper shutdown ordering and cleanup in supervision tree

### Implementation Requirements

1. **Agent Supervisor Tree** (`lib/pipeline/mabeam/agents/supervisor.ex`):
   - Dynamic supervisor for worker agents
   - Fixed supervisor for manager and monitor agents
   - Integration with existing Pipeline.Application supervision tree

2. **Agent Registry** (`lib/pipeline/mabeam/agents/registry.ex`):
   - Agent discovery and lookup
   - Integration with existing Pipeline.Monitoring.Registry
   - Health checking and status tracking

3. **Lifecycle Management**:
   - Graceful agent startup and shutdown
   - Failure recovery and restart strategies
   - Configuration-based agent pool management

### Key Integration Points

**Existing Application Structure:**
From `lib/pipeline/application.ex`:
```elixir
def start(_type, _args) do
  children = [
    {Registry, keys: :unique, name: Pipeline.Registry}
  ]
  
  opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**Registry Integration:**
From `lib/pipeline/monitoring/registry.ex`:
- Process monitoring and lifecycle tracking
- **Agent Integration**: Agents must register in same system

**Session Management Integration:**
From `lib/pipeline/session_manager.ex`:
- Session persistence and cleanup
- **Agent Integration**: Coordinate session cleanup when agents restart

### Agent Supervisor Implementation

**Main Agent Supervisor** (`lib/pipeline/mabeam/agents/supervisor.ex`):
```elixir
defmodule Pipeline.MABEAM.Agents.Supervisor do
  use Supervisor
  
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    config = Pipeline.CLI.Config.load_cli_config(opts)
    
    children = [
      # Agent registry integration
      {Pipeline.MABEAM.Agents.Registry, []},
      
      # Core agents - always running
      {Pipeline.MABEAM.Agents.PipelineManager, [id: "pipeline_manager"]},
      {Pipeline.MABEAM.Agents.SystemMonitor, [id: "system_monitor"]},
      
      # Dynamic worker supervisor
      {Pipeline.MABEAM.Agents.WorkerSupervisor, [config: config]}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  # Public API for dynamic worker management
  def add_worker(specialization \\ :general, opts \\ []) do
    worker_id = generate_worker_id(specialization)
    
    spec = {
      Pipeline.MABEAM.Agents.PipelineWorker,
      [id: worker_id, specialization: specialization] ++ opts
    }
    
    case DynamicSupervisor.start_child(Pipeline.MABEAM.Agents.WorkerSupervisor, spec) do
      {:ok, pid} -> 
        Pipeline.MABEAM.Agents.Registry.register_worker(worker_id, pid, specialization)
        {:ok, pid}
      error -> error
    end
  end
  
  def remove_worker(worker_id) do
    case Pipeline.MABEAM.Agents.Registry.lookup_worker(worker_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(Pipeline.MABEAM.Agents.WorkerSupervisor, pid)
        Pipeline.MABEAM.Agents.Registry.unregister_worker(worker_id)
      error -> error
    end
  end
end
```

**Worker Supervisor** (`lib/pipeline/mabeam/agents/worker_supervisor.ex`):
```elixir
defmodule Pipeline.MABEAM.Agents.WorkerSupervisor do
  use DynamicSupervisor
  
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    config = opts[:config] || %{}
    
    # Start initial worker pool
    spawn_link(fn -> start_initial_workers(config) end)
    
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: config[:max_worker_count] || 10
    )
  end
  
  defp start_initial_workers(config) do
    worker_count = config[:default_worker_count] || 3
    specializations = config[:worker_specializations] || [:general]
    
    for _i <- 1..worker_count do
      specialization = Enum.random(specializations)
      Pipeline.MABEAM.Agents.Supervisor.add_worker(specialization)
    end
  end
end
```

### Registry Integration

**Agent Registry** (`lib/pipeline/mabeam/agents/registry.ex`):
```elixir
defmodule Pipeline.MABEAM.Agents.Registry do
  use GenServer
  
  # Integrate with existing Pipeline.Registry
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Register this process in the main pipeline registry
    Registry.register(Pipeline.Registry, :agent_registry, %{})
    
    state = %{
      managers: %{},
      workers: %{},
      monitors: %{}
    }
    
    {:ok, state}
  end
  
  # Worker management
  def register_worker(worker_id, pid, specialization) do
    GenServer.call(__MODULE__, {:register_worker, worker_id, pid, specialization})
  end
  
  def lookup_worker(worker_id) do
    GenServer.call(__MODULE__, {:lookup_worker, worker_id})
  end
  
  def list_workers(filter \\ %{}) do
    GenServer.call(__MODULE__, {:list_workers, filter})
  end
  
  def find_available_worker(specialization \\ :any) do
    GenServer.call(__MODULE__, {:find_available_worker, specialization})
  end
  
  # Integration with existing monitoring
  def get_health_status() do
    GenServer.call(__MODULE__, :get_health_status)
  end
  
  @impl true
  def handle_call({:register_worker, worker_id, pid, specialization}, _from, state) do
    # Monitor the worker process
    Process.monitor(pid)
    
    worker_info = %{
      id: worker_id,
      pid: pid,
      specialization: specialization,
      status: :idle,
      started_at: DateTime.utc_now(),
      current_pipeline: nil
    }
    
    new_state = put_in(state.workers[worker_id], worker_info)
    {:reply, :ok, new_state}
  end
  
  # Handle worker process termination
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Find and remove the terminated worker
    {worker_id, _worker_info} = 
      Enum.find(state.workers, fn {_id, info} -> info.pid == pid end) || {nil, nil}
    
    if worker_id do
      Logger.warn("Worker #{worker_id} terminated: #{inspect(reason)}")
      new_state = Map.delete(state.workers, worker_id)
      {:noreply, %{state | workers: new_state}}
    else
      {:noreply, state}
    end
  end
end
```

### Application Integration

**Update Pipeline.Application** (`lib/pipeline/application.ex`):
```elixir
defmodule Pipeline.Application do
  use Application
  
  @impl true
  def start(_type, _args) do
    # Determine if MABEAM mode is enabled
    multi_agent_enabled = Application.get_env(:pipeline, :mabeam_enabled, false)
    
    base_children = [
      {Registry, keys: :unique, name: Pipeline.Registry}
    ]
    
    children = if multi_agent_enabled do
      base_children ++ [
        # Add agent supervision tree
        {Pipeline.MABEAM.Agents.Supervisor, []}
      ]
    else
      base_children
    end
    
    opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Configuration Integration

**MABEAM Configuration** (`lib/pipeline/mabeam/config.ex`):
```elixir
defmodule Pipeline.MABEAM.Config do
  @moduledoc """
  Configuration management for MABEAM system.
  Integrates with existing Pipeline.Config patterns.
  """
  
  def load_config(opts \\ []) do
    base_config = %{
      # Agent pool configuration
      default_worker_count: get_env_int("PIPELINE_DEFAULT_WORKERS", 3),
      max_worker_count: get_env_int("PIPELINE_MAX_WORKERS", 10),
      
      # Specializations
      worker_specializations: parse_specializations(
        System.get_env("PIPELINE_WORKER_SPECIALIZATIONS", "general,claude,gemini")
      ),
      
      # Execution configuration
      max_concurrent_pipelines: get_env_int("PIPELINE_MAX_CONCURRENT", 5),
      pipeline_timeout: get_env_int("PIPELINE_TIMEOUT", 300_000),
      
      # Monitoring configuration
      health_check_interval: get_env_int("PIPELINE_HEALTH_CHECK_INTERVAL", 5000),
      metrics_retention_seconds: get_env_int("PIPELINE_METRICS_RETENTION", 3600),
      
      # Integration with existing config
      workspace_dir: System.get_env("PIPELINE_WORKSPACE_DIR", "./workspace"),
      output_dir: System.get_env("PIPELINE_OUTPUT_DIR", "./outputs"),
      debug: System.get_env("PIPELINE_DEBUG") == "true"
    }
    
    # Merge with provided options
    Map.merge(base_config, Enum.into(opts, %{}))
  end
  
  defp get_env_int(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> String.to_integer(value)
    end
  end
  
  defp parse_specializations(specializations_string) do
    specializations_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end
end
```

### Health Check Integration

**Health Check Extension** (`lib/pipeline/health_check.ex`):
```elixir
# Extend existing Pipeline.health_check/0 function
defmodule Pipeline.HealthCheck do
  def check_system_health() do
    checks = [
      check_base_system(),
      check_multi_agent_system()
    ]
    
    case Enum.all?(checks, &(&1 == :ok)) do
      true -> :ok
      false -> {:error, filter_errors(checks)}
    end
  end
  
  defp check_base_system() do
    # Use existing health check logic
    Pipeline.health_check()
  end
  
  defp check_multi_agent_system() do
    if multi_agent_enabled?() do
      case Pipeline.MABEAM.Agents.Registry.get_health_status() do
        {:ok, _status} -> :ok
        error -> error
      end
    else
      :ok
    end
  end
  
  defp multi_agent_enabled?() do
    Application.get_env(:pipeline, :mabeam_enabled, false)
  end
end
```

### Expected Deliverables

1. **Supervision Tree** in `lib/pipeline/mabeam/agents/`:
   - `supervisor.ex` - Main agent supervisor
   - `worker_supervisor.ex` - Dynamic worker management
   - `registry.ex` - Agent discovery and health tracking

2. **Integration Modules**:
   - Updated `lib/pipeline/application.ex` with optional agent supervision
   - `lib/pipeline/mabeam/config.ex` - Configuration management
   - Extended health check system

3. **Management APIs**:
   - Public functions for adding/removing workers
   - Agent status and health checking
   - Integration with existing monitoring

4. **Test Coverage**:
   - Supervisor tree starts correctly
   - Worker agents can be added/removed dynamically
   - Failure recovery works properly
   - Integration with existing application doesn't break functionality

### Success Criteria

- Agent supervision tree integrates cleanly with existing Pipeline.Application
- Workers can be dynamically added and removed
- Agent failures are detected and handled gracefully
- Registry provides accurate agent status information
- Health checks include both base system and agent system
- Configuration follows existing pipeline_ex patterns
- No breaking changes to existing functionality when MABEAM mode is disabled

---

## Prompt 7: Testing, Documentation, and Final Integration

### Context Files to Read First

**MANDATORY - Read these files for testing integration:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles and patterns for all development
- `/home/home/p/g/n/pipeline_ex/test/pipeline_test.exs` - Main test patterns
- `/home/home/p/g/n/pipeline_ex/test/support/test_case.exs` - Test case helpers
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/test_mode.ex` - Mock/live testing patterns
- `/home/home/p/g/n/pipeline_ex/test/support/enhanced_mocks.ex` - Mock implementations
- `/home/home/p/g/n/pipeline_ex/TESTING_STRATEGY.md` - Complete testing approach
- `/home/home/p/g/n/pipeline_ex/TEST_COVERAGE_SUMMARY.md` - Coverage requirements

**Documentation Files:**
- `/home/home/p/g/n/pipeline_ex/README.md` - Complete API documentation
- `/home/home/p/g/n/pipeline_ex/ADVANCED_FEATURES.md` - Feature documentation
- `/home/home/p/g/n/pipeline_ex/LIBRARY_build.md` - Library usage patterns

### Task Description

Implement comprehensive testing for the MABEAM system, create complete documentation, and finalize the integration with the existing pipeline_ex system. This includes unit tests, integration tests, performance tests, and user documentation, following OTP testing principles from ELIXIR_DEV_GUIDE.md.

**Critical OTP Testing Requirements from ELIXIR_DEV_GUIDE.md:**
- Use start_supervised!/1 to test entire supervision trees, not isolated modules
- Test process lifecycle with Process.monitor/1 and assert_receive, not Process.sleep/1
- Use :async false for tests involving stateful processes and registries
- Test crash scenarios by killing processes and verifying supervisor restarts
- Test the entire OTP application startup, not just individual modules

### Implementation Requirements

1. **Test Suite Development**:
   - Unit tests for all agent modules and actions
   - Integration tests for MABEAM pipeline execution
   - Performance tests for concurrent execution
   - CLI testing for interactive components

2. **Documentation Creation**:
   - User guide for MABEAM system
   - API documentation for all new modules
   - Integration examples and usage patterns
   - Migration guide for existing users

3. **Final Integration**:
   - Configuration validation
   - Error handling and logging
   - Performance optimization
   - Production readiness checklist

### Key Testing Integration Points

**Existing Test Patterns:**
From `test/pipeline_test.exs`:
```elixir
defmodule PipelineTest do
  use ExUnit.Case
  use Pipeline.TestCase  # Provides mock/live switching
  
  test "executes workflow successfully" do
    # Test pattern to follow for agents
  end
end
```

**Mock System Integration:**
From `lib/pipeline/test_mode.ex`:
- Mock/live mode switching
- **Agent Testing**: Agents must work in both mock and live modes

**Test Case Helpers:**
From `test/support/test_case.exs`:
- Common test setup patterns
- **Agent Integration**: Extend for agent-specific test helpers

### Test Suite Implementation

1. **Unit Tests** (`test/pipeline/agents/`):

```elixir
# test/pipeline/agents/pipeline_manager_test.exs
defmodule Pipeline.MABEAM.Agents.PipelineManagerTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  alias Pipeline.MABEAM.Agents.PipelineManager
  
  setup do
    # Use existing test setup patterns
    {:ok, agent} = start_supervised({PipelineManager, [id: "test_manager"]})
    %{agent: agent}
  end
  
  test "schedules pipeline for execution", %{agent: agent} do
    pipeline_config = load_test_pipeline("simple_test.yaml")
    
    result = PipelineManager.schedule_pipeline(agent, pipeline_config)
    assert {:ok, _execution_id} = result
  end
  
  test "distributes work to available workers", %{agent: agent} do
    # Test worker distribution logic
    assert true  # Implement actual test
  end
  
  defp load_test_pipeline(filename) do
    # Use existing test fixture loading
    path = Path.join(["test", "fixtures", "workflows", filename])
    {:ok, config} = Pipeline.Config.load_and_validate(path)
    config
  end
end
```

2. **Integration Tests** (`test/integration/multi_agent/`):

```elixir
# test/integration/multi_agent/pipeline_execution_test.exs
defmodule Pipeline.Integration.MultiAgent.PipelineExecutionTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  @moduletag :integration
  
  setup do
    # Start the full agent system
    {:ok, supervisor} = start_supervised(Pipeline.MABEAM.Agents.Supervisor)
    
    # Wait for agents to be ready
    :timer.sleep(100)
    
    %{supervisor: supervisor}
  end
  
  test "executes pipeline through MABEAM system" do
    # Test that a pipeline can be executed through the agent system
    # and produces the same results as direct execution
    
    pipeline_file = "test/fixtures/workflows/simple_workflow.yaml"
    
    # Execute directly
    {:ok, direct_result} = Pipeline.run(pipeline_file)
    
    # Execute through agent system
    {:ok, agent_result} = execute_through_agents(pipeline_file)
    
    # Results should be equivalent (allowing for execution metadata differences)
    assert normalize_result(direct_result) == normalize_result(agent_result)
  end
  
  test "handles concurrent pipeline execution" do
    # Test multiple pipelines executing simultaneously
    pipeline_files = [
      "test/fixtures/workflows/simple_workflow.yaml",
      "test/fixtures/workflows/complex_workflow.yaml"
    ]
    
    tasks = Enum.map(pipeline_files, fn file ->
      Task.async(fn -> execute_through_agents(file) end)
    end)
    
    results = Task.await_many(tasks, 30_000)
    
    # All should succeed
    assert Enum.all?(results, fn {:ok, _} -> true; _ -> false end)
  end
  
  defp execute_through_agents(pipeline_file) do
    # Implementation to execute pipeline through agent system
    manager = Pipeline.MABEAM.Agents.Registry.get_manager()
    PipelineManager.execute_pipeline(manager, pipeline_file)
  end
  
  defp normalize_result(result) do
    # Remove execution-specific metadata for comparison
    Map.drop(result, ["execution_time", "execution_id", "timestamp"])
  end
end
```

3. **CLI Tests** (`test/pipeline/cli/`):

```elixir
# test/pipeline/cli/commands_test.exs
defmodule Pipeline.CLI.CommandsTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  alias Pipeline.CLI.Commands
  
  test "run command executes pipeline" do
    # Test CLI command execution
    state = %{config: %{workspace_dir: "test/tmp", debug: true}}
    
    {:ok, output, _new_state} = Commands.Run.run(
      ["test/fixtures/workflows/simple_workflow.yaml"], 
      state
    )
    
    assert output =~ "Pipeline completed successfully"
  end
  
  test "status command shows agent information" do
    # Start agents for testing
    start_supervised(Pipeline.MABEAM.Agents.Supervisor)
    :timer.sleep(100)
    
    state = %{}
    {:ok, output, _} = Commands.Status.run([], state)
    
    assert output =~ "Agent Status"
    assert output =~ "pipeline_manager"
  end
end
```

### Performance Testing

**Performance Test Suite** (`test/performance/multi_agent_test.exs`):

```elixir
defmodule Pipeline.Performance.MultiAgentTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  @moduletag :performance
  @moduletag timeout: 120_000
  
  test "concurrent pipeline execution performance" do
    # Start agent system
    start_supervised(Pipeline.MABEAM.Agents.Supervisor)
    :timer.sleep(1000)  # Allow agents to start
    
    # Prepare test pipelines
    pipeline_count = 10
    pipeline_file = "test/fixtures/workflows/performance_test.yaml"
    
    # Measure concurrent execution through agents
    agent_start_time = System.monotonic_time(:millisecond)
    
    agent_tasks = for _i <- 1..pipeline_count do
      Task.async(fn -> execute_through_agents(pipeline_file) end)
    end
    
    agent_results = Task.await_many(agent_tasks, 60_000)
    agent_end_time = System.monotonic_time(:millisecond)
    
    # Measure sequential direct execution for comparison
    direct_start_time = System.monotonic_time(:millisecond)
    
    direct_results = for _i <- 1..pipeline_count do
      {:ok, result} = Pipeline.run(pipeline_file)
      result
    end
    
    direct_end_time = System.monotonic_time(:millisecond)
    
    # Calculate metrics
    agent_time = agent_end_time - agent_start_time
    direct_time = direct_end_time - direct_start_time
    
    # Assert all executions succeeded
    assert Enum.all?(agent_results, fn {:ok, _} -> true; _ -> false end)
    assert length(direct_results) == pipeline_count
    
    # Agent system should be faster for concurrent execution
    assert agent_time < direct_time
    
    # Log performance metrics
    IO.puts("\nPerformance Test Results:")
    IO.puts("  Concurrent (agents): #{agent_time}ms")
    IO.puts("  Sequential (direct): #{direct_time}ms")
    IO.puts("  Speedup: #{Float.round(direct_time / agent_time, 2)}x")
  end
end
```

### Documentation Implementation

**User Guide** (`docs/multi_agent_guide.md`):

```markdown
# MABEAM Pipeline System User Guide

## Overview

The MABEAM pipeline system extends pipeline_ex with distributed execution capabilities using Jido agents. This allows for concurrent pipeline execution, fault tolerance, and intelligent work distribution.

## Quick Start

### 1. Enable MABEAM Mode

Add to your configuration:

```elixir
config :pipeline, :mabeam_enabled, true
```

### 2. Start the System

```bash
# Start with interactive CLI
mix pipeline.mabeam

# Or start programmatically
{:ok, _pid} = Pipeline.MABEAM.Agents.Supervisor.start_link()
```

### 3. Execute Pipelines

```bash
# Through CLI
pipeline> run examples/data_analysis.yaml

# Or programmatically
{:ok, result} = Pipeline.MABEAM.execute("my_pipeline.yaml")
```

## Integration with Existing Code

The MABEAM system is fully compatible with existing pipeline_ex code:

```elixir
# Existing code continues to work
{:ok, result} = Pipeline.run("my_pipeline.yaml")

# Multi-agent execution (when enabled)
{:ok, result} = Pipeline.run("my_pipeline.yaml")  # Automatically uses agents
```

[Continue with complete user guide...]
```

**API Documentation** (`docs/api/multi_agent_api.md`):

```markdown
# MABEAM API Reference

## Core Modules

### Pipeline.MABEAM.Agents.PipelineManager

Main agent responsible for orchestrating pipeline execution across workers.

#### Functions

- `schedule_pipeline/2` - Queue a pipeline for execution
- `get_status/1` - Get current manager status
- `list_active_pipelines/1` - List currently executing pipelines

[Continue with complete API documentation...]
```

### Configuration Validation

**Configuration Validator** (`lib/pipeline/mabeam/config_validator.ex`):

```elixir
defmodule Pipeline.MABEAM.ConfigValidator do
  @moduledoc """
  Validates MABEAM configuration and provides helpful error messages.
  """
  
  def validate_config(config) do
    with :ok <- validate_worker_count(config),
         :ok <- validate_specializations(config),
         :ok <- validate_directories(config),
         :ok <- validate_timeouts(config) do
      :ok
    else
      {:error, reason} -> {:error, "Multi-agent configuration error: #{reason}"}
    end
  end
  
  defp validate_worker_count(config) do
    default_count = config[:default_worker_count] || 3
    max_count = config[:max_worker_count] || 10
    
    cond do
      default_count <= 0 -> 
        {:error, "default_worker_count must be positive"}
      max_count < default_count -> 
        {:error, "max_worker_count must be >= default_worker_count"}
      true -> :ok
    end
  end
  
  # Additional validation functions...
end
```

### Production Readiness

**Production Checklist** (`docs/production_checklist.md`):

```markdown
# MABEAM Production Deployment Checklist

## Configuration
- [ ] Set appropriate worker counts for your workload
- [ ] Configure specializations based on your pipeline types
- [ ] Set proper timeouts and resource limits
- [ ] Configure monitoring thresholds

## Performance
- [ ] Run performance tests with your typical workload
- [ ] Validate memory usage under load
- [ ] Test failure recovery scenarios
- [ ] Verify graceful shutdown behavior

## Monitoring
- [ ] Set up health check endpoints
- [ ] Configure alerting for agent failures
- [ ] Monitor queue depths and processing rates
- [ ] Track API costs and usage patterns

[Continue with complete checklist...]
```

### Expected Deliverables

1. **Test Suite** in `test/`:
   - Unit tests for all agent modules
   - Integration tests for MABEAM execution
   - Performance tests for concurrent scenarios
   - CLI tests for interactive components

2. **Documentation** in `docs/`:
   - Complete user guide with examples
   - API reference documentation
   - Integration patterns and best practices
   - Production deployment guide

3. **Configuration and Validation**:
   - Configuration validator with helpful error messages
   - Environment variable documentation
   - Migration guide for existing users

4. **Production Features**:
   - Comprehensive error handling and logging
   - Performance monitoring and metrics
   - Health checks and system status reporting

### Success Criteria

- All tests pass in both mock and live modes
- Performance tests demonstrate improved concurrent execution
- Documentation is complete and accurate
- Integration works seamlessly with existing pipeline_ex functionality
- Configuration validation catches common errors with helpful messages
- System is ready for production deployment
- Migration path is clear for existing users
- All deliverables maintain compatibility with existing API patterns

---

## Final Integration Notes

Each prompt builds upon the previous ones and maintains integration with the existing pipeline_ex system, strictly following OTP principles from ELIXIR_DEV_GUIDE.md. Key principles throughout:

1. **No Breaking Changes**: All existing pipeline_ex functionality continues to work
2. **Optional Integration**: MABEAM mode is opt-in via configuration  
3. **OTP Compliance**: All processes follow proper supervision tree patterns
4. **API Compatibility**: New features follow existing patterns and conventions
5. **Testing Parity**: All features work in both mock and live modes using proper OTP testing
6. **Documentation Standards**: Follow existing documentation patterns and quality

**Critical OTP Compliance Requirements:**
- All long-lived processes must be under supervision
- No Process.sleep/1 anywhere in the codebase
- Use Registry for process discovery and coordination
- Follow "Let It Crash" philosophy throughout
- Proper GenServer patterns with clean separation of client API and server callbacks

The implementation should result in a production-ready MABEAM (Multi-Agent BEAM) system that seamlessly extends pipeline_ex capabilities while maintaining all existing functionality and demonstrating exemplary OTP architecture.