# Complete Test Infrastructure Cleanup - Self-Contained Implementation Prompt

## Context & Objective

You are implementing the final cleanup of the Pipeline test infrastructure to resolve the remaining 12 test failures. The pipeline system is 98% functional with 593/605 tests passing. All failures are infrastructure/test-related, not core functionality issues.

## Required Reading

**PRIMARY REFERENCE**: Read `/home/home/p/g/n/pipeline_ex/20250701_final_test_cleanup.md` completely for:
- Detailed failure analysis
- Root cause identification
- Specific solution requirements
- Implementation phases

**SUPPORTING CONTEXT**:
- Current pipeline architecture in `CLAUDE.md`
- Test infrastructure in `test/support/` directory
- Performance monitoring in `lib/pipeline/monitoring/performance.ex`
- Main executor in `lib/pipeline/executor.ex`

## Current Test Status
- **Total Tests**: 605
- **Passing**: 593 (98%)
- **Failing**: 12 (infrastructure issues only)
- **Categories**: Process management (8), Data resolution (2), Test expectations (2)

## Implementation Tasks

### PHASE 1: Critical Fixes (IMMEDIATE - Complete these first)

#### Task 1.1: Fix Process Management Error in Executor
**File**: `lib/pipeline/executor.ex`
**Line**: 43
**Problem**: `Logger.warning("⚠️  Failed to start performance monitoring: #{reason}")` fails when `reason` is `{:already_started, pid}`

**Required Fix**:
```elixir
case Performance.start_monitoring(pipeline_name, opts) do
  {:ok, _pid} -> 
    Logger.debug("📊 Performance monitoring started for: #{pipeline_name}")
  {:already_started, _pid} ->
    Logger.debug("📊 Performance monitoring already running for: #{pipeline_name}")
  {:error, reason} -> 
    Logger.warning("⚠️  Failed to start performance monitoring: #{inspect(reason)}")
end
```

#### Task 1.2: Fix Data Source Resolution in Basic Performance Test
**File**: `test/pipeline/performance/basic_performance_test.exs`
**Line**: 133
**Problem**: `data_source: "previous_response:create_data.variables.items"` format incorrect

**Investigation Required**:
1. Check how `set_variable` step stores results
2. Verify correct data source format for loop steps
3. Fix the test to use correct format

**Reference**: Look at existing working loop tests in `test/pipeline/step/loop_test.exs` for correct patterns

#### Task 1.3: Fix Loop Performance Test Expectations
**File**: `test/pipeline/step/loop_performance_test.exs`
**Line**: 246
**Problem**: `assert results["parallel"] == true` - result structure mismatch

**Investigation Required**:
1. Run the test to see actual result structure
2. Update assertion to match actual structure
3. Ensure test validates correct behavior

### PHASE 2: Infrastructure Enhancements (AFTER Phase 1 complete)

#### Task 2.1: Create Process Management Helper
**File**: `test/support/process_helper.ex` (NEW FILE)

**Required Implementation**:
```elixir
defmodule Pipeline.Test.ProcessHelper do
  @moduledoc """
  Helper utilities for managing processes in tests.
  """

  alias Pipeline.Monitoring.Performance

  def safe_start_monitoring(name, opts \\ []) do
    case Performance.start_monitoring(name, opts) do
      {:ok, pid} -> {:ok, pid}
      {:already_started, pid} -> {:ok, pid}
      error -> error
    end
  end
  
  def ensure_stopped(name) do
    case Performance.stop_monitoring(name) do
      {:ok, metrics} -> {:ok, metrics}
      {:error, :not_found} -> :ok
      error -> error
    end
  end
  
  def cleanup_all_monitoring do
    try do
      Registry.select(Pipeline.MonitoringRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$2"]}])
      |> Enum.each(fn pid ->
        if Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)
    rescue
      _ -> :ok
    end
  end
end
```

#### Task 2.2: Create Data Source Test Helper
**File**: `test/support/data_source_helper.ex` (NEW FILE)

