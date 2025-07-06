# Validation Pipeline for LLM-Generated Configurations

## Overview

This document describes a comprehensive, multi-stage validation pipeline specifically designed for LLM-generated pipeline configurations. The pipeline ensures that LLM outputs are not only syntactically valid but also semantically correct, executable, and optimized for their intended purpose.

## Validation Pipeline Architecture

```
┌─────────────────┐
│  LLM Output     │
│    (JSON)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Stage 1: Parse  │───▶ Syntax Errors ───▶ Quick Fix
│   Validation    │                          │
└────────┬────────┘                          │
         │ Valid JSON                        │
         ▼                                   │
┌─────────────────┐                          │
│ Stage 2: Schema │───▶ Schema Errors ───▶ Repair
│   Validation    │                          │
└────────┬────────┘                          │
         │ Schema Valid                      │
         ▼                                   │
┌─────────────────┐                          │
│Stage 3: Semantic│───▶ Logic Errors ────▶ Refine
│   Validation    │                          │
└────────┬────────┘                          │
         │ Semantically Valid                │
         ▼                                   │
┌─────────────────┐                          │
│ Stage 4: Exec.  │───▶ Runtime Errors ──▶ Adjust
│   Validation    │                          │
└────────┬────────┘                          │
         │ Executable                        │
         ▼                                   ▼
┌─────────────────┐                 ┌──────────────┐
│ Valid Pipeline  │                 │ Refinement   │
│  Configuration  │◀────────────────│   Engine     │
└─────────────────┘                 └──────────────┘
```

## Validation Stages

### Stage 1: Parse Validation

**Purpose**: Ensure the LLM output is valid JSON that can be parsed.

```elixir
defmodule Pipeline.Validation.ParseValidator do
  @moduledoc """
  First-stage validation for raw LLM output.
  """
  
  def validate_parse(raw_output) do
    case Jason.decode(raw_output) do
      {:ok, parsed} ->
        {:ok, parsed}
        
      {:error, %Jason.DecodeError{} = error} ->
        case attempt_repair(raw_output, error) do
          {:ok, repaired} -> validate_parse(repaired)
          {:error, _} -> {:error, :stage_1, format_parse_error(error)}
        end
    end
  end
  
  defp attempt_repair(raw_output, error) do
    repairs = [
      &fix_trailing_commas/1,
      &fix_unescaped_quotes/1,
      &fix_incomplete_objects/1,
      &extract_json_from_markdown/1
    ]
    
    Enum.find_value(repairs, {:error, :unrepairable}, fn repair_fn ->
      case repair_fn.(raw_output) do
        {:ok, _} = success -> success
        _ -> nil
      end
    end)
  end
  
  defp extract_json_from_markdown(output) do
    # LLMs sometimes wrap JSON in markdown code blocks
    case Regex.run(~r/```(?:json)?\n(.*)\n```/s, output) do
      [_, json_content] -> {:ok, json_content}
      _ -> {:error, :no_json_block}
    end
  end
end
```

### Stage 2: Schema Validation

**Purpose**: Validate against the pipeline JSON Schema with detailed error reporting.

```elixir
defmodule Pipeline.Validation.SchemaValidator do
  @moduledoc """
  JSON Schema validation with detailed error analysis.
  """
  
  alias Pipeline.Format.Schema
  
  def validate_schema(parsed_json, options \\ []) do
    schema = select_schema(options)
    
    case ExJsonSchema.validate(schema, parsed_json) do
      :ok ->
        {:ok, parsed_json}
        
      {:error, errors} ->
        analyzed_errors = analyze_schema_errors(errors, parsed_json)
        {:error, :stage_2, analyzed_errors}
    end
  end
  
  defp analyze_schema_errors(errors, data) do
    errors
    |> Enum.map(&enrich_error(&1, data))
    |> group_by_severity()
    |> prioritize_fixes()
  end
  
  defp enrich_error(error, data) do
    %{
      path: error.path,
      message: error.message,
      actual_value: get_in(data, parse_path(error.path)),
      expected: extract_expectation(error),
      severity: determine_severity(error),
      suggested_fix: suggest_fix(error, data)
    }
  end
  
  defp suggest_fix(%{error: :missing_required_field} = error, _data) do
    %{
      action: :add_field,
      field: error.field,
      default_value: get_field_default(error.field)
    }
  end
  
  defp suggest_fix(%{error: :invalid_type} = error, data) do
    %{
      action: :change_type,
      path: error.path,
      from: type_of(get_in(data, error.path)),
      to: error.expected_type
    }
  end
end
```

### Stage 3: Semantic Validation

**Purpose**: Ensure logical consistency and semantic correctness beyond schema compliance.

