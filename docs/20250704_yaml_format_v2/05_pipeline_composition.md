# Pipeline Composition Reference

## Table of Contents

1. [Overview](#overview)
2. [Pipeline Step Type](#pipeline-step-type)
3. [Input Mapping](#input-mapping)
4. [Output Extraction](#output-extraction)
5. [Context Management](#context-management)
6. [Safety Features](#safety-features)
7. [Execution Configuration](#execution-configuration)
8. [Design Patterns](#design-patterns)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

## Overview

Pipeline composition enables building complex workflows from smaller, reusable pipeline components. This modular approach provides:

- **Reusability**: Share common workflows across projects
- **Maintainability**: Update shared logic in one place
- **Testability**: Test pipeline components in isolation
- **Scalability**: Build arbitrarily complex workflows
- **Organization**: Separate concerns into logical units

## Pipeline Step Type

The `pipeline` step type executes another complete pipeline as a single step:

```yaml
- name: "data_processing"
  type: "pipeline"
  
  # Pipeline source (one required)
  pipeline_file: "./pipelines/data_processor.yaml"    # External file
  pipeline_ref: "common/data_processor"               # Registry (future)
  pipeline:                                           # Inline definition
    name: "inline_processor"
    steps:
      - name: "process"
        type: "gemini"
        prompt:
          - type: "static"
            content: "Process data"
```

### External Pipeline Files

Most common approach - reference external YAML files:

```yaml
steps:
  - name: "security_scan"
    type: "pipeline"
    pipeline_file: "./pipelines/security/vulnerability_scanner.yaml"
    inputs:
      target_directory: "./src"
      scan_depth: "comprehensive"
    outputs:
      - "vulnerabilities"
      - "security_score"
```

**File Organization**:
```
pipelines/
├── components/           # Reusable components
│   ├── data/
│   │   ├── validator.yaml
│   │   ├── transformer.yaml
│   │   └── aggregator.yaml
│   ├── analysis/
│   │   ├── code_review.yaml
│   │   ├── security_scan.yaml
│   │   └── performance_check.yaml
│   └── generation/
│       ├── test_generator.yaml
│       └── doc_generator.yaml
├── workflows/           # Complete workflows
│   ├── full_analysis.yaml
│   └── deployment.yaml
└── templates/          # Pipeline templates
    └── standard_review.yaml
```

### Inline Pipeline Definition

Define pipelines directly within the parent:

```yaml
- name: "quick_validation"
  type: "pipeline"
  pipeline:
    name: "inline_validator"
    steps:
      - name: "syntax_check"
        type: "gemini"
        prompt:
          - type: "static"
            content: "Check syntax validity"
          - type: "static"
            content: "{{inputs.code}}"
      
      - name: "semantic_check"
        type: "gemini"
        prompt:
          - type: "static"
            content: "Verify semantic correctness"
          - type: "previous_response"
            step: "syntax_check"
```

### Pipeline Registry (Future)

Reference pipelines from a central registry:

```yaml
- name: "standard_security_scan"
  type: "pipeline"
  pipeline_ref: "security/owasp_top_10_scan"
  version: "2.1.0"
  inputs:
    target: "{{workspace.path}}"
```

## Input Mapping

Pass data from parent to child pipeline:

```yaml
- name: "analyze_code"
  type: "pipeline"
  pipeline_file: "./pipelines/code_analyzer.yaml"
  
  inputs:
    # Direct values
    language: "python"
    framework: "django"
    
    # From previous steps
    source_code: "{{steps.extract.code}}"
    requirements: "{{steps.parse.requirements}}"
    
    # From workflow context
    project_name: "{{workflow.project_name}}"
    environment: "{{workflow.environment}}"
    
    # From state variables
    analysis_config: "{{state.config}}"
    
    # Complex expressions
    threshold: "{{state.base_threshold * 1.5}}"
    
    # Arrays and objects
    files_to_analyze: "{{steps.scan.python_files}}"
    options:
      depth: "comprehensive"
      include_tests: true
      metrics: ["complexity", "coverage", "quality"]
```

### Type Preservation

Single template references preserve their original type:

```yaml
inputs:
  # Preserves integer type
  max_iterations: "{{config.iterations}}"        # → 10
  
  # Preserves object type  
  settings: "{{steps.load.config}}"              # → {"timeout": 30, "retry": 3}
  
  # Preserves array type
  items: "{{steps.gather.results}}"              # → ["a", "b", "c"]
  
  # String concatenation forces string type
  message: "Count: {{config.iterations}}"        # → "Count: 10"
```

### Input Validation

Child pipelines can validate inputs:

```yaml
# child_pipeline.yaml
workflow:
  name: "validated_processor"
  
  # Input schema (future)
  input_schema:
    type: "object"
    required: ["data", "format"]
    properties:
      data:
        type: "array"
        minItems: 1
      format:
        type: "string"
        enum: ["json", "csv", "xml"]
  
  steps:
    - name: "process"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Process {{inputs.data}} in {{inputs.format}} format"
```

## Output Extraction

Extract specific results from nested pipelines:

```yaml
- name: "run_analysis"
  type: "pipeline"
  pipeline_file: "./analyzer.yaml"
  
  outputs:
    # Simple extraction - gets steps.{name}.result
    - "final_report"
    
    # Path-based extraction
    - path: "metrics.security.score"
      as: "security_score"
    
    - path: "analysis.vulnerabilities"
      as: "vulnerabilities_list"
    
    - path: "summary.recommendations[0]"
      as: "top_recommendation"
```

### Output Patterns

**Simple Extraction**:
```yaml
outputs:
  - "step_name"    # Extracts steps.step_name.result
```

**Path Extraction**:
```yaml
outputs:
  - path: "data.items[0].value"
    as: "first_value"
  
  - path: "metrics.performance.response_time"
    as: "response_time"
```

**Multiple Extractions**:
```yaml
outputs:
  - path: "analysis.score"
    as: "quality_score"
  
  - path: "analysis.issues"
    as: "found_issues"
  
  - path: "recommendations"
    as: "improvement_suggestions"
```

### Using Extracted Outputs

```yaml
steps:
  - name: "security_pipeline"
    type: "pipeline"
    pipeline_file: "./security_scan.yaml"
    outputs:
      - path: "scan.vulnerabilities"
        as: "vulns"
      - path: "scan.risk_score"
        as: "risk"
  
  - name: "process_results"
    type: "gemini"
    prompt:
      - type: "static"
        content: |
          Risk Score: {{steps.security_pipeline.risk}}
          Vulnerabilities Found: {{length(steps.security_pipeline.vulns)}}
          
          Details:
      - type: "static"
        content: "{{steps.security_pipeline.vulns}}"
```

## Context Management

### Context Inheritance

Control what context is passed to child pipelines:

```yaml
- name: "child_pipeline"
  type: "pipeline"
  pipeline_file: "./child.yaml"
  
  config:
    inherit_context: true        # Pass all parent context
    inherit_providers: true      # Inherit API configurations
    inherit_functions: false     # Don't inherit function definitions
```

**Inheritance Options**:
- `inherit_context`: Share variables and state
- `inherit_providers`: Share API keys and settings
- `inherit_functions`: Share Gemini function definitions

### Context Isolation

Each pipeline maintains its own context:

```yaml
# Parent pipeline
workflow:
  name: "parent"
  variables:
    shared_var: "parent_value"
    private_var: "parent_only"
  
  steps:
    - name: "child_isolated"
      type: "pipeline"
      pipeline_file: "./child.yaml"
      config:
        inherit_context: false    # Complete isolation
      inputs:
        # Explicitly pass needed values
        needed_var: "{{variables.shared_var}}"
```

### Variable Resolution

Variable resolution follows a hierarchical order:

1. Child pipeline's local variables
2. Child pipeline's inputs
3. Inherited parent context (if enabled)
4. Parent's parent context (recursive)

```yaml
# Variable resolution example
- name: "nested_pipeline"
  type: "pipeline"
  pipeline_file: "./nested.yaml"
  config:
    inherit_context: true
  inputs:
    # These override any inherited values
    override_var: "child_specific_value"
```

## Safety Features

### Recursion Protection

Prevent infinite recursion and circular dependencies:

```yaml
- name: "recursive_pipeline"
  type: "pipeline"
  pipeline_file: "./processor.yaml"
  
  config:
    max_depth: 5                 # Maximum nesting depth
```

**Circular Dependency Detection**:
```yaml
# pipeline_a.yaml
- name: "call_b"
  type: "pipeline"
  pipeline_file: "./pipeline_b.yaml"

# pipeline_b.yaml
- name: "call_a"
  type: "pipeline"
  pipeline_file: "./pipeline_a.yaml"  # ERROR: Circular dependency!
```

### Resource Limits

Control resource usage:

```yaml
- name: "resource_limited"
  type: "pipeline"
  pipeline_file: "./heavy_processor.yaml"
  
  config:
    memory_limit_mb: 1024        # 1GB memory limit
    timeout_seconds: 300         # 5 minute timeout
    max_total_steps: 100         # Step count limit
```

### Error Boundaries

Isolate errors within child pipelines:

```yaml
- name: "error_isolated"
  type: "pipeline"
  pipeline_file: "./risky_operation.yaml"
  
  config:
    continue_on_error: true      # Don't fail parent
    capture_errors: true         # Store error details
  
  # Handle errors in parent
  error_handler:
    - name: "handle_child_error"
      type: "gemini"
      condition: "steps.error_isolated.error != null"
      prompt:
        - type: "static"
          content: "Child pipeline failed: {{steps.error_isolated.error}}"
```

## Execution Configuration

### Workspace Management

Each pipeline can have its own workspace:

```yaml
- name: "isolated_workspace"
  type: "pipeline"
  pipeline_file: "./file_processor.yaml"
  
  config:
    workspace_dir: "./nested/{{step.name}}"
    cleanup_on_success: true     # Remove after completion
    cleanup_on_error: false      # Keep for debugging
```

### Checkpointing

Nested checkpoint configuration:

```yaml
- name: "checkpointed_pipeline"
  type: "pipeline"
  pipeline_file: "./long_running.yaml"
  
  config:
    checkpoint_enabled: true
    checkpoint_frequency: 10     # Every 10 steps
    checkpoint_dir: "./checkpoints/nested"
```

### Execution Modes

```yaml
- name: "execution_modes"
  type: "pipeline"
  pipeline_file: "./processor.yaml"
  
  config:
    # Tracing and debugging
    enable_tracing: true
    trace_metadata:
      request_id: "{{inputs.request_id}}"
      user_id: "{{inputs.user_id}}"
    
    # Performance
    cache_enabled: true          # Cache pipeline definition
    lazy_load: true              # Load only when needed
    
    # Retry configuration
    max_retries: 2
    retry_on: ["timeout", "resource_limit"]
```

## Design Patterns

### Component Library Pattern

Build a library of reusable components:

```yaml
# components/validation/schema_validator.yaml
workflow:
  name: "schema_validator"
  description: "Validates data against JSON schema"
  
  steps:
    - name: "validate"
      type: "gemini"
      prompt:
        - type: "static"
          content: |
            Validate this data against the schema:
            Data: {{inputs.data}}
            Schema: {{inputs.schema}}
```

Usage:
```yaml
steps:
  - name: "validate_user_data"
    type: "pipeline"
    pipeline_file: "./components/validation/schema_validator.yaml"
    inputs:
      data: "{{steps.parse.user_data}}"
      schema: "{{config.user_schema}}"
```

### Pipeline Template Pattern

Create parameterized pipeline templates:

```yaml
# templates/standard_analysis.yaml
workflow:
  name: "standard_analysis_template"
  
  steps:
    - name: "analyze"
      type: "{{inputs.analyzer_type}}"
      prompt:
        - type: "file"
          path: "{{inputs.prompt_path}}"
        - type: "file"
          path: "{{inputs.target_path}}"
```

### Hierarchical Composition

Build complex workflows from layers:

```yaml
# Top-level workflow
workflow:
  name: "complete_system"
  
  steps:
    - name: "data_pipeline"
      type: "pipeline"
      pipeline_file: "./pipelines/data_pipeline.yaml"
      
    - name: "analysis_pipeline"
      type: "pipeline"
      pipeline_file: "./pipelines/analysis_pipeline.yaml"
      inputs:
        data: "{{steps.data_pipeline.processed_data}}"
    
    - name: "reporting_pipeline"
      type: "pipeline"
      pipeline_file: "./pipelines/reporting_pipeline.yaml"
      inputs:
        analysis: "{{steps.analysis_pipeline.results}}"
```

### Factory Pattern

Dynamically select pipelines:

```yaml
steps:
  - name: "detect_type"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Detect the project type"
  
  - name: "run_appropriate_pipeline"
    type: "pipeline"
    pipeline_file: "./pipelines/{{steps.detect_type.project_type}}_analyzer.yaml"
    inputs:
      project_path: "./src"
```

### Recursive Processing Pattern

Process hierarchical data structures:

```yaml
workflow:
  name: "tree_processor"
  
  steps:
    - name: "process_node"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Process node: {{inputs.node}}"
    
    - name: "process_children"
      type: "for_loop"
      iterator: "child"
      data_source: "steps.process_node.children"
      
      steps:
        - name: "recurse"
          type: "pipeline"
          pipeline_ref: "tree_processor"
          inputs:
            node: "{{loop.child}}"
          config:
            max_depth: "{{inputs.max_depth - 1}}"
```

## Best Practices

### 1. Pipeline Organization

**Single Responsibility**:
- Each pipeline should have one clear purpose
- Keep pipelines focused and cohesive
- Avoid mixing unrelated functionality

**Naming Conventions**:
- Use descriptive names: `validate_user_input.yaml`
- Include action verbs: `generate_`, `analyze_`, `transform_`
- Group by domain: `security/scan_vulnerabilities.yaml`

**Directory Structure**:
```
pipelines/
├── components/      # Small, reusable units
├── workflows/       # Complete business workflows
├── templates/       # Parameterized templates
└── experimental/    # Work in progress
```

### 2. Input/Output Design

**Clear Interfaces**:
```yaml
# Document expected inputs
workflow:
  name: "data_processor"
  description: "Processes raw data into structured format"
  
  # Future: Input documentation
  inputs:
    raw_data:
      type: "array"
      description: "Raw data records to process"
    format:
      type: "string"
      enum: ["json", "csv", "xml"]
      description: "Output format"
```

**Minimal Coupling**:
- Pass only required data
- Avoid tight coupling between pipelines
- Use clear, documented interfaces

### 3. Error Handling

**Graceful Degradation**:
```yaml
- name: "optional_enhancement"
  type: "pipeline"
  pipeline_file: "./enhance_data.yaml"
  config:
    continue_on_error: true
    fallback_value: "{{inputs.original_data}}"
```

**Error Context**:
```yaml
- name: "critical_operation"
  type: "pipeline"
  pipeline_file: "./critical.yaml"
  
  on_error:
    - name: "log_error"
      type: "set_variable"
      variables:
        error_context:
          pipeline: "critical_operation"
          inputs: "{{inputs}}"
          error: "{{error}}"
          timestamp: "{{now()}}"
```

### 4. Performance Optimization

**Pipeline Caching**:
```yaml
config:
  cache_pipeline: true           # Cache parsed pipeline
  cache_ttl: 3600               # 1 hour TTL
```

**Lazy Loading**:
```yaml
- name: "conditional_pipeline"
  type: "pipeline"
  pipeline_file: "./expensive_operation.yaml"
  condition: "steps.check.requires_processing"
  config:
    lazy_load: true             # Only load if condition met
```

**Resource Pooling**:
```yaml
config:
  reuse_workspace: true         # Reuse workspace between runs
  pool_size: 5                  # Connection pool size
```

### 5. Testing Strategies

**Isolated Testing**:
```yaml
# Test individual pipeline components
mix pipeline.run pipelines/components/validator.yaml \
  --inputs '{"data": "test_data", "schema": "test_schema"}'
```

**Mock Pipelines**:
```yaml
# Use mock pipelines for testing
- name: "test_with_mock"
  type: "pipeline"
  pipeline_file: "{{TEST_MODE ? './mocks/processor.yaml' : './processor.yaml'}}"
```

## Troubleshooting

### Common Issues

**1. Circular Dependencies**
```
Error: Circular dependency detected: A -> B -> C -> A
```
Solution: Review pipeline dependencies and remove cycles

**2. Maximum Depth Exceeded**
```
Error: Maximum nesting depth (10) exceeded
```
Solutions:
- Increase `max_depth` configuration
- Refactor to reduce nesting
- Use iterative instead of recursive approach

**3. Input Type Mismatch**
```
Error: Expected array for 'items', got string
```
Solution: Ensure input types match expected types

**4. Output Path Not Found**
```
Error: Path 'results.data.value' not found in pipeline output
```
Solution: Verify the output structure matches extraction paths

### Debugging Tools

**Execution Tracing**:
```yaml
config:
  enable_tracing: true
  trace_level: "detailed"       # Show all operations
```

**Debug Output**:
```bash
PIPELINE_DEBUG=true mix pipeline.run workflow.yaml
```

**Execution Visualization**:
```
Execution Tree:
├─ main_workflow (0ms)
│  ├─ data_prep (15ms)
│  │  └─ validator (8ms)
│  │     └─ schema_check: valid
│  ├─ processor (125ms)
│  │  ├─ transform (45ms)
│  │  └─ aggregate (80ms)
│  └─ reporter (22ms)
```

### Performance Analysis

**Metrics Collection**:
```yaml
config:
  collect_metrics: true
  metrics:
    - execution_time
    - memory_usage
    - step_count
```

**Bottleneck Identification**:
```
Performance Report:
- Total Duration: 289ms
- Slowest Pipeline: data_processor (125ms)
- Memory Peak: 234MB
- Total Steps: 15
- Nesting Depth: 3
```

This reference provides comprehensive documentation for pipeline composition in Pipeline YAML v2 format, enabling powerful modular workflow design.