import Config

# Development environment configuration
config :pipeline,
  # More permissive limits for development
  max_nesting_depth: 15,
  max_total_steps: 2000,
  memory_limit_mb: 2048,
  timeout_seconds: 600,
  # 10 minutes for dev environment
  gemini_timeout_ms: 600_000,

  # Enhanced logging in development
  log_level: :debug,

  # Enable conversation logging for debugging failures
  enable_conversation_logging: true,
  conversation_log_dir: "./logs",

  # Claude-specific debug settings
  claude_debug_mode: true,
  claude_verbose_logging: true
