# Iterative Refinement System for Invalid Pipelines

## Overview

This document describes a sophisticated iterative refinement system that works with LLMs to progressively improve invalid pipeline configurations. The system uses validation feedback, error analysis, and intelligent prompting to guide LLMs toward generating valid, optimized pipelines through multiple refinement cycles.

## Refinement Architecture

```
┌──────────────────┐
│ Initial Pipeline │
│   (from LLM)     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────┐
│   Validation     │────▶│  Error Analysis  │
│    Pipeline      │     │   & Scoring      │
└────────┬─────────┘     └────────┬─────────┘
         │                         │
         │ Valid                   │ Invalid
         ▼                         ▼
┌──────────────────┐     ┌──────────────────┐
│     Success      │     │ Refinement Loop  │
│   (Complete)     │     │   Controller     │
└──────────────────┘     └────────┬─────────┘
                                   │
                          ┌────────▼─────────┐
                          │                  │
                 ┌────────▼──────┐  ┌───────▼────────┐
                 │  LLM Refiner  │  │ Auto-Repairer  │
                 │  (Complex)    │  │   (Simple)     │
                 └────────┬──────┘  └───────┬────────┘
                          │                  │
                          └────────┬─────────┘
                                   │
                                   ▼
                          ┌──────────────────┐
                          │ Refined Pipeline │
                          │   (Iteration)    │
                          └──────────────────┘
```

## Core Components

### 1. Refinement Controller

```elixir
defmodule Pipeline.Refinement.Controller do
  @moduledoc """
  Orchestrates the iterative refinement process.
  """
  
  defstruct [
    :max_iterations,
    :convergence_threshold,
    :refinement_strategy,
    :history,
    :context
  ]
  
  def refine(initial_pipeline, context, opts \\ []) do
    controller = %__MODULE__{
      max_iterations: opts[:max_iterations] || 5,
      convergence_threshold: opts[:threshold] || 0.95,
      refinement_strategy: opts[:strategy] || :adaptive,
      history: [],
      context: context
    }
    
    iterate_refinement(initial_pipeline, controller)
  end
  
  defp iterate_refinement(pipeline, controller, iteration \\ 1) do
    # Validate current pipeline
    validation_result = validate_comprehensive(pipeline, controller.context)
    
    # Update history
    controller = update_history(controller, pipeline, validation_result)
    
    # Check termination conditions
    cond do
      validation_result.score >= controller.convergence_threshold ->
        {:ok, pipeline, controller.history}
        
      iteration >= controller.max_iterations ->
        {:max_iterations, pipeline, controller.history}
        
      is_stuck?(controller.history) ->
        {:stuck, pipeline, controller.history}
        
      true ->
        # Continue refinement
        refined = apply_refinement_strategy(
          pipeline, 
          validation_result, 
          controller
        )
        
        iterate_refinement(refined, controller, iteration + 1)
    end
  end
  
  defp is_stuck?(history) do
    # Detect if we're making no progress
    recent = Enum.take(history, -3)
    
    case recent do
      [a, b, c] -> 
        # Check if scores are not improving
        abs(a.score - b.score) < 0.01 and abs(b.score - c.score) < 0.01
      _ -> 
        false
    end
  end
end
```

### 2. Validation Scoring System

