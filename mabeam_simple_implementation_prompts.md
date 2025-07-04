# MABEAM Simple Implementation Prompts

This file contains streamlined prompts for implementing MABEAM (Multi-Agent BEAM) using Jido as the primary agent framework. This approach leverages Jido's built-in capabilities instead of reinventing agent infrastructure.

---

## Prompt 1: Basic Jido Integration and Pipeline Actions

### Context Files to Read First

**MANDATORY - Read these files to understand the integration approach:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles
- `/home/home/p/g/n/pipeline_ex/JIDO_INTEGRATION_GUIDE.md` - **REQUIRED READING** - Complete Jido integration strategy
- `/home/home/p/g/n/pipeline_ex/README.md` - Pipeline_ex API and usage patterns
- `/home/home/p/g/n/pipeline_ex/lib/pipeline.ex` - Main Pipeline API functions
- `/home/home/p/g/n/agentjido/jido/README.md` - Jido core concepts and installation
- `/home/home/p/g/n/agentjido/jido/guides/actions/overview.md` - Jido Action system

### Task Description

Implement basic MABEAM integration by adding Jido as a dependency and creating fundamental Jido Actions that wrap existing pipeline_ex functionality. This leverages Jido's built-in Action system instead of building custom execution logic.

**Key Strategy from JIDO_INTEGRATION_GUIDE.md:**
- Use Jido.Action behavior for all operations
- Wrap existing Pipeline.run/2 and other APIs
- Leverage Jido's built-in validation, error handling, and compensation
- No custom GenServers - use Jido's patterns

### Implementation Requirements

1. **Update Dependencies** in `mix.exs`:
```elixir
{:jido, "~> 1.1.0"}
```

2. **Create Core Pipeline Actions** in `lib/pipeline/mabeam/actions/`:

**ExecutePipelineYaml Action:**
```elixir
defmodule Pipeline.MABEAM.Actions.ExecutePipelineYaml do
  use Jido.Action,
    name: "execute_pipeline_yaml",
    description: "Executes a pipeline_ex YAML workflow",
    schema: [
      pipeline_file: [type: :string, required: true, doc: "Path to YAML pipeline file"],
      workspace_dir: [type: :string, default: "./workspace"],
      output_dir: [type: :string, default: "./outputs"],
      debug: [type: :boolean, default: false],
      timeout: [type: :pos_integer, default: 300_000]
    ]

  @impl true
  def run(params, _context) do
    # Use existing Pipeline.run/2 API
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

**GeneratePipeline Action (Genesis Integration):**
```elixir
defmodule Pipeline.MABEAM.Actions.GeneratePipeline do
  use Jido.Action,
    name: "generate_pipeline",
    description: "Generates a new pipeline using Genesis system",
    schema: [
      description: [type: :string, required: true, doc: "Description of pipeline to generate"],
      output_file: [type: :string, required: true, doc: "Output file path for generated pipeline"]
    ]

  @impl true
  def run(params, _context) do
    # Integration with existing Genesis pipeline generation
    # Use existing mix task functionality
    case System.cmd("mix", ["pipeline.generate.live", params.description], 
         into: "", stderr_to_stdout: true) do
      {output, 0} -> {:ok, %{output: output, file: params.output_file}}
      {error, _} -> {:error, "Generation failed: #{error}"}
    end
  end
end
```

3. **Create Pipeline Health Action:**
```elixir
defmodule Pipeline.MABEAM.Actions.HealthCheck do
  use Jido.Action,
    name: "health_check",
    description: "Checks pipeline_ex system health"

  @impl true
  def run(_params, _context) do
    # Use existing health check
    case Pipeline.health_check() do
      :ok -> {:ok, %{status: :healthy, timestamp: DateTime.utc_now()}}
      {:error, issues} -> {:ok, %{status: :unhealthy, issues: issues}}
    end
  end
