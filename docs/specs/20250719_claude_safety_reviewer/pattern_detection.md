# Pattern Detection System - Detailed Design

## Overview

The Pattern Detection System identifies behavioral patterns in Claude's actions that indicate potential issues such as getting stuck, going off-track, or exhibiting problematic behaviors. It works by analyzing sequences of actions and their outcomes to detect anomalies.

## Core Patterns

### 1. Repetitive Error Pattern

Detects when Claude repeatedly encounters the same error without making progress.

```elixir
defmodule Pipeline.Safety.Patterns.RepetitiveErrors do
  @behaviour Pipeline.Safety.Pattern
  
  @impl true
  def detect(history, _context) do
    recent_errors = get_recent_errors(history, window: 10)
    
    error_groups = Enum.group_by(recent_errors, &normalize_error/1)
    
    max_repetition = error_groups
                     |> Map.values()
                     |> Enum.map(&length/1)
                     |> Enum.max(fn -> 0 end)
    
    %PatternMatch{
      detected: max_repetition >= 3,
      confidence: min(max_repetition / 5, 1.0),
      severity: calculate_severity(max_repetition),
      details: %{
        repeated_error: find_most_repeated_error(error_groups),
        repetition_count: max_repetition,
        window_size: 10
      }
    }
  end
  
  defp normalize_error(error) do
    # Normalize errors to detect same type regardless of specifics
    error
    |> strip_paths()
    |> strip_line_numbers()
    |> categorize_error_type()
  end
  
  defp calculate_severity(count) do
    cond do
      count >= 5 -> :critical
      count >= 4 -> :high
      count >= 3 -> :medium
      true -> :low
    end
  end
end
```

### 2. Scope Creep Pattern

Detects when Claude starts working outside the expected scope of the task.

```elixir
defmodule Pipeline.Safety.Patterns.ScopeCreep do
  @behaviour Pipeline.Safety.Pattern
  
  @impl true
  def detect(history, context) do
    expected_paths = extract_expected_paths(context)
    accessed_paths = extract_accessed_paths(history)
    
    out_of_scope = MapSet.difference(
      MapSet.new(accessed_paths),
      MapSet.new(expected_paths)
    )
    
    scope_ratio = MapSet.size(out_of_scope) / max(length(accessed_paths), 1)
    
    %PatternMatch{
      detected: scope_ratio > 0.3,
      confidence: scope_ratio,
      severity: calculate_scope_severity(scope_ratio, out_of_scope),
      details: %{
        expected_paths: expected_paths,
        out_of_scope_paths: MapSet.to_list(out_of_scope),
        scope_expansion_ratio: scope_ratio,
        critical_paths_accessed: find_critical_paths(out_of_scope)
      }
    }
  end
  
  defp extract_expected_paths(context) do
    # Derive expected paths from:
    # 1. Explicit scope configuration
    # 2. Initial prompt analysis
    # 3. Project structure
    base_paths = context.config[:allowed_paths] || []
    
    inferred_paths = infer_paths_from_prompt(context.initial_prompt)
    
    (base_paths ++ inferred_paths)
    |> Enum.flat_map(&expand_glob/1)
    |> Enum.uniq()
  end
  
  defp find_critical_paths(paths) do
    critical_patterns = [
      ~r/\.env/,
      ~r/config\/secret/,
      ~r/\.git\//,
      ~r/node_modules\//,
      ~r/\/etc\//
    ]
    
    Enum.filter(paths, fn path ->
      Enum.any?(critical_patterns, &Regex.match?(&1, path))
    end)
  end
end
```

### 3. Goal Drift Pattern

Detects when Claude's actions drift away from the original objectives.

