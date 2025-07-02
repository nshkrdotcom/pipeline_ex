# Pipeline

[![CI](https://github.com/nshkrdotcom/pipeline_ex/actions/workflows/elixir.yaml/badge.svg)](https://github.com/nshkrdotcom/pipeline_ex/actions/workflows/elixir.yaml)

**AI Pipeline Orchestration Library for Elixir** 

A robust, production-ready library for chaining AI providers (Claude and Gemini) with advanced features like fault tolerance, session management, and self-improving Genesis pipelines. 

**🎯 Library Readiness: 8.5/10** - Ready for immediate use as a Git dependency with comprehensive testing, clean API, and flexible configuration.

<details>
<summary><strong>📋 Remaining 1.5/10 for Full Production Readiness</strong></summary>

**Missing Features (1.5/10):**

1. **Hex Package Publication (0.5/10)** - Currently Git-only, needs `mix hex.publish` workflow
2. **Enhanced Documentation (0.3/10)** - ExDoc polish, API reference examples, getting started guide  
3. **Backward Compatibility (0.2/10)** - Semantic versioning strategy, deprecation warnings, migration guides
4. **Performance Benchmarks (0.2/10)** - Baseline metrics, memory profiling, concurrency benchmarks
5. **Production Hardening (0.3/10)** - Rate limiting, circuit breakers, structured logging with correlation IDs

**Current Status:** 8.5/10 = Excellent for Git dependency | 10/10 = Enterprise-ready Hex package

</details>

## 🧬 Genesis Pipeline: Self-Improving AI System

**NEW**: Our flagship feature - a pipeline that generates pipelines! The Genesis Pipeline is an AI system that creates other AI pipelines, enabling true self-improvement and evolution.

### Quick Start with Genesis

```bash
# Generate a new AI pipeline with one command
mix pipeline.generate.live "Create a sentiment analysis pipeline"

# The system will create a complete, executable pipeline in evolved_pipelines/
# Run your generated pipeline immediately:
mix pipeline.run evolved_pipelines/sentiment_analyzer_*.yaml
```

**What just happened?** The Genesis Pipeline used Claude to analyze your request, design the optimal pipeline structure, and generate a complete YAML configuration that's immediately ready to execute.

## 📦 Library Usage

**Use pipeline_ex as a dependency in your Elixir applications:**

### Add to Your Project

```elixir
# mix.exs
defp deps do
  [
    {:pipeline_ex, git: "https://github.com/nshkrdotcom/pipeline_ex.git", tag: "v0.1.0"}
  ]
end
```

### Simple API

```elixir
# Load and execute a pipeline
{:ok, config} = Pipeline.load_workflow("my_analysis.yaml")
{:ok, results} = Pipeline.execute(config)

# Execute with custom configuration
{:ok, results} = Pipeline.execute(config,
  workspace_dir: "/app/ai_workspace",
  output_dir: "/app/pipeline_outputs"
)

# Convenience function
{:ok, results} = Pipeline.run("my_analysis.yaml", debug: true)

# Health check
case Pipeline.health_check() do
  :ok -> IO.puts("Pipeline system ready")
  {:error, issues} -> IO.puts("Issues: #{inspect(issues)}")
end
```

### Configuration Options

The library supports flexible configuration through multiple sources:

1. **Function options** (highest priority):
   ```elixir
   Pipeline.execute(config, workspace_dir: "/custom/workspace")
   ```

2. **Environment variables**:
   ```bash
   export PIPELINE_WORKSPACE_DIR="/app/workspace"
   export PIPELINE_OUTPUT_DIR="/app/outputs"
   export PIPELINE_CHECKPOINT_DIR="/app/checkpoints"
   ```

3. **YAML configuration** and **defaults**

### Integration Examples

```elixir
# Phoenix controller
defmodule MyAppWeb.AIController do
  def analyze(conn, %{"code" => code}) do
    case Pipeline.run("pipelines/code_analysis.yaml",
      workspace_dir: "/tmp/ai_workspace") do
      {:ok, %{"analysis" => result}} -> 
        json(conn, %{analysis: result})
      {:error, reason} -> 
        put_status(conn, 500) |> json(%{error: reason})
    end
  end
end

# Background job with Oban
defmodule MyApp.AnalysisWorker do
  use Oban.Worker, queue: :ai_analysis
  
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
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
end
```

### Testing Integration

```elixir
# Enable mock mode for development/testing
Application.put_env(:pipeline, :test_mode, true)

# All AI calls will be mocked
{:ok, results} = Pipeline.execute(config)
```

📖 **Complete Library Guide**: See [LIBRARY_build.md](LIBRARY_build.md) for detailed usage instructions, configuration options, and integration patterns.

🚀 **Advanced Features**: See [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) for comprehensive documentation on loops, complex conditions, file operations, data transformation, codebase intelligence, and state management.

## Features

### 📦 Library-Ready
- 🏗️ **Elixir Library**: Use as a dependency in any Elixir application
- 🔧 **Clean API**: Simple `Pipeline.execute/2` and `Pipeline.load_workflow/1` functions
- ⚙️ **Configurable**: All paths and settings customizable via options/environment variables
- 🧪 **Mock Mode**: Complete testing support without API costs
- 🏥 **Health Checks**: Built-in system validation and monitoring

### 🤖 AI Integration
- 🤖 **Multi-AI Integration**: Chain Claude and Gemini APIs together
- 🔄 **Flexible Execution Modes**: Mock, Live, and Mixed modes for testing
- 📋 **YAML Workflow Configuration**: Define complex multi-step workflows
- 🎯 **Structured Output**: JSON-based responses with proper error handling
- 🔧 **InstructorLite Integration**: Structured generation with Gemini
- 📊 **Result Management**: Organized output storage and display

### ⚡ Advanced Features
- **Enhanced Claude Steps**: Smart presets, sessions, extraction, batch processing, robust error handling
- **Genesis Pipeline**: Self-improving AI system that generates other pipelines
- **Session Management**: Persistent conversations with automatic checkpointing
- **Fault Tolerance**: Retry mechanisms, circuit breakers, graceful degradation
- **Loop Constructs**: For/while loops with parallel execution and nested support
- **Complex Conditions**: Boolean logic, comparisons, mathematical expressions
- **File Operations**: Copy, move, validate, convert with format transformations
- **Data Transformation**: Filter, aggregate, join with schema validation
- **Codebase Intelligence**: Project discovery, code analysis, dependency mapping
- **State Management**: Variables, interpolation, checkpoints with persistence

📚 **See [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) for detailed documentation and examples of all advanced capabilities.**

## Quick Start

### 1. Installation

#### As a Library Dependency (Recommended)

```elixir
# mix.exs
defp deps do
  [
    {:pipeline_ex, git: "https://github.com/nshkrdotcom/pipeline_ex.git", tag: "v0.1.0"}
  ]
end
```

#### Standalone Development

```bash
git clone <repository>
cd pipeline_ex
mix deps.get
```

### 2. Try the Showcase (Recommended)

**🌟 Start with one of these commands:**

```bash
# Mock mode (safe, free, fast)
mix showcase               # Complete demo with mocks

# Live mode (real API calls, costs money)
mix showcase --live        # Complete demo with live APIs
```

### 🎭 Mock vs Live Mode

**All examples and tests can run in two modes:**

| **Mode** | **Command Format** | **API Calls** | **Costs** | **Authentication Required** |
|----------|-------------------|---------------|-----------|---------------------------|
| **Mock** | `mix showcase` | None (mocked) | $0.00 | No |
| **Live** | `mix showcase --live` | Real API calls | Real costs | Yes (`claude login`) |

## Running Tests

### Mock Mode (Recommended)
```bash
mix test                       # All tests with mocked APIs (fast, free)
```

### Live Mode (Real API Calls)
```bash
# Setup authentication first:
export GEMINI_API_KEY="your_api_key"
claude login

# Run tests with real APIs:
mix pipeline.test.live         # Only integration tests with live APIs (costs money)
```

## Execution Modes

The pipeline supports three execution modes controlled by the `TEST_MODE` environment variable:

| Mode | Description | Use Case |
|------|-------------|----------|
| `mock` | Uses fake responses | Development, unit testing, CI/CD |
| `live` | Uses real API calls | Production, integration testing |
| `mixed` | Mocks for unit tests, live for integration | Hybrid testing approach |

### Mode Examples

```bash
# Mock mode - fast, no API costs
mix pipeline.run examples/comprehensive_config_example.yaml

# Live mode - real AI responses  
mix pipeline.run.live examples/comprehensive_config_example.yaml

# Mixed mode - context-dependent
TEST_MODE=mixed mix test
```

## Configuration

### API Keys

#### Claude
Claude uses the authenticated CLI. Run once:
```bash
claude login
```

#### Gemini
Set your API key:
```bash
export GEMINI_API_KEY="your_gemini_api_key_here"
```

Or in your application config:
```elixir
config :pipeline, gemini_api_key: "your_api_key"
```

### Workflow Configuration

Create YAML workflow files like `test_simple_workflow.yaml`:

```yaml
workflow:
  name: "simple_test_workflow"
  description: "Test basic claude functionality"
  
  steps:
    - name: "analyze_code"
      type: "claude"
      prompt: 
        - type: "static"
          content: |
            Analyze this simple Python function and provide feedback:
            
            def add(a, b):
                return a + b
            
            Please provide your analysis in JSON format.
      
    - name: "plan_improvements"
      type: "gemini"  
      prompt:
        - type: "static"
          content: |
            Based on the previous analysis, create a plan to improve the function.
            Consider error handling, type hints, and documentation.
```

## Example Usage

### Library Usage in Your Application

```elixir
defmodule MyApp.AIProcessor do
  @doc "Analyze code using the pipeline library"
  def analyze_code(code_content) do
    # Load your pipeline configuration
    case Pipeline.load_workflow("pipelines/code_analysis.yaml") do
      {:ok, config} ->
        # Execute with custom workspace
        Pipeline.execute(config,
          workspace_dir: "/tmp/ai_workspace",
          debug: true
        )
      {:error, reason} ->
        {:error, "Failed to load workflow: #{reason}"}
    end
  end
  
  @doc "Health check for the AI system"
  def system_ready? do
    case Pipeline.health_check() do
      :ok -> true
      {:error, _issues} -> false
    end
  end
end

# Usage in your application
{:ok, analysis} = MyApp.AIProcessor.analyze_code(user_code)
IO.inspect(analysis["analysis_step"])
```

### Simple Script Example

```elixir
#!/usr/bin/env elixir

Mix.install([
  {:pipeline_ex, git: "https://github.com/nshkrdotcom/pipeline_ex.git"}
])

# Load and execute pipeline
case Pipeline.run("test_simple_workflow.yaml", output_dir: "outputs") do
  {:ok, results} ->
    IO.puts("✅ Pipeline completed!")
    IO.inspect(results)
    
  {:error, reason} ->
    IO.puts("❌ Pipeline failed: #{reason}")
end
```

### Testing Different Scenarios

```bash
# Test with mock responses (fast)
TEST_MODE=mock elixir run_example.exs

# Test with real Claude + mock Gemini
# (useful when you have Claude access but no Gemini API key)
TEST_MODE=mixed elixir -e "
System.put_env(\"FORCE_MOCK_GEMINI\", \"true\")
Code.compile_file(\"run_example.exs\")
"

# Full live test (requires both API keys)
elixir run_example.exs
```

## Running the Comprehensive Example

The project includes a comprehensive configuration example that demonstrates **all available features** with minimal steps. This example showcases every configuration option, step type, and feature available in the pipeline system.

### Mock Mode (Safe, No API Keys Required)

```bash
# Run the comprehensive example with mocked AI responses
mix pipeline.run examples/comprehensive_config_example.yaml

# Run with debug output to see detailed execution
PIPELINE_DEBUG=true mix pipeline.run examples/comprehensive_config_example.yaml
```

### Live Mode (Real AI Providers)

To run the comprehensive example with actual AI providers:

#### 1. Set Up API Keys

```bash
# Set your Gemini API key (get from https://aistudio.google.com/)
export GEMINI_API_KEY="your_gemini_api_key_here"

# Authenticate Claude CLI (pre-authenticated, no API key needed)
claude auth
```

#### 2. Run in Live Mode

```bash
# Run with real AI providers
mix pipeline.run.live examples/comprehensive_config_example.yaml

# Run with full debug logging
PIPELINE_DEBUG=true PIPELINE_LOG_LEVEL=debug mix pipeline.run.live examples/comprehensive_config_example.yaml
```

### What the Comprehensive Example Demonstrates

The `examples/comprehensive_config_example.yaml` shows:

- ✅ **Basic step types**: `gemini`, `claude`, `parallel_claude`, `gemini_instructor`
- ✅ **Enhanced Claude steps**: `claude_smart`, `claude_session`, `claude_extract`, `claude_batch`, `claude_robust`
- ✅ **Function calling**: Gemini with structured function definitions
- ✅ **All Claude tools**: Write, Edit, Read, Bash, Search, Glob, Grep
- ✅ **Parallel execution**: Multiple Claude instances running simultaneously
- ✅ **Conditional steps**: Steps that run based on previous results
- ✅ **All prompt types**: Static content, file content, previous responses
- ✅ **Workspace management**: Sandboxed file operations
- ✅ **Token budgets**: Fine-tuned AI response configurations
- ✅ **Model selection**: Different AI models for different tasks
- ✅ **Output management**: Structured result saving and organization

## Enhanced Claude Step Types

The pipeline includes five advanced Claude step types that extend the basic `claude` step with specialized capabilities:

### 🎯 Claude Smart (`claude_smart`)
Intelligent preset-based configuration with environment awareness.
- **Presets**: `development`, `production`, `analysis`, `chat`, `test`
- **Auto-optimization**: Preset-specific tool restrictions and performance tuning
- **Environment detection**: Automatic preset selection based on Mix environment

```yaml
- name: "smart_analysis" 
  type: "claude_smart"
  preset: "analysis"  # Uses analysis-optimized settings
  prompt: [...]
```

### 🗣️ Claude Session (`claude_session`)
Persistent conversation management with session state.
- **Session persistence**: Continue conversations across multiple steps
- **Automatic checkpointing**: Save session state for recovery
- **Turn management**: Configurable conversation length limits

```yaml
- name: "session_start"
  type: "claude_session" 
  session_name: "math_tutor"
  session_config:
    persist: true
    max_turns: 50
```

### 📄 Claude Extract (`claude_extract`)
Advanced content extraction and post-processing.
- **Output formats**: `json`, `markdown`, `structured`, `summary`
- **Post-processing**: Extract code blocks, recommendations, links, key points
- **Content filtering**: Apply extraction rules and transformations

```yaml
- name: "extract_json"
  type: "claude_extract"
  preset: "analysis"
  extraction_config:
    format: "json"
    post_processing: ["extract_code_blocks", "extract_recommendations"]
    include_metadata: true
```

### ⚡ Claude Batch (`claude_batch`)
Parallel task execution with load balancing.
- **Concurrent processing**: Run multiple Claude queries simultaneously
- **Task management**: Queue and execute independent tasks
- **Performance scaling**: Configurable parallelism limits

```yaml
- name: "batch_analysis"
  type: "claude_batch"
  batch_config:
    max_parallel: 3
    tasks:
      - id: "task1"
        prompt: "Analyze JavaScript code..."
      - id: "task2" 
        prompt: "Analyze Python code..."
```

### 🛡️ Claude Robust (`claude_robust`)
Enterprise-grade error recovery and fault tolerance.
- **Retry mechanisms**: Configurable backoff strategies
- **Fallback actions**: Graceful degradation options
- **Circuit breaker**: Prevent cascade failures

```yaml
- name: "robust_analysis"
  type: "claude_robust"
  retry_config:
    max_retries: 3
    backoff_strategy: "exponential"
    fallback_action: "simplified_prompt"
```

### Testing Enhanced Step Types

Each enhanced step type has dedicated example files for testing:

```bash
# Test individual enhanced step types
mix pipeline.run.live examples/claude_smart_example.yaml
mix pipeline.run.live examples/claude_session_example.yaml  
mix pipeline.run.live examples/claude_extract_example.yaml
mix pipeline.run.live examples/claude_batch_example.yaml
mix pipeline.run.live examples/claude_robust_example.yaml

# Or run all enhanced examples in mock mode (free)
mix pipeline.run examples/claude_smart_example.yaml
mix pipeline.run examples/claude_session_example.yaml
# ... etc
```

### Environment Configuration

For advanced configuration, you can set these environment variables:

```bash
# API Configuration
export GEMINI_API_KEY="your_gemini_api_key"
# Note: Claude uses CLI authentication (claude auth), no API key needed

# Pipeline Directories
export PIPELINE_WORKSPACE_DIR="./workspace"     # Claude's sandbox
export PIPELINE_OUTPUT_DIR="./outputs"          # Result storage
export PIPELINE_CHECKPOINT_DIR="./checkpoints"  # State management

# Logging and Debug
export PIPELINE_LOG_LEVEL="debug"               # debug, info, warn, error
export PIPELINE_DEBUG="true"                    # Detailed execution logs

# Execution Mode
export TEST_MODE="live"                          # live, mock, mixed
```

### Creating Your Own Workflows

1. **Start with the example**: Copy `examples/comprehensive_config_example.yaml`
2. **Read the guides**: 
   - [Pipeline Configuration Guide](PIPELINE_CONFIG_GUIDE.md) for basic configuration
   - [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) for loops, conditions, file operations, and more
   - [TESTING_STRATEGY.md](TESTING_STRATEGY.md) for comprehensive testing approaches
3. **Test in mock mode**: Validate your workflow logic without API costs
4. **Run live**: Execute with real AI providers when ready

## Development

### Running the Example

The `run_example.exs` script demonstrates the pipeline:

```bash
# Quick test with mocks
TEST_MODE=mock elixir run_example.exs

# Full test with APIs
elixir run_example.exs
```

### Test Structure

```
test/
├── unit/           # Fast unit tests (mocked)
├── integration/    # Integration tests (live APIs) 
├── fixtures/       # Test data and workflows
└── support/        # Test helpers
```

### Adding New Tests

```elixir
defmodule MyTest do
  use ExUnit.Case
  use Pipeline.TestCase  # Provides test mode helpers
  
  test "my feature works in mock mode" do
    # Test automatically uses mocks
    assert Pipeline.execute_something() == expected_result
  end
end
```

## Debugging

Enable debug output:

```bash
# See detailed execution logs
DEBUG=true elixir run_example.exs

# See API request/response details
VERBOSE=true elixir run_example.exs
```

Debug output includes:
- Step execution flow
- API request/response details
- Provider selection (mock vs live)
- Result processing

## Common Issues

### Claude CLI Not Authenticated
```bash
# Error: Claude CLI not found or not authenticated
claude login
```

### Missing Gemini API Key
```bash
# Error: GEMINI_API_KEY environment variable not set
export GEMINI_API_KEY="your_key_here"
```

### Mixed Results (Some Success, Some Failure)
```bash
# Check which providers are mocked vs live
TEST_MODE=mock elixir run_example.exs  # All mocked
TEST_MODE=live elixir run_example.exs  # All live
```

## License

TODO: Add license information