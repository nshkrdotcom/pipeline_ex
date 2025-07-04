# Missing Pieces Implementation Plan
**Date:** July 1, 2025  
**Current Status:** Pipeline_ex 8.5/10 Library Ready  
**Goal:** Implement 5 critical features for intelligent, self-correcting workflows

## Current Codebase Analysis

### Strengths (What We Have)
- ✅ **Solid Foundation**: Step architecture, provider abstraction, configuration management
- ✅ **Basic File I/O**: File reading, output saving, workspace management, checkpoint persistence
- ✅ **Result Management**: Comprehensive storage, JSON handling, field extraction
- ✅ **Simple Conditionals**: Basic step conditions with dot notation access
- ✅ **Session State**: Claude sessions, checkpointing, result chaining
- ✅ **Testing Framework**: Mock providers, comprehensive test coverage

### Critical Gaps (What We Need)
1. **Loop constructs** - No iteration primitives
2. **Complex conditionals** - No AND/OR logic or comparisons  
3. **File operations** - No generic file manipulation steps
4. **Data transformation** - No dedicated data processing steps
5. **Codebase intelligence** - No project structure awareness

---

## 1. Robust File I/O Enhancement

### Current State ✅
```elixir
# What exists:
- PromptBuilder.read_file_with_cache/1
- Executor.save_step_output/3  
- Workspace directory creation
- CheckpointManager file persistence
```

### Missing Capabilities ❌
- Generic file operations (copy, move, delete)
- Directory operations and bulk processing
- File format conversions (CSV, XML, JSON)
- File validation and permission checking
- Large file streaming support

### Implementation Plan

#### Phase 1: Core File Operations Step Type
```yaml
# New step type: file_ops
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
```

#### Phase 2: File Processing Utilities
```elixir
# lib/pipeline/step/file_ops.ex
defmodule Pipeline.Step.FileOps do
  @operations ~w(copy move delete validate list convert)
  
  def execute(%{"operation" => op} = step, context) when op in @operations do
    case op do
      "copy" -> handle_copy(step, context)
      "move" -> handle_move(step, context) 
      "delete" -> handle_delete(step, context)
      "validate" -> handle_validate(step, context)
      "list" -> handle_list(step, context)
      "convert" -> handle_convert(step, context)
    end
  end
  
  defp handle_convert(%{"format" => format} = step, context) do
    # CSV -> JSON, XML -> YAML, etc.
  end
end
```

#### Phase 3: Advanced Features
- Streaming file processing for large datasets
- Atomic file operations with rollback
- File watching and change detection
- Binary file handling (images, PDFs)

---

## 2. Structured Data Exchange Enhancement

### Current State ✅
```elixir
# What exists:
- ResultManager with JSON serialization
- PromptBuilder field extraction
- transform_for_prompt with format options
- Basic result validation
```

### Missing Capabilities ❌
- Schema validation and enforcement
- Data transformation and manipulation steps
- Format conversion utilities
- Data aggregation operations
- Query language for complex extraction

### Implementation Plan

#### Phase 1: Schema Validation System
```yaml
# Enhanced structured output with schema
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

#### Phase 2: Data Transformation Step Type
```yaml
- name: "process_results"
  type: "data_transform"
  operations:
    - operation: "filter"
      field: "recommendations"
      condition: "priority == 'high'"
    - operation: "aggregate" 
      field: "scores"
      function: "average"
    - operation: "join"
      left_field: "analysis.files"
      right_data: "previous_response:file_list"
      join_key: "filename"
```

#### Phase 3: Query Language
```elixir
# lib/pipeline/data/query_engine.ex
defmodule Pipeline.Data.QueryEngine do
  # JSONPath-like queries
  def query(data, "$.analysis[?(@.score > 7)].recommendations")
  def query(data, "$.files[*].{name: filename, size: filesize}")
  
  # Aggregation functions
  def aggregate(data, :sum, "scores")
  def aggregate(data, :group_by, "category")
end
```

---

## 3. Conditional Execution Enhancement

### Current State ✅
```elixir
# What exists:
- should_execute_step?/2 with basic conditions
- Dot notation field access (step_name.field)
- truthy?/1 evaluation function
- Skip logging for conditional steps
```

### Missing Capabilities ❌
- Complex boolean expressions (AND/OR/NOT)
- Comparison operators (>, <, ==, !=, contains)
- Mathematical expressions and calculations
- Pattern matching and regex conditions
- Dynamic condition evaluation

### Implementation Plan

#### Phase 1: Expression Language
```yaml
# Complex conditions with boolean logic
- name: "conditional_step"
  type: "claude"
  condition: 
    and:
      - "analysis.score > 7"
      - or:
        - "analysis.status == 'passed'"
        - "analysis.warnings.length < 3"
      - not: "analysis.errors.length > 0"
  prompt: "Proceed with implementation..."

