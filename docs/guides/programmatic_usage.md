# Programmatic Usage Guide

## Overview

PipelineEx is designed as a **library**, not a long-running service. It executes AI workflows on-demand and returns results. Think of it like HTTPoison or Ecto - you call it when needed, it does work, and returns.

## Architecture

### Execution Model

**One-shot execution (stateless):**
```elixir
# Load workflow
{:ok, config} = Pipeline.load_workflow("my_pipeline.yaml")

# Execute (blocking call)
{:ok, results} = Pipeline.execute(config)

# Pipeline is done - no persistent state
```

**NOT a supervised service:**
- No persistent GenServers for pipeline execution
- No long-running state machines
- No message queues or worker pools for pipelines themselves

**What IS supervised:**
- Performance monitoring (temporary GenServer during execution)
- Registry for monitoring processes

### When to Use

✅ **Good use cases:**
- Batch processing AI tasks
- Code generation/analysis workflows
- Data transformation pipelines
- CI/CD integration (analyze PRs, generate docs)
- One-off complex AI orchestrations

❌ **Not designed for:**
- Real-time chat applications (use direct Claude/Gemini APIs)
- High-frequency API calls (too much overhead)
- Long-running stateful conversations (sessions exist but are file-based)
- WebSocket-style continuous connections

## Programmatic Interface

### Basic API

```elixir
# 1. Simple execution
{:ok, results} = Pipeline.run("my_workflow.yaml")

# 2. Load then execute (reusable config)
{:ok, config} = Pipeline.load_workflow("workflow.yaml")
{:ok, results} = Pipeline.execute(config)

# 3. With custom options
{:ok, results} = Pipeline.execute(config,
  workspace_dir: "/tmp/my_workspace",
  output_dir: "/app/outputs",
  debug: true
)
```

### Return Values

```elixir
# Success
{:ok, %{
  "step_name" => %{
    text: "AI response here...",
    success: true,
    cost: 0.025,
    model: "claude-haiku-4-5-20251001"
  },
  "another_step" => %{...}
}}

# Failure
{:error, "Step 'analyze' failed: Timeout after 30s"}
```

### Advanced Usage

#### Execute Individual Steps (for testing)

```elixir
step = %{
  "name" => "analyze_code",
  "type" => "claude",
  "claude_options" => %{"model" => "haiku", "max_turns" => 1},
  "prompt" => [
    %{"type" => "static", "content" => "Analyze this code..."}
  ]
}

context = %{
  workspace_dir: "/tmp/test",
  results: %{},
  config: %{}
}

{:ok, result} = Pipeline.execute_step(step, context)
```

#### Health Checks

```elixir
case Pipeline.health_check() do
  :ok ->
    IO.puts("✅ Ready to execute pipelines")

  {:error, issues} ->
    IO.puts("❌ Configuration problems:")
    Enum.each(issues, &IO.puts("  - #{&1}"))
end
```

#### Configuration Inspection

```elixir
config = Pipeline.get_config()
# => %{
#   workspace_dir: "./workspace",
#   output_dir: "./outputs",
#   checkpoint_dir: "./checkpoints",
#   log_level: :info,
#   test_mode: "live",
#   debug_enabled: false
# }
```

## Test Mode vs Live Mode

### Mock Mode (Default for Safety)

```elixir
# Runs without calling real APIs
System.put_env("TEST_MODE", "mock")
{:ok, results} = Pipeline.run("workflow.yaml")
# => Returns mock data, no API costs
```

### Live Mode (Real API Calls)

```elixir
# Calls real Claude and Gemini APIs
System.put_env("TEST_MODE", "live")
{:ok, results} = Pipeline.run("workflow.yaml")
# => Real API calls, costs real money
```

### From Mix Tasks

```bash
# Mock (safe, no costs)
mix pipeline.run examples/simple_test.yaml

# Live (real APIs, costs money)
mix pipeline.run.live examples/simple_test.yaml
# OR
TEST_MODE=live mix pipeline.run examples/simple_test.yaml
```