**Required Implementation**:
```elixir
defmodule Pipeline.Test.DataSourceHelper do
  @moduledoc """
  Helper utilities for testing data source resolution.
  """

  def create_test_context(step_name, variables) when is_map(variables) do
    %{
      results: %{
        step_name => %{
          "variables" => variables,
          "success" => true
        }
      }
    }
  end
  
  def create_test_context(step_name, data) do
    %{
      results: %{
        step_name => data
      }
    }
  end
  
  def format_variable_source(step_name, variable_name) do
    "previous_response:#{step_name}.variables.#{variable_name}"
  end
  
  def format_result_source(step_name, field_path \\ nil) do
    if field_path do
      "previous_response:#{step_name}.#{field_path}"
    else
      "previous_response:#{step_name}"
    end
  end
end
```

#### Task 2.3: Update Performance Tests to Use Helpers
**Files**: 
- `test/pipeline/performance/load_test.exs`
- `test/pipeline/performance/basic_performance_test.exs`

**Required Changes**:
1. Import helper modules
2. Replace direct Performance calls with helper calls
3. Use standardized data source formats
4. Implement proper cleanup

### PHASE 3: Validation (AFTER Phase 2 complete)

#### Task 3.1: Run Complete Test Suite
```bash
mix test --seed 1
```
**Expected**: 0 failures, 605 tests passing

#### Task 3.2: Run Performance Tests Specifically
```bash
mix test test/pipeline/performance/ --seed 1
```
**Expected**: All performance tests passing

#### Task 3.3: Run Load Tests
```bash
mix test test/pipeline/performance/load_test.exs --seed 1
```
**Expected**: All load tests passing

## Key Files and Locations

### Files to Modify
1. `lib/pipeline/executor.ex:43` - Process management error
2. `test/pipeline/performance/basic_performance_test.exs:133` - Data source format
3. `test/pipeline/step/loop_performance_test.exs:246` - Test expectations

### Files to Create
1. `test/support/process_helper.ex` - Process management utilities
2. `test/support/data_source_helper.ex` - Data source test utilities

### Reference Files (READ ONLY)
1. `20250701_final_test_cleanup.md` - Complete analysis
2. `test/pipeline/step/loop_test.exs` - Working loop test patterns
3. `lib/pipeline/monitoring/performance.ex` - Performance monitoring API
4. `test/support/enhanced_test_case.ex` - Existing test infrastructure

## Debugging Guidelines

### For Process Management Issues
1. Check `Performance.start_monitoring/2` return values
2. Verify Registry is running: `Registry.whereis(Pipeline.MonitoringRegistry, name)`
3. Use `inspect/1` for safe tuple/error logging

### For Data Source Issues
1. Print actual context structure: `IO.inspect(context.results, label: "Context")`
2. Test data source resolution manually
3. Check `set_variable` step result format

### For Test Expectation Issues
1. Print actual results: `IO.inspect(results, label: "Actual Results")`
2. Compare with expected structure
3. Update test assertions accordingly

## Success Criteria

### Phase 1 Complete ✅
- No string interpolation errors in logs
- Basic performance test passes
- Loop performance test passes

### Phase 2 Complete ✅  
- All performance tests use helper functions
- Clean test isolation and cleanup
- Standardized data source patterns

### Phase 3 Complete ✅
- All 605 tests passing
- No warnings or compilation errors
- Stable test suite for CI/CD

## Error Patterns to Watch For

### Process Management
```
** (Protocol.UndefinedError) protocol String.Chars not implemented for type Tuple
Got value: {:already_started, #PID<...>}
```

### Data Source Resolution
```
"Step 'process_items' failed: No previous_response found"
"Step 'process_items' failed: Field not found in step result: items"
```

### Test Structure
```
Assertion with == failed
code:  assert results["field"] == expected
left:  nil
right: expected_value
```

## Additional Context

The pipeline system itself is fully functional - these are purely test infrastructure issues. The implementation has successfully added:
- Streaming file operations (>100MB)
- Memory-efficient loop processing 
- Result streaming between steps
- Lazy evaluation for data transforms
- Real-time performance monitoring

Focus on test reliability and infrastructure robustness rather than core functionality changes.

## Final Notes

1. **Test in Phases**: Complete Phase 1 before moving to Phase 2
2. **Validate Each Fix**: Run specific tests after each change
3. **Preserve Existing Functionality**: Only fix failures, don't modify working tests
4. **Document Changes**: Update test documentation if patterns change

The goal is 100% test reliability while maintaining the robust pipeline functionality that's already working.