end
```

### Key Integration Points

**From Pipeline.ex API:**
- Use `Pipeline.run/2` directly in Actions
- Leverage existing configuration and workspace management
- Maintain compatibility with all existing pipeline features

**From Jido Actions:**
- Built-in parameter validation using schema
- Automatic error handling and compensation support
- Execution context and telemetry integration

### Expected Deliverables

1. Updated `mix.exs` with Jido dependency
2. Core Actions in `lib/pipeline/mabeam/actions/`:
   - `execute_pipeline_yaml.ex`
   - `generate_pipeline.ex` 
   - `health_check.ex`
3. Basic test suite showing Actions work with existing pipeline YAML files
4. Integration test demonstrating Jido Workflow execution

### Success Criteria

- `mix deps.get` successfully installs Jido
- Actions can execute existing pipeline YAML files
- Jido Workflow.run/4 works with pipeline Actions
- All existing pipeline_ex functionality remains unchanged
- Actions provide better error handling than direct API calls

---

## Prompt 2: Create Pipeline Management Agent

### Context Files to Read First

**MANDATORY - Read these files:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - Core OTP principles
- `/home/home/p/g/n/pipeline_ex/JIDO_INTEGRATION_GUIDE.md` - **REQUIRED READING** - Agent implementation strategy
- `/home/home/p/g/n/agentjido/jido/guides/agents/overview.md` - Complete Jido Agent implementation
- `/home/home/p/g/n/agentjido/jido/guides/agents/stateful.md` - Stateful agent patterns
- Previous prompt deliverables (Actions from Prompt 1)

### Task Description

Create a Jido Agent that manages pipeline execution using the Actions from Prompt 1. This agent maintains execution history, manages queue state, and provides a stateful interface for pipeline operations.

**Key Strategy from JIDO_INTEGRATION_GUIDE.md:**
- Use Jido.Agent behavior for state management
- Register Actions created in Prompt 1
- Let Jido handle instruction processing and error recovery
- Use Jido's built-in schema validation for agent state

### Implementation Requirements

1. **Pipeline Manager Agent** (`lib/pipeline/mabeam/agents/pipeline_manager.ex`):

```elixir
defmodule Pipeline.MABEAM.Agents.PipelineManager do
  use Jido.Agent,
    name: "pipeline_manager",
    description: "Manages pipeline execution with state tracking",
    actions: [
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      Pipeline.MABEAM.Actions.GeneratePipeline,
      Pipeline.MABEAM.Actions.HealthCheck,
      # Add built-in Jido actions for state management
      Jido.Actions.Directives.RegisterAction
    ],
    schema: [
      execution_history: [type: {:list, :map}, default: [], doc: "History of pipeline executions"],
      current_execution: [type: :map, default: nil, doc: "Currently running pipeline"],
      total_executions: [type: :integer, default: 0, doc: "Total number of executions"],
      queue: [type: {:list, :map}, default: [], doc: "Pending pipeline executions"],
      stats: [type: :map, default: %{}, doc: "Execution statistics"]
    ]

  # Jido automatically handles:
  # - State validation using schema
  # - Action routing and execution
  # - Error handling and recovery
  # - Instruction processing
  # - OTP supervision integration
end
```

2. **Pipeline Worker Agent** (`lib/pipeline/mabeam/agents/pipeline_worker.ex`):

```elixir
defmodule Pipeline.MABEAM.Agents.PipelineWorker do
  use Jido.Agent,
    name: "pipeline_worker",
    description: "Executes individual pipelines with specialization",
    actions: [
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      Pipeline.MABEAM.Actions.HealthCheck
    ],
    schema: [
      worker_id: [type: :string, required: true, doc: "Unique worker identifier"],
      specialization: [type: :atom, default: :general, doc: "Worker specialization type"],
      status: [type: :atom, default: :idle, doc: "Current worker status"],
      current_pipeline: [type: :map, default: nil, doc: "Currently executing pipeline"],
      execution_count: [type: :integer, default: 0, doc: "Number of completed executions"],
      last_execution: [type: :map, default: nil, doc: "Last execution details"]
    ]