```elixir
defmodule Pipeline.Validation.SemanticValidator do
  @moduledoc """
  Semantic validation for pipeline logic and consistency.
  """
  
  def validate_semantics(pipeline_data, context \\ %{}) do
    validators = [
      &validate_step_references/2,
      &validate_variable_consistency/2,
      &validate_prompt_templates/2,
      &validate_conditional_logic/2,
      &validate_resource_usage/2,
      &validate_step_ordering/2
    ]
    
    errors = Enum.flat_map(validators, fn validator ->
      case validator.(pipeline_data, context) do
        {:ok, _} -> []
        {:error, errors} -> errors
      end
    end)
    
    if Enum.empty?(errors) do
      {:ok, pipeline_data}
    else
      {:error, :stage_3, analyze_semantic_errors(errors)}
    end
  end
  
  defp validate_step_references(data, _context) do
    steps = get_in(data, ["workflow", "steps"]) || []
    step_names = MapSet.new(steps, & &1["name"])
    
    errors = Enum.flat_map(steps, fn step ->
      find_invalid_references(step, step_names)
    end)
    
    if Enum.empty?(errors), do: {:ok, data}, else: {:error, errors}
  end
  
  defp validate_variable_consistency(data, _context) do
    # Track variable definitions and usage
    var_tracker = VariableTracker.new()
    
    data
    |> get_in(["workflow", "steps"])
    |> Enum.reduce({:ok, var_tracker}, fn step, {:ok, tracker} ->
      VariableTracker.analyze_step(tracker, step)
    end)
    |> case do
      {:ok, tracker} -> VariableTracker.get_errors(tracker)
      errors -> errors
    end
  end
  
  defp validate_prompt_templates(data, _context) do
    # Validate template syntax and variable references
    steps = get_in(data, ["workflow", "steps"]) || []
    
    Enum.flat_map(steps, fn step ->
      case step["prompt"] do
        nil -> []
        prompt -> validate_prompt_structure(prompt, step["name"])
      end
    end)
  end
end
```

### Stage 4: Execution Validation

**Purpose**: Validate that the pipeline can actually execute in the target environment.

```elixir
defmodule Pipeline.Validation.ExecutionValidator do
  @moduledoc """
  Dry-run validation to ensure pipeline executability.
  """
  
  def validate_execution(pipeline_data, context) do
    with {:ok, compiled} <- compile_pipeline(pipeline_data),
         {:ok, _} <- check_provider_availability(compiled, context),
         {:ok, _} <- check_tool_availability(compiled, context),
         {:ok, _} <- simulate_execution(compiled, context) do
      {:ok, pipeline_data}
    else
      {:error, reason} ->
        {:error, :stage_4, analyze_execution_error(reason, pipeline_data)}
    end
  end
  
  defp compile_pipeline(data) do
    # Attempt to compile to internal representation
    case Pipeline.Config.load_from_map(data) do
      {:ok, config} -> {:ok, config}
      {:error, reason} -> {:error, {:compilation, reason}}
    end
  end
  
  defp check_provider_availability(pipeline, context) do
    required_providers = extract_required_providers(pipeline)
    available_providers = context[:available_providers] || default_providers()
    
    missing = MapSet.difference(
      MapSet.new(required_providers),
      MapSet.new(available_providers)
    )
    
    if MapSet.size(missing) == 0 do
      {:ok, :all_available}
    else
      {:error, {:missing_providers, MapSet.to_list(missing)}}
    end
  end
  
  defp simulate_execution(pipeline, context) do
    # Lightweight simulation of pipeline execution
    simulator = ExecutionSimulator.new(context)
    
    pipeline
    |> get_in(["workflow", "steps"])
    |> Enum.reduce_while({:ok, simulator}, fn step, {:ok, sim} ->
      case ExecutionSimulator.simulate_step(sim, step) do
        {:ok, new_sim} -> {:cont, {:ok, new_sim}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
end
```

## Validation Context and Configuration

### Context Builder

```elixir
defmodule Pipeline.Validation.Context do
  @moduledoc """
  Build validation context based on environment and requirements.
  """
  
  defstruct [
    :available_providers,
    :available_tools,
    :resource_limits,
    :validation_mode,
    :fix_strategy,
    :user_expertise
  ]
  
  def build(options \\ []) do
    %__MODULE__{
      available_providers: detect_providers(),
      available_tools: load_tool_registry(),
      resource_limits: get_resource_limits(),
      validation_mode: options[:mode] || :strict,
      fix_strategy: options[:fix_strategy] || :interactive,
      user_expertise: options[:user_expertise] || :intermediate
    }
  end
  
  defp detect_providers do
    # Detect which AI providers are configured
    [:claude, :gemini, :openai]
    |> Enum.filter(&provider_available?/1)
  end
end
```

### Validation Configuration

