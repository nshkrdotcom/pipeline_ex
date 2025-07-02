# Pipeline Schema Validation System

## Overview

The Pipeline Schema Validation System provides comprehensive JSON Schema-based validation for step outputs, ensuring structured data exchange between pipeline steps with clear error reporting and automatic validation.

## Features

- ✅ **JSON Schema Validation**: Full support for JSON Schema specification
- ✅ **Automatic Validation**: Validates step outputs when `output_schema` is specified
- ✅ **Detailed Error Messages**: Clear, actionable validation error reporting
- ✅ **Common Schema Library**: Pre-built schemas for common data structures
- ✅ **Flexible Data Extraction**: Handles various result formats automatically
- ✅ **Integration with Result Manager**: Seamless integration with existing pipeline infrastructure

## Usage

### Basic Schema Definition

Add an `output_schema` field to any pipeline step:

```yaml
- name: "analyze_code"
  type: "claude"
  prompt: "Analyze this code..."
  output_schema:
    type: "object"
    required: ["analysis", "score"]
    properties:
      analysis:
        type: "string"
        minLength: 50
      score:
        type: "number"
        minimum: 0
        maximum: 10
```

### Supported Schema Types

- **string**: Text validation with length, pattern, and enum constraints
- **number**: Numeric validation with min/max bounds
- **integer**: Integer validation with constraints
- **boolean**: Boolean value validation
- **object**: Object validation with property schemas and requirements
- **array**: Array validation with item schemas and length constraints
- **null**: Null value validation

### Schema Constraints

#### String Constraints
```yaml
properties:
  name:
    type: "string"
    minLength: 2
    maxLength: 50
    pattern: "^[A-Za-z ]+$"
    enum: ["red", "green", "blue"]
```

#### Numeric Constraints
```yaml
properties:
  score:
    type: "number"
    minimum: 0
    maximum: 100
    exclusiveMinimum: 0
    exclusiveMaximum: 100
```

#### Object Constraints
```yaml
properties:
  user:
    type: "object"
    required: ["name", "email"]
    properties:
      name: {type: "string"}
      email: {type: "string"}
    additionalProperties: false
```

#### Array Constraints
```yaml
properties:
  tags:
    type: "array"
    minItems: 1
    maxItems: 10
    items:
      type: "string"
```

## Common Schemas

The system includes pre-built schemas for common use cases:

```elixir
# Get a common schema
schema = Pipeline.Schemas.CommonSchemas.analysis_result_schema()

# Available schemas:
- analysis_result
- code_analysis  
- test_results
- api_response
- file_operation
- documentation
```

### Analysis Result Schema
```yaml
output_schema:
  type: "object"
  required: ["analysis", "score"]
  properties:
    analysis: {type: "string", minLength: 10}
    score: {type: "number", minimum: 0, maximum: 10}
    summary: {type: "string", maxLength: 500}
    recommendations:
      type: "array"
      items:
        type: "object"
        required: ["priority", "action"]
        properties:
          priority: {type: "string", enum: ["high", "medium", "low"]}
          action: {type: "string", minLength: 5}
```

### Test Results Schema
```yaml
output_schema:
  type: "object"
  required: ["total_tests", "passed", "failed", "status"]
  properties:
    total_tests: {type: "integer", minimum: 0}
    passed: {type: "integer", minimum: 0}
    failed: {type: "integer", minimum: 0}
    status: {type: "string", enum: ["passed", "failed", "partial"]}
    duration: {type: "number", minimum: 0}
```

## Data Extraction

The system automatically extracts validation data from various result formats:

1. **Structured Results**: Extracts from `data`, `content`, `text`, or `response` fields
2. **Success Results**: Filters out metadata fields (`success`, `cost`, `duration`, `timestamp`)
3. **Direct Data**: Validates the result directly if no nested structure is found
4. **Key Conversion**: Automatically converts atom keys to strings for JSON Schema compatibility

## Error Handling

### Validation Errors

When validation fails, you get detailed error information:

```
Schema validation failed for step 'analyze_code' (2 errors):
  1. analysis: String must be at least 50 characters long
  2. score: Value must be <= 10
```

### Error Structure

Each validation error includes:
- `path`: Location of the error in the data structure
- `message`: Human-readable error description
- `value`: The actual value that failed validation
- `schema`: The schema that was violated

## Integration

### Result Manager Integration

```elixir
# Automatic validation when storing results
{:ok, manager} = ResultManager.store_result_with_schema(
  manager, 
  "step_name", 
  result, 
  schema
)

# Manual validation
{:ok, validated_data} = SchemaValidator.validate_step_output(
  "step_name", 
  data, 
  schema
)
```

### Pipeline Execution

Schema validation is automatically triggered during pipeline execution when an `output_schema` is specified in the step definition.

## Best Practices

1. **Start Simple**: Begin with basic required fields and add constraints incrementally
2. **Use Common Schemas**: Leverage pre-built schemas for standard data structures
3. **Descriptive Constraints**: Add meaningful descriptions to schema properties
4. **Fail Fast**: Use schema validation to catch data issues early in the pipeline
5. **Test Schemas**: Validate your schemas with sample data before deployment

## Examples

See `examples/schema_validation_example.yaml` for a complete pipeline demonstrating schema validation features.

## API Reference

### SchemaValidator Module

- `validate/2` - Validate data against a schema
- `validate_step_output/3` - Validate with detailed step context
- `valid_schema?/1` - Check if a schema is valid
- `supported_types/0` - Get list of supported JSON Schema types

### ResultManager Integration

- `store_result_with_schema/4` - Store result with optional schema validation
- Schema validation is integrated into the normal result storage flow

### Common Schemas

- `Pipeline.Schemas.CommonSchemas.analysis_result_schema/0`
- `Pipeline.Schemas.CommonSchemas.code_analysis_schema/0`
- `Pipeline.Schemas.CommonSchemas.test_results_schema/0`
- `Pipeline.Schemas.CommonSchemas.api_response_schema/0`
- `Pipeline.Schemas.CommonSchemas.file_operation_schema/0`
- `Pipeline.Schemas.CommonSchemas.documentation_schema/0`