```elixir
defmodule Pipeline.Safety.Patterns.GoalDrift do
  @behaviour Pipeline.Safety.Pattern
  
  @impl true
  def detect(history, context) do
    goals = extract_goals(context)
    recent_actions = get_recent_actions(history, 20)
    
    alignment_scores = Enum.map(recent_actions, fn action ->
      calculate_goal_alignment(action, goals)
    end)
    
    avg_alignment = Enum.sum(alignment_scores) / max(length(alignment_scores), 1)
    drift_trend = calculate_drift_trend(alignment_scores)
    
    %PatternMatch{
      detected: avg_alignment < 0.5 && drift_trend < -0.3,
      confidence: 1.0 - avg_alignment,
      severity: calculate_drift_severity(avg_alignment, drift_trend),
      details: %{
        average_alignment: avg_alignment,
        drift_trend: drift_trend,
        goals: goals,
        misaligned_actions: find_misaligned_actions(recent_actions, goals)
      }
    }
  end
  
  defp calculate_goal_alignment(action, goals) do
    # Use semantic analysis to determine alignment
    action_intent = extract_action_intent(action)
    
    goal_scores = Enum.map(goals, fn goal ->
      semantic_similarity(action_intent, goal)
    end)
    
    Enum.max(goal_scores, fn -> 0.0 end)
  end
  
  defp calculate_drift_trend(scores) do
    # Calculate trend using linear regression
    indexed_scores = Enum.with_index(scores)
    
    {slope, _intercept} = linear_regression(indexed_scores)
    slope
  end
  
  defp semantic_similarity(text1, text2) do
    # Simplified semantic similarity
    # In production, use embeddings or more sophisticated NLP
    words1 = tokenize(text1)
    words2 = tokenize(text2)
    
    intersection = MapSet.intersection(
      MapSet.new(words1),
      MapSet.new(words2)
    )
    
    union = MapSet.union(
      MapSet.new(words1),
      MapSet.new(words2)
    )
    
    MapSet.size(intersection) / max(MapSet.size(union), 1)
  end
end
```

### 4. Resource Spiral Pattern

Detects exponentially increasing resource usage that could lead to system issues.

```elixir
defmodule Pipeline.Safety.Patterns.ResourceSpiral do
  @behaviour Pipeline.Safety.Pattern
  
  @impl true
  def detect(history, _context) do
    resource_metrics = extract_resource_metrics(history)
    
    patterns = %{
      memory: detect_spiral(resource_metrics.memory),
      file_operations: detect_spiral(resource_metrics.file_ops),
      api_calls: detect_spiral(resource_metrics.api_calls),
      execution_time: detect_spiral(resource_metrics.exec_times)
    }
    
    any_spiral = Enum.any?(patterns, fn {_, result} -> result.detected end)
    max_severity = patterns
                   |> Map.values()
                   |> Enum.map(& &1.severity)
                   |> Enum.max()
    
    %PatternMatch{
      detected: any_spiral,
      confidence: calculate_spiral_confidence(patterns),
      severity: max_severity,
      details: %{
        patterns: patterns,
        projected_exhaustion: project_resource_exhaustion(patterns),
        recommendations: generate_resource_recommendations(patterns)
      }
    }
  end
  
  defp detect_spiral(measurements) do
    return unless length(measurements) >= 3
    
    # Calculate growth rates
    growth_rates = measurements
                   |> Enum.chunk_every(2, 1, :discard)
                   |> Enum.map(fn [a, b] -> b / max(a, 1) end)
    
    avg_growth = Enum.sum(growth_rates) / length(growth_rates)
    
    %{
      detected: avg_growth > 1.5,
      growth_rate: avg_growth,
      severity: calculate_growth_severity(avg_growth)
    }
  end
  
  defp project_resource_exhaustion(patterns) do
    projections = Enum.map(patterns, fn {resource, pattern} ->
      if pattern.detected do
        steps_to_limit = calculate_steps_to_limit(
          resource,
          pattern.growth_rate
        )
        {resource, steps_to_limit}
      else
        {resource, :no_risk}
      end
    end)
    
    Map.new(projections)
  end
end
```

### 5. Exploration Wandering Pattern

Detects when Claude explores the codebase without clear direction.

