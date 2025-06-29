# Testing Architecture & Development Guide

## Overview

This document outlines the comprehensive testing strategy for the pipeline orchestration system, providing elegant mock/live mode management and robust test coverage for all components.

## Core Testing Principles

### 1. Clear Separation of Concerns
- **Business Logic**: Tested with mocks for external dependencies
- **Integration Points**: Tested with both mocks and live services
- **End-to-End Flows**: Tested in controlled environments

### 2. Environment-Based Testing
- **Unit Tests**: Always use mocks (fast, reliable, no external deps)
- **Integration Tests**: Can use mocks or live services based on configuration
- **E2E Tests**: Use live services in staging environments

### 3. Dependency Injection Pattern
- All external service interactions go through provider interfaces
- Providers can be swapped between mock and live implementations
- Configuration determines which provider to use

## Testing Architecture

### Provider Interface Pattern

```elixir
# All external services implement a provider behavior
defmodule Pipeline.Providers.AIProvider do
  @callback query(prompt :: String.t(), options :: map()) :: 
    {:ok, response :: map()} | {:error, reason :: String.t()}
end

# Live implementation
defmodule Pipeline.Providers.ClaudeProvider do
  @behaviour Pipeline.Providers.AIProvider
  
  def query(prompt, options) do
    # Real Claude SDK calls
  end
end

# Mock implementation  
defmodule Pipeline.Test.Mocks.ClaudeProvider do
  @behaviour Pipeline.Providers.AIProvider
  
  def query(prompt, options) do
    # Deterministic mock responses
  end
end
```

### Configuration-Driven Provider Selection

```elixir
# config/test.exs
config :pipeline, :providers, %{
  ai_provider: Pipeline.Test.Mocks.ClaudeProvider,
  gemini_provider: Pipeline.Test.Mocks.GeminiProvider
}

# config/dev.exs
config :pipeline, :providers, %{
  ai_provider: Pipeline.Providers.ClaudeProvider,
  gemini_provider: Pipeline.Providers.GeminiProvider
}
```

### Test Mode Management

```elixir
# Environment variable controls test mode
# TEST_MODE=mock mix test          # Uses mocks
# TEST_MODE=live mix test          # Uses live services  
# TEST_MODE=mixed mix test         # Uses mocks for unit, live for integration

defmodule Pipeline.TestMode do
  def provider_for(service) do
    case get_test_mode() do
      :mock -> mock_provider(service)
      :live -> live_provider(service)
      :mixed -> mixed_provider(service)
    end
  end
  
  defp get_test_mode do
    System.get_env("TEST_MODE", "mock") |> String.to_atom()
  end
end
```

## Mock Implementation Strategy

### 1. Deterministic Responses
```elixir
defmodule Pipeline.Test.Mocks.ClaudeProvider do
  @behaviour Pipeline.Providers.AIProvider
  
  # Predictable responses based on input patterns
  def query("simple test", _opts) do
    {:ok, %{
      text: "Mock response for simple test",
      success: true,
      cost: 0.001
    }}
  end
  
  def query("error test", _opts) do
    {:error, "Mock error for testing"}
  end
  
  # Pattern matching for common scenarios
  def query(prompt, _opts) when is_binary(prompt) do
    {:ok, %{
      text: "Mock response for: #{String.slice(prompt, 0, 50)}...",
      success: true,
      cost: 0.001
    }}
  end
end
```

### 2. Stateful Mocks for Complex Scenarios
```elixir
defmodule Pipeline.Test.Mocks.StatefulClaudeProvider do
  use GenServer
  @behaviour Pipeline.Providers.AIProvider
  
  # Track conversation state, turn counts, etc.
  def query(prompt, options) do
    GenServer.call(__MODULE__, {:query, prompt, options})
  end
  
  def handle_call({:query, prompt, options}, _from, state) do
    # Simulate turn limits, state transitions, etc.
    {response, new_state} = generate_response(prompt, options, state)
    {:reply, response, new_state}
  end
end
```

### 3. Scenario-Based Testing
```elixir
defmodule Pipeline.Test.Scenarios do
  def setup_successful_workflow do
    # Configure mocks for a complete successful workflow
    Pipeline.Test.Mocks.ClaudeProvider.set_responses([
      "Create a Python hello world program",
      "Add error handling to the program", 
      "Write unit tests for the program"
    ])
  end
  
  def setup_failure_scenario do
    # Configure mocks to simulate various failure modes
    Pipeline.Test.Mocks.ClaudeProvider.set_error_on_turn(2, "API rate limit exceeded")
  end
end
```

## Test Organization

### Directory Structure
```
test/
├── unit/                    # Fast, isolated tests with mocks
│   ├── pipeline/
│   │   ├── executor_test.exs
│   │   ├── step/
│   │   │   ├── claude_test.exs
│   │   │   └── gemini_test.exs
│   │   └── workflow_loader_test.exs
│   └── support/
├── integration/             # Cross-component tests
│   ├── end_to_end_test.exs
│   ├── workflow_execution_test.exs
│   └── provider_integration_test.exs
├── fixtures/                # Test data and configurations
│   ├── workflows/
│   │   ├── simple_workflow.yaml
│   │   └── complex_workflow.yaml
│   └── responses/
│       ├── claude_responses.json
│       └── gemini_responses.json
└── support/                 # Test helpers and utilities
    ├── test_case.exs
    ├── factory.ex
    └── mocks/
        ├── claude_provider.ex
        └── gemini_provider.ex
```

