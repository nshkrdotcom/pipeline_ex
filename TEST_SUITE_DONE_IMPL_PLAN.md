# Test Suite Implementation Plan

## Overview

This document outlines a phased approach to implement the remaining pipeline functionality based on the comprehensive test suite that has been created. The plan focuses on making **all tests pass in mock mode first**, then stabilizing the system to 100% functionality before moving to live API testing.

## Current Status

### ✅ **Test Suite Complete**
- **6 Unit Test Files**: Comprehensive coverage of all features
- **2 Integration Test Files**: End-to-end workflow scenarios
- **Mock System**: Full mock providers for testing
- **Test Infrastructure**: Proper test mode management

### ✅ **Already Implemented (Verified by Code Analysis)**
- Claude options configuration and handling
- File prompt type support
- Workspace directory integration
- Gemini functions and function calling
- Previous response extraction with field access
- Configuration loading and validation
- Checkpoint system

### ❌ **Missing Implementation (Identified by Tests)**
Based on test failures and missing features in the executor:

1. **Conditional step execution** - Tests expect `condition` field support
2. **Step type integration** - `parallel_claude` and `gemini_instructor` not wired
3. **Enhanced mock interfaces** - Tests expect pattern-based mock responses
4. **Output format defaults** - `claude_output_format` not implemented

## Implementation Phases

### **Phase 1: Fix Mock System and Basic Tests (Priority: Critical)**

**Goal**: Make all unit tests pass in mock mode

#### 1.1 Fix Mock Provider Interfaces
**Files to modify**: 
- `lib/pipeline/test/mocks/claude_provider.ex`
- `lib/pipeline/test/mocks/gemini_provider.ex`

**Current Issue**: Tests expect `set_response_pattern` functions that don't exist

**Implementation**:
```elixir
# Add to ClaudeProvider mock
def set_response_pattern(pattern, response) do
  Process.put({:mock_response, pattern}, response)
end

def query(prompt, options) do
  # Check for pattern-specific responses first
  case find_matching_pattern(prompt) do
    {:ok, response} -> {:ok, response}
    :not_found -> 
      # Fall back to existing pattern matching
      # ... existing logic
  end
end

defp find_matching_pattern(prompt) do
  Process.get_keys()
  |> Enum.filter(fn key -> match?({:mock_response, _}, key) end)
  |> Enum.find_value(:not_found, fn {_, pattern} ->
    if String.contains?(prompt, pattern), do: {:ok, Process.get({:mock_response, pattern})}
  end)
end
```

**Similar changes needed for GeminiProvider mock**

#### 1.2 Fix Test File Syntax Errors
**Files to fix**: 
- `test/unit/pipeline/file_prompt_test.exs`
- `test/unit/pipeline/workspace_integration_test.exs` 
- `test/unit/pipeline/gemini_functions_test.exs`
- `test/unit/pipeline/previous_response_test.exs`
- `test/unit/pipeline/workflow_performance_test.exs`

**Issues**: Broken by sed command - orphaned lines and invalid syntax

**Implementation**:
- Remove orphaned mock setup lines
- Ensure proper test structure
- Fix any remaining function call issues

#### 1.3 Validate Core Functionality
**Test Command**: `mix test test/unit/`
**Success Criteria**: All unit tests pass in mock mode

---

### **Phase 2: Implement Missing Core Features (Priority: High)**

**Goal**: Implement the 2 critical missing features identified in buildout analysis

#### 2.1 Conditional Step Execution
**File to modify**: `lib/pipeline/executor.ex`

**Current State**: No conditional logic in executor

**Implementation Plan**:
```elixir
# Add to execute_step/3 before step execution
defp should_execute_step?(step, state) do
  case step["condition"] do
    nil -> true
    condition_expr -> evaluate_condition(condition_expr, state)
  end
end

defp evaluate_condition(condition_expr, state) do
  case String.split(condition_expr, ".") do
    [step_name] -> 
      get_in(state.results, [step_name]) |> is_truthy()
    [step_name, field] ->
      get_in(state.results, [step_name, field]) |> is_truthy()
    parts when length(parts) > 2 ->
      get_in(state.results, parts) |> is_truthy()
  end
end

defp is_truthy(nil), do: false
defp is_truthy(false), do: false
defp is_truthy(""), do: false
defp is_truthy([]), do: false
defp is_truthy(_), do: true
```

**Tests to validate**: 
- `test/unit/pipeline/executor_test.exs` (add conditional tests)
- `test/integration/workflow_scenarios_test.exs` (error recovery scenario)

#### 2.2 Wire Up Missing Step Types
**File to modify**: `lib/pipeline/executor.ex`

**Current State**: Only supports "claude" and "gemini" types

**Implementation Plan**:
```elixir
# Update execute_step/3 case statement
case step["type"] do
  "claude" -> 
    Pipeline.Step.Claude.execute(step, workflow, state)
  "gemini" -> 
    Pipeline.Step.Gemini.execute(step, workflow, state)
  "parallel_claude" ->
    Pipeline.Step.ParallelClaude.execute(step, workflow, state)
  "gemini_instructor" ->
    Pipeline.Step.GeminiInstructor.execute(step, workflow, state)
  unsupported ->
    {:error, "Unknown step type: #{unsupported}"}
end
```

**Additional changes needed**:
- Update `lib/pipeline/config.ex` line 135 validation to include new types
- Ensure step modules follow same interface pattern

