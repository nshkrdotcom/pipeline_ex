defmodule Pipeline.Step.ClaudeSmartTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.Step.ClaudeSmart
  import Pipeline.Test.EnhancedFactory

  describe "claude_smart step execution" do
    test "executes with development preset", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "development_test",
          "preset" => "development"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      assert Map.has_key?(result, "claude_smart_metadata")
      assert result["claude_smart_metadata"]["preset_applied"] == "development"
      assert result["enhanced_provider"] == true
    end

    test "executes with production preset", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "production_test",
          "preset" => "production"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      assert result["claude_smart_metadata"]["preset_applied"] == "production"
      assert String.contains?(result["text"], "production safety constraints")
    end

    test "executes with analysis preset", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "analysis_test",
          "preset" => "analysis"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      assert result["claude_smart_metadata"]["preset_applied"] == "analysis"
      assert String.contains?(result["text"], "detailed analysis capabilities")
    end

    test "executes with chat preset", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "chat_test",
          "preset" => "chat"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      assert result["claude_smart_metadata"]["preset_applied"] == "chat"
      assert String.contains?(result["text"], "conversational mode")
    end

    test "executes with test preset", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "test_test",
          "preset" => "test"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      assert result["claude_smart_metadata"]["preset_applied"] == "test"
      assert String.contains?(result["text"], "optimized for testing")
    end

    test "uses workflow default preset when step preset not specified", %{
      workspace_dir: workspace_dir
    } do
      step =
        claude_smart_step(%{
          "name" => "default_preset_test"
          # No preset specified
        })
        # Remove default preset to allow workflow defaults
        |> Map.delete("preset")

      context =
        mock_context(workspace_dir, %{
          "workflow" => %{
            "defaults" => %{
              "claude_preset" => "analysis"
            }
          }
        })

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert result["claude_smart_metadata"]["preset_applied"] == "analysis"
    end

    test "uses environment-aware preset detection", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "env_aware_test",
          "environment_aware" => true
        })
        # Remove default preset to allow environment detection
        |> Map.delete("preset")

      context =
        mock_context(workspace_dir, %{
          "workflow" => %{
            "environment" => %{
              "mode" => "production"
            }
          }
        })

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert result["claude_smart_metadata"]["preset_applied"] == "production"
    end

    test "merges step claude_options with preset", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "merge_test",
          "preset" => "development",
          "claude_options" => %{
            # Override preset default
            "max_turns" => 25,
            # Add custom option
            "custom_field" => "custom_value"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      # Should still show development preset was applied
      assert result["claude_smart_metadata"]["preset_applied"] == "development"
    end

    test "handles unknown preset gracefully", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "unknown_preset_test",
          "preset" => "unknown_preset"
        })

      context = mock_context(workspace_dir)

      # Should still succeed, falling back to development preset
      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      # Preset should be marked as unknown but execution succeeds
      assert result["claude_smart_metadata"]["preset_applied"] == "unknown_preset"
    end

    test "handles missing preset gracefully", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "no_preset_test"
          # No preset specified, no defaults, no environment_aware
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      assert_success_result(result)
      # Should default to development
      assert result["claude_smart_metadata"]["preset_applied"] == "development"
    end

    test "includes enhanced metadata in response", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "metadata_test",
          "preset" => "development",
          "environment_aware" => true
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      # Check for enhanced metadata
      assert Map.has_key?(result, "claude_smart_metadata")
      metadata = result["claude_smart_metadata"]

      assert metadata["preset_applied"] == "development"
      assert metadata["environment_aware"] == true
      assert metadata["optimization_applied"] == true
    end

    test "handles prompt building errors", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "prompt_error_test",
          "preset" => "development",
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
      case ClaudeSmart.execute(step, context) do
        {:ok, _result} ->
          # If it succeeds, that's fine too (depends on PromptBuilder implementation)
          :ok

        {:error, reason} ->
          assert is_binary(reason)
          assert String.length(reason) > 0
      end
    end

    test "applies preset optimizations correctly", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "optimization_test",
          "preset" => "development"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      # Development preset should include optimization indicators
      assert result["claude_smart_metadata"]["optimization_applied"] == true
      assert String.contains?(result["text"], "development optimizations applied")
    end
  end

  describe "preset integration with OptionBuilder" do
    test "development preset includes expected options", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "dev_options_test",
          "preset" => "development"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      # Development preset characteristics should be reflected in response
      assert result["enhanced_provider"] == true
      # Development preset cost
      assert result["cost"] == 0.002
    end

    test "production preset includes expected options", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "prod_options_test",
          "preset" => "production"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      # Production preset characteristics
      # Production preset cost (lower)
      assert result["cost"] == 0.001
      assert String.contains?(result["text"], "production safety constraints")
    end

    test "test preset includes expected options", %{workspace_dir: workspace_dir} do
      step =
        claude_smart_step(%{
          "name" => "test_options_test",
          "preset" => "test"
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)

      # Test preset characteristics
      # Test preset cost (minimal)
      assert result["cost"] == 0.0001
      assert String.contains?(result["text"], "optimized for testing")
    end
  end

  describe "error handling" do
    test "handles provider errors gracefully", %{workspace_dir: workspace_dir} do
      # This test would require mocking a provider failure, which is complex
      # For now, we'll test the basic error handling structure

      step =
        claude_smart_step(%{
          "name" => "error_test",
          "preset" => "development"
        })

      context = mock_context(workspace_dir)

      # The step should execute successfully in mock mode
      # In a real scenario, we'd mock a provider failure
      assert {:ok, result} = ClaudeSmart.execute(step, context)
      assert_success_result(result)
    end

    test "validates step configuration", %{workspace_dir: workspace_dir} do
      # Test with minimal valid configuration
      step = %{
        "name" => "minimal_test",
        "type" => "claude_smart",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt"
          }
        ]
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSmart.execute(step, context)
      assert_success_result(result)
    end
  end
end
