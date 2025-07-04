defmodule Pipeline.Tracing.NestedExecutionTest do
  use ExUnit.Case, async: true
  
  alias Pipeline.Tracing.NestedExecution

  describe "start_nested_trace/4" do
    test "creates initial trace context" do
      context = %{
        pipeline_id: "test_pipeline",
        nesting_depth: 0
      }
      
      step = %{"name" => "test_step", "type" => "claude"}
      
      trace_context = NestedExecution.start_nested_trace("test_pipeline", context, step)
      
      assert is_binary(trace_context.trace_id)
      assert is_binary(trace_context.current_span)
      assert map_size(trace_context.spans) == 1
      assert is_struct(trace_context.start_time, DateTime)
      
      span = Map.values(trace_context.spans) |> List.first()
      assert span.pipeline_id == "test_pipeline"
      assert span.step_name == "test_step"
      assert span.step_type == "claude"
      assert span.depth == 0
      assert span.status == :running
      assert span.parent_span == nil
    end

    test "creates nested trace with parent" do
      parent_trace = %{
        trace_id: "parent_trace_id",
        current_span: "parent_span_id",
        spans: %{
          "parent_span_id" => %{
            id: "parent_span_id",
            pipeline_id: "parent_pipeline",
            depth: 0
          }
        },
        start_time: DateTime.utc_now()
      }
      
      context = %{
        pipeline_id: "child_pipeline",
        nesting_depth: 1
      }
      
      trace_context = NestedExecution.start_nested_trace("child_pipeline", context, nil, parent_trace)
      
      assert trace_context.trace_id == "parent_trace_id"
      assert map_size(trace_context.spans) == 2
      assert trace_context.start_time == parent_trace.start_time
      
      # Find the new span
      new_span = Enum.find(Map.values(trace_context.spans), &(&1.pipeline_id == "child_pipeline"))
      assert new_span.parent_span == "parent_span_id"
      assert new_span.depth == 1
    end

    test "collects span metadata from context and step" do
      context = %{
        pipeline_id: "test_pipeline",
        nesting_depth: 2,
        step_index: 5,
        parent_context: %{pipeline_id: "parent"}
      }
      
      step = %{"name" => "metadata_step", "type" => "gemini", "config" => %{"timeout" => 30}}
      
      trace_context = NestedExecution.start_nested_trace("test_pipeline", context, step)
      
      span = Map.values(trace_context.spans) |> List.first()
      metadata = span.metadata
      
      assert metadata.nesting_depth == 2
      assert metadata.pipeline_id == "test_pipeline"
      assert metadata.step_index == 5
      assert metadata.has_parent == true
      assert metadata.step_config["name"] == "metadata_step"
      assert metadata.step_config["type"] == "gemini"
      refute Map.has_key?(metadata.step_config, "config")  # Sanitized
      assert metadata.context_size == 4
    end
  end

  describe "complete_span/2" do
    test "completes span with success result" do
      trace_context = %{
        trace_id: "test_trace",
        current_span: "test_span",
        spans: %{
          "test_span" => %{
            id: "test_span",
            start_time: DateTime.utc_now() |> DateTime.add(-1000, :millisecond),
            status: :running,
            parent_span: nil
          }
        }
      }
      
      result = {:ok, "success_value"}
      
      updated_context = NestedExecution.complete_span(trace_context, result)
      
      span = updated_context.spans["test_span"]
      assert span.status == :completed
      assert span.error == nil
      assert is_struct(span.end_time, DateTime)
      assert is_number(span.duration_ms)
      assert span.duration_ms > 0
      assert updated_context.current_span == nil  # No parent
    end

    test "completes span with error result" do
      trace_context = %{
        trace_id: "test_trace",
        current_span: "test_span",
        spans: %{
          "test_span" => %{
            id: "test_span",
            start_time: DateTime.utc_now() |> DateTime.add(-500, :millisecond),
            status: :running,
            parent_span: "parent_span"
          }
        }
      }
      
      result = {:error, "Something went wrong"}
      
      updated_context = NestedExecution.complete_span(trace_context, result)
      
      span = updated_context.spans["test_span"]
      assert span.status == :failed
      assert span.error == "Something went wrong"
      assert is_number(span.duration_ms)
      assert updated_context.current_span == "parent_span"  # Returns to parent
    end

    test "handles missing span gracefully" do
      trace_context = %{
        trace_id: "test_trace",
        current_span: "nonexistent_span",
        spans: %{}
      }
      
      result = NestedExecution.complete_span(trace_context, :ok)
      
      # Should return unchanged context
      assert result == trace_context
    end

    test "handles nil current_span gracefully" do
      trace_context = %{
        trace_id: "test_trace",
        current_span: nil,
        spans: %{}
      }
      
      result = NestedExecution.complete_span(trace_context, :ok)
      
      # Should return unchanged context
      assert result == trace_context
    end
  end

  describe "build_execution_tree/1" do
    test "builds tree from single span" do
      trace_context = %{
        spans: %{
          "root_span" => %{
            id: "root_span",
            pipeline_id: "root_pipeline",
            parent_span: nil,
            depth: 0,
            duration_ms: 1000
          }
        }
      }
      
      tree = NestedExecution.build_execution_tree(trace_context)
      
      assert tree.pipeline_id == "root_pipeline"
      assert length(tree.spans) == 1
      assert tree.children == []
      assert tree.total_duration_ms == 1000
      assert tree.step_count == 1
      assert tree.max_depth == 0
    end

    test "builds tree with nested spans" do
      trace_context = %{
        spans: %{
          "root_span" => %{
            id: "root_span",
            pipeline_id: "root_pipeline",
            parent_span: nil,
            depth: 0,
            duration_ms: 2000
          },
          "child_span_1" => %{
            id: "child_span_1",
            pipeline_id: "child_pipeline_1",
            parent_span: "root_span",
            depth: 1,
            duration_ms: 800
          },
          "child_span_2" => %{
            id: "child_span_2",
            pipeline_id: "child_pipeline_2",
            parent_span: "root_span",
            depth: 1,
            duration_ms: 600
          },
          "grandchild_span" => %{
            id: "grandchild_span",
            pipeline_id: "grandchild_pipeline",
            parent_span: "child_span_1",
            depth: 2,
            duration_ms: 300
          }
        }
      }
      
      tree = NestedExecution.build_execution_tree(trace_context)
      
      assert tree.pipeline_id == "root_pipeline"
      assert length(tree.children) == 2
      assert tree.step_count == 4  # 1 root + 3 descendants
      assert tree.max_depth == 2
      
      # Check first child
      child1 = Enum.find(tree.children, &(&1.pipeline_id == "child_pipeline_1"))
      assert child1 != nil
      assert length(child1.children) == 1
      assert child1.children |> List.first() |> Map.get(:pipeline_id) == "grandchild_pipeline"
      
      # Check second child
      child2 = Enum.find(tree.children, &(&1.pipeline_id == "child_pipeline_2"))
      assert child2 != nil
      assert child2.children == []
    end

    test "handles multiple root spans" do
      trace_context = %{
        spans: %{
          "root_span_1" => %{
            id: "root_span_1",
            pipeline_id: "root_pipeline_1",
            parent_span: nil,
            depth: 0,
            duration_ms: 1000
          },
          "root_span_2" => %{
            id: "root_span_2",
            pipeline_id: "root_pipeline_2",
            parent_span: nil,
            depth: 0,
            duration_ms: 1500
          }
        }
      }
      
      tree = NestedExecution.build_execution_tree(trace_context)
      
      assert tree.pipeline_id == "multiple_roots"
      assert length(tree.spans) == 2
      assert length(tree.children) == 2
      assert tree.step_count == 2
    end
  end

  describe "visualize_execution_tree/2" do
    test "visualizes simple tree" do
      execution_tree = %{
        pipeline_id: "root_pipeline",
        spans: [%{
          status: :completed,
          step_name: nil,
          duration_ms: 1000
        }],
        children: [],
        total_duration_ms: 1000,
        step_count: 1,
        max_depth: 0
      }
      
      visualization = NestedExecution.visualize_execution_tree(execution_tree)
      
      assert visualization =~ "Execution Tree:"
      assert visualization =~ "Pipeline: root_pipeline"
      assert visualization =~ "Total Duration: 1000ms"
      assert visualization =~ "Step Count: 1"
      assert visualization =~ "Max Depth: 0"
      assert visualization =~ "├─ ✅ root_pipeline"
      assert visualization =~ "(1000ms)"
    end

    test "visualizes nested tree with options" do
      execution_tree = %{
        pipeline_id: "root_pipeline",
        spans: [%{
          status: :completed,
          step_name: "root_step",
          duration_ms: 2000
        }],
        children: [
          %{
            pipeline_id: "child_pipeline",
            spans: [%{
              status: :failed,
              step_name: "child_step",
              duration_ms: 500
            }],
            children: [],
            total_duration_ms: 500,
            step_count: 1,
            max_depth: 1
          }
        ],
        total_duration_ms: 2000,
        step_count: 2,
        max_depth: 1
      }
      
      options = %{show_timings: true, show_status: true, max_depth: 10}
      visualization = NestedExecution.visualize_execution_tree(execution_tree, options)
      
      assert visualization =~ "├─ ✅ root_pipeline → root_step (2000ms)"
      assert visualization =~ "  ├─ ❌ child_pipeline → child_step (500ms)"
    end

    test "respects max_depth option" do
      deep_tree = %{
        pipeline_id: "root",
        spans: [%{status: :completed, step_name: nil, duration_ms: 100}],
        children: [
          %{
            pipeline_id: "level1",
            spans: [%{status: :completed, step_name: nil, duration_ms: 100}],
            children: [
              %{
                pipeline_id: "level2",
                spans: [%{status: :completed, step_name: nil, duration_ms: 100}],
                children: [],
                total_duration_ms: 100,
                step_count: 1,
                max_depth: 2
              }
            ],
            total_duration_ms: 100,
            step_count: 1,
            max_depth: 2
          }
        ],
        total_duration_ms: 100,
        step_count: 1,
        max_depth: 2
      }
      
      visualization = NestedExecution.visualize_execution_tree(deep_tree, %{max_depth: 1})
      
      assert visualization =~ "├─ ✅ root"
      assert visualization =~ "... (max depth reached)"
      refute visualization =~ "level2"
    end
  end

  describe "generate_performance_summary/1" do
    test "generates comprehensive performance summary" do
      execution_tree = %{
        pipeline_id: "root_pipeline",
        spans: [%{
          depth: 0,
          duration_ms: 2000,
          status: :completed,
          pipeline_id: "root_pipeline"
        }],
        children: [
          %{
            pipeline_id: "child_pipeline_1",
            spans: [%{
              depth: 1,
              duration_ms: 800,
              status: :completed,
              pipeline_id: "child_pipeline_1"
            }],
            children: [],
            total_duration_ms: 800,
            step_count: 1,
            max_depth: 1
          },
          %{
            pipeline_id: "child_pipeline_2",
            spans: [%{
              depth: 1,
              duration_ms: 500,
              status: :failed,
              pipeline_id: "child_pipeline_2"
            }],
            children: [],
            total_duration_ms: 500,
            step_count: 1,
            max_depth: 1
          }
        ],
        total_duration_ms: 2000,
        step_count: 3,
        max_depth: 1
      }
      
      summary = NestedExecution.generate_performance_summary(execution_tree)
      
      assert summary.total_duration_ms == 2000
      assert summary.total_spans == 3
      assert summary.completed_spans == 3
      assert summary.failed_spans == 1
      assert summary.max_depth == 1
      assert summary.pipeline_count == 3
      
      # Check depth metrics
      assert Map.has_key?(summary.depth_metrics, 0)
      assert Map.has_key?(summary.depth_metrics, 1)
      
      depth_0_metrics = summary.depth_metrics[0]
      assert depth_0_metrics.span_count == 1
      assert depth_0_metrics.total_duration_ms == 2000
      
      depth_1_metrics = summary.depth_metrics[1]
      assert depth_1_metrics.span_count == 2
      assert depth_1_metrics.total_duration_ms == 1300  # 800 + 500
      assert depth_1_metrics.avg_duration_ms == 650.0
      assert depth_1_metrics.min_duration_ms == 500
      assert depth_1_metrics.max_duration_ms == 800
      
      # Success rate calculation (2 out of 3 successful)
      assert abs(summary.success_rate - 66.67) < 0.1
    end

    test "handles empty tree" do
      execution_tree = %{
        pipeline_id: "empty",
        spans: [],
        children: [],
        total_duration_ms: 0,
        step_count: 0,
        max_depth: 0
      }
      
      summary = NestedExecution.generate_performance_summary(execution_tree)
      
      assert summary.total_spans == 0
      assert summary.success_rate == 0.0
      assert summary.depth_metrics == %{}
    end
  end

  describe "create_debug_info/2" do
    test "creates comprehensive debug information" do
      trace_context = %{
        trace_id: "debug_trace_id",
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "pipeline1",
            depth: 0,
            duration_ms: 1000,
            status: :completed,
            parent_span: nil
          }
        }
      }
      
      error = "Debug test error"
      
      debug_info = NestedExecution.create_debug_info(trace_context, error)
      
      assert debug_info.trace_id == "debug_trace_id"
      assert debug_info.total_spans == 1
      assert debug_info.error_context == "Debug test error"
      assert is_struct(debug_info.debug_timestamp, DateTime)
      assert is_map(debug_info.execution_tree)
      assert is_map(debug_info.performance_summary)
      assert is_binary(debug_info.trace_visualization)
    end

    test "handles nil error gracefully" do
      trace_context = %{
        trace_id: "trace_id",
        spans: %{}
      }
      
      debug_info = NestedExecution.create_debug_info(trace_context, nil)
      
      assert debug_info.error_context == nil
      assert debug_info.total_spans == 0
    end
  end

  describe "span collection and analysis" do
    test "collects all spans from complex tree" do
      # This tests the private collect_all_spans function indirectly through generate_performance_summary
      complex_tree = create_complex_execution_tree()
      
      summary = NestedExecution.generate_performance_summary(complex_tree)
      
      # Should collect spans from all levels
      assert summary.total_spans > 1
      assert summary.max_depth > 0
    end
  end

  # Helper function to create test data
  defp create_complex_execution_tree do
    %{
      pipeline_id: "root",
      spans: [%{
        depth: 0,
        duration_ms: 1000,
        status: :completed,
        pipeline_id: "root"
      }],
      children: [
        %{
          pipeline_id: "child1",
          spans: [%{
            depth: 1,
            duration_ms: 400,
            status: :completed,
            pipeline_id: "child1"
          }],
          children: [
            %{
              pipeline_id: "grandchild1",
              spans: [%{
                depth: 2,
                duration_ms: 200,
                status: :completed,
                pipeline_id: "grandchild1"
              }],
              children: [],
              total_duration_ms: 200,
              step_count: 1,
              max_depth: 2
            }
          ],
          total_duration_ms: 400,
          step_count: 2,
          max_depth: 2
        },
        %{
          pipeline_id: "child2",
          spans: [%{
            depth: 1,
            duration_ms: 300,
            status: :failed,
            pipeline_id: "child2"
          }],
          children: [],
          total_duration_ms: 300,
          step_count: 1,
          max_depth: 1
        }
      ],
      total_duration_ms: 1000,
      step_count: 4,
      max_depth: 2
    }
  end
end