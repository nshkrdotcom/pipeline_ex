# Elixir Pipeline Orchestration - Test Planning Document

## 1. Feature Coverage Analysis

### Feature Compliance Matrix

| Feature Category | Feature | Status | Test Priority |
|-----------------|---------|---------|---------------|
| **Core Workflow** | | | |
| | YAML parsing | ✅ Implemented | High |
| | Step execution | ✅ Implemented | High |
| | Conditional steps | ✅ Implemented | High |
| | Checkpoint save | ✅ Implemented | Medium |
| | Checkpoint resume | ❌ Not implemented | Low |
| | Error handling | ✅ Implemented | High |
| **Prompt Templates** | | | |
| | Static content | ✅ Implemented | High |
| | File loading | ✅ Implemented | High |
| | Previous response | ✅ Implemented | High |
| | Field extraction | ⚠️ Partial | Medium |
| **Gemini Features** | | | |
| | Model selection | ✅ Implemented | High |
| | Token budgets | ✅ Implemented | High |
| | Basic generation | ✅ Implemented | High |
| | Function calling | ⚠️ Partial | Low |
| | Function definitions | ❌ Not parsed | Low |
| **Claude Features** | | | |
| | Workspace sandbox | ✅ Implemented | Critical |
| | Max turns | ✅ Implemented | High |
| | Allowed tools | ✅ Implemented | High |
| | Output formats (json/text) | ✅ Implemented | High |
| | Stream-json format | ❌ Not implemented | Low |
| | CWD setting | ✅ Implemented | Critical |
| | Verbose mode | ✅ Implemented | Low |
| | System prompt | ✅ Implemented | Medium |
| **Parallel Execution** | | | |
| | Parallel Claude | ✅ Implemented | Medium |
| | Result aggregation | ✅ Implemented | Medium |
| | Error isolation | ⚠️ Needs testing | High |
| **Output & Debug** | | | |
| | Debug logging | ✅ Implemented | High |
| | Output files | ✅ Implemented | High |
| | Workspace tracking | ✅ Implemented | Medium |
| | Debug viewer | ✅ Implemented | Medium |

### ✅ Implemented Features

Based on the Pipeline Configuration Technical Guide, here's what we've implemented:

#### Core Features
- [x] YAML configuration parsing
- [x] Workflow execution engine
- [x] Step types: `gemini`, `claude`, `parallel_claude`
- [x] Prompt templates: `static`, `file`, `previous_response`
- [x] Token budget management for Gemini
- [x] Output file saving
- [x] Debug logging
- [x] Workspace sandboxing

#### Configuration Support
- [x] `workflow.name`
- [x] `workflow.checkpoint_enabled`
- [x] `workflow.workspace_dir`
- [x] `workflow.defaults`
- [x] `workflow.steps`
- [x] Step conditions
- [x] Claude options (all CLI flags)
- [x] Gemini model selection
- [x] Token budget overrides

### ⚠️ Partially Implemented Features

- [ ] **Function Calling (Gemini)**: Basic structure exists but needs full implementation
  - Current: Fallback to regular generation
  - Needed: Actual function parsing and execution
  
- [ ] **Checkpoint Resume**: Save works, but resume not implemented
  - Current: Saves checkpoint files
  - Needed: Load and resume from checkpoint

### ❌ Not Yet Implemented

- [ ] **Field Extraction**: `previous_response` with `extract` field
  - Current: Basic implementation exists
  - Issue: Needs better nested field access
  
- [ ] **Gemini Functions Definition**: `workflow.gemini_functions`
  - Not parsed or used in execution

- [ ] **Stream-JSON Output Format**: For Claude
  - Current: Only json and text
  - Needed: Streaming JSON support

- [ ] **Additional Claude Options**:
  - [ ] `permission_prompt_tool`
  - [ ] `permission_mode`
  - [ ] `executable` / `executable_args`
  
- [ ] **Resume from Checkpoint**: Load and continue workflow
  - Current: Only saves checkpoints
  - Needed: `--resume` functionality

