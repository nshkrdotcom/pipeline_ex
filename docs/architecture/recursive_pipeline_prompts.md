# Recursive Pipeline Implementation Prompts

This document contains progressive implementation prompts for adding recursive pipeline support to pipeline_ex. Each phase builds on the previous one and must pass all tests before proceeding to the next phase.

---

## Phase 1: Core Infrastructure - Basic Nested Pipeline Execution

### Objective
Implement the foundational `Pipeline.Step.NestedPipeline` module that can execute simple nested pipelines from files or inline definitions.

### Required Reading
1. **Technical Design Document**: `/docs/architecture/20250103_recursive.md`
   - Focus on: Sections 4 (Design Overview) and 5 (Detailed Design)
   - Understand: Step definition schema, basic execution flow

2. **Core Pipeline Files**:
   - `/lib/pipeline/executor.ex` - Understand how steps are executed (lines 476-544)
   - `/lib/pipeline/config.ex` - Pipeline configuration loading
   - `/lib/pipeline/enhanced_config.ex` - Enhanced configuration handling
   - `/lib/pipeline/prompt_builder.ex` - How prompts are built and variables resolved

3. **Example Step Implementations**:
   - `/lib/pipeline/step/claude.ex` - Simple step implementation pattern
   - `/lib/pipeline/step/parallel_claude.ex` - Parallel execution pattern
   - `/lib/pipeline/step/loop.ex` - Complex control flow pattern

### Implementation Tasks

1. **Create the NestedPipeline Module**
   ```elixir
   # /lib/pipeline/step/nested_pipeline.ex
   defmodule Pipeline.Step.NestedPipeline do
     @moduledoc """
     Executes another pipeline as a step within the current pipeline.
     """
     
     require Logger
     alias Pipeline.{Config, Executor}
     
     def execute(step, context) do
       # 1. Load the pipeline (from file, ref, or inline)
       # 2. Create a basic nested context
       # 3. Execute the pipeline
       # 4. Return the results
     end
   end
   ```

2. **Update the Executor**
   - Add `"pipeline"` case to `do_execute_step/2` in `/lib/pipeline/executor.ex`
   - Handle basic error propagation

3. **Implement Pipeline Loading**
   - Support `pipeline_file` for external YAML files
   - Support `pipeline` for inline definitions
   - Basic validation of loaded pipelines

### Tests to Write

1. **Unit Tests** (`/test/pipeline/step/nested_pipeline_test.exs`):
   ```elixir
   defmodule Pipeline.Step.NestedPipelineTest do
     use ExUnit.Case
     
     describe "execute/2 - basic functionality" do
       test "executes inline pipeline successfully"
       test "loads and executes pipeline from file"
       test "returns error for missing pipeline file"
       test "returns error for invalid pipeline format"
       test "propagates errors from nested pipeline steps"
     end
   end
   ```

2. **Integration Tests** (`/test/integration/nested_pipeline_test.exs`):
   ```elixir
   defmodule Pipeline.Integration.NestedPipelineTest do
     use Pipeline.IntegrationCase
     
     test "simple nested pipeline end-to-end"
     test "nested pipeline with set_variable steps"
     test "error propagation from nested to parent"
   end
   ```

3. **Test Fixtures**:
   - `/test/fixtures/pipelines/simple_nested.yaml`
   - `/test/fixtures/pipelines/nested_with_error.yaml`

### Success Criteria
- [ ] All unit tests pass (minimum 5 tests)
- [ ] All integration tests pass (minimum 3 tests)
- [ ] Can execute a simple nested pipeline from file
- [ ] Can execute an inline nested pipeline
- [ ] Errors in nested pipelines are properly propagated
- [ ] No impact on existing pipeline functionality

### Example Test Pipeline
```yaml
# test/fixtures/pipelines/test_nested_basic.yaml
workflow:
  name: "test_nested_basic"
  steps:
    - name: "set_data"
      type: "set_variable"
      value: "test_data"
    
    - name: "nested_step"
      type: "pipeline"
      pipeline:
        name: "inline_test"
        steps:
          - name: "echo"
            type: "set_variable"
            value: "nested_result"
    
    - name: "verify"
      type: "set_variable"
      value: "{{steps.nested_step.result}}"
```