```elixir
defmodule Pipeline.Safety.Patterns.ExplorationWandering do
  @behaviour Pipeline.Safety.Pattern
  
  @impl true
  def detect(history, context) do
    movement_pattern = analyze_movement_pattern(history)
    
    metrics = %{
      unique_directories: count_unique_directories(movement_pattern),
      backtracking_ratio: calculate_backtracking(movement_pattern),
      depth_variance: calculate_depth_variance(movement_pattern),
      focus_score: calculate_focus_score(movement_pattern)
    }
    
    wandering_score = calculate_wandering_score(metrics)
    
    %PatternMatch{
      detected: wandering_score > 0.7,
      confidence: wandering_score,
      severity: calculate_wandering_severity(wandering_score, context),
      details: %{
        metrics: metrics,
        movement_visualization: visualize_movement(movement_pattern),
        suggested_focus: suggest_exploration_focus(history, context)
      }
    }
  end
  
  defp analyze_movement_pattern(history) do
    history
    |> Enum.filter(&file_operation?/1)
    |> Enum.map(&extract_path/1)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] ->
      %{
        from: from,
        to: to,
        distance: calculate_path_distance(from, to),
        direction: calculate_direction(from, to)
      }
    end)
  end
  
  defp calculate_wandering_score(metrics) do
    weights = %{
      unique_directories: 0.3,
      backtracking_ratio: 0.3,
      depth_variance: 0.2,
      focus_score: 0.2
    }
    
    Enum.reduce(weights, 0.0, fn {metric, weight}, acc ->
      acc + (Map.get(metrics, metric, 0) * weight)
    end)
  end
end
```

### 6. Hallucination Pattern

Detects when Claude references non-existent files or makes incorrect assumptions.

```elixir
defmodule Pipeline.Safety.Patterns.Hallucination do
  @behaviour Pipeline.Safety.Pattern
  
  @impl true
  def detect(history, _context) do
    hallucinations = find_hallucinations(history)
    
    hallucination_rate = length(hallucinations) / max(length(history), 1)
    
    %PatternMatch{
      detected: length(hallucinations) >= 2,
      confidence: min(hallucination_rate * 10, 1.0),
      severity: calculate_hallucination_severity(hallucinations),
      details: %{
        hallucinations: hallucinations,
        types: categorize_hallucinations(hallucinations),
        recovery_attempts: count_recovery_attempts(history, hallucinations)
      }
    }
  end
  
  defp find_hallucinations(history) do
    history
    |> Enum.filter(fn action ->
      case action do
        %{type: :file_read, result: {:error, :not_found}, assumed_exists: true} ->
          true
          
        %{type: :reference, target: target, exists: false} ->
          true
          
        %{type: :assertion, claim: claim, verified: false} ->
          true
          
        _ ->
          false
      end
    end)
  end
  
  defp categorize_hallucinations(hallucinations) do
    Enum.group_by(hallucinations, fn h ->
      cond do
        h.type == :file_read -> :phantom_files
        h.type == :reference -> :incorrect_references
        h.type == :assertion -> :false_assumptions
        true -> :other
      end
    end)
  end
end
```

## Pattern Composition

### 1. Composite Pattern Detection

```elixir
defmodule Pipeline.Safety.Patterns.CompositeDetector do
  @patterns [
    RepetitiveErrors,
    ScopeCreep,
    GoalDrift,
    ResourceSpiral,
    ExplorationWandering,
    Hallucination
  ]
  
  def detect_all_patterns(history, context) do
    pattern_results = Enum.map(@patterns, fn pattern_module ->
      result = pattern_module.detect(history, context)
      {pattern_module, result}
    end)
    
    # Check for pattern combinations that amplify risk
    combined_patterns = detect_pattern_combinations(pattern_results)
    
    %{
      individual_patterns: pattern_results,
      combined_patterns: combined_patterns,
      overall_risk: calculate_overall_risk(pattern_results, combined_patterns),
      recommendations: generate_recommendations(pattern_results, combined_patterns)
    }
  end
  
  defp detect_pattern_combinations(results) do
    combinations = [
      # Stuck in error loop while exploring
      {:error_exploration_loop, [:repetitive_errors, :exploration_wandering], 1.5},
      
      # Resource exhaustion with goal drift  
      {:runaway_execution, [:resource_spiral, :goal_drift], 2.0},
      
      # Hallucinating while out of scope
      {:confused_state, [:hallucination, :scope_creep], 1.8}
    ]
    
    Enum.filter(combinations, fn {_name, required_patterns, _multiplier} ->
      all_detected?(required_patterns, results)
    end)
  end
end
```

