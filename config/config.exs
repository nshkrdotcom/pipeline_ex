import Config

# Configuration for Pipeline Safety Features
config :pipeline,
  # Recursion limits
  max_nesting_depth: 10,
  max_total_steps: 1000,

  # Resource limits
  memory_limit_mb: 1024,
  timeout_seconds: 300,

  # Workspace configuration
  workspace_enabled: true,
  nested_workspace_root: "./nested_workspaces",
  cleanup_on_error: true,

  # Allowed directories for pipeline files (security)
  allowed_pipeline_dirs: ["./pipelines", "./examples", "./test/fixtures/pipelines"],

  # Pipeline registry configuration (future feature)
  enable_pipeline_registry: false,
  pipeline_cache_ttl: 3600

# Environment-specific configuration
import_config "#{config_env()}.exs"

