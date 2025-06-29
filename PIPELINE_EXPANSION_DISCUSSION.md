# Pipeline YAML Format Expansion Discussion

## Overview

Based on our review of the Claude Code SDK comprehensive manual and the implementation of the generic tool system, this document outlines how we should expand the pipeline YAML format to leverage all capabilities of both the Claude SDK and our new tool system.

## Current Pipeline YAML Format

Our current format supports basic orchestration:

```yaml
workflow:
  name: "Pipeline Name"
  defaults:
    gemini_model: "gemini-2.5-flash"
    output_dir: "./outputs"
  steps:
    - name: "step_name"
      type: "gemini" | "claude" | "parallel_claude"
      prompt: "text" | [prompt_parts]
      functions: ["tool_names"]  # NEW: Function calling
      claude_options: {...}
      output_to_file: "filename"
```

## Proposed Expansion

### 1. Enhanced Claude Integration (Based on SDK Manual)

```yaml
workflow:
  name: "Advanced Pipeline"
  defaults:
    gemini_model: "gemini-2.5-flash"
    claude_model: "claude-opus-4-20250514"  # NEW
    output_dir: "./outputs"
    
  # NEW: Claude global configuration
  claude_config:
    max_turns: 10
    permission_mode: "accept_edits"  # default, accept_edits, bypass_permissions, plan
    system_prompt: "You are an expert developer assistant"
    output_format: "stream_json"  # text, json, stream_json
    verbose: true
    
  # NEW: MCP (Model Context Protocol) configuration
  mcp_config:
    servers:
      filesystem:
        command: "npx"
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/allowed/path"]
      github:
        command: "npx"
        args: ["-y", "@modelcontextprotocol/server-github"]
        env:
          GITHUB_TOKEN: "${GITHUB_TOKEN}"
    
  # NEW: Tool system configuration
  tool_config:
    auto_discover: true
    allowed_tools: ["get_wan_ip", "system_info"]
    platform_filter: ["ubuntu-24.04", "linux"]
    
  steps:
    # Enhanced Claude step
    - name: "advanced_claude"
      type: "claude"
      prompt: "Analyze and refactor this code"
      claude_options:
        max_turns: 5
        permission_mode: "plan"
        allowed_tools: ["Read", "Write", "Bash"]
        disallowed_tools: ["NetworkAccess"]
        mcp_tools: ["mcp__filesystem__read", "mcp__github__search"]
        cwd: "./src"
        executable: "node"
        executable_args: ["--max-memory=4096"]
        append_system_prompt: "Focus on security and performance"
        
    # Enhanced Gemini step with function calling
    - name: "gemini_with_tools"
      type: "gemini"
      prompt: "Analyze system and gather information"
      functions: ["get_wan_ip", "system_info", "file_search"]
      tool_options:
        timeout: 30
        platform: "ubuntu-24.04"
        
    # NEW: Session management
    - name: "continue_conversation"
      type: "claude_continue"
      session_ref: "advanced_claude"  # Reference to previous step
      prompt: "Now implement the suggestions"
      
    # NEW: Parallel tool execution
    - name: "parallel_analysis"
      type: "parallel_tools"
      tools:
        - name: "get_wan_ip"
          args: {"service": "ipify"}
        - name: "system_info"
          args: {"include_processes": true}
        - name: "file_search"
          args: {"pattern": "*.ex", "directory": "./lib"}
```

### 2. Advanced Workflow Control

```yaml
workflow:
  name: "Complex Workflow"
  
  # NEW: Conditional execution
  conditions:
    is_production: "${ENV} == 'production'"
    has_tests: "file_exists('./test')"
    
  # NEW: Error handling
  error_handling:
    strategy: "continue" | "stop" | "retry"
    max_retries: 3
    retry_delay: 1000
    
  # NEW: Parallel execution groups
  parallel_groups:
    - name: "analysis_group"
      max_concurrency: 3
      steps: ["analyze_code", "check_security", "run_tests"]
      
  steps:
    - name: "conditional_step"
      type: "gemini"
      condition: "is_production"
      prompt: "Production-specific analysis"
      
    - name: "retry_step"
      type: "claude"
      retry_policy:
        max_attempts: 3
        backoff: "exponential"
      prompt: "Flaky operation"
      
    - name: "timeout_step"
      type: "claude"
      timeout: 30000  # 30 seconds
      prompt: "Quick operation"
```

