# Context Management Guide for Recursive Pipelines

## Table of Contents

1. [Overview](#overview)
2. [Context Architecture](#context-architecture)
3. [Variable Resolution](#variable-resolution)
4. [Input Mapping](#input-mapping)
5. [Output Extraction](#output-extraction)
6. [Context Inheritance](#context-inheritance)
7. [Template Engine](#template-engine)
8. [Advanced Patterns](#advanced-patterns)
9. [Performance Considerations](#performance-considerations)
10. [Troubleshooting](#troubleshooting)
11. [API Reference](#api-reference)

## Overview

Context management is the heart of the recursive pipeline system, controlling how data flows between parent and child pipelines. This guide provides comprehensive documentation on managing variable scoping, data passing, and result extraction in nested pipeline architectures.

## Context Architecture

### Context Hierarchy

Each pipeline execution maintains its own context, creating a hierarchical structure:

```
Root Context (main pipeline)
├─ Nested Context Level 1 (sub-pipeline A)
│  ├─ Nested Context Level 2 (sub-pipeline A1)
│  └─ Nested Context Level 2 (sub-pipeline A2)
└─ Nested Context Level 1 (sub-pipeline B)
```

### Context Components

Each context contains:

```elixir
%{
  # Core execution data
  pipeline_id: "unique-id",
  depth: 0,  # Nesting level
  parent: nil | %Context{},  # Parent context reference
  
  # Variable storage
  variables: %{
    "steps" => %{
      "step_name" => %{"result" => any()}
    },
    "global_vars" => %{},
    "workflow" => %{}
  },
  
  # Configuration
  functions: %{},
  providers: %{},
  workspace: "./workspace/nested_pipeline",
  
  # Metadata
  trace_id: "uuid",
  start_time: ~U[2025-01-03 12:00:00Z]
}
```

## Variable Resolution

### Resolution Order

The template engine resolves variables in a specific order:

1. **Current Context First**: Check the current (child) pipeline's context
2. **Parent Context**: If not found and inheritance enabled, check parent
3. **Recursive Up Chain**: Continue up the context chain
4. **Graceful Fallback**: Return original template if not found

### Template Patterns

Supported variable reference patterns:

```yaml
# 1. Step Results
"{{steps.step_name.result}}"              # Full result
"{{steps.step_name.result.field}}"        # Specific field
"{{steps.step_name.result.data.items}}"   # Deep access

# 2. Global Variables
"{{global_vars.api_key}}"
"{{global_vars.config.timeout}}"

# 3. Workflow Data
"{{workflow.name}}"
"{{workflow.config.environment}}"
"{{workflow.metadata.version}}"

# 4. Direct Variables (from inputs)
"{{variable_name}}"
"{{nested.path.to.value}}"
```

### Type Preservation

Single variable templates preserve their original type:

```yaml
inputs:
  # Integer preserved
  count: "{{steps.data.count}}"           # → 42
  
  # Object preserved
  config: "{{steps.setup.result}}"        # → {"timeout": 30, "retries": 3}
  
  # Array preserved
  items: "{{steps.parse.items}}"          # → ["a", "b", "c"]
  
  # String concatenation forces string type
  message: "Count: {{steps.data.count}}"  # → "Count: 42"
```

## Input Mapping

### Basic Input Passing

Pass data from parent to child pipeline:

```yaml
- name: "analyze_data"
  type: "pipeline"
  pipeline_file: "./analysis.yaml"
  inputs:
    # Static values
    mode: "detailed"
    threshold: 0.8
    
    # Dynamic values from parent
    data: "{{steps.prepare.result}}"
    config: "{{global_vars.analysis_config}}"
```

### Complex Input Mapping

Handle complex data structures:

```yaml
inputs:
  # Object composition
  analysis_config:
    source: "{{steps.extract.source_info}}"
    rules: "{{global_vars.processing_rules}}"
    options:
      format: "json"
      validate: true
      threshold: "{{workflow.config.quality_threshold}}"
  
  # Array mapping
  datasets:
    - "{{steps.load1.data}}"
    - "{{steps.load2.data}}"
    - "{{steps.load3.data}}"
  
  # Conditional mapping
  processing_mode: "{{steps.detect.is_large_dataset ? 'batch' : 'stream'}}"
```

### Input Validation Example

```yaml
# parent_pipeline.yaml
steps:
  - name: "validate_inputs"
    type: "claude"
    prompt: |
      Validate these inputs:
      - API Key: {{global_vars.api_key}}
      - Dataset: {{inputs.dataset_path}}
      Return JSON: {"valid": boolean, "errors": []}
  
  - name: "process_if_valid"
    type: "pipeline"
    pipeline_file: "./processor.yaml"
    condition: "{{steps.validate_inputs.result.valid}}"
    inputs:
      dataset: "{{inputs.dataset_path}}"
      api_key: "{{global_vars.api_key}}"
      validation_result: "{{steps.validate_inputs.result}}"
```

## Output Extraction

### Simple Output Extraction

Extract specific step results from nested pipelines:

```yaml
- name: "nested_analysis"
  type: "pipeline"
  pipeline_file: "./analyzer.yaml"
  outputs:
    # Extract entire step results
    - "final_report"      # Gets steps.final_report.result
    - "metrics"          # Gets steps.metrics.result
```

### Path-Based Extraction

Extract nested fields with path notation:

```yaml
outputs:
  # Deep field extraction
  - path: "analysis.performance.score"
    as: "perf_score"
  
  - path: "validation.errors"
    as: "validation_errors"
  
  - path: "report.sections.summary.text"
    as: "summary_text"
```

### Advanced Extraction Patterns

```yaml
# Complex extraction example
- name: "multi_stage_analysis"
  type: "pipeline"
  pipeline_file: "./stages.yaml"
  outputs:
    # Extract from different steps
    - path: "stage1.preprocessing.stats"
      as: "preprocessing_stats"
    
    - path: "stage2.analysis.findings"
      as: "findings"
    
    - path: "stage3.report.url"
      as: "report_url"
    
    # Extract error information
    - path: "validation.error"
      as: "validation_error"

# Using extracted outputs
- name: "summarize"
  type: "claude"
  prompt: |
    Analysis Results:
    - Preprocessing: {{steps.multi_stage_analysis.preprocessing_stats}}
    - Findings: {{steps.multi_stage_analysis.findings}}
    - Report: {{steps.multi_stage_analysis.report_url}}
    {{#if steps.multi_stage_analysis.validation_error}}
    - Validation Error: {{steps.multi_stage_analysis.validation_error}}
    {{/if}}
```

## Context Inheritance

### Inheritance Configuration

Control what child pipelines inherit from parents:

```yaml
- name: "child_pipeline"
  type: "pipeline"
  pipeline_file: "./child.yaml"
  config:
    inherit_context: true      # Inherit all context vars
    inherit_providers: true    # Use parent's LLM configs
    inherit_functions: false   # Don't inherit function defs
```

### Selective Inheritance

Fine-grained control over inheritance:

```elixir
# In child pipeline configuration
config:
  inheritance:
    global_vars:
      include: ["api_keys", "endpoints"]
      exclude: ["temp_vars", "debug_flags"]
    
    providers:
      inherit_all: true
      override:
        claude:
          model: "claude-3.5-sonnet"  # Override parent's model
    
    functions:
      inherit: false  # Start fresh with functions
```

### Inheritance Use Cases

#### 1. Shared Configuration
```yaml
# parent.yaml
global_vars:
  api_endpoint: "https://api.example.com"
  auth_token: "{{env.API_TOKEN}}"
  retry_config:
    max_attempts: 3
    backoff_ms: 1000

steps:
  - name: "fetch_data"
    type: "pipeline"
    pipeline_file: "./fetcher.yaml"
    config:
      inherit_context: true  # Child inherits API config
```

#### 2. Provider Inheritance
```yaml
# parent.yaml
providers:
  claude:
    model: "claude-3.5-sonnet"
    temperature: 0.3
    max_tokens: 4000

steps:
  - name: "analysis"
    type: "pipeline"
    pipeline_file: "./analyzer.yaml"
    config:
      inherit_providers: true  # Use same Claude config
```

#### 3. Isolated Execution
```yaml
# When you need complete isolation
- name: "sandboxed_execution"
  type: "pipeline"
  pipeline_file: "./untrusted.yaml"
  config:
    inherit_context: false
    inherit_providers: false
    inherit_functions: false
  inputs:
    # Explicitly pass only what's needed
    data: "{{steps.sanitize.safe_data}}"
```

## Template Engine

### Template Resolution Process

The custom template engine (`Pipeline.Context.Nested.resolve_template/2`) works as follows:

```elixir
# Resolution steps
1. Parse template for {{...}} patterns
2. Extract variable path (e.g., "steps.myStep.result.field")
3. Navigate context hierarchy to find value
4. Replace template with resolved value
5. Preserve types for single-variable templates
```

### Advanced Template Features

#### Nested Object Access
```yaml
# Given context:
# steps.analyze.result = {
#   "metrics": {
#     "performance": {
#       "score": 95,
#       "grade": "A"
#     }
#   }
# }

inputs:
  score: "{{steps.analyze.result.metrics.performance.score}}"  # → 95
  grade: "{{steps.analyze.result.metrics.performance.grade}}"  # → "A"
```

#### Array Access (Future Enhancement)
```yaml
# Planned support for array indexing
inputs:
  first_item: "{{steps.parse.items[0]}}"
  last_item: "{{steps.parse.items[-1]}}"
  subset: "{{steps.parse.items[0:3]}}"
```

#### Conditional Templates (Future Enhancement)
```yaml
# Planned support for conditionals
inputs:
  mode: "{{steps.check.is_large ? 'batch' : 'stream'}}"
  config: "{{workflow.env == 'prod' ? prod_config : dev_config}}"
```

### Custom Template Resolution

Implement custom resolution logic:

```elixir
defmodule MyCustomResolver do
  def resolve_template(template, context) do
    # Custom resolution logic
    case template do
      "{{custom." <> rest -> 
        resolve_custom_pattern(rest, context)
      _ -> 
        Pipeline.Context.Nested.resolve_template(template, context)
    end
  end
end
```

## Advanced Patterns

### Pattern 1: Data Pipeline with Progressive Enhancement

```yaml
workflow:
  name: "data_processing_pipeline"
  steps:
    # Stage 1: Basic processing
    - name: "basic_processing"
      type: "pipeline"
      pipeline:
        name: "basic"
        steps:
          - name: "validate"
            type: "claude"
            prompt: "Validate data structure"
          - name: "normalize"
            type: "claude"
            prompt: "Normalize data format"
      outputs:
        - "normalize"
        - path: "validate.issues"
          as: "validation_issues"
    
    # Stage 2: Enhanced processing (conditional)
    - name: "enhanced_processing"
      type: "pipeline"
      pipeline_file: "./enhanced_processor.yaml"
      condition: "{{steps.basic_processing.validation_issues == null}}"
      inputs:
        normalized_data: "{{steps.basic_processing.normalize}}"
        processing_hints: "{{global_vars.optimization_rules}}"
      outputs:
        - path: "optimize.result"
          as: "optimized_data"
        - path: "analyze.insights"
          as: "insights"
    
    # Stage 3: Merge results
    - name: "final_merge"
      type: "claude"
      prompt: |
        Merge processing results:
        - Basic: {{steps.basic_processing.normalize}}
        {{#if steps.enhanced_processing}}
        - Optimized: {{steps.enhanced_processing.optimized_data}}
        - Insights: {{steps.enhanced_processing.insights}}
        {{/if}}
```

### Pattern 2: Context Accumulation

Build up context across multiple nested pipelines:

```yaml
workflow:
  name: "accumulating_analysis"
  global_vars:
    accumulated_findings: []
    
  steps:
    - name: "security_scan"
      type: "pipeline"
      pipeline_file: "./scanners/security.yaml"
      outputs:
        - path: "scan.vulnerabilities"
          as: "security_findings"
    
    - name: "accumulate_security"
      type: "claude"
      prompt: |
        Add findings to accumulator:
        Current: {{global_vars.accumulated_findings}}
        New: {{steps.security_scan.security_findings}}
      output_to_global: "accumulated_findings"
    
    - name: "performance_scan"
      type: "pipeline"
      pipeline_file: "./scanners/performance.yaml"
      inputs:
        previous_findings: "{{global_vars.accumulated_findings}}"
      outputs:
        - path: "scan.bottlenecks"
          as: "perf_findings"
    
    - name: "accumulate_performance"
      type: "claude"
      prompt: |
        Add findings to accumulator:
        Current: {{global_vars.accumulated_findings}}
        New: {{steps.performance_scan.perf_findings}}
      output_to_global: "accumulated_findings"
    
    - name: "final_report"
      type: "pipeline"
      pipeline_file: "./reporting/comprehensive.yaml"
      inputs:
        all_findings: "{{global_vars.accumulated_findings}}"
```

### Pattern 3: Dynamic Pipeline Selection

Choose pipelines based on runtime conditions:

```yaml
workflow:
  name: "adaptive_processor"
  steps:
    - name: "detect_type"
      type: "claude"
      prompt: |
        Detect data type and return pipeline selection:
        Data: {{inputs.raw_data}}
        
        Return JSON:
        {
          "data_type": "text|structured|binary",
          "pipeline_path": "./processors/[type]_processor.yaml",
          "config": {}
        }
    
    - name: "process_data"
      type: "pipeline"
      pipeline_file: "{{steps.detect_type.result.pipeline_path}}"
      inputs:
        data: "{{inputs.raw_data}}"
        type_config: "{{steps.detect_type.result.config}}"
      config:
        inherit_context: true
```

## Performance Considerations

### Context Size Management

Large contexts can impact performance. Best practices:

1. **Selective Output Extraction**: Only extract needed fields
   ```yaml
   outputs:
     - path: "analysis.summary"  # Don't extract entire analysis
       as: "summary"
   ```

2. **Clear Unused Variables**: Clean up large intermediate results
   ```yaml
   - name: "cleanup"
     type: "claude"
     prompt: "Process complete"
     clear_vars: ["steps.large_intermediate_data"]
   ```

3. **Streaming Results**: For large data, use streaming patterns
   ```yaml
   config:
     stream_results: true
     chunk_size_mb: 10
   ```

### Memory Optimization

Monitor and optimize memory usage:

```yaml
- name: "memory_intensive"
  type: "pipeline"
  pipeline_file: "./processor.yaml"
  config:
    memory_limit_mb: 512
    gc_after_steps: ["large_transform", "data_aggregation"]
```

### Context Inheritance Performance

Inheritance has performance implications:

```yaml
# Faster: Selective inheritance
config:
  inherit_context: false
inputs:
  only_needed_var: "{{global_vars.specific_value}}"

# Slower: Full inheritance
config:
  inherit_context: true  # Copies entire parent context
```

## Troubleshooting

### Common Issues

#### 1. Variable Not Found

**Error**: Template `{{steps.missing.result}}` not resolved

**Debugging**:
```yaml
- name: "debug_context"
  type: "claude"
  prompt: |
    Debug context state:
    Available steps: {{keys(steps)}}
    Step results: {{json(steps)}}
```

#### 2. Type Mismatch

**Error**: Expected string but got object

**Solution**: Force string conversion
```yaml
inputs:
  # Force string conversion
  text_value: "Data: {{json(steps.complex.result)}}"
  
  # Preserve object type
  object_value: "{{steps.complex.result}}"
```

#### 3. Circular Context Reference

**Error**: Circular reference in context inheritance

**Solution**: Break circular dependency
```yaml
config:
  inherit_context: false  # Break inheritance chain
inputs:
  # Explicitly pass needed values
  required_data: "{{steps.previous.data}}"
```

### Debug Utilities

#### Context Inspector

```yaml
- name: "inspect_context"
  type: "claude"
  prompt: |
    Inspect current context:
    - Depth: {{context.depth}}
    - Pipeline ID: {{context.pipeline_id}}
    - Parent: {{context.parent.pipeline_id}}
    - Variables: {{json(variables)}}
    - Global Vars: {{json(global_vars)}}
```

#### Trace Context Chain

```elixir
# In debug console
Pipeline.Context.Nested.trace_context_chain(context)
# Returns:
[
  %{depth: 2, pipeline: "child_pipeline", parent: "parent_pipeline"},
  %{depth: 1, pipeline: "parent_pipeline", parent: "root"},
  %{depth: 0, pipeline: "root", parent: nil}
]
```

## API Reference

### Core Functions

```elixir
# Create nested context
Pipeline.Context.Nested.create_nested_context(parent_context, step_config)

# Resolve templates
Pipeline.Context.Nested.resolve_template(template, context)
Pipeline.Context.Nested.resolve_inputs(inputs, context)

# Extract outputs
Pipeline.Context.Nested.extract_outputs(results, output_config)
Pipeline.Context.Nested.extract_output_value(results, output_path)

# Context utilities
Pipeline.Context.Nested.should_inherit?(config, key)
Pipeline.Context.Nested.merge_parent_context(child_context, parent_context, config)
```

### Configuration Schema

```yaml
type: pipeline
inputs:                    # Input mappings (optional)
  var_name: "template"    # Template string or static value
  
outputs:                  # Output extraction (optional)
  - "step_name"          # Simple extraction
  - path: "step.field"   # Path-based extraction
    as: "alias"          # With aliasing
    
config:
  inherit_context: boolean      # Inherit all parent context
  inherit_providers: boolean    # Inherit provider configs
  inherit_functions: boolean    # Inherit function definitions
  
  # Advanced inheritance (future)
  inheritance:
    global_vars:
      include: [list]
      exclude: [list]
    providers:
      override: {map}
```

---

This guide provides comprehensive documentation for context management in recursive pipelines. The context system enables powerful data flow patterns while maintaining isolation and safety across nested pipeline executions.