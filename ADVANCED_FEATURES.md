# Advanced Pipeline Features Guide

**🎯 Library Status: Complete Implementation Ready** - This guide covers the 5 critical advanced features that transform pipeline_ex from an 8.5/10 library into a complete 10/10 AI engineering platform.

## Overview

This document covers the advanced features implemented to address the critical gaps identified in the missing pieces analysis. These features enable intelligent, self-correcting workflows with enterprise-grade capabilities.

## 🔄 1. Enhanced Loop Constructs

### For Loops
Execute steps iteratively over data collections with full variable scoping and error handling.

```yaml
- name: "process_files"
  type: "for_loop"
  iterator: "file"
  data_source: "previous_response:file_list"
  steps:
    - name: "analyze_file"
      type: "claude"
      prompt: "Analyze file: {{loop.file.name}}"
      
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
          prompt: "Analyze {{loop.file.path}} in {{loop.parent.category.name}}"
```

### While Loops
Continue execution until conditions are met with safety limits and early termination.

```yaml
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

### Loop Features
- **Variable Scoping**: `{{loop.variable}}` access with nested loop support (`{{loop.parent.variable}}`)
- **Parallel Execution**: Configure `parallel: true` with `max_parallel` limits
- **Safety Limits**: `max_iterations` prevents infinite loops
- **Error Handling**: `break_on_error` and graceful degradation
- **Performance**: Memory-efficient streaming for large datasets

## 🧠 2. Complex Conditional Logic

### Boolean Expressions
Advanced condition evaluation with AND/OR/NOT logic and comparison operators.

```yaml
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
```

### Comparison Operations
Support for mathematical and string comparison operations.

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

### Switch/Case Branching
Route execution based on values with default fallbacks.

```yaml
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

### Condition Features
- **Operators**: `>`, `<`, `==`, `!=`, `contains`, `matches`, `between`
- **Functions**: `length()`, `any()`, `all()`, `count()`, `sum()`, `average()`
- **Pattern Matching**: Regular expressions and string patterns
- **Date/Time**: Relative time comparisons and arithmetic
- **Mathematical**: Complex expressions with variables

## 📁 3. Advanced File Operations

### Core File Operations
Comprehensive file manipulation within pipeline workspaces.

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

### Supported Operations
- **copy**: Duplicate files with path resolution
- **move**: Relocate files atomically
- **delete**: Remove files and directories safely
- **validate**: Check existence, size, permissions
- **list**: Directory scanning with filters
- **convert**: Format transformations (CSV↔JSON↔YAML↔XML)

### File Operation Features
- **Atomic Operations**: Rollback on failure
- **Permission Checking**: Validate access before operations
- **Large File Streaming**: Memory-efficient processing
- **Workspace Relative**: Safe path resolution within workspaces
- **Binary Support**: Handle images, PDFs, and other binary formats

## 🔄 4. Structured Data Transformation

### Schema Validation
Enforce structured output formats with comprehensive validation.

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

### Data Transformation
Manipulate structured data between pipeline steps.

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

### Query Language
JSONPath-like syntax for complex data extraction.

```yaml
- name: "extract_high_priority"
  type: "data_transform"
  operations:
    - operation: "query"
      expression: "$.analysis[?(@.score > 7)].recommendations"
    - operation: "transform"
      expression: "$.files[*].{name: filename, size: filesize}"
```

### Data Features
- **JSON Schema**: Complete validation with clear error messages
- **Transformations**: filter, map, aggregate, join, group_by, sort
- **Query Engine**: JSONPath expressions with functions
- **Type Safety**: Automatic type conversion and validation
- **Chaining**: Multiple operations in sequence

## 🗂️ 5. Codebase Intelligence System

### Automatic Discovery
Intelligent project structure analysis and context awareness.

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

### Codebase Queries
Search and analyze code relationships intelligently.

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

### Code Analysis
AST parsing and semantic understanding for multiple languages.

```yaml
- name: "analyze_code_structure"
  type: "codebase_query"
  queries:
    functions:
      find_functions:
        - in_file: "lib/user.ex"
        - public_only: true
    dependencies:
      find_dependents:
        - of_file: "lib/user.ex"
        - include_tests: true
```

### Codebase Features
- **Project Detection**: Elixir, Node.js, Python, Go, Rust support
- **File Relationships**: Dependency mapping and impact analysis
- **Git Integration**: Commit history, branch status, change detection
- **Semantic Search**: Find functions, classes, imports across codebases
- **Test Mapping**: Automatic test-to-code relationship discovery

