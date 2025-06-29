# Pipeline Orchestration System

An Elixir-based AI pipeline orchestration system that combines **Gemini (Brain)** and **Claude (Muscle)** with a generic tool system for function calling.

## 🏗️ Architecture

- **Gemini = BRAIN** 🧠: Analysis, reasoning, and function calling with tools
- **Claude = MUSCLE** 💪: Code execution and implementation tasks
- **Tool System** 🔧: Generic, provider-agnostic function calling with auto-discovery

## ✨ Features

- 🧠 **Gemini Integration** - Brain for analysis and reasoning with function calling
- 💪 **Claude Integration** - Muscle for code execution and implementation  
- 🔧 **Generic Tool System** - Provider-agnostic tool architecture
- 📦 **InstructorLite Adapter** - Structured LLM output with function calling
- 🌐 **Sample Tools** - WAN IP lookup tool for Ubuntu 24.04
- ⚙️ **YAML Configuration** - Simple workflow definition
- 🏗️ **Multi-Provider Ready** - Extensible to other LLM providers

## 🚀 Quick Start

### Prerequisites

1. **Elixir 1.14+** installed
2. **Gemini API Key** from Google AI (for function calling)
3. **Claude CLI** authenticated (`claude login`) (for Claude steps)

### Setup

```bash
# Clone and setup
git clone <your-repo>
cd pipeline_ex

# Install dependencies (including Claude Code SDK from GitHub)
mix deps.get

# Set up Gemini API key for function calling
export GEMINI_API_KEY="your_api_key_here"
```

### Demo the Tool System (No API Key Required)

```bash
# Run the complete tool system demo
mix run demo_wan_ip_tool.exs
```

This shows:
- ✅ Tool auto-registration and discovery
- ✅ WAN IP retrieval using multiple services (ipify, httpbin, checkip)
- ✅ Function calling schema generation for Gemini
- ✅ Complete tool lifecycle without requiring API keys

### Run Function Calling Pipeline

```bash
# Test WAN IP tool via Gemini function calling (requires API key)
mix run -e "Pipeline.run(\"test_wan_ip_tool.yaml\")"
```

### Traditional Pipeline (Original Functionality)

```bash
# Run traditional Gemini + Claude workflow
./pipeline.exs example_workflow.yaml

# Or use mix run
mix run pipeline.exs example_workflow.yaml
```

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
├── test_wan_ip_tool.yaml            # 🔧 Function calling example
├── demo_wan_ip_tool.exs             # 🔧 Tool system demo
├── pipeline.exs                     # Traditional CLI runner
├── view_debug.exs                   # Debug viewer script
└── example_workflow.yaml            # Traditional example config
```

## 🔧 Tool System Usage

### Available Tools

#### `get_wan_ip` (Ubuntu 24.04)
Gets the current WAN (external/public) IP address.

**Parameters:**
- `service` (optional): `"ipify"`, `"httpbin"`, or `"checkip"` (default: "ipify")
- `timeout` (optional): Timeout in seconds, 1-30 (default: 10)

**Example Output:**
```json
{
  "wan_ip": "76.39.46.119",
  "service_used": "ipify", 
  "platform": "ubuntu-24.04",
  "timestamp": "2025-06-29T01:28:03.369980Z"
}
```

### Function Calling Configuration

```yaml
workflow:
  name: "WAN IP Tool Test"
  defaults:
    gemini_model: "gemini-2.5-flash"
    output_dir: "./outputs"
  steps:
    - name: "get_my_wan_ip"
      type: "gemini"
      prompt: |
        I need to find out what my current WAN IP address is. 
        Please use the available tools to get this information.
      functions:
        - "get_wan_ip"
      output_to_file: "wan_ip_result.json"
```

### Manual Tool Usage

```bash
# Start Elixir shell
iex -S mix

# Manual tool testing
{:ok, _pid} = Pipeline.Tools.ToolRegistry.start_link()
Pipeline.Tools.ToolRegistry.auto_register_tools()

# Execute tool directly
Pipeline.Tools.ToolRegistry.execute_tool("get_wan_ip", %{})
Pipeline.Tools.ToolRegistry.execute_tool("get_wan_ip", %{"service" => "httpbin"})

# List available tools
Pipeline.Tools.ToolRegistry.list_tools()

