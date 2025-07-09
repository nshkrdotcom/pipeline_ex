# JSON/YAML Bridge Architecture

## Overview

This document details the architecture for a robust JSON/YAML bridge system that enables seamless conversion between formats while preserving data types and supporting DSPy integration requirements.

## Current System Analysis

### Current YAML Processing
```elixir
# lib/pipeline/config.ex and lib/pipeline/enhanced_config.ex
{:ok, config} <- YamlElixir.read_from_string(content)
```

### Current JSON Processing
```elixir
# lib/pipeline/result_manager.ex
Jason.encode(data, pretty: true)
Jason.decode(json_string)
```

### Key Problems Identified

1. **Type Loss During Conversion**
   - YAML numbers become strings in JSON
   - Boolean values lose type information
   - Complex types (dates, timestamps) become strings

2. **No Bidirectional Support**
   - Can't convert JSON back to YAML reliably
   - No round-trip guarantee for configuration
   - Loss of YAML-specific features (comments, formatting)

3. **Limited Schema Integration**
   - No validation during conversion
   - No type hints from schema
   - No automatic type coercion

4. **DSPy Incompatibility**
   - DSPy requires strict type preservation
   - No support for DSPy signature schemas
   - No structured output handling

## Bridge Architecture Design

### 1. **Core Bridge Component**

```elixir
defmodule Pipeline.Bridge.JsonYamlBridge do
  @moduledoc """
  Bidirectional JSON/YAML conversion with type preservation.
  """
  
  defstruct [
    :source_format,
    :target_format,
    :type_metadata,
    :schema,
    :conversion_options
  ]
  
  @type format :: :json | :yaml
  @type conversion_options :: %{
    preserve_types: boolean(),
    validate_schema: boolean(),
    pretty_print: boolean(),
    maintain_comments: boolean()
  }
  
  def new(source_format, target_format, opts \\ []) do
    %__MODULE__{
      source_format: source_format,
      target_format: target_format,
      type_metadata: %{},
      schema: Keyword.get(opts, :schema),
      conversion_options: build_conversion_options(opts)
    }
  end
  
  def convert(bridge, data) do
    with {:ok, parsed_data} <- parse_source_data(data, bridge.source_format),
         {:ok, type_metadata} <- extract_type_metadata(parsed_data, bridge.schema),
         {:ok, converted_data} <- convert_data(parsed_data, type_metadata, bridge),
         {:ok, serialized_data} <- serialize_target_data(converted_data, bridge.target_format, bridge.conversion_options) do
      {:ok, serialized_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### 2. **Type Preservation System**

```elixir
defmodule Pipeline.Bridge.TypePreserver do
  @moduledoc """
  Advanced type preservation across format conversions.
  """
  
  defstruct [
    :type_map,
    :preservation_rules,
    :custom_handlers
  ]
  
  @type type_info :: %{
    original_type: atom(),
    target_type: atom(),
    conversion_rule: atom(),
    metadata: map()
  }
  
  def extract_type_metadata(data, schema \\ nil) do
    type_map = 
      data
      |> traverse_data(&analyze_type/1)
      |> enhance_with_schema(schema)
    
    {:ok, %{type_map: type_map, schema: schema}}
  end
  
  def apply_type_metadata(data, type_metadata) do
    data
    |> traverse_data_with_metadata(&apply_type_conversion/2, type_metadata)
  end
  
  defp analyze_type(value) do
    %{
      original_type: determine_elixir_type(value),
      json_type: determine_json_type(value),
      yaml_type: determine_yaml_type(value),
      conversion_hints: determine_conversion_hints(value)
    }
  end
  
  defp determine_elixir_type(value) do
    cond do
      is_integer(value) -> :integer
      is_float(value) -> :float
      is_boolean(value) -> :boolean
      is_binary(value) -> :string
      is_list(value) -> :array
      is_map(value) -> :object
      is_nil(value) -> :null
      true -> :unknown
    end
  end
  
  defp determine_conversion_hints(value) do
    cond do
      is_binary(value) && String.match?(value, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/) ->
        [:datetime]
      is_binary(value) && String.match?(value, ~r/^\d+$/) ->
        [:potential_integer]
      is_binary(value) && String.match?(value, ~r/^(true|false)$/) ->
        [:potential_boolean]
      true ->
        []
    end
  end