```elixir
defmodule Pipeline.Validation.Config do
  @moduledoc """
  Configure validation behavior and strategies.
  """
  
  defstruct [
    stages: [:parse, :schema, :semantic, :execution],
    stop_on_error: false,
    auto_fix: true,
    max_fix_attempts: 3,
    validation_timeout: 30_000,
    parallel_validation: true
  ]
  
  def strict_mode do
    %__MODULE__{
      stop_on_error: true,
      auto_fix: false,
      stages: [:parse, :schema, :semantic, :execution]
    }
  end
  
  def lenient_mode do
    %__MODULE__{
      stop_on_error: false,
      auto_fix: true,
      stages: [:parse, :schema]  # Skip semantic and execution
    }
  end
  
  def development_mode do
    %__MODULE__{
      stop_on_error: false,
      auto_fix: true,
      max_fix_attempts: 5,
      stages: [:parse, :schema, :semantic]  # Skip execution
    }
  end
end
```

## Error Analysis and Reporting

### Unified Error Report

```elixir
defmodule Pipeline.Validation.Report do
  @moduledoc """
  Comprehensive validation reporting with actionable insights.
  """
  
  defstruct [
    :status,
    :stages_completed,
    :errors,
    :warnings,
    :suggestions,
    :fixed_issues,
    :validation_time
  ]
  
  def generate(validation_results) do
    %__MODULE__{
      status: determine_status(validation_results),
      stages_completed: count_completed_stages(validation_results),
      errors: collect_errors(validation_results),
      warnings: collect_warnings(validation_results),
      suggestions: generate_suggestions(validation_results),
      fixed_issues: collect_fixed_issues(validation_results),
      validation_time: calculate_total_time(validation_results)
    }
  end
  
  def format_for_llm(report) do
    """
    VALIDATION REPORT
    Status: #{report.status}
    Stages: #{report.stages_completed}/4 completed
    
    ERRORS (#{length(report.errors)}):
    #{format_errors_for_llm(report.errors)}
    
    SUGGESTED FIXES:
    #{format_suggestions_for_llm(report.suggestions)}
    
    Please revise the pipeline configuration addressing these issues.
    """
  end
  
  def format_for_human(report) do
    # Rich formatting with colors, examples, and detailed explanations
  end
end
```

## Integration with LLM Refinement

### Validation Loop

```elixir
defmodule Pipeline.Validation.Loop do
  @moduledoc """
  Orchestrate validation and refinement loop with LLMs.
  """
  
  def validate_with_refinement(llm_output, context, opts \\ []) do
    max_attempts = opts[:max_attempts] || 3
    
    Stream.iterate({llm_output, 0}, fn {output, attempt} ->
      case run_validation_pipeline(output, context) do
        {:ok, valid_config} ->
          {:halt, {:ok, valid_config}}
          
        {:error, report} when attempt < max_attempts ->
          refined = request_refinement(output, report, context)
          {refined, attempt + 1}
          
        {:error, report} ->
          {:halt, {:error, :max_attempts_exceeded, report}}
      end
    end)
    |> Enum.find(fn
      {:halt, _} -> true
      _ -> false
    end)
    |> elem(1)
  end
  
  defp request_refinement(original, error_report, context) do
    prompt = build_refinement_prompt(original, error_report)
    provider = context[:llm_provider] || :claude
    
    Pipeline.LLM.Generator.refine_with_errors(
      provider,
      prompt,
      original,
      error_report
    )
  end
end
```

## Performance Optimization

### Caching and Memoization

```elixir
defmodule Pipeline.Validation.Cache do
  @moduledoc """
  Cache validation results for common patterns.
  """
  
  use GenServer
  
  def validate_with_cache(pipeline_data, validators) do
    cache_key = generate_cache_key(pipeline_data)
    
    case get_cached_result(cache_key) do
      {:ok, result} -> 
        {:cache_hit, result}
        
      :miss ->
        result = run_validators(pipeline_data, validators)
        cache_result(cache_key, result)
        {:validated, result}
    end
  end
end
```

### Parallel Validation

```elixir
defmodule Pipeline.Validation.Parallel do
  @moduledoc """
  Run independent validations in parallel.
  """
  
  def validate_parallel(pipeline_data, validators) do
    validators
    |> Task.async_stream(fn validator ->
      {validator.name, validator.validate(pipeline_data)}
    end, max_concurrency: System.schedulers_online())
    |> Enum.reduce({:ok, []}, &combine_results/2)
  end
end
```

## Conclusion

This comprehensive validation pipeline ensures that LLM-generated configurations are not only syntactically correct but also semantically valid and executable. The multi-stage approach with integrated refinement capabilities creates a robust system that can handle the imperfections inherent in LLM outputs while maintaining high standards for pipeline quality.