# Get tool definitions for LLM integration
Pipeline.Tools.ToolRegistry.get_tool_definitions()
```

## ⚙️ Configuration

### Function Calling Pipeline

```yaml
workflow:
  name: "Function Calling Example"
  defaults:
    gemini_model: "gemini-2.5-flash"
    output_dir: "./outputs"
  steps:
    - name: "analysis_with_tools"
      type: "gemini"
      prompt: "Analyze the network and get system information"
      functions:
        - "get_wan_ip"
        - "system_info"  # (when available)
      output_to_file: "analysis.json"
```

### Traditional Pipeline (Original Format)

```yaml
workflow:
  name: "my_pipeline"
  workspace_dir: "./workspace"
  
  defaults:
    gemini_model: "gemini-1.5-flash"
    gemini_token_budget:
      max_output_tokens: 2048
      temperature: 0.7
    claude_output_format: "json"
    output_dir: "./outputs"
    
  steps:
    - name: "plan"
      type: "gemini"
      prompt: "Create a plan..."
      output_to_file: "plan.json"
      
    - name: "implement"
      type: "claude"
      claude_options:
        max_turns: 15
        cwd: "./workspace"
      prompt: "Implement the plan"
```

### Mixed Gemini + Claude with Tools

```yaml
workflow:
  name: "Brain + Muscle + Tools Pipeline"
  steps:
    - name: "analyze"
      type: "gemini"
      prompt: "Analyze this system and get network info"
      functions:
        - "get_wan_ip"
    
    - name: "implement"
      type: "claude"
      prompt: "Implement monitoring based on the analysis"
      claude_options:
        allowed_tools: ["str_replace_editor", "bash"]