## Examples: Do They Call APIs?

**By default: NO** (mock mode)

```bash
# This does NOT call real APIs
mix pipeline.run examples/simple_test.yaml
# Uses Pipeline.Test.Mocks.ClaudeProvider
# Returns fake responses instantly
```

**With .live task: YES**

```bash
# This DOES call real APIs
mix pipeline.run.live examples/simple_test.yaml
# Uses Pipeline.Providers.ClaudeProvider
# Makes real API calls to Claude/Gemini
# Costs real money
```

## Integration Patterns

### 1. Phoenix Controller Integration

```elixir
defmodule MyAppWeb.AIController do
  use MyAppWeb, :controller

  def analyze_code(conn, %{"code" => code}) do
    # Create temporary workflow
    workflow = %{
      "workflow" => %{
        "name" => "code_analysis",
        "steps" => [
          %{
            "name" => "analyze",
            "type" => "claude",
            "claude_options" => %{"model" => "haiku"},
            "prompt" => [
              %{"type" => "static", "content" => "Analyze: #{code}"}
            ]
          }
        ]
      }
    }

    case Pipeline.execute(workflow, workspace_dir: "/tmp/analysis_#{:rand.uniform(10000)}") do
      {:ok, results} ->
        json(conn, %{analysis: results["analyze"]["text"]})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: reason})
    end
  end
end
```

### 2. Task/Job Queue Integration

```elixir
defmodule MyApp.AIProcessor do
  use Oban.Worker, queue: :ai_tasks

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"workflow_path" => path}}) do
    System.put_env("TEST_MODE", "live")

    case Pipeline.run(path) do
      {:ok, results} ->
        # Store results in database
        MyApp.Results.save(results)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Enqueue work
%{workflow_path: "pipelines/daily_analysis.yaml"}
|> MyApp.AIProcessor.new()
|> Oban.insert()
```

### 3. Batch Processing Script

```elixir
defmodule Scripts.BatchAnalyzer do
  def run(input_files) do
    System.put_env("TEST_MODE", "live")

    results =
      input_files
      |> Task.async_stream(fn file ->
        workflow = build_workflow_for_file(file)
        Pipeline.execute(workflow)
      end, max_concurrency: 3, timeout: 120_000)
      |> Enum.to_list()

    summarize_results(results)
  end

  defp build_workflow_for_file(file) do
    %{
      "workflow" => %{
        "name" => "analyze_#{Path.basename(file)}",
        "steps" => [...]
      }
    }
  end
end
```

### 4. Testing Integration

```elixir
defmodule MyApp.CodeAnalyzerTest do
  use ExUnit.Case

  setup do
    # Use mock mode for tests
    System.put_env("TEST_MODE", "mock")
    :ok
  end

  test "analyzes code successfully" do
    {:ok, config} = Pipeline.load_workflow("test/fixtures/analyzer.yaml")
    {:ok, results} = Pipeline.execute(config)

    assert results["analyze"]["success"] == true
    assert results["analyze"]["text"] =~ "Mock response"
  end
end
```

## Performance Monitoring

Pipeline execution includes optional performance monitoring:

```elixir
# Enable monitoring (default: true)
{:ok, results} = Pipeline.execute(config, enable_monitoring: true)

# During execution, monitoring GenServer tracks:
# - Memory usage
# - Execution time per step
# - Overall pipeline duration
# - Step counts and errors

# Monitoring stops automatically when pipeline completes
```

Check logs for performance summary:

```
[info] 📊 Performance Summary:
[info]    Duration: 4739ms
[info]    Steps: 2/2
[info]    Peak Memory: 82.4 MB
```

## State Management

### Stateless Execution

Each `Pipeline.execute/2` call:
1. Creates fresh execution context
2. Initializes workspace directories
3. Executes steps sequentially
4. Returns results
5. Cleans up (unless checkpoints enabled)

### Checkpoints (Optional Persistence)

