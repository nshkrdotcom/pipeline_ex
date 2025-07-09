# Schema Validation Upgrade Requirements

## Current Architecture Analysis

### Existing Validation System

The current pipeline_ex system has a solid foundation for schema validation but requires significant enhancements to support DSPy integration. Here's the current state:

#### 1. **Current Schema Validator** (`lib/pipeline/validation/schema_validator.ex`)

**Strengths:**
- Comprehensive JSON Schema validation implementation
- Supports all standard JSON Schema types (object, array, string, number, etc.)
- Detailed error reporting with path information
- Validation constraints (min/max length, patterns, enums)
- Step-specific validation with context

**Limitations:**
- **No YAML schema support** - only validates JSON structures
- **No type preservation** - loses original data types during validation
- **No schema composition** - can't extend or merge schemas
- **No conditional validation** - no support for if/then/else logic
- **Limited metadata support** - no annotation or documentation fields

#### 2. **Current Configuration System** (`lib/pipeline/config.ex` and `lib/pipeline/enhanced_config.ex`)

**Current YAML Processing:**
```elixir
{:ok, config} <- YamlElixir.read_from_string(content)
```

**Strengths:**
- Comprehensive step validation
- Support for enhanced step types
- Extensive options validation
- Environment-specific configuration

**Limitations:**
- **YAML-only input** - no JSON support
- **No bidirectional conversion** - can't convert back to YAML
- **No schema-driven validation** - validation is hard-coded
- **No extensibility** - can't add new validation rules dynamically

#### 3. **Result Management** (`lib/pipeline/result_manager.ex`)

**Current JSON Handling:**
```elixir
# Serialization
Jason.encode(data, pretty: true)

# Deserialization  
case Jason.decode(json_string) do
  {:ok, data} -> 
    # Manual key conversion
    restored_results = Map.new(results, fn {step_name, result} ->
      {step_name, atomize_keys(result)}
    end)
```

**Strengths:**
- JSON serialization/deserialization
- Result validation and transformation
- Schema-based validation support (basic)

**Limitations:**
- **Manual key conversion** - no automatic type preservation
- **Limited schema integration** - basic validation only
- **No YAML support** - JSON only
- **No structured output validation** - relies on manual transformation

## DSPy Integration Requirements

### 1. **DSPy Signature Schema Support**

DSPy requires structured input/output definitions that need to be validated and converted:

```yaml
# Required DSPy signature format
signature:
  input_fields:
    - name: code
      type: string
      description: "Source code to analyze"
    - name: context
      type: object
      description: "Analysis context"
      schema:
        type: object
        properties:
          language: {type: string}
          complexity: {type: string, enum: [low, medium, high]}
  
  output_fields:
    - name: analysis
      type: object
      description: "Analysis results"
      schema:
        type: object
        properties:
          issues: {type: array, items: {type: string}}
          score: {type: number, minimum: 0, maximum: 100}
```

### 2. **Structured Output Validation**

DSPy requires strict validation of outputs against schemas:

```elixir
# Need to validate DSPy outputs
{:ok, validated_output} = Pipeline.DSPy.Validator.validate_output(
  raw_output,
  signature.output_schema
)
```

### 3. **Type Preservation Requirements**

DSPy needs to preserve data types across serialization:

```elixir
# Current problem: loses type information
score = 85  # integer
# After YAML -> JSON -> Map conversion
score = "85"  # string

# DSPy requirement: preserve types
score = 85  # still integer
```

## Required Enhancements

### Phase 1: Core Schema System Enhancement

#### 1. **Enhanced Schema Validator**

```elixir
defmodule Pipeline.Enhanced.SchemaValidator do
  @moduledoc """
  Enhanced schema validation with DSPy support.
  """
  
  # Support for DSPy-specific schema features
  def validate_dspy_signature(signature_config) do
    # Validate DSPy signature format
    # Support nested schemas
    # Validate input/output field definitions
  end
  
  def validate_with_type_preservation(data, schema) do
    # Validate while preserving original types
    # Support type coercion where appropriate
    # Maintain type metadata
  end
  
  def validate_conditional_schema(data, schema) do
    # Support if/then/else logic
    # Conditional validation based on data content
    # Dynamic schema selection
  end
end
```

#### 2. **Schema Composition System**

```elixir
defmodule Pipeline.Enhanced.SchemaComposer do
  @moduledoc """
  Schema composition and extension system.
  """
  
  def compose_schemas(base_schema, extensions) do
    # Merge multiple schemas
    # Handle conflicts and overrides
    # Support allOf, anyOf, oneOf
  end
  
  def extend_schema(base_schema, extension) do
    # Extend existing schema
    # Add new properties
    # Override existing constraints
  end
end
```

### Phase 2: JSON/YAML Bridge System

#### 1. **Bidirectional Converter**