### 2. Pattern Learning System

```elixir
defmodule Pipeline.Safety.Patterns.LearningSystem do
  use GenServer
  
  @moduledoc """
  Learns from pattern detections to improve accuracy over time
  """
  
  def record_pattern_outcome(pattern_id, detection_result, actual_outcome) do
    GenServer.cast(__MODULE__, {
      :record_outcome,
      pattern_id,
      detection_result,
      actual_outcome
    })
  end
  
  def get_pattern_accuracy(pattern_id) do
    GenServer.call(__MODULE__, {:get_accuracy, pattern_id})
  end
  
  def handle_cast({:record_outcome, pattern_id, detection, outcome}, state) do
    updated_stats = update_pattern_stats(
      state.pattern_stats,
      pattern_id,
      detection,
      outcome
    )
    
    # Adjust thresholds if accuracy is low
    new_thresholds = if should_adjust_thresholds?(updated_stats[pattern_id]) do
      optimize_thresholds(pattern_id, updated_stats[pattern_id])
    else
      state.thresholds
    end
    
    {:noreply, %{state | 
      pattern_stats: updated_stats,
      thresholds: new_thresholds
    }}
  end
  
  defp update_pattern_stats(stats, pattern_id, detection, outcome) do
    current = Map.get(stats, pattern_id, %{
      true_positives: 0,
      false_positives: 0,
      true_negatives: 0,
      false_negatives: 0
    })
    
    updated = case {detection.detected, outcome} do
      {true, :confirmed} -> %{current | true_positives: current.true_positives + 1}
      {true, :false_alarm} -> %{current | false_positives: current.false_positives + 1}
      {false, :missed} -> %{current | false_negatives: current.false_negatives + 1}
      {false, :correct} -> %{current | true_negatives: current.true_negatives + 1}
    end
    
    Map.put(stats, pattern_id, updated)
  end
end
```

## Pattern Configuration

### 1. Configuration Schema

```yaml
pattern_detection:
  enabled_patterns:
    - repetitive_errors
    - scope_creep
    - goal_drift
    - resource_spiral
    - exploration_wandering
    - hallucination
  
  pattern_configs:
    repetitive_errors:
      window_size: 10
      threshold: 3
      normalization_level: medium  # low | medium | high
    
    scope_creep:
      allowed_expansion_ratio: 0.3
      critical_paths:
        - "**/.env*"
        - "**/secrets/**"
        - ".git/**"
      inference_enabled: true
    
    goal_drift:
      alignment_threshold: 0.5
      trend_window: 20
      semantic_analysis: basic  # basic | advanced
    
    resource_spiral:
      growth_threshold: 1.5
      measurement_window: 5
      resources_monitored:
        - memory
        - file_operations
        - api_calls
        - execution_time
    
    exploration_wandering:
      wandering_threshold: 0.7
      max_unique_directories: 20
      backtrack_limit: 0.4
    
    hallucination:
      detection_confidence: 0.8
      min_occurrences: 2
      verify_references: true
  
  combination_detection:
    enabled: true
    risk_multipliers:
      error_exploration_loop: 1.5
      runaway_execution: 2.0
      confused_state: 1.8
  
  learning:
    enabled: true
    adjustment_threshold: 0.7  # Accuracy below this triggers adjustment
    history_retention_days: 30
```

### 2. Pattern Customization