end
```

### 3. **Schema-Aware Conversion**

```elixir
defmodule Pipeline.Bridge.SchemaAwareConverter do
  @moduledoc """
  Schema-aware conversion with validation and type coercion.
  """
  
  def convert_with_schema(data, source_format, target_format, schema) do
    with {:ok, parsed_data} <- parse_data(data, source_format),
         {:ok, validated_data} <- validate_against_schema(parsed_data, schema),
         {:ok, typed_data} <- apply_schema_types(validated_data, schema),
         {:ok, converted_data} <- convert_format(typed_data, target_format) do
      {:ok, converted_data}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  def validate_against_schema(data, schema) do
    case Pipeline.Enhanced.SchemaValidator.validate_with_type_preservation(data, schema) do
      {:ok, validated_data} -> {:ok, validated_data}
      {:error, errors} -> {:error, "Schema validation failed: #{inspect(errors)}"}
    end
  end
  
  def apply_schema_types(data, schema) do
    type_rules = extract_type_rules_from_schema(schema)
    typed_data = apply_type_rules(data, type_rules)
    {:ok, typed_data}
  end
  
  defp extract_type_rules_from_schema(schema) do
    schema
    |> traverse_schema(&extract_type_rule/1)
    |> Enum.into(%{})
  end
  
  defp extract_type_rule({path, property_schema}) do
    type_rule = %{
      path: path,
      type: property_schema["type"],
      format: property_schema["format"],
      coercion: property_schema["coercion"] || :strict
    }
    
    {path, type_rule}
  end
end
```

### 4. **DSPy Integration Support**

```elixir
defmodule Pipeline.Bridge.DSPySupport do
  @moduledoc """
  DSPy-specific conversion support.
  """
  
  def convert_dspy_signature(signature_yaml) do
    with {:ok, parsed_yaml} <- YamlElixir.read_from_string(signature_yaml),
         {:ok, dspy_schema} <- validate_dspy_signature_schema(parsed_yaml),
         {:ok, type_metadata} <- extract_dspy_type_metadata(dspy_schema),
         {:ok, converted_json} <- convert_to_dspy_json(dspy_schema, type_metadata) do
      {:ok, converted_json}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  def validate_dspy_signature_schema(data) do
    dspy_signature_schema = %{
      "type" => "object",
      "required" => ["input_fields", "output_fields"],
      "properties" => %{
        "input_fields" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["name", "type"],
            "properties" => %{
              "name" => %{"type" => "string"},
              "type" => %{"type" => "string"},
              "description" => %{"type" => "string"},
              "schema" => %{"type" => "object"}
            }
          }
        },
        "output_fields" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["name", "type"],
            "properties" => %{
              "name" => %{"type" => "string"},
              "type" => %{"type" => "string"},
              "description" => %{"type" => "string"},
              "schema" => %{"type" => "object"}
            }
          }
        }
      }
    }
    
    Pipeline.Enhanced.SchemaValidator.validate(data, dspy_signature_schema)
  end
  
  defp extract_dspy_type_metadata(signature) do
    input_types = extract_field_types(signature["input_fields"])
    output_types = extract_field_types(signature["output_fields"])
    
    type_metadata = %{
      input_types: input_types,
      output_types: output_types,
      preservation_rules: build_dspy_preservation_rules(input_types, output_types)
    }
    
    {:ok, type_metadata}
  end
  
  defp extract_field_types(fields) do
    Enum.map(fields, fn field ->
      %{
        name: field["name"],
        type: field["type"],
        schema: field["schema"],
        description: field["description"]
      }
    end)
  end