```elixir
defmodule Pipeline.Refinement.Scorer do
  @moduledoc """
  Score pipeline validity and quality for refinement decisions.
  """
  
  @weights %{
    syntax: 0.2,
    schema: 0.3,
    semantic: 0.3,
    execution: 0.2
  }
  
  def score_pipeline(pipeline, validation_results) do
    scores = %{
      syntax: score_syntax(validation_results.syntax),
      schema: score_schema(validation_results.schema),
      semantic: score_semantic(validation_results.semantic),
      execution: score_execution(validation_results.execution)
    }
    
    weighted_score = calculate_weighted_score(scores, @weights)
    
    %{
      overall_score: weighted_score,
      component_scores: scores,
      critical_errors: find_critical_errors(validation_results),
      improvement_priority: prioritize_improvements(scores)
    }
  end
  
  defp score_syntax(result) do
    case result do
      {:ok, _} -> 1.0
      {:error, :minor_fixes} -> 0.8
      {:error, :major_fixes} -> 0.5
      {:error, :unparseable} -> 0.0
    end
  end
  
  defp score_semantic(result) do
    case result do
      {:ok, _} -> 1.0
      {:error, errors} ->
        # Score based on error severity and count
        base_score = 1.0
        deduction = Enum.reduce(errors, 0, fn error, acc ->
          acc + error_weight(error)
        end)
        max(0, base_score - deduction)
    end
  end
  
  defp prioritize_improvements(scores) do
    scores
    |> Enum.filter(fn {_, score} -> score < 1.0 end)
    |> Enum.sort_by(fn {type, score} -> 
      {score, priority_order(type)}
    end)
    |> Enum.map(fn {type, _} -> type end)
  end
end
```

### 3. Adaptive Refinement Strategy

```elixir
defmodule Pipeline.Refinement.AdaptiveStrategy do
  @moduledoc """
  Adapts refinement approach based on error patterns and history.
  """
  
  def select_refinement_approach(pipeline, validation, history) do
    error_pattern = analyze_error_pattern(validation)
    progress_trend = analyze_progress(history)
    
    case {error_pattern, progress_trend} do
      {:simple_fixes, _} ->
        {:auto_repair, select_repair_functions(validation)}
        
      {:complex_semantic, :improving} ->
        {:llm_guided, build_focused_prompt(validation)}
        
      {:complex_semantic, :stuck} ->
        {:llm_restructure, build_restructure_prompt(pipeline, validation)}
        
      {:mixed, :improving} ->
        {:hybrid, combine_strategies(validation)}
        
      _ ->
        {:llm_comprehensive, build_comprehensive_prompt(validation)}
    end
  end
  
  defp analyze_error_pattern(validation) do
    errors = collect_all_errors(validation)
    
    cond do
      all_simple_fixes?(errors) -> :simple_fixes
      mostly_semantic?(errors) -> :complex_semantic
      mostly_structural?(errors) -> :structural
      true -> :mixed
    end
  end
  
  defp analyze_progress(history) do
    scores = Enum.map(history, & &1.score)
    
    cond do
      improving_steadily?(scores) -> :improving
      plateaued?(scores) -> :stuck
      oscillating?(scores) -> :unstable
      true -> :unknown
    end
  end
end
```

### 4. LLM Refinement Interface

```elixir
defmodule Pipeline.Refinement.LLMRefiner do
  @moduledoc """
  Interface for LLM-based refinement with different strategies.
  """
  
  def refine_with_llm(pipeline, validation_report, strategy, context) do
    prompt = build_refinement_prompt(pipeline, validation_report, strategy)
    
    case strategy do
      :focused ->
        refine_focused_errors(prompt, pipeline, validation_report)
        
      :restructure ->
        restructure_pipeline(prompt, pipeline, context)
        
      :comprehensive ->
        comprehensive_refinement(prompt, pipeline, validation_report)
    end
  end
  
  defp refine_focused_errors(base_prompt, pipeline, report) do
    # Target specific errors with focused prompts
    critical_errors = report.critical_errors
    
    refinement_prompt = """
    #{base_prompt}
    
    CRITICAL ERRORS TO FIX:
    #{format_critical_errors(critical_errors)}
    
    CURRENT PIPELINE:
    #{Jason.encode!(pipeline, pretty: true)}
    
    Please fix ONLY the critical errors listed above. 
    Make minimal changes to preserve the pipeline's intent.
    Return the complete corrected pipeline in JSON format.
    """
    
    query_llm_with_schema(refinement_prompt, :refinement_schema)
  end
  
  defp restructure_pipeline(base_prompt, pipeline, context) do
    analysis = analyze_pipeline_intent(pipeline)
    
    restructure_prompt = """
    #{base_prompt}
    
    The current pipeline has fundamental structural issues.
    
    ORIGINAL INTENT:
    #{analysis.intent_description}
    
    DETECTED PATTERN:
    #{analysis.pattern}
    
    Please restructure this pipeline while preserving its intent.
    Use the #{analysis.pattern} pattern as a guide.
    
    Return a completely restructured pipeline in JSON format.
    """
    
    query_llm_with_schema(restructure_prompt, :full_pipeline_schema)
  end
end
```

