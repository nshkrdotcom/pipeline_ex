defmodule Pipeline.Debug.NestedExecutionTest do
  use ExUnit.Case, async: true

  alias Pipeline.Debug.NestedExecution

  describe "start_debug_session/2" do
    test "creates debug session with default options" do
      trace_context = %{
        trace_id: "test_trace_id",
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "test_pipeline",
            depth: 0,
            duration_ms: 1000,
            status: :completed,
            parent_span: nil
          }
        }
      }

      session = NestedExecution.start_debug_session(trace_context)

      assert is_binary(session.session_id)
      assert session.trace_context == trace_context
      assert is_map(session.execution_tree)
      assert is_map(session.debug_options)
      assert is_struct(session.start_time, DateTime)
      assert session.commands_history == []

      # Check default options
      assert session.debug_options.show_metadata == false
      assert session.debug_options.show_errors == true
      assert session.debug_options.show_performance == true
      assert session.debug_options.max_depth == 10
    end

    test "creates debug session with custom options" do
      trace_context = %{trace_id: "test", spans: %{}}

      options = %{
        show_metadata: true,
        show_errors: false,
        max_depth: 5
      }

      session = NestedExecution.start_debug_session(trace_context, options)

      assert session.debug_options.show_metadata == true
      assert session.debug_options.show_errors == false
      assert session.debug_options.max_depth == 5
      # Should preserve defaults for unspecified options
      assert session.debug_options.show_performance == true
    end
  end

  describe "debug_execution_tree/2" do
    test "formats execution tree with basic options" do
      context = create_test_execution_tree()

      output = NestedExecution.debug_execution_tree(context)

      assert output =~ "🌳 Execution Tree Debug View"
      assert output =~ "Pipeline: root_pipeline"
      assert output =~ "Total Duration: 1500ms"
      assert output =~ "Total Steps: 3"
      assert output =~ "Max Depth: 1"
      assert output =~ "Tree Structure:"
      assert output =~ "├─ ✅ root_pipeline"
      assert output =~ "├─ ❌ child_pipeline"
      assert output =~ "📊 Execution Summary:"
    end

    test "shows metadata when requested" do
      context = create_test_execution_tree()
      options = %{show_metadata: true}

      output = NestedExecution.debug_execution_tree(context, options)

      assert output =~ "📊 Depth:"
      assert output =~ "🕐 Started:"
      assert output =~ "📍 Span ID:"
    end

    test "hides errors when requested" do
      context = create_test_execution_tree_with_errors()
      options = %{show_errors: false}

      output = NestedExecution.debug_execution_tree(context, options)

      refute output =~ "❌ Error:"
      refute output =~ "Something went wrong"
    end

    test "respects max_depth option" do
      context = create_deep_execution_tree()
      options = %{max_depth: 2}

      output = NestedExecution.debug_execution_tree(context, options)

      assert output =~ "... (max depth 2 reached)"
    end

    test "handles debug session input" do
      trace_context = %{
        trace_id: "test",
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "test_pipeline",
            parent_span: nil,
            depth: 0,
            duration_ms: 1000,
            status: :completed,
            step_name: nil,
            step_type: "pipeline"
          }
        }
      }

      session = NestedExecution.start_debug_session(trace_context)

      output = NestedExecution.debug_execution_tree(session)

      assert output =~ "test_pipeline"
      assert output =~ "1000ms"
    end
  end

  describe "analyze_execution/2" do
    test "analyzes execution for performance issues" do
      execution_tree = create_test_execution_tree()

      analysis = NestedExecution.analyze_execution(execution_tree)

      assert is_list(analysis.performance_issues)
      assert is_list(analysis.potential_optimizations)
      assert is_list(analysis.error_patterns)
      assert is_map(analysis.resource_usage)
      assert is_list(analysis.recommendations)

      # Check resource usage analysis
      assert is_number(analysis.resource_usage.total_execution_time)
      assert is_number(analysis.resource_usage.span_count)
      assert is_number(analysis.resource_usage.avg_span_duration)
      assert is_list(analysis.resource_usage.depth_distribution)
    end

    test "detects slow execution performance issue" do
      slow_tree = %{
        pipeline_id: "slow_pipeline",
        spans: [
          # 10 seconds - slow
          %{depth: 0, duration_ms: 10000, status: :completed},
          # 8 seconds - slow
          %{depth: 1, duration_ms: 8000, status: :completed}
        ],
        children: [],
        total_duration_ms: 18000,
        step_count: 2,
        max_depth: 1
      }

      analysis = NestedExecution.analyze_execution(slow_tree)

      slow_issue = Enum.find(analysis.performance_issues, &(&1.type == :slow_execution))
      assert slow_issue != nil
      assert slow_issue.severity == :warning
      assert length(slow_issue.spans) == 2
    end

    test "detects high failure rate" do
      failing_tree = %{
        pipeline_id: "failing_pipeline",
        spans: [
          %{depth: 0, duration_ms: 1000, status: :failed},
          %{depth: 0, duration_ms: 1000, status: :failed},
          %{depth: 0, duration_ms: 1000, status: :completed}
        ],
        children: [],
        total_duration_ms: 3000,
        step_count: 3,
        max_depth: 0
      }

      analysis = NestedExecution.analyze_execution(failing_tree)

      failure_issue = Enum.find(analysis.performance_issues, &(&1.type == :high_failure_rate))
      assert failure_issue != nil
      assert failure_issue.severity == :error
    end

    test "detects deep nesting issue" do
      deep_tree = %{
        pipeline_id: "deep_pipeline",
        spans: [%{depth: 0, duration_ms: 1000, status: :completed}],
        children: [],
        total_duration_ms: 1000,
        step_count: 1,
        # Deep nesting
        max_depth: 8
      }

      analysis = NestedExecution.analyze_execution(deep_tree)

      depth_issue = Enum.find(analysis.performance_issues, &(&1.type == :deep_nesting))
      assert depth_issue != nil
      assert depth_issue.severity == :warning
    end

    test "analyzes error patterns" do
      tree_with_errors = %{
        pipeline_id: "error_pipeline",
        spans: [
          %{depth: 0, duration_ms: 1000, status: :failed, error: "timeout error"},
          %{depth: 1, duration_ms: 500, status: :failed, error: "timeout occurred"},
          %{depth: 0, duration_ms: 800, status: :failed, error: "circular dependency"},
          %{depth: 0, duration_ms: 1200, status: :completed, error: nil}
        ],
        children: [],
        total_duration_ms: 3500,
        step_count: 4,
        max_depth: 1
      }

      analysis = NestedExecution.analyze_execution(tree_with_errors)

      assert length(analysis.error_patterns) > 0

      # Should group timeout errors together
      timeout_pattern = Enum.find(analysis.error_patterns, &(&1.error_type == :timeout))
      assert timeout_pattern != nil
      assert timeout_pattern.count == 2

      # Should identify circular dependency
      circular_pattern =
        Enum.find(analysis.error_patterns, &(&1.error_type == :circular_dependency))

      assert circular_pattern != nil
      assert circular_pattern.count == 1
    end

    test "suggests optimizations based on execution patterns" do
      # Test various scenarios that should trigger different optimization suggestions

      # Deep nesting should suggest parallel execution
      deep_tree = %{
        pipeline_id: "deep",
        spans: [],
        children: [],
        total_duration_ms: 1000,
        step_count: 1,
        max_depth: 4
      }

      analysis_deep = NestedExecution.analyze_execution(deep_tree)

      assert "Consider parallel execution for independent nested pipelines" in analysis_deep.potential_optimizations

      # Many pipelines should suggest caching - create tree with 12 unique pipelines
      many_spans =
        for i <- 1..12 do
          %{
            id: "span_#{i}",
            pipeline_id: "pipeline_#{i}",
            depth: 0,
            duration_ms: 100,
            status: :completed,
            error: nil
          }
        end

      many_pipelines_tree = %{
        pipeline_id: "many",
        spans: many_spans,
        children: [],
        total_duration_ms: 1200,
        step_count: 12,
        max_depth: 0
      }

      analysis_many = NestedExecution.analyze_execution(many_pipelines_tree)

      assert "Consider caching pipeline definitions for repeated executions" in analysis_many.potential_optimizations
    end
  end

  describe "generate_debug_report/3" do
    test "generates comprehensive debug report" do
      trace_context = %{
        trace_id: "debug_trace",
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "test_pipeline",
            depth: 0,
            duration_ms: 1000,
            status: :completed,
            parent_span: nil,
            step_name: nil,
            step_type: "pipeline",
            error: nil
          }
        }
      }

      error = "Test debug error"

      report = NestedExecution.generate_debug_report(trace_context, error)

      assert report =~ "🐛 NESTED PIPELINE DEBUG REPORT"
      assert report =~ "Trace ID: debug_trace"
      assert report =~ "Error Context:"
      assert report =~ "Test debug error"
      assert report =~ "🎯 EXECUTION OVERVIEW"
      assert report =~ "🚀 PERFORMANCE ANALYSIS"
      assert report =~ "⚠️ ERROR ANALYSIS"
      assert report =~ "💡 RECOMMENDATIONS"
      assert report =~ "🔧 DEBUG COMMANDS"
    end

    test "generates report without error" do
      trace_context = %{
        trace_id: "success_trace",
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "success_pipeline",
            depth: 0,
            duration_ms: 500,
            status: :completed,
            parent_span: nil,
            step_name: nil,
            step_type: "pipeline",
            error: nil
          }
        }
      }

      report = NestedExecution.generate_debug_report(trace_context)

      assert report =~ "success_trace"
      refute report =~ "Error Context:"
      assert report =~ "✅ No error patterns detected"
    end
  end

  describe "inspect_context/2" do
    test "inspects execution context with step information" do
      context = %{
        pipeline_id: "inspect_test",
        nesting_depth: 2,
        step_index: 5,
        results: %{
          "step1" => "result1",
          "step2" => %{"nested" => "data"}
        },
        global_vars: %{
          "config" => "production",
          "version" => "1.0"
        },
        parent_context: %{
          pipeline_id: "parent_pipeline",
          nesting_depth: 1,
          parent_context: %{
            pipeline_id: "root_pipeline",
            nesting_depth: 0,
            parent_context: nil
          }
        }
      }

      step = %{
        "name" => "current_step",
        "type" => "claude",
        "config" => %{"timeout" => 30}
      }

      output = NestedExecution.inspect_context(context, step)

      assert output =~ "Context Inspection:"
      assert output =~ "Pipeline: inspect_test"
      assert output =~ "Nesting Depth: 2"
      assert output =~ "Step Index: 5"
      assert output =~ "Current Step:"
      assert output =~ "Name: current_step"
      assert output =~ "Type: claude"
      assert output =~ "Available: step1, step2"
      assert output =~ "config, version"
      assert output =~ "root_pipeline → parent_pipeline → inspect_test"
    end

    test "handles minimal context gracefully" do
      context = %{pipeline_id: "minimal"}

      output = NestedExecution.inspect_context(context)

      assert output =~ "Pipeline: minimal"
      assert output =~ "Nesting Depth: 0"
      assert output =~ "Step Index: unknown"
      assert output =~ "No results available"
      assert output =~ "No global variables"
    end

    test "formats large result sets appropriately" do
      context = %{
        pipeline_id: "large_results",
        results: %{
          "step1" => "result1",
          "step2" => "result2",
          "step3" => "result3",
          "step4" => "result4",
          "step5" => "result5",
          "step6" => "result6",
          "step7" => "result7"
        }
      }

      output = NestedExecution.inspect_context(context)

      assert output =~ "step1, step2, step3, step4, step5 (+ 2 more)"
    end
  end

  describe "compare_executions/2" do
    test "compares multiple execution traces" do
      trace1 = %{
        trace_id: "trace1",
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

      trace2 = %{
        trace_id: "trace2",
        spans: %{
          "span2" => %{
            id: "span2",
            pipeline_id: "pipeline2",
            depth: 0,
            duration_ms: 1500,
            status: :completed,
            parent_span: nil
          }
        }
      }

      comparison = NestedExecution.compare_executions([trace1, trace2])

      assert comparison =~ "📊 PERFORMANCE COMPARISON"
      assert comparison =~ "Executions Compared: 2"
      assert comparison =~ "Average Duration:"
      assert comparison =~ "Duration Variance:"
      assert comparison =~ "Success Rate Trend:"
    end

    test "handles insufficient data for comparison" do
      trace1 = %{trace_id: "single", spans: %{}}

      comparison = NestedExecution.compare_executions([trace1])

      assert comparison == "At least 2 performance metrics required for comparison"
    end
  end

  describe "search_execution/3" do
    test "searches by pipeline IDs" do
      trace_context = %{
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "data_processor",
            step_name: "process_data",
            error: nil
          },
          "span2" => %{
            id: "span2",
            pipeline_id: "analysis_engine",
            step_name: "analyze",
            error: nil
          },
          "span3" => %{
            id: "span3",
            pipeline_id: "data_validator",
            step_name: "validate",
            error: nil
          }
        }
      }

      results = NestedExecution.search_execution(trace_context, "data", :pipeline_ids)

      # data_processor and data_validator
      assert length(results) == 2
      pipeline_ids = Enum.map(results, & &1.span.pipeline_id)
      assert "data_processor" in pipeline_ids
      assert "data_validator" in pipeline_ids
      refute "analysis_engine" in pipeline_ids
    end

    test "searches by step names" do
      trace_context = %{
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "pipeline1",
            step_name: "validate_input",
            error: nil
          },
          "span2" => %{
            id: "span2",
            pipeline_id: "pipeline2",
            step_name: "process_data",
            error: nil
          },
          "span3" => %{
            id: "span3",
            pipeline_id: "pipeline3",
            step_name: "validate_output",
            error: nil
          }
        }
      }

      results = NestedExecution.search_execution(trace_context, "validate", :step_names)

      # validate_input and validate_output
      assert length(results) == 2
      step_names = Enum.map(results, & &1.span.step_name)
      assert "validate_input" in step_names
      assert "validate_output" in step_names
      refute "process_data" in step_names
    end

    test "searches by errors" do
      trace_context = %{
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "pipeline1",
            step_name: "step1",
            error: "Connection timeout"
          },
          "span2" => %{
            id: "span2",
            pipeline_id: "pipeline2",
            step_name: "step2",
            error: "API timeout occurred"
          },
          "span3" => %{
            id: "span3",
            pipeline_id: "pipeline3",
            step_name: "step3",
            error: nil
          }
        }
      }

      results = NestedExecution.search_execution(trace_context, "timeout", :errors)

      assert length(results) == 2
      errors = Enum.map(results, & &1.span.error)
      assert "Connection timeout" in errors
      assert "API timeout occurred" in errors
    end

    test "searches all fields when search_in is :all" do
      trace_context = %{
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "test_pipeline",
            step_name: "normal_step",
            error: nil
          },
          "span2" => %{
            id: "span2",
            pipeline_id: "normal_pipeline",
            step_name: "test_step",
            error: nil
          },
          "span3" => %{
            id: "span3",
            pipeline_id: "other_pipeline",
            step_name: "other_step",
            error: "test error occurred"
          }
        }
      }

      results = NestedExecution.search_execution(trace_context, "test", :all)

      # Matches in pipeline_id, step_name, and error
      assert length(results) == 3

      # Verify match info is correct
      match_fields = Enum.map(results, & &1.match_info.matched_field)
      assert :pipeline_id in match_fields
      assert :step_name in match_fields
      assert :error in match_fields
    end

    test "handles regex patterns" do
      trace_context = %{
        spans: %{
          "span1" => %{
            id: "span1",
            pipeline_id: "data_processor_v1",
            step_name: "step1",
            error: nil
          },
          "span2" => %{
            id: "span2",
            pipeline_id: "data_processor_v2",
            step_name: "step2",
            error: nil
          },
          "span3" => %{
            id: "span3",
            pipeline_id: "analysis_engine",
            step_name: "step3",
            error: nil
          }
        }
      }

      # Search for pipelines matching pattern "data_processor_v\d+"
      regex_pattern = ~r/data_processor_v\d+/
      results = NestedExecution.search_execution(trace_context, regex_pattern, :pipeline_ids)

      assert length(results) == 2
      pipeline_ids = Enum.map(results, & &1.span.pipeline_id)
      assert "data_processor_v1" in pipeline_ids
      assert "data_processor_v2" in pipeline_ids
      refute "analysis_engine" in pipeline_ids
    end
  end

  # Helper functions for creating test data

  defp create_test_execution_tree do
    %{
      pipeline_id: "root_pipeline",
      spans: [
        %{
          status: :completed,
          step_name: nil,
          duration_ms: 1000,
          depth: 0,
          pipeline_id: "root_pipeline",
          parent_span: nil
        }
      ],
      children: [
        %{
          pipeline_id: "child_pipeline",
          spans: [
            %{
              status: :failed,
              step_name: "child_step",
              duration_ms: 500,
              depth: 1,
              pipeline_id: "child_pipeline",
              parent_span: "root_span"
            }
          ],
          children: [],
          total_duration_ms: 500,
          step_count: 1,
          max_depth: 1
        }
      ],
      total_duration_ms: 1500,
      step_count: 3,
      max_depth: 1
    }
  end

  defp create_test_execution_tree_with_errors do
    %{
      pipeline_id: "error_pipeline",
      spans: [
        %{
          status: :failed,
          step_name: "failing_step",
          duration_ms: 1000,
          depth: 0,
          error: "Something went wrong"
        }
      ],
      children: [],
      total_duration_ms: 1000,
      step_count: 1,
      max_depth: 0
    }
  end

  defp create_deep_execution_tree do
    %{
      pipeline_id: "level0",
      spans: [%{status: :completed, step_name: nil, duration_ms: 100, depth: 0}],
      children: [
        %{
          pipeline_id: "level1",
          spans: [%{status: :completed, step_name: nil, duration_ms: 100, depth: 1}],
          children: [
            %{
              pipeline_id: "level2",
              spans: [%{status: :completed, step_name: nil, duration_ms: 100, depth: 2}],
              children: [
                %{
                  pipeline_id: "level3",
                  spans: [%{status: :completed, step_name: nil, duration_ms: 100, depth: 3}],
                  children: [],
                  total_duration_ms: 100,
                  step_count: 1,
                  max_depth: 3
                }
              ],
              total_duration_ms: 100,
              step_count: 1,
              max_depth: 3
            }
          ],
          total_duration_ms: 100,
          step_count: 1,
          max_depth: 3
        }
      ],
      total_duration_ms: 100,
      step_count: 1,
      max_depth: 3
    }
  end
end
