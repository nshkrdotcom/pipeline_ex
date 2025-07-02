# Pipeline Library Build Guide

## Overview

This document explains how to build and use `pipeline_ex` as a library dependency in your Elixir applications. The library provides a robust AI pipeline orchestration framework with support for Claude and Gemini providers.

## Library Readiness Score: 8.5/10 ✅

Pipeline_ex is well-architected for library usage with the following strengths:

### ✅ Excellent Library Features
- **Clean API**: Primary functions available at `Pipeline.execute/2` and `Pipeline.load_workflow/1`
- **Configurable**: All paths and settings can be overridden via options or environment variables
- **Robust Testing**: Comprehensive mock system for library consumers
- **Provider Abstraction**: Easy to swap AI providers or add new ones
- **Error Handling**: Proper error returns with detailed context

### ✅ Production Ready
- **No Hardcoded Paths**: All directories configurable via options/environment
- **Hex Package Ready**: Complete package configuration in `mix.exs`
- **Documentation**: Comprehensive module docs with examples
- **Health Checks**: Built-in system validation

## Quick Start

### 1. Add Dependency

```elixir
# mix.exs
defp deps do
  [
    {:pipeline_ex, git: "https://github.com/nshkrdotcom/pipeline_ex.git", tag: "v0.1.0"}
  ]
end
```

### 2. Basic Usage

```elixir
# Load and execute a pipeline
{:ok, config} = Pipeline.load_workflow("my_analysis.yaml")
{:ok, results} = Pipeline.execute(config)

# Or use the convenience function
{:ok, results} = Pipeline.run("my_analysis.yaml")
```

### 3. Custom Configuration

```elixir
# Execute with custom directories
{:ok, results} = Pipeline.execute(config,
  workspace_dir: "/app/ai_workspace",
  output_dir: "/app/pipeline_outputs",
  checkpoint_dir: "/app/checkpoints"
)
```

## Configuration Options

### Directory Configuration

The library supports flexible directory configuration through multiple sources:

1. **Function Options** (highest priority):
   ```elixir
   Pipeline.execute(config, workspace_dir: "/custom/workspace")
   ```

2. **Environment Variables**:
   ```bash
   export PIPELINE_WORKSPACE_DIR="/app/workspace"
   export PIPELINE_OUTPUT_DIR="/app/outputs"
   export PIPELINE_CHECKPOINT_DIR="/app/checkpoints"
   ```

3. **YAML Configuration**:
   ```yaml
   workflow:
     workspace_dir: "./workspace"
     checkpoint_dir: "./checkpoints"
     defaults:
       output_dir: "./outputs"
   ```

4. **Defaults**: `./workspace`, `./outputs`, `./checkpoints`

### Provider Configuration

```elixir
# Environment variables for AI providers
export GEMINI_API_KEY="your-gemini-key"
# Claude uses the claude CLI tool
```

## Testing Integration

### Mock Mode for Development

```elixir
# In your test environment
Application.put_env(:pipeline, :test_mode, true)

# All AI calls will be mocked
{:ok, results} = Pipeline.execute(config)
```

### Health Checks

```elixir
case Pipeline.health_check() do
  :ok -> 
    IO.puts("Pipeline system ready")
  {:error, issues} -> 
    IO.puts("Issues: #{inspect(issues)}")
end
```

## Integration Examples

### Phoenix Application

```elixir
# lib/my_app/ai_service.ex
defmodule MyApp.AIService do
  def analyze_code(code_content) do
    case Pipeline.run("pipelines/code_analysis.yaml", 
      workspace_dir: "/tmp/ai_workspace") do
      {:ok, %{"analysis" => result}} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end

# lib/my_app_web/controllers/ai_controller.ex
defmodule MyAppWeb.AIController do
  def analyze(conn, %{"code" => code}) do
    case MyApp.AIService.analyze_code(code) do
      {:ok, analysis} -> json(conn, %{analysis: analysis})
      {:error, reason} -> put_status(conn, 500) |> json(%{error: reason})
    end
  end
end
```

### Background Job