### Test Categories

#### Unit Tests (Always Mocked)
```elixir
defmodule Pipeline.ExecutorTest do
  use Pipeline.Test.Case, mode: :mock
  
  test "executes workflow steps in sequence" do
    workflow = build(:simple_workflow)
    
    assert {:ok, results} = Pipeline.Executor.execute(workflow)
    assert length(results) == 3
  end
end
```

#### Integration Tests (Configurable)
```elixir
defmodule Pipeline.WorkflowExecutionTest do
  use Pipeline.Test.Case, mode: :configurable
  
  @tag :integration
  test "complete workflow execution" do
    workflow = load_fixture("workflows/simple_workflow.yaml")
    
    assert {:ok, results} = Pipeline.Executor.execute(workflow)
    assert results["final_step"]["success"] == true
  end
end
```

#### Live Tests (Live Services Only)
```elixir
defmodule Pipeline.LiveIntegrationTest do
  use Pipeline.Test.Case, mode: :live
  
  @tag :live
  @tag timeout: 30_000
  test "actual Claude API integration" do
    # Only runs with TEST_MODE=live or TEST_MODE=mixed
    prompt = "Write a simple hello world in Python"
    
    assert {:ok, response} = Pipeline.Providers.ClaudeProvider.query(prompt, %{})
    assert response.success == true
    assert is_binary(response.text)
  end
end
```

## Mock Data Management

### Response Fixtures
```elixir
# test/fixtures/responses/claude_responses.json
{
  "simple_python_program": {
    "text": "print('Hello, World!')\n\n# This is a simple Python program...",
    "success": true,
    "cost": 0.0023
  },
  "code_review": {
    "text": "Code review feedback:\n1. Consider adding type hints...",
    "success": true, 
    "cost": 0.0156
  }
}
```

### Factory Pattern
```elixir
defmodule Pipeline.Test.Factory do
  def build(:workflow) do
    %{
      "workflow" => %{
        "name" => "test_workflow",
        "steps" => [
          build(:claude_step),
          build(:gemini_step)
        ]
      }
    }
  end
  
  def build(:claude_step) do
    %{
      "name" => "claude_task",
      "type" => "claude",
      "prompt" => [%{"type" => "static", "content" => "Test prompt"}]
    }
  end
end
```

## Running Tests

### Command Examples
```bash
# Unit tests only (fast, always mocked)
mix test test/unit/

# Integration tests with mocks
TEST_MODE=mock mix test test/integration/

# Integration tests with live services
TEST_MODE=live mix test test/integration/ --include live

# All tests with mixed mode
TEST_MODE=mixed mix test

# Specific test scenarios
mix test --only integration
mix test --only live
mix test --exclude live  # Skip live tests
```

### Continuous Integration
```bash
# CI pipeline uses mocks for speed and reliability
TEST_MODE=mock mix test --coverage

# Nightly build runs live tests
TEST_MODE=live mix test --include live --timeout 300000
```

## Development Workflow

### 1. Writing New Features
1. Start with unit tests using mocks
2. Implement the feature with provider interfaces
3. Add integration tests that work with mocks
4. Test with live services locally
5. Update mock responses based on live behavior

### 2. Debugging Issues  
1. Reproduce with mocks first (faster iteration)
2. Compare mock vs live behavior
3. Update mocks to match live service behavior
4. Fix implementation based on findings

### 3. Adding New External Services
1. Define provider behavior/interface
2. Create mock implementation
3. Implement live provider
4. Add configuration switching
5. Write comprehensive tests for both

## Quality Assurance

### Test Coverage Requirements
- **Unit Tests**: 95% line coverage minimum
- **Integration Tests**: All critical paths covered
- **Mock Accuracy**: Regular validation against live services

### Performance Benchmarks
```elixir
defmodule Pipeline.Test.Performance do
  use ExUnit.Case
  
  @tag :benchmark
  test "workflow execution performance" do
    workflow = build(:complex_workflow)
    
    {time, _result} = :timer.tc(fn ->
      Pipeline.Executor.execute(workflow)
    end)
    
    # Workflow should complete within 5 seconds with mocks
    assert time < 5_000_000  # microseconds
  end
end
```

### Mock Validation
```elixir
# Periodically validate mocks against live services
defmodule Pipeline.Test.MockValidation do
  @tag :validation
  test "mock responses match live service behavior" do
    test_cases = load_validation_cases()
    
    for test_case <- test_cases do
      mock_response = MockProvider.query(test_case.prompt, test_case.options)
      live_response = LiveProvider.query(test_case.prompt, test_case.options)
      
      assert_responses_equivalent(mock_response, live_response)
    end
  end
end
```

## Best Practices

### 1. Mock Design
- **Deterministic**: Same input always produces same output
- **Realistic**: Mirror real service behavior patterns
- **Fast**: No network calls, minimal computation
- **Comprehensive**: Cover error cases and edge conditions

### 2. Test Data
- **Version Controlled**: All fixtures in git
- **Realistic**: Based on actual service responses
- **Minimal**: Only include necessary data
- **Documented**: Clear comments explaining test scenarios

### 3. Configuration
- **Environment Driven**: Use env vars for mode selection
- **Default Safe**: Default to mocks for safety
- **Override Capable**: Easy to switch modes for debugging
- **CI Friendly**: Reliable in automated environments

This testing architecture provides a robust foundation for developing and maintaining the pipeline orchestration system with confidence in both mocked and live environments.