```

## 🛠️ Creating New Tools

### 1. Implement the Tool Behavior

```elixir
defmodule Pipeline.Tools.Implementations.MyTool.Linux do
  @behaviour Pipeline.Tools.Tool
  require Logger
  
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
    param1 = Map.get(args, "param1")
    
    # Your tool logic here
    case do_work(param1) do
      {:ok, result} -> 
        {:ok, %{result: result, timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}}
      {:error, reason} -> 
        {:error, reason}
    end
  end
  
  @impl Pipeline.Tools.Tool
  def supported_platforms(), do: ["linux", "ubuntu-24.04"]
  
  @impl Pipeline.Tools.Tool
  def validate_environment() do
    # Check if tool can run (dependencies, etc.)
    case System.cmd("which", ["required_command"], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {_output, _} -> {:error, "required_command not found"}
    end
  end
  
  defp do_work(param), do: {:ok, "processed #{param}"}
end
```

### 2. Register in Tool Registry

Add your tool module to `lib/pipeline/tools/tool_registry.ex`:

```elixir
defp discover_tool_modules(base_module) do
  [
    Pipeline.Tools.Implementations.GetWanIp.Ubuntu2404,
    Pipeline.Tools.Implementations.MyTool.Linux  # Add here
  ]
end
```

### 3. Use in Pipeline

```yaml
workflow:
  name: "My Tool Test"
  steps:
    - name: "use_my_tool"
      type: "gemini"
      prompt: "Please use my_tool to process data"
      functions:
        - "my_tool"
```

## 📊 Viewing Results

### Traditional Pipeline Results

```bash
# View debug logs and outputs
./view_debug.exs

# View only debug log
./view_debug.exs -l

# View workspace files with stats
./view_debug.exs -w

# View without content (paths only)
./view_debug.exs -n
```

### Function Calling Results

Function calling results are saved to the output directory specified in the configuration:

```bash
# View the output file from function calling
cat ./outputs/wan_ip_result.json

# View debug logs
ls ./outputs/debug_*.log
cat ./outputs/debug_*.log
```

**Example Function Calling Output:**
```json
{
  "reasoning": "The user wants to find their WAN IP address...",
  "function_calls_executed": 1,
  "function_results": [
    {
      "function": "get_wan_ip",
      "args": {},
      "status": "success",
      "result": {
        "wan_ip": "76.39.46.119",
        "service_used": "ipify",
        "platform": "ubuntu-24.04",
        "timestamp": "2025-06-29T01:28:03.369980Z"
      },
      "timestamp": "2025-06-29T01:28:03.380000Z"
    }
  ]
}
```

## 🎯 Architecture Benefits

### Provider Agnostic
- Tools work with any LLM provider (Gemini, OpenAI, Claude, etc.)
- Consistent interface across providers
- Easy to add new LLM providers

### Platform Specific
- Tools can be platform-specific (Ubuntu, macOS, Windows)
- Environment validation prevents runtime failures
- Multiple implementations per tool type

### Extensible
- Simple behavior-based tool creation
- Auto-discovery and registration
- JSON schema generation for any provider

### Error Handling
- Isolated tool execution
- Comprehensive validation
- Graceful failure handling

## 🎯 Original Features

- **YAML Configuration**: Compatible with Python version format
- **Sandboxed Execution**: Claude operates in isolated workspace
- **Debug Logging**: Comprehensive logging of all AI interactions  
- **Token Budget Management**: Fine-grained control over response lengths
- **Parallel Execution**: Run multiple Claude instances concurrently
- **Checkpoint Support**: Save and resume workflow state
- **Prompt Templates**: Build complex prompts from components

## 🔗 Dependencies

### Core Dependencies
- **[InstructorLite](https://hex.pm/packages/instructor_lite)** v1.0.0 - Structured LLM output
- **[Ecto](https://hex.pm/packages/ecto)** v3.12 - Schema definitions for structured output
- **[Req](https://hex.pm/packages/req)** v0.5 - HTTP client for tool implementations
- **[YamlElixir](https://hex.pm/packages/yaml_elixir)** - YAML parsing
- **[Jason](https://hex.pm/packages/jason)** - JSON encoding/decoding

### Optional Dependencies  
- **ClaudeCodeSDK** - Local Elixir SDK for Claude (path dependency)
- **[GeminiEx](https://hex.pm/packages/gemini)** v0.0.2 - Legacy Gemini client (replaced by InstructorLite)

## 🔧 Troubleshooting

### Tool Registration Issues

```bash
# Check if tools are being discovered
mix run -e "IO.inspect(Pipeline.Tools.ToolRegistry.discover_tool_modules())"

# Test tool registration manually
mix run -e "
{:ok, _pid} = Pipeline.Tools.ToolRegistry.start_link()
result = Pipeline.Tools.ToolRegistry.auto_register_tools()
IO.inspect(result)
"
```

### Tool Environment Validation

```bash
# Test specific tool validation
mix run -e "IO.inspect(Pipeline.Tools.Implementations.GetWanIp.Ubuntu2404.validate_environment())"

# Check if curl is available (required for WAN IP tool)
which curl
```

### Function Calling Schema Issues

```bash
# Verify schema generation
mix run -e "
{:ok, _pid} = Pipeline.Tools.ToolRegistry.start_link()
Pipeline.Tools.ToolRegistry.auto_register_tools()
schema = Pipeline.Tools.Adapters.InstructorLiteAdapter.create_function_schema()
IO.inspect(schema, pretty: true)
"
```

### Pipeline Execution Issues

```bash
# Test config parsing
mix run -e "IO.inspect(Pipeline.Config.load(\"test_wan_ip_tool.yaml\"))"

# Run with debug output
MIX_ENV=dev mix run -e "Pipeline.run(\"test_wan_ip_tool.yaml\")"
```

## 🛠️ Development

### Running Tests

```bash
mix test
```

### Building Documentation

```bash
mix docs
```

### Development Tools

```bash
# Format code
mix format

# Check for issues
mix credo

# Interactive development
iex -S mix
```

## 🚀 Next Steps

### Adding More Tools
1. **File Operations** - Read, write, search files
2. **System Info** - CPU, memory, disk usage
3. **Network Tools** - Port scanning, DNS lookup
4. **Database Tools** - Query databases, check connections

### Adding More Providers
1. **OpenAI** - GPT-4 function calling
2. **Anthropic** - Claude function calling  
3. **Azure OpenAI** - Enterprise GPT integration
4. **Local Models** - Ollama, LocalAI integration

### Advanced Features
1. **Tool Composition** - Chain multiple tools together
2. **Async Execution** - Background tool processing
3. **Tool Security** - Sandboxing and permission controls
4. **Tool Monitoring** - Performance metrics and logging

## 📝 Notes

- **NEW**: Generic tool system with function calling support
- **NEW**: InstructorLite integration for structured output
- **NEW**: Provider-agnostic architecture for multi-LLM support
- **MAINTAINED**: Full compatibility with Python version configuration
- **MAINTAINED**: Same output locations and debug functionality
- **MAINTAINED**: All existing Claude + Gemini orchestration features

## 🤝 Contributing

This enhanced Elixir implementation adds a generic tool system while maintaining full compatibility with the original Python pipeline orchestration system. 

**Key Extension Points:**
1. **Tools** - Add new tool implementations
2. **Providers** - Add new LLM provider adapters
3. **Platforms** - Add platform-specific tool variants
4. **Orchestration** - Enhance pipeline capabilities

---

🎉 **Ready to orchestrate AI pipelines with function calling!**