```elixir
# lib/my_app/workers/analysis_worker.ex
defmodule MyApp.AnalysisWorker do
  use Oban.Worker, queue: :ai_analysis
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    project = MyApp.Projects.get_project!(project_id)
    
    # Execute pipeline with project-specific workspace
    case Pipeline.execute(get_analysis_config(), 
      workspace_dir: "/tmp/analysis_#{project_id}",
      output_dir: "/app/results/#{project_id}") do
      {:ok, results} -> 
        MyApp.Projects.update_analysis(project, results)
        :ok
      {:error, reason} -> 
        {:error, reason}
    end
  end
  
  defp get_analysis_config do
    {:ok, config} = Pipeline.load_workflow("pipelines/project_analysis.yaml")
    config
  end
end
```

### GenServer Integration

```elixir
defmodule MyApp.PipelineServer do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def analyze_async(data) do
    GenServer.cast(__MODULE__, {:analyze, data})
  end
  
  @impl true
  def init(opts) do
    workspace_dir = Keyword.get(opts, :workspace_dir, "/tmp/pipeline_workspace")
    {:ok, %{workspace_dir: workspace_dir}}
  end
  
  @impl true
  def handle_cast({:analyze, data}, state) do
    # Execute pipeline asynchronously
    Task.start(fn ->
      case Pipeline.run("pipelines/analysis.yaml",
        workspace_dir: state.workspace_dir) do
        {:ok, results} -> 
          # Handle results
          MyApp.PubSub.broadcast("analysis_complete", results)
        {:error, reason} -> 
          # Handle error
          MyApp.PubSub.broadcast("analysis_error", reason)
      end
    end)
    
    {:noreply, state}
  end
end
```

## Error Handling

```elixir
case Pipeline.execute(config) do
  {:ok, results} ->
    # Success - results is a map with step names as keys
    analysis = results["analysis_step"]
    
  {:error, reason} ->
    # Error - reason contains detailed error information
    Logger.error("Pipeline failed: #{reason}")
end
```

## Performance Considerations

### Directory Management
- Use absolute paths for better performance
- Ensure workspace directories have proper permissions
- Clean up temporary workspaces after use

### Resource Usage
- Pipelines create temporary files during execution
- Memory usage scales with pipeline complexity
- Consider using separate workspaces for concurrent executions

### Concurrency
- Library is designed for concurrent execution
- Each pipeline execution is isolated
- Use different workspace directories for parallel jobs

## Troubleshooting

### Common Issues

1. **Permission Errors**:
   ```bash
   # Ensure workspace directories are writable
   chmod 755 /path/to/workspace
   ```

2. **Missing API Keys**:
   ```elixir
   # Check environment variables
   System.get_env("GEMINI_API_KEY")
   ```

3. **Claude CLI Not Found**:
   ```bash
   # Install Claude CLI for live mode
   # Or use mock mode for development
   ```

### Debug Mode

```elixir
# Enable debug logging
{:ok, results} = Pipeline.execute(config, debug: true)
```

## Building for Production

### Environment Setup

```bash
# Production environment variables
export PIPELINE_WORKSPACE_DIR="/app/pipeline_workspace"
export PIPELINE_OUTPUT_DIR="/app/pipeline_outputs"
export PIPELINE_CHECKPOINT_DIR="/app/checkpoints"
export GEMINI_API_KEY="your-production-key"
```

### Directory Structure

```
/app/
├── pipeline_workspace/    # AI workspace operations
├── pipeline_outputs/      # Saved results
├── checkpoints/          # Session checkpoints
└── pipelines/            # YAML pipeline definitions
```

### Health Monitoring

```elixir
# Add to your application health check
def health_check do
  case Pipeline.health_check() do
    :ok -> :ok
    {:error, issues} -> {:error, {:pipeline_issues, issues}}
  end
end
```

## Next Steps

1. **Create Your Pipelines**: Write YAML pipeline definitions
2. **Test Integration**: Use mock mode for development
3. **Deploy**: Configure production environment
4. **Monitor**: Add health checks and logging
5. **Scale**: Use separate workspaces for concurrent jobs

## Support

For issues and questions:
- Check the test suite in `test/pipeline_library_test.exs` for usage examples
- Review existing pipeline configurations in the `pipelines/` directory
- Use `Pipeline.health_check/0` to validate your setup