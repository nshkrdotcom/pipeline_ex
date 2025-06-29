# Pipeline Build-out Plan

## Introduction

This document outlines the current implementation status of the pipeline configuration features as described in `PIPELINE_CONFIG_GUIDE.md`. It provides a prioritized plan for implementing the remaining missing features to bring the pipeline to full functionality.

**Note**: This document has been updated based on a comprehensive analysis of the actual codebase implementation as of the latest revision.

## Current Implementation Status

The following table summarizes the **actual** implementation status of each feature from the configuration guide:

| Feature | Status | Implementation Details |
|---|---|---|
| **Workflow Section** | | |
| `name` | ✅ Implemented | `lib/pipeline/config.ex:108` - Required field validation |
| `checkpoint_enabled` | ✅ Implemented | `lib/pipeline/executor.ex:70-76` - Full checkpoint system |
| `workspace_dir` | ✅ Implemented | `lib/pipeline/executor.ex:74` - Directory creation and management |
| `checkpoint_dir` | ✅ Implemented | `lib/pipeline/config.ex:216` - Default and custom paths |
| **Defaults Section** | | |
| `gemini_model` | ✅ Implemented | `lib/pipeline/config.ex:221-228` - Model validation and defaults |
| `gemini_token_budget` | ✅ Implemented | `lib/pipeline/config.ex:229-236` - Token limit configuration |
| `claude_output_format` | ❌ Not Implemented | No support in config or providers |
| `output_dir` | ✅ Implemented | `lib/pipeline/config.ex:237-241` - Output directory handling |
| **Steps Section** | | |
| `name` | ✅ Implemented | `lib/pipeline/config.ex:122` - Required field validation |
| `type` | 🟡 Partial | `lib/pipeline/executor.ex:198-207` - Only `gemini`/`claude` wired (not `parallel_claude`/`gemini_instructor`) |
| `role` | ✅ Implemented | `lib/pipeline/config.ex:126` - Loaded but documentation-only |
| `condition` | ❌ Not Implemented | No conditional execution logic in executor |
| `output_to_file` | ✅ Implemented | `lib/pipeline/executor.ex:265-270` - File output handling |
| **Prompt Templates** | | |
| `static` | ✅ Implemented | `lib/pipeline/prompt_builder.ex:17-22` - Static content support |
| `file` | ✅ Implemented | `lib/pipeline/prompt_builder.ex:25-36` - File loading with validation |
| `previous_response` | ✅ Implemented | `lib/pipeline/prompt_builder.ex:39-65` - Response reference and extraction |
| `extract` (field) | ✅ Implemented | `lib/pipeline/prompt_builder.ex:55-63` - JSON field extraction |
| **Claude Options** | | |
| `claude_options` | ✅ Implemented | `lib/pipeline/step/claude.ex:19` + `lib/pipeline/providers/claude_provider.ex:40-48` - Full options support |
| **Advanced Features** | | |
| `gemini_functions` | ✅ Implemented | `lib/pipeline/providers/gemini_provider.ex:67-91` + instructor tools - Complete function calling |

## Remaining Implementation Tasks

Based on the actual code analysis, only a few features remain to be implemented:

### Priority 1: Critical Missing Features

1. **Implement `condition` for conditional step execution**:
   - **Current Status**: No conditional logic exists in `lib/pipeline/executor.ex`
   - **Implementation Approach**: 
     - Add condition evaluation in `execute_step/3` before step execution
     - Support dot-notation field access (e.g., `"previous_step.field_name"`)
     - Use `Access.get/2` for nested field extraction from step results
     - Skip step if condition evaluates to false/nil
   - **File**: `lib/pipeline/executor.ex:198-207` (modify step execution loop)
   - **Impact**: High - Enables dynamic workflows and branching logic

2. **Wire up `parallel_claude` and `gemini_instructor` step types**:
   - **Current Status**: Step implementations exist but not integrated in executor
   - **Implementation Approach**:
     - Add "parallel_claude" and "gemini_instructor" cases to `execute_step/3` 
     - Update step type validation in `lib/pipeline/config.ex:135`
     - Parallel claude should execute tasks concurrently and merge results
   - **Files**: 
     - `lib/pipeline/executor.ex:198-207` (add new cases)
     - `lib/pipeline/config.ex:135` (update validation)
   - **Impact**: Medium - Unlocks advanced step types already implemented

### Priority 2: Quality of Life Improvements

3. **Implement `claude_output_format` default**:
   - **Current Status**: Not implemented in config or providers
   - **Implementation Approach**:
     - Add `claude_output_format` to defaults schema in `lib/pipeline/config.ex`
     - Use default in `lib/pipeline/providers/claude_provider.ex` when not specified in step
     - Support formats: "json", "text", "stream-json"
   - **Files**:
     - `lib/pipeline/config.ex:237-241` (add to defaults)
     - `lib/pipeline/providers/claude_provider.ex:40-48` (use default)
   - **Impact**: Low - Convenience feature for consistent output formatting

## Implementation Details

### Conditional Step Execution (Priority 1)

**Current executor loop** (`lib/pipeline/executor.ex:198-207`):
```elixir
case step["type"] do
  "claude" -> 
    Pipeline.Step.Claude.execute(step, workflow, state)
  "gemini" -> 
    Pipeline.Step.Gemini.execute(step, workflow, state)
end
```

**Proposed enhancement**:
```elixir
# Add before step execution
if should_execute_step?(step, state) do
  case step["type"] do
    "claude" -> Pipeline.Step.Claude.execute(step, workflow, state)
    "gemini" -> Pipeline.Step.Gemini.execute(step, workflow, state)
    "parallel_claude" -> Pipeline.Step.ParallelClaude.execute(step, workflow, state)
    "gemini_instructor" -> Pipeline.Step.GeminiInstructor.execute(step, workflow, state)
  end
else
  # Skip step, return current state
  {:ok, state}
end
```

### Step Type Integration (Priority 1)

**Existing implementations ready for integration**:
- `lib/pipeline/step/parallel_claude.ex` - Complete implementation
- `lib/pipeline/step/gemini_instructor.ex` - Complete implementation  
- Both use same interface as claude/gemini steps

**Required changes**:
1. Update `lib/pipeline/config.ex:135` validation to include new types
2. Add cases to executor switch statement
3. Test integration with existing workflow patterns

## Summary

The pipeline implementation is significantly more complete than originally documented. The main gaps are:
1. **Conditional execution logic** (high priority)
2. **Step type integration** for parallel_claude/gemini_instructor (medium priority) 
3. **Claude output format defaults** (low priority convenience feature)

All major features (claude_options, file prompts, workspace_dir, gemini_functions) are already fully implemented and working.