end
```

3. **Agent Supervisor** (`lib/pipeline/mabeam/supervisor.ex`):

```elixir
defmodule Pipeline.MABEAM.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Main pipeline manager
      {Pipeline.MABEAM.Agents.PipelineManager, id: "pipeline_manager"},
      
      # Default worker pool
      {Pipeline.MABEAM.Agents.PipelineWorker, id: "worker_1", worker_id: "worker_1"},
      {Pipeline.MABEAM.Agents.PipelineWorker, id: "worker_2", worker_id: "worker_2"}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

4. **Application Integration** (update `lib/pipeline/application.ex`):

```elixir
def start(_type, _args) do
  base_children = [
    {Registry, keys: :unique, name: Pipeline.Registry}
  ]

  children = if Application.get_env(:pipeline, :mabeam_enabled, false) do
    base_children ++ [Pipeline.MABEAM.Supervisor]
  else
    base_children
  end

  opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Usage Examples

**Basic Agent Usage:**
```elixir
# Start the MABEAM system
Application.put_env(:pipeline, :mabeam_enabled, true)
{:ok, _} = Pipeline.Application.start(:normal, [])

# Send instruction to pipeline manager
{:ok, manager} = Pipeline.MABEAM.Agents.PipelineManager.start_link(id: "manager")

instruction = %Jido.Instruction{
  action: "execute_pipeline_yaml",
  params: %{pipeline_file: "examples/simple_test.yaml"}
}