### 5. Refinement Prompt Builder

```elixir
defmodule Pipeline.Refinement.PromptBuilder do
  @moduledoc """
  Builds effective refinement prompts based on error analysis.
  """
  
  def build_refinement_prompt(pipeline, validation_report, strategy) do
    base = build_base_prompt(strategy)
    errors = format_errors_for_llm(validation_report)
    suggestions = generate_fix_suggestions(validation_report)
    examples = select_relevant_examples(validation_report)
    
    """
    #{base}
    
    VALIDATION REPORT:
    #{errors}
    
    SUGGESTED FIXES:
    #{suggestions}
    
    #{if examples, do: format_examples(examples), else: ""}
    
    REFINEMENT CONSTRAINTS:
    1. Address all critical errors first
    2. Preserve the original pipeline intent
    3. Follow the provided JSON schema exactly
    4. Make minimal changes when possible
    """
  end
  
  defp generate_fix_suggestions(report) do
    report.errors
    |> Enum.map(&suggest_fix/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&format_suggestion/1)
    |> Enum.join("\n")
  end
  
  defp suggest_fix(error) do
    case error.type do
      :missing_field ->
        %{
          action: "Add field '#{error.field}' with value: #{suggest_value(error)}",
          location: error.path
        }
        
      :invalid_reference ->
        %{
          action: "Fix reference '#{error.reference}' - available: #{error.available}",
          location: error.path
        }
        
      :type_mismatch ->
        %{
          action: "Change type from #{error.actual_type} to #{error.expected_type}",
          location: error.path
        }
        
      _ -> nil
    end
  end
end
```

### 6. Auto-Repair Engine

```elixir
defmodule Pipeline.Refinement.AutoRepair do
  @moduledoc """
  Automatic repair for simple, deterministic errors.
  """
  
  def auto_repair(pipeline, validation_report) do
    repairs = plan_repairs(validation_report)
    
    if safe_to_auto_repair?(repairs) do
      apply_repairs(pipeline, repairs)
    else
      {:skip_auto_repair, repairs}
    end
  end
  
  defp plan_repairs(report) do
    report.errors
    |> Enum.filter(&can_auto_repair?/1)
    |> Enum.map(&create_repair_action/1)
    |> resolve_repair_conflicts()
  end
  
  defp can_auto_repair?(error) do
    error.type in [
      :missing_required_field,
      :invalid_enum_value,
      :simple_type_coercion,
      :trailing_comma,
      :missing_quote
    ] and error.confidence >= 0.9
  end
  
  defp apply_repairs(pipeline, repairs) do
    # Sort repairs by path depth (deepest first)
    sorted_repairs = Enum.sort_by(repairs, fn repair ->
      -length(repair.path)
    end)
    
    Enum.reduce(sorted_repairs, pipeline, fn repair, acc ->
      apply_single_repair(acc, repair)
    end)
  end
  
  defp apply_single_repair(pipeline, repair) do
    case repair.action do
      :add ->
        put_in(pipeline, repair.path, repair.value)
        
      :update ->
        update_in(pipeline, repair.path, fn _ -> repair.value end)
        
      :remove ->
        remove_in(pipeline, repair.path)
        
      :coerce ->
        update_in(pipeline, repair.path, repair.coerce_fn)
    end
  end
end
```

## Refinement Patterns

### 1. Progressive Enhancement

```elixir
defmodule Pipeline.Refinement.Patterns.Progressive do
  @moduledoc """
  Gradually improve pipeline from minimal to complete.
  """
  
  def progressive_refinement(initial, target_capabilities) do
    stages = [
      :ensure_basic_structure,
      :add_required_steps,
      :configure_steps,
      :add_error_handling,
      :optimize_performance
    ]
    
    Enum.reduce(stages, initial, fn stage, pipeline ->
      enhance_stage(pipeline, stage, target_capabilities)
    end)
  end
end
```

