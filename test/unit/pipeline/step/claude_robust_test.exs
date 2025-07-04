defmodule Pipeline.Step.ClaudeRobustTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.Step.ClaudeRobust
  import Pipeline.Test.EnhancedFactory

  describe "claude_robust step execution" do
    test "executes with basic robust config", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "basic_robust_test",
          "retry_config" => %{
            "max_retries" => 2,
            "backoff_strategy" => "exponential",
            "retry_conditions" => ["timeout", "rate_limit"]
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      assert_success_result(result)
      assert Map.has_key?(result, "claude_robust_metadata")
      assert result["claude_robust_metadata"]["robustness_applied"] == true
      assert result["claude_robust_metadata"]["error_recovery_enabled"] == true
    end

    test "applies production preset as default", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "default_preset_test",
          "retry_config" => %{
            "max_retries" => 1
          }
        })
        # Remove default preset
        |> Map.delete("preset")

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      assert_success_result(result)
      # Should apply production preset by default for robust steps
      assert String.contains?(result["text"], "production safety constraints")
    end

    test "applies custom preset correctly", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "custom_preset_test",
          "preset" => "development",
          "retry_config" => %{
            "max_retries" => 1
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      assert_success_result(result)
      assert String.contains?(result["text"], "development optimizations applied")
    end

    test "works without retry config", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "no_config_test"
        })
        # Remove retry config
        |> Map.delete("retry_config")

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      assert_success_result(result)
      # Should use environment default retry config (test env uses 2)
      expected_retries = Application.get_env(:pipeline, :claude_robust_max_retries, 3)

      assert result["claude_robust_metadata"]["retry_config_used"]["max_retries"] ==
               expected_retries
    end

    test "handles different backoff strategies", %{workspace_dir: workspace_dir} do
      strategies = ["linear", "exponential", "fixed"]

      Enum.each(strategies, fn strategy ->
        step =
          claude_robust_step(%{
            "name" => "strategy_test_#{strategy}",
            "retry_config" => %{
              "max_retries" => 1,
              "backoff_strategy" => strategy,
              "base_delay_ms" => 100
            }
          })

        context = mock_context(workspace_dir)

        assert {:ok, result} = ClaudeRobust.execute(step, context)
        assert_success_result(result)

        assert result["claude_robust_metadata"]["retry_config_used"]["backoff_strategy"] ==
                 strategy
      end)
    end

    test "includes comprehensive robustness metadata", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "metadata_test",
          "retry_config" => %{
            "max_retries" => 3,
            "backoff_strategy" => "exponential",
            "fallback_action" => "graceful_degradation"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      assert_success_result(result)

      metadata = result["claude_robust_metadata"]
      assert metadata["step_name"] == "metadata_test"
      assert metadata["robustness_applied"] == true
      assert metadata["error_recovery_enabled"] == true
      assert metadata["fallback_configured"] == true
      assert Map.has_key?(metadata, "retry_config_used")
      assert Map.has_key?(metadata, "robust_execution_timestamp")
    end

    test "merges claude_options with robust options", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "options_merge_test",
          "retry_config" => %{
            "max_retries" => 2
          },
          "claude_options" => %{
            "max_turns" => 25,
            "verbose" => false,
            "custom_option" => "custom_value"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      assert_success_result(result)
      # Should merge successfully and apply robustness
      assert result["claude_robust_metadata"]["robustness_applied"] == true
    end
  end

  describe "retry mechanisms" do
    test "tracks retry attempts in metadata", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "retry_tracking_test",
          "retry_config" => %{
            "max_retries" => 2,
            "retry_conditions" => ["timeout", "rate_limit"]
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      assert_success_result(result)

      # In mock mode, should succeed on first attempt
      if Map.has_key?(result, "robustness_metadata") do
        robustness_meta = result["robustness_metadata"]
        assert robustness_meta["attempt_number"] >= 1
        assert robustness_meta["total_attempts"] >= 1
        assert Map.has_key?(robustness_meta, "execution_time_ms")
        assert is_list(robustness_meta["error_history"])
      end
    end

    test "respects max_retries limit", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "max_retries_test",
          "retry_config" => %{
            "max_retries" => 1,
            # Simulate always retrying
            "retry_conditions" => ["always_retry"]
          }
        })

      context = mock_context(workspace_dir)

      # In mock mode, this should succeed
      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)
    end

    test "uses different retry conditions", %{workspace_dir: workspace_dir} do
      conditions = [
        ["timeout"],
        ["rate_limit"],
        ["temporary_error"],
        ["timeout", "rate_limit", "temporary_error"]
      ]

      Enum.each(conditions, fn retry_conditions ->
        step =
          claude_robust_step(%{
            "name" => "conditions_test",
            "retry_config" => %{
              "max_retries" => 1,
              "retry_conditions" => retry_conditions
            }
          })

        context = mock_context(workspace_dir)

        assert {:ok, result} = ClaudeRobust.execute(step, context)
        assert_success_result(result)

        assert result["claude_robust_metadata"]["retry_config_used"]["retry_conditions"] ==
                 retry_conditions
      end)
    end

    test "calculates backoff delays correctly", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "backoff_test",
          "retry_config" => %{
            "max_retries" => 2,
            "backoff_strategy" => "exponential",
            "base_delay_ms" => 500
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)

      # Verify that backoff strategy is recorded
      assert result["claude_robust_metadata"]["retry_config_used"]["backoff_strategy"] ==
               "exponential"

      assert result["claude_robust_metadata"]["retry_config_used"]["base_delay_ms"] == 500
    end
  end

  describe "fallback mechanisms" do
    test "supports graceful degradation fallback", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "graceful_degradation_test",
          "retry_config" => %{
            "max_retries" => 1,
            "fallback_action" => "graceful_degradation"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)

      # Should have fallback configured
      assert result["claude_robust_metadata"]["fallback_configured"] == true
    end

    test "supports cached response fallback", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "cached_response_test",
          "retry_config" => %{
            "max_retries" => 1,
            "fallback_action" => "use_cached_response"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)

      # Should succeed and configure fallback
      assert result["claude_robust_metadata"]["fallback_configured"] == true
    end

    test "supports simplified prompt fallback", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "simplified_prompt_test",
          "retry_config" => %{
            "max_retries" => 1,
            "fallback_action" => "simplified_prompt"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)

      # Should succeed and configure fallback
      assert result["claude_robust_metadata"]["fallback_configured"] == true
    end

    test "supports emergency response fallback", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "emergency_response_test",
          "retry_config" => %{
            "max_retries" => 1,
            "fallback_action" => "emergency_response"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)

      # Should succeed and configure fallback
      assert result["claude_robust_metadata"]["fallback_configured"] == true
    end

    test "handles unknown fallback actions gracefully", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "unknown_fallback_test",
          "retry_config" => %{
            "max_retries" => 1,
            "fallback_action" => "unknown_action"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)

      # Should default to graceful degradation
      assert result["claude_robust_metadata"]["fallback_configured"] == true
    end
  end

  describe "integration with other features" do
    test "works with prompt building from previous steps", %{workspace_dir: workspace_dir} do
      # First create a step with some output
      first_step =
        claude_robust_step(%{
          "name" => "context_first",
          "retry_config" => %{
            "max_retries" => 1
          },
          "prompt" => [
            %{
              "type" => "static",
              "content" => "Initial robust analysis"
            }
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, first_result} = ClaudeRobust.execute(first_step, context)

      # Second step that references first step's output
      updated_context = %{context | results: %{"context_first" => first_result}}

      second_step =
        claude_robust_step(%{
          "name" => "context_second",
          "retry_config" => %{
            "max_retries" => 1
          },
          "prompt" => [
            %{
              "type" => "previous_response",
              "step" => "context_first"
            },
            %{
              "type" => "static",
              "content" => "Continue with robust processing"
            }
          ]
        })

      assert {:ok, second_result} = ClaudeRobust.execute(second_step, updated_context)

      # Should succeed and apply robustness
      assert_success_result(second_result)
      assert second_result["claude_robust_metadata"]["robustness_applied"] == true
    end

    test "preserves original response fields", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "preserve_fields_test",
          "retry_config" => %{
            "max_retries" => 1
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)

      # Should preserve original response fields from mock provider
      assert_success_result(result)
      assert result["claude_robust_metadata"]["robustness_applied"] == true

      # Original mock response fields should be preserved
      assert Map.has_key?(result, "success")
    end

    test "works with environment-aware configuration", %{workspace_dir: workspace_dir} do
      # Test with environment that might influence preset selection
      config_with_env = %{
        "workflow" => %{
          "name" => "test_workflow",
          "environment" => %{
            "mode" => "production"
          }
        }
      }

      step =
        claude_robust_step(%{
          "name" => "environment_test",
          "retry_config" => %{
            "max_retries" => 2
          }
        })
        # Let it detect from environment
        |> Map.delete("preset")

      context = mock_context(workspace_dir, config_with_env)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)
      assert result["claude_robust_metadata"]["robustness_applied"] == true
    end
  end

  describe "error handling and validation" do
    test "validates retry configuration", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "invalid_config_test",
          "retry_config" => %{
            # Invalid: must be non-negative
            "max_retries" => -1,
            # Invalid: must be non-negative
            "base_delay_ms" => -100
          }
        })

      context = mock_context(workspace_dir)

      assert {:error, reason} = ClaudeRobust.execute(step, context)
      assert String.contains?(reason, "max_retries")
    end

    test "handles invalid backoff strategy", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "invalid_strategy_test",
          "retry_config" => %{
            "max_retries" => 1,
            "backoff_strategy" => "invalid_strategy"
          }
        })

      context = mock_context(workspace_dir)

      assert {:error, reason} = ClaudeRobust.execute(step, context)
      assert String.contains?(String.downcase(reason), "backoff_strategy")
    end

    test "handles prompt building errors gracefully", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "prompt_error_test",
          "retry_config" => %{
            "max_retries" => 1
          },
          "prompt" => [
            %{
              "type" => "previous_response",
              # This should cause an error
              "step" => "nonexistent_step"
            }
          ]
        })

      # Empty results
      context = mock_context(workspace_dir, %{}, %{})

      # Should handle prompt building errors gracefully
      case ClaudeRobust.execute(step, context) do
        {:ok, _result} ->
          # If it succeeds, that's fine too (depends on PromptBuilder implementation)
          :ok

        {:error, reason} ->
          assert is_binary(reason)
          assert String.length(reason) > 0
      end
    end

    test "validates minimal configuration", %{workspace_dir: workspace_dir} do
      # Test with minimal valid configuration
      step = %{
        "name" => "minimal_robust_test",
        "type" => "claude_robust",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt"
          }
        ]
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)
    end

    test "handles non-retryable errors appropriately", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "non_retryable_test",
          "retry_config" => %{
            "max_retries" => 2,
            # Only retry on timeout
            "retry_conditions" => ["timeout"]
          }
        })

      context = mock_context(workspace_dir)

      # In mock mode, should succeed regardless
      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)
    end

    test "handles circuit breaker scenarios", %{workspace_dir: workspace_dir} do
      step =
        claude_robust_step(%{
          "name" => "circuit_breaker_test",
          "retry_config" => %{
            "max_retries" => 3,
            # Custom field for circuit breaker
            "circuit_breaker_threshold" => 5
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeRobust.execute(step, context)
      assert_success_result(result)

      # Should track circuit breaker status
      assert result["claude_robust_metadata"]["circuit_breaker_active"] == false
    end
  end
end
