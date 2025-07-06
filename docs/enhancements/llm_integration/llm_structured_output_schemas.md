# LLM Structured Output Schemas for Pipeline Generation

## Overview

This document defines the structured output schemas specifically designed for LLM pipeline generation. These schemas balance expressiveness with constraints to ensure LLMs generate valid, executable pipelines while maintaining flexibility for complex use cases.

## Schema Design Principles

### 1. Progressive Complexity
- Start with minimal required fields
- Allow optional fields for advanced features
- Use sensible defaults to reduce LLM burden

### 2. Provider Optimization
- Adapt schemas based on LLM provider capabilities
- Use provider-specific features (Claude tools, Gemini functions)
- Optimize token usage without sacrificing validity

### 3. Error Prevention
- Constrain choices where possible (enums)
- Provide clear field descriptions
- Include examples in schema metadata

## Core Pipeline Schema

### 1. Minimal Pipeline Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "Pipeline Configuration",
  "description": "A pipeline that processes data through a series of steps",
  "required": ["workflow"],
  "properties": {
    "workflow": {
      "type": "object",
      "required": ["name", "steps"],
      "properties": {
        "name": {
          "type": "string",
          "description": "Unique identifier for the pipeline",
          "pattern": "^[a-z][a-z0-9_]*$",
          "examples": ["data_analyzer", "content_generator"]
        },
        "description": {
          "type": "string",
          "description": "Human-readable description of what the pipeline does"
        },
        "steps": {
          "type": "array",
          "description": "Ordered list of processing steps",
          "minItems": 1,
          "items": {
            "$ref": "#/definitions/step"
          }
        }
      }
    }
  },
  "definitions": {
    "step": {
      "type": "object",
      "required": ["name", "type"],
      "properties": {
        "name": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_]*$",
          "description": "Unique step identifier"
        },
        "type": {
          "type": "string",
          "enum": ["claude", "gemini", "data_transform", "file_ops"],
          "description": "Step processor type"
        },
        "prompt": {
          "description": "Instructions for AI steps",
          "oneOf": [
            {"type": "string"},
            {"$ref": "#/definitions/prompt_array"}
          ]
        }
      }
    }
  }
}
```

### 2. Enhanced Schema with Structured Prompts

```json
{
  "definitions": {
    "prompt_array": {
      "type": "array",
      "description": "Structured prompt with multiple parts",
      "items": {
        "oneOf": [
          {
            "type": "object",
            "required": ["type", "content"],
            "properties": {
              "type": {"const": "static"},
              "content": {"type": "string"}
            }
          },
          {
            "type": "object",
            "required": ["type", "step"],
            "properties": {
              "type": {"const": "previous_response"},
              "step": {"type": "string"},
              "extract": {"type": "string"}
            }
          },
          {
            "type": "object",
            "required": ["type", "path"],
            "properties": {
              "type": {"const": "file"},
              "path": {"type": "string"}
            }
          }
        ]
      }
    }
  }
}
```

### 3. Provider-Specific Schemas

#### Claude-Optimized Schema
```json
{
  "definitions": {
    "claude_step": {
      "type": "object",
      "required": ["name", "type", "prompt"],
      "properties": {
        "type": {"const": "claude"},
        "claude_options": {
          "type": "object",
          "properties": {
            "model": {
              "type": "string",
              "enum": ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"],
              "default": "claude-3-sonnet"
            },
            "max_tokens": {
              "type": "integer",
              "minimum": 1,
              "maximum": 200000,
              "default": 4096
            },
            "temperature": {
              "type": "number",
              "minimum": 0,
              "maximum": 1,
              "default": 0.7
            },
            "tools": {
              "type": "array",
              "items": {"$ref": "#/definitions/tool_definition"}
            }
          }
        }
      }
    }
  }
}
```

#### Gemini-Optimized Schema
```json
{
  "definitions": {
    "gemini_step": {
      "type": "object",
      "required": ["name", "type", "prompt"],
      "properties": {
        "type": {"const": "gemini"},
        "functions": {
          "type": "array",
          "description": "Function definitions for Gemini",
          "items": {"$ref": "#/definitions/gemini_function"}
        },
        "gemini_options": {
          "type": "object",
          "properties": {
            "model": {
              "type": "string",
              "enum": ["gemini-1.5-pro", "gemini-1.5-flash"],
              "default": "gemini-1.5-flash"
            },
            "response_mime_type": {
              "type": "string",
              "enum": ["text/plain", "application/json"],
              "default": "text/plain"
            }
          }
        }
      }
    }
  }
}
```

## Structured Output Strategies by Provider

### 1. Claude Structured Output

```elixir
defmodule Pipeline.LLM.Schemas.Claude do
  @moduledoc """
  Claude-specific schema generation for structured outputs.
  """
  
  def generation_tool_schema do
    %{
      name: "generate_pipeline",
      description: "Generate a complete pipeline configuration",
      input_schema: %{
        type: "object",
        required: ["workflow"],
        properties: %{
          workflow: %{
            type: "object",
            required: ["name", "steps"],
            properties: %{
              name: %{
                type: "string",
                description: "Pipeline identifier (lowercase, underscore separated)"
              },
              steps: %{
                type: "array",
                description: "Array of pipeline steps",
                items: step_schema()
              }
            }
          }
        }
      }
    }
  end
  
  def refinement_tool_schema do
    %{
      name: "refine_pipeline",
      description: "Refine a pipeline configuration based on validation errors",
      input_schema: %{
        type: "object",
        required: ["original_pipeline", "refinements"],
        properties: %{
          original_pipeline: %{type: "object"},
          refinements: %{
            type: "array",
            items: %{
              type: "object",
              properties: %{
                path: %{type: "string", description: "JSONPath to field"},
                action: %{type: "string", enum: ["update", "add", "remove"]},
                value: %{description: "New value for the field"}
              }
            }
          }
        }
      }
    }
  end
