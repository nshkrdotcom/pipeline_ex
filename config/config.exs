import Config

# Configuration for Pipeline Safety Features
config :pipeline,
  # Recursion limits
  max_nesting_depth: 10,
  max_total_steps: 1000,

  # Resource limits
  memory_limit_mb: 1024,
  timeout_seconds: 300,
  
  # Max turns configuration for different contexts
  max_turns_default: 3,              # Default fallback for Claude providers
  max_turns_sdk_default: 1,          # Default for SDK calls when not specified
  max_turns_session: 50,             # Maximum turns for persistent sessions
  max_turns_robust_retry: 1,         # Turns for robust error recovery attempts
  
  # Environment-specific presets
  max_turns_presets: %{
    development: 20,    # Permissive for development
    production: 10,     # Conservative for production
    analysis: 5,        # Limited for code analysis
    chat: 15,          # Moderate for conversational flows
    test: 3            # Minimal for tests
  },

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
