import Config

# Test environment configuration
config :pipeline,
  # Lower limits for faster testing
  max_nesting_depth: 5,
  max_total_steps: 100,
  memory_limit_mb: 512,
  timeout_seconds: 30,

  # Disable workspace for most tests to avoid cleanup overhead
  workspace_enabled: false,
  cleanup_on_error: false,

  # Test-specific logging
  log_level: :warning