end
```

### 2. Gemini Structured Output

```elixir
defmodule Pipeline.LLM.Schemas.Gemini do
  @moduledoc """
  Gemini-specific schema generation using response schemas.
  """
  
  def generation_schema do
    %{
      type: "object",
      properties: %{
        workflow: %{
          type: "object",
          properties: %{
            name: %{type: "string"},
            description: %{type: "string"},
            steps: %{
              type: "array",
              items: %{
                type: "object",
                properties: %{
                  name: %{type: "string"},
                  type: %{type: "string"},
                  prompt: %{
                    oneOf: [
                      %{type: "string"},
                      %{type: "array", items: %{type: "object"}}
                    ]
                  }
                },
                required: ["name", "type"]
              }
            }
          },
          required: ["name", "steps"]
        }
      },
      required: ["workflow"]
    }
  end
  
  def configure_generation_request(prompt, schema) do
    %{
      contents: [%{parts: [%{text: prompt}]}],
      generation_config: %{
        response_mime_type: "application/json",
        response_schema: schema
      }
    }
  end
end
```

## Schema Composition Patterns

### 1. Modular Schema Building

```elixir
defmodule Pipeline.LLM.Schemas.Builder do
  @moduledoc """
  Build schemas dynamically based on requirements.
  """
  
  def build_schema(requirements) do
    base_schema()
    |> add_step_types(requirements[:allowed_steps])
    |> add_constraints(requirements[:constraints])
    |> add_examples(requirements[:examples])
    |> optimize_for_provider(requirements[:provider])
  end
  
  defp add_step_types(schema, nil), do: schema
  defp add_step_types(schema, allowed_steps) do
    put_in(
      schema,
      ["definitions", "step", "properties", "type", "enum"],
      allowed_steps
    )
  end
  
  defp add_constraints(schema, constraints) do
    Enum.reduce(constraints, schema, fn
      {:max_steps, n}, acc ->
        put_in(acc, ["properties", "workflow", "properties", "steps", "maxItems"], n)
      
      {:required_steps, steps}, acc ->
        add_required_steps_constraint(acc, steps)
      
      {:forbidden_features, features}, acc ->
        remove_features_from_schema(acc, features)
    end)
  end
end
```

### 2. Context-Aware Schema Selection

```elixir
defmodule Pipeline.LLM.Schemas.Selector do
  @moduledoc """
  Select appropriate schema based on generation context.
  """
  
  def select_schema(context) do
    cond do
      context[:user_expertise] == :beginner ->
        simplified_schema()
      
      context[:pipeline_type] == :data_processing ->
        data_pipeline_schema()
      
      context[:pipeline_type] == :multi_agent ->
        multi_agent_schema()
      
      true ->
        general_purpose_schema()
    end
  end
  
  defp simplified_schema do
    # Minimal schema with only essential fields
    # Hidden complexity, strong defaults
  end
  
  defp data_pipeline_schema do
    # Schema optimized for data transformation pipelines
    # Includes data_transform, file_ops steps
  end
  
  defp multi_agent_schema do
    # Schema with routing, conditional edges
    # Support for agent collaboration patterns
  end
end
```

## Validation Integration

### 1. Pre-Generation Validation

```elixir
defmodule Pipeline.LLM.Schemas.PreValidator do
  @moduledoc """
  Validate requirements before schema generation.
  """
  
  def validate_generation_request(request) do
    with :ok <- validate_request_clarity(request),
         :ok <- validate_feasibility(request),
         :ok <- validate_resource_requirements(request) do
      {:ok, analyze_requirements(request)}
    end
  end
  
  defp validate_request_clarity(request) do
    # Check if request is specific enough
    # Identify ambiguous requirements
    # Suggest clarifications
  end
end
```

### 2. Post-Generation Validation

```elixir
defmodule Pipeline.LLM.Schemas.PostValidator do
  @moduledoc """
  Validate generated pipelines against extended rules.
  """
  
  def validate_generated(pipeline, context) do
    validations = [
      &validate_against_schema/2,
      &validate_semantic_coherence/2,
      &validate_execution_feasibility/2,
      &validate_resource_usage/2
    ]
    
    Enum.reduce_while(validations, {:ok, pipeline}, fn validator, {:ok, data} ->
      case validator.(data, context) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end
end
```

## Best Practices for LLM Schema Design

### 1. Schema Simplification Rules
- Remove fields LLMs rarely use correctly
- Provide strong defaults for complex options
- Use enums instead of free-form strings where possible

### 2. Error Prevention Patterns
- Clear, unambiguous field descriptions
- Examples for complex structures
- Mutually exclusive field groups clearly marked

### 3. Token Optimization
- Shorter field names for high-frequency fields
- Optional fields truly optional (not required with null)
- Compress schema for token-limited models

### 4. Iterative Refinement Support
- Design schemas that support partial updates
- Include metadata for tracking changes
- Allow incremental complexity addition

## Conclusion

These structured output schemas provide a robust foundation for LLM pipeline generation. By carefully balancing constraints with flexibility, and optimizing for specific providers, we can achieve high success rates in generating valid, executable pipelines while maintaining the expressiveness needed for complex use cases.