**Tests to validate**: 
- Create specific tests for parallel_claude and gemini_instructor execution
- Verify integration scenarios work with new step types

---

### **Phase 3: Polish and Stabilization (Priority: Medium)**

**Goal**: Achieve 100% test pass rate and system stability

#### 3.1 Implement Claude Output Format Defaults
**Files to modify**:
- `lib/pipeline/config.ex` (add to defaults schema)
- `lib/pipeline/providers/claude_provider.ex` (use default when not specified)

**Implementation Plan**:
```elixir
# In config.ex defaults processing
defp apply_claude_defaults(step, defaults) do
  output_format = defaults["claude_output_format"] || "json"
  
  step_options = step["claude_options"] || %{}
  updated_options = Map.put_new(step_options, "output_format", output_format)
  
  Map.put(step, "claude_options", updated_options)
end
```

#### 3.2 Enhanced Error Handling and Validation
**Goals**:
- Better error messages for invalid configurations
- Graceful handling of missing dependencies
- Robust file operation error handling

**Implementation Areas**:
- Improve validation error messages in `config.ex`
- Add try-catch blocks around file operations in `prompt_builder.ex`
- Better error context in `executor.ex`

#### 3.3 Performance Optimization
**Based on performance test expectations**:
- Optimize prompt building for large files
- Improve memory usage in multi-step workflows
- Add caching for repeated file reads

---

### **Phase 4: Integration Testing and Bug Fixes (Priority: Medium)**

**Goal**: Ensure all integration scenarios work correctly

#### 4.1 Fix Integration Test Issues
**Files to verify**:
- `test/integration/workflow_scenarios_test.exs`
- `test/integration/live_api_test.exs`

**Key Scenarios to Test**:
1. **Code Review Workflow**: Multi-step with function calling
2. **Full-Stack Development**: Complex dependencies and file operations
3. **Data Analysis**: Previous response extraction with nested fields
4. **Error Recovery**: Failure handling and checkpoint recovery
5. **Feature Combination**: All configuration options working together

#### 4.2 Mock-to-Live Compatibility
**Ensure**:
- Mock responses match expected live API response formats
- Error scenarios are realistic
- Function calling responses follow actual Gemini patterns

---

### **Phase 5: Documentation and Final Validation (Priority: Low)**

#### 5.1 Update Configuration Examples
- Ensure all YAML examples in `PIPELINE_CONFIG_GUIDE.md` work
- Add examples for new conditional execution feature
- Document parallel_claude and gemini_instructor usage

#### 5.2 Final Test Suite Validation
**Complete Test Run Commands**:
```bash
# All unit tests should pass
mix test test/unit/ --include performance --include stress

# All integration tests should pass in mock mode
mix test test/integration/

# Performance benchmarks should meet targets
mix test test/unit/pipeline/workflow_performance_test.exs --include performance

# Configuration validation tests
mix test test/unit/pipeline/config_test.exs
```

---

## Success Criteria by Phase

### **Phase 1 Success**: ✅ COMPLETED
- [x] All unit tests pass: `mix test test/unit/`
- [x] No syntax errors or undefined function calls
- [x] Mock providers handle all test scenarios
- [x] Fixed mock provider interfaces with `set_response_pattern` functions
- [x] Fixed test file syntax errors from sed command damage
- [x] Implemented conditional step execution in executor.ex
- [x] Wired up missing step types (parallel_claude, gemini_instructor)

### **Phase 2 Success**: ✅ COMPLETED
- [x] Claude output format defaults implemented and tested
- [x] Enhanced error handling with descriptive messages
- [x] Performance optimizations (file caching, memory management)
- [x] Function calling support in basic Gemini steps
- [x] All 4 step types (claude, gemini, parallel_claude, gemini_instructor) execute
- [x] Unit tests pass with new features

### **Phase 3 Success**:
- [ ] 100% test pass rate: `mix test`
- [ ] Performance tests meet benchmarks
- [ ] No memory leaks detected

### **Phase 4 Success**:
- [ ] All integration tests pass: `mix test test/integration/`
- [ ] Complex workflow scenarios complete successfully
- [ ] Error scenarios handled gracefully

### **Phase 5 Success**:
- [ ] All documentation examples work
- [ ] Final comprehensive test run passes
- [ ] System ready for live API testing

## Risk Mitigation

### **High Risk Items**:
1. **Mock Interface Changes**: Could break existing functionality
   - **Mitigation**: Test after each small change, maintain backward compatibility

2. **Conditional Logic Complexity**: Could introduce subtle bugs
   - **Mitigation**: Start with simple string matching, add comprehensive test cases

3. **Step Type Integration**: May have interface mismatches
   - **Mitigation**: Verify interfaces match between step types before wiring

### **Testing Strategy**:
- **Incremental Development**: Make one small change, run tests, repeat
- **Mock-First Approach**: All functionality must work in mocks before live testing
- **Regression Prevention**: Run full test suite after each major change

## Next Steps

1. **Start with Phase 1.1**: Fix mock provider interfaces to support test expectations
2. **Validate incrementally**: After each change, run relevant test subset
3. **Maintain test coverage**: Ensure no functionality regressions
4. **Document issues**: Track any unexpected behaviors for live testing phase

This phased approach ensures a stable, well-tested system before moving to live API validation, minimizing the risk of issues in the more expensive live testing phase.