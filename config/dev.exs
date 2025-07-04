import Config

# Development environment configuration
config :pipeline,
  # More permissive limits for development
  max_nesting_depth: 15,
  max_total_steps: 2000,
  memory_limit_mb: 2048,
  timeout_seconds: 600,

  # Enhanced logging in development
  log_level: :debug
