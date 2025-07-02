# Missing Pieces Implementation Prompts
**Date:** July 1, 2025  
**Goal:** Self-contained prompts for implementing 5 critical pipeline features systematically

Each prompt is designed to be run independently with full context. Read the specified files and implement the requested phase.

---

## Phase 1A: Enhanced Conditional Execution Engine

### Context Files to Read:
- `./lib/pipeline/executor.ex` (lines 1-50, 120-180) - Current condition evaluation
- `./lib/pipeline/step.ex` (lines 1-100) - Step execution patterns  
- `./examples/simple_test.yaml` (full file) - Basic workflow structure
- `./MISSING_PIECES_20250701.md` (lines 125-200) - Conditional execution requirements

### Task:
Create a new `Pipeline.Condition.Engine` module that supports complex boolean expressions for step conditions. Current system only supports simple truthy checks on previous step results.

**Requirements:**
1. Support AND/OR/NOT boolean logic
2. Comparison operators: `>`, `<`, `==`, `!=`, `contains`, `matches`
3. Dot notation for nested field access: `step_name.field.subfield`
4. Backward compatible with existing simple conditions

**Implementation:**
- Create `lib/pipeline/condition/engine.ex`
- Update `lib/pipeline/executor.ex` to use new engine
- Add comprehensive tests in `test/pipeline/condition_engine_test.exs`

**Expected YAML syntax:**
```yaml
condition:
  and:
    - "analysis.score > 7"
    - or:
      - "analysis.status == 'passed'"
      - "analysis.warnings.length < 3"
    - not: "analysis.errors.length > 0"
```

---

1A IS DONE!

---

## Phase 1B: Basic Loop Step Types

### Context Files to Read:
- `./lib/pipeline/step/claude.ex` (lines 1-50) - Step execution pattern
- `./lib/pipeline/executor.ex` (lines 80-150) - Context and step execution
- `./lib/pipeline/result_manager.ex` (lines 1-100) - Result handling
- `./MISSING_PIECES_20250701.md` (lines 250-320) - Loop requirements

### Task:
Implement `for_loop` and `while_loop` step types that can iterate over data and execute sub-steps.

**Requirements:**
1. `for_loop` iterates over arrays from previous step results
2. `while_loop` continues until condition becomes false
3. Loop variables accessible in sub-steps via `{{loop.variable}}`
4. Maximum iteration safety limits
5. Proper error handling and early termination

**Implementation:**
- Create `lib/pipeline/step/loop.ex`
- Add loop context management to executor
- Create tests in `test/pipeline/step/loop_test.exs`

**Expected YAML syntax:**
```yaml
- name: "process_files"
  type: "for_loop"
  iterator: "file"
  data_source: "previous_response:file_list"
  steps:
    - name: "analyze_file"
      type: "claude"
      prompt: "Analyze file: {{loop.file.name}}"

- name: "fix_until_passing"
  type: "while_loop"
  condition: "test_results.status != 'passed'"
  max_iterations: 5
  steps:
    - name: "fix_issues"
      type: "claude"
      prompt: "Fix based on: {{previous_response}}"
```

---

1B is DONE!


---

## Phase 1C: File Operations Step Type

### Context Files to Read:
- `./lib/pipeline/config.ex` (lines 1-50) - File loading patterns
- `./lib/pipeline/executor.ex` (lines 81-120) - Workspace management
- `./lib/pipeline/step/claude.ex` (lines 1-100) - Step implementation pattern
- `./MISSING_PIECES_20250701.md` (lines 50-125) - File I/O requirements

### Task:
Create a `file_ops` step type for comprehensive file operations within the pipeline workspace.

**Requirements:**
1. Operations: copy, move, delete, validate, list, convert
2. Support for workspace-relative and absolute paths
3. File validation (existence, size, permissions)
4. Format conversion (CSV, JSON, YAML, XML)
5. Atomic operations with error rollback

**Implementation:**
- Create `lib/pipeline/step/file_ops.ex`
- Add file utility functions in `lib/pipeline/utils/file_utils.ex`
- Create tests in `test/pipeline/step/file_ops_test.exs`