---

## Phase 2: Context Management - Variable Passing and Result Extraction

### Objective
Implement sophisticated context management including input mapping, output extraction, and context inheritance.

### Prerequisites
- Phase 1 completed with all tests passing
- Basic nested pipeline execution working

### Required Reading
1. **Technical Design Document**: `/docs/architecture/20250103_recursive.md`
   - Focus on: Context Management section
   - Understand: Context inheritance model, variable resolution

2. **Context and State Management**:
   - `/lib/pipeline/state/variable_engine.ex` - Variable resolution system
   - `/lib/pipeline/streaming/result_stream.ex` - Result handling
   - `/lib/pipeline/checkpoint_manager.ex` - State persistence

3. **Step Examples with Context Usage**:
   - `/lib/pipeline/step/data_transform.ex` - Data manipulation patterns
   - `/lib/pipeline/step/claude_extract.ex` - Result extraction patterns

### Implementation Tasks

1. **Enhance Context Creation**
   ```elixir
   defmodule Pipeline.Context.Nested do
     def create_nested_context(parent_context, step_config) do
       # 1. Handle input mappings
       # 2. Set up context inheritance
       # 3. Initialize nested state
       # 4. Track nesting depth
     end
     
     def extract_outputs(results, output_config) do
       # 1. Simple output extraction
       # 2. Path-based extraction
       # 3. Multiple output handling
     end
   end
   ```

2. **Implement Input Mapping**
   - Resolve variables from parent context
   - Support static values
   - Handle complex expressions

3. **Implement Output Extraction**
   - Extract specific step results
   - Support nested path extraction
   - Handle aliasing with `as` parameter

### Tests to Write

1. **Context Management Tests** (`/test/pipeline/context/nested_test.exs`):
   ```elixir
   test "maps inputs from parent context"
   test "supports static input values"
   test "resolves complex variable expressions"
   test "extracts simple outputs"
   test "extracts nested outputs with paths"
   test "handles missing output gracefully"
   ```

2. **Integration Tests**:
   ```elixir
   test "passes variables between parent and child pipelines"
   test "extracts multiple outputs from nested pipeline"
   test "inherits context when configured"
   test "isolates context when inheritance disabled"
   ```

3. **Property-Based Tests**:
   ```elixir
   property "input mappings preserve types"
   property "output extraction maintains data integrity"
   ```

### Success Criteria
- [ ] All Phase 1 tests still pass
- [ ] All new unit tests pass (minimum 8 tests)
- [ ] All integration tests pass (minimum 4 tests)
- [ ] Variables can be passed from parent to child
- [ ] Results can be extracted from nested pipelines
- [ ] Context inheritance works as designed

### Example Test Pipeline
```yaml
workflow:
  name: "test_context_management"
  steps:
    - name: "prepare_data"
      type: "set_variable"
      value:
        name: "test"
        count: 42
    
    - name: "process"
      type: "pipeline"
      pipeline_file: "./nested_processor.yaml"
      inputs:
        item_name: "{{steps.prepare_data.result.name}}"
        item_count: "{{steps.prepare_data.result.count}}"
        multiplier: 2
      outputs:
        - "final_count"
        - path: "analysis.summary"
          as: "summary_text"
      config:
        inherit_context: true
```

---

## Phase 3: Safety Features - Recursion Protection and Resource Management

### Objective
Implement safety mechanisms including recursion depth limits, circular dependency detection, and resource management.

### Prerequisites
- Phase 2 completed with all tests passing
- Context management fully functional

### Required Reading
1. **Technical Design Document**: `/docs/architecture/20250103_recursive.md`
   - Focus on: Safety and Resource Management section
   - Understand: Recursion limits, circular dependency detection

2. **Monitoring and Safety**:
   - `/lib/pipeline/monitoring/performance.ex` - Performance tracking
   - `/lib/pipeline/validation/schema_validator.ex` - Validation patterns
   - `/lib/pipeline/executor.ex` - Error handling patterns (lines 95-115)

3. **Resource Management Examples**:
   - `/lib/pipeline/checkpoint_manager.ex` - Resource cleanup patterns

