# Advanced Features Reference

## Table of Contents

1. [Overview](#overview)
2. [Data Transformation](#data-transformation)
3. [Codebase Intelligence](#codebase-intelligence)
4. [File Operations](#file-operations)
5. [Schema Validation](#schema-validation)
6. [Function Calling](#function-calling)
7. [Session Management](#session-management)
8. [Content Processing](#content-processing)
9. [Performance Features](#performance-features)
10. [Integration Patterns](#integration-patterns)

## Overview

Pipeline's advanced features enable sophisticated AI engineering workflows through:

- **Data transformation** with JSONPath and complex operations
- **Codebase intelligence** for language-aware analysis
- **File operations** with format conversion
- **Schema validation** for structured outputs
- **Function calling** for tool integration
- **Session management** for stateful workflows
- **Content processing** for extraction and summarization
- **Performance optimization** for large-scale processing

## Data Transformation

### Transform Step Type

The `data_transform` step provides powerful data manipulation:

```yaml
- name: "process_analysis_results"
  type: "data_transform"
  
  input_source: "steps.analysis.results"
  
  operations:
    # Filter items by condition
    - operation: "filter"
      field: "vulnerabilities"
      condition: "severity == 'critical' or severity == 'high'"
    
    # Transform each item
    - operation: "map"
      field: "vulnerabilities"
      expression: |
        {
          "id": item.cve_id,
          "risk_score": item.cvss_score * 10,
          "priority": item.cvss_score > 7 ? "urgent" : "normal",
          "description": substring(item.description, 0, 200)
        }
    
    # Group by category
    - operation: "group_by"
      field: "vulnerabilities"
      key: "category"
    
    # Aggregate statistics
    - operation: "aggregate"
      field: "vulnerabilities"
      function: "count"
      group_by: "severity"
      as: "severity_counts"
    
    # Sort results
    - operation: "sort"
      field: "vulnerabilities"
      by: "risk_score"
      order: "desc"
  
  output_field: "processed_vulnerabilities"
  output_to_file: "vulnerability_report.json"
```

### Available Operations

#### Filter
Select items matching conditions:
```yaml
- operation: "filter"
  field: "items"
  condition: "price > 100 and category == 'electronics'"
```

#### Map
Transform each item:
```yaml
- operation: "map"
  field: "users"
  expression: |
    {
      "full_name": item.first_name + " " + item.last_name,
      "age_group": item.age < 18 ? "minor" : "adult",
      "account_type": item.premium ? "premium" : "basic"
    }
```

#### Aggregate
Calculate statistics:
```yaml
- operation: "aggregate"
  field: "transactions"
  function: "sum"           # sum, average, min, max, count
  value_field: "amount"     # Field to aggregate
  group_by: "category"      # Optional grouping
```

#### Join
Combine datasets:
```yaml
- operation: "join"
  left_field: "orders"
  right_source: "steps.fetch.customers"
  join_key: "customer_id"
  join_type: "left"         # left, right, inner, outer
  as: "enriched_orders"
```

#### Group By
Group items by key:
```yaml
- operation: "group_by"
  field: "events"
  key: "event_type"
  aggregate:
    count: "count"
    total_duration: "sum(duration)"
    avg_duration: "average(duration)"
```

#### Sort
Order items:
```yaml
- operation: "sort"
  field: "products"
  by: "price"               # or complex: "category,price"
  order: "asc"              # asc or desc
```

### JSONPath Expressions

Access nested data with JSONPath:

```yaml
operations:
  # Access nested fields
  - operation: "extract"
    expression: "$.data.users[*].profile.email"
    as: "email_list"
  
  # Filter with JSONPath
  - operation: "extract"
    expression: "$.items[?(@.price > 100)].name"
    as: "expensive_items"
  
  # Complex queries
  - operation: "extract"
    expression: "$.orders[?(@.status == 'pending')].items[*].total"
    as: "pending_totals"
```

### Complex Transformations

Chain multiple operations:

```yaml
- name: "analyze_test_results"
  type: "data_transform"
  input_source: "steps.test_run.results"
  
  operations:
    # Extract test cases
    - operation: "extract"
      expression: "$.suites[*].tests[*]"
      as: "all_tests"
    
    # Filter failed tests
    - operation: "filter"
      field: "all_tests"
      condition: "status == 'failed'"
      as: "failed_tests"
    
    # Group by suite
    - operation: "group_by"
      field: "failed_tests"
      key: "suite_name"
      as: "failures_by_suite"
    
    # Calculate statistics
    - operation: "map"
      field: "failures_by_suite"
      expression: |
        {
          "suite": key,
          "failure_count": length(value),
          "failure_rate": length(value) / suite_total_tests * 100,
          "critical_failures": filter(value, "priority == 'critical'")
        }
    
    # Sort by failure rate
    - operation: "sort"
      field: "failures_by_suite"
      by: "failure_rate"
      order: "desc"
  
  output_field: "test_analysis"
```

## Codebase Intelligence

### Codebase Query Step

Intelligent code analysis and discovery:

```yaml
- name: "analyze_codebase"
  type: "codebase_query"
  
  codebase_context: true    # Include project metadata
  
  queries:
    # Project information
    project_info:
      get_project_type: true
      get_dependencies: true
      get_git_status: true
      get_recent_commits: 10
    
    # Find specific files
    source_files:
      find_files:
        - type: "source"
        - pattern: "**/*.py"
        - exclude_patterns: ["**/test_*", "**/__pycache__/**"]
        - modified_since: "2024-01-01"
        - min_size: 100
    
    # Find related test files
    test_coverage:
      find_files:
        - related_to: "src/auth.py"
        - type: "test"
        - pattern: "**/test_*.py"
    
    # Extract code structure
    api_endpoints:
      find_functions:
        - in_files: "src/api/**/*.py"
        - with_decorator: "@app.route"
        - extract_metadata: true
    
    # Analyze imports
    dependencies:
      find_imports:
        - in_files: "src/**/*.py"
        - external_only: true
        - group_by_package: true
    
    # Find usage
    auth_usage:
      find_references:
        - to_function: "authenticate_user"
        - in_files: "src/**/*.py"
        - include_line_numbers: true
  
  output_to_file: "codebase_analysis.json"
```

### Language-Specific Analysis

Support for multiple languages:

```yaml
queries:
  # Python-specific
  python_classes:
    find_classes:
      - in_files: "**/*.py"
      - with_base_class: "BaseModel"
      - include_methods: true
  
  # JavaScript/TypeScript
  react_components:
    find_exports:
      - in_files: "**/*.{jsx,tsx}"
      - type: "react_component"
      - with_props: true
  
  # Go
  go_interfaces:
    find_interfaces:
      - in_files: "**/*.go"
      - exported_only: true
  
  # Elixir
  elixir_modules:
    find_modules:
      - in_files: "lib/**/*.ex"
      - with_behaviour: "GenServer"
```

### Dependency Analysis

Track code dependencies:

```yaml
queries:
  # Direct dependencies
  module_deps:
    find_dependencies:
      - for_file: "lib/user.ex"
      - include_stdlib: false
      - max_depth: 1
  
  # Reverse dependencies
  module_usage:
    find_dependents:
      - of_file: "lib/auth.ex"
      - include_tests: true
      - group_by_directory: true
  
  # Circular dependencies
  circular_deps:
    find_circular_dependencies:
      - in_directory: "lib/"
      - max_cycle_length: 5
```

### Git Integration

Analyze version control data:

```yaml
queries:
  git_info:
    # Recent changes
    get_changed_files:
      - since_commit: "HEAD~10"
      - include_stats: true
    
    # Author statistics
    get_contributors:
      - for_files: "src/core/**"
      - include_commit_count: true
    
    # Hot spots
    get_change_frequency:
      - time_period: "3 months"
      - minimum_changes: 5
```

## File Operations

### File Operations Step

Comprehensive file manipulation:

```yaml
- name: "organize_outputs"
  type: "file_ops"
  
  operation: "copy"
  source:
    - pattern: "workspace/**/*.py"
    - exclude: ["**/test_*.py", "**/__pycache__/**"]
  destination: "output/python_files/"
  options:
    preserve_structure: true
    overwrite: true
```

### Supported Operations

#### Copy Files
```yaml
- name: "backup_sources"
  type: "file_ops"
  operation: "copy"
  source: ["src/", "tests/"]
  destination: "backup/{{timestamp}}/"
  options:
    recursive: true
    preserve_timestamps: true
```

#### Move Files
```yaml
- name: "reorganize"
  type: "file_ops"
  operation: "move"
  source:
    pattern: "temp/*.processed"
  destination: "completed/"
  options:
    create_destination: true
```

#### Delete Files
```yaml
- name: "cleanup"
  type: "file_ops"
  operation: "delete"
  files:
    - pattern: "**/*.tmp"
    - pattern: "**/*.cache"
    - older_than: "7 days"
  options:
    dry_run: false
```

#### Validate Files
```yaml
- name: "verify_outputs"
  type: "file_ops"
  operation: "validate"
  files:
    - path: "output/report.pdf"
      must_exist: true
      min_size: 1024
      max_size: 10485760  # 10MB
    
    - path: "output/data/"
      must_be_dir: true
      must_contain: ["summary.json", "details.csv"]
    
    - pattern: "output/**/*.json"
      validate_json: true
```

#### List Files
```yaml
- name: "scan_directory"
  type: "file_ops"
  operation: "list"
  path: "./workspace"
  options:
    recursive: true
    include_hidden: false
    pattern: "**/*.{py,js,ts}"
    sort_by: "modified"
    limit: 100
  output_field: "file_list"
```

#### Format Conversion
```yaml
- name: "convert_data"
  type: "file_ops"
  operation: "convert"
  source: "data.csv"
  destination: "data.json"
  format: "csv_to_json"
  options:
    csv_delimiter: ","
    csv_headers: true
    json_indent: 2
```

### Batch Operations

Process multiple files:

```yaml
- name: "batch_convert"
  type: "for_loop"
  iterator: "file"
  data_source: "steps.scan.csv_files"
  
  steps:
    - name: "convert_file"
      type: "file_ops"
      operation: "convert"
      source: "{{loop.file.path}}"
      destination: "{{replace(loop.file.path, '.csv', '.json')}}"
      format: "csv_to_json"
```

## Schema Validation

### Output Schema Validation

Enforce structured outputs:

```yaml
- name: "structured_analysis"
  type: "gemini"
  
  output_schema:
    type: "object"
    required: ["summary", "findings", "recommendations"]
    properties:
      summary:
        type: "string"
        minLength: 50
        maxLength: 500
      
      findings:
        type: "array"
        minItems: 1
        items:
          type: "object"
          required: ["type", "severity", "description"]
          properties:
            type:
              type: "string"
              enum: ["bug", "vulnerability", "improvement"]
            severity:
              type: "string"
              enum: ["low", "medium", "high", "critical"]
            description:
              type: "string"
            line_number:
              type: "integer"
              minimum: 1
      
      recommendations:
        type: "array"
        items:
          type: "object"
          properties:
            priority:
              type: "integer"
              minimum: 1
              maximum: 5
            action:
              type: "string"
            effort:
              type: "string"
              enum: ["trivial", "small", "medium", "large"]
      
      metadata:
        type: "object"
        properties:
          timestamp:
            type: "string"
            format: "date-time"
          version:
            type: "string"
            pattern: "^\\d+\\.\\d+\\.\\d+$"
  
  prompt:
    - type: "static"
      content: "Analyze code and return structured findings"
```

### Schema Features

**Data Types**:
- `string`, `number`, `integer`, `boolean`
- `object`, `array`
- `null` (for optional fields)

**String Constraints**:
```yaml
properties:
  email:
    type: "string"
    format: "email"
    pattern: "^[\\w.-]+@[\\w.-]+\\.\\w+$"
  
  code:
    type: "string"
    minLength: 6
    maxLength: 6
    pattern: "^[0-9]{6}$"
```

**Numeric Constraints**:
```yaml
properties:
  score:
    type: "number"
    minimum: 0
    maximum: 100
    multipleOf: 0.5
  
  count:
    type: "integer"
    minimum: 0
    exclusiveMaximum: 1000
```

**Array Constraints**:
```yaml
properties:
  tags:
    type: "array"
    minItems: 1
    maxItems: 10
    uniqueItems: true
    items:
      type: "string"
      enum: ["bug", "feature", "docs", "test"]
```

**Complex Schemas**:
```yaml
output_schema:
  type: "object"
  properties:
    result:
      oneOf:
        - type: "object"
          properties:
            success:
              const: true
            data:
              type: "object"
        - type: "object"
          properties:
            success:
              const: false
            error:
              type: "string"
  
  # Conditional schemas
  if:
    properties:
      type:
        const: "user"
  then:
    required: ["email", "username"]
  else:
    required: ["id"]
```

## Function Calling

### Gemini Functions

Define and use functions with Gemini:

```yaml
workflow:
  gemini_functions:
    analyze_code_quality:
      description: "Analyze code quality metrics"
      parameters:
        type: "object"
        required: ["file_path", "metrics"]
        properties:
          file_path:
            type: "string"
            description: "Path to the file to analyze"
          metrics:
            type: "array"
            items:
              type: "string"
              enum: ["complexity", "maintainability", "coverage"]
          include_suggestions:
            type: "boolean"
            default: true
    
    generate_test_cases:
      description: "Generate test cases for a function"
      parameters:
        type: "object"
        required: ["function_name", "function_code"]
        properties:
          function_name:
            type: "string"
          function_code:
            type: "string"
          test_types:
            type: "array"
            items:
              type: "string"
              enum: ["unit", "integration", "edge_case"]
          coverage_target:
            type: "number"
            minimum: 0
            maximum: 100
  
  steps:
    - name: "code_analysis"
      type: "gemini"
      functions:
        - "analyze_code_quality"
        - "generate_test_cases"
      prompt:
        - type: "static"
          content: |
            Analyze this code file and:
            1. Call analyze_code_quality for quality metrics
            2. Call generate_test_cases for untested functions
        - type: "file"
          path: "src/main.py"
```

### Function Results

Process function call results:

```yaml
- name: "process_analysis"
  type: "gemini"
  prompt:
    - type: "static"
      content: "Summarize the analysis results:"
    - type: "previous_response"
      step: "code_analysis"
      extract: "function_calls"
```

## Session Management

### Claude Sessions

Maintain conversation state:

```yaml
- name: "development_session"
  type: "claude_session"
  
  session_config:
    session_name: "feature_development"
    persist: true
    continue_on_restart: true
    checkpoint_frequency: 10
    max_turns: 100
    description: "Developing authentication feature"
  
  claude_options:
    max_turns: 20
    allowed_tools: ["Write", "Edit", "Read", "Bash"]
  
  prompt:
    - type: "static"
      content: "Let's continue developing the auth feature"
    - type: "session_context"
      session_id: "feature_development"
      include_last_n: 5
```

### Session Continuation

Continue sessions across steps:

```yaml
steps:
  - name: "start_session"
    type: "claude_session"
    session_config:
      session_name: "refactoring_session"
      persist: true
    prompt:
      - type: "static"
        content: "Begin refactoring the user module"
  
  - name: "continue_work"
    type: "claude_session"
    session_config:
      session_name: "refactoring_session"
      continue_session: true
    prompt:
      - type: "claude_continue"
        new_prompt: "Now add error handling to all functions"
  
  - name: "final_review"
    type: "claude_session"
    session_config:
      session_name: "refactoring_session"
      continue_session: true
    prompt:
      - type: "claude_continue"
        new_prompt: "Review all changes and create a summary"
```

## Content Processing

### Content Extraction

Advanced extraction with ContentExtractor:

```yaml
- name: "extract_insights"
  type: "claude_extract"
  preset: "analysis"
  
  extraction_config:
    use_content_extractor: true
    format: "structured"
    
    post_processing:
      - "extract_code_blocks"
      - "extract_recommendations"
      - "extract_errors"
      - "extract_metrics"
      - "extract_dependencies"
    
    code_block_processing:
      identify_language: true
      syntax_highlight: true
      extract_imports: true
    
    recommendation_format:
      include_priority: true
      include_effort: true
      group_by_category: true
    
    max_summary_length: 1000
    include_metadata: true
  
  prompt:
    - type: "file"
      path: "analysis_report.md"
```

### Extraction Formats

**Structured Format**:
```yaml
extraction_config:
  format: "structured"
  sections:
    - name: "overview"
      max_length: 500
    - name: "findings"
      item_limit: 20
    - name: "recommendations"
      priority_only: true
```

**Summary Format**:
```yaml
extraction_config:
  format: "summary"
  summary_style: "bullet_points"
  max_points: 10
  include_key_metrics: true
```

**Markdown Format**:
```yaml
extraction_config:
  format: "markdown"
  heading_level: 2
  include_toc: true
  code_fence_style: "```"
```

## Performance Features

### Streaming Operations

Process large datasets efficiently:

```yaml
- name: "stream_process"
  type: "data_transform"
  
  input_source: "large_dataset.jsonl"
  stream_mode: true
  chunk_size: 1000
  
  operations:
    - operation: "filter"
      condition: "record.active == true"
    
    - operation: "map"
      expression: |
        {
          "id": record.id,
          "processed_at": now(),
          "summary": substring(record.description, 0, 100)
        }
  
  output_file: "processed_data.jsonl"
  output_format: "jsonl"
```

### Parallel Processing

Execute operations concurrently:

```yaml
- name: "parallel_analysis"
  type: "parallel_claude"
  
  parallel_config:
    max_workers: 5
    queue_size: 20
    timeout_per_task: 300
    retry_failed: true
  
  task_generator:
    type: "file_list"
    pattern: "**/*.py"
    batch_size: 10
  
  task_template:
    claude_options:
      max_turns: 5
      allowed_tools: ["Read"]
    prompt:
      - type: "static"
        content: "Analyze this batch of files:"
      - type: "dynamic"
        content: "{{task.files}}"
```

### Caching

Optimize repeated operations:

```yaml
workflow:
  cache_config:
    enabled: true
    ttl: 3600
    max_size_mb: 100
    cache_keys:
      - "file_content"
      - "analysis_results"
      - "transformations"
  
  steps:
    - name: "cached_analysis"
      type: "gemini"
      cache:
        key: "analysis_{{hash(file_path)}}"
        ttl: 7200
      prompt:
        - type: "file"
          path: "{{file_path}}"
```

## Integration Patterns

### Multi-Stage Processing

Complex workflows with multiple stages:

```yaml
workflow:
  name: "complete_analysis_pipeline"
  
  steps:
    # Stage 1: Discovery
    - name: "discover"
      type: "codebase_query"
      codebase_context: true
      queries:
        project_structure:
          get_project_type: true
          find_entry_points: true
    
    # Stage 2: Analysis
    - name: "analyze_each_component"
      type: "for_loop"
      iterator: "component"
      data_source: "steps.discover.project_structure.components"
      parallel: true
      
      steps:
        - name: "component_analysis"
          type: "pipeline"
          pipeline_file: "./analyze_component.yaml"
          inputs:
            component: "{{loop.component}}"
    
    # Stage 3: Transform Results
    - name: "consolidate"
      type: "data_transform"
      input_source: "steps.analyze_each_component.results"
      operations:
        - operation: "flatten"
          field: "analyses"
        - operation: "group_by"
          key: "severity"
        - operation: "sort"
          by: "priority"
          order: "desc"
    
    # Stage 4: Generate Report
    - name: "report"
      type: "claude_extract"
      extraction_config:
        format: "markdown"
        include_metadata: true
      prompt:
        - type: "static"
          content: "Generate comprehensive report:"
        - type: "previous_response"
          step: "consolidate"
```

### Event-Driven Patterns

React to conditions and events:

```yaml
workflow:
  name: "monitoring_pipeline"
  
  steps:
    - name: "monitor_loop"
      type: "while_loop"
      condition: "state.monitoring_active"
      max_iterations: 1000
      
      steps:
        - name: "check_conditions"
          type: "codebase_query"
          queries:
            changes:
              get_changed_files:
                since: "{{state.last_check}}"
        
        - name: "process_if_changed"
          type: "pipeline"
          condition: "length(steps.check_conditions.changes) > 0"
          pipeline_file: "./process_changes.yaml"
          inputs:
            changes: "{{steps.check_conditions.changes}}"
        
        - name: "update_state"
          type: "set_variable"
          variables:
            last_check: "{{now()}}"
        
        - name: "wait"
          type: "file_ops"
          operation: "wait"
          duration_seconds: 60
```

### Adaptive Workflows

Workflows that adapt based on runtime conditions:

```yaml
workflow:
  name: "adaptive_processor"
  
  steps:
    - name: "analyze_workload"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Analyze workload characteristics"
        - type: "file"
          path: "workload_metrics.json"
    
    - name: "select_strategy"
      type: "switch"
      expression: "steps.analyze_workload.recommended_strategy"
      
      cases:
        "batch":
          - name: "batch_process"
            type: "pipeline"
            pipeline_file: "./strategies/batch_processor.yaml"
        
        "stream":
          - name: "stream_process"
            type: "pipeline"
            pipeline_file: "./strategies/stream_processor.yaml"
        
        "parallel":
          - name: "parallel_process"
            type: "pipeline"
            pipeline_file: "./strategies/parallel_processor.yaml"
      
      default:
        - name: "standard_process"
          type: "pipeline"
          pipeline_file: "./strategies/standard_processor.yaml"
```

This reference provides comprehensive documentation for advanced features in Pipeline YAML v2 format, enabling sophisticated AI engineering workflows.