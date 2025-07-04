# Step Types Reference

## Table of Contents

1. [Overview](#overview)
2. [AI Provider Steps](#ai-provider-steps)
   - [Gemini](#gemini)
   - [Claude](#claude)
   - [Claude Smart](#claude-smart)
   - [Claude Session](#claude-session)
   - [Claude Extract](#claude-extract)
   - [Claude Batch](#claude-batch)
   - [Claude Robust](#claude-robust)
   - [Parallel Claude](#parallel-claude)
   - [Gemini Instructor](#gemini-instructor)
3. [Control Flow Steps](#control-flow-steps)
   - [Pipeline](#pipeline)
   - [For Loop](#for-loop)
   - [While Loop](#while-loop)
   - [Switch/Case](#switchcase)
4. [Data & File Operations](#data--file-operations)
   - [Data Transform](#data-transform)
   - [File Operations](#file-operations)
   - [Codebase Query](#codebase-query)
5. [State Management](#state-management)
   - [Set Variable](#set-variable)
   - [Checkpoint](#checkpoint)

## Overview

Pipeline supports 17+ distinct step types organized into four categories:

1. **AI Provider Steps**: Interact with Claude and Gemini APIs
2. **Control Flow Steps**: Manage execution flow and pipeline composition
3. **Data & File Operations**: Transform data and manipulate files
4. **State Management**: Manage variables and checkpoints

## AI Provider Steps

### Gemini

**Type**: `gemini`  
**Purpose**: Use Google's Gemini models for analysis, planning, and decision-making

```yaml
- name: "analyze_requirements"
  type: "gemini"
  role: "brain"                   # Semantic role indicator
  model: "gemini-2.5-flash"       # Model selection
  
  # Token configuration
  token_budget:
    max_output_tokens: 4096
    temperature: 0.7              # Creativity level (0-1)
    top_p: 0.95                   # Nucleus sampling
    top_k: 40                     # Top-k sampling
  
  # Function calling
  functions:
    - "evaluate_code_quality"
    - "generate_test_cases"
  
  # Prompt
  prompt:
    - type: "static"
      content: "Analyze these requirements and create a plan"
    - type: "file"
      path: "requirements.md"
  
  # Output
  output_to_file: "analysis_plan.json"
  output_schema:
    type: "object"
    required: ["plan", "risks", "timeline"]
```

**Key Features**:
- Multiple model options (flash, pro, etc.)
- Function calling support
- Structured output with schema validation
- Fine-tuned token control

**Common Use Cases**:
- Requirements analysis
- Architecture planning
- Code review and quality assessment
- Test generation
- Decision making

### Claude

**Type**: `claude`  
**Purpose**: Use Anthropic's Claude for code execution, file manipulation, and implementation tasks

```yaml
- name: "implement_feature"
  type: "claude"
  role: "muscle"                  # Execution role
  
  claude_options:
    # Core settings
    max_turns: 20                 # Conversation turns limit
    output_format: "json"         # Response format
    verbose: true                 # Detailed logging
    
    # Tool permissions
    allowed_tools: ["Write", "Edit", "Read", "Bash", "Search"]
    disallowed_tools: ["Delete"]  # Explicitly forbidden
    
    # System prompts
    system_prompt: "You are an expert Python developer"
    append_system_prompt: "Follow PEP 8 strictly"
    
    # Working environment
    cwd: "./workspace/backend"    # Working directory
    
    # Advanced options
    session_id: "feature_dev_001" # For session continuation
    resume_session: true          # Resume if exists
    debug_mode: true
    telemetry_enabled: true
    cost_tracking: true
  
  prompt:
    - type: "static"
      content: "Implement the user authentication feature"
    - type: "previous_response"
      step: "analyze_requirements"
      extract: "implementation_plan"
  
  output_to_file: "implementation_result.json"
```

**Available Tools**:
- `Write`: Create new files
- `Edit`: Modify existing files
- `Read`: Read file contents
- `Bash`: Execute shell commands
- `Search`: Search across files
- `Glob`: Find files by pattern
- `Grep`: Search file contents

**Key Features**:
- Full file system access within workspace
- Shell command execution
- Session management for continuity
- Comprehensive error handling
- Cost tracking and telemetry

### Claude Smart

**Type**: `claude_smart`  
**Purpose**: Intelligent preset-based Claude configuration with environment awareness

```yaml
- name: "smart_analysis"
  type: "claude_smart"
  preset: "analysis"              # Preset configuration
  environment_aware: true         # Auto-detect from Mix.env
  
  # Optional overrides
  claude_options:
    max_turns: 10                 # Override preset default
  
  prompt:
    - type: "file"
      path: "pipelines/prompts/analysis/security_audit.md"
    - type: "file"
      path: "src/main.ex"
  
  output_to_file: "security_analysis.json"
```

**Available Presets**:
- `development`: Permissive settings, full tool access, verbose logging
- `production`: Restricted tools, optimized for safety and performance
- `analysis`: Read-only tools, optimized for code analysis
- `chat`: Simple conversation mode, basic tools

**Key Features**:
- Automatic configuration based on environment
- Preset-specific optimizations
- Simplified configuration
- Intelligent defaults

### Claude Session

**Type**: `claude_session`  
**Purpose**: Maintain stateful conversations across multiple interactions

```yaml
- name: "tutoring_session"
  type: "claude_session"
  
  session_config:
    session_name: "elixir_tutorial"
    persist: true                 # Save session state
    continue_on_restart: true     # Resume after failures
    checkpoint_frequency: 5       # Save every 5 turns
    max_turns: 100               # Extended conversation
    description: "Interactive Elixir tutoring session"
  
  claude_options:
    allowed_tools: ["Write", "Read", "Bash"]
    output_format: "text"
  
  prompt:
    - type: "static"
      content: "Let's continue our Elixir tutorial"
    - type: "session_context"
      session_id: "elixir_tutorial"
      include_last_n: 10          # Include last 10 messages
  
  output_to_file: "session_transcript.md"
```

**Key Features**:
- Conversation state persistence
- Automatic checkpointing
- Session recovery after failures
- Context window management
- Multi-turn conversations

**Use Cases**:
- Interactive tutorials
- Long-running development tasks
- Iterative refinement processes
- Conversational workflows

### Claude Extract

**Type**: `claude_extract`  
**Purpose**: Advanced content extraction and post-processing

```yaml
- name: "extract_insights"
  type: "claude_extract"
  preset: "analysis"
  
  extraction_config:
    use_content_extractor: true
    format: "structured"          # Output format
    post_processing:
      - "extract_code_blocks"
      - "extract_recommendations"
      - "extract_key_points"
      - "extract_links"
    max_summary_length: 2000
    include_metadata: true
  
  claude_options:
    max_turns: 5
    allowed_tools: ["Read"]
  
  prompt:
    - type: "static"
      content: "Analyze this codebase and extract key insights"
    - type: "file"
      path: "src/"
  
  output_to_file: "extracted_insights.json"
```

**Format Options**:
- `text`: Plain text extraction
- `json`: Structured JSON output
- `structured`: Organized sections
- `summary`: Condensed summary
- `markdown`: Formatted markdown

**Post-Processing Options**:
- `extract_code_blocks`: Extract code snippets
- `extract_recommendations`: Pull out suggestions
- `extract_key_points`: Identify main points
- `extract_links`: Extract URLs and references
- `extract_entities`: Named entity extraction

### Claude Batch

**Type**: `claude_batch`  
**Purpose**: Process multiple tasks in parallel

```yaml
- name: "batch_code_review"
  type: "claude_batch"
  
  batch_config:
    max_parallel: 3               # Concurrent executions
    timeout_per_task: 300         # 5 minutes per task
    consolidate_results: true     # Merge all results
  
  tasks:
    - id: "review_backend"
      prompt:
        - type: "static"
          content: "Review the backend code"
        - type: "file"
          path: "backend/src/"
      output_to_file: "backend_review.json"
      
    - id: "review_frontend"
      prompt:
        - type: "static"
          content: "Review the frontend code"
        - type: "file"
          path: "frontend/src/"
      output_to_file: "frontend_review.json"
      
    - id: "review_tests"
      prompt:
        - type: "static"
          content: "Review test coverage and quality"
        - type: "file"
          path: "test/"
      output_to_file: "test_review.json"
```

**Key Features**:
- Parallel task execution
- Independent task configuration
- Result consolidation
- Load balancing
- Per-task timeouts

### Claude Robust

**Type**: `claude_robust`  
**Purpose**: Enterprise-grade error handling and retry logic

```yaml
- name: "critical_deployment"
  type: "claude_robust"
  
  retry_config:
    max_retries: 5
    backoff_strategy: "exponential" # Exponential backoff
    retry_conditions:
      - "timeout"
      - "rate_limit"
      - "api_error"
    fallback_action: "simplified_prompt"
  
  claude_options:
    max_turns: 30
    allowed_tools: ["Write", "Edit", "Read", "Bash"]
    timeout_ms: 60000             # 1 minute timeout
  
  prompt:
    - type: "file"
      path: "pipelines/prompts/deployment/production_deploy.md"
    - type: "previous_response"
      step: "deployment_plan"
  
  output_to_file: "deployment_result.json"
```

**Retry Strategies**:
- `linear`: Fixed delay between retries
- `exponential`: Exponentially increasing delays

**Fallback Actions**:
- `simplified_prompt`: Retry with simpler instructions
- `mock_response`: Return mock data
- `skip`: Skip the step
- `fail`: Fail the pipeline

### Parallel Claude

**Type**: `parallel_claude`  
**Purpose**: Execute multiple Claude instances simultaneously

```yaml
- name: "parallel_implementation"
  type: "parallel_claude"
  
  parallel_tasks:
    - id: "api_endpoints"
      claude_options:
        max_turns: 20
        allowed_tools: ["Write", "Edit", "Read"]
        cwd: "./workspace/api"
      prompt:
        - type: "static"
          content: "Implement the REST API endpoints"
        - type: "previous_response"
          step: "api_design"
      output_to_file: "api_implementation.json"
    
    - id: "database_schema"
      claude_options:
        max_turns: 15
        allowed_tools: ["Write", "Edit"]
        cwd: "./workspace/database"
      prompt:
        - type: "static"
          content: "Create the database schema"
        - type: "previous_response"
          step: "data_model"
      output_to_file: "db_implementation.json"
    
    - id: "test_suite"
      claude_options:
        max_turns: 25
        allowed_tools: ["Write", "Read", "Bash"]
        cwd: "./workspace/tests"
      prompt:
        - type: "static"
          content: "Write comprehensive tests"
      output_to_file: "test_implementation.json"
```

**Key Features**:
- True parallel execution
- Independent workspaces
- Task isolation
- Result aggregation
- Resource management

### Gemini Instructor

**Type**: `gemini_instructor`  
**Purpose**: Structured output generation with schema validation

```yaml
- name: "generate_api_spec"
  type: "gemini_instructor"
  
  model: "gemini-2.5-flash"
  validation_mode: "strict"       # Strict schema enforcement
  
  schema:
    type: "object"
    required: ["endpoints", "models", "authentication"]
    properties:
      endpoints:
        type: "array"
        items:
          type: "object"
          required: ["method", "path", "description"]
          properties:
            method:
              type: "string"
              enum: ["GET", "POST", "PUT", "DELETE"]
            path:
              type: "string"
              pattern: "^/api/.*"
            description:
              type: "string"
      models:
        type: "object"
      authentication:
        type: "object"
        required: ["type", "endpoints"]
  
  prompt:
    - type: "static"
      content: "Generate OpenAPI specification for this service"
    - type: "file"
      path: "docs/api_requirements.md"
  
  output_to_file: "api_specification.json"
```

**Key Features**:
- Guaranteed structured output
- Schema validation
- Type safety
- Integration with InstructorLite
- JSON Schema support

## Control Flow Steps

### Pipeline

**Type**: `pipeline`  
**Purpose**: Execute another pipeline as a step (recursive composition)

```yaml
- name: "data_processing"
  type: "pipeline"
  
  # Option 1: External file
  pipeline_file: "./pipelines/data_processor.yaml"
  
  # Option 2: Registry reference (future)
  # pipeline_ref: "common/data_processor"
  
  # Option 3: Inline definition
  # pipeline:
  #   name: "inline_processor"
  #   steps: [...]
  
  # Input mapping
  inputs:
    raw_data: "{{steps.extract.result}}"
    config: "{{workflow.processing_config}}"
    mode: "production"
  
  # Output extraction
  outputs:
    - "processed_data"            # Simple extraction
    - path: "metrics.accuracy"    # Path extraction
      as: "accuracy_score"
    - path: "report.summary"
      as: "summary_text"
  
  # Configuration
  config:
    inherit_context: true         # Pass parent context
    workspace_dir: "./nested/data_processing"
    timeout_seconds: 600
    max_depth: 5                  # Nesting limit
    enable_tracing: true
```

**Key Features**:
- Pipeline composition and modularity
- Context isolation
- Input/output mapping
- Safety limits (depth, memory, time)
- Circular dependency detection

**Use Cases**:
- Reusable workflows
- Complex multi-stage processing
- Modular architecture
- Testing pipeline components

### For Loop

**Type**: `for_loop`  
**Purpose**: Iterate over collections with optional parallelization

```yaml
- name: "process_files"
  type: "for_loop"
  
  iterator: "file"                # Loop variable name
  data_source: "{{steps.scan.files}}" # Array to iterate
  
  # Parallel execution
  parallel: true
  max_parallel: 5                 # Concurrent limit
  
  # Error handling
  break_on_error: false           # Continue on errors
  
  # Loop body
  steps:
    - name: "analyze_file"
      type: "claude"
      prompt:
        - type: "static"
          content: "Analyze this file:"
        - type: "static"
          content: "{{loop.file.path}}"
      output_to_file: "analysis_{{loop.file.name}}.json"
    
    - name: "update_progress"
      type: "set_variable"
      variables:
        processed_count: "{{state.processed_count + 1}}"
```

**Variable Access**:
- `{{loop.variable}}`: Current item
- `{{loop.index}}`: Current index (0-based)
- `{{loop.parent.variable}}`: Parent loop variable
- `{{loop.is_first}}`: Boolean first iteration
- `{{loop.is_last}}`: Boolean last iteration

**Data Sources**:
- Arrays from previous steps
- Static arrays
- File listings
- Query results

### While Loop

**Type**: `while_loop`  
**Purpose**: Repeat steps until condition is met

```yaml
- name: "optimize_until_passing"
  type: "while_loop"
  
  condition: "{{steps.test.score < 90}}"
  
  # Safety limits
  max_iterations: 10
  timeout_seconds: 1800           # 30 minutes total
  
  # Loop body
  steps:
    - name: "optimize"
      type: "claude"
      prompt:
        - type: "static"
          content: "Improve the code to increase test score"
        - type: "previous_response"
          step: "test"
          extract: "failures"
      
    - name: "test"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Run tests and calculate score"
      output_schema:
        type: "object"
        required: ["score", "failures"]
```

**Condition Expressions**:
- Comparison operators: `==`, `!=`, `>`, `<`, `>=`, `<=`
- Boolean operators: `and`, `or`, `not`
- String operations: `contains`, `matches`
- Null checks: `exists`, `empty`

**Safety Features**:
- Maximum iteration limit
- Total timeout protection
- Infinite loop detection
- Memory usage monitoring

### Switch/Case

**Type**: `switch`  
**Purpose**: Branch execution based on values

```yaml
- name: "handle_by_type"
  type: "switch"
  
  expression: "{{steps.detect.file_type}}"
  
  cases:
    "python":
      - name: "analyze_python"
        type: "claude"
        prompt:
          - type: "static"
            content: "Analyze Python code"
          
    "javascript":
      - name: "analyze_js"
        type: "claude"
        prompt:
          - type: "static"
            content: "Analyze JavaScript code"
            
    "markdown":
      - name: "process_docs"
        type: "gemini"
        prompt:
          - type: "static"
            content: "Process documentation"
  
  default:
    - name: "generic_analysis"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Perform generic analysis"
```

**Features**:
- Value-based branching
- Multiple steps per case
- Default fallback
- Expression evaluation
- Pattern matching support

## Data & File Operations

### Data Transform

**Type**: `data_transform`  
**Purpose**: Transform and manipulate structured data

```yaml
- name: "process_results"
  type: "data_transform"
  
  input_source: "{{steps.analysis.results}}"
  
  operations:
    # Filter operation
    - operation: "filter"
      field: "items"
      condition: "score > 80 and category == 'critical'"
    
    # Map transformation
    - operation: "map"
      field: "items"
      expression: |
        {
          "id": item.id,
          "score": item.score * 100,
          "priority": item.score > 90 ? "high" : "normal"
        }
    
    # Aggregation
    - operation: "aggregate"
      field: "items"
      function: "average"
      group_by: "category"
    
    # Join with another dataset
    - operation: "join"
      left_field: "items"
      right_source: "{{steps.metadata.items}}"
      join_key: "id"
      join_type: "left"
    
    # Sort results
    - operation: "sort"
      field: "items"
      by: "score"
      order: "desc"
  
  output_field: "processed_results"
  output_to_file: "transformed_data.json"
```

**Available Operations**:
- `filter`: Filter items by condition
- `map`: Transform each item
- `aggregate`: Calculate statistics
- `join`: Combine datasets
- `group_by`: Group items
- `sort`: Order items
- `unique`: Remove duplicates
- `flatten`: Flatten nested arrays

**Aggregate Functions**:
- `sum`, `average`, `min`, `max`
- `count`, `count_distinct`
- `std_dev`, `variance`

### File Operations

**Type**: `file_ops`  
**Purpose**: Manipulate files and directories

```yaml
- name: "organize_outputs"
  type: "file_ops"
  
  # Copy files
  operation: "copy"
  source: 
    - "./workspace/src/*.py"
    - "./workspace/tests/*.py"
  destination: "./output/python_files/"
  
  # Alternative operations:
  
  # Move files
  # operation: "move"
  # source: "./temp/*"
  # destination: "./processed/"
  
  # Delete files
  # operation: "delete"
  # files: ["./temp/*.tmp", "./cache/*"]
  
  # Validate files exist
  # operation: "validate"
  # files:
  #   - path: "./config/app.yaml"
  #     must_exist: true
  #     min_size: 100
  #   - path: "./output/"
  #     must_be_dir: true
  
  # List files
  # operation: "list"
  # path: "./workspace"
  # pattern: "**/*.py"
  # recursive: true
  
  # Convert formats
  # operation: "convert"
  # source: "./data.csv"
  # destination: "./data.json"
  # format: "csv_to_json"
```

**Supported Operations**:
- `copy`: Duplicate files/directories
- `move`: Relocate files/directories
- `delete`: Remove files/directories
- `validate`: Check file properties
- `list`: Directory listing
- `convert`: Format conversion

**Format Conversions**:
- `csv_to_json`, `json_to_csv`
- `yaml_to_json`, `json_to_yaml`
- `xml_to_json`, `json_to_xml`

### Codebase Query

**Type**: `codebase_query`  
**Purpose**: Intelligent codebase analysis and file discovery

```yaml
- name: "analyze_project"
  type: "codebase_query"
  
  codebase_context: true          # Include project metadata
  
  queries:
    # Find specific file types
    source_files:
      find_files:
        - type: "source"
        - pattern: "lib/**/*.ex"
        - exclude_tests: true
        - modified_since: "2024-01-01"
    
    # Find test files related to source
    test_files:
      find_files:
        - related_to: "lib/user.ex"
        - type: "test"
    
    # Find functions in files
    public_functions:
      find_functions:
        - in_file: "lib/user.ex"
        - public_only: true
        - with_annotation: "@doc"
    
    # Analyze dependencies
    dependencies:
      find_dependencies:
        - for_file: "lib/user.ex"
        - include_transitive: false
    
    # Find dependent files
    dependents:
      find_dependents:
        - of_file: "lib/user.ex"
        - include_tests: true
    
    # Project information
    project_info:
      get_project_type: true
      get_dependencies: true
      get_git_status: true
  
  output_to_file: "codebase_analysis.json"
```

**Query Types**:
- `find_files`: Locate files by criteria
- `find_functions`: Extract function definitions
- `find_dependencies`: Analyze imports/requires
- `find_dependents`: Reverse dependency lookup
- `get_project_type`: Detect project framework
- `get_git_status`: Git repository information

**Supported Languages**:
- Elixir
- Python
- JavaScript/TypeScript
- Go
- Rust

## State Management

### Set Variable

**Type**: `set_variable`  
**Purpose**: Manage workflow state and variables

```yaml
- name: "initialize_state"
  type: "set_variable"
  
  variables:
    # Static values
    iteration_count: 0
    max_retries: 3
    results: []
    
    # Computed values
    total_files: "{{length(steps.scan.files)}}"
    start_time: "{{now()}}"
    
    # Complex expressions
    threshold: "{{workflow.base_threshold * 1.5}}"
    is_production: "{{environment.mode == 'production'}}"
  
  scope: "global"                 # Variable scope
```

**Variable Scopes**:
- `global`: Available to all steps
- `local`: Current step only
- `session`: Persists across runs

**Supported Operations**:
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- String concatenation
- Array operations
- Boolean logic
- Function calls

### Checkpoint

**Type**: `checkpoint`  
**Purpose**: Save workflow state for recovery

```yaml
- name: "save_progress"
  type: "checkpoint"
  
  state:
    completed_steps: "{{state.completed_steps}}"
    processed_items: "{{state.processed_items}}"
    current_phase: "implementation"
    metrics:
      files_processed: "{{state.file_count}}"
      errors_found: "{{state.error_count}}"
      completion_percentage: "{{state.progress}}"
  
  checkpoint_name: "phase_2_complete"
  include_workspace: true         # Save workspace files
  compress: true                  # Compress checkpoint
```

**Features**:
- State persistence
- Workspace backup
- Compression support
- Automatic recovery
- Checkpoint management

**Use Cases**:
- Long-running workflows
- Failure recovery
- Progress tracking
- Partial execution

## Step Type Selection Guide

| Task Type | Recommended Step Type | Key Consideration |
|-----------|----------------------|-------------------|
| Planning & Analysis | `gemini` | Best for reasoning and structure |
| Code Implementation | `claude` | Full tool access for file manipulation |
| Quick Analysis | `claude_smart` | Preset configurations |
| Long Conversations | `claude_session` | State persistence |
| Content Extraction | `claude_extract` | Structured output processing |
| Parallel Tasks | `claude_batch` or `parallel_claude` | Concurrent execution |
| Critical Operations | `claude_robust` | Error recovery |
| Structured Output | `gemini_instructor` | Schema validation |
| Modular Workflows | `pipeline` | Composition and reuse |
| Iteration | `for_loop` or `while_loop` | Collection processing |
| Branching | `switch` | Value-based routing |
| Data Manipulation | `data_transform` | JSONPath operations |
| File Management | `file_ops` | File system operations |
| Code Analysis | `codebase_query` | Language-aware analysis |

This reference provides comprehensive documentation for all available step types in Pipeline YAML v2 format.