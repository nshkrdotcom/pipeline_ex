# JSON-First Pipeline Architecture

## Overview

This document outlines a JSON-first architecture where JSON is the canonical format for all machine-to-machine communication (especially LLMs), while YAML serves as the human-readable interface. This approach leverages the strengths of both formats while ensuring robust validation and error handling.

## Architecture Principles

### 1. Format Separation

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Human     │────▶│    YAML     │────▶│    JSON     │
│   Input     │     │   Format    │     │  (Internal) │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                     ▲
                           ▼                     │
                    ┌─────────────┐              │
                    │ Conversion  │──────────────┘
                    │   Layer     │
                    └─────────────┘
                           ▲
                           │
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     LLM     │────▶│    JSON     │────▶│ Validation  │
│   Output    │     │   Format    │     │   Engine    │
└─────────────┘     └─────────────┘     └─────────────┘
```

### 2. Core Design Decisions

1. **JSON as Canonical Format**
   - All internal processing uses JSON
   - LLMs generate JSON directly
   - Validation schemas defined for JSON
   - Storage and transmission in JSON

2. **YAML for Human Interface**
   - Editing and reading by developers
   - Configuration files in repositories
   - Examples and documentation
   - Optional, not required

3. **Bidirectional Conversion**
   - Lossless YAML → JSON conversion
   - Smart JSON → YAML formatting
   - Preserve comments and structure where possible

## Implementation Architecture

### 1. Format Manager

```elixir
defmodule Pipeline.Format.Manager do
  @moduledoc """
  Centralized format management for pipeline configurations.
  """
  
  @type format :: :json | :yaml
  @type pipeline_data :: map()
  
  @doc """
  Load pipeline from any supported format
  """
  @spec load(String.t() | map(), opts :: keyword()) :: 
    {:ok, pipeline_data()} | {:error, term()}
  def load(source, opts \\ []) do
    with {:ok, format, data} <- detect_and_parse(source),
         {:ok, normalized} <- normalize_to_json(data, format),
         {:ok, validated} <- validate_if_requested(normalized, opts) do
      {:ok, validated}
    end
  end
  
  @doc """
  Export pipeline to specified format
  """
  @spec export(pipeline_data(), format(), opts :: keyword()) :: 
    {:ok, String.t()} | {:error, term()}
  def export(data, format, opts \\ []) do
    with {:ok, validated} <- validate_before_export(data),
         {:ok, formatted} <- format_for_export(validated, format, opts) do
      {:ok, formatted}
    end
  end
end
```

### 2. JSON Schema Integration

```elixir
defmodule Pipeline.Format.Schema do
  @moduledoc """
  JSON Schema definitions for pipeline configurations.
  """
  
  @doc """
  Get the complete pipeline JSON Schema for validation
  """
  def pipeline_schema do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "type" => "object",
      "required" => ["workflow"],
      "properties" => %{
        "workflow" => workflow_schema()
      }
    }
  end
  
  @doc """
  Get schema for LLM structured output generation
  """
  def llm_generation_schema(options \\ []) do
    base_schema = pipeline_schema()
    
    # Add LLM-specific constraints
    base_schema
    |> add_llm_constraints(options)
    |> optimize_for_provider(options[:provider])
  end
  
  defp workflow_schema do
    %{
      "type" => "object",
      "required" => ["name", "steps"],
      "properties" => %{
        "name" => %{"type" => "string", "minLength" => 1},
        "description" => %{"type" => "string"},
        "steps" => %{
          "type" => "array",
          "minItems" => 1,
          "items" => step_schema()
        }
      }
    }
  end
end
```

### 3. Validation Pipeline

```elixir
defmodule Pipeline.Format.Validator do
  @moduledoc """
  Multi-stage validation for pipeline configurations.
  """
  
  alias Pipeline.Format.Schema
  
  @doc """
  Comprehensive validation pipeline for JSON configurations
  """
  def validate_pipeline(json_data, context \\ %{}) do
    with :ok <- validate_json_schema(json_data),
         :ok <- validate_semantic_rules(json_data),
         :ok <- validate_references(json_data),
         :ok <- validate_executability(json_data, context) do
      {:ok, json_data}
    else
      {:error, stage, errors} ->
        {:error, build_validation_report(stage, errors, json_data)}
    end
  end
  
  # Stage 1: JSON Schema Validation
  defp validate_json_schema(data) do
    schema = Schema.pipeline_schema()
    case ExJsonSchema.validate(schema, data) do
      :ok -> :ok
      {:error, errors} -> {:error, :schema, errors}
    end
  end
  
  # Stage 2: Semantic Rules
  defp validate_semantic_rules(data) do
    rules = [
      &validate_step_dependencies/1,
      &validate_variable_references/1,
      &validate_conditional_logic/1,
      &validate_prompt_templates/1
    ]
    
    errors = Enum.flat_map(rules, fn rule -> 
      case rule.(data) do
        :ok -> []
        {:error, e} -> [e]
      end
    end)
    
    if Enum.empty?(errors), do: :ok, else: {:error, :semantic, errors}
  end
  
  # Stage 3: Reference Validation
  defp validate_references(data) do
    # Validate all internal references
    # - Step names in previous_response
    # - Function references
    # - Variable interpolations
  end
  
  # Stage 4: Executability Check
  defp validate_executability(data, context) do
    # Dry-run validation
    # - Check provider availability
    # - Verify tool access
    # - Test template rendering
  end
