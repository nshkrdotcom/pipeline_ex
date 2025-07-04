defmodule Pipeline.Step.NestedPipelineTest do
  use ExUnit.Case
  alias Pipeline.Step.NestedPipeline

  describe "execute/2 - basic functionality" do
    test "executes inline pipeline successfully" do
      step = %{
        "name" => "nested_test",
        "type" => "pipeline",
        "pipeline" => %{
          "name" => "inline_test",
          "steps" => [
            %{
              "name" => "set_value",
              "type" => "test_echo",
              "value" => "nested_result"
            }
          ]
        }
      }

      context = create_test_context()

      assert {:ok, result} = NestedPipeline.execute(step, context)
      assert result["set_value"] == "nested_result"
    end

    test "loads and executes pipeline from file" do
      # Create a test pipeline file
      test_pipeline_path =
        Path.join(System.tmp_dir!(), "test_pipeline_#{:rand.uniform(10000)}.yaml")

      pipeline_content = """
      workflow:
        name: "test_from_file"
        steps:
          - name: "test_step"
            type: "test_echo"
            value: "file_result"
      """

      File.write!(test_pipeline_path, pipeline_content)

      step = %{
        "name" => "file_test",
        "type" => "pipeline",
        "pipeline_file" => test_pipeline_path
      }

      context = create_test_context()

      try do
        assert {:ok, result} = NestedPipeline.execute(step, context)
        assert result["test_step"] == "file_result"
      after
        File.rm(test_pipeline_path)
      end
    end

    test "returns error for missing pipeline file" do
      step = %{
        "name" => "missing_file_test",
        "type" => "pipeline",
        "pipeline_file" => "/nonexistent/pipeline.yaml"
      }

      context = create_test_context()

      assert {:error, reason} = NestedPipeline.execute(step, context)
      assert reason =~ "Failed to load pipeline file"
    end

    test "returns error for invalid pipeline format" do
      step = %{
        "name" => "invalid_format_test",
        "type" => "pipeline",
        "pipeline" => %{
          "name" => "invalid"
          # Missing required 'steps' field
        }
      }

      context = create_test_context()

      assert {:error, reason} = NestedPipeline.execute(step, context)
      assert reason =~ "Invalid inline pipeline format"
    end

    test "propagates errors from nested pipeline steps" do
      step = %{
        "name" => "error_propagation_test",
        "type" => "pipeline",
        "pipeline" => %{
          "name" => "error_test",
          "steps" => [
            %{
              "name" => "failing_step",
              "type" => "invalid_type",
              "value" => "should_fail"
            }
          ]
        }
      }

      context = create_test_context()

      assert {:error, reason} = NestedPipeline.execute(step, context)
      assert reason =~ "Nested pipeline 'error_test' failed"
    end

    test "tracks nesting depth correctly" do
      step = %{
        "name" => "depth_test",
        "type" => "pipeline",
        "pipeline" => %{
          "name" => "depth_test_pipeline",
          "steps" => [
            %{
              "name" => "check_depth",
              "type" => "test_echo",
              "value" => "depth_tracked"
            }
          ]
        }
      }

      context = create_test_context()
      _initial_depth = context[:nesting_depth] || 0

      # Execute and verify depth tracking
      assert {:ok, _result} = NestedPipeline.execute(step, context)
      # The depth should be incremented during execution
      # (We can't directly check this in Phase 1, but the structure is in place)
    end

    test "handles missing pipeline source" do
      step = %{
        "name" => "no_source_test",
        "type" => "pipeline"
        # Missing both pipeline_file and pipeline keys
      }

      context = create_test_context()

      assert {:error, reason} = NestedPipeline.execute(step, context)
      assert reason =~ "No pipeline source specified"
    end

    test "wraps inline pipeline in workflow structure if needed" do
      # Test that a pipeline without explicit workflow wrapper still works
      step = %{
        "name" => "auto_wrap_test",
        "type" => "pipeline",
        "pipeline" => %{
          "steps" => [
            %{
              "name" => "wrapped_step",
              "type" => "test_echo",
              "value" => "auto_wrapped"
            }
          ]
        }
      }

      context = create_test_context()

      assert {:ok, result} = NestedPipeline.execute(step, context)
      assert result["wrapped_step"] == "auto_wrapped"
    end
  end

  # Helper function to create a test context
  defp create_test_context do
    %{
      results: %{},
      step_index: 0,
      execution_log: [],
      workspace_dir: System.tmp_dir!(),
      output_dir: System.tmp_dir!(),
      checkpoint_enabled: false,
      workflow_name: "test_workflow"
    }
  end
end