end
```

### 5. **Advanced Format Handlers**

```elixir
defmodule Pipeline.Bridge.FormatHandlers do
  @moduledoc """
  Specialized handlers for different data formats.
  """
  
  defmodule YamlHandler do
    def parse(yaml_string, opts \\ []) do
      case YamlElixir.read_from_string(yaml_string) do
        {:ok, data} -> 
          processed_data = 
            data
            |> normalize_yaml_types()
            |> apply_yaml_specific_processing(opts)
          {:ok, processed_data}
        {:error, reason} -> {:error, "YAML parsing failed: #{inspect(reason)}"}
      end
    end
    
    def serialize(data, opts \\ []) do
      processed_data = 
        data
        |> prepare_for_yaml()
        |> apply_yaml_formatting(opts)
      
      case YamlElixir.write_to_string(processed_data) do
        {:ok, yaml_string} -> {:ok, yaml_string}
        {:error, reason} -> {:error, "YAML serialization failed: #{inspect(reason)}"}
      end
    end
    
    defp normalize_yaml_types(data) do
      # Handle YAML-specific type normalization
      data
      |> convert_yaml_timestamps()
      |> convert_yaml_booleans()
      |> convert_yaml_numbers()
    end
    
    defp convert_yaml_timestamps(data) when is_map(data) do
      Map.new(data, fn {key, value} ->
        {key, convert_yaml_timestamps(value)}
      end)
    end
    
    defp convert_yaml_timestamps(data) when is_list(data) do
      Enum.map(data, &convert_yaml_timestamps/1)
    end
    
    defp convert_yaml_timestamps(value) when is_binary(value) do
      case DateTime.from_iso8601(value) do
        {:ok, datetime, _offset} -> datetime
        {:error, _} -> value
      end
    end
    
    defp convert_yaml_timestamps(value), do: value
  end
  
  defmodule JsonHandler do
    def parse(json_string, opts \\ []) do
      case Jason.decode(json_string) do
        {:ok, data} -> 
          processed_data = 
            data
            |> normalize_json_types()
            |> apply_json_specific_processing(opts)
          {:ok, processed_data}
        {:error, reason} -> {:error, "JSON parsing failed: #{inspect(reason)}"}
      end
    end
    
    def serialize(data, opts \\ []) do
      pretty = Keyword.get(opts, :pretty, false)
      
      processed_data = 
        data
        |> prepare_for_json()
        |> apply_json_formatting(opts)
      
      case Jason.encode(processed_data, pretty: pretty) do
        {:ok, json_string} -> {:ok, json_string}
        {:error, reason} -> {:error, "JSON serialization failed: #{inspect(reason)}"}
      end
    end
    
    defp normalize_json_types(data) do
      # Handle JSON-specific type normalization
      data
      |> convert_json_timestamps()
      |> convert_json_numbers()
    end
    
    defp prepare_for_json(data) do
      # Convert Elixir types to JSON-compatible types
      data
      |> convert_atoms_to_strings()
      |> convert_datetime_to_iso8601()
      |> handle_special_types()
    end
  end
end
```

### 6. **Configuration Integration**

```elixir
defmodule Pipeline.Bridge.ConfigIntegration do
  @moduledoc """
  Integration with existing pipeline configuration system.
  """
  
  def load_config_with_bridge(file_path, opts \\ []) do
    format = determine_format_from_extension(file_path)
    
    with {:ok, content} <- File.read(file_path),
         {:ok, bridge} <- create_bridge_for_config(format, opts),
         {:ok, converted_data} <- Pipeline.Bridge.JsonYamlBridge.convert(bridge, content),
         {:ok, validated_config} <- Pipeline.Enhanced.SchemaValidator.validate_config(converted_data) do
      {:ok, validated_config}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  def save_config_with_bridge(config, file_path, opts \\ []) do
    format = determine_format_from_extension(file_path)
    
    with {:ok, bridge} <- create_bridge_for_config(:elixir_map, format, opts),
         {:ok, converted_data} <- Pipeline.Bridge.JsonYamlBridge.convert(bridge, config),
         :ok <- File.write(file_path, converted_data) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp create_bridge_for_config(source_format, target_format \\ :elixir_map, opts \\ []) do
    bridge_opts = [
      preserve_types: Keyword.get(opts, :preserve_types, true),
      validate_schema: Keyword.get(opts, :validate_schema, true),
      schema: get_pipeline_config_schema()
    ]
    
    bridge = Pipeline.Bridge.JsonYamlBridge.new(source_format, target_format, bridge_opts)
    {:ok, bridge}
  end
  
  defp get_pipeline_config_schema do
    # Return the comprehensive pipeline configuration schema
    %{
      "type" => "object",
      "required" => ["workflow"],
      "properties" => %{
        "workflow" => %{
          "type" => "object",
          "required" => ["name", "steps"],
          "properties" => %{
            "name" => %{"type" => "string"},
            "description" => %{"type" => "string"},
            "steps" => %{
              "type" => "array",
              "items" => get_step_schema()
            },
            "dspy_config" => get_dspy_config_schema()
          }
        }
      }
    }
  end
