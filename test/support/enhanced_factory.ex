defmodule Pipeline.Test.EnhancedFactory do
  @moduledoc """
  Enhanced factory for creating test configurations and mock responses
  for the Claude Agent SDK integration features.
  """

  @doc """
  Creates enhanced Claude options configuration for testing.
  """
  def enhanced_claude_options(overrides \\ %{}) do
    Map.merge(
      %{
        # Core Configuration
        "max_turns" => 15,
        "output_format" => "stream_json",
        "verbose" => true,

        # Tool Management
        "allowed_tools" => ["Write", "Edit", "Read", "Bash"],
        "disallowed_tools" => ["WebFetch"],

        # System Prompts
        "system_prompt" => "You are a helpful coding assistant",
        "append_system_prompt" => "Follow best practices",

        # Working Environment
        "cwd" => "./workspace",

        # Session Management
        "session_id" => "test-session-123",
        "resume_session" => false,

        # Performance & Reliability
        "retry_config" => %{
          "max_retries" => 3,
          "backoff_strategy" => "exponential",
          "retry_on" => ["timeout", "api_error"]
        },
        "timeout_ms" => 300_000,

        # Debug & Monitoring
        "debug_mode" => true,
        "telemetry_enabled" => true,
        "cost_tracking" => true,

        # Permission Management (Future)
        "permission_mode" => "accept_edits",
        "permission_prompt_tool" => "mcp__auth__approve",

        # MCP Support (Future)
        "mcp_config" => "./config/mcp_servers.json"
      },
      stringify_keys(overrides)
    )
  end

  @doc """
  Creates a claude_smart step configuration.
  """
  def claude_smart_step(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "test_smart_step",
        "type" => "claude_smart",
        "preset" => "development",
        "environment_aware" => true,
        "claude_options" => enhanced_claude_options(),
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for smart step"
          }
        ],
        "output_to_file" => "test_smart_output.json"
      },
      stringify_keys(overrides)
    )
  end

  @doc """
  Creates a claude_session step configuration.
  """
  def claude_session_step(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "test_session_step",
        "type" => "claude_session",
        "session_config" => %{
          "persist" => true,
          "session_name" => "test_session",
          "continue_on_restart" => true,
          "checkpoint_frequency" => 5,
          "description" => "Test session for automated testing"
        },
        "claude_options" => enhanced_claude_options(),
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for session step"
          }
        ],
        "output_to_file" => "test_session_output.json"
      },
      stringify_keys(overrides)
    )
  end

  @doc """
  Creates a claude_extract step configuration.
  """
  def claude_extract_step(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "test_extract_step",
        "type" => "claude_extract",
        "extraction_config" => %{
          "use_content_extractor" => true,
          "format" => "structured",
          "post_processing" => ["extract_code_blocks", "extract_recommendations"],
          "max_summary_length" => 500,
          "include_metadata" => true
        },
        "claude_options" => enhanced_claude_options(),
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for extraction step"
          }
        ],
        "output_to_file" => "test_extract_output.json"
      },
      stringify_keys(overrides)
    )
  end

  @doc """
  Creates a claude_batch step configuration.
  """
  def claude_batch_step(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "test_batch_step",
        "type" => "claude_batch",
        "batch_config" => %{
          "max_parallel" => 3,
          "timeout_per_task" => 60_000,
          "consolidate_results" => true
        },
        "tasks" => [
          %{
            "file" => "test1.py",
            "prompt" => "Analyze this file for issues"
          },
          %{
            "file" => "test2.py",
            "prompt" => "Analyze this file for issues"
          }
        ],
        "claude_options" => enhanced_claude_options(),
        "output_to_file" => "test_batch_output.json"
      },
      stringify_keys(overrides)
    )
  end

  @doc """
  Creates a claude_robust step configuration.
  """
  def claude_robust_step(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "test_robust_step",
        "type" => "claude_robust",
        "retry_config" => %{
          "max_retries" => 3,
          "backoff_strategy" => "exponential",
          "retry_conditions" => ["max_turns_exceeded", "api_timeout"],
          "fallback_action" => "continue_with_mock"
        },
        "claude_options" => enhanced_claude_options(),
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt for robust step"
          }
        ],
        "output_to_file" => "test_robust_output.json"
      },
      stringify_keys(overrides)
    )
  end

  @doc """
  Creates an enhanced workflow configuration with new features.
  """
  def enhanced_workflow(overrides \\ %{}) do
    base_workflow = %{
      "workflow" => %{
        "name" => "test_enhanced_workflow",
        "checkpoint_enabled" => true,
        "workspace_dir" => "./workspace",
        "checkpoint_dir" => "./checkpoints",

        # Enhanced: Claude authentication configuration
        "claude_auth" => %{
          "auto_check" => true,
          "provider" => "anthropic",
          "fallback_mock" => true,
          "diagnostics" => true
        },

        # Enhanced: Environment configuration
        "environment" => %{
          "mode" => "development",
          "debug_level" => "detailed",
          "cost_alerts" => %{
            "enabled" => true,
            "threshold_usd" => 1.0,
            "notify_on_exceed" => true
          }
        },
        "defaults" => %{
          "gemini_model" => "gemini-2.5-flash",
          "gemini_token_budget" => %{
            "max_output_tokens" => 2048,
            "temperature" => 0.7
          },
          "claude_output_format" => "stream_json",
          "claude_preset" => "development",
          "output_dir" => "./outputs/test"
        },
        "steps" => [
          claude_smart_step(),
          claude_session_step(),
          claude_extract_step()
        ]
      }
    }

    deep_merge(base_workflow, overrides)
  end

  @doc """
  Creates enhanced prompt configurations.
  """
  def enhanced_prompt_templates do
    [
      # Static content
      %{
        "type" => "static",
        "content" => "Enhanced static content for testing"
      },

      # File content
      %{
        "type" => "file",
        "path" => "test_file.py"
      },

      # Enhanced previous_response with ContentExtractor
      %{
        "type" => "previous_response",
        "step" => "previous_step",
        "extract_with" => "content_extractor",
        "summary" => true,
        "max_length" => 1000
      },

      # Session context (new)
      %{
        "type" => "session_context",
        "session_id" => "test_session",
        "include_last_n" => 3
      },

      # Claude continue (new)
      %{
        "type" => "claude_continue",
        "session_id" => "${previous_step.session_id}",
        "new_prompt" => "Continue with the next step"
      }
    ]
  end

  @doc """
  Creates mock responses for enhanced step types.
  """
  def enhanced_mock_responses do
    %{
      # Mock response for claude_smart steps
      "claude_smart" => [
        %{
          "type" => "system",
          "data" => %{
            "session_id" => "mock-session-smart-123",
            "model" => "claude-3-5-sonnet-20241022",
            "tools" => ["Write", "Edit", "Read", "Bash"]
          }
        },
        %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" => "Mock response from claude_smart step with development preset applied"
            }
          }
        },
        %{
          "type" => "result",
          "subtype" => "success",
          "data" => %{
            "total_cost_usd" => 0.001,
            "num_turns" => 1,
            "duration_ms" => 1500,
            "session_id" => "mock-session-smart-123"
          }
        }
      ],

      # Mock response for claude_session steps
      "claude_session" => [
        %{
          "type" => "system",
          "data" => %{
            "session_id" => "persistent-session-456",
            "session_name" => "test_session",
            "checkpoint_enabled" => true,
            "model" => "claude-3-5-sonnet-20241022"
          }
        },
        %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" => "Mock response from claude_session step with session persistence"
            }
          }
        },
        %{
          "type" => "result",
          "subtype" => "success",
          "data" => %{
            "total_cost_usd" => 0.002,
            "num_turns" => 1,
            "duration_ms" => 2000,
            "session_id" => "persistent-session-456",
            "session_checkpointed" => true
          }
        }
      ],

      # Mock response for claude_extract steps
      "claude_extract" => [
        %{
          "type" => "system",
          "data" => %{
            "session_id" => "extract-session-789",
            "model" => "claude-3-5-sonnet-20241022",
            "extraction_mode" => "structured"
          }
        },
        %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" => [
                %{
                  "type" => "text",
                  "text" =>
                    "## Analysis Results\n\n### Code Blocks\n```python\ndef example():\n    pass\n```\n\n### Recommendations\n1. Add error handling\n2. Improve documentation"
                }
              ]
            }
          }
        },
        %{
          "type" => "result",
          "subtype" => "success",
          "data" => %{
            "total_cost_usd" => 0.003,
            "num_turns" => 1,
            "duration_ms" => 2500,
            "session_id" => "extract-session-789",
            "extracted_metadata" => %{
              "code_blocks_found" => 1,
              "recommendations_count" => 2,
              "content_length" => 150
            }
          }
        }
      ],

      # Mock response for claude_batch steps
      "claude_batch" => [
        %{
          "type" => "system",
          "data" => %{
            "session_id" => "batch-session-abc",
            "model" => "claude-3-5-sonnet-20241022",
            "batch_mode" => true,
            "parallel_tasks" => 2
          }
        },
        %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" =>
                "Mock batch processing results:\n\nTask 1 (test1.py): No issues found\nTask 2 (test2.py): Minor style improvements suggested"
            }
          }
        },
        %{
          "type" => "result",
          "subtype" => "success",
          "data" => %{
            "total_cost_usd" => 0.005,
            "num_turns" => 1,
            "duration_ms" => 3000,
            "session_id" => "batch-session-abc",
            "batch_results" => %{
              "tasks_completed" => 2,
              "tasks_failed" => 0,
              "total_processing_time" => 3000
            }
          }
        }
      ],

      # Mock response for claude_robust steps with retry
      "claude_robust" => [
        %{
          "type" => "system",
          "data" => %{
            "session_id" => "robust-session-def",
            "model" => "claude-3-5-sonnet-20241022",
            "retry_enabled" => true,
            "max_retries" => 3
          }
        },
        %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" => "Mock response from claude_robust step (attempt 1 of max 3)"
            }
          }
        },
        %{
          "type" => "result",
          "subtype" => "success",
          "data" => %{
            "total_cost_usd" => 0.001,
            "num_turns" => 1,
            "duration_ms" => 1800,
            "session_id" => "robust-session-def",
            "retry_info" => %{
              "attempts_made" => 1,
              "max_retries" => 3,
              "retry_strategy" => "exponential"
            }
          }
        }
      ],

      # Mock response for error scenarios
      "error_max_turns" => [
        %{
          "type" => "system",
          "data" => %{
            "session_id" => "error-session-123",
            "model" => "claude-3-5-sonnet-20241022"
          }
        },
        %{
          "type" => "result",
          "subtype" => "error_max_turns",
          "data" => %{
            "error" => "Task exceeded max_turns limit",
            "num_turns" => 15,
            "max_turns" => 15,
            "session_id" => "error-session-123"
          }
        }
      ],

      # Mock response for retry scenarios
      "retry_success" => [
        %{
          "type" => "system",
          "data" => %{
            "session_id" => "retry-session-456",
            "model" => "claude-3-5-sonnet-20241022",
            "retry_attempt" => 2
          }
        },
        %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" => "Mock response after successful retry (attempt 2)"
            }
          }
        },
        %{
          "type" => "result",
          "subtype" => "success",
          "data" => %{
            "total_cost_usd" => 0.002,
            "num_turns" => 1,
            "duration_ms" => 2200,
            "session_id" => "retry-session-456",
            "retry_info" => %{
              "attempts_made" => 2,
              "final_attempt" => true
            }
          }
        }
      ]
    }
  end

  @doc """
  Creates test files for file-based prompts.
  """
  def create_test_files(base_dir \\ "./workspace") do
    File.mkdir_p!(base_dir)

    test_files = %{
      "test_file.py" => """
      def example_function():
          \"\"\"Example function for testing.\"\"\"
          return "Hello, World!"

      # TODO: Add error handling
      """,
      "requirements.txt" => """
      pytest>=7.0.0
      requests>=2.28.0
      """,
      "README.md" => """
      # Test Project

      This is a test project for pipeline configuration testing.
      """
    }

    Enum.each(test_files, fn {filename, content} ->
      File.write!(Path.join(base_dir, filename), content)
    end)

    test_files
  end

  # Private helper functions

  defp stringify_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} -> {key, stringify_keys(value)}
    end)
  end

  defp stringify_keys(list) when is_list(list) do
    Enum.map(list, &stringify_keys/1)
  end

  defp stringify_keys(value), do: value

  # Deep merge function for nested maps
  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      deep_merge(v1, v2)
    end)
  end

  defp deep_merge(_left, right), do: right
end
