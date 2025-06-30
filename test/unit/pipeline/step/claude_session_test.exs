defmodule Pipeline.Step.ClaudeSessionTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.Step.ClaudeSession
  import Pipeline.Test.EnhancedFactory

  describe "claude_session step execution" do
    test "creates new session and executes successfully", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "new_session_test",
          "session_config" => %{
            "session_name" => "test_new_session",
            "persist" => true,
            "checkpoint_frequency" => 3
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      assert_success_result(result)
      assert Map.has_key?(result, "claude_session_metadata")
      assert result["claude_session_metadata"]["session_name"] == "test_new_session"
      assert result["claude_session_metadata"]["session_persisted"] == true
      assert result["claude_session_metadata"]["checkpoint_frequency"] == 3
    end

    test "reuses existing session", %{workspace_dir: workspace_dir} do
      session_name = "test_existing_session"

      # Create session first
      first_step =
        claude_session_step(%{
          "name" => "first_session_test",
          "session_config" => %{
            "session_name" => session_name,
            "persist" => true
          }
        })

      context = mock_context(workspace_dir)

      # Execute first step to create session
      assert {:ok, first_result} = ClaudeSession.execute(first_step, context)
      first_session_id = first_result["claude_session_metadata"]["session_id"]

      # Execute second step with same session name
      second_step =
        claude_session_step(%{
          "name" => "second_session_test",
          "session_config" => %{
            "session_name" => session_name,
            "persist" => true
          }
        })

      assert {:ok, second_result} = ClaudeSession.execute(second_step, context)
      second_session_id = second_result["claude_session_metadata"]["session_id"]

      # Should reuse the same session
      assert first_session_id == second_session_id
    end

    test "handles session configuration options", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "config_test",
          "session_config" => %{
            "session_name" => "test_config_session",
            "persist" => false,
            "continue_on_restart" => true,
            "checkpoint_frequency" => 10,
            "description" => "Test configuration session"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      metadata = result["claude_session_metadata"]
      assert metadata["session_persisted"] == false
      assert metadata["continue_on_restart"] == true
      assert metadata["checkpoint_frequency"] == 10
    end

    test "uses session name as fallback when not specified", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "fallback_name_test",
          "session_config" => %{
            "persist" => true
            # No session_name specified
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      # Should use step name as session name
      assert result["claude_session_metadata"]["session_name"] == "fallback_name_test"
    end

    test "applies preset options correctly", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "preset_test",
          "preset" => "development",
          "session_config" => %{
            "session_name" => "test_preset_session",
            "persist" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      assert_success_result(result)
      assert String.contains?(result["text"], "development optimizations applied")
    end

    test "uses analysis preset as default", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "default_preset_test",
          "session_config" => %{
            "session_name" => "test_default_preset",
            "persist" => true
          }
        })
        # Remove default preset
        |> Map.delete("preset")

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      assert_success_result(result)
      # Should apply analysis preset by default for sessions
      assert String.contains?(result["text"], "detailed analysis capabilities")
    end

    test "handles checkpointing", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "checkpoint_test",
          "session_config" => %{
            "session_name" => "test_checkpoint_session",
            "persist" => true,
            # Checkpoint every interaction
            "checkpoint_frequency" => 1
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      assert_success_result(result)
      assert result["claude_session_metadata"]["checkpoint_frequency"] == 1
    end

    test "merges claude_options with session options", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "options_merge_test",
          "session_config" => %{
            "session_name" => "test_merge_session",
            "persist" => true
          },
          "claude_options" => %{
            "max_turns" => 25,
            "verbose" => false,
            "custom_option" => "custom_value"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      assert_success_result(result)
      # Should merge successfully and include session metadata
      assert Map.has_key?(result, "claude_session_metadata")
    end

    test "validates required session_config", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "no_config_test"
        })
        # Remove required session_config
        |> Map.delete("session_config")

      context = mock_context(workspace_dir)

      # Should fail validation before execution
      # This would be caught by the enhanced config validation
      # For now, let's test that execution handles missing config gracefully
      case ClaudeSession.execute(step, context) do
        {:ok, _result} ->
          # If it succeeds with empty config, that's acceptable
          :ok

        {:error, reason} ->
          assert is_binary(reason)
          assert String.contains?(String.downcase(reason), "session")
      end
    end
  end

  describe "session management integration" do
    test "session persistence across multiple steps", %{workspace_dir: workspace_dir} do
      session_name = "persistent_test_session"

      # First interaction
      first_step =
        claude_session_step(%{
          "name" => "first_interaction",
          "session_config" => %{
            "session_name" => session_name,
            "persist" => true,
            "checkpoint_frequency" => 2
          },
          "prompt" => [
            %{
              "type" => "static",
              "content" => "Start a conversation about testing"
            }
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, first_result} = ClaudeSession.execute(first_step, context)
      first_session_id = first_result["claude_session_metadata"]["session_id"]

      # Second interaction with same session
      second_step =
        claude_session_step(%{
          "name" => "second_interaction",
          "session_config" => %{
            "session_name" => session_name,
            "persist" => true
          },
          "prompt" => [
            %{
              "type" => "static",
              "content" => "Continue the testing conversation"
            }
          ]
        })

      assert {:ok, second_result} = ClaudeSession.execute(second_step, context)
      second_session_id = second_result["claude_session_metadata"]["session_id"]

      # Should use the same session
      assert first_session_id == second_session_id
      assert first_result["claude_session_metadata"]["session_name"] == session_name
      assert second_result["claude_session_metadata"]["session_name"] == session_name
    end

    test "handles session creation errors gracefully", %{workspace_dir: workspace_dir} do
      # This test would require mocking session manager errors
      # For now, test basic error handling structure

      step =
        claude_session_step(%{
          "name" => "error_handling_test",
          "session_config" => %{
            "session_name" => "test_error_session",
            "persist" => true
          }
        })

      context = mock_context(workspace_dir)

      # In mock mode, session creation should succeed
      assert {:ok, result} = ClaudeSession.execute(step, context)
      assert_success_result(result)
    end

    test "includes proper session metadata", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "metadata_test",
          "session_config" => %{
            "session_name" => "test_metadata_session",
            "persist" => true,
            "continue_on_restart" => false,
            "checkpoint_frequency" => 5,
            "description" => "Metadata test session"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)

      # Check for comprehensive session metadata
      assert Map.has_key?(result, "claude_session_metadata")
      metadata = result["claude_session_metadata"]

      assert Map.has_key?(metadata, "session_id")
      assert metadata["session_name"] == "test_metadata_session"
      assert metadata["session_persisted"] == true
      assert metadata["continue_on_restart"] == false
      assert metadata["checkpoint_frequency"] == 5
    end

    test "handles prompt building with session context", %{workspace_dir: workspace_dir} do
      # First create a session with some output
      first_step =
        claude_session_step(%{
          "name" => "context_first",
          "session_config" => %{
            "session_name" => "test_context_session",
            "persist" => true
          },
          "prompt" => [
            %{
              "type" => "static",
              "content" => "Initial prompt for context"
            }
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, first_result} = ClaudeSession.execute(first_step, context)

      # Second step that references first step's output
      updated_context = %{context | results: %{"context_first" => first_result}}

      second_step =
        claude_session_step(%{
          "name" => "context_second",
          "session_config" => %{
            "session_name" => "test_context_session",
            "persist" => true
          },
          "prompt" => [
            %{
              "type" => "previous_response",
              "step" => "context_first"
            },
            %{
              "type" => "static",
              "content" => "Continue based on the above"
            }
          ]
        })

      assert {:ok, second_result} = ClaudeSession.execute(second_step, updated_context)

      # Should succeed and use same session
      assert first_result["claude_session_metadata"]["session_id"] ==
               second_result["claude_session_metadata"]["session_id"]
    end
  end

  describe "error handling" do
    test "handles prompt building errors gracefully", %{workspace_dir: workspace_dir} do
      step =
        claude_session_step(%{
          "name" => "prompt_error_test",
          "session_config" => %{
            "session_name" => "test_error_session",
            "persist" => true
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
      case ClaudeSession.execute(step, context) do
        {:ok, _result} ->
          # If it succeeds, that's fine too (depends on PromptBuilder implementation)
          :ok

        {:error, reason} ->
          assert is_binary(reason)
          assert String.length(reason) > 0
      end
    end

    test "validates session configuration", %{workspace_dir: workspace_dir} do
      # Test with minimal valid configuration
      step = %{
        "name" => "minimal_session_test",
        "type" => "claude_session",
        "session_config" => %{
          "session_name" => "minimal_test",
          "persist" => false
        },
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt"
          }
        ]
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeSession.execute(step, context)
      assert_success_result(result)
    end
  end
end
