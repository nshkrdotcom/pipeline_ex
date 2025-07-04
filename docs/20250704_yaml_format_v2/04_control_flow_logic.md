# Control Flow & Logic Reference

## Table of Contents

1. [Overview](#overview)
2. [Conditional Execution](#conditional-execution)
   - [Simple Conditions](#simple-conditions)
   - [Boolean Expressions](#boolean-expressions)
   - [Comparison Operators](#comparison-operators)
   - [Complex Conditions](#complex-conditions)
3. [Loop Constructs](#loop-constructs)
   - [For Loops](#for-loops)
   - [While Loops](#while-loops)
   - [Nested Loops](#nested-loops)
   - [Parallel Loops](#parallel-loops)
4. [Branching Logic](#branching-logic)
   - [Switch/Case](#switchcase)
   - [Multi-Branch Conditions](#multi-branch-conditions)
5. [State Management](#state-management)
   - [Variables](#variables)
   - [Variable Scoping](#variable-scoping)
   - [State Persistence](#state-persistence)
6. [Parallel Execution](#parallel-execution)
   - [Parallel Steps](#parallel-steps)
   - [Synchronization](#synchronization)
7. [Error Handling & Recovery](#error-handling--recovery)
8. [Advanced Patterns](#advanced-patterns)

## Overview

Pipeline's control flow system enables sophisticated workflow orchestration through:

- **Conditional execution** based on runtime values
- **Loop constructs** for iterative processing
- **Branching logic** for decision trees
- **State management** for workflow variables
- **Parallel execution** for concurrent processing
- **Error handling** with recovery strategies

## Conditional Execution

### Simple Conditions

Basic conditional step execution:

```yaml
steps:
  - name: "analyze_code"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Analyze code quality and set needs_refactoring flag"
    
  - name: "refactor_code"
    type: "claude"
    condition: "steps.analyze_code.needs_refactoring"
    prompt:
      - type: "static"
        content: "Refactor the identified issues"
```

**Field-based conditions**:
```yaml
# Boolean field check
condition: "steps.previous.success"

# Null/existence check
condition: "steps.scan.vulnerabilities"

# Array emptiness
condition: "steps.find.results"
```

### Boolean Expressions

Complex boolean logic with AND/OR/NOT:

```yaml
condition:
  and:
    - "steps.tests.passed"
    - "steps.security.score > 80"
    - or:
      - "environment.mode == 'production'"
      - "config.force_deploy == true"
    - not: "steps.lint.has_errors"
```

**Operators**:
- `and`: All conditions must be true
- `or`: Any condition must be true
- `not`: Negates the condition

### Comparison Operators

Available comparison operators:

```yaml
# Numeric comparisons
condition: "steps.analysis.score >= 85"
condition: "steps.metrics.coverage < 70"
condition: "steps.count.value == 10"
condition: "steps.size.bytes != 0"

# String comparisons
condition: "steps.detect.language == 'python'"
condition: "steps.check.status != 'failed'"

# String operations
condition: "steps.file.path contains '.test.'"
condition: "steps.name.value starts_with 'test_'"
condition: "steps.url.value ends_with '.com'"
condition: "steps.file.name matches '^[a-z]+_test\\.py$'"

# Array operations
condition: "steps.scan.language in ['python', 'javascript', 'ruby']"
condition: "'critical' in steps.issues.severities"
condition: "steps.results.count > 0"

# Special operators
condition: "steps.score.value between 70 and 90"
condition: "steps.optional_field exists"
condition: "steps.results.items empty"
```

### Complex Conditions

Advanced condition patterns:

```yaml
# Mathematical expressions
condition: "steps.metrics.score * steps.metrics.weight > 100"

# Function calls
condition: "length(steps.files.results) > 10"
condition: "any(steps.tests.results, 'status == \"failed\"')"
condition: "all(steps.checks.results, 'passed == true')"

# Date/time comparisons
condition: "steps.build.timestamp > now() - hours(24)"
condition: "steps.created.date < date('2024-12-31')"

# Combined conditions
condition:
  and:
    - "steps.analysis.complexity < 10"
    - or:
      - "steps.tests.coverage > 90"
      - and:
        - "steps.tests.coverage > 80"
        - "steps.review.approved"
    - not:
      and:
        - "steps.security.has_vulnerabilities"
        - "steps.security.severity == 'critical'"
```

## Loop Constructs

### For Loops

Iterate over collections:

```yaml
- name: "process_files"
  type: "for_loop"
  iterator: "file"                    # Loop variable name
  data_source: "steps.scan.files"     # Array to iterate
  
  # Loop configuration
  break_on_error: false               # Continue on errors
  max_iterations: 100                 # Safety limit
  
  steps:
    - name: "validate_file"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Validate file: {{loop.file.path}}"
      condition: "loop.file.size > 0"
    
    - name: "process_file"
      type: "claude"
      prompt:
        - type: "static"
          content: |
            Process file {{loop.index}} of {{loop.length}}:
            Name: {{loop.file.name}}
            Path: {{loop.file.path}}
            First: {{loop.is_first}}
            Last: {{loop.is_last}}
```

**Loop Variables**:
- `{{loop.iterator}}`: Current item (e.g., `{{loop.file}}`)
- `{{loop.index}}`: Current index (0-based)
- `{{loop.length}}`: Total items
- `{{loop.is_first}}`: Boolean first iteration
- `{{loop.is_last}}`: Boolean last iteration

**Data Sources**:
```yaml
# From previous step
data_source: "steps.gather.items"

# Static array
data_source: ["file1.py", "file2.py", "file3.py"]

# Variable reference
data_source: "{{state.file_list}}"

# Range (future)
data_source: "range(1, 10)"
```

### While Loops

Repeat until condition is met:

```yaml
- name: "optimize_performance"
  type: "while_loop"
  condition: "steps.benchmark.score < 90"
  max_iterations: 10
  timeout_seconds: 3600
  
  steps:
    - name: "analyze_bottlenecks"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Identify performance bottlenecks"
        - type: "previous_response"
          step: "benchmark"
    
    - name: "optimize"
      type: "claude"
      prompt:
        - type: "static"
          content: "Optimize the identified bottlenecks"
        - type: "previous_response"
          step: "analyze_bottlenecks"
    
    - name: "benchmark"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Run performance benchmark and return score"
```

**Safety Features**:
- `max_iterations`: Prevents infinite loops
- `timeout_seconds`: Total time limit
- Automatic break on errors (configurable)

### Nested Loops

Loops within loops:

```yaml
- name: "process_categories"
  type: "for_loop"
  iterator: "category"
  data_source: "steps.organize.categories"
  
  steps:
    - name: "process_category_items"
      type: "for_loop"
      iterator: "item"
      data_source: "loop.category.items"
      
      steps:
        - name: "analyze_item"
          type: "gemini"
          prompt:
            - type: "static"
              content: |
                Category: {{loop.parent.category.name}}
                Item: {{loop.item.name}}
                Category Index: {{loop.parent.index}}
                Item Index: {{loop.index}}
```

**Parent Access**:
- `{{loop.parent.iterator}}`: Parent loop variable
- `{{loop.parent.index}}`: Parent loop index
- `{{loop.parent.parent.iterator}}`: Grandparent access

### Parallel Loops

Execute loop iterations concurrently:

```yaml
- name: "parallel_processing"
  type: "for_loop"
  iterator: "task"
  data_source: "steps.prepare.tasks"
  
  # Parallel configuration
  parallel: true
  max_parallel: 5                     # Concurrent limit
  ordered_results: true               # Maintain order
  
  steps:
    - name: "process_task"
      type: "claude"
      prompt:
        - type: "static"
          content: "Process task: {{loop.task.id}}"
```

**Parallel Features**:
- Independent execution
- Resource pooling
- Result ordering
- Error isolation

## Branching Logic

### Switch/Case

Value-based branching:

```yaml
- name: "handle_by_type"
  type: "switch"
  expression: "steps.detect.file_type"
  
  cases:
    "python":
      - name: "lint_python"
        type: "claude"
        prompt:
          - type: "static"
            content: "Run Python linting with pylint"
      
      - name: "test_python"
        type: "claude"
        prompt:
          - type: "static"
            content: "Run pytest"
    
    "javascript":
      - name: "lint_js"
        type: "claude"
        prompt:
          - type: "static"
            content: "Run ESLint"
      
      - name: "test_js"
        type: "claude"
        prompt:
          - type: "static"
            content: "Run Jest tests"
    
    "go":
      - name: "lint_go"
        type: "claude"
        prompt:
          - type: "static"
            content: "Run go fmt and go vet"
  
  default:
    - name: "generic_lint"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Perform generic code analysis"
```

**Pattern Matching** (future):
```yaml
cases:
  "test_*.py":
    # Handle test files
  "src/**/*.js":
    # Handle source JS files
  "*.{yaml,yml}":
    # Handle YAML files
```

### Multi-Branch Conditions

Complex branching with multiple paths:

```yaml
steps:
  - name: "evaluate_risk"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Evaluate deployment risk level"
  
  # High risk path
  - name: "manual_review"
    type: "claude"
    condition:
      and:
        - "steps.evaluate_risk.risk_level == 'high'"
        - "environment.mode == 'production'"
    prompt:
      - type: "static"
        content: "Create manual review checklist"
  
  # Medium risk path
  - name: "automated_tests"
    type: "claude"
    condition:
      and:
        - "steps.evaluate_risk.risk_level == 'medium'"
        - not: "steps.manual_review"
    prompt:
      - type: "static"
        content: "Run comprehensive test suite"
  
  # Low risk path
  - name: "quick_deploy"
    type: "claude"
    condition:
      and:
        - "steps.evaluate_risk.risk_level == 'low'"
        - not: "steps.manual_review"
        - not: "steps.automated_tests"
    prompt:
      - type: "static"
        content: "Proceed with streamlined deployment"
```

## State Management

### Variables

Set and manage workflow variables:

```yaml
steps:
  - name: "initialize"
    type: "set_variable"
    variables:
      counter: 0
      results: []
      config:
        retry_limit: 3
        timeout: 300
      
  - name: "update_counter"
    type: "set_variable"
    variables:
      counter: "{{state.counter + 1}}"
      
  - name: "append_result"
    type: "set_variable"
    variables:
      results: "{{append(state.results, steps.process.result)}}"
```

**Variable Operations**:
```yaml
# Arithmetic
sum: "{{state.a + state.b}}"
product: "{{state.x * state.y}}"
remainder: "{{state.total % state.batch_size}}"

# String operations
full_name: "{{state.first_name + ' ' + state.last_name}}"
uppercase: "{{upper(state.text)}}"
substring: "{{substring(state.text, 0, 10)}}"

# Array operations
count: "{{length(state.items)}}"
first: "{{state.items[0]}}"
filtered: "{{filter(state.items, 'active == true')}}"
mapped: "{{map(state.items, 'name')}}"

# Object operations
value: "{{state.config.database.host}}"
keys: "{{keys(state.config)}}"
merged: "{{merge(state.defaults, state.overrides)}}"
```

### Variable Scoping

Three levels of variable scope:

```yaml
workflow:
  # Global variables
  variables:
    api_key: "${API_KEY}"
    environment: "production"
  
  steps:
    - name: "process"
      type: "set_variable"
      scope: "global"             # Available to all steps
      variables:
        shared_data: "value"
    
    - name: "local_work"
      type: "set_variable"
      scope: "local"              # Current step only
      variables:
        temp_data: "temporary"
    
    - name: "session_data"
      type: "set_variable"
      scope: "session"            # Persists across runs
      variables:
        run_count: "{{state.run_count + 1}}"
```

**Variable Resolution Order**:
1. Local scope
2. Step variables
3. Global scope
4. Workflow variables
5. Environment variables

### State Persistence

Save and restore workflow state:

```yaml
steps:
  - name: "checkpoint_before_critical"
    type: "checkpoint"
    state:
      current_phase: "data_processing"
      processed_items: "{{state.processed_items}}"
      error_count: "{{state.error_count}}"
    checkpoint_name: "before_critical_operation"
    
  - name: "critical_operation"
    type: "claude"
    prompt:
      - type: "static"
        content: "Perform critical data transformation"
    
  - name: "checkpoint_after_critical"
    type: "checkpoint"
    state:
      current_phase: "data_processed"
      transformation_complete: true
    include_workspace: true
```

**Checkpoint Features**:
- Named checkpoints
- Workspace backup
- Automatic recovery
- State versioning

## Parallel Execution

### Parallel Steps

Execute multiple steps concurrently:

```yaml
- name: "parallel_analysis"
  type: "parallel_claude"
  parallel_tasks:
    - id: "security"
      claude_options:
        max_turns: 15
        allowed_tools: ["Read"]
      prompt:
        - type: "file"
          path: "prompts/security_analysis.md"
      output_to_file: "security_results.json"
      
    - id: "performance"
      claude_options:
        max_turns: 15
        allowed_tools: ["Read", "Bash"]
      prompt:
        - type: "file"
          path: "prompts/performance_analysis.md"
      output_to_file: "performance_results.json"
      
    - id: "quality"
      claude_options:
        max_turns: 10
        allowed_tools: ["Read"]
      prompt:
        - type: "file"
          path: "prompts/code_quality.md"
      output_to_file: "quality_results.json"
```

### Synchronization

Coordinate parallel execution:

```yaml
steps:
  # Launch parallel tasks
  - name: "parallel_work"
    type: "parallel_claude"
    parallel_tasks:
      - id: "task1"
        # ... task configuration
      - id: "task2"
        # ... task configuration
  
  # Wait for all to complete
  - name: "aggregate_results"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Combine results from parallel tasks:"
      - type: "previous_response"
        step: "parallel_work"
```

**Synchronization Patterns**:
- Wait for all (default)
- First to complete (future)
- Timeout with partial results
- Error threshold

## Error Handling & Recovery

### Error Conditions

Handle errors in control flow:

```yaml
steps:
  - name: "risky_operation"
    type: "claude"
    continue_on_error: true
    error_output: "error_details"
    prompt:
      - type: "static"
        content: "Perform operation that might fail"
  
  - name: "handle_error"
    type: "gemini"
    condition: "steps.risky_operation.error != null"
    prompt:
      - type: "static"
        content: "Analyze error and suggest recovery:"
      - type: "previous_response"
        step: "risky_operation"
        extract: "error_details"
```

### Retry Logic

Built-in retry mechanisms:

```yaml
- name: "retry_loop"
  type: "while_loop"
  condition: "state.retry_count < 3 and steps.attempt.success != true"
  
  steps:
    - name: "attempt"
      type: "claude_robust"
      retry_config:
        max_retries: 2
        backoff_strategy: "exponential"
      prompt:
        - type: "static"
          content: "Attempt operation"
    
    - name: "increment_retry"
      type: "set_variable"
      variables:
        retry_count: "{{state.retry_count + 1}}"
```

## Advanced Patterns

### State Machines

Implement state machine logic:

```yaml
workflow:
  variables:
    current_state: "initial"
  
  steps:
    - name: "state_machine"
      type: "while_loop"
      condition: "state.current_state != 'complete'"
      max_iterations: 20
      
      steps:
        - name: "handle_state"
          type: "switch"
          expression: "state.current_state"
          
          cases:
            "initial":
              - name: "initialize"
                type: "gemini"
                prompt:
                  - type: "static"
                    content: "Initialize process"
              - name: "set_next_state"
                type: "set_variable"
                variables:
                  current_state: "processing"
            
            "processing":
              - name: "process"
                type: "claude"
                prompt:
                  - type: "static"
                    content: "Process data"
              - name: "check_completion"
                type: "set_variable"
                variables:
                  current_state: "{{steps.process.done ? 'review' : 'processing'}}"
            
            "review":
              - name: "review"
                type: "gemini"
                prompt:
                  - type: "static"
                    content: "Review results"
              - name: "finalize"
                type: "set_variable"
                variables:
                  current_state: "complete"
```

### Dynamic Workflow Generation

Generate workflow steps dynamically:

```yaml
steps:
  - name: "plan_workflow"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Create a list of tasks to perform"
    output_schema:
      type: "object"
      properties:
        tasks:
          type: "array"
          items:
            type: "object"
            properties:
              name: {type: "string"}
              type: {type: "string"}
              prompt: {type: "string"}
  
  - name: "execute_planned_tasks"
    type: "for_loop"
    iterator: "task"
    data_source: "steps.plan_workflow.tasks"
    
    steps:
      - name: "dynamic_execution"
        type: "{{loop.task.type}}"
        prompt:
          - type: "static"
            content: "{{loop.task.prompt}}"
```

### Recursive Control Flow

Control flow with recursive patterns:

```yaml
- name: "recursive_search"
  type: "pipeline"
  pipeline:
    name: "search_tree"
    steps:
      - name: "examine_node"
        type: "gemini"
        prompt:
          - type: "static"
            content: "Examine node: {{inputs.node}}"
      
      - name: "process_children"
        type: "for_loop"
        iterator: "child"
        data_source: "steps.examine_node.children"
        condition: "steps.examine_node.has_children"
        
        steps:
          - name: "recurse"
            type: "pipeline"
            pipeline_ref: "search_tree"
            inputs:
              node: "{{loop.child}}"
            config:
              max_depth: 5
```

This reference provides comprehensive documentation for control flow and logic capabilities in Pipeline YAML v2 format.