### 2. Pattern Matching Refinement

```elixir
defmodule Pipeline.Refinement.Patterns.Matching do
  @moduledoc """
  Refine by matching against known good patterns.
  """
  
  @patterns %{
    data_processing: %{
      required_steps: ["load", "transform", "validate", "save"],
      step_types: %{"load" => "file_ops", "transform" => "data_transform"},
      connections: :sequential
    },
    rag_pipeline: %{
      required_steps: ["query", "retrieve", "augment", "generate"],
      step_types: %{"retrieve" => "vector_search", "generate" => "claude"},
      connections: :sequential
    }
  }
  
  def refine_to_pattern(pipeline, detected_pattern) do
    pattern = @patterns[detected_pattern]
    
    pipeline
    |> ensure_required_steps(pattern.required_steps)
    |> set_step_types(pattern.step_types)
    |> configure_connections(pattern.connections)
  end
end
```

## Learning and Improvement

### 1. Refinement History Analysis

```elixir
defmodule Pipeline.Refinement.Learning do
  @moduledoc """
  Learn from refinement history to improve future iterations.
  """
  
  def analyze_refinement_patterns(history_collection) do
    %{
      common_errors: find_common_errors(history_collection),
      successful_fixes: extract_successful_patterns(history_collection),
      problem_indicators: identify_problem_indicators(history_collection),
      optimal_strategies: determine_optimal_strategies(history_collection)
    }
  end
  
  def update_refinement_knowledge(analysis) do
    # Update prompt templates
    update_prompt_templates(analysis.successful_fixes)
    
    # Update auto-repair rules
    extend_auto_repair_rules(analysis.common_errors)
    
    # Update strategy selection
    refine_strategy_selection(analysis.optimal_strategies)
  end
end
```

### 2. Feedback Loop Integration

```elixir
defmodule Pipeline.Refinement.Feedback do
  @moduledoc """
  Integrate user feedback into refinement process.
  """
  
  def collect_feedback(original, refined, user_satisfaction) do
    %{
      original_pipeline: original,
      refined_pipeline: refined,
      changes_made: diff_pipelines(original, refined),
      user_rating: user_satisfaction,
      timestamp: DateTime.utc_now()
    }
  end
  
  def improve_from_feedback(feedback_collection) do
    # Identify patterns in successful refinements
    successful = Enum.filter(feedback_collection, & &1.user_rating >= 4)
    
    patterns = extract_refinement_patterns(successful)
    update_refinement_strategies(patterns)
  end
end
```

## Configuration and Customization

```elixir
defmodule Pipeline.Refinement.Config do
  @moduledoc """
  Configure refinement behavior.
  """
  
  defstruct [
    max_iterations: 5,
    convergence_threshold: 0.95,
    auto_repair_threshold: 0.8,
    llm_refinement_threshold: 0.6,
    strategy: :adaptive,
    preserve_intent: true,
    allow_restructure: false,
    feedback_enabled: true
  ]
  
  def for_user_level(level) do
    case level do
      :beginner ->
        %__MODULE__{
          max_iterations: 7,
          auto_repair_threshold: 0.9,
          preserve_intent: true,
          allow_restructure: false
        }
        
      :intermediate ->
        %__MODULE__{
          max_iterations: 5,
          strategy: :adaptive,
          allow_restructure: true
        }
        
      :expert ->
        %__MODULE__{
          max_iterations: 3,
          strategy: :minimal,
          preserve_intent: false
        }
    end
  end
end
```

## Conclusion

The iterative refinement system provides a sophisticated approach to improving LLM-generated pipelines through multiple passes. By combining automatic repairs, intelligent LLM guidance, pattern matching, and continuous learning, the system can transform initially invalid configurations into high-quality, executable pipelines while preserving user intent and optimizing for specific use cases.