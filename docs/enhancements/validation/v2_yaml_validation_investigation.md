# V2 YAML Documentation vs Implementation Investigation

## Executive Summary

This document investigates the discrepancies between the V2 YAML documentation and the actual library implementation, with a focus on schema validation capabilities. The investigation reveals that while the V2 features are well-documented and mostly implemented, there is **no formal schema validation** for the pipeline YAML structure itself.

## Key Findings

### 1. Documentation Status
- Comprehensive V2 documentation exists at `/docs/20250704_yaml_format_v2/`
- 13 detailed documentation files covering all V2 features
- Complete schema reference in `01_complete_schema_reference.md`
- Well-structured guides for migration, best practices, and patterns

### 2. Implementation Status

#### ✅ Fully Implemented V2 Features
- **All enhanced Claude step types**: `claude_smart`, `claude_session`, `claude_extract`, `claude_batch`, `claude_robust`
- **Control flow structures**: `for_loop`, `while_loop` (both handled by `Loop` module)
- **Data operations**: `data_transform`, `file_ops`
- **Nested pipelines**: `pipeline` step type (handled by `NestedPipeline` module)
- **Code analysis**: `codebase_query` step type
- **Enhanced prompt types**: `session_context`, `claude_continue`
- **Preset system**: Via `OptionBuilder` module
- **Session management**: Via `SessionManager` module

#### ⚠️ Missing Documentation in Code
- No `switch` statement implementation (documented but not in executor)
- Validation functions marked as not yet implemented in `EnhancedConfig`:
  - `validate_switch_conditions/1`
  - `validate_output_format/1`
  - `validate_case_values/1`

### 3. Schema Validation Analysis

#### Current State
1. **No formal YAML schema validation** - The pipeline YAML structure is validated through Elixir code, not JSON Schema
2. **Two validation modules exist**:
   - `Pipeline.Config` - Base validation for v1 features
   - `Pipeline.EnhancedConfig` - Extended validation for v2 features
3. **Schema validation exists only for step outputs** - `Pipeline.Validation.SchemaValidator` validates data produced by steps, not the pipeline YAML itself

#### Validation Coverage
- ✅ Required fields validation (workflow name, steps array)
- ✅ Step type validation (against known types)
- ✅ Step-specific field validation (prompts, functions, etc.)
- ✅ Reference validation (previous_response dependencies)
- ✅ Claude options validation
- ✅ Environment configuration validation
- ❌ No JSON Schema for pipeline YAML format
- ❌ No external validation capability
- ❌ No IDE integration for YAML validation

## Discrepancies Found

### 1. Missing Implementations
- **Switch/Case control flow** - Documented in `04_control_flow_logic.md` but not implemented
- Some validation functions stubbed but not implemented

### 2. Validation Gaps
- No formal schema file (`.schema.json` or `.schema.yaml`)
- Validation is tightly coupled with application code
- Cannot validate YAML files outside of the application
- No support for IDE schema validation

### 3. Documentation vs Reality
- Documentation describes features comprehensively
- Implementation covers ~95% of documented features
- Some edge cases and advanced features may have gaps

## Recommendations for Schema Validation

### 1. Create Formal JSON Schema (High Priority)
```yaml
# Create /schemas/pipeline-v2.schema.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Pipeline V2 YAML Schema",
  "type": "object",
  "required": ["workflow"],
  "properties": {
    "workflow": {
      "type": "object",
      "required": ["name", "steps"],
      ...
    }
  }
}
```

**Benefits:**
- External validation tools can use it
- IDE integration (VS Code, IntelliJ)
- Documentation generation
- Contract testing
- API documentation

### 2. Implement Schema-Based Validation (Medium Priority)
```elixir
defmodule Pipeline.Validation.YamlValidator do
  @schema_path "priv/schemas/pipeline-v2.schema.json"
  
  def validate_yaml(yaml_content) do
    with {:ok, schema} <- load_schema(),
         {:ok, data} <- YamlElixir.read_from_string(yaml_content) do
      ExJsonSchema.Validator.validate(schema, data)
    end
  end
end
```

**Benefits:**
- Single source of truth for validation
- Easier to maintain and update
- Can be used in CI/CD pipelines
- Better error messages

### 3. Add Validation CLI Tool (Low Priority)
```bash
# Standalone validation command
mix pipeline.validate path/to/pipeline.yaml

# Pre-commit hook validation
./scripts/validate-pipelines.sh
```

### 4. Complete Missing Implementations (Medium Priority)
- Implement switch/case control flow
- Complete all validation function stubs
- Add comprehensive test coverage

### 5. Schema Evolution Strategy (High Priority)
- Version the schema files
- Implement migration validation
- Support multiple schema versions
- Add deprecation warnings

## Implementation Roadmap

### Phase 1: Schema Creation (Week 1)
1. Extract validation rules from existing code
2. Create comprehensive JSON Schema
3. Test against existing YAML files
4. Document schema structure

### Phase 2: Integration (Week 2)
1. Add ExJsonSchema dependency
2. Implement YamlValidator module
3. Integrate with existing validation
4. Add validation CLI command

### Phase 3: Tooling (Week 3)
1. Create VS Code extension config
2. Add pre-commit hooks
3. Create validation GitHub Action
4. Update documentation

### Phase 4: Completion (Week 4)
1. Implement missing features
2. Add comprehensive tests
3. Update all documentation
4. Create migration guide

## Conclusion

The V2 YAML format is well-documented and mostly implemented, but lacks formal schema validation. The current code-based validation works but limits external tooling and validation capabilities. Implementing a JSON Schema-based validation system would significantly improve the developer experience, enable better tooling integration, and provide a clear contract for pipeline definitions.

The recommended approach is to create a formal JSON Schema as the single source of truth, then gradually migrate the existing validation to use it while maintaining backward compatibility.