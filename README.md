# Pipeline

A flexible Elixir pipeline for chaining AI providers (Claude and Gemini) with support for both live API calls and mocked responses for testing.

## Features

- 🤖 **Multi-AI Integration**: Chain Claude and Gemini APIs together
- 🔄 **Flexible Execution Modes**: Mock, Live, and Mixed modes for testing
- 📋 **YAML Workflow Configuration**: Define complex multi-step workflows
- 🎯 **Structured Output**: JSON-based responses with proper error handling
- 🔧 **InstructorLite Integration**: Structured generation with Gemini
- 📊 **Result Management**: Organized output storage and display

## Quick Start

### 1. Installation

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
TEST_MODE=mock elixir run_example.exs

# Live mode - real AI responses
TEST_MODE=live elixir run_example.exs

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

### Simple Script Example

```elixir
#!/usr/bin/env elixir

Mix.install([
  {:pipeline, path: "."}
])

# Load workflow
{:ok, config} = Pipeline.Config.load_workflow("test_simple_workflow.yaml")

# Execute pipeline
case Pipeline.Executor.execute(config, output_dir: "outputs") do
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