end
```

### 7. **Performance Optimization**

```elixir
defmodule Pipeline.Bridge.PerformanceOptimizer do
  @moduledoc """
  Performance optimizations for bridge operations.
  """
  
  # Caching for frequently converted schemas
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def cached_convert(bridge, data) do
    cache_key = generate_cache_key(bridge, data)
    
    case get_from_cache(cache_key) do
      {:ok, cached_result} -> 
        {:ok, cached_result}
      
      :not_found ->
        case Pipeline.Bridge.JsonYamlBridge.convert(bridge, data) do
          {:ok, result} -> 
            store_in_cache(cache_key, result)
            {:ok, result}
          
          {:error, reason} -> 
            {:error, reason}
        end
    end
  end
  
  def warm_cache(common_schemas) do
    # Pre-warm cache with common conversion patterns
    Enum.each(common_schemas, fn schema ->
      bridge = Pipeline.Bridge.JsonYamlBridge.new(:yaml, :json, schema: schema)
      sample_data = generate_sample_data(schema)
      cached_convert(bridge, sample_data)
    end)
  end
  
  # Streaming support for large files
  def stream_convert(bridge, input_stream) do
    input_stream
    |> Stream.chunk_every(1000)
    |> Stream.map(&convert_chunk(bridge, &1))
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Stream.map(&elem(&1, 1))
  end
  
  defp convert_chunk(bridge, chunk) do
    try do
      Pipeline.Bridge.JsonYamlBridge.convert(bridge, chunk)
    rescue
      error ->
        Logger.error("Chunk conversion failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
```

## Usage Examples

### Basic Conversion

```elixir
# YAML to JSON with type preservation
yaml_config = """
workflow:
  name: test_pipeline
  timeout: 30
  enabled: true
  created_at: 2024-01-01T00:00:00Z
"""

bridge = Pipeline.Bridge.JsonYamlBridge.new(:yaml, :json, preserve_types: true)
{:ok, json_result} = Pipeline.Bridge.JsonYamlBridge.convert(bridge, yaml_config)
```

### DSPy Signature Conversion

```elixir
# Convert DSPy signature from YAML to JSON
dspy_signature = """
signature:
  input_fields:
    - name: code
      type: string
      description: "Source code"
  output_fields:
    - name: analysis
      type: object
      description: "Analysis results"
"""

{:ok, json_signature} = Pipeline.Bridge.DSPySupport.convert_dspy_signature(dspy_signature)
```

### Schema-Aware Conversion

```elixir
# Convert with schema validation
schema = %{
  "type" => "object",
  "properties" => %{
    "timeout" => %{"type" => "integer"},
    "enabled" => %{"type" => "boolean"}
  }
}

{:ok, result} = Pipeline.Bridge.SchemaAwareConverter.convert_with_schema(
  yaml_config, 
  :yaml, 
  :json, 
  schema
)
```

## Benefits

1. **Type Safety**: Preserves data types across format conversions
2. **Schema Validation**: Validates data during conversion
3. **DSPy Compatibility**: Full support for DSPy signature requirements
4. **Performance**: Caching and streaming for large datasets
5. **Flexibility**: Support for custom type handlers and conversion rules
6. **Error Handling**: Comprehensive error reporting with context

This bridge architecture provides the robust foundation needed for DSPy integration while maintaining compatibility with existing pipeline configurations.