## 💾 6. State Management & Variables

### Variable Assignment
Persistent state management across pipeline execution.

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
```

### Variable Interpolation
Use variables throughout pipeline configurations.

```yaml
- name: "conditional_step"
  type: "claude"
  condition: "state.attempt_count < state.error_threshold"
  prompt: "Attempt #{{state.attempt_count}}: Process data"
```

### State Persistence
Maintain state across pipeline runs and checkpoint recovery.

```yaml
- name: "save_progress"
  type: "checkpoint"
  state:
    completed_files: "{{state.processed_files}}"
    last_successful_step: "{{current_step}}"
```

### State Features
- **Scoping**: Global, loop, and session variable scopes
- **Persistence**: Automatic checkpoint integration
- **Type Safety**: Variable validation and type checking
- **Interpolation**: Template variables in any configuration field
- **Mutation**: Safe state updates with rollback support

## 🚀 Performance & Streaming

### Large Dataset Processing
Memory-efficient handling of large files and data collections.

```yaml
- name: "process_large_dataset"
  type: "file_ops"
  operation: "stream_process"
  source: "large_data.csv"
  chunk_size: 1000
  processor:
    type: "claude"
    prompt: "Process data chunk: {{chunk}}"
```

### Parallel Execution
Concurrent processing with resource management.

```yaml
- name: "parallel_analysis"
  type: "for_loop"
  iterator: "file"
  data_source: "file_list"
  parallel: true
  max_parallel: 5
  memory_limit: "500MB"
  steps:
    - name: "analyze_file"
      type: "claude"
      prompt: "Analyze {{loop.file}}"
```

### Performance Features
- **Streaming I/O**: Process files without loading into memory
- **Lazy Evaluation**: Compute results only when needed
- **Resource Limits**: Memory and execution time constraints
- **Performance Monitoring**: Built-in metrics and bottleneck detection
- **Optimization**: Automatic query optimization and caching

## 🛠️ Integration Examples

### Complete Workflow Example
A real-world example combining all advanced features:

```yaml
workflow:
  name: "advanced_code_analysis"
  description: "Complete codebase analysis with intelligent processing"
  
  steps:
    - name: "discover_project"
      type: "codebase_query"
      codebase_context: true
      queries:
        project_info:
          get_project_type: true
          get_dependencies: true
          get_git_status: true
    
    - name: "initialize_analysis_state"
      type: "set_variable"
      variables:
        total_files: 0
        processed_files: []
        issues_found: []
        analysis_score: 0
    
    - name: "find_source_files"
      type: "codebase_query"
      queries:
        source_files:
          find_files:
            - type: "source"
            - exclude_tests: true
            - modified_since: "{{state.last_analysis_date}}"
    
    - name: "analyze_files"
      type: "for_loop"
      iterator: "file"
      data_source: "previous_response:source_files"
      parallel: true
      max_parallel: 3
      steps:
        - name: "analyze_single_file"
          type: "claude"
          output_schema:
            type: "object"
            required: ["file_path", "issues", "score"]
            properties:
              file_path: {type: "string"}
              issues:
                type: "array"
                items:
                  type: "object"
                  properties:
                    severity: {type: "string", enum: ["low", "medium", "high"]}
                    message: {type: "string"}
              score: {type: "number", minimum: 0, maximum: 10}
          prompt: |
            Analyze this {{codebase.project_type}} file: {{loop.file.path}}
            
            File content:
            ```
            {{file:{{loop.file.path}}}}
            ```
            
            Consider:
            - Code quality and style
            - Potential bugs or issues
            - Performance concerns
            - Security vulnerabilities
        
        - name: "update_analysis_state"
          type: "set_variable"
          variables:
            processed_files: "{{state.processed_files + [loop.file.path]}}"
            issues_found: "{{state.issues_found + previous_response.issues}}"
    
    - name: "filter_high_priority_issues"
      type: "data_transform"
      input_source: "state.issues_found"
      operations:
        - operation: "filter"
          condition: "severity == 'high'"
        - operation: "group_by"
          field: "file_path"
        - operation: "sort"
          field: "severity"
          order: "desc"
    
    - name: "generate_fixes"
      type: "while_loop"
      condition: "length(filtered_issues) > 0 and state.fix_attempts < 3"
      max_iterations: 3
      steps:
        - name: "attempt_fix"
          type: "claude"
          condition: 
            and:
              - "length(previous_response:filtered_issues) > 0"
              - "state.fix_attempts < 3"
          prompt: |
            Fix these high-priority issues:
            {{previous_response:filtered_issues}}
            
            Generate specific fix recommendations for each issue.
        
        - name: "increment_fix_attempts"
          type: "set_variable"
          variables:
            fix_attempts: "{{state.fix_attempts + 1}}"
    
    - name: "save_analysis_report"
      type: "data_transform"
      operations:
        - operation: "aggregate"
          input_source: "state"
          output_format: "analysis_report"
      
    - name: "export_results"
      type: "file_ops"
      operation: "convert"
      source: "analysis_report"
      destination: "analysis_report.json"
      format: "object_to_json"

    - name: "checkpoint_final_state"
      type: "checkpoint"
      state:
        analysis_complete: true
        total_issues: "{{length(state.issues_found)}}"
        high_priority_issues: "{{length(filtered_issues)}}"
        completion_time: "{{now()}}"
