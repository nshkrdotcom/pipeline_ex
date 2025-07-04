defmodule Pipeline.EnhancedConfigTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.EnhancedConfig

  describe "enhanced Claude options validation" do
    test "validates core configuration options", %{workspace_dir: workspace_dir} do
      claude_options =
        enhanced_claude_options(%{
          "max_turns" => 15,
          "output_format" => "stream_json",
          "verbose" => true
        })

      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["max_turns"] == 15
      assert validated_step["claude_options"]["output_format"] == "stream_json"
      assert validated_step["claude_options"]["verbose"] == true
    end

    test "validates tool management options", %{workspace_dir: workspace_dir} do
      claude_options =
        enhanced_claude_options(%{
          "allowed_tools" => ["Write", "Edit", "Read", "Bash"],
          "disallowed_tools" => ["WebFetch", "Search"]
        })

      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["allowed_tools"] == [
               "Write",
               "Edit",
               "Read",
               "Bash"
             ]

      assert validated_step["claude_options"]["disallowed_tools"] == ["WebFetch", "Search"]
    end

    test "validates system prompt options", %{workspace_dir: workspace_dir} do
      claude_options =
        enhanced_claude_options(%{
          "system_prompt" => "You are a senior software engineer",
          "append_system_prompt" => "Follow best practices and write clean code"
        })

      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["system_prompt"] ==
               "You are a senior software engineer"

      assert validated_step["claude_options"]["append_system_prompt"] ==
               "Follow best practices and write clean code"
    end

    test "validates session management options", %{workspace_dir: workspace_dir} do
      claude_options =
        enhanced_claude_options(%{
          "session_id" => "custom-session-123",
          "resume_session" => true
        })

      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["session_id"] == "custom-session-123"
      assert validated_step["claude_options"]["resume_session"] == true
    end

    test "validates retry configuration", %{workspace_dir: workspace_dir} do
      retry_config = %{
        "max_retries" => 3,
        "backoff_strategy" => "exponential",
        "retry_on" => ["timeout", "api_error"]
      }

      claude_options = enhanced_claude_options(%{"retry_config" => retry_config})
      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["retry_config"]["max_retries"] == 3
      assert validated_step["claude_options"]["retry_config"]["backoff_strategy"] == "exponential"

      assert validated_step["claude_options"]["retry_config"]["retry_on"] == [
               "timeout",
               "api_error"
             ]
    end

    test "validates performance and reliability options", %{workspace_dir: workspace_dir} do
      claude_options =
        enhanced_claude_options(%{
          "timeout_ms" => 300_000,
          "debug_mode" => true,
          "telemetry_enabled" => true,
          "cost_tracking" => true
        })

      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["timeout_ms"] == 300_000
      assert validated_step["claude_options"]["debug_mode"] == true
      assert validated_step["claude_options"]["telemetry_enabled"] == true
      assert validated_step["claude_options"]["cost_tracking"] == true
    end

    test "validates permission management options", %{workspace_dir: workspace_dir} do
      claude_options =
        enhanced_claude_options(%{
          "permission_mode" => "accept_edits",
          "permission_prompt_tool" => "mcp__auth__approve"
        })

      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["permission_mode"] == "accept_edits"
      assert validated_step["claude_options"]["permission_prompt_tool"] == "mcp__auth__approve"
    end

    test "validates MCP configuration", %{workspace_dir: workspace_dir} do
      claude_options =
        enhanced_claude_options(%{
          "mcp_config" => "./config/mcp_servers.json"
        })

      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["claude_options"]["mcp_config"] == "./config/mcp_servers.json"
    end

    test "rejects invalid max_turns values", %{workspace_dir: workspace_dir} do
      claude_options = enhanced_claude_options(%{"max_turns" => -1})
      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "max_turns")
      assert String.contains?(error_msg, "must be positive")
    end

    test "rejects invalid output_format values", %{workspace_dir: workspace_dir} do
      claude_options = enhanced_claude_options(%{"output_format" => "invalid_format"})
      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "output_format")
      assert String.contains?(error_msg, "must be one of")
    end

    test "rejects invalid backoff_strategy values", %{workspace_dir: workspace_dir} do
      retry_config = %{
        "max_retries" => 3,
        "backoff_strategy" => "invalid_strategy"
      }

      claude_options = enhanced_claude_options(%{"retry_config" => retry_config})
      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "backoff_strategy")
      assert String.contains?(error_msg, "linear") or String.contains?(error_msg, "exponential")
    end

    test "rejects invalid permission_mode values", %{workspace_dir: workspace_dir} do
      claude_options = enhanced_claude_options(%{"permission_mode" => "invalid_mode"})
      step = claude_smart_step(%{"claude_options" => claude_options})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "permission_mode")
    end
  end

  describe "workflow-level enhanced configuration" do
    test "validates claude_auth configuration", %{workspace_dir: workspace_dir} do
      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "claude_auth" => %{
              "auto_check" => true,
              "provider" => "anthropic",
              "fallback_mock" => true,
              "diagnostics" => true
            },
            "steps" => [claude_smart_step()]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)

      assert validated_config["workflow"]["claude_auth"]["auto_check"] == true
      assert validated_config["workflow"]["claude_auth"]["provider"] == "anthropic"
      assert validated_config["workflow"]["claude_auth"]["fallback_mock"] == true
      assert validated_config["workflow"]["claude_auth"]["diagnostics"] == true
    end

    test "validates environment configuration", %{workspace_dir: workspace_dir} do
      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "environment" => %{
              "mode" => "development",
              "debug_level" => "detailed",
              "cost_alerts" => %{
                "enabled" => true,
                "threshold_usd" => 1.0,
                "notify_on_exceed" => true
              }
            },
            "steps" => [claude_smart_step()]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)

      assert validated_config["workflow"]["environment"]["mode"] == "development"
      assert validated_config["workflow"]["environment"]["debug_level"] == "detailed"
      assert validated_config["workflow"]["environment"]["cost_alerts"]["enabled"] == true
      assert validated_config["workflow"]["environment"]["cost_alerts"]["threshold_usd"] == 1.0
    end

    test "validates claude_preset in defaults", %{workspace_dir: workspace_dir} do
      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "defaults" => %{
              "claude_preset" => "development"
            },
            "steps" => [claude_smart_step()]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      assert validated_config["workflow"]["defaults"]["claude_preset"] == "development"
    end

    test "rejects invalid claude_auth provider", %{workspace_dir: workspace_dir} do
      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "claude_auth" => %{
              "provider" => "invalid_provider"
            },
            "steps" => [claude_smart_step()]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "provider")

      assert String.contains?(error_msg, "anthropic") or
               String.contains?(error_msg, "aws_bedrock")
    end

    test "rejects invalid environment mode", %{workspace_dir: workspace_dir} do
      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "environment" => %{
              "mode" => "invalid_mode"
            },
            "steps" => [claude_smart_step()]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "mode")

      assert String.contains?(error_msg, "development") or
               String.contains?(error_msg, "production")
    end

    test "rejects invalid debug_level", %{workspace_dir: workspace_dir} do
      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "environment" => %{
              "debug_level" => "invalid_level"
            },
            "steps" => [claude_smart_step()]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "debug_level")
    end

    test "rejects invalid claude_preset", %{workspace_dir: workspace_dir} do
      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "defaults" => %{
              "claude_preset" => "invalid_preset"
            },
            "steps" => [claude_smart_step()]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "claude_preset")
    end
  end

  describe "new step types validation" do
    test "validates claude_smart step configuration", %{workspace_dir: workspace_dir} do
      step = claude_smart_step()

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["type"] == "claude_smart"
      assert validated_step["preset"] == "development"
      assert validated_step["environment_aware"] == true
      assert_valid_enhanced_claude_options(validated_step["claude_options"])
    end

    test "validates claude_session step configuration", %{workspace_dir: workspace_dir} do
      step = claude_session_step()

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["type"] == "claude_session"
      assert validated_step["session_config"]["persist"] == true
      assert validated_step["session_config"]["session_name"] == "test_session"
      assert validated_step["session_config"]["checkpoint_frequency"] == 5
    end

    test "validates claude_extract step configuration", %{workspace_dir: workspace_dir} do
      step = claude_extract_step()

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["type"] == "claude_extract"
      assert validated_step["extraction_config"]["use_content_extractor"] == true
      assert validated_step["extraction_config"]["format"] == "structured"
      assert validated_step["extraction_config"]["max_summary_length"] == 500
    end

    test "validates claude_batch step configuration", %{workspace_dir: workspace_dir} do
      step = claude_batch_step()

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["type"] == "claude_batch"
      assert validated_step["batch_config"]["max_parallel"] == 3
      assert validated_step["batch_config"]["timeout_per_task"] == 60_000
      assert is_list(validated_step["tasks"])
    end

    test "validates claude_robust step configuration", %{workspace_dir: workspace_dir} do
      step = claude_robust_step()

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:ok, validated_config} = EnhancedConfig.load_from_map(config)
      validated_step = List.first(validated_config["workflow"]["steps"])

      assert validated_step["type"] == "claude_robust"
      assert validated_step["retry_config"]["max_retries"] == 3
      assert validated_step["retry_config"]["backoff_strategy"] == "exponential"
      assert is_list(validated_step["retry_config"]["retry_conditions"])
    end

    test "rejects invalid preset for claude_smart step", %{workspace_dir: workspace_dir} do
      step = claude_smart_step(%{"preset" => "invalid_preset"})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "preset")
    end

    test "rejects invalid extraction format", %{workspace_dir: workspace_dir} do
      extraction_config = %{
        "format" => "invalid_format"
      }

      step = claude_extract_step(%{"extraction_config" => extraction_config})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "format")
    end

    test "rejects invalid max_parallel for claude_batch", %{workspace_dir: workspace_dir} do
      batch_config = %{
        "max_parallel" => 0
      }

      step = claude_batch_step(%{"batch_config" => batch_config})

      config =
        enhanced_workflow(%{
          "workflow" => %{
            "workspace_dir" => workspace_dir,
            "steps" => [step]
          }
        })

      assert {:error, error_msg} = EnhancedConfig.load_from_map(config)
      assert String.contains?(error_msg, "max_parallel")
      assert String.contains?(error_msg, "positive")
    end
  end
end