**Expected YAML syntax:**
```yaml
- name: "copy_config"
  type: "file_ops"
  operation: "copy"
  source: "templates/config.yaml"
  destination: "config/app.yaml"

- name: "validate_files"
  type: "file_ops"
  operation: "validate"
  files:
    - path: "lib/my_app.ex"
      must_exist: true
      min_size: 100
    - path: "test/"
      must_be_dir: true

- name: "convert_data"
  type: "file_ops"
  operation: "convert"
  source: "data.csv"
  destination: "data.json"
  format: "csv_to_json"
```
---

1c is done!

---

## Phase 2A: Schema Validation System

### Context Files to Read:
- `./lib/pipeline/result_manager.ex` (full file) - Current result handling
- `./lib/pipeline/step/gemini_instructor.ex` (lines 1-100) - Structured output pattern
- `./lib/pipeline/schemas/analysis_response.ex` (full file) - Existing schema example
- `./MISSING_PIECES_20250701.md` (lines 200-250) - Schema validation requirements

### Task:
Implement a comprehensive schema validation system for step outputs to ensure structured data exchange.

**Requirements:**
1. JSON Schema-based validation for step outputs
2. Automatic validation when `output_schema` is specified
3. Clear error messages for validation failures
4. Support for common data types and constraints
5. Integration with existing result management

**Implementation:**
- Create `lib/pipeline/validation/schema_validator.ex`
- Update result manager to use validation
- Add schema definitions in `lib/pipeline/schemas/`
- Create tests in `test/pipeline/validation/schema_validator_test.exs`

**Expected YAML syntax:**
```yaml
- name: "analyze_code"
  type: "claude"
  output_schema:
    type: "object"
    required: ["analysis", "recommendations", "score"]
    properties:
      analysis:
        type: "string"
        min_length: 50
      score:
        type: "number"
        minimum: 0
        maximum: 10
      recommendations:
        type: "array"
        items:
          type: "object"
          properties:
            priority: {type: "string", enum: ["high", "medium", "low"]}
            action: {type: "string"}
```
--

2a done


---

## Phase 2B: Data Transformation Step Type

### Context Files to Read:
- `./lib/pipeline/step.ex` (lines 1-100) - Step patterns
- `./lib/pipeline/result_manager.ex` (lines 50-150) - Data manipulation
- `./lib/pipeline/providers/gemini_provider.ex` (lines 100-150) - JSON handling
- `./MISSING_PIECES_20250701.md` (lines 200-250) - Data transformation requirements

### Task:
Create a `data_transform` step type for manipulating structured data between pipeline steps.

**Requirements:**
1. Operations: filter, map, aggregate, join, group_by, sort
2. JSONPath-like syntax for field access
3. Mathematical and string operations
4. Data type conversions
5. Chaining multiple transformations

**Implementation:**
- Create `lib/pipeline/step/data_transform.ex`
- Add transformation engine in `lib/pipeline/data/transformer.ex`
- Create tests in `test/pipeline/step/data_transform_test.exs`

**Expected YAML syntax:**
```yaml
- name: "process_results"
  type: "data_transform"
  input_source: "previous_response:analysis"
  operations:
    - operation: "filter"
      field: "recommendations"
      condition: "priority == 'high'"
    - operation: "aggregate"
      field: "scores"
      function: "average"
    - operation: "join"
      left_field: "files"
      right_source: "previous_response:file_metadata"
      join_key: "filename"
  output_field: "processed_data"
```

---

2b done

---

## Phase 2C: State Management with Variables

### Context Files to Read:
- `./lib/pipeline/executor.ex` (lines 80-120) - Context management
- `./lib/pipeline/checkpoint_manager.ex` (full file) - State persistence
- `./lib/pipeline/session_manager.ex` (lines 1-100) - Session state
- `./MISSING_PIECES_20250701.md` (lines 320-380) - State management requirements

### Task:
Implement pipeline state management with variables that persist across steps and can be modified during execution.

**Requirements:**
1. `set_variable` step type for variable assignment
2. Variable interpolation in step configurations
3. State persistence in checkpoints
4. Variable scoping (global, loop, session)
5. Type safety and validation

**Implementation:**
- Create `lib/pipeline/step/set_variable.ex`
- Add variable engine in `lib/pipeline/state/variable_engine.ex`
- Update executor for variable interpolation
- Create tests in `test/pipeline/state/variable_engine_test.exs`

