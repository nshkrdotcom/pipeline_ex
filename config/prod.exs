import Config

# Production environment configuration
config :pipeline,
  # Conservative limits for production
  max_nesting_depth: 8,
  max_total_steps: 500,
  memory_limit_mb: 1024,
  timeout_seconds: 300,

  # Production safety settings
  workspace_enabled: true,
  cleanup_on_error: true,

  # Restricted allowed directories for security
  allowed_pipeline_dirs: ["./pipelines"],

  # Production logging
  log_level: :info
