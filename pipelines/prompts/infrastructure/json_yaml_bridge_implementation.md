# JSON/YAML Bridge Implementation Prompt

## Context Recontextualization

You are working on the pipeline_ex system, an Elixir-based pipeline generator that needs a robust JSON/YAML bridge system for seamless format conversion with type preservation.

### Current System State
- **YAML processing**: Uses `YamlElixir.read_from_string/1` in `lib/pipeline/config.ex` for basic YAML loading
- **JSON processing**: Uses `Jason.encode/2` and `Jason.decode/1` in `lib/pipeline/result_manager.ex` for serialization
- **Key conversion**: Manual atom/string conversion with `atomize_keys/1` function
- **Type handling**: No type preservation across format boundaries
- **Validation**: Separate validation after parsing, no schema-aware conversion

### Current Problems
1. **Type loss during conversion** - YAML numbers become strings in JSON
2. **No bidirectional support** - Can't reliably convert JSON back to YAML
3. **Limited schema integration** - No validation during conversion
4. **Manual key handling** - Requires explicit atom/string conversion
5. **DSPy incompatibility** - No support for DSPy signature schemas

### DSPy Integration Requirements
- **Signature conversion** - Convert DSPy YAML signatures to JSON format
- **Type preservation** - Maintain exact data types through conversion
- **Schema validation** - Validate during conversion process
- **Structured output** - Handle complex nested structures
- **Bidirectional conversion** - Support both YAML→JSON and JSON→YAML

## Task

Implement a comprehensive JSON/YAML bridge system that enables seamless conversion between formats while preserving data types and supporting DSPy integration.

### Required Components

1. **Core Bridge Module** (`lib/pipeline/bridge/json_yaml_bridge.ex`)
   - Bidirectional conversion with type preservation
   - Schema-aware conversion and validation
   - Configurable conversion options
   - Error handling with detailed context

2. **Type Preservation System** (`lib/pipeline/bridge/type_preserver.ex`)
   - Extract and maintain type metadata
   - Support for complex nested structures
   - Schema-based type inference
   - Type coercion rules and validation

3. **Format Handlers** (`lib/pipeline/bridge/format_handlers.ex`)
   - Specialized YAML handler with type normalization
   - Enhanced JSON handler with type preservation
   - Custom type conversion rules
   - Format-specific optimization

4. **DSPy Support Module** (`lib/pipeline/bridge/dspy_support.ex`)
   - DSPy signature conversion
   - Signature schema validation
   - Type metadata extraction for DSPy
   - DSPy-specific conversion rules

5. **Configuration Integration** (`lib/pipeline/bridge/config_integration.ex`)
   - Integration with existing config system
   - Schema-aware config loading
   - Backward compatibility layer
   - Performance optimization

### Implementation Requirements

- **Preserve existing functionality** - All current YAML/JSON processing must continue working
- **Type safety** - Maintain data types across all conversions
- **Schema validation** - Validate data during conversion process
- **Error handling** - Comprehensive error reporting with context
- **Performance** - Efficient conversion with caching support
- **Extensibility** - Support for custom type handlers and rules

### Conversion Examples

The bridge must handle conversions like:
```yaml
# YAML Input
workflow:
  timeout: 30          # integer
  enabled: true        # boolean
  created_at: 2024-01-01T00:00:00Z  # datetime
  scores: [85, 92, 78] # array of integers
```

```json
// JSON Output (with type preservation)
{
  "workflow": {
    "timeout": 30,
    "enabled": true,
    "created_at": "2024-01-01T00:00:00Z",
    "scores": [85, 92, 78]
  }
}
```

### DSPy Signature Support

Must support DSPy signature conversion:
```yaml
# DSPy YAML Signature
signature:
  input_fields:
    - name: code
      type: string
      description: "Source code"
  output_fields:
    - name: analysis
      type: object
      description: "Analysis results"
```

### Integration Points

- **Configuration system** - Enhance existing config loading
- **Result manager** - Improve serialization/deserialization
- **Step execution** - Support type-aware step result handling
- **Schema validator** - Integrate with enhanced validation system

### Code Style Requirements

- Follow existing Elixir patterns from the codebase
- Use GenServer for stateful components where appropriate
- Include comprehensive documentation and examples
- Add detailed logging for debugging
- Structure with clear module boundaries

### Testing Requirements

- Test all conversion scenarios (YAML↔JSON)
- Validate type preservation in all cases
- Test DSPy signature conversion
- Include performance benchmarks
- Add edge case handling tests

### Performance Considerations

- Implement caching for frequently converted data
- Support streaming for large files
- Optimize memory usage for large datasets
- Add configurable conversion options

Implement this bridge system as a complete, production-ready solution that integrates seamlessly with the existing pipeline_ex architecture while providing the foundation for DSPy integration.