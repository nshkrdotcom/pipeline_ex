# Quick Usage Guide

## 🚀 TL;DR - How to Use This

### 1. See the Tool System in Action (No API Keys)

```bash
# Shows complete tool system working with real WAN IP lookup
mix run demo_wan_ip_tool.exs
```

**What you'll see:**
- ✅ Tool auto-registration: `get_wan_ip`
- ✅ Live WAN IP retrieval: `76.39.46.119` (your actual IP)
- ✅ Multiple services: `ipify`, `httpbin`, `checkip`
- ✅ Function calling schema generation for Gemini

### 2. Try Manual Tool Usage

```bash
# Start interactive shell
iex -S mix

# Execute in shell:
{:ok, _pid} = Pipeline.Tools.ToolRegistry.start_link()
Pipeline.Tools.ToolRegistry.auto_register_tools()

# Get your WAN IP right now
Pipeline.Tools.ToolRegistry.execute_tool("get_wan_ip", %{})

# Try different service
Pipeline.Tools.ToolRegistry.execute_tool("get_wan_ip", %{"service" => "httpbin"})
```

### 3. Function Calling with Gemini (Requires API Key)

```bash
# Set your Gemini API key
export GEMINI_API_KEY="your-actual-api-key"

# Run function calling pipeline
mix run -e "Pipeline.run(\"test_wan_ip_tool.yaml\")"
```

**What happens:**
1. Gemini receives: "Get my WAN IP using available tools"
2. Gemini calls: `get_wan_ip` function
3. Tool executes: `curl https://api.ipify.org`
4. Result saved: `./outputs/wan_ip_result.json`

## 📂 Files You Care About

### Ready to Use
- `demo_wan_ip_tool.exs` - **START HERE** - Shows everything working
- `test_wan_ip_tool.yaml` - Function calling config example
- `README.md` - Complete documentation

### Tool System Code
- `lib/pipeline/tools/implementations/get_wan_ip/ubuntu_2404.ex` - Sample tool
- `lib/pipeline/tools/tool_registry.ex` - Tool discovery & execution
- `lib/pipeline/tools/adapters/instructor_lite_adapter.ex` - LLM integration

### Pipeline Code  
- `lib/pipeline/step/gemini_instructor.ex` - Gemini + function calling
- `lib/pipeline/orchestrator.ex` - Main orchestration engine

## 🔧 What the Tool System Does

### Architecture
```
User Request → Gemini → Function Schema → Tool Registry → Ubuntu Tool → curl → Result
```

### Real Example
```
"Get my WAN IP" → Gemini decides to call get_wan_ip → Tool executes curl → Returns "76.39.46.119"
```

### Why This Matters
- **Provider Agnostic**: Works with any LLM (Gemini, OpenAI, Claude, etc.)
- **Platform Specific**: Ubuntu tools, macOS tools, Windows tools
- **Auto Discovery**: Just add tools, they're found automatically
- **Real Execution**: Actually calls curl, gets real data

## 💡 Key Concepts

### Tools Are Just Behaviors
```elixir
@behaviour Pipeline.Tools.Tool

def get_definition() -> %{name, description, parameters}
def execute(args) -> {:ok, result} | {:error, reason}
def validate_environment() -> :ok | {:error, reason}
```

### Function Calling Flow
1. **LLM** decides to call a function
2. **Adapter** converts LLM response to tool call
3. **Registry** finds and executes the tool
4. **Tool** does real work (curl, file ops, etc.)
5. **Result** goes back to LLM

### Provider Adapters
- **InstructorLite**: Converts tools → JSON schemas for Gemini
- **Future**: OpenAI adapter, Claude adapter, etc.

## 🎯 What You Can Build

### More Tools
```elixir
# System info tool
def execute(_args) do
  {:ok, %{
    cpu_usage: get_cpu_usage(),
    memory: get_memory_info(),
    disk_space: get_disk_info()
  }}
end

# File search tool  
def execute(%{"pattern" => pattern, "directory" => dir}) do
  files = find_files(pattern, dir)
  {:ok, %{files: files, count: length(files)}}
end

# Database query tool
def execute(%{"query" => sql}) do
  result = run_query(sql)
  {:ok, %{rows: result, count: length(result)}}
end
```

### More Providers
```elixir
# OpenAI adapter
defmodule Pipeline.Tools.Adapters.OpenAI do
  def create_function_schema(tools) do
    # Convert to OpenAI function calling format
  end
end

# Claude adapter  
defmodule Pipeline.Tools.Adapters.Claude do
  def create_function_schema(tools) do
    # Convert to Claude function calling format
  end
end
```

### Pipeline Workflows
```yaml
# Multi-tool analysis
workflow:
  name: "System Analysis"
  steps:
    - name: "gather_info"
      type: "gemini"
      prompt: "Analyze this system comprehensively"
      functions:
        - "get_wan_ip"      # Network info
        - "system_info"     # Resource usage  
        - "file_search"     # Important files
        - "port_scan"       # Security check

    - name: "implement_fixes"
      type: "claude"
      prompt: "Implement fixes based on the analysis"
```

## 🚀 Try It Now

**1 minute test:**
```bash
git clone <repo>
cd pipeline_ex  
mix deps.get
mix run demo_wan_ip_tool.exs
```

**5 minute test with API:**
```bash
export GEMINI_API_KEY="your-key"
mix run -e "Pipeline.run(\"test_wan_ip_tool.yaml\")"
cat ./outputs/wan_ip_result.json
```

**That's it!** You now have a working AI pipeline with function calling. 🎉