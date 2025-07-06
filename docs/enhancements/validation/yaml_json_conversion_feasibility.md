# YAML/JSON Conversion Feasibility Study for Pipeline_ex

## Executive Summary

Converting between YAML and JSON in Pipeline_ex is **highly feasible** with a **hybrid build/buy approach**:
- **Buy**: Use existing libraries (`yaml_elixir` for parsing, `ymlr` for encoding, `jason` for JSON)
- **Build**: Create a thin conversion layer that handles pipeline-specific concerns

This approach supports the goal of using YAML for human readability while internally working with JSON for LLM interactions.

## Current State Analysis

### What We Have
- **YAML Parsing**: ✅ `yaml_elixir v2.11` (already in use)
- **JSON Handling**: ✅ `jason` (already in use)
- **YAML Encoding**: ❌ Not currently available

### What We Need
- YAML encoding capability
- Bidirectional conversion utilities
- Validation after conversion
- Format-specific optimizations

## Build vs Buy Analysis

### Option 1: Pure "Buy" - Use Existing Libraries

**Libraries to Add:**
```elixir
# mix.exs
defp deps do
  [
    {:ymlr, "~> 5.1"},  # YAML encoding
    # existing: {:yaml_elixir, "~> 2.11"}
    # existing: {:jason, "~> 1.4"}
  ]
end
```

**Pros:**
- Minimal development effort
- Well-tested libraries
- Community support

**Cons:**
- No pipeline-specific optimizations
- Manual handling of conversion edge cases
- No integrated validation

### Option 2: Pure "Build" - Custom Implementation

**Pros:**
- Complete control over conversion
- Pipeline-specific optimizations
- Integrated validation

**Cons:**
- Significant development effort
- Maintenance burden
- Reinventing the wheel
- YAML spec complexity

### Option 3: Hybrid Approach (Recommended) ✅

**Implementation:**
```elixir
defmodule Pipeline.Format.Converter do
  @moduledoc """
  Handles YAML<->JSON conversion for pipeline configurations.
  Preserves pipeline-specific semantics during conversion.
  """
  
  alias Pipeline.Validation.Schemas.WorkflowSchema
  
  @doc """
  Convert YAML string to JSON with validation
  """
  def yaml_to_json(yaml_string, opts \\ []) do
    with {:ok, data} <- parse_yaml(yaml_string),
         {:ok, normalized} <- normalize_pipeline_data(data),
         {:ok, validated} <- validate_if_requested(normalized, opts),
         {:ok, json} <- encode_json(validated, opts) do
      {:ok, json}
    end
  end
  
  @doc """
  Convert JSON string to YAML with validation
  """
  def json_to_yaml(json_string, opts \\ []) do
    with {:ok, data} <- Jason.decode(json_string),
         {:ok, normalized} <- normalize_pipeline_data(data),
         {:ok, validated} <- validate_if_requested(normalized, opts),
         yaml <- encode_yaml(validated, opts) do
      {:ok, yaml}
    end
  end
  
  # Private functions handle pipeline-specific concerns
  defp normalize_pipeline_data(data) do
    data
    |> ensure_string_keys()
    |> normalize_step_types()
    |> handle_null_values()
    |> preserve_numeric_types()
  end
end
```

## Implementation Design

### 1. Core Conversion Module
```elixir
defmodule Pipeline.Format do
  defmodule Converter do
    # YAML <-> JSON conversion
  end
  
  defmodule Normalizer do
    # Pipeline-specific data normalization
  end
  
  defmodule Validator do
    # Format validation using Exdantic
  end
  
  defmodule Cache do
    # Cache converted formats for performance
  end
end
```

### 2. Pipeline-Specific Handling

#### Features to Preserve:
- Step type consistency
- Prompt template structures
- Variable references (`{{var}}`)
- Function definitions
- Conditional expressions

#### Features to Normalize:
- Key format (string vs atom)
- Null/nil representation
- Number types (int vs float)
- Boolean values

### 3. LLM Integration Optimizations

```elixir
defmodule Pipeline.Format.LLMOptimizer do
  @doc """
  Optimize JSON for LLM consumption
  """
  def optimize_for_llm(json_data) do
    json_data
    |> remove_null_values()
    |> flatten_single_item_arrays()
    |> simplify_boolean_fields()
    |> add_schema_hints()
  end
  
  @doc """
  Prepare YAML for human editing
  """
  def optimize_for_human(yaml_data) do
    yaml_data
    |> add_helpful_comments()
    |> use_readable_multiline_strings()
    |> group_related_fields()
    |> sort_keys_logically()
  end
end
```

### 4. Validation Integration

```elixir
defmodule Pipeline.Format.ValidatedConverter do
  def yaml_to_validated_json(yaml_string) do
    with {:ok, data} <- Converter.yaml_to_json(yaml_string),
         {:ok, validated} <- WorkflowSchema.validate(data) do
      {:ok, Jason.encode!(validated)}
    end
  end
end
```

## Migration Strategy

### Phase 1: Foundation (Week 1)
1. Add `ymlr` dependency
2. Create basic converter module
3. Add conversion tests
4. Document conversion limitations

### Phase 2: Integration (Week 2)
1. Integrate with existing pipeline loading
2. Add format detection
3. Create CLI conversion tools
4. Add performance benchmarks

### Phase 3: Optimization (Week 3)
1. Add caching layer
2. Implement LLM optimizations
3. Add streaming for large files
4. Create format migration tools

### Phase 4: Tooling (Week 4)
1. VS Code extension support
2. Format validation commands
3. Batch conversion utilities
4. Documentation generation

## Technical Considerations

### 1. Security
- Never use `atoms: true` with untrusted input
- Validate data structure before conversion
- Sanitize file paths and names
- Limit file sizes for conversion

### 2. Performance
- Cache frequently converted formats
- Use streaming for large files (>10MB)
- Batch conversions when possible
- Consider background processing

### 3. Compatibility
- Document YAML features that don't survive conversion
- Provide migration guides
- Support both formats in APIs
- Version converted formats

### 4. Error Handling
```elixir
def handle_conversion_error(error, context) do
  case error do
    {:yaml_parse_error, reason} ->
      suggest_yaml_fixes(reason, context)
    
    {:json_encode_error, reason} ->
      identify_problematic_data(reason, context)
    
    {:validation_error, errors} ->
      format_validation_errors(errors, context)
  end
end
```

## Cost-Benefit Analysis

### Benefits
1. **Developer Experience**: YAML for humans, JSON for machines
2. **LLM Integration**: Optimal format for AI interactions
3. **Tooling Support**: Better IDE integration with JSON Schema
4. **Flexibility**: Support multiple input formats
5. **Performance**: Cached conversions, optimized formats

### Costs
1. **Development Time**: ~1 week for full implementation
2. **Dependencies**: One additional dependency (ymlr)
3. **Complexity**: Additional conversion layer
4. **Testing**: Need comprehensive conversion tests

## Recommendation

**Implement the hybrid approach** with these priorities:

1. **Immediate**: Add `ymlr` and basic conversion utilities
2. **Short-term**: Integrate with pipeline validation using Exdantic
3. **Medium-term**: Add LLM optimizations and caching
4. **Long-term**: Build comprehensive tooling ecosystem

This approach provides the best balance of:
- Quick implementation using proven libraries
- Pipeline-specific optimizations where needed
- Future flexibility for format evolution
- Solid foundation for LLM integration

The investment is justified by improved developer experience and better LLM integration capabilities.