## 2. Testing Strategy

### 2.1 Unit Testing Approach

#### Module Testing Hierarchy

```
1. Foundation Layer (no dependencies)
   - Pipeline.Config
   - Pipeline.Debug
   - Pipeline.PromptBuilder

2. Integration Layer (depends on foundation)
   - Pipeline.Step.Gemini
   - Pipeline.Step.Claude
   - Pipeline.Step.ParallelClaude

3. Orchestration Layer (depends on all)
   - Pipeline.Orchestrator
   - Pipeline
```

### 2.2 Mocking System Design

#### Mock Modules to Create

```elixir
# lib/pipeline/test/mocks.ex
defmodule Pipeline.Test.Mocks do
  @moduledoc """
  Mock system for testing pipeline components without external dependencies.
  """

  defmodule GeminiMock do
    @behaviour Pipeline.Test.AIProvider
    
    def generate(prompt, opts) do
      # Return predictable responses based on prompt patterns
    end
  end

  defmodule ClaudeSDKMock do
    @behaviour Pipeline.Test.ClaudeProvider
    
    def query(prompt, options) do
      # Return a stream of mock messages
    end
  end

  defmodule FileMock do
    @behaviour Pipeline.Test.FileSystem
    
    def read(path), do: {:ok, "mocked content"}
    def write(path, content), do: :ok
    def mkdir_p(path), do: :ok
  end
end
```

#### Behaviour Definitions

```elixir
# lib/pipeline/test/behaviours.ex
defmodule Pipeline.Test.AIProvider do
  @callback generate(prompt :: String.t(), opts :: keyword()) :: 
    {:ok, map()} | {:error, term()}
end

defmodule Pipeline.Test.ClaudeProvider do
  @callback query(prompt :: String.t(), options :: struct()) :: 
    Enumerable.t()
end

defmodule Pipeline.Test.FileSystem do
  @callback read(path :: String.t()) :: {:ok, binary()} | {:error, term()}
  @callback write(path :: String.t(), content :: binary()) :: :ok | {:error, term()}
  @callback mkdir_p(path :: String.t()) :: :ok | {:error, term()}
end
```

### 2.3 Test Categories

#### 1. Configuration Tests
- **Valid YAML parsing**: All configuration options
- **Invalid YAML handling**: Missing required fields, wrong types
- **Default value application**: Ensure defaults work correctly
- **Complex prompt building**: Multi-part prompts with references

#### 2. Orchestration Tests
- **Step execution order**: Sequential execution
- **Conditional execution**: Steps skipped based on conditions
- **Error propagation**: Failed steps stop pipeline
- **Result passing**: Previous step results available
- **Checkpoint saving**: Files created at correct times

#### 3. Gemini Integration Tests
- **Token budget application**: Defaults and overrides
- **Model selection**: Correct model used
- **Response handling**: Various response formats
- **Error scenarios**: API failures, timeouts
- **Function calling**: When implemented

#### 4. Claude Integration Tests
- **Workspace sandboxing**: Files created in correct directory
- **Options passing**: All CLI options correctly applied
- **Stream processing**: Handle message streams
- **Output formats**: JSON, text, stream-json
- **Tool restrictions**: allowed_tools enforced

#### 5. Parallel Execution Tests
- **Task isolation**: Tasks don't interfere
- **Result aggregation**: Combined results correct
- **Error handling**: One task failure behavior
- **Performance**: Actually runs in parallel

#### 6. Debug and Output Tests
- **Log file creation**: Correct format and location
- **Output file saving**: JSON serialization
- **Workspace file tracking**: find_workspace_files accuracy
- **Viewer functionality**: All CLI options work

### 2.4 Test Data Strategy

#### Configuration Fixtures

```elixir
# test/fixtures/configs/
- minimal_gemini.yaml      # Simplest possible Gemini workflow
- minimal_claude.yaml      # Simplest possible Claude workflow  
- complex_workflow.yaml    # All features used
- invalid_missing_name.yaml
- invalid_bad_step_type.yaml
- conditional_workflow.yaml
- parallel_tasks.yaml
- function_calling.yaml
```