```elixir
defmodule Pipeline.Enhanced.ConfigMutator do
  @moduledoc """
  Bidirectional JSON/YAML conversion with type preservation.
  """
  
  def yaml_to_json_with_schema(yaml_content, schema) do
    # Convert YAML to JSON
    # Validate against schema
    # Preserve type information
    # Generate type metadata
  end
  
  def json_to_yaml_with_schema(json_content, schema) do
    # Convert JSON to YAML
    # Preserve type information
    # Apply schema constraints
    # Format for readability
  end
  
  def preserve_types_in_conversion(data, type_metadata) do
    # Maintain original types through conversion
    # Handle complex data structures
    # Support custom type handlers
  end
end
```

#### 2. **Type Preservation System**

```elixir
defmodule Pipeline.Enhanced.TypePreserver do
  @moduledoc """
  Type preservation across serialization boundaries.
  """
  
  defstruct [:original_types, :conversion_map, :preservation_rules]
  
  def extract_type_metadata(data) do
    # Extract type information from data
    # Create type preservation map
    # Handle nested structures
  end
  
  def apply_type_metadata(data, type_metadata) do
    # Restore original types
    # Apply type coercion
    # Validate type consistency
  end
end
```

### Phase 3: DSPy Integration Support

#### 1. **DSPy Schema Adapter**

```elixir
defmodule Pipeline.DSPy.SchemaAdapter do
  @moduledoc """
  Adapter for DSPy schema requirements.
  """
  
  def pipeline_schema_to_dspy(pipeline_schema) do
    # Convert pipeline schema to DSPy format
    # Handle signature-specific requirements
    # Support DSPy validation rules
  end
  
  def dspy_schema_to_pipeline(dspy_schema) do
    # Convert DSPy schema to pipeline format
    # Maintain validation rules
    # Support pipeline-specific features
  end
  
  def validate_dspy_compatibility(schema) do
    # Validate schema is DSPy compatible
    # Check for unsupported features
    # Suggest improvements
  end
end
```

#### 2. **Structured Output Validator**

```elixir
defmodule Pipeline.DSPy.OutputValidator do
  @moduledoc """
  Specialized validator for DSPy structured outputs.
  """
  
  def validate_structured_output(output, signature) do
    # Validate against DSPy signature
    # Handle complex output structures
    # Support partial validation
  end
  
  def extract_structured_data(raw_output, extraction_schema) do
    # Extract structured data from raw output
    # Apply extraction rules
    # Validate extracted data
  end
end
```

## Implementation Architecture

### 1. **Enhanced Configuration Flow**

```elixir
# New configuration processing flow
yaml_content
|> Pipeline.Enhanced.ConfigMutator.yaml_to_json_with_schema(base_schema)
|> Pipeline.Enhanced.SchemaValidator.validate_with_type_preservation(full_schema)
|> Pipeline.Enhanced.SchemaComposer.compose_schemas(dspy_extensions)
|> Pipeline.DSPy.SchemaAdapter.ensure_dspy_compatibility()
```

### 2. **Result Processing Enhancement**

```elixir
# Enhanced result processing
raw_result
|> Pipeline.DSPy.OutputValidator.validate_structured_output(signature)
|> Pipeline.Enhanced.TypePreserver.preserve_types()
|> Pipeline.Enhanced.ResultManager.store_with_metadata()
```

### 3. **Schema Definition System**

```yaml
# Enhanced schema definition
schema:
  version: "2.0"
  type: "dspy_compatible"
  
  base_schema:
    type: object
    properties:
      input: {type: string}
      output: {type: object}
  
  dspy_extensions:
    signature:
      input_fields:
        - name: input
          type: string
          validation: {minLength: 1}
      output_fields:
        - name: output
          type: object
          validation: {required: [result]}
  
  type_preservation:
    enabled: true
    preserve_numbers: true
    preserve_booleans: true
    custom_types:
      - name: "timestamp"
        pattern: "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z"
        convert_to: "datetime"
```

## Migration Strategy

### Phase 1: Backwards Compatible Enhancement

1. **Extend existing SchemaValidator** without breaking changes
2. **Add optional type preservation** to existing validation
3. **Implement basic JSON/YAML conversion** alongside existing system

### Phase 2: Enhanced Feature Integration

1. **Add DSPy schema support** as optional feature
2. **Implement structured output validation** for DSPy steps
3. **Add schema composition** for complex workflows

### Phase 3: Full DSPy Integration

1. **Enable DSPy optimization** with full schema support
2. **Add automatic schema generation** from DSPy signatures
3. **Implement optimization feedback** into schema validation

## Benefits of Enhanced System

### 1. **Reliability**
- Strict validation prevents runtime errors
- Type preservation eliminates conversion bugs
- Schema composition enables complex workflows

### 2. **DSPy Compatibility**
- Full support for DSPy signature requirements
- Structured output validation
- Seamless integration with optimization

### 3. **Developer Experience**
- Clear error messages with path information
- Flexible schema composition
- Automatic type handling

### 4. **Performance**
- Efficient validation with caching
- Minimal memory overhead
- Fast conversion between formats

This enhanced schema validation system provides the foundation needed for reliable DSPy integration while maintaining backwards compatibility with existing pipelines.