end
```

## LLM Integration Strategy

### 1. Structured Output Generation

```elixir
defmodule Pipeline.LLM.Generator do
  @moduledoc """
  Generate pipeline configurations using LLMs with structured outputs.
  """
  
  def generate_pipeline(description, opts \\ []) do
    provider = opts[:provider] || :claude
    
    # Get provider-optimized schema
    schema = Pipeline.Format.Schema.llm_generation_schema(provider: provider)
    
    # Build generation prompt
    prompt = build_generation_prompt(description, schema)
    
    # Generate with structured output
    case generate_with_structured_output(provider, prompt, schema) do
      {:ok, json_output} ->
        validate_and_refine(json_output, description, opts)
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp generate_with_structured_output(:claude, prompt, schema) do
    # Use Claude's JSON mode or tool use for structured output
    Pipeline.Providers.ClaudeProvider.query_structured(
      prompt,
      response_format: %{
        type: "json_object",
        schema: schema
      }
    )
  end
  
  defp generate_with_structured_output(:gemini, prompt, schema) do
    # Use Gemini's structured generation
    Pipeline.Providers.GeminiProvider.query_structured(
      prompt,
      response_schema: schema,
      response_mime_type: "application/json"
    )
  end
end
```

### 2. Validation and Refinement Pipeline

```elixir
defmodule Pipeline.LLM.Refinement do
  @moduledoc """
  Iterative refinement of LLM-generated pipelines.
  """
  
  @max_refinement_attempts 3
  
  def validate_and_refine(json_output, original_request, opts) do
    case Pipeline.Format.Validator.validate_pipeline(json_output) do
      {:ok, valid_pipeline} ->
        {:ok, valid_pipeline}
        
      {:error, validation_report} ->
        refine_with_errors(json_output, validation_report, original_request, opts)
    end
  end
  
  defp refine_with_errors(json_output, errors, request, opts, attempt \\ 1) do
    if attempt > @max_refinement_attempts do
      {:error, {:max_attempts_exceeded, errors}}
    else
      refinement_prompt = build_refinement_prompt(json_output, errors, request)
      
      case generate_refined_pipeline(refinement_prompt, opts) do
        {:ok, refined_json} ->
          validate_and_refine(refined_json, request, opts)
        {:error, reason} ->
          {:error, {:refinement_failed, reason}}
      end
    end
  end
end
```

### 3. Format Conversion Layer

```elixir
defmodule Pipeline.Format.Converter do
  @moduledoc """
  Bidirectional conversion between JSON and YAML formats.
  """
  
  @doc """
  Convert JSON to YAML with formatting optimizations
  """
  def json_to_yaml(json_data, opts \\ []) do
    yaml_data = json_data
    |> prepare_for_yaml()
    |> apply_yaml_optimizations(opts)
    
    {:ok, Ymlr.document!(yaml_data, opts)}
  end
  
  @doc """
  Convert YAML to JSON with normalization
  """
  def yaml_to_json(yaml_string, opts \\ []) do
    with {:ok, data} <- YamlElixir.read_from_string(yaml_string),
         normalized <- normalize_for_json(data) do
      {:ok, Jason.encode!(normalized, pretty: opts[:pretty])}
    end
  end
  
  defp prepare_for_yaml(data) do
    data
    |> convert_long_strings_to_multiline()
    |> group_related_fields()
    |> add_helpful_comments()
  end
  
  defp normalize_for_json(data) do
    data
    |> ensure_string_keys()
    |> normalize_null_values()
    |> flatten_multiline_strings()
  end
end
```

## Benefits of JSON-First Architecture

### 1. LLM Integration
- Direct structured output support
- No parsing ambiguity
- Provider-optimized schemas
- Reliable validation

### 2. Validation Robustness
- Single canonical format
- JSON Schema standard
- Tool ecosystem support
- Clear error messages

### 3. Developer Experience
- YAML for human editing
- JSON for programmatic use
- Seamless conversion
- Format flexibility

### 4. System Integrity
- Type preservation
- Schema evolution
- Version compatibility
- Error recovery

## Implementation Considerations

### 1. Performance
- Cache converted formats
- Lazy validation options
- Streaming for large configs
- Batch processing support

### 2. Error Handling
- Detailed error locations
- Suggested fixes
- Partial validation modes
- Recovery strategies

### 3. Extensibility
- Custom validators
- Format plugins
- Schema extensions
- Provider adaptations

## Migration Strategy

### Phase 1: Foundation
1. Implement format manager
2. Create JSON schemas
3. Build conversion layer
4. Add validation pipeline

### Phase 2: LLM Integration
1. Structured output support
2. Refinement pipeline
3. Error recovery
4. Provider optimizations

### Phase 3: Tooling
1. CLI converters
2. IDE integration
3. Validation tools
4. Documentation

## Conclusion

A JSON-first architecture provides the ideal foundation for LLM-generated pipelines while maintaining human readability through YAML. This approach ensures robust validation, reliable generation, and seamless integration with modern AI systems.