#### Mock Response Fixtures

```elixir
# test/fixtures/responses/
- gemini_analysis.json     # Typical Gemini response
- gemini_with_function.json # Function call response
- claude_messages.json     # Stream of Claude messages
- error_response.json      # Error scenarios
```

### 2.5 Property-Based Testing

Using StreamData for property tests:

```elixir
# Areas for property testing:
1. Configuration parsing - random valid YAML structures
2. Prompt building - various combinations of parts
3. Token budget merging - ensure overrides work
4. Path resolution - workspace sandboxing invariants
```

### 2.6 Integration Test Scenarios

#### Scenario 1: Code Analysis Pipeline
```yaml
# Full workflow testing Gemini analysis → Claude implementation
- Gemini analyzes code
- Claude implements fixes
- Gemini reviews result
```

#### Scenario 2: Parallel Development
```yaml
# Test parallel Claude execution
- Gemini creates plan
- Parallel Claude tasks (backend, frontend, tests)
- Gemini integration review
```

#### Scenario 3: Error Recovery
```yaml
# Test error handling and recovery
- Step 1 succeeds
- Step 2 fails (mock error)
- Conditional step 3 skipped
- Cleanup step runs
```

### 2.7 Performance Testing

#### Benchmarks to Create
1. **Configuration parsing speed**: Large YAML files
2. **Prompt building performance**: Complex templates
3. **Parallel execution speedup**: Compare sequential vs parallel
4. **Memory usage**: Large responses and file operations

### 2.8 Test Helpers

```elixir
defmodule Pipeline.Test.Helpers do
  @moduledoc """
  Common test utilities for pipeline testing.
  """

  def with_temp_dir(fun) do
    # Create temp directory, run test, cleanup
  end

  def create_test_config(opts) do
    # Build valid config from options
  end

  def assert_step_executed(orchestrator, step_name) do
    # Verify step was run and has results
  end

  def assert_file_created(path, content \\ nil) do
    # Check file exists and optionally content
  end

  def capture_logs(fun) do
    # Capture Logger output during test
  end
end
```

## 3. Testing Infrastructure

### 3.1 ExUnit Configuration

```elixir
# test/test_helper.exs
ExUnit.start()

# Configure mocks
Mox.defmock(Pipeline.GeminiMock, for: Pipeline.Test.AIProvider)
Mox.defmock(Pipeline.ClaudeMock, for: Pipeline.Test.ClaudeProvider)
Mox.defmock(Pipeline.FileMock, for: Pipeline.Test.FileSystem)

# Set global test mode
Application.put_env(:pipeline, :test_mode, true)
```

### 3.2 Test Organization

```
test/
├── pipeline/
│   ├── config_test.exs
│   ├── orchestrator_test.exs
│   ├── debug_test.exs
│   ├── prompt_builder_test.exs
│   └── step/
│       ├── gemini_test.exs
│       ├── claude_test.exs
│       └── parallel_claude_test.exs
├── integration/
│   ├── full_workflow_test.exs
│   ├── error_handling_test.exs
│   └── performance_test.exs
├── fixtures/
│   ├── configs/
│   └── responses/
└── support/
    ├── mocks.ex
    ├── behaviours.ex
    └── helpers.ex
```

## 4. Continuous Integration

### 4.1 Test Matrix

```yaml
# .github/workflows/test.yml
matrix:
  elixir: [1.14, 1.15, 1.16]
  otp: [25, 26]
  include:
    - integration_tests: true
      elixir: 1.16
      otp: 26
```

### 4.2 Test Stages

1. **Unit Tests**: Fast, no external dependencies
2. **Integration Tests**: With mocks
3. **Contract Tests**: Verify mock behavior matches real services
4. **End-to-End Tests**: Optional, with real services

## 5. Test Coverage Goals

