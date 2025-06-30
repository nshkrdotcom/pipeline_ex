defmodule Pipeline.Step.ClaudeExtractTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.Step.ClaudeExtract
  import Pipeline.Test.EnhancedFactory

  describe "claude_extract step execution" do
    test "executes with basic extraction config", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "basic_extract_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "text",
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      assert result["extraction_applied"] == true
      assert Map.has_key?(result, "extraction_metadata")
      assert result["extraction_metadata"]["format"] == "text"
    end

    test "executes with structured format", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "structured_extract_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "structured",
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      assert String.contains?(result["text"], "## Extracted Content")
      assert result["extraction_metadata"]["format"] == "structured"
    end

    test "executes with JSON format", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "json_extract_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "json",
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      # Should be valid JSON
      assert {:ok, _parsed} = Jason.decode(result["text"])
      assert result["extraction_metadata"]["format"] == "json"
    end

    test "executes with summary format and length limit", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "summary_extract_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "summary",
            "max_summary_length" => 100,
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      assert String.length(result["text"]) <= 100
      assert result["extraction_metadata"]["format"] == "summary"
    end

    test "executes with markdown format", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "markdown_extract_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "markdown",
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      assert String.contains?(result["text"], "# Extracted Content")
      assert result["extraction_metadata"]["format"] == "markdown"
    end

    test "applies post-processing operations", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "post_processing_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "structured",
            "post_processing" => ["extract_code_blocks", "extract_recommendations"],
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      metadata = result["extraction_metadata"]
      assert "extract_code_blocks" in metadata["post_processing_applied"]
      assert "extract_recommendations" in metadata["post_processing_applied"]
    end

    test "works without extraction config", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "no_config_test"
        })
        # Remove extraction config
        |> Map.delete("extraction_config")

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      # Should still work but without extraction features
      assert result["extraction_applied"] == true
    end

    test "uses analysis preset as default", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "default_preset_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "text"
          }
        })
        # Remove default preset
        |> Map.delete("preset")

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      # Should apply analysis preset by default for extraction
      assert String.contains?(result["text"], "detailed analysis capabilities")
    end

    test "applies custom preset correctly", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "custom_preset_test",
          "preset" => "development",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "text"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      assert String.contains?(result["text"], "development optimizations applied")
    end
  end

  describe "content extraction features" do
    test "extracts content with metadata", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "metadata_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "structured",
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      # Check for comprehensive extraction metadata
      assert Map.has_key?(result, "extraction_metadata")
      metadata = result["extraction_metadata"]

      assert metadata["format"] == "structured"
      assert metadata["use_content_extractor"] == true
      assert Map.has_key?(metadata, "extraction_timestamp")
      assert Map.has_key?(metadata, "original_length")
      assert Map.has_key?(metadata, "processed_length")
      assert metadata["step_name"] == "metadata_test"
    end

    test "handles different post-processing operations", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "all_post_processing_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "structured",
            "post_processing" => [
              "extract_code_blocks",
              "extract_recommendations",
              "extract_links",
              "extract_key_points",
              "format_markdown",
              "generate_summary"
            ],
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)

      # All post-processing operations should be recorded
      metadata = result["extraction_metadata"]

      expected_operations = [
        "extract_code_blocks",
        "extract_recommendations",
        "extract_links",
        "extract_key_points",
        "format_markdown",
        "generate_summary"
      ]

      Enum.each(expected_operations, fn op ->
        assert op in metadata["post_processing_applied"]
      end)
    end

    test "preserves original response fields", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "preserve_fields_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "text",
            "include_metadata" => false
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      # Should preserve original response fields from mock provider
      assert_success_result(result)
      assert result["extraction_applied"] == true

      # Original mock response fields should be preserved
      # (These come from the mock provider)
      assert Map.has_key?(result, "success")
    end

    test "handles different content extraction formats", %{workspace_dir: workspace_dir} do
      formats = ["text", "json", "structured", "summary", "markdown"]

      Enum.each(formats, fn format ->
        step =
          claude_extract_step(%{
            "name" => "format_test_#{format}",
            "extraction_config" => %{
              "use_content_extractor" => true,
              "format" => format,
              "include_metadata" => true
            }
          })

        context = mock_context(workspace_dir)

        assert {:ok, result} = ClaudeExtract.execute(step, context)
        assert_success_result(result)
        assert result["extraction_metadata"]["format"] == format

        # Format-specific assertions
        case format do
          "json" ->
            assert {:ok, _} = Jason.decode(result["text"])

          "structured" ->
            assert String.contains?(result["text"], "##")

          "markdown" ->
            assert String.contains?(result["text"], "#")

          _ ->
            assert is_binary(result["text"])
        end
      end)
    end

    test "applies summary length limits correctly", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "length_limit_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "summary",
            "max_summary_length" => 50,
            "include_metadata" => true
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      assert String.length(result["text"]) <= 50
    end
  end

  describe "integration with other features" do
    test "works with prompt building from previous steps", %{workspace_dir: workspace_dir} do
      # First create a step with some output
      first_step =
        claude_extract_step(%{
          "name" => "context_first",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "structured"
          },
          "prompt" => [
            %{
              "type" => "static",
              "content" => "Initial content for extraction"
            }
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, first_result} = ClaudeExtract.execute(first_step, context)

      # Second step that references first step's output
      updated_context = %{context | results: %{"context_first" => first_result}}

      second_step =
        claude_extract_step(%{
          "name" => "context_second",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "json"
          },
          "prompt" => [
            %{
              "type" => "previous_response",
              "step" => "context_first"
            },
            %{
              "type" => "static",
              "content" => "Extract more content from the above"
            }
          ]
        })

      assert {:ok, second_result} = ClaudeExtract.execute(second_step, updated_context)

      # Should succeed and extract content
      assert_success_result(second_result)
      assert second_result["extraction_applied"] == true
    end

    test "merges claude_options with extraction options", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "options_merge_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "structured"
          },
          "claude_options" => %{
            "max_turns" => 25,
            "verbose" => false,
            "custom_option" => "custom_value"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)

      assert_success_result(result)
      # Should merge successfully and apply extraction
      assert result["extraction_applied"] == true
    end
  end

  describe "error handling" do
    test "handles prompt building errors gracefully", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "prompt_error_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "text"
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
      case ClaudeExtract.execute(step, context) do
        {:ok, _result} ->
          # If it succeeds, that's fine too (depends on PromptBuilder implementation)
          :ok

        {:error, reason} ->
          assert is_binary(reason)
          assert String.length(reason) > 0
      end
    end

    test "handles invalid extraction configuration", %{workspace_dir: workspace_dir} do
      # Test with unknown format
      step =
        claude_extract_step(%{
          "name" => "invalid_format_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            # Invalid format
            "format" => "unknown_format"
          }
        })

      context = mock_context(workspace_dir)

      # Should handle gracefully and default to text format
      assert {:ok, result} = ClaudeExtract.execute(step, context)
      assert_success_result(result)
    end

    test "handles unknown post-processing operations", %{workspace_dir: workspace_dir} do
      step =
        claude_extract_step(%{
          "name" => "unknown_post_processing_test",
          "extraction_config" => %{
            "use_content_extractor" => true,
            "format" => "text",
            "post_processing" => ["unknown_operation", "another_unknown"]
          }
        })

      context = mock_context(workspace_dir)

      # Should handle gracefully and skip unknown operations
      assert {:ok, result} = ClaudeExtract.execute(step, context)
      assert_success_result(result)
    end

    test "validates minimal configuration", %{workspace_dir: workspace_dir} do
      # Test with minimal valid configuration
      step = %{
        "name" => "minimal_extract_test",
        "type" => "claude_extract",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Test prompt"
          }
        ]
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeExtract.execute(step, context)
      assert_success_result(result)
    end
  end
end
