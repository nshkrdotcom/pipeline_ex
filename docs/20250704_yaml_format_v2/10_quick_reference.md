# Pipeline YAML v2 Quick Reference

## Basic Structure

```yaml
workflow:
  name: "pipeline_name"              # Required
  description: "What it does"        # Optional
  version: "2.0.0"                  # Optional
  
  # Environment & auth
  environment:
    mode: "production"              # development|production|test
  
  claude_auth:
    provider: "anthropic"           # anthropic|aws_bedrock|google_vertex
  
  # Defaults for all steps
  defaults:
    gemini_model: "gemini-2.5-flash"
    timeout_seconds: 300
  
  # Step definitions
  steps: []                         # Required
```

## Step Types (17+)

### AI Provider Steps

```yaml
# Basic
type: "gemini"          # Google Gemini
type: "claude"          # Anthropic Claude
type: "parallel_claude" # Multiple Claude instances
type: "gemini_instructor" # Structured output

# Enhanced Claude
type: "claude_smart"    # Preset-based config
type: "claude_session"  # Stateful conversations
type: "claude_extract"  # Content extraction
type: "claude_batch"    # Parallel batch processing
type: "claude_robust"   # Enterprise error handling
```

### Control Flow Steps

```yaml
type: "pipeline"        # Execute another pipeline
type: "for_loop"        # Iterate over collections
type: "while_loop"      # Conditional repetition
type: "switch"          # Multi-branch logic
```

### Data & File Operations

```yaml
type: "data_transform"  # JSONPath transformations
type: "file_ops"        # File manipulation
type: "codebase_query"  # Code intelligence
type: "set_variable"    # State management
type: "checkpoint"      # Save/restore state
```

## Prompt Types

```yaml
prompt:
  # Inline text
  - type: "static"
    content: "Analyze this code"
  
  # External file
  - type: "file"
    path: "prompts/analysis.md"
    variables:
      LANG: "Python"
  
  # Previous step output
  - type: "previous_response"
    step: "analysis"
    extract: "recommendations"
  
  # Session history
  - type: "session_context"
    session_id: "dev_session"
    include_last_n: 10
  
  # Continue conversation
  - type: "claude_continue"
    new_prompt: "Now add tests"
```

## Common Patterns

### Pipeline Composition

```yaml
- name: "modular_step"
  type: "pipeline"
  pipeline_file: "./components/analyzer.yaml"
  inputs:
    data: "{{steps.previous.result}}"
  outputs:
    - path: "analysis.score"
      as: "quality_score"
```

### Loops

```yaml
# For loop
- name: "process_files"
  type: "for_loop"
  iterator: "file"
  data_source: "{{steps.scan.files}}"
  parallel: true
  max_parallel: 5
  steps:
    - name: "analyze"
      type: "claude"
      prompt: "Analyze {{loop.file.path}}"

# While loop
- name: "optimize"
  type: "while_loop"
  condition: "{{score < 90}}"
  max_iterations: 10
  steps:
    - name: "improve"
      type: "claude"
```

### Conditional Execution

```yaml
# Simple condition
condition: "{{steps.test.passed}}"

# Complex condition
condition:
  and:
    - "{{steps.test.passed}}"
    - "{{steps.security.score > 80}}"
    - or:
      - "{{env == 'prod'}}"
      - "{{force_deploy}}"
```

### Error Handling

```yaml
- name: "safe_operation"
  type: "claude_robust"
  retry_config:
    max_retries: 3
    backoff_strategy: "exponential"
    fallback_action: "simplified_prompt"
  continue_on_error: true
```

## Variable Access

```yaml
# Step results
{{steps.step_name.result}}
{{steps.step_name.field.nested}}

# Loop variables
{{loop.item}}              # Current item
{{loop.index}}             # Current index
{{loop.parent.item}}       # Parent loop

# State variables
{{state.variable_name}}
{{variables.global_var}}

# System variables
{{workflow.name}}
{{timestamp}}
{{execution_id}}
```

## Claude Options

```yaml
claude_options:
  # Core
  max_turns: 20
  output_format: "json"      # text|json|stream_json
  
  # Tools
  allowed_tools: ["Write", "Edit", "Read", "Bash", "Search"]
  disallowed_tools: ["Delete"]
  
  # System
  system_prompt: "You are an expert"
  append_system_prompt: "Be concise"
  cwd: "./workspace"
  
  # Async Streaming
  async_streaming: true      # Enable message streaming
  stream_handler: "console"  # console|simple|debug|file|buffer|callback
  stream_buffer_size: 10     # Messages to buffer
  stream_handler_opts:       # Handler-specific options
    show_timestamps: true
    show_tool_use: true
  
  # Advanced
  session_id: "session_123"
  retry_config:
    max_retries: 3
```