**Expected YAML syntax:**
```yaml
- name: "initialize_state"
  type: "set_variable"
  variables:
    attempt_count: 0
    error_threshold: 3
    processed_files: []

- name: "increment_counter"
  type: "set_variable"
  variables:
    attempt_count: "{{state.attempt_count + 1}}"

- name: "conditional_step"
  type: "claude"
  condition: "state.attempt_count < state.error_threshold"
  prompt: "Attempt #{{state.attempt_count}}: Process data"
```

---

## Phase 3A: Codebase Discovery System

### Context Files to Read:
- `./lib/pipeline/executor.ex` (lines 81-120) - Workspace initialization
- `./lib/pipeline/config.ex` (lines 1-100) - Configuration patterns
- `./mix.exs` (full file) - Project structure example
- `./MISSING_PIECES_20250701.md` (lines 380-450) - Codebase context requirements

### Task:
Create a codebase discovery system that automatically analyzes project structure and provides intelligent context to pipeline steps.

**Requirements:**
1. Automatic project type detection (Elixir, Node.js, Python, etc.)
2. File structure analysis and categorization
3. Dependency parsing from configuration files
4. Git information integration
5. Intelligent file relationship mapping

**Implementation:**
- Create `lib/pipeline/codebase/context.ex`
- Add analyzers in `lib/pipeline/codebase/analyzers/`
- Create discovery engine in `lib/pipeline/codebase/discovery.ex`
- Create tests in `test/pipeline/codebase/context_test.exs`

**Expected Integration:**
```yaml
- name: "analyze_project"
  type: "claude"
  codebase_context: true
  prompt: |
    Analyze this {{codebase.project_type}} project.
    Main files: {{codebase.structure.main_files}}
    Dependencies: {{codebase.dependencies}}
    Recent changes: {{codebase.git_info.recent_commits}}
```

---

## Phase 3B: Codebase Query Step Type

### Context Files to Read:
- `./lib/pipeline/step.ex` (lines 1-100) - Step patterns
- Phase 3A implementation - Codebase context system
- `./lib/pipeline/step/claude.ex` (lines 50-100) - Context injection
- `./MISSING_PIECES_20250701.md` (lines 450-500) - Codebase query requirements

### Task:
Create a `codebase_query` step type that allows intelligent querying of project structure and code relationships.

**Requirements:**
1. File finding by patterns, types, and relationships
2. Code analysis queries (find functions, classes, imports)
3. Test relationship discovery
4. Dependency analysis
5. Change impact analysis

**Implementation:**
- Create `lib/pipeline/step/codebase_query.ex`
- Add query engine in `lib/pipeline/codebase/query_engine.ex`
- Add AST parsing utilities for different languages
- Create tests in `test/pipeline/step/codebase_query_test.exs`

**Expected YAML syntax:**
```yaml
- name: "find_related_files"
  type: "codebase_query"
  queries:
    main_modules:
      find_files:
        - type: "main"
        - pattern: "lib/**/*.ex"
        - exclude_tests: true
    test_files:
      find_files:
        - related_to: "{{previous_response:target_file}}"
        - type: "test"
    dependencies:
      find_dependencies:
        - for_file: "lib/user.ex"
        - include_transitive: false
```

---

## Phase 4A: Advanced Loop Features

### Context Files to Read:
- Phase 1B implementation - Basic loop system
- `./lib/pipeline/executor.ex` (lines 120-180) - Step execution
- `./lib/pipeline/step/parallel_claude.ex` (full file) - Parallel execution pattern
- `./MISSING_PIECES_20250701.md` (lines 320-380) - Advanced loop requirements

### Task:
Enhance the loop system with nested loops, parallel execution, and advanced control flow.

**Requirements:**
1. Nested loop support with proper variable scoping
2. Parallel loop execution for independent iterations
3. Loop control: break, continue, early termination
4. Performance optimization for large datasets
5. Memory management for long-running loops

**Implementation:**
- Enhance `lib/pipeline/step/loop.ex`
- Add parallel execution capabilities
- Implement loop control flow
- Create performance tests in `test/pipeline/step/loop_performance_test.exs`

**Expected YAML syntax:**
```yaml
- name: "nested_processing"
  type: "for_loop"
  iterator: "category"
  data_source: "categories"
  parallel: true
  max_parallel: 3
  steps:
    - name: "process_category_files"
      type: "for_loop"
      iterator: "file"
      data_source: "{{loop.category.files}}"
      steps:
        - name: "analyze_file"
          type: "claude"
          break_on_error: false
          prompt: "Analyze {{loop.file.path}} in {{loop.parent.category.name}}"
```

