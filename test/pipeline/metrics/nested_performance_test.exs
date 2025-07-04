defmodule Pipeline.Metrics.NestedPerformanceTest do
  use ExUnit.Case, async: true
  
  alias Pipeline.Metrics.NestedPerformance

  describe "start_performance_tracking/2" do
    test "initializes performance tracking context" do
      trace_id = "test_trace_123"
      pipeline_id = "root_pipeline"
      
      context = NestedPerformance.start_performance_tracking(trace_id, pipeline_id)
      
      assert is_binary(context.execution_id)
      assert context.trace_id == trace_id
      assert is_struct(context.start_time, DateTime)
      assert context.end_time == nil
      assert context.total_duration_ms == nil
      assert context.pipeline_metrics == []
      assert context.depth_metrics == %{}
      assert is_map(context.resource_metrics)
      
      # Check initial resource metrics
      assert is_number(context.resource_metrics.peak_memory_mb)
      assert is_number(context.resource_metrics.avg_memory_mb)
      assert context.resource_metrics.total_memory_allocated_mb == 0.0
      assert is_number(context.resource_metrics.gc_collections)
      assert is_number(context.resource_metrics.process_count_peak)
      
      # Check initial summary
      assert context.summary.total_pipelines == 0
      assert context.summary.total_steps == 0
      assert context.summary.max_depth == 0
      assert context.summary.overall_success_rate == 0.0
      assert context.summary.performance_grade == :unknown
      assert context.summary.bottlenecks == []
      assert context.summary.recommendations == []
    end
  end

  describe "record_pipeline_metric/8" do
    test "records pipeline metrics and updates context" do
      context = NestedPerformance.start_performance_tracking("trace1", "root")
      
      updated_context = NestedPerformance.record_pipeline_metric(
        context,
        "test_pipeline",
        1,        # depth
        1500,     # duration_ms
        5,        # step_count
        true,     # success
        nil,      # error
        %{child_pipelines: ["child1", "child2"]}  # metadata
      )
      
      assert length(updated_context.pipeline_metrics) == 1
      
      metric = List.first(updated_context.pipeline_metrics)
      assert metric.pipeline_id == "test_pipeline"
      assert metric.depth == 1
      assert metric.duration_ms == 1500
      assert metric.step_count == 5
      assert metric.success == true
      assert metric.error == nil
      assert is_number(metric.memory_usage_mb)
      assert metric.child_pipelines == ["child1", "child2"]
      
      # Check summary updates
      assert updated_context.summary.total_pipelines == 1
      assert updated_context.summary.total_steps == 5
      assert updated_context.summary.max_depth == 1
      assert updated_context.summary.overall_success_rate == 100.0
      
      # Check depth metrics
      assert Map.has_key?(updated_context.depth_metrics, 1)
      depth_metric = updated_context.depth_metrics[1]
      assert depth_metric.pipeline_count == 1
      assert depth_metric.total_duration_ms == 1500
      assert depth_metric.avg_duration_ms == 1500.0
      assert depth_metric.step_count == 5
    end

    test "records failed pipeline metrics" do
      context = NestedPerformance.start_performance_tracking("trace1", "root")
      
      updated_context = NestedPerformance.record_pipeline_metric(
        context,
        "failed_pipeline",
        0,        # depth
        800,      # duration_ms
        3,        # step_count
        false,    # success
        "API timeout error"  # error
      )
      
      metric = List.first(updated_context.pipeline_metrics)
      assert metric.success == false
      assert metric.error == "API timeout error"
      
      # Success rate should be 0% for one failed pipeline
      assert updated_context.summary.overall_success_rate == 0.0
    end

    test "accumulates multiple pipeline metrics" do
      context = NestedPerformance.start_performance_tracking("trace1", "root")
      
      # Record first pipeline (success)
      context = NestedPerformance.record_pipeline_metric(
        context, "pipeline1", 0, 1000, 3, true
      )
      
      # Record second pipeline (success)
      context = NestedPerformance.record_pipeline_metric(
        context, "pipeline2", 1, 500, 2, true
      )
      
      # Record third pipeline (failure)
      context = NestedPerformance.record_pipeline_metric(
        context, "pipeline3", 1, 300, 1, false, "Error occurred"
      )
      
      assert length(context.pipeline_metrics) == 3
      assert context.summary.total_pipelines == 3
      assert context.summary.total_steps == 6  # 3 + 2 + 1
      assert context.summary.max_depth == 1
      
      # Success rate: 2 out of 3 = 66.67%
      assert abs(context.summary.overall_success_rate - 66.67) < 0.1
      
      # Check depth metrics accumulation
      depth_0_metrics = context.depth_metrics[0]
      assert depth_0_metrics.pipeline_count == 1
      assert depth_0_metrics.total_duration_ms == 1000
      
      depth_1_metrics = context.depth_metrics[1]
      assert depth_1_metrics.pipeline_count == 2
      assert depth_1_metrics.total_duration_ms == 800  # 500 + 300
      assert depth_1_metrics.avg_duration_ms == 400.0
      assert depth_1_metrics.min_duration_ms == 300
      assert depth_1_metrics.max_duration_ms == 500
    end
  end

  describe "complete_performance_tracking/1" do
    test "completes tracking and calculates final metrics" do
      context = NestedPerformance.start_performance_tracking("trace1", "root")
      
      # Add some metrics
      context = NestedPerformance.record_pipeline_metric(
        context, "pipeline1", 0, 1000, 3, true
      )
      context = NestedPerformance.record_pipeline_metric(
        context, "pipeline2", 1, 500, 2, true
      )
      
      # Wait a tiny bit to ensure duration > 0
      :timer.sleep(1)
      
      completed_context = NestedPerformance.complete_performance_tracking(context)
      
      assert is_struct(completed_context.end_time, DateTime)
      assert is_number(completed_context.total_duration_ms)
      assert completed_context.total_duration_ms > 0
      
      # Resource metrics should be updated
      assert completed_context.resource_metrics.peak_memory_mb >= completed_context.resource_metrics.avg_memory_mb
      
      # Summary should be finalized
      assert completed_context.summary.performance_grade != :unknown
      assert is_list(completed_context.summary.bottlenecks)
      assert is_list(completed_context.summary.recommendations)
    end
  end

  describe "analyze_performance/1" do
    test "analyzes performance and identifies issues" do
      # Create a performance context with various issues
      performance_metrics = create_performance_context_with_issues()
      
      analysis = NestedPerformance.analyze_performance(performance_metrics)
      
      assert is_atom(analysis.performance_grade)
      assert is_list(analysis.bottlenecks)
      assert is_list(analysis.performance_issues)
      assert is_map(analysis.resource_analysis)
      assert is_list(analysis.recommendations)
      assert is_number(analysis.efficiency_score)
      assert is_map(analysis.scalability_assessment)
      
      # Check scalability assessment structure
      assert Map.has_key?(analysis.scalability_assessment, :depth_scalability)
      assert Map.has_key?(analysis.scalability_assessment, :memory_scalability)
      assert Map.has_key?(analysis.scalability_assessment, :overall)
    end

    test "identifies memory bottlenecks" do
      performance_metrics = %{
        summary: %{total_pipelines: 2, max_depth: 2},
        pipeline_metrics: [
          %{duration_ms: 1000, step_count: 3},
          %{duration_ms: 800, step_count: 2}
        ],
        total_duration_ms: 1800,
        resource_metrics: %{peak_memory_mb: 1500.0}  # High memory usage
      }
      
      analysis = NestedPerformance.analyze_performance(performance_metrics)
      
      memory_bottleneck = Enum.find(analysis.bottlenecks, &String.contains?(&1, "memory"))
      assert memory_bottleneck != nil
      assert memory_bottleneck =~ "1500.0 MB"
    end

    test "identifies slow pipeline bottlenecks" do
      avg_duration = 1000
      total_duration = 3000
      
      performance_metrics = %{
        summary: %{total_pipelines: 3, max_depth: 1},
        pipeline_metrics: [
          %{duration_ms: 500, step_count: 2, pipeline_id: "fast_pipeline"},
          %{duration_ms: 1000, step_count: 3, pipeline_id: "normal_pipeline"},
          %{duration_ms: 2500, step_count: 5, pipeline_id: "slow_pipeline"}  # Much slower than average
        ],
        total_duration_ms: total_duration,
        resource_metrics: %{peak_memory_mb: 100.0}
      }
      
      analysis = NestedPerformance.analyze_performance(performance_metrics)
      
      slow_bottleneck = Enum.find(analysis.bottlenecks, &String.contains?(&1, "Slow pipelines"))
      assert slow_bottleneck != nil
      assert slow_bottleneck =~ "slow_pipeline"
    end

    test "identifies deep nesting bottlenecks" do
      performance_metrics = %{
        summary: %{total_pipelines: 1, max_depth: 8},  # Deep nesting
        pipeline_metrics: [%{duration_ms: 1000, step_count: 3}],
        total_duration_ms: 1000,
        resource_metrics: %{peak_memory_mb: 100.0}
      }
      
      analysis = NestedPerformance.analyze_performance(performance_metrics)
      
      depth_bottleneck = Enum.find(analysis.bottlenecks, &String.contains?(&1, "Deep nesting"))
      assert depth_bottleneck != nil
      assert depth_bottleneck =~ "depth: 8"
    end

    test "detects low success rate performance issue" do
      performance_metrics = %{
        summary: %{overall_success_rate: 85.0, total_pipelines: 10, max_depth: 2},  # Below 95%
        pipeline_metrics: [],
        total_duration_ms: 5000,
        resource_metrics: %{peak_memory_mb: 100.0}
      }
      
      analysis = NestedPerformance.analyze_performance(performance_metrics)
      
      success_issue = Enum.find(analysis.performance_issues, &(&1.type == :low_success_rate))
      assert success_issue != nil
      assert success_issue.severity == :error
      assert success_issue.description =~ "85.0%"
    end

    test "detects long execution performance issue" do
      performance_metrics = %{
        summary: %{overall_success_rate: 100.0, total_pipelines: 1, max_depth: 1},
        pipeline_metrics: [%{duration_ms: 70000, step_count: 3}],  # Over 1 minute
        total_duration_ms: 70000,
        resource_metrics: %{peak_memory_mb: 100.0}
      }
      
      analysis = NestedPerformance.analyze_performance(performance_metrics)
      
      duration_issue = Enum.find(analysis.performance_issues, &(&1.type == :long_execution))
      assert duration_issue != nil
      assert duration_issue.severity == :warning
    end

    test "calculates efficiency score" do
      performance_metrics = %{
        summary: %{
          total_steps: 10,
          overall_success_rate: 90.0,  # 90% success rate
          total_pipelines: 3,
          max_depth: 2
        },
        total_duration_ms: 5000,  # 5 seconds
        resource_metrics: %{peak_memory_mb: 200.0},  # 200MB peak
        pipeline_metrics: []
      }
      
      analysis = NestedPerformance.analyze_performance(performance_metrics)
      
      # Efficiency = (successful_steps) / (time_factor * memory_factor)
      # successful_steps = 10 * 0.9 = 9
      # time_factor = 5000 / 1000 = 5
      # memory_factor = 200 / 100 = 2
      # efficiency = 9 / (5 * 2) = 0.9
      assert abs(analysis.efficiency_score - 0.9) < 0.1
    end
  end

  describe "generate_performance_report/2" do
    test "generates comprehensive performance report" do
      performance_metrics = create_sample_performance_metrics()
      
      report = NestedPerformance.generate_performance_report(performance_metrics)
      
      assert report =~ "📊 NESTED PIPELINE PERFORMANCE REPORT"
      assert report =~ "Execution ID:"
      assert report =~ "Trace ID:"
      assert report =~ "Performance Grade:"
      assert report =~ "🎯 EXECUTION OVERVIEW"
      assert report =~ "Total Duration:"
      assert report =~ "Total Pipelines:"
      assert report =~ "📏 DEPTH ANALYSIS"
      assert report =~ "💾 RESOURCE ANALYSIS"
      assert report =~ "⚡ PERFORMANCE ANALYSIS"
    end

    test "includes detailed metrics when requested" do
      performance_metrics = create_sample_performance_metrics()
      options = %{include_details: true}
      
      report = NestedPerformance.generate_performance_report(performance_metrics, options)
      
      assert report =~ "📋 DETAILED METRICS"
      assert report =~ "Pipeline Execution Details:"
    end

    test "excludes recommendations when requested" do
      performance_metrics = create_sample_performance_metrics()
      options = %{include_recommendations: false}
      
      report = NestedPerformance.generate_performance_report(performance_metrics, options)
      
      refute report =~ "💡 RECOMMENDATIONS"
    end
  end

  describe "compare_performance/2" do
    test "compares multiple performance metrics" do
      metrics1 = create_sample_performance_metrics("trace1", 1000)
      metrics2 = create_sample_performance_metrics("trace2", 1500) 
      metrics3 = create_sample_performance_metrics("trace3", 800)
      
      comparison = NestedPerformance.compare_performance([metrics1, metrics2, metrics3])
      
      assert comparison =~ "📊 PERFORMANCE COMPARISON"
      assert comparison =~ "Executions Compared: 3"
      assert comparison =~ "Average Duration:"
      assert comparison =~ "Duration Variance:"
      assert comparison =~ "Success Rate Trend:"
    end

    test "handles insufficient data gracefully" do
      metrics1 = create_sample_performance_metrics("single", 1000)
      
      comparison = NestedPerformance.compare_performance([metrics1])
      
      assert comparison == "At least 2 performance metrics required for comparison"
    end
  end

  describe "emit_performance_telemetry/2" do
    test "emits telemetry without errors" do
      performance_metrics = create_sample_performance_metrics()
      
      # Should not raise any errors
      assert :ok == NestedPerformance.emit_performance_telemetry(performance_metrics)
      assert :ok == NestedPerformance.emit_performance_telemetry(performance_metrics, :custom_event)
    end
  end

  describe "performance calculations" do
    test "calculates performance grade correctly" do
      # Test excellent performance
      excellent_metrics = %{
        summary: %{overall_success_rate: 100.0, max_depth: 2, total_pipelines: 3},
        total_duration_ms: 500,  # Fast execution
        resource_metrics: %{peak_memory_mb: 50.0, gc_collections: 2, process_count_peak: 10},
        pipeline_metrics: []
      }
      
      analysis = NestedPerformance.analyze_performance(excellent_metrics)
      assert analysis.performance_grade == :excellent
      
      # Test poor performance  
      poor_metrics = %{
        summary: %{overall_success_rate: 60.0, max_depth: 12, total_pipelines: 20},  # Low success, deep nesting
        total_duration_ms: 45000,  # Very slow
        resource_metrics: %{peak_memory_mb: 2000.0, gc_collections: 50, process_count_peak: 200},  # High resource usage
        pipeline_metrics: []
      }
      
      analysis_poor = NestedPerformance.analyze_performance(poor_metrics)
      assert analysis_poor.performance_grade == :poor
    end

    test "assesses scalability correctly" do
      # Good scalability
      good_scalability_metrics = %{
        summary: %{max_depth: 3, total_pipelines: 5},
        resource_metrics: %{peak_memory_mb: 150.0},
        pipeline_metrics: []
      }
      
      analysis = NestedPerformance.analyze_performance(good_scalability_metrics)
      assert analysis.scalability_assessment.depth_scalability == :excellent
      assert analysis.scalability_assessment.memory_scalability == :good
      assert analysis.scalability_assessment.overall == :excellent  # min of the two
      
      # Poor scalability
      poor_scalability_metrics = %{
        summary: %{max_depth: 15, total_pipelines: 20},  # Very deep
        resource_metrics: %{peak_memory_mb: 2500.0},     # Very high memory
        pipeline_metrics: []
      }
      
      analysis_poor = NestedPerformance.analyze_performance(poor_scalability_metrics)
      assert analysis_poor.scalability_assessment.depth_scalability == :poor
      assert analysis_poor.scalability_assessment.memory_scalability == :poor
      assert analysis_poor.scalability_assessment.overall == :poor
    end
  end

  describe "resource analysis" do
    test "analyzes memory efficiency" do
      # Excellent memory efficiency (low memory per pipeline)
      efficient_metrics = %{
        summary: %{total_pipelines: 10},
        resource_metrics: %{peak_memory_mb: 80.0},  # 8MB per pipeline
        pipeline_metrics: []
      }
      
      analysis = NestedPerformance.analyze_performance(efficient_metrics)
      assert analysis.resource_analysis.memory_efficiency == :excellent
      
      # Poor memory efficiency (high memory per pipeline)
      inefficient_metrics = %{
        summary: %{total_pipelines: 5},
        resource_metrics: %{peak_memory_mb: 600.0},  # 120MB per pipeline
        pipeline_metrics: []
      }
      
      analysis_poor = NestedPerformance.analyze_performance(inefficient_metrics)
      assert analysis_poor.resource_analysis.memory_efficiency == :poor
    end
  end

  # Helper functions for creating test data

  defp create_performance_context_with_issues do
    %{
      execution_id: "test_execution",
      trace_id: "test_trace",
      start_time: DateTime.utc_now() |> DateTime.add(-10, :second),
      end_time: DateTime.utc_now(),
      total_duration_ms: 10000,
      pipeline_metrics: [
        %{pipeline_id: "slow_pipeline", duration_ms: 8000, step_count: 5, success: true},
        %{pipeline_id: "fast_pipeline", duration_ms: 500, step_count: 2, success: true},
        %{pipeline_id: "failed_pipeline", duration_ms: 1000, step_count: 3, success: false}
      ],
      depth_metrics: %{
        0 => %{pipeline_count: 1, total_duration_ms: 8000, avg_duration_ms: 8000.0, success_rate: 100.0},
        1 => %{pipeline_count: 2, total_duration_ms: 1500, avg_duration_ms: 750.0, success_rate: 50.0}
      },
      resource_metrics: %{
        peak_memory_mb: 1200.0,
        avg_memory_mb: 800.0,
        gc_collections: 25,
        process_count_peak: 150
      },
      summary: %{
        total_pipelines: 3,
        total_steps: 10,
        max_depth: 6,  # Deep nesting
        overall_success_rate: 66.67,  # Low success rate
        performance_grade: :unknown,
        bottlenecks: [],
        recommendations: []
      }
    }
  end

  defp create_sample_performance_metrics(trace_id \\ "sample_trace", duration \\ 2000) do
    %{
      execution_id: "sample_execution",
      trace_id: trace_id,
      start_time: DateTime.utc_now() |> DateTime.add(-duration, :millisecond),
      end_time: DateTime.utc_now(),
      total_duration_ms: duration,
      pipeline_metrics: [
        %{
          pipeline_id: "sample_pipeline_1",
          depth: 0,
          duration_ms: div(duration, 2),
          step_count: 3,
          success: true,
          error: nil,
          memory_usage_mb: 100.0,
          child_pipelines: ["child1"]
        },
        %{
          pipeline_id: "sample_pipeline_2", 
          depth: 1,
          duration_ms: div(duration, 4),
          step_count: 2,
          success: true,
          error: nil,
          memory_usage_mb: 75.0,
          child_pipelines: []
        }
      ],
      depth_metrics: %{
        0 => %{
          depth: 0,
          pipeline_count: 1,
          total_duration_ms: div(duration, 2),
          avg_duration_ms: div(duration, 2) * 1.0,
          min_duration_ms: div(duration, 2),
          max_duration_ms: div(duration, 2),
          success_rate: 100.0,
          step_count: 3
        },
        1 => %{
          depth: 1,
          pipeline_count: 1,
          total_duration_ms: div(duration, 4),
          avg_duration_ms: div(duration, 4) * 1.0,
          min_duration_ms: div(duration, 4),
          max_duration_ms: div(duration, 4),
          success_rate: 100.0,
          step_count: 2
        }
      },
      resource_metrics: %{
        peak_memory_mb: 150.0,
        avg_memory_mb: 125.0,
        total_memory_allocated_mb: 25.0,
        gc_collections: 5,
        process_count_peak: 20
      },
      summary: %{
        total_pipelines: 2,
        total_steps: 5,
        max_depth: 1,
        overall_success_rate: 100.0,
        performance_grade: :good,
        bottlenecks: [],
        recommendations: ["Performance appears optimal for current workload"]
      }
    }
  end
end