## Gemini Configuration

```yaml
# Model selection
model: "gemini-2.5-flash"   # flash|pro|ultra

# Token budget
token_budget:
  max_output_tokens: 4096
  temperature: 0.7          # 0.0-1.0
  top_p: 0.95              # 0.0-1.0
  top_k: 40                # 1-40

# Functions
functions: ["analyze_code", "generate_tests"]
```

## Data Transformation

```yaml
- name: "transform_data"
  type: "data_transform"
  operations:
    - operation: "filter"
      condition: "score > 80"
    
    - operation: "map"
      expression: |
        {
          "id": item.id,
          "priority": item.score > 90 ? "high" : "normal"
        }
    
    - operation: "aggregate"
      function: "average"
      field: "score"
    
    - operation: "sort"
      by: "priority"
      order: "desc"
```

## File Operations

```yaml
- name: "file_management"
  type: "file_ops"
  
  # Operations
  operation: "copy"         # copy|move|delete|validate|list|convert
  
  # For copy/move
  source: "src/*.py"
  destination: "backup/"
  
  # For convert
  format: "csv_to_json"     # Various formats supported
```

## Resource Limits

```yaml
workflow:
  resource_limits:
    max_total_steps: 1000
    max_memory_mb: 4096
    max_execution_time_s: 3600
    max_nesting_depth: 10
    max_cost_usd: 50.00
```

## Safety Features

```yaml
workflow:
  safety:
    sandbox_mode: true
    allowed_paths: ["./workspace"]
    max_file_operations: 1000
    detect_circular_deps: true
```

## Output Schema Validation

```yaml
output_schema:
  type: "object"
  required: ["status", "results"]
  properties:
    status:
      type: "string"
      enum: ["success", "partial", "failed"]
    results:
      type: "array"
      items:
        type: "object"
        properties:
          score:
            type: "number"
            minimum: 0
            maximum: 100
```

## Environment Modes

```yaml
# Development
environment:
  mode: "development"
  debug_level: "detailed"
  allow_mock_providers: true

# Production
environment:
  mode: "production"
  debug_level: "basic"
  cost_alerts:
    enabled: true
    threshold_usd: 10.00
```

## Common Operators

### Comparison
- `==`, `!=`, `>`, `<`, `>=`, `<=`
- `contains`, `starts_with`, `ends_with`
- `matches` (regex)
- `in`, `not_in`
- `between`
- `exists`, `empty`

### Boolean
- `and`, `or`, `not`

### Functions
- `length()`, `count()`
- `sum()`, `average()`, `min()`, `max()`
- `any()`, `all()`
- `filter()`, `map()`
- `concat()`, `append()`
- `hash()`, `now()`, `date()`

## Quick Examples

### Basic Pipeline
```yaml
workflow:
  name: "simple_analysis"
  steps:
    - name: "analyze"
      type: "gemini"
      prompt:
        - type: "file"
          path: "code.py"
```

### With Error Handling
```yaml
- name: "safe_step"
  type: "claude_robust"
  retry_config:
    max_retries: 3
  prompt: "..."
```

### Parallel Processing
```yaml
- name: "parallel_work"
  type: "parallel_claude"
  parallel_tasks:
    - id: "task1"
      prompt: "..."
    - id: "task2"
      prompt: "..."
```

### Nested Pipeline
```yaml
- name: "reusable"
  type: "pipeline"
  pipeline_file: "./component.yaml"
  inputs:
    data: "{{data}}"
```

### Async Streaming
```yaml
- name: "streaming_claude"
  type: "claude"
  claude_options:
    async_streaming: true
    stream_handler: "simple"
    stream_handler_opts:
      show_timestamps: true
  prompt: "Generate a report..."
```

## Debugging

```bash
# Enable debug mode
PIPELINE_DEBUG=true mix pipeline.run workflow.yaml

# Dry run
mix pipeline.run workflow.yaml --dry-run

# Validate syntax
mix pipeline.validate workflow.yaml
```

---

**Full Documentation**: See numbered guides in this directory for detailed information on each feature.