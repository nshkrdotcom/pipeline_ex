# Error Recovery and Repair Strategies for LLM-Generated Pipelines

## Overview

LLMs, despite structured output constraints, can still produce invalid configurations due to various factors like token limits, training data biases, or misunderstood requirements. This document outlines comprehensive strategies for detecting, diagnosing, and automatically repairing common errors in LLM-generated pipeline configurations.

## Error Taxonomy

### 1. Syntax Errors (Parse-Level)

**Common Issues:**
- Malformed JSON (missing quotes, commas, brackets)
- Escaped characters issues
- Truncated output due to token limits
- Markdown wrapping (```json blocks)

**Recovery Strategy:**
```elixir
defmodule Pipeline.Recovery.SyntaxRepair do
  @moduledoc """
  Automated syntax repair for common JSON errors.
  """
  
  def repair_syntax(raw_output) do
    repairs = [
      &fix_truncated_json/1,
      &unwrap_markdown_blocks/1,
      &fix_common_json_errors/1,
      &attempt_partial_recovery/1
    ]
    
    apply_repairs_sequentially(raw_output, repairs)
  end
  
  defp fix_truncated_json(input) do
    # Detect if JSON was cut off mid-stream
    if appears_truncated?(input) do
      attempt_completion(input)
    else
      {:unchanged, input}
    end
  end
  
  defp attempt_completion(truncated) do
    # Analyze structure and add missing closures
    open_brackets = count_open_brackets(truncated)
    
    completed = truncated <> generate_closures(open_brackets)
    
    case Jason.decode(completed) do
      {:ok, _} -> {:repaired, completed}
      {:error, _} -> {:failed, truncated}
    end
  end
  
  defp fix_common_json_errors(input) do
    input
    |> fix_trailing_commas()
    |> fix_missing_quotes()
    |> fix_single_quotes()
    |> fix_unescaped_characters()
  end
end
```

### 2. Schema Violations (Structure-Level)

**Common Issues:**
- Missing required fields
- Wrong field types
- Invalid enum values
- Incorrect nesting

**Recovery Strategy:**
```elixir
defmodule Pipeline.Recovery.SchemaRepair do
  @moduledoc """
  Schema-aware repair strategies.
  """
  
  def repair_schema_violations(data, schema, errors) do
    errors
    |> group_by_repair_strategy()
    |> apply_repairs(data, schema)
  end
  
  defp group_by_repair_strategy(errors) do
    Enum.group_by(errors, fn error ->
      case error do
        %{type: :missing_required} -> :add_defaults
        %{type: :invalid_type} -> :coerce_types
        %{type: :invalid_enum} -> :nearest_match
        %{type: :invalid_format} -> :reformat
        _ -> :complex
      end
    end)
  end
  
  defp apply_repairs(grouped_errors, data, schema) do
    grouped_errors
    |> Enum.reduce({:ok, data}, fn {strategy, errors}, {:ok, acc} ->
      apply_repair_strategy(strategy, errors, acc, schema)
    end)
  end
  
  defp apply_repair_strategy(:add_defaults, errors, data, schema) do
    Enum.reduce(errors, data, fn error, acc ->
      path = error.path
      field_schema = get_field_schema(schema, path)
      default = extract_default(field_schema) || generate_default(field_schema)
      
      put_in(acc, path, default)
    end)
  end
  
  defp apply_repair_strategy(:coerce_types, errors, data, _schema) do
    Enum.reduce(errors, data, fn error, acc ->
      path = error.path
      current_value = get_in(acc, path)
      target_type = error.expected_type
      
      case coerce_value(current_value, target_type) do
        {:ok, coerced} -> put_in(acc, path, coerced)
        {:error, _} -> acc  # Skip if coercion fails
      end
    end)
  end
end
```

### 3. Semantic Errors (Logic-Level)

**Common Issues:**
- Invalid step references
- Circular dependencies
- Unreachable steps
- Conflicting configurations

**Recovery Strategy:**
```elixir
defmodule Pipeline.Recovery.SemanticRepair do
  @moduledoc """
  Repair logical inconsistencies in pipeline structure.
  """
  
  def repair_semantic_errors(pipeline, errors) do
    repairs = %{
      invalid_references: &fix_references/2,
      circular_dependencies: &break_cycles/2,
      unreachable_steps: &connect_orphans/2,
      conflicting_configs: &resolve_conflicts/2
    }
    
    Enum.reduce(errors, {:ok, pipeline}, fn error, {:ok, acc} ->
      repair_fn = repairs[error.type]
      repair_fn.(acc, error)
    end)
  end
  
  defp fix_references(pipeline, error) do
    # Fix invalid step references
    steps = get_in(pipeline, ["workflow", "steps"])
    valid_names = MapSet.new(steps, & &1["name"])
    
    fixed_steps = Enum.map(steps, fn step ->
      fix_step_references(step, valid_names, error.invalid_refs)
    end)
    
    {:ok, put_in(pipeline, ["workflow", "steps"], fixed_steps)}
  end
  
  defp fix_step_references(step, valid_names, invalid_refs) do
    case step["prompt"] do
      prompts when is_list(prompts) ->
        fixed_prompts = Enum.map(prompts, fn prompt ->
          fix_prompt_reference(prompt, valid_names, invalid_refs)
        end)
        %{step | "prompt" => fixed_prompts}
        
      _ -> step
    end
  end
  
  defp break_cycles(pipeline, error) do
    # Detect and break circular dependencies
    graph = build_dependency_graph(pipeline)
    cycles = detect_cycles(graph)
    
    if Enum.empty?(cycles) do
      {:ok, pipeline}
    else
      broken_graph = break_minimal_edges(graph, cycles)
      {:ok, rebuild_pipeline_from_graph(pipeline, broken_graph)}
    end
  end
end
```

### 4. Execution Errors (Runtime-Level)

**Common Issues:**
- Missing provider configuration
- Unavailable tools
- Resource limit violations
- Permission errors

**Recovery Strategy:**
```elixir
defmodule Pipeline.Recovery.ExecutionRepair do
  @moduledoc """
  Repair execution-level issues.
  """
  
  def repair_execution_errors(pipeline, errors, context) do
    repairs = %{
      missing_provider: &substitute_provider/3,
      unavailable_tool: &remove_or_substitute_tool/3,
      resource_limit: &optimize_resource_usage/3,
      permission_error: &adjust_permissions/3
    }
    
    Enum.reduce(errors, {:ok, pipeline}, fn error, {:ok, acc} ->
      repair_fn = repairs[error.type]
      repair_fn.(acc, error, context)
    end)
  end
  
  defp substitute_provider(pipeline, error, context) do
    unavailable = error.provider
    available = context.available_providers
    
    substitute = find_best_substitute(unavailable, available)
    
    steps = get_in(pipeline, ["workflow", "steps"])
    updated_steps = Enum.map(steps, fn step ->
      if step["type"] == unavailable do
        %{step | "type" => substitute}
        |> adjust_provider_options(unavailable, substitute)
      else
        step
      end
    end)
    
    {:ok, put_in(pipeline, ["workflow", "steps"], updated_steps)}
  end
  
  defp find_best_substitute(target, available) do
    # Smart substitution based on capabilities
    substitution_matrix = %{
      "claude" => ["gemini", "openai"],
      "gemini" => ["claude", "openai"],
      "openai" => ["claude", "gemini"]
    }
    
    candidates = substitution_matrix[target] || []
    Enum.find(candidates, fn c -> c in available end) || List.first(available)
  end
end
```

## Intelligent Repair Strategies

### 1. Context-Aware Repair

```elixir
defmodule Pipeline.Recovery.IntelligentRepair do
  @moduledoc """
  Context-aware repair using domain knowledge.
  """
  
  def smart_repair(pipeline, errors, context) do
    pipeline_intent = analyze_intent(pipeline)
    user_expertise = context[:user_expertise] || :intermediate
    
    repair_strategy = select_strategy(pipeline_intent, user_expertise, errors)
    
    apply_intelligent_repairs(pipeline, errors, repair_strategy)
  end
  
  defp analyze_intent(pipeline) do
    # Analyze pipeline structure to understand intent
    cond do
      has_data_processing_pattern?(pipeline) -> :data_pipeline
      has_multi_agent_pattern?(pipeline) -> :multi_agent
      has_content_generation_pattern?(pipeline) -> :content_generation
      true -> :general
    end
  end
  
  defp select_strategy(intent, expertise, errors) do
    case {intent, expertise} do
      {:data_pipeline, :beginner} ->
        DataPipelineRepair.beginner_strategy()
        
      {:multi_agent, _} ->
        MultiAgentRepair.standard_strategy()
        
      {_, :expert} ->
        MinimalRepair.expert_strategy()
        
      _ ->
        DefaultRepair.safe_strategy()
    end
  end
end
```

### 2. Pattern-Based Repair

```elixir
defmodule Pipeline.Recovery.PatternRepair do
  @moduledoc """
  Repair using common pipeline patterns.
  """
  
  @patterns %{
    rag_pipeline: %{
      required_steps: ["retrieve", "augment", "generate"],
      step_order: :strict,
      connections: :sequential
    },
    multi_agent: %{
      required_steps: ["router", "agent_*", "aggregator"],
      step_order: :flexible,
      connections: :conditional
    }
  }
  
  def repair_with_patterns(pipeline, detected_pattern) do
    pattern = @patterns[detected_pattern]
    
    pipeline
    |> ensure_required_steps(pattern.required_steps)
    |> fix_step_ordering(pattern.step_order)
    |> repair_connections(pattern.connections)
  end
end
```

### 3. LLM-Assisted Repair

```elixir
defmodule Pipeline.Recovery.LLMRepair do
  @moduledoc """
  Use LLMs to assist in complex repairs.
  """
  
  def repair_with_llm(pipeline, errors, context) do
    if should_use_llm_repair?(errors) do
      request_llm_repair(pipeline, errors, context)
    else
      {:skip_llm, "Errors can be fixed automatically"}
    end
  end
  
  defp should_use_llm_repair?(errors) do
    # Use LLM for complex semantic errors
    Enum.any?(errors, fn error ->
      error.complexity == :high || error.requires_domain_knowledge
    end)
  end
  
  defp request_llm_repair(pipeline, errors, context) do
    repair_prompt = build_repair_prompt(pipeline, errors)
    
    # Use structured output for repair suggestions
    repair_schema = %{
      type: "object",
      properties: %{
        repairs: %{
          type: "array",
          items: %{
            type: "object",
            properties: %{
              error_id: %{type: "string"},
              repair_type: %{type: "string"},
              changes: %{type: "array"}
            }
          }
        },
        explanation: %{type: "string"}
      }
    }
    
    case LLM.query_structured(repair_prompt, repair_schema) do
      {:ok, repair_plan} -> apply_repair_plan(pipeline, repair_plan)
      {:error, _} -> {:error, "LLM repair failed"}
    end
  end
end
```

## Recovery Orchestration

### Main Recovery Pipeline

```elixir
defmodule Pipeline.Recovery.Orchestrator do
  @moduledoc """
  Orchestrate the complete recovery process.
  """
  
  def recover(raw_output, context \\ %{}) do
    with {:ok, parsed} <- recover_syntax(raw_output),
         {:ok, schema_valid} <- recover_schema(parsed, context),
         {:ok, semantic_valid} <- recover_semantics(schema_valid, context),
         {:ok, executable} <- recover_execution(semantic_valid, context) do
      {:ok, executable}
    else
      {:error, stage, reason} ->
        handle_unrecoverable_error(stage, reason, context)
    end
  end
  
  defp recover_syntax(raw) do
    case Pipeline.Recovery.SyntaxRepair.repair_syntax(raw) do
      {:repaired, json} -> {:ok, Jason.decode!(json)}
      {:unchanged, json} -> {:ok, Jason.decode!(json)}
      {:failed, _} -> {:error, :syntax, "Unrecoverable JSON syntax errors"}
    end
  end
  
  defp recover_schema(data, context) do
    case validate_schema(data) do
      {:ok, _} -> {:ok, data}
      {:error, errors} ->
        Pipeline.Recovery.SchemaRepair.repair_schema_violations(data, schema(), errors)
    end
  end
  
  defp handle_unrecoverable_error(stage, reason, context) do
    if context[:fallback_enabled] do
      use_fallback_pipeline(stage, reason, context)
    else
      format_error_for_user(stage, reason)
    end
  end
end
```

### Recovery Configuration

```elixir
defmodule Pipeline.Recovery.Config do
  @moduledoc """
  Configure recovery behavior.
  """
  
  defstruct [
    auto_repair: true,
    max_repair_attempts: 3,
    use_llm_repair: true,
    fallback_strategy: :minimal,
    preserve_intent: true,
    log_repairs: true
  ]
  
  def aggressive do
    %__MODULE__{
      auto_repair: true,
      max_repair_attempts: 5,
      use_llm_repair: true,
      preserve_intent: false  # Prioritize validity over intent
    }
  end
  
  def conservative do
    %__MODULE__{
      auto_repair: true,
      max_repair_attempts: 2,
      use_llm_repair: false,
      preserve_intent: true  # Maintain original intent
    }
  end
end
```

## Recovery Metrics and Monitoring

```elixir
defmodule Pipeline.Recovery.Metrics do
  @moduledoc """
  Track recovery success rates and patterns.
  """
  
  def track_recovery(original, repaired, errors_fixed) do
    %{
      timestamp: DateTime.utc_now(),
      error_types: categorize_errors(errors_fixed),
      repair_strategies: strategies_used(original, repaired),
      success: validate_repaired(repaired),
      complexity_score: calculate_complexity(errors_fixed),
      time_taken: measure_repair_time()
    }
  end
  
  def analyze_patterns(recovery_history) do
    # Identify common error patterns
    # Optimize repair strategies
    # Improve LLM prompts based on failures
  end
end
```

## Best Practices

### 1. Graceful Degradation
- Always attempt the minimal viable fix first
- Preserve as much of the original intent as possible
- Provide clear feedback about what was changed

### 2. Transparency
- Log all repairs made
- Provide before/after comparisons
- Explain why repairs were necessary

### 3. Learning from Failures
- Track common error patterns
- Update LLM prompts to prevent repeated errors
- Build a library of repair patterns

### 4. User Control
- Allow users to review and approve repairs
- Provide options for repair aggressiveness
- Support manual override of automatic repairs

## Conclusion

A robust error recovery system is essential for reliable LLM-generated pipelines. By combining automated syntax repair, schema-aware fixes, semantic analysis, and intelligent recovery strategies, we can transform potentially invalid LLM outputs into valid, executable pipeline configurations while maintaining the original intent as much as possible.