---

## Phase 4B: Advanced Condition Expressions

### Context Files to Read:
- Phase 1A implementation - Basic condition engine
- `./lib/pipeline/condition/engine.ex` (from Phase 1A)
- `./lib/pipeline/step/claude_smart.ex` (lines 50-100) - Smart decision making
- `./MISSING_PIECES_20250701.md` (lines 125-200) - Advanced conditional requirements

### Task:
Enhance the condition engine with mathematical expressions, functions, and pattern matching.

**Requirements:**
1. Mathematical expressions: `score * weight > threshold`
2. String functions: `contains()`, `matches()`, `length()`, `startsWith()`
3. Array functions: `any()`, `all()`, `count()`, `sum()`, `average()`
4. Date/time comparisons and arithmetic
5. Regular expression pattern matching

**Implementation:**
- Enhance `lib/pipeline/condition/engine.ex`
- Add expression parser and evaluator
- Add function library in `lib/pipeline/condition/functions.ex`
- Create comprehensive tests in `test/pipeline/condition/advanced_test.exs`

**Expected YAML syntax:**
```yaml
- name: "complex_decision"
  type: "claude"
  condition:
    and:
      - "analysis.score * analysis.confidence > 0.8"
      - "any(analysis.issues, 'severity == \"high\"') == false"
      - "length(analysis.recommendations) between 3 and 10"
      - "analysis.timestamp > now() - days(7)"
      - "analysis.file_path matches '.*\\.ex$'"
```

---

## Phase 4C: Streaming and Performance

### Context Files to Read:
- All previous implementations
- `./lib/pipeline/executor.ex` (lines 150-250) - Execution optimization
- `./lib/pipeline/result_manager.ex` (lines 100-200) - Memory management
- `./MISSING_PIECES_20250701.md` (lines 50-125) - Performance requirements

### Task:
Add streaming capabilities and performance optimizations for large-scale pipeline execution.

**Requirements:**
1. Streaming file I/O for large datasets
2. Memory-efficient loop execution
3. Result streaming between steps
4. Lazy evaluation where possible
5. Performance monitoring and metrics

**Implementation:**
- Add streaming capabilities to file operations
- Implement lazy evaluation in data transformations
- Add performance monitoring in `lib/pipeline/monitoring/performance.ex`
- Create load tests in `test/pipeline/performance/load_test.exs`

**Expected Features:**
- Stream processing for files >100MB
- Memory usage <500MB for any pipeline
- Execution metrics and bottleneck identification
- Configurable performance thresholds

---

## Testing and Validation Prompts

### Integration Test Suite

### Context Files to Read:
- All Phase implementations
- `./test/integration/` (full directory)
- `./examples/` (select representative pipelines)
- `./test/test_helper.exs` (full file)

### Task:
Create comprehensive integration tests that demonstrate real-world usage of all new features working together.

**Requirements:**
1. End-to-end workflow tests combining multiple features
2. Performance benchmarks for each new step type
3. Error handling and recovery scenarios
4. Mock mode tests for all new features
5. Real-world example pipelines

**Implementation:**
- Create `test/integration/missing_pieces_test.exs`
- Add example workflows in `examples/missing_pieces/`
- Create performance benchmarks
- Update test documentation

### Documentation Update

### Context Files to Read:
- All implementations
- `./README.md` (lines 150-400) - Current feature documentation
- `./LIBRARY_build.md` (lines 100-300) - Library usage patterns

### Task:
Update all documentation to reflect new capabilities and provide clear usage examples.

**Requirements:**
1. Update README.md with new step types
2. Add examples to LIBRARY_build.md
3. Create migration guide for existing pipelines
4. Update API documentation
5. Create tutorial for advanced features

---

## Usage Instructions

1. **Run prompts in order** - Each phase builds on previous implementations
2. **Test between phases** - Ensure stability before proceeding
3. **Read context files first** - Each prompt includes specific line numbers to focus on
4. **Implement incrementally** - Don't try to do everything at once
5. **Maintain backward compatibility** - Existing pipelines should continue working

Each prompt is self-contained and includes all necessary context to implement the feature from scratch.