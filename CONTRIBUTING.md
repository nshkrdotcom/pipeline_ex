# Contributing to Pipeline Orchestration System

Welcome to the Pipeline Orchestration System! This guide will help you understand the architecture and contribute effectively to this Elixir-based AI pipeline system.

## 🏗️ Architecture Overview

The Pipeline Orchestration System combines **Gemini (Brain)** and **Claude (Muscle)** with a generic tool system:

- **Gemini = BRAIN** 🧠: Analysis, reasoning, and function calling with tools
- **Claude = MUSCLE** 💪: Code execution and implementation tasks  
- **Tool System** 🔧: Generic, provider-agnostic function calling with auto-discovery
- **InstructorLite** 📦: Structured LLM output with function calling
- **Claude Code SDK** ⚡: Process execution and code interaction

## 📁 Project Structure

```
pipeline_ex/
├── lib/pipeline/
│   ├── tools/                        # 🔧 TOOL SYSTEM
│   │   ├── tool.ex                   # Tool behavior interface
│   │   ├── tool_registry.ex          # Auto-discovery & execution
│   │   ├── adapters/
│   │   │   └── instructor_lite_adapter.ex  # LLM provider adapter
│   │   └── implementations/
│   │       └── get_wan_ip/
│   │           └── ubuntu_2404.ex    # WAN IP tool for Ubuntu
│   ├── step/
│   │   ├── gemini_instructor.ex      # Gemini with function calling
│   │   ├── claude.ex                # Claude step executor
│   │   └── parallel_claude.ex       # Parallel Claude executor
│   ├── orchestrator.ex              # Core orchestration engine
│   ├── config.ex                   # YAML config parser
│   └── schemas/
│       └── analysis_response.ex     # Ecto schemas for InstructorLite
├── mix.exs                         # Dependencies & project config
└── README.md                       # Main documentation
```

## 🔧 Core Components

### 1. Tool System Architecture

The tool system provides a generic, provider-agnostic architecture for function calling:

#### Tool Behavior (`Pipeline.Tools.Tool`)
```elixir
@callback get_definition() :: %{
  name: String.t(),
  description: String.t(),
  parameters: map()
}

@callback execute(args :: map()) :: {:ok, any()} | {:error, any()}
@callback supported_platforms() :: [String.t()]
@callback validate_environment() :: :ok | {:error, String.t()}
```

#### Tool Registry (`Pipeline.Tools.ToolRegistry`)
- **Auto-discovery**: Automatically finds and registers tools
- **Execution**: Centralized tool execution with error handling
- **Validation**: Environment validation before registration
- **LLM Integration**: Provides tool definitions for function calling

### 2. InstructorLite Integration

InstructorLite provides structured output from LLMs with function calling support:

#### Key Features:
- **Structured Schemas**: Uses Ecto schemas for type safety
- **Function Calling**: Seamless integration with Gemini function calling
- **Validation**: Automatic validation of LLM responses
- **Adapters**: Provider-agnostic interface

#### Usage Pattern:
```elixir
# In gemini_instructor.ex
{:ok, response} = InstructorLite.chat_completion(
  model: "gemini-2.5-flash",
  messages: messages,
  response_model: Pipeline.Schemas.AnalysisResponse,
  functions: tool_definitions
)
```

### 3. Pipeline Orchestration

The orchestrator manages workflow execution:

#### Key Features:
- **Step Execution**: Sequential step processing
- **State Management**: Results passed between steps
- **Conditional Logic**: Skip steps based on conditions
- **Checkpointing**: Save/resume workflow state
- **Debug Logging**: Comprehensive execution logging

### 4. Claude Code SDK Integration

Claude steps use the Claude Code SDK for process execution:

#### Key Features:
- **Streaming**: Real-time response processing
- **Tool Control**: Fine-grained tool permissions
- **Working Directory**: Sandboxed execution
- **Message Processing**: Handles different message types

## 🛠️ Development Guidelines

### Adding New Tools

1. **Create Tool Implementation**:
```elixir
defmodule Pipeline.Tools.Implementations.MyTool.Platform do
  @behaviour Pipeline.Tools.Tool
  
  @impl Pipeline.Tools.Tool
  def get_definition() do
    %{
      name: "my_tool",
      description: "What this tool does",
      parameters: %{
        type: "object",
        properties: %{
          param1: %{type: "string", description: "Parameter description"}
        },
        required: ["param1"]
      }
    }
  end
  
  @impl Pipeline.Tools.Tool
  def execute(args) do
    # Implementation
    {:ok, result}
  end
  
  @impl Pipeline.Tools.Tool
  def supported_platforms(), do: ["ubuntu-24.04"]
  
  @impl Pipeline.Tools.Tool
  def validate_environment() do
    # Check dependencies
    :ok
  end
end
```