{:ok, result} = Pipeline.MABEAM.Agents.PipelineManager.cmd(manager, [instruction])
```

**Workflow Integration:**
```elixir
# Execute through Jido Workflow system
{:ok, result} = Jido.Workflow.run(
  Pipeline.MABEAM.Actions.ExecutePipelineYaml,
  %{pipeline_file: "analysis.yaml"},
  %{user_id: "123"},
  timeout: 30_000,
  max_retries: 3
)
```

### Expected Deliverables

1. **Agent Modules** in `lib/pipeline/mabeam/agents/`:
   - `pipeline_manager.ex` - Main coordination agent
   - `pipeline_worker.ex` - Individual execution agent
2. **Supervisor** in `lib/pipeline/mabeam/supervisor.ex`
3. **Application Integration** - Optional MABEAM mode
4. **Test Suite** showing agents can execute pipelines and maintain state
5. **Usage Examples** demonstrating agent instruction processing

### Success Criteria

- Agents start successfully under supervision
- Instructions route to correct Actions and execute pipelines
- Agent state is maintained and validated by Jido
- Multiple agents can run concurrently
- Integration with existing pipeline_ex APIs is seamless
- All Jido built-in features (error handling, state validation) work correctly

---

## Prompt 3: Add Monitoring Sensors and Workflow Integration

### Context Files to Read First

**MANDATORY - Read these files:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - OTP principles
- `/home/home/p/g/n/pipeline_ex/JIDO_INTEGRATION_GUIDE.md` - **REQUIRED READING** - Sensor integration strategy  
- `/home/home/p/g/n/agentjido/jido/guides/sensors/overview.md` - Complete Jido Sensor implementation
- `/home/home/p/g/n/agentjido/jido/guides/actions/workflows.md` - Jido Workflow capabilities
- Previous prompt deliverables (Actions and Agents)

### Task Description

Add Jido Sensors for monitoring and enhance the system with Jido Workflow capabilities for advanced execution features like async processing, retries, and telemetry.

**Key Strategy from JIDO_INTEGRATION_GUIDE.md:**
- Use Jido.Sensor behavior for monitoring
- Leverage Jido.Workflow for advanced execution features
- Integrate with existing pipeline_ex monitoring systems
- Use Jido's built-in signal/event system

### Implementation Requirements

1. **Pipeline Queue Sensor** (`lib/pipeline/mabeam/sensors/queue_monitor.ex`):

```elixir
defmodule Pipeline.MABEAM.Sensors.QueueMonitor do
  use Jido.Sensor,
    name: "pipeline_queue_monitor",
    description: "Monitors pipeline execution queue depth and processing rates",
    schema: [
      check_interval: [type: :pos_integer, default: 5000, doc: "Check interval in milliseconds"],
      alert_threshold: [type: :integer, default: 10, doc: "Queue depth alert threshold"]
    ]

  @impl true
  def mount(opts) do
    # Schedule periodic checks using timer, not Process.sleep
    :timer.send_interval(opts.check_interval, self(), :check_queue)
    
    {:ok, %{
      id: opts.id,
      target: opts.target,
      config: opts,
      last_check: DateTime.utc_now()
    }}
  end

  @impl true
  def handle_info(:check_queue, state) do
    case deliver_signal(state) do
      {:ok, signal} -> 
        dispatch_signal(signal, state)
        {:noreply, %{state | last_check: DateTime.utc_now()}}
      {:error, reason} ->
        Logger.error("Queue monitor failed: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def deliver_signal(state) do
    # Get queue stats from pipeline manager agents
    queue_depth = get_total_queue_depth()
    processing_rate = calculate_processing_rate()
    
    {:ok, Jido.Signal.new(%{
      source: "#{state.sensor.name}:#{state.id}",
      type: "pipeline.queue_status",
      data: %{
        queue_depth: queue_depth,
        processing_rate: processing_rate,
        alert: queue_depth > state.config.alert_threshold,
        timestamp: DateTime.utc_now()
      }
    })}
  end

  defp get_total_queue_depth() do
    # Query pipeline manager agents for queue stats
    # Implementation depends on agent registry
    0  # Placeholder
  end

  defp calculate_processing_rate() do
    # Calculate pipelines processed per minute
    0.0  # Placeholder
  end
end
```

2. **Performance Sensor** (`lib/pipeline/mabeam/sensors/performance_monitor.ex`):

```elixir
defmodule Pipeline.MABEAM.Sensors.PerformanceMonitor do
  use Jido.Sensor,
    name: "performance_monitor",
    description: "Monitors pipeline execution performance metrics",
    schema: [
      metric_window: [type: :pos_integer, default: 60_000, doc: "Metrics collection window"],
      emit_interval: [type: :pos_integer, default: 30_000, doc: "Signal emission interval"]
    ]

  @impl true
  def mount(opts) do
    :timer.send_interval(opts.emit_interval, self(), :emit_metrics)
    
    {:ok, %{
      id: opts.id,
      target: opts.target,
      config: opts,
      metrics_buffer: []
    }}
  end

  @impl true
  def deliver_signal(state) do
    metrics = collect_performance_metrics(state.config.metric_window)
    
    {:ok, Jido.Signal.new(%{
      source: "performance_monitor:#{state.id}",
      type: "pipeline.performance_metrics",
      data: %{
        avg_execution_time: metrics.avg_execution_time,
        throughput_per_hour: metrics.throughput_per_hour,
        error_rate: metrics.error_rate,
        active_pipelines: metrics.active_pipelines,
        timestamp: DateTime.utc_now()
      }
    })}
  end

  defp collect_performance_metrics(_window) do
    # Collect from pipeline monitoring system
    %{
      avg_execution_time: 45.2,
      throughput_per_hour: 120,
      error_rate: 0.02,
      active_pipelines: 3
    }
  end
end
```

3. **Enhanced Workflow Actions** (`lib/pipeline/mabeam/actions/workflow_actions.ex`):

```elixir
defmodule Pipeline.MABEAM.Actions.ExecutePipelineAsync do
  use Jido.Action,
    name: "execute_pipeline_async",
    description: "Executes pipeline asynchronously with full Jido Workflow features",
    schema: [
      pipeline_file: [type: :string, required: true],
      timeout: [type: :pos_integer, default: 300_000],
      max_retries: [type: :integer, default: 3],
      telemetry_level: [type: :atom, default: :full]
    ]

  @impl true  
  def run(params, context) do
    # Use Jido Workflow for advanced execution
    async_ref = Jido.Workflow.run_async(
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      %{pipeline_file: params.pipeline_file},
      context,
      timeout: params.timeout,
      max_retries: params.max_retries,
      telemetry: params.telemetry_level
    )
    
    {:ok, %{async_ref: async_ref, status: :started}}
  end
end

defmodule Pipeline.MABEAM.Actions.AwaitPipelineResult do
  use Jido.Action,
    name: "await_pipeline_result", 
    description: "Awaits result from async pipeline execution",
    schema: [
      async_ref: [type: :any, required: true],
      timeout: [type: :pos_integer, default: 300_000]
    ]

  @impl true
  def run(params, _context) do
    case Jido.Workflow.await(params.async_ref, params.timeout) do
      {:ok, result} -> {:ok, result}
      {:error, :timeout} -> {:error, "Pipeline execution timed out"}
      {:error, reason} -> {:error, "Pipeline execution failed: #{inspect(reason)}"}
    end
  end
end
```

4. **Update Supervisor** to include sensors:

```elixir
defmodule Pipeline.MABEAM.Supervisor do
  use Supervisor

  @impl true
  def init(_opts) do
    children = [
      # Agents
      {Pipeline.MABEAM.Agents.PipelineManager, id: "pipeline_manager"},
      {Pipeline.MABEAM.Agents.PipelineWorker, id: "worker_1", worker_id: "worker_1"},
      
      # Sensors for monitoring
      {Pipeline.MABEAM.Sensors.QueueMonitor, 
       id: "queue_monitor", 
       target: {:bus, target: :system_bus}},
      {Pipeline.MABEAM.Sensors.PerformanceMonitor,
       id: "performance_monitor",
       target: {:bus, target: :system_bus}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### Advanced Usage Examples

**Async Pipeline Execution:**
```elixir
# Start async execution
{:ok, async_result} = Jido.Workflow.run(
  Pipeline.MABEAM.Actions.ExecutePipelineAsync,
  %{pipeline_file: "large_analysis.yaml", max_retries: 5}
)

# Do other work...

# Await completion
{:ok, final_result} = Jido.Workflow.run(
  Pipeline.MABEAM.Actions.AwaitPipelineResult,
  %{async_ref: async_result.async_ref}
)
```

**Monitoring Integration:**
```elixir
# Sensors automatically emit signals to configured targets
# Signals can be consumed by other agents or external systems
```

### Expected Deliverables

1. **Sensor Modules** in `lib/pipeline/mabeam/sensors/`:
   - `queue_monitor.ex` - Queue depth monitoring
   - `performance_monitor.ex` - Performance metrics
2. **Enhanced Actions** for async workflow capabilities
3. **Updated Supervisor** including sensors
4. **Integration Examples** showing async execution and monitoring
5. **Test Suite** covering sensor functionality and workflow features

### Success Criteria

- Sensors start and emit signals periodically
- Async pipeline execution works through Jido Workflows
- Monitoring data is collected and emitted via signals
- Performance metrics are accurate and timely
- Integration maintains all existing pipeline_ex functionality
- Jido's built-in telemetry and retry mechanisms work correctly

---

## Prompt 4: Create Simple CLI Interface and Production Integration

### Context Files to Read First

**MANDATORY - Read these files:**
- `/home/home/p/g/n/pipeline_ex/ELIXIR_DEV_GUIDE.md` - **REQUIRED READING** - OTP principles
- `/home/home/p/g/n/pipeline_ex/JIDO_INTEGRATION_GUIDE.md` - **REQUIRED READING** - CLI integration approach
- `/home/home/p/g/n/pipeline_ex/lib/mix/tasks/pipeline.run.ex` - Existing CLI patterns
- `/home/home/p/g/n/pipeline_ex/README.md` - CLI usage patterns and configuration
- Previous prompt deliverables (Actions, Agents, Sensors)

### Task Description

Create a simple CLI interface for MABEAM and prepare the system for production use. This includes a Mix task for easy startup, basic monitoring output, and production configuration options.

**Key Strategy from JIDO_INTEGRATION_GUIDE.md:**
- Keep CLI simple - leverage existing Mix task patterns
- Use Jido Agents for CLI state management
- Integrate with existing pipeline_ex CLI workflows
- Focus on production readiness over complex features

### Implementation Requirements

1. **MABEAM CLI Agent** (`lib/pipeline/mabeam/agents/cli_interface.ex`):

```elixir
defmodule Pipeline.MABEAM.Agents.CLIInterface do
  use Jido.Agent,
    name: "cli_interface",
    description: "Command-line interface for MABEAM system",
    actions: [
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      Pipeline.MABEAM.Actions.GeneratePipeline,
      Pipeline.MABEAM.Actions.HealthCheck,
      Pipeline.MABEAM.Actions.GetSystemStatus  # New action for status
    ],
    schema: [
      command_history: [type: {:list, :string}, default: []],
      current_mode: [type: :atom, default: :interactive],
      auto_refresh: [type: :boolean, default: true]
    ]

  # Jido handles all the GenServer complexity
  # CLI logic is implemented through Actions
end
```

2. **System Status Action** (`lib/pipeline/mabeam/actions/get_system_status.ex`):

```elixir
defmodule Pipeline.MABEAM.Actions.GetSystemStatus do
  use Jido.Action,
    name: "get_system_status",
    description: "Gets current MABEAM system status and metrics"

  @impl true
  def run(_params, _context) do
    # Collect status from various agents and sensors
    manager_status = get_manager_status()
    worker_statuses = get_worker_statuses()
    queue_stats = get_queue_statistics()
    performance_metrics = get_performance_metrics()

    {:ok, %{
      timestamp: DateTime.utc_now(),
      system_health: :healthy,  # Determine from collected data
      managers: manager_status,
      workers: worker_statuses,
      queue: queue_stats,
      performance: performance_metrics
    }}
  end

  defp get_manager_status() do
    # Query pipeline managers via Registry or direct calls
    %{active: 1, total_executions: 45}
  end

  defp get_worker_statuses() do
    # Query workers
    [
      %{id: "worker_1", status: :idle, executions: 20},
      %{id: "worker_2", status: :busy, executions: 15}
    ]
  end

  defp get_queue_statistics() do
    %{pending: 2, running: 1, completed_today: 42}
  end

  defp get_performance_metrics() do
    %{avg_execution_time: 45.2, throughput_per_hour: 34}
  end
end
```

3. **Mix Task** (`lib/mix/tasks/pipeline.mabeam.ex`):

```elixir
defmodule Mix.Tasks.Pipeline.Mabeam do
  use Mix.Task

  @shortdoc "Start MABEAM (Multi-Agent BEAM) pipeline system"

  @moduledoc """
  Start the MABEAM pipeline system with CLI interface.

  ## Examples

      # Start with default configuration
      mix pipeline.mabeam

      # Start with custom worker count  
      mix pipeline.mabeam --workers 5

      # Start in monitoring mode only
      mix pipeline.mabeam --monitor-only

      # Execute specific pipeline
      mix pipeline.mabeam --run examples/analysis.yaml

  ## Options

    * `--workers` - Number of worker agents (default: 2)
    * `--monitor-only` - Start monitoring without workers
    * `--run` - Execute specific pipeline and exit
    * `--debug` - Enable debug output
    * `--config` - Custom configuration file
  """

  def run(args) do
    {opts, [], _} = OptionParser.parse(args, switches: [
      workers: :integer,
      monitor_only: :boolean,
      run: :string,
      debug: :boolean,
      config: :string
    ])

    # Start the application with MABEAM enabled
    Application.put_env(:pipeline, :mabeam_enabled, true)
    {:ok, _} = Application.ensure_all_started(:pipeline)

    if opts[:run] do
      # Single pipeline execution mode
      execute_single_pipeline(opts[:run], opts)
    else
      # Interactive/daemon mode
      start_interactive_mode(opts)
    end
  end

  defp execute_single_pipeline(pipeline_file, opts) do
    IO.puts("Executing pipeline: #{pipeline_file}")
    
    case Jido.Workflow.run(
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      %{pipeline_file: pipeline_file, debug: opts[:debug] || false},
      %{},
      timeout: 300_000
    ) do
      {:ok, result} ->
        IO.puts("✅ Pipeline completed successfully")
        if opts[:debug], do: IO.inspect(result, label: "Result")
        System.halt(0)
      
      {:error, reason} ->
        IO.puts("❌ Pipeline failed: #{reason}")
        System.halt(1)
    end
  end

  defp start_interactive_mode(opts) do
    IO.puts("\n🤖 MABEAM (Multi-Agent BEAM) Pipeline System")
    IO.puts("===========================================")
    
    # Display initial status
    display_system_status()
    
    if opts[:monitor_only] do
      IO.puts("\nRunning in monitoring mode. Press Ctrl+C to exit.")
      start_monitoring_loop()
    else
      IO.puts("\nType 'help' for available commands.")
      start_command_loop()
    end
  end

  defp display_system_status() do
    case Jido.Workflow.run(Pipeline.MABEAM.Actions.GetSystemStatus, %{}) do
      {:ok, status} ->
        IO.puts("\nSystem Status:")
        IO.puts("  Health: #{status.system_health}")
        IO.puts("  Workers: #{length(status.workers)}")
        IO.puts("  Queue: #{status.queue.pending} pending, #{status.queue.running} running")
        IO.puts("  Performance: #{status.performance.avg_execution_time}ms avg")

      {:error, _reason} ->
        IO.puts("\nSystem Status: Unable to retrieve")
    end
  end

  defp start_monitoring_loop() do
    :timer.send_interval(5000, self(), :refresh_display)
    monitoring_loop()
  end

  defp monitoring_loop() do
    receive do
      :refresh_display ->
        IO.write("\e[H\e[J")  # Clear screen
        IO.puts("MABEAM Monitoring Dashboard - #{DateTime.utc_now()}")
        display_system_status()
        monitoring_loop()
    end
  end

  defp start_command_loop() do
    command = IO.gets("mabeam> ") |> String.trim()
    
    case command do
      "help" -> show_help(); start_command_loop()
      "status" -> display_system_status(); start_command_loop()
      "quit" -> System.halt(0)
      "run " <> pipeline_file -> 
        execute_single_pipeline(String.trim(pipeline_file), %{})
        start_command_loop()
      "" -> start_command_loop()
      unknown -> 
        IO.puts("Unknown command: #{unknown}")
        start_command_loop()
    end
  end

  defp show_help() do
    IO.puts("""
    Available commands:
      help     - Show this help
      status   - Display system status  
      run <file> - Execute pipeline file
      quit     - Exit MABEAM
    """)
  end
end
```

4. **Production Configuration** (`config/config.exs`):

```elixir
# MABEAM Configuration
config :pipeline,
  # Enable MABEAM system
  mabeam_enabled: false,  # Default off, enable via Mix task or env var
  
  # MABEAM-specific settings
  mabeam: [
    # Agent configuration
    default_worker_count: 2,
    max_worker_count: 10,
    
    # Monitoring configuration  
    queue_monitor_interval: 5000,
    performance_monitor_interval: 30_000,
    
    # Execution configuration
    default_pipeline_timeout: 300_000,
    max_retries: 3,
    
    # CLI configuration
    cli_refresh_interval: 5000,
    auto_display_status: true
  ]

# Jido configuration
config :jido,
  default_timeout: 30_000,
  task_supervisor: Pipeline.MABEAM.TaskSupervisor
```

5. **Update Application** for task supervisor:

```elixir
# In lib/pipeline/application.ex
def start(_type, _args) do
  base_children = [
    {Registry, keys: :unique, name: Pipeline.Registry}
  ]

  children = if Application.get_env(:pipeline, :mabeam_enabled, false) do
    base_children ++ [
      # Task supervisor for Jido async operations
      {Task.Supervisor, name: Pipeline.MABEAM.TaskSupervisor},
      # MABEAM supervision tree
      Pipeline.MABEAM.Supervisor
    ]
  else
    base_children
  end

  opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Usage Examples

**Basic CLI Usage:**
```bash
# Start interactive MABEAM system
mix pipeline.mabeam

# Execute single pipeline
mix pipeline.mabeam --run examples/analysis.yaml

# Start with monitoring dashboard
mix pipeline.mabeam --monitor-only

# Start with more workers
mix pipeline.mabeam --workers 5 --debug
```

**Programmatic Usage:**
```elixir
# Enable MABEAM in your application
Application.put_env(:pipeline, :mabeam_enabled, true)

# Use Jido Workflow for robust execution
{:ok, result} = Jido.Workflow.run(
  Pipeline.MABEAM.Actions.ExecutePipelineYaml,
  %{pipeline_file: "analysis.yaml"},
  %{user_id: "123"},
  timeout: 60_000,
  max_retries: 3,
  telemetry: :full
)
```

### Expected Deliverables

1. **CLI Agent** in `lib/pipeline/mabeam/agents/cli_interface.ex`
2. **System Status Action** for monitoring
3. **Mix Task** in `lib/mix/tasks/pipeline.mabeam.ex`
4. **Production Configuration** with sensible defaults
5. **Updated Application** with task supervisor
6. **Documentation** showing CLI usage and configuration options

### Success Criteria

- Mix task starts MABEAM system successfully
- CLI provides basic status and execution capabilities
- Single pipeline execution mode works correctly
- Monitoring mode displays real-time status updates
- Configuration is production-ready with proper defaults
- Integration maintains all existing pipeline_ex functionality
- System can be enabled/disabled via configuration

---

## Final Implementation Notes

This simplified approach leverages Jido's mature framework instead of building custom agent infrastructure:

### Benefits of This Approach

1. **Minimal Custom Code**: ~15 modules vs ~50+ in original approach
2. **Production-Ready**: Jido provides battle-tested OTP patterns
3. **Built-in Features**: Automatic error handling, retries, telemetry, async execution
4. **Clean Integration**: Actions wrap existing Pipeline.run/2 API cleanly
5. **Testing Support**: Jido provides comprehensive testing utilities

### Key Principles Followed

1. **Leverage Jido**: Use Jido.Action, Jido.Agent, Jido.Sensor, Jido.Workflow
2. **Minimal Reinvention**: Wrap existing pipeline_ex APIs, don't replace them
3. **OTP Compliance**: Jido handles supervision, registry, GenServer patterns
4. **Clean Separation**: Actions for operations, Agents for state, Sensors for monitoring
5. **Production Focus**: Configuration, monitoring, and CLI for real-world usage

### Implementation Timeline

- **Prompt 1**: 1-2 days (basic Actions and dependency)
- **Prompt 2**: 2-3 days (Agents and supervision) 
- **Prompt 3**: 2-3 days (Sensors and workflow integration)
- **Prompt 4**: 1-2 days (CLI and production features)

**Total**: ~1 week for a production-ready MABEAM system using Jido's proven patterns.