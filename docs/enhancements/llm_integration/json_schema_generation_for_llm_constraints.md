# JSON Schema Generation for LLM Constraints

## Overview

This document details how to generate optimized JSON Schemas specifically for constraining LLM outputs when generating pipeline configurations. Different LLM providers have varying levels of support for structured outputs, and schemas must be tailored to maximize success rates while maintaining expressiveness.

## Provider-Specific Schema Support

### 1. Claude (Anthropic)

**Supported Methods:**
- Tool Use (Function Calling) with JSON Schema
- Direct JSON mode with schema hints
- System prompts with schema examples

```elixir
defmodule Pipeline.Schema.Claude do
  @moduledoc """
  Generate Claude-optimized schemas for pipeline generation.
  """
  
  def generate_tool_schema(requirements) do
    %{
      name: "create_pipeline",
      description: "Create a complete pipeline configuration",
      input_schema: build_claude_schema(requirements)
    }
  end
  
  defp build_claude_schema(requirements) do
    base_schema()
    |> apply_claude_optimizations()
    |> add_claude_constraints(requirements)
  end
  
  defp apply_claude_optimizations(schema) do
    schema
    |> use_descriptive_field_names()  # Claude responds well to clear naming
    |> add_detailed_descriptions()     # More context improves accuracy
    |> simplify_nested_structures()    # Flatten where possible
    |> add_examples_to_fields()        # Claude uses examples effectively
  end
  
  def generate_system_prompt_with_schema(schema) do
    """
    You must generate a pipeline configuration that EXACTLY matches this JSON schema:
    
    ```json
    #{Jason.encode!(schema, pretty: true)}
    ```
    
    Important constraints:
    - All required fields must be present
    - Field types must match exactly
    - Enum values must be from the provided list
    - Arrays must contain items matching the item schema
    """
  end
end
```

### 2. Gemini (Google)

**Supported Methods:**
- Response Schema with `response_mime_type: "application/json"`
- Function declarations with structured outputs
- Strongly typed generation config

```elixir
defmodule Pipeline.Schema.Gemini do
  @moduledoc """
  Generate Gemini-optimized schemas for pipeline generation.
  """
  
  def generate_response_schema(requirements) do
    %{
      type: "object",
      properties: build_gemini_properties(requirements),
      required: determine_required_fields(requirements)
    }
  end
  
  defp build_gemini_properties(requirements) do
    # Gemini prefers explicit type definitions
    %{
      "workflow" => %{
        type: "object",
        properties: %{
          "name" => %{type: "string"},
          "steps" => %{
            type: "array",
            items: gemini_step_schema(requirements)
          }
        }
      }
    }
  end
  
  def configure_generation(schema) do
    %{
      generation_config: %{
        response_mime_type: "application/json",
        response_schema: schema,
        temperature: 0.1,  # Lower for structured output
        candidate_count: 1
      }
    }
  end
end
```

### 3. OpenAI

**Supported Methods:**
- Function calling with JSON Schema
- Response format with JSON mode
- Structured outputs (beta)

```elixir
defmodule Pipeline.Schema.OpenAI do
  @moduledoc """
  Generate OpenAI-optimized schemas for pipeline generation.
  """
  
  def generate_function_schema(requirements) do
    %{
      name: "create_pipeline",
      description: "Generate a pipeline configuration",
      parameters: build_openai_schema(requirements),
      required: ["workflow"]
    }
  end
  
  def generate_response_format(requirements) do
    %{
      type: "json_schema",
      json_schema: %{
        name: "pipeline_config",
        schema: build_openai_schema(requirements),
        strict: true  # Enforce strict mode
      }
    }
  end
end
```

## Schema Generation Strategies

### 1. Progressive Complexity

```elixir
defmodule Pipeline.Schema.Progressive do
  @moduledoc """
  Generate schemas with progressive complexity based on context.
  """
  
  def generate_schema(complexity_level, base_requirements) do
    case complexity_level do
      :minimal ->
        minimal_schema(base_requirements)
      :standard ->
        standard_schema(base_requirements)
      :advanced ->
        advanced_schema(base_requirements)
      :expert ->
        full_schema(base_requirements)
    end
  end
  
  defp minimal_schema(reqs) do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "type" => "object",
      "properties" => %{
        "workflow" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "steps" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "type" => %{"type" => "string", "enum" => reqs.allowed_step_types},
                  "prompt" => %{"type" => "string"}
                },
                "required" => ["name", "type", "prompt"]
              }
            }
          },
          "required" => ["name", "steps"]
        }
      },
      "required" => ["workflow"]
    }
  end
  
  defp standard_schema(reqs) do
    minimal_schema(reqs)
    |> add_prompt_structure()
    |> add_step_options()
    |> add_validation_rules()
  end
  
  defp add_prompt_structure(schema) do
    put_in(
      schema,
      ["properties", "workflow", "properties", "steps", "items", "properties", "prompt"],
      %{
        "oneOf" => [
          %{"type" => "string"},
          %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "type" => %{"type" => "string", "enum" => ["static", "file", "previous_response"]},
                "content" => %{"type" => "string"}
              }
            }
          }
        ]
      }
    )
  end
end
```