### 3. Advanced Tool System Integration

```yaml
workflow:
  name: "Tool-Heavy Pipeline"
  
  # NEW: Custom tool definitions inline
  custom_tools:
    database_query:
      description: "Query the application database"
      parameters:
        type: "object"
        properties:
          query: {type: "string", description: "SQL query to execute"}
          timeout: {type: "integer", default: 30}
        required: ["query"]
      implementation: "Pipeline.Tools.Implementations.Database.Postgres"
      platforms: ["linux", "ubuntu-24.04"]
      
  # NEW: Tool validation and safety
  tool_safety:
    dangerous_patterns: ["rm -rf", "sudo", "drop table"]
    sandbox_mode: true
    allowed_paths: ["/project", "/tmp"]
    
  steps:
    - name: "custom_tool_usage"
      type: "gemini"
      prompt: "Analyze database performance"
      functions: ["database_query"]
      tool_options:
        sandbox: true
        validate_args: true
        
    - name: "tool_composition"
      type: "gemini"
      prompt: "Get system overview"
      functions: ["get_wan_ip", "system_info", "database_query"]
      tool_execution:
        strategy: "sequential" | "parallel"
        on_error: "continue" | "stop"
```

### 4. Session and State Management

```yaml
workflow:
  name: "Stateful Pipeline"
  
  # NEW: Session configuration
  session_config:
    persist_sessions: true
    session_timeout: 3600000  # 1 hour
    workspace_isolation: true
    
  # NEW: State management
  state:
    variables:
      project_path: "./src"
      analysis_results: null
    persistence:
      type: "file" | "memory" | "database"
      location: "./pipeline_state.json"
      
  steps:
    - name: "analyze"
      type: "gemini"
      prompt: "Analyze code in ${project_path}"
      output_to_state: "analysis_results"
      
    - name: "implement"
      type: "claude_continue"
      session_ref: "analyze"
      prompt: "Implement fixes based on: ${state.analysis_results}"
      
    - name: "validate"
      type: "claude"
      condition: "state.analysis_results != null"
      prompt: "Validate the implemented changes"
```

### 5. Security and Permissions

```yaml
workflow:
  name: "Secure Pipeline"
  
  # NEW: Security configuration
  security:
    permission_model: "strict" | "permissive" | "custom"
    allowed_commands: ["git", "npm", "mix"]
    forbidden_commands: ["rm", "sudo", "curl"]
    file_access:
      read_only: ["/etc", "/usr"]
      read_write: ["./src", "./test"]
      forbidden: ["/home", "/root"]
      
  # NEW: Audit and logging
  audit:
    log_level: "debug" | "info" | "warn" | "error"
    log_targets: ["file", "console", "remote"]
    include_prompts: true
    include_responses: true
    redact_sensitive: true
    
  steps:
    - name: "secure_operation"
      type: "claude"
      prompt: "Perform secure code analysis"
      security_context:
        permission_mode: "plan"  # Never auto-execute
        require_approval: true
        allowed_tools: ["Read"]
```

### 6. Integration and Deployment

```yaml
workflow:
  name: "CI/CD Pipeline"
  
  # NEW: Integration hooks
  integrations:
    github:
      token: "${GITHUB_TOKEN}"
      repository: "owner/repo"
      create_pr: true
      auto_merge: false
      
    slack:
      webhook: "${SLACK_WEBHOOK}"
      notify_on: ["success", "error"]
      
    monitoring:
      prometheus_endpoint: "http://monitoring:9090"
      alert_on_error: true
      
  # NEW: Deployment configuration
  deployment:
    environments: ["staging", "production"]
    approval_required: true
    rollback_on_failure: true
    
  steps:
    - name: "test_changes"
      type: "claude"
      prompt: "Run comprehensive tests"
      on_success: "deploy_staging"
      on_failure: "notify_team"
      
    - name: "deploy_staging"
      type: "claude"
      condition: "ENV == 'staging'"
      prompt: "Deploy to staging environment"
      integrations: ["github", "slack"]
      
    - name: "manual_approval"
      type: "human_approval"
      message: "Review staging deployment and approve production"
      timeout: 86400000  # 24 hours
      
    - name: "deploy_production"
      type: "claude"
      condition: "approval_received"
      prompt: "Deploy to production"
      security_context:
        require_approval: true
        permission_mode: "plan"
```