```

## 🧪 Testing & Validation

All advanced features support comprehensive testing:

### Mock Mode Testing
```bash
# Test all advanced features with mocks
mix pipeline.run examples/advanced_features_example.yaml

# Test specific feature sets
mix pipeline.run examples/loops_example.yaml
mix pipeline.run examples/conditions_example.yaml
mix pipeline.run examples/file_ops_example.yaml
mix pipeline.run examples/data_transform_example.yaml
mix pipeline.run examples/codebase_query_example.yaml
```

### Live Mode Testing
```bash
# Test with real AI providers
mix pipeline.run.live examples/advanced_features_example.yaml

# Performance testing
mix pipeline.benchmark examples/large_dataset_example.yaml
```

### Integration Testing
```bash
# Full integration test suite
mix test test/integration/advanced_features_test.exs

# Performance benchmarks
mix test test/performance/advanced_features_performance_test.exs
```

## 📚 Migration Guide

### From Basic to Advanced
Existing pipelines remain fully compatible. To use advanced features:

1. **Add Loop Processing**:
   ```yaml
   # Before: Single step
   - name: "analyze"
     type: "claude"
     prompt: "Analyze file1.ex"
   
   # After: Loop over multiple files
   - name: "analyze_all"
     type: "for_loop"
     iterator: "file"
     data_source: "file_list"
     steps:
       - name: "analyze"
         type: "claude"
         prompt: "Analyze {{loop.file}}"
   ```

2. **Add Conditional Logic**:
   ```yaml
   # Before: Always runs
   - name: "deploy"
     type: "claude"
     prompt: "Deploy application"
   
   # After: Conditional execution
   - name: "deploy"
     type: "claude"
     condition: "tests.status == 'passed' and analysis.score > 8"
     prompt: "Deploy application"
   ```

3. **Add Schema Validation**:
   ```yaml
   # Before: Unstructured output
   - name: "analyze"
     type: "claude"
     prompt: "Analyze code"
   
   # After: Structured output
   - name: "analyze"
     type: "claude"
     output_schema:
       type: "object"
       required: ["score", "issues"]
     prompt: "Analyze code and return JSON"
   ```

## 🎯 Best Practices

### Performance
- Use `parallel: true` for independent loop iterations
- Set appropriate `max_parallel` limits (typically 3-5)
- Use streaming for files >100MB
- Set memory limits for long-running processes

### Error Handling
- Always set `max_iterations` on while loops
- Use `break_on_error: false` for non-critical operations
- Implement fallback strategies with conditions
- Add checkpoints for long-running workflows

### Data Management
- Validate schemas early in pipelines
- Use data transformations to normalize between steps
- Keep state variables minimal and focused
- Clean up large temporary data regularly

### Codebase Intelligence
- Enable `codebase_context: true` for code analysis steps
- Cache codebase discovery results for multiple runs
- Use specific queries rather than broad scans
- Combine with file operations for intelligent refactoring

## 🔗 Related Documentation

- [LIBRARY_build.md](LIBRARY_build.md) - Complete library usage guide
- [PIPELINE_CONFIG_GUIDE.md](PIPELINE_CONFIG_GUIDE.md) - Configuration reference
- [examples/](examples/) - Working examples for all features
- [test/integration/](test/integration/) - Integration test examples

---

**Next Steps**: See [TESTING_STRATEGY.md](TESTING_STRATEGY.md) for comprehensive examples and testing approaches for each advanced feature.