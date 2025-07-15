# Complete YAML Schema Reference

## Table of Contents

1. [Root Structure](#root-structure)
2. [Workflow Configuration](#workflow-configuration)
3. [Defaults Section](#defaults-section)
4. [Steps Section](#steps-section)
5. [Step Types Schema](#step-types-schema)
6. [Prompt Configuration](#prompt-configuration)
7. [Advanced Configuration](#advanced-configuration)
8. [Complete Schema Definition](#complete-schema-definition)

## Root Structure

Every pipeline configuration file must have a single root key `workflow`:

```yaml
workflow:
  # All configuration goes here
```

## Workflow Configuration

### Required Fields

```yaml
workflow:
  name: string                    # Unique identifier for the workflow
  steps: array                    # List of workflow steps (at least one required)
```

### Optional Fields

```yaml
workflow:
  description: string             # Human-readable description
  version: string                 # Workflow version (e.g., "2.0")
  
  # Execution settings
  checkpoint_enabled: boolean     # Enable state saving (default: false)
  workspace_dir: string           # Claude's sandbox directory (default: "./workspace")
  checkpoint_dir: string          # Checkpoint storage (default: "./checkpoints")
  output_dir: string              # Output directory (default: "./outputs/{workflow_name}")
  
  # Authentication & environment
  claude_auth:                    # Claude authentication configuration
    auto_check: boolean           # Verify auth before starting
    provider: enum                # "anthropic", "aws_bedrock", "google_vertex"
    fallback_mock: boolean        # Use mocks if auth fails in dev
    diagnostics: boolean          # Run auth diagnostics
  
  environment:                    # Environment configuration
    mode: enum                    # "development", "production", "test"
    debug_level: enum             # "basic", "detailed", "performance"
    cost_alerts:
      enabled: boolean
      threshold_usd: float
      notify_on_exceed: boolean
  
  # Default settings
  defaults: object                # Default values for all steps
  
  # Function definitions
  gemini_functions: object        # Gemini function calling definitions
  
  # Resource limits
  resource_limits:
    max_total_steps: integer      # Maximum steps across all pipelines
    max_memory_mb: integer        # Memory limit in MB
    max_execution_time_s: integer # Total execution time limit
```

## Defaults Section

Sets default values inherited by all steps unless overridden:

```yaml
defaults:
  # Model configuration
  gemini_model: string            # Default Gemini model
  claude_preset: enum             # Default Claude preset
  claude_model: string            # Default Claude model ("sonnet", "opus", specific version)
  claude_fallback_model: string   # Default Claude fallback model
  
  # Token configuration
  gemini_token_budget:
    max_output_tokens: integer    # 256-8192
    temperature: float            # 0.0-1.0
    top_p: float                  # 0.0-1.0
    top_k: integer                # 1-40
  
  # Output configuration
  claude_output_format: enum      # "json", "text", "stream-json"
  output_dir: string              # Default output directory
  
  # Execution settings
  timeout_seconds: integer        # Default step timeout
  retry_on_error: boolean         # Auto-retry failed steps
  continue_on_error: boolean      # Continue workflow on step failure
```

## Steps Section

Array of step definitions that form the workflow:

```yaml
steps:
  - name: string                  # Unique step identifier (required)
    type: string                  # Step type (required)
    description: string           # Step description (optional)
    
    # Conditional execution
    condition: string | object    # Skip step based on condition
    
    # Output handling
    output_to_file: string        # Save output to file
    output_schema: object         # Validate output structure
    
    # Step-specific configuration
    # ... varies by step type
```

## Step Types Schema

### AI Provider Steps

#### 1. Gemini Step (`type: "gemini"`)

```yaml
- name: string
  type: "gemini"
  role: enum["brain", "muscle"]  # Semantic role (optional)
  
  # Model configuration
  model: string                   # Override default model
  token_budget:
    max_output_tokens: integer
    temperature: float
    top_p: float
    top_k: integer
  
  # Function calling
  functions: array[string]        # Function names to enable
  
  # Prompt configuration
  prompt: array                   # Required (see Prompt Configuration)
  
  # Output
  output_to_file: string
  output_schema: object           # JSON Schema for validation
```

#### 2. Claude Step (`type: "claude"`)

```yaml
- name: string
  type: "claude"
  role: enum["brain", "muscle"]
  
  claude_options:
    # Core settings
    max_turns: integer            # Conversation limit
    output_format: enum           # "text", "json", "stream_json"
    verbose: boolean              # Detailed logging
    
    # Tool management
    allowed_tools: array[string]  # Permitted tools
    disallowed_tools: array[string]
    
    # System prompts
    system_prompt: string         # Override system prompt
    append_system_prompt: string  # Additional instructions
    
    # Working directory
    cwd: string                   # Working directory path
    
    # Advanced options
    session_id: string            # Session continuation
    resume_session: boolean       # Auto-resume if exists
    debug_mode: boolean
    telemetry_enabled: boolean
    cost_tracking: boolean
    
    # Retry configuration
    retry_config:
      max_retries: integer
      backoff_strategy: enum      # "linear", "exponential"
      retry_on: array[string]     # Error conditions
    
    # Timeout
    timeout_ms: integer
  
  prompt: array                   # Required
  output_to_file: string
```

#### 3. Enhanced Claude Steps

##### Claude Smart (`type: "claude_smart"`)

```yaml
- name: string
  type: "claude_smart"
  preset: enum                    # "development", "production", "analysis", "chat"
  environment_aware: boolean      # Auto-detect from Mix env
  
  # Inherits all claude_options
  claude_options: object          # Optional overrides
  prompt: array                   # Required
```

##### Claude Session (`type: "claude_session"`)

```yaml
- name: string
  type: "claude_session"
  
  session_config:
    session_name: string          # Session identifier
    persist: boolean              # Save session state
    continue_on_restart: boolean  # Resume after failure
    checkpoint_frequency: integer # Save every N turns
    max_turns: integer            # Session turn limit
    description: string           # Session description
  
  claude_options: object          # Standard Claude options
  prompt: array                   # Required
```

##### Claude Extract (`type: "claude_extract"`)

```yaml
- name: string
  type: "claude_extract"
  preset: enum                    # Claude preset
  
  extraction_config:
    use_content_extractor: boolean
    format: enum                  # "text", "json", "structured", "summary", "markdown"
    post_processing: array[string] # Processing steps
    max_summary_length: integer
    include_metadata: boolean
  
  claude_options: object
  prompt: array
```

##### Claude Batch (`type: "claude_batch"`)

```yaml
- name: string
  type: "claude_batch"
  
  batch_config:
    max_parallel: integer         # Concurrent executions
    timeout_per_task: integer     # Per-task timeout
    consolidate_results: boolean  # Merge all results
  
  tasks: array
    - id: string                  # Task identifier
      prompt: array               # Task-specific prompt
      output_to_file: string      # Task output file
      claude_options: object      # Task-specific options
```

##### Claude Robust (`type: "claude_robust"`)

```yaml
- name: string
  type: "claude_robust"
  
  retry_config:
    max_retries: integer
    backoff_strategy: enum
    retry_conditions: array[string]
    fallback_action: string       # Action on final failure
  
  claude_options: object
  prompt: array
```

#### 4. Parallel Claude (`type: "parallel_claude"`)

```yaml
- name: string
  type: "parallel_claude"
  
  parallel_tasks: array           # Required
    - id: string                  # Task identifier
      claude_options: object      # Task Claude settings
      prompt: array               # Task prompt
      output_to_file: string      # Task output
      condition: string           # Optional task condition
```

#### 5. Gemini Instructor (`type: "gemini_instructor"`)

```yaml
- name: string
  type: "gemini_instructor"
  
  model: string                   # Gemini model
  schema: object                  # Output structure schema
  validation_mode: enum           # "strict", "loose"
  
  prompt: array
  output_to_file: string
```

### Control Flow Steps

#### 6. Pipeline Step (`type: "pipeline"`)

```yaml
- name: string
  type: "pipeline"
  
  # Pipeline source (one required)
  pipeline_file: string           # External file path
  pipeline_ref: string            # Registry reference (future)
  pipeline: object                # Inline pipeline definition
  
  # Input mapping
  inputs: object                  # Variables to pass
  
  # Output extraction
  outputs: array
    - string                      # Simple extraction
    - path: string                # Path-based extraction
      as: string                  # Output variable name
  
  # Execution configuration
  config:
    inherit_context: boolean      # Inherit parent context
    inherit_providers: boolean    # Inherit provider configs
    inherit_functions: boolean    # Inherit function defs
    workspace_dir: string         # Nested workspace
    checkpoint_enabled: boolean
    timeout_seconds: integer
    max_retries: integer
    continue_on_error: boolean
    max_depth: integer            # Nesting limit
    memory_limit_mb: integer
    enable_tracing: boolean
```

#### 7. For Loop (`type: "for_loop"`)

```yaml
- name: string
  type: "for_loop"
  
  # Iterator configuration
  iterator: string                # Loop variable name
  data_source: string | array     # Data to iterate over
  
  # Execution settings
  parallel: boolean               # Parallel execution
  max_parallel: integer           # Concurrent limit
  break_on_error: boolean         # Stop on first error
  
  # Loop body
  steps: array                    # Steps to execute
```

#### 8. While Loop (`type: "while_loop"`)

```yaml
- name: string
  type: "while_loop"
  
  # Condition
  condition: string | object      # Loop condition
  
  # Safety limits
  max_iterations: integer         # Maximum iterations
  timeout_seconds: integer        # Total timeout
  
  # Loop body
  steps: array                    # Steps to execute
```

#### 9. Switch/Case (`type: "switch"`)

```yaml
- name: string
  type: "switch"
  
  expression: string              # Value to switch on
  
  cases: object                   # Case mappings
    "value1": array[steps]
    "value2": array[steps]
  
  default: array[steps]           # Default case
```

### Data & File Operations

#### 10. Data Transform (`type: "data_transform"`)

```yaml
- name: string
  type: "data_transform"
  
  input_source: string            # Data source
  
  operations: array
    - operation: enum             # "filter", "map", "aggregate", "join", "group_by", "sort"
      field: string               # Target field
      condition: string           # For filter
      expression: string          # For map/transform
      function: string            # For aggregate
      join_key: string            # For join
      order: enum                 # For sort: "asc", "desc"
  
  output_field: string            # Result variable
  output_to_file: string
```

#### 11. File Operations (`type: "file_ops"`)

```yaml
- name: string
  type: "file_ops"
  
  operation: enum                 # "copy", "move", "delete", "validate", "list", "convert"
  
  # For copy/move
  source: string | array
  destination: string
  
  # For validate
  files: array
    - path: string
      must_exist: boolean
      must_be_dir: boolean
      min_size: integer
      max_size: integer
  
  # For convert
  format: enum                    # "csv_to_json", "json_to_csv", "yaml_to_json", etc.
  
  # For list
  pattern: string                 # Glob pattern
  recursive: boolean
```

#### 12. Codebase Query (`type: "codebase_query"`)

```yaml
- name: string
  type: "codebase_query"
  
  codebase_context: boolean       # Include project info
  
  queries: object
    query_name:
      # File queries
      find_files:
        - type: enum              # "source", "test", "config", "main"
        - pattern: string         # Glob pattern
        - exclude_tests: boolean
        - modified_since: string  # Date/time
        - related_to: string      # File reference
      
      # Code queries
      find_functions:
        - in_file: string
        - public_only: boolean
        - with_annotation: string
      
      # Dependency queries
      find_dependencies:
        - for_file: string
        - include_transitive: boolean
      
      find_dependents:
        - of_file: string
        - include_tests: boolean
  
  output_to_file: string
```

### State Management

#### 13. Set Variable (`type: "set_variable"`)

```yaml
- name: string
  type: "set_variable"
  
  variables: object               # Variable assignments
    var_name: value               # Static value
    computed: "{{expression}}"    # Computed value
  
  scope: enum                     # "global", "local", "session"
```

#### 14. Checkpoint (`type: "checkpoint"`)

```yaml
- name: string
  type: "checkpoint"
  
  state: object                   # State to save
  
  checkpoint_name: string         # Custom name
  include_workspace: boolean      # Save workspace files
  compress: boolean               # Compress checkpoint
```

## Prompt Configuration

All AI steps require prompt configuration:

```yaml
prompt: array
  # Static content
  - type: "static"
    content: string               # Inline text
  
  # File content
  - type: "file"
    path: string                  # File path
    variables: object             # Template variables
    inject_as: string             # Variable name
    encoding: string              # File encoding
  
  # Previous response
  - type: "previous_response"
    step: string                  # Step name
    extract: string               # JSON path
    extract_with: enum            # "content_extractor"
    summary: boolean              # Summarize content
    max_length: integer           # Length limit
  
  # Session context
  - type: "session_context"
    session_id: string            # Session ID
    include_last_n: integer       # Message count
  
  # Claude continue
  - type: "claude_continue"
    new_prompt: string            # Continuation prompt
```

## Advanced Configuration

### Condition Syntax

```yaml
# Simple conditions
condition: "steps.analyze.score > 7"

# Boolean expressions
condition:
  and:
    - "steps.test.passed == true"
    - or:
      - "steps.analyze.score > 8"
      - "steps.review.approved == true"
    - not: "steps.validate.errors > 0"

# Operators
# Comparison: ==, !=, >, <, >=, <=
# String: contains, matches, starts_with, ends_with
# Array: in, not_in, any, all
# Special: between, exists, empty
```

### Function Definitions

```yaml
gemini_functions:
  function_name:
    description: string
    parameters:
      type: object
      properties:
        param1:
          type: string
          description: string
          enum: array             # Optional values
        param2:
          type: integer
          minimum: integer
          maximum: integer
      required: array[string]
```

### Output Schema Validation

```yaml
output_schema:
  type: object
  required: array[string]
  properties:
    field_name:
      type: enum                  # "string", "number", "boolean", "object", "array"
      description: string
      # Type-specific constraints
      minLength: integer          # For strings
      maxLength: integer
      pattern: string             # Regex
      minimum: number             # For numbers
      maximum: number
      items: object               # For arrays
      properties: object          # For objects
```

## Complete Schema Definition

```yaml
workflow:
  # Required
  name: string
  steps: array[Step]
  
  # Optional
  description: string
  version: string
  checkpoint_enabled: boolean
  workspace_dir: string
  checkpoint_dir: string
  output_dir: string
  
  # Authentication
  claude_auth:
    auto_check: boolean
    provider: enum["anthropic", "aws_bedrock", "google_vertex"]
    fallback_mock: boolean
    diagnostics: boolean
  
  # Environment
  environment:
    mode: enum["development", "production", "test"]
    debug_level: enum["basic", "detailed", "performance"]
    cost_alerts:
      enabled: boolean
      threshold_usd: float
      notify_on_exceed: boolean
  
  # Defaults
  defaults:
    gemini_model: string
    gemini_token_budget: TokenBudget
    claude_output_format: enum["json", "text", "stream-json"]
    claude_preset: enum["development", "production", "analysis", "chat"]
    output_dir: string
    timeout_seconds: integer
    retry_on_error: boolean
    continue_on_error: boolean
  
  # Functions
  gemini_functions: map[string, FunctionDefinition]
  
  # Resource limits
  resource_limits:
    max_total_steps: integer
    max_memory_mb: integer
    max_execution_time_s: integer
```

This schema reference provides the complete structure for Pipeline YAML v2 format, including all fields, types, and validation rules.