### 2. Context-Aware Schema Generation

```elixir
defmodule Pipeline.Schema.ContextAware do
  @moduledoc """
  Generate schemas based on user context and requirements.
  """
  
  def generate_from_context(context) do
    base = base_schema_for_domain(context.domain)
    
    base
    |> adjust_for_user_level(context.user_level)
    |> add_domain_constraints(context.domain)
    |> optimize_for_provider(context.llm_provider)
    |> add_security_constraints(context.security_level)
  end
  
  defp base_schema_for_domain(domain) do
    case domain do
      :data_processing ->
        Schemas.DataProcessing.base_schema()
      :content_generation ->
        Schemas.ContentGeneration.base_schema()
      :multi_agent ->
        Schemas.MultiAgent.base_schema()
      _ ->
        Schemas.Generic.base_schema()
    end
  end
  
  defp adjust_for_user_level(schema, level) do
    case level do
      :beginner ->
        schema
        |> hide_advanced_fields()
        |> add_more_examples()
        |> strengthen_validation()
        
      :expert ->
        schema
        |> expose_all_fields()
        |> relax_constraints()
        |> add_experimental_features()
        
      _ ->
        schema
    end
  end
end
```

### 3. Dynamic Schema Builder

```elixir
defmodule Pipeline.Schema.DynamicBuilder do
  @moduledoc """
  Build schemas dynamically based on requirements.
  """
  
  def build(requirements) do
    SchemaBuilder.new()
    |> add_workflow_structure()
    |> add_step_types(requirements.allowed_steps)
    |> add_constraints(requirements.constraints)
    |> add_conditional_fields(requirements.conditionals)
    |> optimize_for_llm(requirements.llm_provider)
    |> finalize()
  end
  
  defmodule SchemaBuilder do
    defstruct schema: %{}, 
              definitions: %{}, 
              constraints: [],
              metadata: %{}
    
    def new do
      %__MODULE__{
        schema: %{
          "$schema" => "http://json-schema.org/draft-07/schema#",
          "type" => "object"
        }
      }
    end
    
    def add_workflow_structure(builder) do
      update_in(builder.schema["properties"], fn _ ->
        %{
          "workflow" => %{
            "type" => "object",
            "properties" => %{},
            "required" => []
          }
        }
      end)
    end
    
    def add_step_types(builder, allowed_types) do
      # Dynamically build step schemas based on allowed types
      step_schemas = Enum.map(allowed_types, fn type ->
        {type, generate_step_schema_for_type(type)}
      end)
      
      # Add to definitions
      update_in(builder.definitions, fn defs ->
        Map.merge(defs, Map.new(step_schemas))
      end)
    end
    
    def finalize(builder) do
      builder.schema
      |> Map.put("definitions", builder.definitions)
      |> apply_global_constraints(builder.constraints)
    end
  end
end
```

## Schema Optimization Techniques

### 1. Token Optimization

```elixir
defmodule Pipeline.Schema.TokenOptimizer do
  @moduledoc """
  Optimize schemas to reduce token usage in LLM interactions.
  """
  
  def optimize_for_tokens(schema, target_reduction \\ 0.3) do
    schema
    |> shorten_field_names()
    |> remove_redundant_descriptions()
    |> use_references_for_repetition()
    |> compress_enums()
    |> measure_reduction(schema, target_reduction)
  end
  
  defp shorten_field_names(schema) do
    # Map verbose names to concise ones
    name_map = %{
      "workflow" => "wf",
      "steps" => "s",
      "properties" => "props",
      "required" => "req"
    }
    
    transform_keys(schema, name_map)
  end
  
  defp use_references_for_repetition(schema) do
    # Find repeated structures and use $ref
    repeated = find_repeated_structures(schema)
    
    Enum.reduce(repeated, schema, fn {structure, locations}, acc ->
      ref_name = generate_ref_name(structure)
      acc
      |> add_to_definitions(ref_name, structure)
      |> replace_with_refs(locations, ref_name)
    end)
  end
end
```

### 2. Constraint Optimization

