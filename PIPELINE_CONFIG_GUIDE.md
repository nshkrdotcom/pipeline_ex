# Pipeline Configuration Technical Guide

## Table of Contents

1. [Overview](#overview)
2. [Configuration File Structure](#configuration-file-structure)
3. [Workflow Section](#workflow-section)
4. [Defaults Section](#defaults-section)
5. [Steps Section](#steps-section)
6. [Step Types](#step-types)
7. [Prompt Templates](#prompt-templates)
8. [Token Budget Management](#token-budget-management)
9. [Claude Options](#claude-options)
10. [Advanced Features](#advanced-features)
11. [Complete Examples](#complete-examples)
12. [Best Practices](#best-practices)
13. [Troubleshooting](#troubleshooting)

## Overview

Pipeline configuration files are written in YAML format and define the complete workflow for orchestrating Gemini (planning/decision-making) and Claude (code execution) to accomplish complex tasks.

### Basic Structure

```yaml
workflow:
  name: "string"                    # Required: Workflow identifier
  checkpoint_enabled: boolean       # Optional: Enable state saving
  workspace_dir: "string"          # Optional: Claude's sandbox directory
  checkpoint_dir: "string"         # Optional: Checkpoint storage location
  
  defaults:                        # Optional: Default settings
    gemini_model: "string"         # Gemini model to use
    gemini_token_budget: {}        # Token limits for Gemini
    claude_output_format: "string" # Output format for Claude
    output_dir: "string"          # Where to save outputs
    
  gemini_functions: {}            # Optional: Function definitions
  
  steps: []                       # Required: List of workflow steps
```

## Configuration File Structure

### Root Level

The configuration file must have a single root key `workflow`:

```yaml
workflow:
  # All configuration goes here
```

### Required Fields

- `workflow.name`: Unique identifier for the workflow
- `workflow.steps`: Array of step definitions

### Optional Fields

- `workflow.checkpoint_enabled`: Enable workflow state saving (default: false)
- `workflow.workspace_dir`: Directory for Claude's file operations (default: "./workspace")
- `workflow.checkpoint_dir`: Where to save checkpoints (default: "./checkpoints")
- `workflow.defaults`: Default settings for all steps

## Workflow Section

The workflow section contains global settings:

```yaml
workflow:
  name: "data_processor"
  checkpoint_enabled: true
  workspace_dir: "./workspace"
  checkpoint_dir: "./checkpoints"
```

### Field Details

#### `name` (string, required)
- Identifies the workflow in logs and outputs
- Used in output directory naming
- Should be descriptive and unique

#### `checkpoint_enabled` (boolean, optional)
- When `true`, saves state after each step
- Allows resuming interrupted workflows
- Checkpoints include step results and timestamps

#### `workspace_dir` (string, optional)
- Directory where Claude performs file operations
- Created automatically if it doesn't exist
- Provides sandboxing for Claude's file access
- Default: "./workspace"

#### `checkpoint_dir` (string, optional)
- Directory for storing checkpoint files
- Created automatically if needed
- Default: "./checkpoints"

## Defaults Section

Sets default values for all steps:

```yaml
defaults:
  gemini_model: "gemini-2.5-flash-lite-preview-06-17"
  gemini_token_budget:
    max_output_tokens: 2048
    temperature: 0.7
    top_p: 0.95
    top_k: 40
  claude_output_format: "json"
  output_dir: "./outputs/my_workflow"
```

### Available Defaults

#### `gemini_model` (string)
Available models:
- `"gemini-2.5-flash"` - Fast, efficient model
- `"gemini-2.5-flash-lite-preview-06-17"` - Lightweight version
- `"gemini-2.5-pro"` - Most capable model
- `"gemini-2.0-flash"` - Previous generation

#### `gemini_token_budget` (object)
Default token limits for Gemini:
- `max_output_tokens`: Maximum response length (256-8192)
- `temperature`: Randomness control (0.0-1.0)
- `top_p`: Nucleus sampling (0.0-1.0)
- `top_k`: Top-k sampling (1-40)

#### `claude_output_format` (string)
Default output format for Claude:
- `"json"` - Structured JSON output
- `"text"` - Plain text output
- `"stream-json"` - Streaming JSON

#### `output_dir` (string)
Default directory for saving step outputs.

## Steps Section

The heart of the configuration - defines the workflow sequence:

```yaml
steps:
  - name: "analyze"
    type: "gemini"
    role: "brain"
    # ... step configuration
    
  - name: "implement"
    type: "claude"
    role: "muscle"
    # ... step configuration
```

### Step Fields

#### Common Fields (all step types)

##### `name` (string, required)
- Unique identifier for the step
- Referenced by other steps via `previous_response`
- Used in output filenames

##### `type` (string, required)
Options:
- `"gemini"` - Gemini AI step
- `"claude"` - Claude AI step
- `"parallel_claude"` - Multiple Claude instances

##### `role` (string, optional)
- `"brain"` - Decision-making role (typically Gemini)
- `"muscle"` - Execution role (typically Claude)
- Used for documentation/clarity

##### `condition` (string, optional)
Skip step based on previous results:
```yaml
condition: "previous_step.field_name"
```

##### `output_to_file` (string, optional)
Save step output to specified file:
```yaml
output_to_file: "analysis_result.json"
```

## Step Types

### 1. Gemini Step

For planning, analysis, and decision-making:

```yaml
- name: "plan_implementation"
  type: "gemini"
  role: "brain"
  model: "gemini-2.5-flash"  # Override default
  token_budget:
    max_output_tokens: 4096
    temperature: 0.5
  prompt:
    - type: "static"
      content: "Create an implementation plan..."
  output_to_file: "plan.json"
```

#### Gemini-Specific Fields

##### `model` (string, optional)
Override the default Gemini model for this step.

##### `token_budget` (object, optional)
Override default token limits:
```yaml
token_budget:
  max_output_tokens: 8192  # More tokens for detailed output
  temperature: 0.3         # Lower for focused responses
  top_p: 0.9              # Adjust nucleus sampling
  top_k: 20               # Limit token choices
```

##### `functions` (array, optional)
Enable function calling:
```yaml
functions:
  - "evaluate_code"
  - "generate_tests"
```

### 2. Claude Step

For code execution and file manipulation:

```yaml
- name: "implement_feature"
  type: "claude"
  role: "muscle"
  claude_options:
    print: true
    max_turns: 15
    allowed_tools: ["Write", "Edit", "Read", "Bash"]
    output_format: "json"
    cwd: "./workspace"
  prompt:
    - type: "static"
      content: "Implement the following..."
  output_to_file: "implementation.json"
```

#### Claude-Specific Fields

##### `claude_options` (object, optional)
Configuration for Claude CLI:

```yaml
claude_options:
  print: true                    # Non-interactive mode
  output_format: "json"          # Response format
  max_turns: 20                  # Conversation limit
  allowed_tools: ["Write", "Edit", "Read", "Bash", "Search"]
  verbose: true                  # Detailed logging
  append_system_prompt: "Focus on clean code"
  cwd: "./workspace/project"     # Working directory
```

### 3. Parallel Claude Step

Run multiple Claude instances simultaneously:

```yaml
- name: "parallel_development"
  type: "parallel_claude"
  parallel_tasks:
    - id: "backend"
      claude_options:
        max_turns: 15
        cwd: "./workspace/backend"
      prompt:
        - type: "static"
          content: "Implement REST API..."
      output_to_file: "backend.json"
      
    - id: "frontend"
      claude_options:
        max_turns: 15
        cwd: "./workspace/frontend"
      prompt:
        - type: "static"
          content: "Implement React UI..."
      output_to_file: "frontend.json"
```

#### Parallel-Specific Fields

##### `parallel_tasks` (array, required)
List of task definitions, each with:
- `id`: Unique task identifier
- `claude_options`: Task-specific Claude settings
- `prompt`: Task prompt configuration
- `output_to_file`: Task output file

## Prompt Templates

Prompts are built from components that can reference files and previous outputs:

### 1. Static Content

Fixed text content:

```yaml
prompt:
  - type: "static"
    content: |
      Analyze this requirement:
      - Feature A
      - Feature B
```

### 2. File Content

Load content from files:

```yaml
prompt:
  - type: "file"
    path: "requirements.txt"
  - type: "file"
    path: "src/main.py"
```

### 3. Previous Response

Reference output from earlier steps:

```yaml
prompt:
  - type: "static"
    content: "Based on the plan:"
  - type: "previous_response"
    step: "planning_step"
```

With field extraction:

```yaml
prompt:
  - type: "previous_response"
    step: "analysis_step"
    extract: "issues"  # Extract specific field from JSON
```

### 4. Complex Example

Combining all prompt types:

```yaml
prompt:
  - type: "static"
    content: "Project requirements:"
  - type: "file"
    path: "requirements.md"
  - type: "static"
    content: "\n\nPrevious analysis found these issues:"
  - type: "previous_response"
    step: "code_review"
    extract: "critical_issues"
  - type: "static"
    content: "\n\nPlease fix all critical issues."
```

## Token Budget Management

Fine-tune AI response lengths and quality:

### Understanding Token Budgets

```yaml
token_budget:
  max_output_tokens: 4096  # Response length limit
  temperature: 0.7         # Randomness (0=deterministic, 1=creative)
  top_p: 0.95             # Cumulative probability cutoff
  top_k: 40               # Consider top K tokens
```

### Common Configurations

#### Concise Analysis
```yaml
token_budget:
  max_output_tokens: 1024
  temperature: 0.5
```

#### Detailed Planning
```yaml
token_budget:
  max_output_tokens: 4096
  temperature: 0.7
```

#### Code Generation
```yaml
token_budget:
  max_output_tokens: 8192
  temperature: 0.3  # Lower for consistency
```

#### Creative Writing
```yaml
token_budget:
  max_output_tokens: 2048
  temperature: 0.9  # Higher for variety
```

## Claude Options

### Tool Configuration

Control which tools Claude can use:

```yaml
allowed_tools: ["Write", "Edit", "Read"]  # File operations only
allowed_tools: ["Write", "Edit", "Read", "Bash"]  # Include shell
allowed_tools: ["Write", "Edit", "Read", "Search", "Bash"]  # Full access
```

### Turn Limits

Set conversation length:

```yaml
max_turns: 5   # Quick tasks
max_turns: 15  # Standard implementation
max_turns: 30  # Complex projects
```

### Working Directory

Sandbox file operations:

```yaml
cwd: "./workspace"          # Default sandbox
cwd: "./workspace/backend"  # Project-specific
cwd: "/tmp/safe_dir"       # Absolute path
```

## Advanced Features

### 1. Conditional Execution

Skip steps based on conditions:

```yaml
steps:
  - name: "check_quality"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Review code quality. Set needs_fixes=true if issues found."
    
  - name: "fix_issues"
    type: "claude"
    condition: "check_quality.needs_fixes"  # Only runs if true
    prompt:
      - type: "static"
        content: "Fix the identified issues"
```

### 2. Function Calling

Define functions for Gemini:

```yaml
workflow:
  gemini_functions:
    evaluate_code:
      description: "Evaluate code quality and security"
      parameters:
        type: object
        properties:
          quality_score:
            type: integer
            description: "Score from 1-10"
          security_issues:
            type: array
            items:
              type: string
          needs_refactoring:
            type: boolean
        required: ["quality_score", "security_issues"]
    
  steps:
    - name: "code_review"
      type: "gemini"
      functions:
        - "evaluate_code"
      prompt:
        - type: "static"
          content: "Review this code and call evaluate_code function"
```

### 3. Dynamic Workflows

Build prompts from multiple sources:

```yaml
steps:
  - name: "gather_context"
    type: "gemini"
    prompt:
      - type: "file"
        path: "context/project.md"
      - type: "file" 
        path: "context/architecture.md"
      - type: "static"
        content: "Summarize the project context"
    
  - name: "generate_tasks"
    type: "gemini"
    prompt:
      - type: "previous_response"
        step: "gather_context"
      - type: "static"
        content: "Based on this context, generate implementation tasks"
    
  - name: "implement"
    type: "claude"
    prompt:
      - type: "previous_response"
        step: "generate_tasks"
      - type: "static"
        content: "Implement these tasks"
```

## Complete Examples

### Example 1: Code Review and Fix

```yaml
workflow:
  name: "code_reviewer"
  workspace_dir: "./workspace"
  
  defaults:
    gemini_model: "gemini-2.5-flash"
    output_dir: "./outputs/review"
    
  steps:
    - name: "analyze_code"
      type: "gemini"
      token_budget:
        max_output_tokens: 2048
        temperature: 0.3
      prompt:
        - type: "static"
          content: "Review this code for bugs, security issues, and style:"
        - type: "file"
          path: "src/main.py"
      output_to_file: "analysis.json"
      
    - name: "fix_issues"
      type: "claude"
      claude_options:
        max_turns: 10
        allowed_tools: ["Read", "Edit"]
        cwd: "./workspace"
      prompt:
        - type: "static"
          content: "Fix all issues identified in the review:"
        - type: "previous_response"
          step: "analyze_code"
      output_to_file: "fixes.json"
```

### Example 2: Full Application Development

```yaml
workflow:
  name: "app_builder"
  checkpoint_enabled: true
  workspace_dir: "./workspace"
  
  defaults:
    gemini_model: "gemini-2.5-flash"
    gemini_token_budget:
      max_output_tokens: 4096
      temperature: 0.7
    claude_output_format: "json"
    output_dir: "./outputs/app"
    
  gemini_functions:
    design_architecture:
      description: "Design application architecture"
      parameters:
        type: object
        properties:
          components:
            type: array
            items:
              type: object
              properties:
                name:
                  type: string
                type:
                  type: string
                  enum: ["frontend", "backend", "database", "service"]
                dependencies:
                  type: array
                  items:
                    type: string
    
  steps:
    - name: "design"
      type: "gemini"
      role: "brain"
      functions:
        - "design_architecture"
      prompt:
        - type: "file"
          path: "requirements.md"
        - type: "static"
          content: |
            Design a microservices architecture for these requirements.
            Call design_architecture with the component structure.
      output_to_file: "architecture.json"
      
    - name: "plan_implementation"
      type: "gemini"
      role: "brain"
      token_budget:
        max_output_tokens: 8192
      prompt:
        - type: "static"
          content: "Create detailed implementation instructions for each component:"
        - type: "previous_response"
          step: "design"
      output_to_file: "implementation_plan.json"
      
    - name: "implement_services"
      type: "parallel_claude"
      parallel_tasks:
        - id: "auth_service"
          claude_options:
            max_turns: 20
            allowed_tools: ["Write", "Edit", "Read", "Bash"]
            cwd: "./workspace/services/auth"
          prompt:
            - type: "static"
              content: "Implement the authentication service based on the plan:"
            - type: "previous_response"
              step: "plan_implementation"
              extract: "auth_service"
          output_to_file: "auth_implementation.json"
          
        - id: "api_gateway"
          claude_options:
            max_turns: 20
            allowed_tools: ["Write", "Edit", "Read", "Bash"]
            cwd: "./workspace/services/gateway"
          prompt:
            - type: "static"
              content: "Implement the API gateway based on the plan:"
            - type: "previous_response"
              step: "plan_implementation"
              extract: "api_gateway"
          output_to_file: "gateway_implementation.json"
          
        - id: "frontend"
          claude_options:
            max_turns: 25
            allowed_tools: ["Write", "Edit", "Read", "Bash"]
            cwd: "./workspace/frontend"
          prompt:
            - type: "static"
              content: "Implement the React frontend based on the plan:"
            - type: "previous_response"
              step: "plan_implementation"
              extract: "frontend"
          output_to_file: "frontend_implementation.json"
      
    - name: "integration_tests"
      type: "gemini"
      role: "brain"
      prompt:
        - type: "static"
          content: "Design integration tests for the implemented services:"
        - type: "previous_response"
          step: "implement_services"
      output_to_file: "test_plan.json"
      
    - name: "implement_tests"
      type: "claude"
      role: "muscle"
      claude_options:
        max_turns: 15
        allowed_tools: ["Write", "Read", "Bash"]
        cwd: "./workspace/tests"
      prompt:
        - type: "previous_response"
          step: "integration_tests"
        - type: "static"
          content: "Implement these integration tests"
      output_to_file: "tests_implementation.json"
      
    - name: "final_review"
      type: "gemini"
      role: "brain"
      token_budget:
        max_output_tokens: 2048
        temperature: 0.3
      prompt:
        - type: "static"
          content: |
            Review the complete implementation:
            1. Check if all requirements are met
            2. Identify any missing features
            3. Suggest improvements
            Set 'ready_for_deployment' to true if acceptable.
        - type: "previous_response"
          step: "implement_services"
      output_to_file: "final_review.json"
```

## Best Practices

### 1. Token Budget Optimization

- Start with conservative limits and increase as needed
- Use lower temperatures (0.1-0.3) for technical tasks
- Use higher temperatures (0.7-0.9) for creative tasks
- Monitor token usage in debug logs

### 2. Step Design

- Keep prompts focused on single responsibilities
- Use descriptive step names for easy reference
- Save outputs for all important steps
- Build complex prompts from simpler components

### 3. Error Handling

- Set appropriate `max_turns` for Claude tasks
- Use conditions to handle failure cases
- Include validation steps after implementation
- Review debug logs when issues occur

### 4. Workspace Management

- Use subdirectories for different components
- Set appropriate `cwd` in claude_options
- Keep workspace separate from project files
- Clean workspace between runs if needed

### 5. Prompt Engineering

- Be specific in instructions
- Provide examples when possible
- Use previous responses to maintain context
- Break complex tasks into smaller steps

## Troubleshooting

### Common Issues

#### 1. Claude Hits Turn Limit

```yaml
# Increase max_turns
claude_options:
  max_turns: 30  # Increase from default
```

#### 2. Gemini Response Truncated

```yaml
# Increase token limit
token_budget:
  max_output_tokens: 8192  # Maximum allowed
```

#### 3. Files Created in Wrong Location

```yaml
# Check workspace configuration
workflow:
  workspace_dir: "./workspace"
  
steps:
  - name: "implement"
    claude_options:
      cwd: "./workspace/project"  # Must be under workspace_dir
```

#### 4. Step References Not Found

```yaml
# Ensure step names match exactly
- name: "step_one"  # This exact name
  type: "gemini"
  
- name: "step_two"
  prompt:
    - type: "previous_response"
      step: "step_one"  # Must match exactly
```

#### 5. JSON Parsing Errors

```yaml
# Use appropriate output format
claude_options:
  output_format: "json"  # For structured data
  # or
  output_format: "text"  # For plain text
```

### Debug Techniques

1. **Check Debug Logs**
   ```bash
   python view_debug.py -l
   ```

2. **Verify File Creation**
   ```bash
   python view_debug.py -w
   ```

3. **Test Individual Steps**
   - Comment out later steps
   - Run pipeline partially
   - Check intermediate outputs

4. **Validate YAML Syntax**
   ```bash
   python -c "import yaml; yaml.safe_load(open('config.yaml'))"
   ```

## Schema Reference

### Complete Configuration Schema

```yaml
workflow:
  name: string                    # Required
  checkpoint_enabled: boolean     # Optional
  workspace_dir: string          # Optional
  checkpoint_dir: string         # Optional
  
  # NEW: Enhanced Claude authentication and environment configuration
  claude_auth:                   # Optional
    auto_check: boolean          # Verify auth before starting
    provider: enum["anthropic", "aws_bedrock", "google_vertex"]
    fallback_mock: boolean       # Use mocks if auth fails in dev
    diagnostics: boolean         # Run AuthChecker diagnostics
  
  environment:                   # Optional
    mode: enum["development", "production", "test"]
    debug_level: enum["basic", "detailed", "performance"]
    cost_alerts:
      enabled: boolean
      threshold_usd: float
      notify_on_exceed: boolean
  
  defaults:                      # Optional
    gemini_model: string
    gemini_token_budget:
      max_output_tokens: integer
      temperature: float
      top_p: float
      top_k: integer
    claude_output_format: enum["json", "text", "stream-json"]
    claude_preset: enum["development", "production", "analysis", "chat"]  # NEW
    output_dir: string
    
  gemini_functions:              # Optional
    function_name:
      description: string
      parameters: object         # JSON Schema
      
  steps:                         # Required
    - name: string               # Required
      type: enum["gemini", "claude", "parallel_claude", "claude_session", "claude_smart", "claude_extract", "claude_batch", "claude_robust"]  # Enhanced
      role: enum["brain", "muscle"]  # Optional
      condition: string          # Optional
      output_to_file: string     # Optional
      
      # For type: "gemini"
      model: string              # Optional
      token_budget: object       # Optional
      functions: array[string]   # Optional
      
      # For type: "claude" (Enhanced options)
      claude_options:            # Optional
        # Core Configuration
        max_turns: integer
        output_format: enum["text", "json", "stream_json"]
        verbose: boolean
        
        # Tool Management
        allowed_tools: array[string]
        disallowed_tools: array[string]
        
        # System Prompts
        system_prompt: string
        append_system_prompt: string
        
        # Working Environment
        cwd: string
        
        # Permission Management (Future: MCP Support)
        permission_mode: enum["default", "accept_edits", "bypass_permissions", "plan"]
        permission_prompt_tool: string
        
        # Advanced Features (Future)
        mcp_config: string
        
        # Session Management
        session_id: string
        resume_session: boolean
        
        # Performance & Reliability
        retry_config:
          max_retries: integer
          backoff_strategy: enum["linear", "exponential"]
          retry_on: array[string]
        timeout_ms: integer
        
        # Debug & Monitoring
        debug_mode: boolean
        telemetry_enabled: boolean
        cost_tracking: boolean
      
      # NEW: For type: "claude_smart" (Using OptionBuilder presets)
      preset: enum["development", "production", "analysis", "chat"]
      environment_aware: boolean
      
      # NEW: For type: "claude_extract" (Enhanced content processing)
      extraction_config:
        use_content_extractor: boolean
        format: enum["text", "json", "structured", "summary", "markdown"]
        post_processing: array[string]
        max_summary_length: integer
        include_metadata: boolean
      
      # NEW: For type: "claude_session" (Session management)
      session_config:
        persist: boolean
        session_name: string
        continue_on_restart: boolean
        checkpoint_frequency: integer
        description: string
      
      # NEW: For type: "claude_batch" (Batch processing)
      batch_config:
        max_parallel: integer
        timeout_per_task: integer
        consolidate_results: boolean
      tasks: array
        - file: string
          prompt: string
      
      # NEW: For type: "claude_robust" (Error recovery)
      retry_config:
        max_retries: integer
        backoff_strategy: enum["linear", "exponential"]
        retry_conditions: array[string]
        fallback_action: string
      
      # For type: "parallel_claude"
      parallel_tasks: array      # Required
        - id: string
          claude_options: object
          prompt: array
          output_to_file: string
          
      prompt: array              # Required (except parallel_claude)
        - type: enum["static", "file", "previous_response", "session_context", "claude_continue"]  # Enhanced
          # For type: "static"
          content: string
          # For type: "file"
          path: string
          # For type: "previous_response"
          step: string
          extract: string        # Optional
          extract_with: enum["content_extractor"]  # NEW: Use ContentExtractor
          summary: boolean       # NEW: Summarize content
          max_length: integer    # NEW: Limit extracted content length
          # NEW: For type: "session_context"
          session_id: string
          include_last_n: integer
          # NEW: For type: "claude_continue"
          new_prompt: string
```

### Enhanced Claude Options Reference

The enhanced `claude_options` section now supports the full feature set of the Claude Code SDK:

#### Basic Configuration
- `max_turns`: Maximum conversation turns (integer)
- `output_format`: Response format - "text", "json", or "stream_json"
- `verbose`: Enable detailed logging (boolean)

#### Tool Management  
- `allowed_tools`: List of permitted tool names (array of strings)
- `disallowed_tools`: List of explicitly forbidden tools (array of strings)

#### System Prompts
- `system_prompt`: Custom system prompt override (string)
- `append_system_prompt`: Additional system prompt to append (string)

#### Working Environment
- `cwd`: Working directory for Claude operations (string)

#### Session Management
- `session_id`: Explicit session identifier for continuation (string)
- `resume_session`: Automatically resume existing session if available (boolean)

#### Performance & Reliability
- `retry_config`: Retry mechanism configuration (object)
  - `max_retries`: Maximum number of retry attempts (integer)
  - `backoff_strategy`: "linear" or "exponential" backoff (string)
  - `retry_on`: List of conditions that trigger retries (array)
- `timeout_ms`: Request timeout in milliseconds (integer)

#### Monitoring & Debug
- `debug_mode`: Enable debug output and diagnostics (boolean)
- `telemetry_enabled`: Enable performance telemetry (boolean)
- `cost_tracking`: Track and report API costs (boolean)

### Smart Configuration Presets

The new `claude_smart` step type supports OptionBuilder presets:

- **`development`**: Permissive settings, verbose logging, full tool access
- **`production`**: Restricted settings, minimal tools, safe defaults  
- **`analysis`**: Read-only tools, optimized for code analysis
- **`chat`**: Simple conversation settings, basic tools

### Future-Ready Features

The schema includes placeholders for planned features:

#### MCP Integration
- `mcp_config`: Path to MCP server configuration file
- `permission_prompt_tool`: Tool for handling permission prompts
- `permission_mode`: Permission handling strategy

#### Advanced Content Processing
- Content extraction with multiple format options
- Post-processing pipeline support
- Metadata inclusion and summarization

This guide provides comprehensive documentation for creating and managing pipeline configuration files. Use it as a reference when building your own AI-orchestrated workflows.
