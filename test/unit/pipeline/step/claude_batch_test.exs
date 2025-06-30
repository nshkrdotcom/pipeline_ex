defmodule Pipeline.Step.ClaudeBatchTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.Step.ClaudeBatch
  import Pipeline.Test.EnhancedFactory

  describe "claude_batch step execution" do
    test "executes with basic batch config", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "basic_batch_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "timeout_per_task" => 30_000,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "test1.py", "prompt" => "Analyze this file"},
            %{"file" => "test2.py", "prompt" => "Check for issues"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      assert result["batch_processed"] == true
      assert result["total_tasks"] == 2
      assert Map.has_key?(result, "batch_results")
      assert Map.has_key?(result, "claude_batch_metadata")
    end

    test "executes with file-based tasks", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "file_batch_test",
          "batch_config" => %{
            "max_parallel" => 3,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "src/module1.py"},
            %{"file" => "src/module2.py"},
            %{"file" => "src/module3.py"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      assert result["total_tasks"] == 3
      assert length(result["batch_results"]) == 3

      # Check that files are properly tracked
      metadata = result["claude_batch_metadata"]
      assert length(metadata["files_processed"]) == 3
      assert "src/module1.py" in metadata["files_processed"]
    end

    test "executes with custom prompts per task", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "custom_prompt_batch_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => true
          },
          "tasks" => [
            %{
              "prompt" => [
                %{"type" => "static", "content" => "Analyze code quality"}
              ]
            },
            %{
              "prompt" => [
                %{"type" => "static", "content" => "Check security issues"}
              ]
            }
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      assert result["total_tasks"] == 2
      assert result["successful_tasks"] == 2
    end

    test "works without tasks specified", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "no_tasks_test",
          "batch_config" => %{
            "max_parallel" => 1,
            "consolidate_results" => true
          }
        })
        # Remove tasks
        |> Map.delete("tasks")

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      # Should create one default task
      assert result["total_tasks"] == 1
      assert result["successful_tasks"] == 1
    end

    test "handles different batch configuration options", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "config_options_test",
          "batch_config" => %{
            "max_parallel" => 5,
            "timeout_per_task" => 45_000,
            "consolidate_results" => false
          },
          "tasks" => [
            %{"file" => "test.py", "prompt" => "Analyze"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      # Assert batch-specific success indicators
      assert result["success"] == true
      assert result["batch_processed"] == true
      assert Map.has_key?(result, "batch_results")

      # With consolidate_results=false, should not have consolidated text
      refute Map.has_key?(result, "text")
      refute Map.has_key?(result, "claude_batch_metadata")
    end

    test "applies preset options correctly", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "preset_test",
          "preset" => "development",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "test.py", "prompt" => "Analyze"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      # Should apply development preset (mock provider checks for this)
      task_result = List.first(result["batch_results"])
      assert task_result["status"] == "success"
      assert String.contains?(task_result["result"]["text"], "development optimizations applied")
    end

    test "uses development preset as default", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "default_preset_test",
          "batch_config" => %{
            "max_parallel" => 1,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "test.py", "prompt" => "Analyze"}
          ]
        })
        # Remove default preset
        |> Map.delete("preset")

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      # Should apply development preset by default for batch processing
      task_result = List.first(result["batch_results"])
      assert String.contains?(task_result["result"]["text"], "development optimizations applied")
    end
  end

  describe "parallel processing features" do
    test "processes multiple tasks in parallel", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "parallel_test",
          "batch_config" => %{
            "max_parallel" => 3,
            "timeout_per_task" => 30_000,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "file1.py", "prompt" => "Analyze file 1"},
            %{"file" => "file2.py", "prompt" => "Analyze file 2"},
            %{"file" => "file3.py", "prompt" => "Analyze file 3"},
            %{"file" => "file4.py", "prompt" => "Analyze file 4"}
          ]
        })

      context = mock_context(workspace_dir)

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, result} = ClaudeBatch.execute(step, context)
      end_time = System.monotonic_time(:millisecond)

      assert_success_result(result)
      assert result["total_tasks"] == 4
      assert result["successful_tasks"] == 4

      # Should complete reasonably quickly due to parallel processing and mocks
      execution_time = end_time - start_time
      # Should be much faster than sequential
      assert execution_time < 5000
    end

    test "respects max_parallel limits", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "parallel_limit_test",
          "batch_config" => %{
            # Force sequential processing
            "max_parallel" => 1,
            "timeout_per_task" => 30_000,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "test1.py"},
            %{"file" => "test2.py"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      assert result["total_tasks"] == 2
      assert result["successful_tasks"] == 2
    end

    test "includes performance statistics", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "performance_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "test1.py"},
            %{"file" => "test2.py"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      assert Map.has_key?(result, "performance_statistics")

      stats = result["performance_statistics"]
      assert Map.has_key?(stats, "total_execution_time_ms")
      assert Map.has_key?(stats, "average_task_time_ms")
      assert Map.has_key?(stats, "min_task_time_ms")
      assert Map.has_key?(stats, "max_task_time_ms")
    end

    test "handles task failures gracefully", %{workspace_dir: workspace_dir} do
      # This test simulates what would happen if some tasks failed
      # In mock mode, tasks generally succeed, but we test the structure

      step =
        claude_batch_step(%{
          "name" => "failure_handling_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "good_file.py", "prompt" => "Analyze"},
            %{"file" => "bad_file.py", "prompt" => "Analyze"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      # Even if some tasks fail, the batch should complete
      assert_success_result(result)
      assert result["total_tasks"] == 2

      # Should track successful and failed tasks
      assert Map.has_key?(result, "successful_tasks")
      assert Map.has_key?(result, "failed_tasks")
    end
  end

  describe "result consolidation" do
    test "consolidates results when enabled", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "consolidation_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "module1.py", "prompt" => "Analyze"},
            %{"file" => "module2.py", "prompt" => "Check quality"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)

      # Should have consolidated text
      assert Map.has_key?(result, "text")
      assert String.contains?(result["text"], "# Batch Processing Results")
      assert String.contains?(result["text"], "module1.py")
      assert String.contains?(result["text"], "module2.py")

      # Should have metadata
      assert Map.has_key?(result, "claude_batch_metadata")
      metadata = result["claude_batch_metadata"]
      assert metadata["step_name"] == "consolidation_test"
      assert Map.has_key?(metadata, "batch_processed_at")
    end

    test "skips consolidation when disabled", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "no_consolidation_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => false
          },
          "tasks" => [
            %{"file" => "test.py", "prompt" => "Analyze"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      # Assert batch-specific success indicators
      assert result["success"] == true
      assert result["batch_processed"] == true
      assert Map.has_key?(result, "batch_results")

      # Should NOT have consolidated text or metadata
      refute Map.has_key?(result, "text")
      refute Map.has_key?(result, "claude_batch_metadata")

      # But should still have batch results
      assert Map.has_key?(result, "batch_results")
    end

    test "includes comprehensive batch metadata", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "metadata_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "src/main.py", "prompt" => "Analyze"},
            %{"file" => "src/utils.py", "prompt" => "Review"},
            %{"file" => "tests/test_main.py", "prompt" => "Check tests"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)

      metadata = result["claude_batch_metadata"]
      assert metadata["step_name"] == "metadata_test"
      assert metadata["total_tasks"] == 3

      # Should track task breakdown
      task_breakdown = metadata["task_breakdown"]
      assert Map.has_key?(task_breakdown, "successful")
      assert Map.has_key?(task_breakdown, "failed")
      assert Map.has_key?(task_breakdown, "timeout")

      # Should track files processed
      files_processed = metadata["files_processed"]
      assert "src/main.py" in files_processed
      assert "src/utils.py" in files_processed
      assert "tests/test_main.py" in files_processed
    end
  end

  describe "integration with other features" do
    test "works with prompt building from previous steps", %{workspace_dir: workspace_dir} do
      # First create a step with some output
      first_step =
        claude_batch_step(%{
          "name" => "context_first",
          "batch_config" => %{
            "max_parallel" => 1,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "setup.py", "prompt" => "Analyze setup"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:ok, first_result} = ClaudeBatch.execute(first_step, context)

      # Second step that could reference first step's output in tasks
      updated_context = %{context | results: %{"context_first" => first_result}}

      second_step =
        claude_batch_step(%{
          "name" => "context_second",
          "batch_config" => %{
            "max_parallel" => 1,
            "consolidate_results" => true
          },
          "tasks" => [
            %{
              "prompt" => [
                %{"type" => "static", "content" => "Based on previous batch results, analyze:"},
                %{"type" => "file", "path" => "new_file.py"}
              ]
            }
          ]
        })

      assert {:ok, second_result} = ClaudeBatch.execute(second_step, updated_context)

      # Should succeed and process batch
      assert_success_result(second_result)
      assert second_result["batch_processed"] == true
    end

    test "merges claude_options with batch options", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "options_merge_test",
          "batch_config" => %{
            "max_parallel" => 2,
            "consolidate_results" => true
          },
          "tasks" => [
            %{"file" => "test.py", "prompt" => "Analyze"}
          ],
          "claude_options" => %{
            "max_turns" => 25,
            "verbose" => false,
            "custom_option" => "custom_value"
          }
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      # Should merge successfully and process batch
      assert result["batch_processed"] == true
    end
  end

  describe "error handling" do
    test "handles invalid batch configuration", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "invalid_config_test",
          "batch_config" => %{
            # Invalid: must be positive
            "max_parallel" => 0,
            # Invalid: must be positive
            "timeout_per_task" => -1000
          },
          "tasks" => [
            %{"file" => "test.py"}
          ]
        })

      context = mock_context(workspace_dir)

      assert {:error, reason} = ClaudeBatch.execute(step, context)
      assert String.contains?(reason, "max_parallel")
    end

    test "handles prompt building errors gracefully", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "prompt_error_test",
          "batch_config" => %{
            "max_parallel" => 1,
            "consolidate_results" => true
          },
          "tasks" => [
            %{
              "prompt" => [
                %{
                  "type" => "previous_response",
                  # This should cause an error
                  "step" => "nonexistent_step"
                }
              ]
            }
          ]
        })

      # Empty results
      context = mock_context(workspace_dir, %{}, %{})

      # Should handle prompt building errors gracefully
      case ClaudeBatch.execute(step, context) do
        {:ok, result} ->
          # If it succeeds, check that errors are properly tracked
          assert result["batch_processed"] == true
          # May have failed tasks due to prompt errors
          :ok

        {:error, reason} ->
          assert is_binary(reason)
          assert String.length(reason) > 0
      end
    end

    test "validates minimal configuration", %{workspace_dir: workspace_dir} do
      # Test with minimal valid configuration
      step = %{
        "name" => "minimal_batch_test",
        "type" => "claude_batch",
        "tasks" => [
          %{"file" => "test.py"}
        ]
      }

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)
      assert_success_result(result)
    end

    test "handles empty tasks list", %{workspace_dir: workspace_dir} do
      step =
        claude_batch_step(%{
          "name" => "empty_tasks_test",
          "batch_config" => %{
            "max_parallel" => 1
          },
          # Empty tasks
          "tasks" => []
        })

      context = mock_context(workspace_dir)

      assert {:ok, result} = ClaudeBatch.execute(step, context)

      assert_success_result(result)
      # Should create one default task
      assert result["total_tasks"] == 1
    end
  end
end
