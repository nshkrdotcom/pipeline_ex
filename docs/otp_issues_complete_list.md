# Complete List of OTP and Concurrency Issues in Pipeline System

## Overview
This document provides a comprehensive list of ALL concurrency-related code in the Pipeline system. As noted, the system runs primarily synchronously, so these issues only manifest in specific use cases (parallel execution, monitoring, tool registry access).

## 1. Unsupervised Processes (2 instances total)

### 1.1 Performance Monitoring GenServer
**File**: `lib/pipeline/monitoring/performance.ex:47`
```elixir
GenServer.start_link(__MODULE__, {pipeline_name, opts}, name: via_tuple(pipeline_name))
```
**Issue**: No supervision, crashes won't restart
**Fix**: Add to supervision tree with `:transient` restart strategy
**Impact**: Only affects performance monitoring feature

### 1.2 Tool Registry Agent  
**File**: `lib/pipeline/tools/tool_registry.ex:95`
```elixir
Agent.start_link(fn -> %{} end, name: :tool_registry)
```
**Issue**: Named agent without supervision, name collision on crash
**Fix**: Add to supervision tree with `:permanent` restart strategy
**Impact**: Critical if using custom tools

## 2. Unsupervised Task.async Usage (6 instances total)

### 2.1 Claude Provider Extended
**File**: `lib/pipeline/providers/claude_provider_extended.ex:17`
```elixir
Task.async(fn -> ... end)
```
**Fix**: Use `Task.Supervisor.async(Pipeline.TaskSupervisor, fn -> ... end)`

### 2.2 Enhanced Claude Provider
**File**: `lib/pipeline/providers/enhanced_claude_provider.ex:120`
```elixir
Task.async(fn -> ... end)
```
**Fix**: Use `Task.Supervisor.async(Pipeline.TaskSupervisor, fn -> ... end)`

### 2.3 Claude Batch Processing (2 instances)
**File**: `lib/pipeline/step/claude_batch.ex`
- Line 196: `Task.async_stream` for batch processing
- Line 225: `Task.async` for individual items
**Fix**: Use `Task.Supervisor.async_stream` and `Task.Supervisor.async`

### 2.4 Loop Step
**File**: `lib/pipeline/step/loop.ex:192`
```elixir
Task.async(fn -> ... end)
```
**Fix**: Use `Task.Supervisor.async(Pipeline.TaskSupervisor, fn -> ... end)`

### 2.5 Parallel Claude Step
**File**: `lib/pipeline/step/parallel_claude.ex:22`
```elixir
Task.async(fn -> ... end)
```
**Fix**: Use `Task.Supervisor.async(Pipeline.TaskSupervisor, fn -> ... end)`

## 3. ETS Table Usage (1 instance)

### 3.1 Prompt Builder File Cache
**File**: `lib/pipeline/prompt_builder.ex:41`
```elixir
:ets.new(@file_cache_name, [:named_table, :public, :set])
```
**Issue**: Race condition handled with rescue clause
**Current Mitigation**: Already has try/rescue for ArgumentError
**Better Fix**: Initialize in Application.start or use persistent_term

## 4. File System Race Conditions (1 critical instance)

### 4.1 Checkpoint Latest Symlink
**File**: `lib/pipeline/checkpoint_manager.ex:53-54`
```elixir
_ = File.rm(latest_path)
File.write!(latest_path, json)
```
**Issue**: Race between delete and write
**Fix**: Use atomic rename operation:
```elixir
temp_path = "#{latest_path}.tmp"
File.write!(temp_path, json)
File.rename!(temp_path, latest_path)
```

## 5. Process Dictionary Usage

### 5.1 Session Manager (Production Code)
**File**: `lib/pipeline/session_manager.ex`
- Lines 293, 294: `Process.get/put(:pipeline_sessions)`
- Lines 298: `Process.get(:pipeline_sessions)`
- Lines 303: `Process.get(:pipeline_sessions)`
- Lines 308, 309: `Process.get/put(:pipeline_sessions)`

**Issue**: Not thread-safe across processes
**Fix**: Replace with ETS table or GenServer state
**Impact**: Only affects multi-process session sharing

### 5.2 Nested Pipeline Step
**File**: `lib/pipeline/step/nested_pipeline.ex`
- Lines 120, 211, 213, 325: Process dictionary for nested context
**Issue**: Could lose state in concurrent nested pipelines
**Fix**: Pass context explicitly through function parameters

### 5.3 Test Code (Multiple Files)
The following files use Process dictionary for test mocking:
- `lib/pipeline/test/mocks.ex`
- `lib/pipeline/test/mocks/claude_provider.ex`
- `lib/pipeline/test/mocks/gemini_provider.ex`
- `lib/pipeline/test/mocks/session_manager.ex`
- `lib/pipeline/test_mode.ex`

**Note**: Test usage is acceptable as tests run in isolation

## 6. Dangerous Patterns

### 6.1 Infinite Timeout
**File**: `lib/pipeline/step/parallel_claude.ex:40`
```elixir
Task.await_many(async_tasks, :infinity)
```
**Fix**: Use configurable timeout with default (e.g., 5 minutes)

### 6.2 Silent Error Returns
**File**: `lib/pipeline/safety/resource_monitor.ex:294-300`
```elixir
rescue
  _ -> 0  # Returns 0 on memory check failure
```
**Fix**: Log error and return {:error, reason} or re-raise

## Summary Statistics

- **Total Unsupervised Processes**: 2 (1 GenServer, 1 Agent)
- **Total Unsupervised Tasks**: 6 Task.async calls
- **Total Race Conditions**: 1 critical (checkpoint), 1 handled (ETS)
- **Total Process Dictionary Usage**: 15 instances (4 in production, 11 in tests)
- **Total Files Affected**: 15 files

## Minimal Fix for Production Use

If you want the absolute minimum changes for production stability:

1. **Critical**: Fix the checkpoint race condition (5 lines of code)
2. **Important**: Add TaskSupervisor to supervision tree (10 lines)
3. **Important**: Supervise ToolRegistry if using custom tools (5 lines)
4. **Optional**: Supervise Performance monitoring if needed (5 lines)

Total: ~25 lines of code changes for production stability

## Note on Sequential Execution

As you correctly noted, most pipeline execution is sequential. The concurrency issues only matter for:
- Parallel step types (`parallel_claude`, `claude_batch`)
- Performance monitoring (optional feature)
- Tool registry (only if using custom tools)
- Session sharing across processes (rare use case)

For typical sequential pipeline execution, none of these issues will manifest.