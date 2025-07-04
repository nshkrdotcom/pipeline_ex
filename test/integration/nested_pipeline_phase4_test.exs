defmodule Pipeline.Integration.NestedPipelinePhase4Test do
  use Pipeline.IntegrationCase

  alias Pipeline.{Executor, Config}
  alias Pipeline.Error.NestedPipeline, as: ErrorHandler
  alias Pipeline.Tracing.NestedExecution, as: Tracer
  alias Pipeline.Debug.NestedExecution, as: Debugger
  alias Pipeline.Metrics.NestedPerformance, as: Metrics

  @moduletag :integration

  describe "Phase 4 Developer Experience Integration" do
    test "complete error handling and debugging workflow" do
      # Create a pipeline that will fail to test error handling
      failing_pipeline = %{
        "name" => "failing_integration_test",
        "steps" => [
          %{
            "name" => "set_data",
            "type" => "test_echo",
            "value" => "test_data"
          },
          %{
            "name" => "nested_failing",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "nested_failure",
              "steps" => [
                %{
                  "name" => "fail_step",
                  "type" => "test_echo",
                  "value" => "{{nonexistent.variable}}"  # This will cause an error
                }
              ]
            },
            "inputs" => %{
              "test_input" => "{{steps.set_data.result}}"
            },
            "outputs" => ["fail_step"]
          }
        ]
      }

      # Start performance tracking
      trace_id = "phase4_integration_trace"
      performance_context = Metrics.start_performance_tracking(trace_id, "failing_integration_test")

      # Start execution tracing
      execution_context = %{
        pipeline_id: "failing_integration_test",
        nesting_depth: 0,
        step_index: 0,
        start_time: DateTime.utc_now(),
        results: %{}
      }
      
      trace_context = Tracer.start_nested_trace("failing_integration_test", execution_context)

      # Execute the pipeline (expect it to fail)
      result = Executor.execute_pipeline(failing_pipeline)
      
      # Complete tracing
      completed_trace = Tracer.complete_span(trace_context, result)
      
      # Record performance metrics
      performance_context = Metrics.record_pipeline_metric(
        performance_context,
        "failing_integration_test",
        0,
        1000,  # Mock duration
        2,     # step count
        false, # success = false
        "Variable resolution failed"
      )
      
      completed_performance = Metrics.complete_performance_tracking(performance_context)

      # Test error handling
      case result do
        {:error, error_reason} ->
          # Create comprehensive error report
          error_context = %{
            pipeline_id: "failing_integration_test",
            nesting_depth: 0,
            parent_context: nil,
            start_time: DateTime.utc_now(),
            step_index: 1
          }
          
          step = %{"name" => "nested_failing", "type" => "pipeline"}
          formatted_error = ErrorHandler.format_nested_error(error_reason, error_context, step)
          
          # Verify error formatting
          assert formatted_error.message =~ "Pipeline execution failed"
          assert formatted_error.context.pipeline_id == "failing_integration_test"
          assert formatted_error.context.step_name == "nested_failing"
          assert is_map(formatted_error.debug_info)
          
          # Test debug log creation
          debug_log = ErrorHandler.create_debug_log_entry(error_reason, error_context, step)
          assert debug_log.pipeline_id == "failing_integration_test"
          assert debug_log.step_name == "nested_failing"
          assert debug_log.nesting_depth == 0

        _ ->
          flunk("Expected pipeline to fail for error handling test")
      end

      # Test execution tree debugging
      execution_tree = Tracer.build_execution_tree(completed_trace)
      debug_output = Debugger.debug_execution_tree(execution_tree, %{show_errors: true, show_metadata: true})
      
      assert debug_output =~ "🌳 Execution Tree Debug View"
      assert debug_output =~ "failing_integration_test"
      assert debug_output =~ "📊 Execution Summary"

      # Test execution analysis
      analysis = Debugger.analyze_execution(execution_tree)
      assert is_list(analysis.performance_issues)
      assert is_list(analysis.error_patterns)
      assert is_map(analysis.resource_usage)

      # Test performance analysis
      performance_analysis = Metrics.analyze_performance(completed_performance)
      assert is_atom(performance_analysis.performance_grade)
      assert is_list(performance_analysis.bottlenecks)
      assert is_number(performance_analysis.efficiency_score)

      # Test debug report generation
      debug_report = Debugger.generate_debug_report(completed_trace, result)
      assert debug_report =~ "🐛 NESTED PIPELINE DEBUG REPORT"
      assert debug_report =~ trace_id
      assert debug_report =~ "⚠️ ERROR ANALYSIS"
      assert debug_report =~ "💡 RECOMMENDATIONS"

      # Test performance report generation
      performance_report = Metrics.generate_performance_report(completed_performance)
      assert performance_report =~ "📊 NESTED PIPELINE PERFORMANCE REPORT"
      assert performance_report =~ "🎯 EXECUTION OVERVIEW"
      assert performance_report =~ "💾 RESOURCE ANALYSIS"
    end

    test "successful nested pipeline with comprehensive tracking" do
      # Create a successful nested pipeline to test positive scenarios
      successful_pipeline = %{
        "name" => "successful_integration_test",
        "steps" => [
          %{
            "name" => "prepare",
            "type" => "test_echo",
            "value" => "preparation_complete"
          },
          %{
            "name" => "process_data",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "data_processor",
              "steps" => [
                %{
                  "name" => "transform",
                  "type" => "test_echo",
                  "value" => "transformed_data"
                },
                %{
                  "name" => "validate",
                  "type" => "test_echo",
                  "value" => "validation_passed"
                }
              ]
            },
            "inputs" => %{
              "input_data" => "{{steps.prepare.result}}"
            },
            "outputs" => ["transform", "validate"]
          },
          %{
            "name" => "finalize",
            "type" => "test_echo",
            "value" => "{{steps.process_data.transform}}_final"
          }
        ]
      }

      # Start comprehensive tracking
      trace_id = "successful_integration_trace"
      performance_context = Metrics.start_performance_tracking(trace_id, "successful_integration_test")

      execution_context = %{
        pipeline_id: "successful_integration_test",
        nesting_depth: 0,
        start_time: DateTime.utc_now(),
        results: %{}
      }
      
      trace_context = Tracer.start_nested_trace("successful_integration_test", execution_context)

      # Execute the pipeline
      start_time = DateTime.utc_now()
      result = Executor.execute_pipeline(successful_pipeline)
      end_time = DateTime.utc_now()
      duration_ms = DateTime.diff(end_time, start_time, :millisecond)

      # Complete tracing
      completed_trace = Tracer.complete_span(trace_context, result)
      
      # Record performance metrics for main pipeline
      performance_context = Metrics.record_pipeline_metric(
        performance_context,
        "successful_integration_test",
        0,
        duration_ms,
        3,   # step count
        true, # success
        nil,
        %{child_pipelines: ["data_processor"]}
      )
      
      # Record metrics for nested pipeline
      performance_context = Metrics.record_pipeline_metric(
        performance_context,
        "data_processor",
        1,
        div(duration_ms, 2),  # Estimate nested duration
        2,   # step count
        true, # success
        nil
      )
      
      completed_performance = Metrics.complete_performance_tracking(performance_context)

      # Verify successful execution
      assert match?({:ok, _}, result)
      {:ok, final_results} = result
      assert final_results["finalize"] == "transformed_data_final"

      # Test execution tree building and visualization
      execution_tree = Tracer.build_execution_tree(completed_trace)
      assert execution_tree.pipeline_id == "successful_integration_test"
      assert execution_tree.total_duration_ms >= 0
      assert execution_tree.step_count >= 1

      tree_visualization = Tracer.visualize_execution_tree(execution_tree, %{
        show_timings: true,
        show_status: true
      })
      assert tree_visualization =~ "Execution Tree:"
      assert tree_visualization =~ "successful_integration_test"
      assert tree_visualization =~ "✅"  # Success indicators

      # Test performance summary generation
      performance_summary = Tracer.generate_performance_summary(execution_tree)
      assert performance_summary.total_spans >= 1
      assert performance_summary.success_rate >= 90.0  # Should be high for successful pipeline
      assert performance_summary.max_depth >= 0

      # Test debugging capabilities
      debug_session = Debugger.start_debug_session(completed_trace, %{
        show_metadata: true,
        show_performance: true
      })
      
      assert is_binary(debug_session.session_id)
      assert debug_session.trace_context == completed_trace

      # Test context inspection
      context_inspection = Debugger.inspect_context(execution_context)
      assert context_inspection =~ "Context Inspection:"
      assert context_inspection =~ "successful_integration_test"

      # Test execution analysis for successful case
      analysis = Debugger.analyze_execution(execution_tree)
      
      # Should have fewer or no performance issues for successful execution
      assert length(analysis.performance_issues) <= length(analysis.recommendations)
      assert is_list(analysis.potential_optimizations)

      # Test performance analysis
      performance_analysis = Metrics.analyze_performance(completed_performance)
      
      # Should have good performance grade for simple successful pipeline
      assert performance_analysis.performance_grade in [:excellent, :good, :fair]
      assert performance_analysis.efficiency_score > 0
      
      # Scalability should be reasonable for simple pipeline
      assert performance_analysis.scalability_assessment.overall in [:excellent, :good, :fair]

      # Test search functionality
      search_results = Debugger.search_execution(completed_trace, "successful", :pipeline_ids)
      assert length(search_results) >= 1
      
      pipeline_result = List.first(search_results)
      assert pipeline_result.span.pipeline_id =~ "successful"
      assert pipeline_result.match_info.matched_field == :pipeline_id

      # Test telemetry emission (should not raise errors)
      assert :ok == Metrics.emit_performance_telemetry(completed_performance, :integration_test)
    end

    test "deep nested pipeline performance and debugging" do
      # Create a pipeline with multiple levels of nesting to test depth handling
      deep_pipeline = create_deep_nested_pipeline(3)  # 3 levels deep

      # Start tracking
      trace_id = "deep_nested_trace"
      performance_context = Metrics.start_performance_tracking(trace_id, "root_pipeline")

      execution_context = %{
        pipeline_id: "root_pipeline",
        nesting_depth: 0,
        start_time: DateTime.utc_now(),
        results: %{}
      }
      
      trace_context = Tracer.start_nested_trace("root_pipeline", execution_context)

      # Execute the deep pipeline
      start_time = DateTime.utc_now()
      result = Executor.execute_pipeline(deep_pipeline)
      end_time = DateTime.utc_now()
      duration_ms = DateTime.diff(end_time, start_time, :millisecond)

      # Complete tracing
      completed_trace = Tracer.complete_span(trace_context, result)

      # Record metrics for multiple depths
      performance_context = Metrics.record_pipeline_metric(
        performance_context, "root_pipeline", 0, duration_ms, 2, true, nil
      )
      performance_context = Metrics.record_pipeline_metric(
        performance_context, "level_1_pipeline", 1, div(duration_ms, 2), 2, true, nil
      )
      performance_context = Metrics.record_pipeline_metric(
        performance_context, "level_2_pipeline", 2, div(duration_ms, 4), 2, true, nil
      )
      
      completed_performance = Metrics.complete_performance_tracking(performance_context)

      # Test depth-specific analysis
      execution_tree = Tracer.build_execution_tree(completed_trace)
      performance_summary = Tracer.generate_performance_summary(execution_tree)
      
      # Should detect multiple depth levels
      assert performance_summary.max_depth >= 2
      assert Map.has_key?(performance_summary.depth_metrics, 0)
      assert Map.has_key?(performance_summary.depth_metrics, 1)

      # Test depth-aware debugging
      debug_output = Debugger.debug_execution_tree(execution_tree, %{max_depth: 2})
      assert debug_output =~ "root_pipeline"
      # Should show depth limitation
      if performance_summary.max_depth > 2 do
        assert debug_output =~ "max depth"
      end

      # Test performance analysis for deep nesting
      performance_analysis = Metrics.analyze_performance(completed_performance)
      
      # May detect deep nesting as a potential issue
      if completed_performance.summary.max_depth > 5 do
        depth_bottleneck = Enum.find(performance_analysis.bottlenecks, &String.contains?(&1, "Deep nesting"))
        assert depth_bottleneck != nil
      end

      # Test scalability assessment for deep pipelines
      assert performance_analysis.scalability_assessment.depth_scalability in [:excellent, :good, :fair, :poor]

      # Test comparison with shallow pipeline
      shallow_performance = create_shallow_performance_metrics()
      comparison = Metrics.compare_performance([completed_performance, shallow_performance])
      
      assert comparison =~ "Executions Compared: 2"
      assert comparison =~ "Average Duration:"
    end

    test "error pattern analysis and recommendations" do
      # Simulate multiple failed executions to test error pattern analysis
      error_scenarios = [
        {"timeout_pipeline", "Connection timeout after 30s"},
        {"timeout_pipeline_2", "API timeout occurred"},
        {"circular_pipeline", "Circular dependency detected: A → B → A"},
        {"resource_pipeline", "Memory limit exceeded: 2048MB > 1024MB"},
        {"validation_pipeline", "Invalid configuration provided"}
      ]

      trace_contexts = []
      performance_contexts = []

      for {pipeline_id, error_message} <- error_scenarios do
        # Create trace for each error scenario
        execution_context = %{
          pipeline_id: pipeline_id,
          nesting_depth: 0,
          start_time: DateTime.utc_now(),
          results: %{}
        }
        
        trace_context = Tracer.start_nested_trace(pipeline_id, execution_context)
        completed_trace = Tracer.complete_span(trace_context, {:error, error_message})
        trace_contexts = [completed_trace | trace_contexts]

        # Create performance context for each scenario
        perf_context = Metrics.start_performance_tracking("error_trace_#{pipeline_id}", pipeline_id)
        perf_context = Metrics.record_pipeline_metric(
          perf_context, pipeline_id, 0, 1000, 2, false, error_message
        )
        completed_perf = Metrics.complete_performance_tracking(perf_context)
        performance_contexts = [completed_perf | performance_contexts]
      end

      # Analyze error patterns across multiple executions
      for trace_context <- trace_contexts do
        execution_tree = Tracer.build_execution_tree(trace_context)
        analysis = Debugger.analyze_execution(execution_tree)
        
        # Should detect error patterns
        assert length(analysis.error_patterns) >= 1
        
        error_pattern = List.first(analysis.error_patterns)
        assert is_atom(error_pattern.error_type)
        assert error_pattern.count >= 1
      end

      # Test performance comparison across error scenarios
      comparison = Metrics.compare_performance(performance_contexts)
      assert comparison =~ "Performance Comparison"
      assert comparison =~ "Executions Compared: #{length(error_scenarios)}"

      # Test error-specific formatting
      timeout_error = "Connection timeout after 30s"
      timeout_context = %{
        pipeline_id: "timeout_test",
        nesting_depth: 1,
        parent_context: %{pipeline_id: "parent", nesting_depth: 0, parent_context: nil}
      }
      
      timeout_formatted = ErrorHandler.format_timeout_error(30, timeout_context, 35000)
      assert timeout_formatted =~ "timeout"
      assert timeout_formatted =~ "30s"
      assert timeout_formatted =~ "35.0s"

      # Test circular dependency formatting
      circular_chain = ["pipeline_a", "pipeline_b", "pipeline_a"]
      circular_context = %{pipeline_id: "pipeline_b", nesting_depth: 1}
      
      circular_formatted = ErrorHandler.format_circular_dependency_error(circular_chain, circular_context)
      assert circular_formatted =~ "Circular dependency detected"
      assert circular_formatted =~ "pipeline_a → pipeline_b → pipeline_a"

      # Test resource limit formatting
      resource_formatted = ErrorHandler.format_resource_limit_error(:memory, 2048, 1024, timeout_context)
      assert resource_formatted =~ "Memory usage: 2048MB > 1024MB"
      assert resource_formatted =~ "memory-intensive operations"
    end
  end

  # Helper functions

  defp create_deep_nested_pipeline(depth) when depth <= 0 do
    %{
      "name" => "leaf_pipeline",
      "steps" => [
        %{
          "name" => "leaf_step",
          "type" => "test_echo",
          "value" => "leaf_result"
        }
      ]
    }
  end

  defp create_deep_nested_pipeline(depth) do
    %{
      "name" => "level_#{depth}_pipeline",
      "steps" => [
        %{
          "name" => "setup_step",
          "type" => "test_echo",
          "value" => "level_#{depth}_setup"
        },
        %{
          "name" => "nested_step",
          "type" => "pipeline",
          "pipeline" => create_deep_nested_pipeline(depth - 1),
          "outputs" => ["leaf_step"]
        }
      ]
    }
  end

  defp create_shallow_performance_metrics do
    %{
      execution_id: "shallow_execution",
      trace_id: "shallow_trace",
      start_time: DateTime.utc_now() |> DateTime.add(-1000, :millisecond),
      end_time: DateTime.utc_now(),
      total_duration_ms: 1000,
      pipeline_metrics: [
        %{
          pipeline_id: "shallow_pipeline",
          depth: 0,
          duration_ms: 1000,
          step_count: 2,
          success: true,
          error: nil,
          memory_usage_mb: 50.0,
          child_pipelines: []
        }
      ],
      depth_metrics: %{
        0 => %{
          depth: 0,
          pipeline_count: 1,
          total_duration_ms: 1000,
          avg_duration_ms: 1000.0,
          min_duration_ms: 1000,
          max_duration_ms: 1000,
          success_rate: 100.0,
          step_count: 2
        }
      },
      resource_metrics: %{
        peak_memory_mb: 50.0,
        avg_memory_mb: 45.0,
        total_memory_allocated_mb: 5.0,
        gc_collections: 2,
        process_count_peak: 10
      },
      summary: %{
        total_pipelines: 1,
        total_steps: 2,
        max_depth: 0,
        overall_success_rate: 100.0,
        performance_grade: :excellent,
        bottlenecks: [],
        recommendations: ["Performance appears optimal for current workload"]
      }
    }
  end
end