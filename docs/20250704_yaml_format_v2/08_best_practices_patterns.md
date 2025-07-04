# Best Practices & Patterns

## Table of Contents

1. [Overview](#overview)
2. [Pipeline Design Principles](#pipeline-design-principles)
3. [Common Patterns](#common-patterns)
4. [Error Handling Strategies](#error-handling-strategies)
5. [Performance Optimization](#performance-optimization)
6. [Security Best Practices](#security-best-practices)
7. [Testing Strategies](#testing-strategies)
8. [Documentation Standards](#documentation-standards)
9. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
10. [Real-World Examples](#real-world-examples)

## Overview

This guide presents proven patterns and best practices for building robust, maintainable, and efficient pipelines using the Pipeline YAML v2 format.

## Pipeline Design Principles

### 1. Single Responsibility Principle

Each pipeline should have one clear purpose:

```yaml
# GOOD: Focused pipeline
workflow:
  name: "validate_user_input"
  description: "Validates and sanitizes user input data"
  
  steps:
    - name: "schema_validation"
      type: "gemini"
      # ... focused on validation

# BAD: Mixed responsibilities
workflow:
  name: "process_everything"
  description: "Validates, transforms, analyzes, and deploys"
  # Too many responsibilities in one pipeline
```

### 2. Composition Over Complexity

Build complex workflows from simple, reusable components:

```yaml
# GOOD: Composed pipeline
workflow:
  name: "complete_analysis"
  
  steps:
    - name: "data_validation"
      type: "pipeline"
      pipeline_file: "./components/validator.yaml"
    
    - name: "security_scan"
      type: "pipeline"
      pipeline_file: "./components/security_scanner.yaml"
    
    - name: "performance_check"
      type: "pipeline"
      pipeline_file: "./components/performance_analyzer.yaml"
```

### 3. Explicit Over Implicit

Be clear about inputs, outputs, and dependencies:

```yaml
# GOOD: Explicit configuration
- name: "process_data"
  type: "pipeline"
  pipeline_file: "./processor.yaml"
  
  inputs:
    data_source: "{{steps.extract.data}}"
    format: "json"
    validation_rules: "{{config.rules}}"
  
  outputs:
    - path: "processed_data"
      as: "clean_data"
    - path: "validation_report"
      as: "report"
```

### 4. Fail Fast, Recover Gracefully

Detect problems early and handle them appropriately:

```yaml
# GOOD: Early validation with recovery
steps:
  - name: "validate_inputs"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Validate all inputs before processing"
    output_schema:
      type: "object"
      required: ["valid", "errors"]
  
  - name: "handle_validation"
    type: "switch"
    expression: "steps.validate_inputs.valid"
    
    cases:
      true:
        - name: "process"
          type: "pipeline"
          pipeline_file: "./process.yaml"
      
      false:
        - name: "error_recovery"
          type: "pipeline"
          pipeline_file: "./error_handler.yaml"
```

## Common Patterns

### Progressive Enhancement Pattern

Build complexity gradually:

```yaml
workflow:
  name: "progressive_code_improvement"
  
  steps:
    # Stage 1: Basic analysis
    - name: "quick_scan"
      type: "gemini"
      token_budget:
        max_output_tokens: 1024
      prompt:
        - type: "file"
          path: "prompts/quick_analysis.md"
        - type: "file"
          path: "{{inputs.code_file}}"
    
    # Stage 2: Detailed analysis if issues found
    - name: "deep_analysis"
      type: "claude"
      condition: "steps.quick_scan.issues_found > 0"
      claude_options:
        max_turns: 15
      prompt:
        - type: "file"
          path: "prompts/deep_analysis.md"
        - type: "previous_response"
          step: "quick_scan"
          extract: "issues"
    
    # Stage 3: Fix critical issues
    - name: "fix_critical"
      type: "claude_robust"
      condition: "steps.deep_analysis.critical_count > 0"
      retry_config:
        max_retries: 3
      prompt:
        - type: "file"
          path: "prompts/fix_critical.md"
        - type: "previous_response"
          step: "deep_analysis"
          extract: "critical_issues"
```

### Pipeline Factory Pattern

Dynamically select pipelines based on context:

```yaml
workflow:
  name: "adaptive_processor"
  
  steps:
    - name: "detect_context"
      type: "codebase_query"
      queries:
        project_info:
          get_project_type: true
          get_language: true
          get_framework: true
    
    - name: "select_pipeline"
      type: "gemini"
      prompt:
        - type: "static"
          content: |
            Based on project type: {{steps.detect_context.project_info.type}}
            Language: {{steps.detect_context.project_info.language}}
            Framework: {{steps.detect_context.project_info.framework}}
            
            Select the appropriate pipeline:
            - python_django_pipeline
            - javascript_react_pipeline
            - go_gin_pipeline
            - generic_pipeline
      output_schema:
        type: "object"
        required: ["pipeline_name"]
    
    - name: "execute_selected"
      type: "pipeline"
      pipeline_file: "./pipelines/{{steps.select_pipeline.pipeline_name}}.yaml"
      inputs:
        project_context: "{{steps.detect_context.project_info}}"
```

### Batch Processing Pattern

Efficiently process multiple items:

```yaml
workflow:
  name: "batch_file_processor"
  
  steps:
    - name: "gather_files"
      type: "file_ops"
      operation: "list"
      path: "./data"
      pattern: "**/*.json"
      output_field: "file_list"
    
    - name: "batch_process"
      type: "claude_batch"
      batch_config:
        max_parallel: 5
        timeout_per_task: 300
        consolidate_results: true
      
      # Dynamic task generation
      tasks: |
        {{map(steps.gather_files.file_list, (file) => {
          "id": file.name,
          "prompt": [
            {"type": "static", "content": "Process this JSON file:"},
            {"type": "file", "path": file.path}
          ],
          "output_to_file": "processed/" + file.name
        })}}
```

### Checkpoint and Resume Pattern

Enable long-running workflows with recovery:

```yaml
workflow:
  name: "resumable_migration"
  checkpoint_enabled: true
  
  steps:
    - name: "load_progress"
      type: "checkpoint"
      action: "load"
      checkpoint_name: "migration_progress"
      on_not_found:
        - name: "initialize"
          type: "set_variable"
          variables:
            processed_count: 0
            failed_items: []
            current_batch: 0
    
    - name: "process_batches"
      type: "while_loop"
      condition: "state.current_batch < state.total_batches"
      
      steps:
        - name: "process_batch"
          type: "pipeline"
          pipeline_file: "./batch_processor.yaml"
          inputs:
            batch_number: "{{state.current_batch}}"
            start_from: "{{state.processed_count}}"
        
        - name: "save_progress"
          type: "checkpoint"
          state:
            processed_count: "{{state.processed_count + steps.process_batch.count}}"
            failed_items: "{{concat(state.failed_items, steps.process_batch.failures)}}"
            current_batch: "{{state.current_batch + 1}}"
          checkpoint_name: "migration_progress"
```

### Self-Healing Pattern

Automatically detect and fix issues:

```yaml
workflow:
  name: "self_healing_system"
  
  steps:
    - name: "health_check_loop"
      type: "while_loop"
      condition: "state.monitoring_active"
      max_iterations: 1000
      
      steps:
        - name: "check_health"
          type: "pipeline"
          pipeline_file: "./health_checker.yaml"
          outputs:
            - "health_status"
            - "issues"
        
        - name: "auto_fix"
          type: "switch"
          expression: "steps.check_health.health_status"
          
          cases:
            "unhealthy":
              - name: "diagnose"
                type: "gemini"
                prompt:
                  - type: "static"
                    content: "Diagnose issues and suggest fixes:"
                  - type: "previous_response"
                    step: "check_health"
                    extract: "issues"
              
              - name: "apply_fixes"
                type: "claude_robust"
                retry_config:
                  max_retries: 2
                prompt:
                  - type: "static"
                    content: "Apply the suggested fixes:"
                  - type: "previous_response"
                    step: "diagnose"
                    extract: "fix_recommendations"
            
            "degraded":
              - name: "optimize"
                type: "pipeline"
                pipeline_file: "./optimizer.yaml"
        
        - name: "wait"
          type: "file_ops"
          operation: "wait"
          duration_seconds: 60
```

## Error Handling Strategies

### Graceful Degradation

Provide fallback options:

```yaml
steps:
  - name: "primary_analysis"
    type: "claude"
    continue_on_error: true
    error_output: "primary_error"
    claude_options:
      max_turns: 20
    prompt:
      - type: "file"
        path: "prompts/comprehensive_analysis.md"
  
  - name: "fallback_analysis"
    type: "gemini"
    condition: "steps.primary_analysis.error != null"
    prompt:
      - type: "file"
        path: "prompts/basic_analysis.md"
      - type: "static"
        content: |
          Note: Using simplified analysis due to error:
          {{steps.primary_analysis.error_message}}
```

### Error Context Collection

Gather context for debugging:

```yaml
- name: "error_handler"
  type: "set_variable"
  condition: "steps.{{previous_step}}.error != null"
  variables:
    error_context:
      timestamp: "{{now()}}"
      step_name: "{{previous_step}}"
      error_type: "{{steps.{{previous_step}}.error.type}}"
      error_message: "{{steps.{{previous_step}}.error.message}}"
      input_data: "{{steps.{{previous_step}}.inputs}}"
      system_state:
        memory_usage: "{{system.memory_usage_mb}}"
        execution_time: "{{system.execution_time_seconds}}"
        step_count: "{{system.completed_steps}}"
```

### Circuit Breaker Pattern

Prevent cascade failures:

```yaml
workflow:
  name: "circuit_breaker_example"
  
  variables:
    failure_count: 0
    circuit_open: false
    threshold: 3
  
  steps:
    - name: "check_circuit"
      type: "set_variable"
      condition: "state.failure_count >= state.threshold"
      variables:
        circuit_open: true
    
    - name: "skip_if_open"
      type: "gemini"
      condition: "not state.circuit_open"
      prompt:
        - type: "static"
          content: "Perform operation"
      on_error:
        - name: "increment_failures"
          type: "set_variable"
          variables:
            failure_count: "{{state.failure_count + 1}}"
```

## Performance Optimization

### Lazy Loading Strategy

Load resources only when needed:

```yaml
steps:
  - name: "check_need"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Check if detailed analysis is needed"
    output_schema:
      type: "object"
      properties:
        needs_analysis: {type: "boolean"}
  
  - name: "conditional_load"
    type: "pipeline"
    condition: "steps.check_need.needs_analysis"
    pipeline_file: "./heavy_analysis.yaml"
    config:
      lazy_load: true
      cache_pipeline: true
```

### Parallel Processing

Maximize throughput with parallelization:

```yaml
- name: "parallel_file_processing"
  type: "for_loop"
  iterator: "file_batch"
  data_source: "{{chunk(steps.scan.files, 10)}}"  # Batch files
  parallel: true
  max_parallel: 5
  
  steps:
    - name: "process_batch"
      type: "parallel_claude"
      parallel_tasks: |
        {{map(loop.file_batch, (file) => {
          "id": file.name,
          "claude_options": {
            "max_turns": 5,
            "allowed_tools": ["Read", "Write"]
          },
          "prompt": [
            {"type": "static", "content": "Process file:"},
            {"type": "file", "path": file.path}
          ]
        })}}
```

### Caching Strategy

Implement intelligent caching:

```yaml
workflow:
  cache_config:
    enabled: true
    strategy: "content_hash"
    ttl: 3600
  
  steps:
    - name: "expensive_analysis"
      type: "gemini"
      cache:
        key: "analysis_{{hash(inputs.file_path)}}_{{inputs.version}}"
        ttl: 7200
        conditions:
          - "inputs.force_refresh != true"
      prompt:
        - type: "file"
          path: "{{inputs.file_path}}"
```

## Security Best Practices

### Input Sanitization

Always validate and sanitize inputs:

```yaml
steps:
  - name: "sanitize_inputs"
    type: "data_transform"
    input_source: "{{inputs.user_data}}"
    operations:
      - operation: "validate"
        schema:
          type: "object"
          required: ["name", "email"]
          properties:
            name:
              type: "string"
              pattern: "^[a-zA-Z ]+$"
              maxLength: 100
            email:
              type: "string"
              format: "email"
      
      - operation: "sanitize"
        rules:
          - remove_html_tags: true
          - escape_special_chars: true
          - trim_whitespace: true
    
    output_field: "clean_inputs"
```

### Workspace Isolation

Enforce strict workspace boundaries:

```yaml
workflow:
  safety:
    sandbox_mode: true
    allowed_paths: ["./workspace"]
    read_only_paths: ["./templates", "./prompts"]
  
  steps:
    - name: "isolated_execution"
      type: "claude"
      claude_options:
        cwd: "./workspace/{{execution_id}}"
        allowed_tools: ["Write", "Read"]
        disallowed_tools: ["Bash"]
```

### Secret Management

Never expose secrets in configurations:

```yaml
workflow:
  variables:
    # Use environment variables
    api_key: "${API_KEY}"
    db_password: "${DB_PASSWORD}"
    
    # Use secret manager (future)
    auth_token: "{{secrets.get('auth_token')}}"
  
  steps:
    - name: "secure_operation"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Process data with API"
        # Never include secrets directly in prompts
```

## Testing Strategies

### Unit Testing Pipelines

Test individual pipeline components:

```yaml
# test_validator.yaml
workflow:
  name: "test_validator_component"
  
  steps:
    - name: "test_valid_input"
      type: "pipeline"
      pipeline_file: "./components/validator.yaml"
      inputs:
        data: {"name": "John", "age": 30}
        schema: {"type": "object", "required": ["name", "age"]}
      expected_outputs:
        valid: true
        errors: []
    
    - name: "test_invalid_input"
      type: "pipeline"
      pipeline_file: "./components/validator.yaml"
      inputs:
        data: {"name": "John"}
        schema: {"type": "object", "required": ["name", "age"]}
      expected_outputs:
        valid: false
        errors: ["Missing required field: age"]
```

### Integration Testing

Test complete workflows:

```yaml
workflow:
  name: "integration_test"
  environment:
    mode: "test"
    force_mock_providers: true
  
  steps:
    - name: "setup_test_data"
      type: "file_ops"
      operation: "copy"
      source: "./test/fixtures/"
      destination: "./workspace/test/"
    
    - name: "run_workflow"
      type: "pipeline"
      pipeline_file: "./workflows/main_workflow.yaml"
      inputs:
        data_path: "./workspace/test/input.json"
      config:
        timeout_seconds: 60
    
    - name: "verify_results"
      type: "data_transform"
      input_source: "steps.run_workflow.result"
      operations:
        - operation: "validate"
          expected:
            status: "completed"
            error_count: 0
            output_files: ["report.json", "summary.md"]
```

## Documentation Standards

### Inline Documentation

Document pipelines thoroughly:

```yaml
workflow:
  name: "data_processor"
  description: |
    Processes raw customer data through validation, enrichment,
    and aggregation stages to produce analytics-ready datasets.
    
    Inputs:
      - raw_data_path: Path to raw data file (CSV or JSON)
      - config: Processing configuration
    
    Outputs:
      - processed_data: Cleaned and enriched data
      - quality_report: Data quality metrics
      - error_log: Processing errors
  
  version: "2.1.0"
  author: "Data Team"
  last_updated: "2024-07-03"
  
  steps:
    - name: "validate_data"
      description: "Validates data against business rules"
      # ... step configuration
```

### External Documentation

Maintain comprehensive docs:

```markdown
# Data Processing Pipeline

## Overview
This pipeline processes raw customer data...

## Prerequisites
- Python 3.8+
- Access to data sources
- API credentials

## Configuration
```yaml
inputs:
  raw_data_path: "./data/raw/customers.csv"
  config:
    validation_rules: "strict"
    enrichment_enabled: true
```

## Usage
```bash
mix pipeline.run pipelines/data_processor.yaml \
  --inputs inputs.yaml
```

## Architecture
[Include architecture diagram]

## Error Handling
The pipeline handles errors at multiple levels...
```

## Anti-Patterns to Avoid

### 1. Monolithic Pipelines

❌ **Avoid**:
```yaml
workflow:
  name: "do_everything"
  steps:
    # 100+ steps in one pipeline
    # Multiple unrelated responsibilities
    # Difficult to test and maintain
```

✅ **Instead**:
```yaml
workflow:
  name: "orchestrator"
  steps:
    - name: "data_prep"
      type: "pipeline"
      pipeline_file: "./data_preparation.yaml"
    
    - name: "analysis"
      type: "pipeline"
      pipeline_file: "./analysis.yaml"
```

### 2. Hardcoded Values

❌ **Avoid**:
```yaml
steps:
  - name: "api_call"
    prompt:
      - type: "static"
        content: "Call API at https://api.example.com/v1/data"
```

✅ **Instead**:
```yaml
variables:
  api_endpoint: "${API_ENDPOINT}"
  
steps:
  - name: "api_call"
    prompt:
      - type: "static"
        content: "Call API at {{variables.api_endpoint}}"
```

### 3. Missing Error Handling

❌ **Avoid**:
```yaml
steps:
  - name: "critical_operation"
    type: "claude"
    # No error handling
```

✅ **Instead**:
```yaml
steps:
  - name: "critical_operation"
    type: "claude_robust"
    retry_config:
      max_retries: 3
    on_error:
      - name: "handle_error"
        type: "pipeline"
        pipeline_file: "./error_handler.yaml"
```

## Real-World Examples

### Complete Code Review System

```yaml
workflow:
  name: "code_review_system"
  description: "Automated code review with multi-stage analysis"
  
  steps:
    # Stage 1: Quick scan
    - name: "quick_scan"
      type: "parallel_claude"
      parallel_tasks:
        - id: "syntax_check"
          prompt:
            - type: "file"
              path: "prompts/syntax_check.md"
            - type: "file"
              path: "{{inputs.code_file}}"
        
        - id: "security_scan"
          prompt:
            - type: "file"
              path: "prompts/security_scan.md"
            - type: "file"
              path: "{{inputs.code_file}}"
    
    # Stage 2: Deep analysis if issues found
    - name: "deep_analysis"
      type: "pipeline"
      condition: |
        steps.quick_scan.syntax_check.issues > 0 or 
        steps.quick_scan.security_scan.vulnerabilities > 0
      pipeline_file: "./deep_code_analysis.yaml"
      inputs:
        code_file: "{{inputs.code_file}}"
        quick_scan_results: "{{steps.quick_scan}}"
    
    # Stage 3: Generate fixes
    - name: "generate_fixes"
      type: "claude_session"
      condition: "steps.deep_analysis.fixable_issues > 0"
      session_config:
        session_name: "code_fix_session"
        persist: true
      prompt:
        - type: "file"
          path: "prompts/generate_fixes.md"
        - type: "previous_response"
          step: "deep_analysis"
          extract: "issues"
    
    # Stage 4: Apply and verify
    - name: "apply_fixes"
      type: "claude_robust"
      retry_config:
        max_retries: 2
      claude_options:
        allowed_tools: ["Read", "Write", "Edit"]
      prompt:
        - type: "claude_continue"
          new_prompt: "Apply the generated fixes and verify"
    
    # Stage 5: Final report
    - name: "generate_report"
      type: "gemini"
      prompt:
        - type: "file"
          path: "prompts/review_report.md"
        - type: "static"
          content: "Quick scan results:"
        - type: "previous_response"
          step: "quick_scan"
        - type: "static"
          content: "\nDeep analysis results:"
        - type: "previous_response"
          step: "deep_analysis"
        - type: "static"
          content: "\nApplied fixes:"
        - type: "previous_response"
          step: "apply_fixes"
```

This guide provides comprehensive best practices and patterns for building production-ready pipelines with the Pipeline YAML v2 format.