```yaml
workflow:
  name: "long_running_analysis"
  checkpoint_enabled: true
  checkpoint_interval: 5  # Save every 5 steps
```

Checkpoints are **file-based**, not in-memory:
- Saved to `./checkpoints/` by default
- Can resume failed pipelines
- Not for real-time state sharing

### Sessions (File-based Conversations)

```yaml
- name: "chat_step"
  type: "claude_session"
  session_config:
    session_id: "my_conversation"
    checkpoint_dir: "./sessions"
```

Sessions are **file-based**:
- Each session_id maps to checkpoint file
- Can resume conversations across executions
- Not for concurrent access

## Supervision Tree

```
Pipeline.Supervisor (one_for_one)
  └── Registry (Pipeline.MonitoringRegistry)
      └── Pipeline.Monitoring.Performance (per execution, temporary)
```

**Key points:**
- No persistent pipeline workers
- Monitoring GenServers are temporary (created per execution)
- Registry only exists to name monitoring processes
- Clean shutdown when pipeline completes

## Common Patterns

### Pattern 1: Single Workflow, Multiple Invocations

```elixir
# Load once
{:ok, config} = Pipeline.load_workflow("analyzer.yaml")

# Execute many times
for file <- files do
  {:ok, results} = Pipeline.execute(config,
    workspace_dir: "/tmp/analyze_#{file}"
  )
  process_results(results)
end
```

### Pattern 2: Dynamic Workflow Generation

```elixir
defmodule DynamicPipeline do
  def analyze_with_complexity(code, complexity) do
    model = case complexity do
      :simple -> "haiku"
      :moderate -> "sonnet"
      :complex -> "opus"
    end

    workflow = %{
      "workflow" => %{
        "name" => "dynamic_analysis",
        "steps" => [
          %{
            "name" => "analyze",
            "type" => "claude",
            "claude_options" => %{"model" => model},
            "prompt" => [%{"type" => "static", "content" => code}]
          }
        ]
      }
    }

    Pipeline.execute(workflow)
  end
end
```

### Pattern 3: Error Handling with Retries

```elixir
def execute_with_retry(workflow_path, max_attempts \\ 3) do
  Enum.reduce_while(1..max_attempts, {:error, "No attempts"}, fn attempt, _acc ->
    case Pipeline.run(workflow_path) do
      {:ok, results} ->
        {:halt, {:ok, results}}

      {:error, reason} when attempt < max_attempts ->
        Logger.warning("Attempt #{attempt} failed: #{reason}, retrying...")
        Process.sleep(1000 * attempt)  # Exponential backoff
        {:cont, {:error, reason}}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end)
end
```

## Environment Configuration

```elixir
# config/runtime.exs
import Config

config :pipeline,
  workspace_dir: System.get_env("PIPELINE_WORKSPACE_DIR", "./workspace"),
  output_dir: System.get_env("PIPELINE_OUTPUT_DIR", "./outputs"),
  checkpoint_dir: System.get_env("PIPELINE_CHECKPOINT_DIR", "./checkpoints"),
  max_turns_default: 3,
  gemini_timeout_ms: 300_000

# Provider defaults
config :pipeline,
  claude_model: System.get_env("CLAUDE_MODEL", "haiku"),
  gemini_model: System.get_env("GEMINI_MODEL", "gemini-flash-lite-latest")
```

## Summary

| Aspect | Design |
|--------|--------|
| **Architecture** | Library (like Ecto), not service |
| **State** | Stateless per execution, optional file-based checkpoints |
| **Supervision** | Minimal (only monitoring registry) |
| **Concurrency** | Call from multiple processes, each gets independent execution |
| **API Calls** | Mock by default, explicit live mode required |
| **Performance** | Blocking execution, use Task.async_stream for parallelism |
| **Typical Use** | Batch jobs, CI/CD, one-off AI orchestrations |

**Think of it as:** A sophisticated function that orchestrates AI calls and returns results - not a persistent service managing ongoing work.
