# Configuration & Environment Reference

## Table of Contents

1. [Overview](#overview)
2. [Workflow Configuration](#workflow-configuration)
3. [Environment Settings](#environment-settings)
4. [Authentication Configuration](#authentication-configuration)
5. [Resource Management](#resource-management)
6. [Provider Configuration](#provider-configuration)
7. [Monitoring & Telemetry](#monitoring--telemetry)
8. [Directory Structure](#directory-structure)
9. [Environment Variables](#environment-variables)
10. [Configuration Precedence](#configuration-precedence)

## Overview

Pipeline's configuration system provides flexible control over:

- **Workflow settings** for execution behavior
- **Environment modes** for different deployment contexts
- **Authentication** for AI providers
- **Resource limits** for safety and cost control
- **Monitoring** for observability
- **Directory management** for organized outputs

## Workflow Configuration

### Basic Configuration

```yaml
workflow:
  # Required fields
  name: "data_processing_pipeline"
  
  # Optional metadata
  description: "Processes raw data through multiple stages"
  version: "2.1.0"
  author: "Data Team"
  tags: ["production", "data", "etl"]
  
  # Execution settings
  checkpoint_enabled: true
  continue_on_error: false
  max_execution_time: 3600      # 1 hour
  retry_on_failure: true
  retry_attempts: 3
```

### Workspace Configuration

Control file system access and organization:

```yaml
workflow:
  # Workspace for Claude operations
  workspace_dir: "./workspace"
  workspace_config:
    create_if_missing: true
    cleanup_on_success: true
    cleanup_on_error: false
    preserve_structure: true
    max_size_mb: 1024
  
  # Output organization
  output_dir: "./outputs/${workflow.name}/${timestamp}"
  output_config:
    create_subdirs: true
    organize_by_step: true
    compress_large_files: true
    compression_threshold_mb: 10
  
  # Checkpoint storage
  checkpoint_dir: "./checkpoints"
  checkpoint_config:
    rotation_policy: "keep_last_5"
    compress: true
    include_workspace: true
```

### Defaults Section

Set default values for all steps:

```yaml
workflow:
  defaults:
    # Model defaults
    gemini_model: "gemini-2.5-flash"
    claude_preset: "production"
    
    # Token budgets
    gemini_token_budget:
      max_output_tokens: 4096
      temperature: 0.7
      top_p: 0.95
      top_k: 40
    
    # Output formats
    claude_output_format: "json"
    output_dir: "./outputs"
    
    # Timeouts
    timeout_seconds: 300
    retry_on_error: true
    
    # Step defaults
    continue_on_error: false
    cache_results: true
    cache_ttl: 3600
```

## Environment Settings

### Environment Modes

Configure behavior based on deployment context:

```yaml
workflow:
  environment:
    mode: "production"          # development, production, test
    
    # Mode-specific settings
    development:
      debug_level: "detailed"
      allow_mock_providers: true
      relaxed_limits: true
      verbose_logging: true
    
    production:
      debug_level: "basic"
      allow_mock_providers: false
      strict_limits: true
      structured_logging: true
    
    test:
      debug_level: "detailed"
      force_mock_providers: true
      fast_mode: true
      deterministic: true
```

### Debug Configuration

Control debugging and logging:

```yaml
workflow:
  environment:
    debug_level: "detailed"     # basic, detailed, performance
    
    debug_config:
      # Logging settings
      log_all_steps: true
      log_prompts: true
      log_responses: true
      log_execution_time: true
      
      # Performance tracking
      track_memory_usage: true
      track_token_usage: true
      profile_slow_steps: true
      slow_step_threshold_ms: 5000
      
      # Debug outputs
      save_debug_artifacts: true
      debug_output_dir: "./debug"
      include_traces: true
```

### Cost Management

Monitor and control API costs:

```yaml
workflow:
  environment:
    cost_alerts:
      enabled: true
      threshold_usd: 10.00
      warning_threshold_usd: 7.50
      notify_on_exceed: true
      notification_webhook: "${COST_ALERT_WEBHOOK}"
      
    cost_tracking:
      track_by_step: true
      track_by_provider: true
      generate_reports: true
      report_frequency: "daily"
      
    cost_limits:
      max_cost_per_run: 50.00
      max_cost_per_step: 5.00
      action_on_exceed: "pause"  # pause, continue, abort
```

## Authentication Configuration

### Claude Authentication

Configure Claude API access:

```yaml
workflow:
  claude_auth:
    # Basic settings
    auto_check: true            # Verify auth before starting
    provider: "anthropic"       # anthropic, aws_bedrock, google_vertex
    
    # Provider-specific configuration
    anthropic:
      use_cli_auth: true        # Use Claude CLI authentication
      api_key_env: "ANTHROPIC_API_KEY"  # Fallback to env var
    
    aws_bedrock:
      region: "us-east-1"
      access_key_env: "AWS_ACCESS_KEY_ID"
      secret_key_env: "AWS_SECRET_ACCESS_KEY"
      model_id: "anthropic.claude-3-sonnet"
    
    google_vertex:
      project_id: "${GCP_PROJECT_ID}"
      location: "us-central1"
      credentials_path: "${GOOGLE_APPLICATION_CREDENTIALS}"
    
    # Fallback behavior
    fallback_mock: true         # Use mocks if auth fails (dev only)
    diagnostics: true           # Run auth diagnostics on failure
    retry_auth: true
    max_auth_retries: 3
```

### Gemini Authentication

Configure Gemini API access:

```yaml
workflow:
  gemini_auth:
    api_key_source: "env"       # env, file, secret_manager
    api_key_env: "GEMINI_API_KEY"
    api_key_file: "./.gemini_key"
    
    # Advanced settings
    endpoint_override: null
    use_service_account: false
    service_account_path: null
    
    # Quota management
    rate_limit_per_minute: 60
    concurrent_requests: 5
```

### Multi-Provider Configuration

Support multiple API providers:

```yaml
workflow:
  providers:
    primary: "anthropic"
    fallback: "gemini"
    
    selection_strategy: "round_robin"  # round_robin, least_cost, fastest
    
    provider_weights:
      anthropic: 0.7
      gemini: 0.3
    
    provider_capabilities:
      anthropic:
        supports_tools: true
        supports_vision: true
        max_context: 200000
      gemini:
        supports_functions: true
        supports_vision: true
        max_context: 1000000
```

## Resource Management

### Resource Limits

Prevent resource exhaustion:

```yaml
workflow:
  resource_limits:
    # Execution limits
    max_total_steps: 1000
    max_execution_time_s: 7200    # 2 hours
    max_parallel_steps: 10
    
    # Memory limits
    max_memory_mb: 4096
    max_workspace_size_mb: 10240
    max_output_size_mb: 1024
    
    # API limits
    max_api_calls: 500
    max_tokens_total: 1000000
    max_cost_usd: 100.00
    
    # Safety limits
    max_file_operations: 1000
    max_shell_commands: 100
    max_network_requests: 50
```

### Performance Configuration

Optimize execution performance:

```yaml
workflow:
  performance:
    # Caching
    cache_enabled: true
    cache_strategy: "aggressive"   # conservative, moderate, aggressive
    cache_size_mb: 512
    cache_ttl_seconds: 3600
    
    # Parallelization
    parallel_execution: true
    max_parallel_workers: 8
    queue_size: 100
    
    # Optimization
    lazy_loading: true
    stream_large_files: true
    batch_small_operations: true
    batch_size: 50
    
    # Timeouts
    step_timeout_default: 300
    api_timeout: 60
    file_operation_timeout: 30
```

### Safety Configuration

Ensure safe execution:

```yaml
workflow:
  safety:
    # Sandboxing
    sandbox_mode: true
    allowed_commands: ["python", "node", "git"]
    blocked_commands: ["rm -rf", "sudo", "curl"]
    
    # Network restrictions
    allow_network: true
    allowed_domains: ["api.github.com", "pypi.org"]
    block_local_network: true
    
    # File system protection
    restrict_file_access: true
    allowed_paths: ["./workspace", "./data"]
    read_only_paths: ["./config", "./scripts"]
    
    # Recursive pipeline safety
    max_nesting_depth: 10
    detect_circular_deps: true
    max_recursion_time: 1800
```

## Provider Configuration

### Model Selection

Configure AI model preferences:

```yaml
workflow:
  models:
    # Gemini models
    gemini:
      default: "gemini-2.5-flash"
      by_task:
        analysis: "gemini-2.5-flash"
        generation: "gemini-2.5-pro"
        quick_check: "gemini-2.5-flash-lite-preview-06-17"
    
    # Claude models (determined by SDK)
    claude:
      prefer_fast: false
      prefer_smart: true
      
    # Model selection rules
    selection_rules:
      - condition: "task.complexity > 8"
        model: "gemini-2.5-pro"
      - condition: "task.type == 'code_generation'"
        provider: "claude"
```

### Token Management

Control token usage:

```yaml
workflow:
  token_management:
    # Global limits
    total_token_budget: 500000
    reserve_tokens: 10000
    
    # Per-step limits
    default_max_tokens: 4096
    
    # Dynamic allocation
    dynamic_allocation: true
    allocation_strategy: "priority"  # equal, priority, adaptive
    
    # Token optimization
    optimize_prompts: true
    compression_level: "moderate"
    remove_redundancy: true
```

## Monitoring & Telemetry

### Telemetry Configuration

Enable observability:

```yaml
workflow:
  telemetry:
    enabled: true
    
    # Metrics collection
    metrics:
      collect_execution_time: true
      collect_token_usage: true
      collect_error_rates: true
      collect_memory_usage: true
      
    # Tracing
    tracing:
      enabled: true
      sample_rate: 1.0
      include_prompts: false    # Privacy consideration
      include_responses: false
      
    # Export configuration
    exporters:
      - type: "prometheus"
        endpoint: "http://localhost:9090"
      - type: "opentelemetry"
        endpoint: "http://localhost:4317"
      - type: "file"
        path: "./metrics/pipeline_metrics.json"
```

### Monitoring Alerts

Configure alerting:

```yaml
workflow:
  monitoring:
    alerts:
      # Error rate alerts
      - metric: "error_rate"
        threshold: 0.1
        window: "5m"
        action: "notify"
        
      # Performance alerts
      - metric: "step_duration_p95"
        threshold: 30000  # 30 seconds
        window: "10m"
        action: "log"
        
      # Resource alerts
      - metric: "memory_usage_percent"
        threshold: 80
        window: "1m"
        action: "throttle"
    
    # Notification channels
    notifications:
      webhook_url: "${MONITORING_WEBHOOK}"
      email_addresses: ["ops@example.com"]
      slack_channel: "#pipeline-alerts"
```

## Directory Structure

### Standard Layout

Recommended directory organization:

```yaml
workflow:
  directories:
    # Standard structure
    structure:
      workspace: "./workspace"
      outputs: "./outputs"
      checkpoints: "./checkpoints"
      logs: "./logs"
      cache: "./.cache"
      temp: "./.tmp"
    
    # Auto-organization
    organize:
      by_date: true
      by_workflow: true
      by_execution: true
      
    # Cleanup policies
    cleanup:
      temp_files: "immediate"
      old_outputs: "7_days"
      old_checkpoints: "30_days"
      old_logs: "90_days"
```

### Dynamic Paths

Use variables in paths:

```yaml
workflow:
  # Dynamic directory naming
  output_dir: "./outputs/${workflow.name}/${date}/${execution_id}"
  
  # Environment-based paths
  workspace_dir: "${PIPELINE_WORKSPACE:-./workspace}"
  
  # Conditional paths
  checkpoint_dir: |
    ${environment.mode == 'production' 
      ? '/persistent/checkpoints' 
      : './checkpoints'}
```

## Environment Variables

### System Variables

Pipeline recognizes these environment variables:

```bash
# API Keys
export GEMINI_API_KEY="your_key"
export ANTHROPIC_API_KEY="your_key"  # If not using CLI auth

# Directories
export PIPELINE_WORKSPACE_DIR="./workspace"
export PIPELINE_OUTPUT_DIR="./outputs"
export PIPELINE_CHECKPOINT_DIR="./checkpoints"

# Execution
export PIPELINE_MAX_WORKERS=8
export PIPELINE_TIMEOUT=3600
export PIPELINE_CACHE_SIZE=1024

# Debugging
export PIPELINE_DEBUG=true
export PIPELINE_LOG_LEVEL=debug
export PIPELINE_TRACE=true

# Safety
export PIPELINE_MAX_COST=50.00
export PIPELINE_SANDBOX_MODE=true
export PIPELINE_MAX_MEMORY_MB=4096
```

### Custom Variables

Define and use custom variables:

```yaml
workflow:
  # Define variables
  variables:
    api_endpoint: "${API_ENDPOINT}"
    environment: "${ENVIRONMENT:-development}"
    feature_flag: "${ENABLE_FEATURE:-false}"
  
  # Use in configuration
  steps:
    - name: "api_call"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Call API at {{variables.api_endpoint}}"
```

## Configuration Precedence

Configuration values are resolved in this order:

1. **Step-level configuration** (highest priority)
2. **Workflow defaults**
3. **Environment variables**
4. **Configuration files**
5. **System defaults** (lowest priority)

### Example Precedence

```yaml
# System default: timeout = 300

# Environment variable
export PIPELINE_TIMEOUT=600

workflow:
  # Workflow default
  defaults:
    timeout_seconds: 900
  
  steps:
    - name: "quick_task"
      type: "gemini"
      # Step-level override (this wins)
      timeout_seconds: 120
      prompt: "..."
    
    - name: "normal_task"
      type: "gemini"
      # Uses workflow default (900)
      prompt: "..."
```

### Configuration Files

Load external configuration:

```yaml
workflow:
  # Load base configuration
  extends: "./config/base.yaml"
  
  # Override specific values
  environment:
    mode: "production"
  
  # Merge additional config
  include:
    - "./config/models.yaml"
    - "./config/providers.yaml"
    - "./config/${ENVIRONMENT}.yaml"
```

### Dynamic Configuration

Configure based on conditions:

```yaml
workflow:
  # Conditional configuration
  $if: "${ENVIRONMENT == 'production'}"
  $then:
    checkpoint_enabled: true
    safety:
      sandbox_mode: true
      max_cost_usd: 100.00
  $else:
    checkpoint_enabled: false
    safety:
      sandbox_mode: false
      max_cost_usd: 10.00
```

This reference provides comprehensive documentation for configuration and environment management in Pipeline YAML v2 format.