# Comparison and pattern matching
- name: "error_handler"
  type: "claude" 
  condition:
    or:
      - "test_results.status matches 'fail.*'"
      - "test_results.errors contains 'timeout'"
      - "test_results.duration > 300"
```

#### Phase 2: Condition Engine
```elixir
# lib/pipeline/condition/engine.ex
defmodule Pipeline.Condition.Engine do
  def evaluate(condition, context) do
    case condition do
      %{"and" => conditions} -> 
        Enum.all?(conditions, &evaluate(&1, context))
      %{"or" => conditions} ->
        Enum.any?(conditions, &evaluate(&1, context))  
      %{"not" => condition} ->
        not evaluate(condition, context)
      binary when is_binary(binary) ->
        evaluate_expression(binary, context)
    end
  end
  
  defp evaluate_expression(expr, context) do
    # Parse expressions like "step.field > 5"
    # Support operators: >, <, ==, !=, contains, matches
    # Support functions: length, count, sum, etc.
  end
end
```

#### Phase 3: Advanced Flow Control
```yaml
# Switch/case-like branching
- name: "route_by_status"
  type: "switch"
  expression: "analysis.status"
  cases:
    "passed": 
      - name: "deploy_step"
        type: "claude"
        prompt: "Deploy the application..."
    "failed":
      - name: "fix_step" 
        type: "claude"
        prompt: "Fix the identified issues..."
    "warning":
      - name: "review_step"
        type: "claude"
        prompt: "Review warnings and decide..."
  default:
    - name: "unknown_status"
      type: "claude"
      prompt: "Handle unknown status..."
```

---

## 4. State Management & Looping

### Current State ✅
```elixir
# What exists:
- Execution context with results and logs
- SessionManager for persistent conversations
- CheckpointManager for pipeline state recovery
- Result chaining via previous_response
```

### Missing Capabilities ❌
- Loop primitives (for, while, until)
- Iteration variables and counters
- State mutation and variable assignment
- Data-driven iteration (foreach)
- Loop control (break, continue)

### Implementation Plan

#### Phase 1: Basic Loop Step Types
```yaml
# For loop with counter
- name: "process_files"
  type: "for_loop" 
  iterator: "file"
  data_source: "previous_response:file_list"
  steps:
    - name: "analyze_file"
      type: "claude"
      prompt: "Analyze file: {{loop.file.name}}"
      
# While loop with condition
- name: "fix_until_passing"
  type: "while_loop"
  condition: "test_results.status != 'passed'"
  max_iterations: 5
  steps:
    - name: "run_tests"
      type: "claude"
      prompt: "Run tests and analyze failures"
    - name: "fix_issues"
      type: "claude" 
      prompt: "Fix the failing tests based on: {{previous_response}}"
