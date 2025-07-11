import Config

# Configuration for Pipeline Safety Features
config :pipeline,
  # Recursion limits
  max_nesting_depth: 10,
  max_total_steps: 1000,

  # Resource limits
  memory_limit_mb: 1024,
  timeout_seconds: 300,
  # 5 minutes default for Gemini requests
  gemini_timeout_ms: 300_000,

  # Max turns configuration for different contexts
  # Default fallback for Claude providers
  max_turns_default: 3,
  # Default for SDK calls when not specified
  max_turns_sdk_default: 1,
  # Maximum turns for persistent sessions
  max_turns_session: 50,
  # Turns for robust error recovery attempts
  max_turns_robust_retry: 1,

  # Environment-specific presets
  max_turns_presets: %{
    # Permissive for development
    development: 20,
    # Conservative for production
    production: 10,
    # Limited for code analysis
    analysis: 5,
    # Moderate for conversational flows
    chat: 15,
    # Minimal for tests
    test: 3
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