### 7. Monitoring and Observability

```yaml
workflow:
  name: "Observable Pipeline"
  
  # NEW: Monitoring configuration
  monitoring:
    metrics:
      - name: "execution_time"
        type: "histogram"
        labels: ["step_name", "step_type"]
      - name: "token_usage"
        type: "counter"
        labels: ["model", "step_name"]
      - name: "error_rate"
        type: "gauge"
        
    tracing:
      enabled: true
      jaeger_endpoint: "http://jaeger:14268"
      sample_rate: 1.0
      
    alerts:
      - name: "high_cost"
        condition: "total_cost > 1.0"
        action: "pause_pipeline"
      - name: "long_execution"
        condition: "execution_time > 300000"  # 5 minutes
        action: "notify_admin"
        
  steps:
    - name: "monitored_step"
      type: "gemini"
      prompt: "Expensive operation"
      monitoring:
        track_cost: true
        track_time: true
        custom_metrics:
          complexity_score: "extract_from_response"
```

## Implementation Strategy

### Phase 1: Core Enhancements
1. **Enhanced Claude Integration**: Implement comprehensive SDK options
2. **Session Management**: Add continue/resume functionality
3. **Advanced Tool System**: Custom tools, validation, safety

### Phase 2: Workflow Control
1. **Conditional Execution**: Step conditions and branching
2. **Error Handling**: Retry policies, error recovery
3. **Parallel Execution**: Concurrent step execution

### Phase 3: Security and Production
1. **Permission Management**: Fine-grained security controls
2. **Audit and Logging**: Comprehensive monitoring
3. **Integration Hooks**: External system integration

### Phase 4: Advanced Features
1. **State Management**: Persistent pipeline state
2. **Deployment Integration**: CI/CD capabilities
3. **Observability**: Metrics, tracing, alerting

## Configuration Schema Evolution

### Backward Compatibility
- All existing YAML configs will continue to work
- New features are additive with sensible defaults
- Migration guide for upgrading configs

### Validation
- JSON Schema validation for all configuration
- Runtime validation of tool parameters
- Security policy enforcement

### Documentation
- Comprehensive examples for each feature
- Migration guide from current to new format
- Best practices guide for complex workflows

## Tool System Expansion

### New Tool Categories

1. **System Tools**
   - File operations: read, write, search, copy
   - Process management: start, stop, monitor
   - Network operations: HTTP requests, DNS lookup

2. **Development Tools**
   - Git operations: clone, commit, push, merge
   - Package management: install, update, audit
   - Testing: run tests, coverage analysis

3. **Cloud Tools**
   - AWS operations: S3, EC2, Lambda
   - Docker operations: build, run, deploy
   - Kubernetes: deploy, scale, monitor

4. **Database Tools**
   - SQL operations: query, migrate, backup
   - NoSQL operations: document operations
   - Analytics: data analysis, reporting

### Multi-Provider Tool Support

```yaml
tool_providers:
  - name: "instructor_lite"
    adapter: "Pipeline.Tools.Adapters.InstructorLiteAdapter"
    models: ["gemini-2.5-flash", "gemini-pro"]
    
  - name: "openai"
    adapter: "Pipeline.Tools.Adapters.OpenAIAdapter"
    models: ["gpt-4", "gpt-3.5-turbo"]
    
  - name: "claude"
    adapter: "Pipeline.Tools.Adapters.ClaudeAdapter" 
    models: ["claude-opus-4", "claude-sonnet-3.5"]
```

## Conclusion

This expansion transforms our pipeline system from a simple orchestrator into a comprehensive AI-powered workflow engine that can:

1. **Leverage Full LLM Capabilities**: Function calling, session management, advanced prompting
2. **Provide Production-Ready Features**: Security, monitoring, error handling
3. **Support Complex Workflows**: Conditional execution, parallel processing, state management
4. **Integrate with Existing Systems**: CI/CD, monitoring, communication tools

The phased implementation approach ensures we can deliver value incrementally while maintaining backward compatibility and system stability.