```

#### Phase 2: Loop Implementation
```elixir
# lib/pipeline/step/loop.ex
defmodule Pipeline.Step.Loop do
  def execute(%{"type" => "for_loop"} = step, context) do
    %{"iterator" => var_name, "data_source" => source, "steps" => loop_steps} = step
    
    data = resolve_data_source(source, context)
    
    Enum.reduce_while(data, {:ok, %{}}, fn item, {:ok, acc_results} ->
      # Set loop variable in context
      loop_context = put_in(context.loop_vars[var_name], item)
      
      case execute_loop_steps(loop_steps, loop_context) do
        {:ok, step_results} -> {:cont, {:ok, Map.merge(acc_results, step_results)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
  
  def execute(%{"type" => "while_loop"} = step, context) do
    %{"condition" => condition, "steps" => loop_steps} = step
    max_iterations = Map.get(step, "max_iterations", 10)
    
    execute_while_loop(condition, loop_steps, context, 0, max_iterations, %{})
  end
end
```

#### Phase 3: Advanced State Management
```yaml
# Variable assignment and mutation
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
    
# State persistence across pipeline runs
- name: "save_progress"
  type: "checkpoint"
  state:
    completed_files: "{{state.processed_files}}"
    last_successful_step: "{{current_step}}"
```

---

## 5. Codebase Context Object

### Current State ✅
```elixir
# What exists:
- Workspace directory management
- File path resolution in context
- Basic file access via PromptBuilder
- Environment and configuration access
```

### Missing Capabilities ❌
- Automatic project structure discovery
- Code analysis and AST parsing
- Git integration and version control awareness
- Project metadata parsing (package.json, mix.exs)
- Semantic file search and relationship mapping

### Implementation Plan

#### Phase 1: Codebase Discovery
```elixir
# lib/pipeline/codebase/context.ex
defmodule Pipeline.Codebase.Context do
  defstruct [
    :root_path,
    :project_type,  # :elixir, :javascript, :python, etc.
    :files,         # %{path => %{type, size, modified, etc}}
    :dependencies,  # parsed from package.json, mix.exs, etc.
    :git_info,      # %{branch, commit, status, etc}
    :structure      # %{directories, main_files, test_files, etc}
  ]
  
  def discover(workspace_dir) do
    %__MODULE__{
      root_path: workspace_dir,
      project_type: detect_project_type(workspace_dir),
      files: scan_files(workspace_dir),
      dependencies: parse_dependencies(workspace_dir),
      git_info: get_git_info(workspace_dir),
      structure: analyze_structure(workspace_dir)
    }
  end
end
```

#### Phase 2: Intelligent File Operations
```yaml
# Using codebase context in steps
- name: "analyze_project"
  type: "claude"
  codebase_context: true  # Inject codebase context
  prompt: |
    Analyze this {{codebase.project_type}} project.
    Main files: {{codebase.structure.main_files}}
    Dependencies: {{codebase.dependencies}}
    Recent changes: {{codebase.git_info.recent_commits}}

- name: "find_related_files"
  type: "codebase_query"
  query:
    find_files:
      - related_to: "lib/user.ex"
      - type: "test"
      - modified_since: "2024-01-01"
```

#### Phase 3: Advanced Code Intelligence
```elixir
# lib/pipeline/codebase/analyzer.ex
defmodule Pipeline.Codebase.Analyzer do
  # AST parsing for different languages
  def parse_elixir_file(path), do: # Use Code.string_to_quoted
  def parse_javascript_file(path), do: # Use external parser
  
  # Dependency analysis
  def find_dependents(file_path, codebase)
  def find_dependencies(file_path, codebase)
  
  # Semantic search
  def find_functions_by_name(name, codebase)
  def find_similar_code(code_snippet, codebase)
  
  # Test relationship mapping
  def find_tests_for_file(file_path, codebase)
  def find_file_for_test(test_path, codebase)
end
```

---

## Implementation Roadmap

### Phase 1: Foundation (2-3 weeks)
**Priority: HIGH** - Core loop and conditional capabilities
1. ✅ Implement `Loop` step type (`for_loop`, `while_loop`) 
2. ✅ Enhance `Condition.Engine` with complex expressions
3. ✅ Add `file_ops` step type for basic file operations
4. ✅ Create comprehensive tests for new step types

### Phase 2: Data & State (2-3 weeks)
**Priority: HIGH** - Structured data and state management
1. ✅ Implement schema validation system
2. ✅ Add `data_transform` step type
3. ✅ Enhance state management with variables
4. ✅ Add `set_variable` and `checkpoint` step types

### Phase 3: Intelligence (3-4 weeks)
**Priority: MEDIUM** - Codebase awareness and advanced features
1. ✅ Implement `Codebase.Context` discovery system
2. ✅ Add `codebase_query` step type
3. ✅ Integrate AST parsing for code analysis
4. ✅ Add git integration capabilities

### Phase 4: Polish (1-2 weeks)
**Priority: LOW** - Advanced features and optimization
1. ✅ Add streaming file I/O support
2. ✅ Implement nested loop support
3. ✅ Add advanced query language features
4. ✅ Performance optimization and caching

## Success Metrics

### Functional Goals
- [ ] Execute a loop that processes a list of files
- [ ] Use complex conditions with AND/OR logic
- [ ] Transform and validate structured data between steps
- [ ] Maintain state across multiple pipeline iterations
- [ ] Automatically discover and analyze project structure

### Technical Goals
- [ ] All new step types have >95% test coverage
- [ ] Integration tests demonstrate real-world workflows
- [ ] Performance benchmarks show <10% overhead
- [ ] Documentation includes usage examples for all features
- [ ] Backward compatibility maintained for existing pipelines

### User Experience Goals
- [ ] YAML configuration syntax remains intuitive
- [ ] Error messages are clear and actionable
- [ ] Mock mode supports all new step types
- [ ] Examples demonstrate practical use cases
- [ ] Migration guide helps upgrade existing workflows

## Risk Assessment

### High Risk
- **Complex condition parsing** - Expression language could become too complex
- **Loop performance** - Large datasets might cause memory/timeout issues
- **AST parsing** - External dependencies for multiple languages

### Medium Risk  
- **State management** - Variable scoping could become confusing
- **Codebase discovery** - Different project structures need different approaches
- **File operations** - Atomic operations and error handling complexity

### Low Risk
- **Schema validation** - Well-established patterns available
- **Data transformation** - Straightforward data manipulation
- **Documentation** - Clear examples should be sufficient

## Next Steps

1. **Review and approve** this implementation plan
2. **Set up development branch** for missing pieces work
3. **Implement Phase 1** starting with loop and condition enhancements
4. **Create comprehensive test suite** for each new feature
5. **Update documentation** as features are implemented
6. **Plan integration testing** with real-world scenarios

---

**Note:** This plan builds on the existing 8.5/10 library foundation. Each phase can be implemented incrementally while maintaining backward compatibility and the clean API that makes pipeline_ex ready for production use.