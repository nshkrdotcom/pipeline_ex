defmodule Pipeline.Error.NestedPipelineTest do
  use ExUnit.Case, async: true

  alias Pipeline.Error.NestedPipeline
  alias Pipeline.Safety.RecursionGuard

  describe "format_nested_error/3" do
    test "formats basic nested pipeline error with context" do
      context = %{
        pipeline_id: "test_pipeline",
        nesting_depth: 2,
        parent_context: %{
          pipeline_id: "parent_pipeline",
          nesting_depth: 1,
          parent_context: %{
            pipeline_id: "root_pipeline",
            nesting_depth: 0,
            parent_context: nil
          }
        },
        start_time: DateTime.utc_now(),
        step_index: 3
      }

      step = %{"name" => "failing_step", "type" => "claude"}
      error = "API timeout error"

      result = NestedPipeline.format_nested_error(error, context, step)

      assert result.message =~ "Pipeline execution failed in nested pipeline"
      assert result.message =~ "API timeout error"
      assert result.message =~ "test_pipeline"
      assert result.message =~ "failing_step"
      assert result.message =~ "Nesting Depth: 2"
      assert result.context.pipeline_id == "test_pipeline"
      assert result.context.step_name == "failing_step"
      assert length(result.stack_trace) == 3
    end

    test "handles error tuple format" do
      context = %{
        pipeline_id: "test_pipeline",
        nesting_depth: 1,
        parent_context: nil,
        start_time: DateTime.utc_now()
      }

      error = {:error, "Network connection failed"}

      result = NestedPipeline.format_nested_error(error, context)

      assert result.message =~ "Network connection failed"
      assert result.debug_info.error_classification == :unknown
    end

    test "handles missing step information gracefully" do
      context = %{
        pipeline_id: "test_pipeline",
        nesting_depth: 0,
        parent_context: nil,
        start_time: DateTime.utc_now()
      }

      result = NestedPipeline.format_nested_error("Some error", context, nil)

      assert result.context.step_name == nil
      assert result.message =~ "Step: unknown"
    end

    test "includes execution chain in hierarchy format" do
      context = %{
        pipeline_id: "child",
        nesting_depth: 1,
        parent_context: %{
          pipeline_id: "parent",
          nesting_depth: 0,
          parent_context: nil
        },
        start_time: DateTime.utc_now()
      }

      result = NestedPipeline.format_nested_error("Error", context)

      assert result.hierarchy =~ "Main Pipeline: parent"
      assert result.hierarchy =~ "└─ Nested Pipeline: child"
      assert result.message =~ "1. parent (depth: 0)"
      assert result.message =~ "2. child (depth: 1)"
    end
  end

  describe "format_timeout_error/3" do
    test "formats timeout error with context" do
      context = %{
        pipeline_id: "slow_pipeline",
        nesting_depth: 1,
        parent_context: %{pipeline_id: "parent", nesting_depth: 0, parent_context: nil}
      }

      result = NestedPipeline.format_timeout_error(30, context, 45_000)

      assert result =~ "Pipeline execution timeout"
      assert result =~ "Limit: 30s"
      assert result =~ "Actual: 45.0s"
      assert result =~ "Exceeded by: 15.0s"
      assert result =~ "slow_pipeline"
      assert result =~ "This timeout may indicate"
    end

    test "provides timeout troubleshooting guidance" do
      context = %{pipeline_id: "test", nesting_depth: 0, parent_context: nil}

      result = NestedPipeline.format_timeout_error(10, context, 15_000)

      assert result =~ "Long-running AI model calls"
      assert result =~ "Network connectivity issues"
      assert result =~ "timeout configuration adjustment"
    end
  end

  describe "format_circular_dependency_error/2" do
    test "formats circular dependency with full chain" do
      context = %{
        pipeline_id: "pipeline_b",
        nesting_depth: 2,
        parent_context: %{
          pipeline_id: "pipeline_a",
          nesting_depth: 1,
          parent_context: %{
            pipeline_id: "root",
            nesting_depth: 0,
            parent_context: nil
          }
        }
      }

      circular_chain = ["pipeline_a", "pipeline_b", "pipeline_a"]

      result = NestedPipeline.format_circular_dependency_error(circular_chain, context)

      assert result =~ "Circular dependency detected"
      assert result =~ "pipeline_a → pipeline_b → pipeline_a"
      assert result =~ "Resolution Steps"
      assert result =~ "Review pipeline dependencies"
      assert result =~ "Detection Point: Attempting to call 'pipeline_a'"
    end

    test "includes resolution guidance" do
      context = %{pipeline_id: "test", nesting_depth: 1, parent_context: nil}
      circular_chain = ["a", "b", "a"]

      result = NestedPipeline.format_circular_dependency_error(circular_chain, context)

      assert result =~ "conditional logic to break cycles"
      assert result =~ "pipeline_file and pipeline_ref configurations"
    end
  end

  describe "format_resource_limit_error/4" do
    test "formats memory limit error" do
      context = %{
        pipeline_id: "memory_heavy",
        nesting_depth: 2,
        parent_context: nil
      }

      result = NestedPipeline.format_resource_limit_error(:memory, 2048, 1024, context)

      assert result =~ "Resource limit exceeded"
      assert result =~ "Memory usage: 2048MB > 1024MB limit"
      assert result =~ "memory-intensive operations"
      assert result =~ "memory_limit_mb in configuration"
    end

    test "formats depth limit error with recommendations" do
      context = %{pipeline_id: "deep_nested", nesting_depth: 12, parent_context: nil}

      result = NestedPipeline.format_resource_limit_error(:depth, 12, 10, context)

      assert result =~ "Nesting depth: 12 > 10 levels"
      assert result =~ "Reduce pipeline nesting levels"
      assert result =~ "flattening nested pipeline structures"
    end

    test "formats step count limit error" do
      context = %{pipeline_id: "step_heavy", nesting_depth: 1, parent_context: nil}

      result = NestedPipeline.format_resource_limit_error(:steps, 1500, 1000, context)

      assert result =~ "Total steps: 1500 > 1000 steps"
      assert result =~ "Optimize pipeline step count"
      assert result =~ "parallel execution for independent operations"
    end
  end

  describe "create_debug_log_entry/3" do
    test "creates comprehensive debug log entry" do
      context = %{
        pipeline_id: "debug_test",
        nesting_depth: 2,
        start_time: DateTime.utc_now(),
        results: %{"step1" => "result1"},
        global_vars: %{"var1" => "value1"},
        parent_context: %{pipeline_id: "parent", nesting_depth: 1, parent_context: nil}
      }

      step = %{"name" => "debug_step", "type" => "claude", "config" => %{"timeout" => 30}}
      error = {:error, "Debug test error"}

      result = NestedPipeline.create_debug_log_entry(error, context, step)

      assert result.error_type == :unknown
      assert result.error_message == "Debug test error"
      assert result.pipeline_id == "debug_test"
      assert result.nesting_depth == 2
      assert result.step_name == "debug_step"
      assert result.step_type == "claude"
      assert length(result.execution_chain) == 2
      # RecursionGuard.count_total_steps with mock context
      assert result.total_steps == 0
      assert is_number(result.elapsed_ms)
      assert is_map(result.context_summary)
      assert is_map(result.step_config)
    end

    test "handles minimal context gracefully" do
      context = %{pipeline_id: "minimal"}

      result = NestedPipeline.create_debug_log_entry("Error", context)

      assert result.pipeline_id == "minimal"
      assert result.nesting_depth == 0
      assert result.step_name == nil
      assert result.step_type == nil
      assert result.execution_chain == ["minimal"]
    end

    test "classifies different error types correctly" do
      context = %{pipeline_id: "test"}

      # Test timeout error classification
      timeout_result = NestedPipeline.create_debug_log_entry("Connection timeout", context)
      assert timeout_result.error_type == :timeout

      # Test circular dependency classification
      circular_result =
        NestedPipeline.create_debug_log_entry("Circular dependency detected", context)

      assert circular_result.error_type == :circular_dependency

      # Test resource limit classification
      limit_result = NestedPipeline.create_debug_log_entry("Memory limit exceeded", context)
      assert limit_result.error_type == :resource_limit

      # Test not found classification
      not_found_result = NestedPipeline.create_debug_log_entry("Pipeline not found", context)
      assert not_found_result.error_type == :not_found

      # Test validation classification
      validation_result = NestedPipeline.create_debug_log_entry("Invalid configuration", context)
      assert validation_result.error_type == :validation
    end

    test "sanitizes step configuration properly" do
      context = %{pipeline_id: "test"}

      step = %{
        "name" => "test_step",
        "type" => "claude",
        "prompt" => "sensitive prompt content",
        "config" => %{
          "inherit_context" => true,
          "timeout_seconds" => 30,
          "api_key" => "secret_key",
          "max_depth" => 5
        },
        "sensitive_data" => "should not appear"
      }

      result = NestedPipeline.create_debug_log_entry("Error", context, step)

      # Should include safe fields
      assert result.step_config["name"] == "test_step"
      assert result.step_config["type"] == "claude"
      assert result.step_config["config"]["inherit_context"] == true
      assert result.step_config["config"]["timeout_seconds"] == 30
      assert result.step_config["config"]["max_depth"] == 5

      # Should exclude sensitive fields
      refute Map.has_key?(result.step_config, "prompt")
      refute Map.has_key?(result.step_config, "sensitive_data")
      refute Map.has_key?(result.step_config["config"], "api_key")
    end
  end

  describe "error message extraction" do
    test "extracts message from various error formats" do
      # Test string error
      assert NestedPipeline.create_debug_log_entry("Simple error", %{pipeline_id: "test"}).error_message ==
               "Simple error"

      # Test error tuple
      assert NestedPipeline.create_debug_log_entry({:error, "Tuple error"}, %{pipeline_id: "test"}).error_message ==
               "Tuple error"

      # Test error map
      assert NestedPipeline.create_debug_log_entry({:error, %{message: "Map error"}}, %{
               pipeline_id: "test"
             }).error_message == "Map error"

      # Test exception-like structure
      assert NestedPipeline.create_debug_log_entry(%{message: "Exception error"}, %{
               pipeline_id: "test"
             }).error_message == "Exception error"
    end
  end

  describe "context summarization" do
    test "summarizes context information correctly" do
      context = %{
        pipeline_id: "test",
        nesting_depth: 2,
        results: %{"step1" => "result"},
        global_vars: %{"var1" => "val1"},
        parent_context: %{pipeline_id: "parent", nesting_depth: 1, parent_context: nil},
        extra_field: "extra"
      }

      result = NestedPipeline.create_debug_log_entry("Error", context)
      summary = result.context_summary

      assert summary.has_parent == true
      # Number of fields in context map
      assert summary.context_size == 6
      assert summary.key_count == 6
      assert summary.nesting_depth == 2
    end

    test "handles context without parent" do
      context = %{pipeline_id: "test", nesting_depth: 0}

      result = NestedPipeline.create_debug_log_entry("Error", context)
      summary = result.context_summary

      assert summary.has_parent == false
      assert summary.nesting_depth == 0
    end
  end
end