```elixir
defmodule MyCustomPattern do
  @behaviour Pipeline.Safety.Pattern
  
  @impl true
  def detect(history, context) do
    # Custom detection logic
    suspicious_actions = find_suspicious_actions(history)
    
    %PatternMatch{
      detected: length(suspicious_actions) > 0,
      confidence: calculate_confidence(suspicious_actions),
      severity: :medium,
      details: %{
        actions: suspicious_actions,
        recommendation: "Review suspicious actions"
      }
    }
  end
  
  defp find_suspicious_actions(history) do
    # Implementation specific to your use case
  end
end

# Register custom pattern
Pipeline.Safety.Patterns.register(MyCustomPattern, :custom_suspicious)
```

## Testing Patterns

### 1. Pattern Test Framework

```elixir
defmodule Pipeline.Safety.PatternTestHelper do
  def create_test_history(scenario) do
    case scenario do
      :repetitive_errors ->
        [
          action(:file_read, error: :not_found),
          action(:file_read, error: :not_found),
          action(:file_read, error: :not_found),
          action(:file_read, error: :not_found)
        ]
        
      :scope_creep ->
        [
          action(:file_read, path: "/project/src/main.ex"),
          action(:file_read, path: "/project/lib/helper.ex"),
          action(:file_read, path: "/etc/passwd"),
          action(:file_write, path: "/var/log/app.log")
        ]
        
      :resource_spiral ->
        [
          action(:memory_usage, value: 100),
          action(:memory_usage, value: 200),
          action(:memory_usage, value: 450),
          action(:memory_usage, value: 1100)
        ]
    end
  end
  
  def assert_pattern_detected(pattern_module, scenario, context \\ %{}) do
    history = create_test_history(scenario)
    result = pattern_module.detect(history, context)
    
    assert result.detected == true
    assert result.confidence > 0.5
  end
end
```

### 2. Pattern Unit Tests

```elixir
defmodule Pipeline.Safety.Patterns.RepetitiveErrorsTest do
  use ExUnit.Case
  import Pipeline.Safety.PatternTestHelper
  
  test "detects repetitive errors" do
    assert_pattern_detected(RepetitiveErrors, :repetitive_errors)
  end
  
  test "does not detect with different errors" do
    history = [
      action(:file_read, error: :not_found),
      action(:file_write, error: :permission_denied),
      action(:network, error: :timeout)
    ]
    
    result = RepetitiveErrors.detect(history, %{})
    
    assert result.detected == false
  end
  
  test "calculates severity based on repetition count" do
    history = List.duplicate(action(:file_read, error: :not_found), 5)
    
    result = RepetitiveErrors.detect(history, %{})
    
    assert result.severity == :critical
    assert result.details.repetition_count == 5
  end
end
```

## Monitoring and Observability

### 1. Pattern Metrics

```elixir
defmodule Pipeline.Safety.Patterns.Metrics do
  def record_detection(pattern_id, result) do
    labels = %{
      pattern: to_string(pattern_id),
      detected: to_string(result.detected),
      severity: to_string(result.severity)
    }
    
    # Increment detection counter
    :telemetry.execute(
      [:pipeline, :safety, :pattern, :detection],
      %{count: 1},
      labels
    )
    
    # Record confidence distribution
    :telemetry.execute(
      [:pipeline, :safety, :pattern, :confidence],
      %{value: result.confidence},
      labels
    )
  end
  
  def pattern_dashboard_config() do
    %{
      graphs: [
        %{
          title: "Pattern Detection Rate",
          query: "rate(pipeline_safety_pattern_detection_total[5m])",
          type: :line
        },
        %{
          title: "Pattern Confidence Distribution",
          query: "histogram_quantile(0.95, pipeline_safety_pattern_confidence)",
          type: :histogram
        },
        %{
          title: "Top Detected Patterns",
          query: "topk(5, sum by (pattern) (pipeline_safety_pattern_detection_total))",
          type: :bar
        }
      ],
      alerts: [
        %{
          name: "high_pattern_detection_rate",
          expr: "rate(pipeline_safety_pattern_detection_total{detected=\"true\"}[5m]) > 0.1",
          message: "High rate of pattern detections"
        }
      ]
    }
  end
end
```