### Implementation Tasks

1. **Implement Recursion Guards**
   ```elixir
   defmodule Pipeline.Safety.RecursionGuard do
     def check_depth(context, max_depth) do
       # Check nesting depth
     end
     
     def check_circular_dependency(pipeline_id, context) do
       # Build execution chain and detect cycles
     end
   end
   ```

2. **Add Resource Monitoring**
   - Track memory usage
   - Monitor execution time
   - Count total steps across all nested pipelines

3. **Implement Safety Limits**
   - Maximum nesting depth (configurable)
   - Maximum total steps
   - Memory limits
   - Timeout handling

### Tests to Write

1. **Safety Tests** (`/test/pipeline/safety/recursion_guard_test.exs`):
   ```elixir
   test "prevents infinite recursion"
   test "detects direct circular dependencies"
   test "detects indirect circular dependencies"
   test "respects maximum depth configuration"
   test "counts total steps across nested pipelines"
   ```

2. **Resource Management Tests**:
   ```elixir
   test "cleans up resources on error"
   test "respects memory limits"
   test "handles timeout in nested pipelines"
   test "isolates workspace directories"
   ```

3. **Edge Case Tests**:
   ```elixir
   test "handles deeply nested pipelines at limit"
   test "provides clear error for circular dependency"
   test "gracefully degrades when resources exhausted"
   ```

### Success Criteria
- [ ] All previous tests still pass
- [ ] All safety tests pass (minimum 8 tests)
- [ ] Circular dependencies are detected and prevented
- [ ] Recursion depth limits are enforced
- [ ] Resource cleanup happens on all error paths
- [ ] Clear error messages for limit violations

### Example Test Pipeline
```yaml
# Circular dependency test
workflow:
  name: "pipeline_a"
  steps:
    - name: "call_b"
      type: "pipeline"
      pipeline_file: "./pipeline_b.yaml"
      config:
        max_depth: 5

# pipeline_b.yaml
workflow:
  name: "pipeline_b"
  steps:
    - name: "call_a"
      type: "pipeline"
      pipeline_file: "./pipeline_a.yaml"  # Circular!
```

---

## Phase 4: Developer Experience - Error Handling and Debugging

### Objective
Enhance error messages, implement debugging tools, and create comprehensive logging for nested pipeline execution.

### Prerequisites
- Phase 3 completed with all tests passing
- Safety features fully implemented

### Required Reading
1. **Technical Design Document**: `/docs/architecture/20250103_recursive.md`
   - Focus on: Monitoring and Observability section
   - Understand: Execution tracing, debugging interface

2. **Error Handling and Logging**:
   - `/lib/pipeline/executor.ex` - Error handling patterns (lines 400-474)
   - `/lib/pipeline/monitoring/performance.ex` - Metrics collection
   - `/lib/pipeline/test/helpers.ex` - Test debugging utilities

### Implementation Tasks

1. **Enhanced Error Messages**
   ```elixir
   defmodule Pipeline.Error.NestedPipeline do
     def format_nested_error(error, context, step) do
       # Include full execution stack
       # Show pipeline hierarchy
       # Include relevant context
     end
   end
   ```

2. **Execution Tracing**
   - Track execution path through nested pipelines
   - Generate execution trees
   - Performance metrics per nesting level

3. **Debugging Tools**
   - Visual execution tree output
   - Step-by-step execution logs
   - Context inspection at each level

### Tests to Write

1. **Error Formatting Tests**:
   ```elixir
   test "includes full stack trace in errors"
   test "shows pipeline hierarchy in error messages"
   test "preserves original error details"
   test "formats timeout errors clearly"
   ```

2. **Debugging Tool Tests**:
   ```elixir
   test "generates accurate execution trees"
   test "logs execution at appropriate verbosity"
   test "tracks performance metrics correctly"
   ```

3. **Integration Tests**:
   ```elixir
   test "debugging output helps diagnose issues"
   test "performance metrics aggregate correctly"
   ```

### Success Criteria
- [ ] All previous tests pass
- [ ] Error messages clearly indicate failure location
- [ ] Execution trees accurately represent pipeline flow
- [ ] Performance metrics available for all nested levels
- [ ] Debugging tools aid in troubleshooting