```elixir
defmodule Pipeline.Schema.ConstraintOptimizer do
  @moduledoc """
  Optimize constraints for better LLM compliance.
  """
  
  def optimize_constraints(schema, llm_provider) do
    schema
    |> adjust_constraint_strictness(llm_provider)
    |> add_provider_hints(llm_provider)
    |> reorder_for_importance()
  end
  
  defp adjust_constraint_strictness(:claude, schema) do
    # Claude handles complex constraints well
    schema
  end
  
  defp adjust_constraint_strictness(:gemini, schema) do
    # Gemini prefers simpler constraints
    schema
    |> simplify_complex_patterns()
    |> flatten_deep_nesting()
  end
  
  defp add_provider_hints(:claude, schema) do
    # Add Claude-specific hints
    schema
    |> add_to_descriptions("Use exactly this format: ")
    |> add_inline_examples()
  end
end
```

### 3. Validation Feedback Integration

```elixir
defmodule Pipeline.Schema.FeedbackIntegration do
  @moduledoc """
  Integrate validation feedback to improve schemas.
  """
  
  def improve_schema_from_feedback(schema, validation_history) do
    common_errors = analyze_common_errors(validation_history)
    
    schema
    |> strengthen_weak_points(common_errors)
    |> add_clarifications(common_errors)
    |> adjust_constraints(common_errors)
  end
  
  defp strengthen_weak_points(schema, errors) do
    # Identify fields that frequently have errors
    problem_fields = identify_problem_fields(errors)
    
    Enum.reduce(problem_fields, schema, fn {field_path, error_rate}, acc ->
      if error_rate > 0.3 do
        strengthen_field_validation(acc, field_path)
      else
        acc
      end
    end)
  end
  
  defp add_clarifications(schema, errors) do
    # Add better descriptions where confusion occurs
    confusion_points = find_confusion_patterns(errors)
    
    Enum.reduce(confusion_points, schema, fn {field, clarification}, acc ->
      update_field_description(acc, field, clarification)
    end)
  end
end
```

## Schema Testing and Validation

### 1. Schema Test Suite

```elixir
defmodule Pipeline.Schema.Testing do
  @moduledoc """
  Test generated schemas for effectiveness.
  """
  
  def test_schema_with_llm(schema, test_cases, llm_provider) do
    results = Enum.map(test_cases, fn test_case ->
      result = generate_with_schema(llm_provider, schema, test_case.prompt)
      
      %{
        test_case: test_case,
        generated: result,
        valid: validate_against_schema(result, schema),
        matches_intent: matches_test_intent?(result, test_case)
      }
    end)
    
    %{
      success_rate: calculate_success_rate(results),
      common_failures: analyze_failures(results),
      recommendations: generate_recommendations(results)
    }
  end
  
  def generate_test_cases(domain) do
    [
      %{
        name: "minimal_pipeline",
        prompt: "Create a simple pipeline that processes data",
        expected_steps: ["load", "process", "save"]
      },
      %{
        name: "complex_pipeline",
        prompt: "Create a pipeline with conditional logic and error handling",
        expected_features: [:conditionals, :error_handling]
      }
    ]
  end
end
```

### 2. Schema Evolution

```elixir
defmodule Pipeline.Schema.Evolution do
  @moduledoc """
  Evolve schemas based on usage patterns.
  """
  
  def evolve_schema(current_schema, usage_data) do
    %{
      version: increment_version(current_schema),
      schema: apply_evolution(current_schema, usage_data),
      changelog: generate_changelog(current_schema, usage_data),
      migration: generate_migration_guide(current_schema)
    }
  end
  
  defp apply_evolution(schema, usage_data) do
    schema
    |> add_frequently_used_patterns(usage_data)
    |> remove_unused_features(usage_data)
    |> optimize_based_on_errors(usage_data)
    |> modernize_syntax()
  end
end
```

## Best Practices

### 1. Schema Design Principles
- Start simple, add complexity gradually
- Use clear, unambiguous field names
- Provide examples for complex structures
- Test with multiple LLM providers

### 2. Provider-Specific Tips
- **Claude**: Use detailed descriptions and examples
- **Gemini**: Keep schemas flat and simple
- **OpenAI**: Leverage function calling for best results

### 3. Maintenance Guidelines
- Version schemas for backward compatibility
- Track validation success rates
- Update based on LLM provider updates
- Document schema changes clearly

## Conclusion

Effective JSON Schema generation for LLM constraints requires understanding both the capabilities of different LLM providers and the specific requirements of pipeline generation. By using progressive complexity, context-aware generation, and continuous optimization based on feedback, we can create schemas that consistently produce valid, high-quality pipeline configurations from LLM outputs.