- **Overall Coverage**: 90%+
- **Critical Paths**: 100%
  - Configuration parsing
  - Step execution
  - Error handling
  - Workspace sandboxing
- **Integration Tests**: All major workflows

## 6. Mock Validation Strategy

To ensure mocks remain accurate:

1. **Contract Tests**: Verify mock responses match real service schemas
2. **Recording Mode**: Optionally record real responses for mock updates
3. **Version Tracking**: Track API versions mocks are based on

## 7. Future Testing Considerations

### When Claude SDK is Ready
- Remove Claude mocks
- Add real integration tests
- Verify sandboxing with actual file operations
- Test all CLI option combinations

### When Function Calling is Implemented
- Test function registration
- Test function execution
- Test error handling in functions
- Verify function results in workflow

### Performance Optimization
- Benchmark against Python version
- Profile memory usage
- Optimize critical paths
- Load test with large workflows

## 8. Test Documentation

Each test module should include:
- Purpose and scope
- Mock dependencies
- Setup requirements
- Example usage
- Known limitations

## 9. Testing Commands

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run only unit tests
mix test --exclude integration

# Run specific module
mix test test/pipeline/config_test.exs

# Run with detailed output
mix test --trace

# Run property tests (more iterations)
mix test --max-runs 1000
```

## 10. Implementation Status

### ✅ Completed
1. **Mock system implemented** - ✅ Behaviours and basic mocks created
   - Created `Pipeline.Test.Behaviours` with AIProvider, ClaudeProvider, FileSystem, Logger behaviours
   - Implemented `Pipeline.Test.Mocks` with GeminiMock, ClaudeSDKMock, FileMock, LoggerMock
   - Added `Pipeline.Test.Helpers` with comprehensive test utilities
   - Set up test infrastructure with TestCase, UnitTestCase, IntegrationTestCase
   - All mock tests passing (13 tests, 0 failures)

### 🚧 Next Steps
1. **Write unit tests** - Start with Config and PromptBuilder
2. **Add integration tests** - Test complete workflows with mocks
3. **Set up CI** - Automated testing on push
4. **Add property tests** - For complex logic
5. **Performance benchmarks** - Establish baselines

### Mock System Features

The implemented mock system provides:

#### Test Infrastructure
- `Pipeline.TestCase` - Base test case with common setup
- `Pipeline.UnitTestCase` - For unit tests with mocked dependencies  
- `Pipeline.IntegrationTestCase` - For integration tests with longer timeouts
- Test fixtures in `test/fixtures/` with sample configs and responses
- Automatic cleanup and setup between tests

#### Mock Implementations
- **GeminiMock** - Returns predictable responses based on prompt patterns
  - Analysis responses for \"analyze\" prompts
  - Planning responses for \"plan\" prompts
  - Function call responses when functions enabled
  - Error simulation for \"error\" prompts
- **ClaudeSDKMock** - Simulates Claude Code SDK message streams
  - Different message types (message, tool_use, tool_result, result)
  - JSON and text output format support
  - Realistic message flow simulation
- **FileMock** - In-memory file system simulation
  - Process-dictionary based file storage
  - Standard file operations (read, write, exists?, ls, mkdir_p)
  - State reset between tests
- **LoggerMock** - Captures log messages for testing
  - Categorizes by log level (info, debug, error, warn)
  - Timestamps on all log entries
  - Query by level functionality

#### Test Helpers
- `with_temp_dir/1` - Execute function with temporary directory
- `create_test_config/1` - Generate test configurations
- `create_gemini_step/1` and `create_claude_step/1` - Step builders
- `assert_step_executed/2` - Verify step execution
- `assert_file_created/2` - Check file creation
- `assert_mock_file_created/2` - Check mock file system
- `assert_logged/2` - Verify log messages
- `create_temp_config_file/1` - Generate temporary YAML configs
- `reset_mocks/0` - Reset all mock state

The mock system is now ready for comprehensive testing of the pipeline orchestration system.