### Example Enhanced Error Output
```
Pipeline execution failed in nested pipeline:
  
  Main Pipeline: data_processor
  └─ Step: analyze_data (pipeline)
     └─ Nested Pipeline: analysis_pipeline
        └─ Step: extract_themes (claude)
           └─ Error: API timeout after 30s
  
  Execution Stack:
    1. data_processor.analyze_data (depth: 0)
    2. analysis_pipeline.extract_themes (depth: 1)
  
  Context at failure:
    - Total steps executed: 15
    - Nesting depth: 1
    - Elapsed time: 32.5s
```

---

## Phase 5: Advanced Features - Performance and Caching

### Objective
Implement pipeline caching, performance optimizations, and advanced configuration options.

### Prerequisites
- Phase 4 completed with all tests passing
- Full feature set working correctly

### Required Reading
1. **Technical Design Document**: `/docs/architecture/20250103_recursive.md`
   - Focus on: Performance Considerations section
   - Understand: Caching strategies, optimization approaches

2. **Performance and Caching**:
   - `/lib/pipeline/monitoring/performance.ex` - Performance infrastructure
   - `/lib/pipeline/providers/gemini_provider.ex` - Provider caching patterns
   - `/lib/pipeline/config.ex` - Configuration caching

### Implementation Tasks

1. **Pipeline Caching**
   ```elixir
   defmodule Pipeline.Cache.PipelineCache do
     use GenServer
     
     def get_or_load(pipeline_ref) do
       # Check cache with TTL
       # Load if not cached
       # Handle cache invalidation
     end
   end
   ```

2. **Performance Optimizations**
   - Lazy loading of sub-pipelines
   - Context structure pooling
   - Parallel nested pipeline execution

3. **Advanced Configuration**
   - Pipeline registry support
   - Template variable system
   - Conditional nested execution

### Tests to Write

1. **Caching Tests**:
   ```elixir
   test "caches loaded pipelines"
   test "respects cache TTL"
   test "invalidates cache on file change"
   test "handles concurrent cache access"
   ```

2. **Performance Tests**:
   ```elixir
   test "parallel nested execution improves performance"
   test "context pooling reduces memory allocation"
   test "lazy loading delays pipeline parsing"
   ```

3. **Benchmark Tests**:
   ```elixir
   @tag :benchmark
   test "nested vs flat pipeline performance"
   test "caching impact on repeated execution"
   test "memory usage with deep nesting"
   ```

### Success Criteria
- [ ] All previous tests pass
- [ ] Pipeline caching reduces load time by >50%
- [ ] Memory usage remains stable with repeated execution
- [ ] Parallel execution works when safe
- [ ] Advanced features don't impact basic functionality
- [ ] Benchmarks show acceptable performance

### Example Advanced Configuration
```yaml
workflow:
  name: "advanced_nested"
  steps:
    - name: "parallel_processing"
      type: "parallel_claude"
      parallel_tasks:
        - id: "task1"
          type: "pipeline"
          pipeline_ref: "registered_analyzer"  # From registry
          
        - id: "task2"
          type: "pipeline"
          pipeline_file: "./processor.yaml"
          config:
            cache_ttl: 3600  # Cache for 1 hour
    
    - name: "conditional_nested"
      type: "pipeline"
      condition: "{{steps.parallel_processing.task1.success}}"
      pipeline_file: "./followup.yaml"
      config:
        lazy_load: true  # Don't load unless condition met
```

---

## Final Integration Testing

After all phases are complete, run comprehensive integration tests:

1. **End-to-End Scenarios**:
   - Complex multi-level nesting
   - Real-world pipeline compositions
   - Error recovery scenarios

2. **Performance Validation**:
   - Load testing with deep nesting
   - Memory usage profiling
   - Execution time benchmarks

3. **Compatibility Testing**:
   - All existing pipelines still work
   - Mix of old and new step types
   - Upgrade scenarios

### Success Criteria for Complete Feature
- [ ] All phase tests pass (50+ tests total)
- [ ] No regression in existing functionality
- [ ] Performance meets design goals
- [ ] Documentation is complete
- [ ] Examples cover common use cases