2. **Register in Tool Registry**:
Update `discover_tool_modules/1` in `tool_registry.ex`:
```elixir
defp discover_tool_modules(_base_module) do
  [
    Pipeline.Tools.Implementations.GetWanIp.Ubuntu2404,
    Pipeline.Tools.Implementations.MyTool.Platform  # Add here
  ]
end
```

3. **Test Tool**:
```elixir
# Manual testing in IEx
iex -S mix
{:ok, _pid} = Pipeline.Tools.ToolRegistry.start_link()
Pipeline.Tools.ToolRegistry.auto_register_tools()
Pipeline.Tools.ToolRegistry.execute_tool("my_tool", %{"param1" => "value"})
```

### Adding New Step Types

1. **Create Step Module**:
```elixir
defmodule Pipeline.Step.MyStep do
  def execute(step, orch) do
    # Step implementation
    %{result: "success"}
  end
end
```

2. **Register in Orchestrator**:
Update `execute_step/2` in `orchestrator.ex`:
```elixir
defp execute_step(step, orch) do
  case step.type do
    "gemini" -> Step.GeminiInstructor.execute(step, orch)
    "claude" -> Step.Claude.execute(step, orch)
    "parallel_claude" -> Step.ParallelClaude.execute(step, orch)
    "my_step" -> Step.MyStep.execute(step, orch)  # Add here
    _ -> raise "Unknown step type: #{step.type}"
  end
end
```

### Adding New Schemas

1. **Create Ecto Schema**:
```elixir
defmodule Pipeline.Schemas.MyResponse do
  use Ecto.Schema
  use InstructorLite.Instruction
  
  @primary_key false
  embedded_schema do
    field :field1, :string
    field :field2, :integer
  end
  
  @impl InstructorLite.Instruction
  def validate_changeset(changeset) do
    changeset
    |> validate_required([:field1, :field2])
  end
end
```

2. **Use in Steps**:
```elixir
{:ok, response} = InstructorLite.chat_completion(
  response_model: Pipeline.Schemas.MyResponse,
  # ... other options
)
```

## 🧪 Testing Guidelines

### Unit Testing Tools
```elixir
defmodule Pipeline.Tools.Implementations.MyToolTest do
  use ExUnit.Case
  
  alias Pipeline.Tools.Implementations.MyTool.Platform
  
  test "get_definition/0 returns valid schema" do
    definition = Platform.get_definition()
    assert definition.name == "my_tool"
    assert is_map(definition.parameters)
  end
  
  test "execute/1 with valid args" do
    args = %{"param1" => "test"}
    assert {:ok, result} = Platform.execute(args)
    assert is_map(result)
  end
end
```

### Integration Testing
```elixir
defmodule Pipeline.IntegrationTest do
  use ExUnit.Case
  
  test "full pipeline execution" do
    config_path = "test/fixtures/test_workflow.yaml"
    assert {:ok, orchestrator} = Pipeline.run(config_path)
    assert orchestrator.results != %{}
  end
end
```

### Manual Testing
```bash
# Test tool system
mix run demo_wan_ip_tool.exs

# Test specific workflow
mix run -e "Pipeline.run(\"test_wan_ip_tool.yaml\")"

# Debug mode
mix run view_debug.exs
```

## 📦 Dependencies Management

### Core Dependencies
- `instructor_lite`: Structured LLM responses
- `claude_code_sdk`: Claude integration (from GitHub)
- `yaml_elixir`: YAML configuration parsing
- `jason`: JSON handling
- `req`: HTTP requests
- `ecto`: Schema validation

### Adding Dependencies
1. Update `mix.exs`:
```elixir
defp deps do
  [
    # ... existing deps
    {:new_dep, "~> 1.0"}
  ]
end
```

2. Run `mix deps.get`
3. Update documentation if needed

## 🔍 Debugging

### Debug Logging
The system provides comprehensive debug logging:
```elixir
# In your code
alias Pipeline.Debug
Debug.log(orch.debug_log, "Debug message: #{inspect(data)}")
```

### Tool Registry Debugging
```elixir
# List registered tools
Pipeline.Tools.ToolRegistry.list_tools()

# Get tool definitions
Pipeline.Tools.ToolRegistry.get_tool_definitions()

# Test specific tool
Pipeline.Tools.ToolRegistry.execute_tool("tool_name", %{})
```

### Claude SDK Debugging
```elixir
# Enable verbose logging in Claude options
claude_options:
  verbose: true
  # ... other options
```

## 🚀 Performance Considerations

### Tool Execution
- Tools should validate inputs early
- Use appropriate timeouts for external calls
- Handle errors gracefully
- Cache results when appropriate

### Memory Management
- Large tool responses should stream when possible
- Clean up temporary files
- Monitor process memory usage

### Concurrency
- Tools should be stateless when possible
- Use GenServer for stateful tools
- Consider parallel execution for independent operations

## 📝 Code Style

### Elixir Conventions
- Follow standard Elixir formatting (use `mix format`)
- Use descriptive function and variable names
- Add comprehensive documentation
- Include typespecs where helpful

### Documentation
- All public functions should have `@doc`
- Complex modules should have `@moduledoc`
- Include examples in documentation
- Update README when adding features

### Error Handling
```elixir
# Prefer explicit error tuples
def my_function(args) do
  case validate_args(args) do
    :ok -> {:ok, do_work(args)}
    {:error, reason} -> {:error, reason}
  end
end

# Use with statements for complex pipelines
def complex_operation(data) do
  with {:ok, step1} <- process_step1(data),
       {:ok, step2} <- process_step2(step1),
       {:ok, result} <- finalize(step2) do
    {:ok, result}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

## 🤝 Contributing Process

1. **Fork the Repository**
2. **Create Feature Branch**: `git checkout -b feature/my-feature`
3. **Write Tests**: Add comprehensive tests for new functionality
4. **Update Documentation**: Update README, add examples
5. **Test Thoroughly**: Run all tests and manual testing
6. **Submit PR**: Include detailed description of changes

### PR Guidelines
- Clear, descriptive title
- Detailed description of changes
- Link to relevant issues
- Include test results
- Update documentation as needed

## 📋 Common Patterns

### Tool Implementation Pattern
```elixir
defmodule Pipeline.Tools.Implementations.ToolName.Platform do
  @behaviour Pipeline.Tools.Tool
  require Logger
  
  # Always include platform validation
  @impl Pipeline.Tools.Tool
  def validate_environment() do
    case System.cmd("which", ["required_command"]) do
      {_, 0} -> :ok
      {_, _} -> {:error, "required_command not found"}
    end
  end
  
  # Use consistent error handling
  @impl Pipeline.Tools.Tool
  def execute(args) do
    Logger.info("Executing #{__MODULE__} with args: #{inspect(args)}")
    
    try do
      result = do_work(args)
      Logger.info("✅ #{__MODULE__} completed successfully")
      {:ok, result}
    rescue
      error ->
        Logger.error("❌ #{__MODULE__} failed: #{inspect(error)}")
        {:error, "Execution failed: #{inspect(error)}"}
    end
  end
end
```

### Step Implementation Pattern
```elixir
defmodule Pipeline.Step.MyStep do
  alias Pipeline.{Debug, PromptBuilder}
  require Logger
  
  def execute(step, orch) do
    Logger.info("🔄 Executing #{step.name}")
    
    # Build prompt from configuration
    prompt = PromptBuilder.build(step.prompt, orch.results)
    
    # Log for debugging
    Debug.log(orch.debug_log, "Step #{step.name} prompt: #{prompt}")
    
    # Execute step logic
    result = do_step_work(prompt, step, orch)
    
    # Save output if configured
    if output_file = step[:output_to_file] do
      save_output(orch.output_dir, output_file, result)
    end
    
    Logger.info("✅ Step #{step.name} completed")
    result
  end
end
```

## 🎯 Future Directions

### Planned Enhancements
- More tool implementations (system info, file operations, etc.)
- Enhanced error recovery and retry logic
- Performance monitoring and metrics
- Plugin system for custom step types
- Web UI for pipeline management

### Areas for Contribution
- Tool implementations for different platforms
- Enhanced Claude SDK integration
- Performance optimizations
- Documentation improvements
- Testing infrastructure

---

Thank you for contributing to the Pipeline Orchestration System! Your contributions help make AI-powered automation more accessible and powerful. 🚀 