# Pipeline YAML Format v2 Documentation

**Version**: 2.0  
**Date**: July 4, 2025  
**Status**: Complete reference for all YAML format capabilities

## Overview

This documentation provides a comprehensive reference for the Pipeline YAML format v2, covering all features including the latest recursive pipeline capabilities, enhanced Claude step types, and advanced control flow constructs.

## Documentation Structure

1. **[Complete YAML Schema Reference](./01_complete_schema_reference.md)**  
   Full schema definition with all fields, types, and validation rules

2. **[Step Types Reference](./02_step_types_reference.md)**  
   Detailed documentation for all 17+ step types including examples

3. **[Prompt System Reference](./03_prompt_system_reference.md)**  
   Complete guide to prompt composition, templates, and content processing

4. **[Control Flow & Logic](./04_control_flow_logic.md)**  
   Loops, conditions, parallel execution, and state management

5. **[Pipeline Composition](./05_pipeline_composition.md)**  
   Recursive pipelines, context management, and modular workflows

6. **[Advanced Features](./06_advanced_features.md)**  
   Data transformation, codebase intelligence, file operations

7. **[Configuration & Environment](./07_configuration_environment.md)**  
   Workflow settings, defaults, authentication, and monitoring

8. **[Best Practices & Patterns](./08_best_practices_patterns.md)**  
   Design patterns, optimization strategies, and common use cases

9. **[Migration Guide](./09_migration_guide.md)**  
   Upgrading from v1 to v2 format

10. **[Quick Reference Card](./10_quick_reference.md)**  
    One-page summary of all features

## What's New in v2

### Major Additions

1. **Recursive Pipeline Composition**
   - `type: "pipeline"` for nested pipeline execution
   - Full context management and isolation
   - Safety features and depth tracking

2. **Enhanced Claude Step Types**
   - `claude_smart` - Preset-based intelligent configuration
   - `claude_session` - Stateful conversation management
   - `claude_extract` - Advanced content extraction
   - `claude_batch` - Parallel batch processing
   - `claude_robust` - Enterprise-grade error handling

3. **Advanced Control Flow**
   - `for_loop` and `while_loop` constructs
   - Complex boolean conditions
   - Switch/case branching
   - Parallel execution patterns

4. **Data & File Operations**
   - `data_transform` - JSONPath-based transformations
   - `file_ops` - Comprehensive file manipulation
   - `codebase_query` - Intelligent code analysis

5. **Enhanced Prompt System**
   - External prompt file management
   - Template variables and composition
   - Content extraction and processing
   - Session context references

6. **Enterprise Features**
   - Authentication configuration
   - Cost monitoring and alerts
   - Performance telemetry
   - Resource limits and safety

### Backward Compatibility

All v1 features remain fully supported. The v2 format is a superset of v1, meaning existing pipelines will continue to work without modification.

## Format Version History

- **v1.0** (2024): Initial release with basic Gemini/Claude orchestration
- **v1.5** (2024): Added advanced features (loops, conditions, state)
- **v2.0** (2025): Added recursive pipelines and enhanced Claude SDK integration

## Quick Start Examples

### Basic Pipeline
```yaml
workflow:
  name: "simple_analysis"
  steps:
    - name: "analyze"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Analyze this code"
```

### Recursive Pipeline
```yaml
workflow:
  name: "modular_workflow"
  steps:
    - name: "data_processing"
      type: "pipeline"
      pipeline_file: "./pipelines/data_processor.yaml"
      inputs:
        data: "{{inputs.raw_data}}"
      outputs:
        - "processed_data"
```

### Advanced Control Flow
```yaml
workflow:
  name: "iterative_improvement"
  steps:
    - name: "improve_until_passing"
      type: "while_loop"
      condition: "{{steps.test.result.status != 'passed'}}"
      max_iterations: 5
      steps:
        - name: "fix_issues"
          type: "claude_robust"
          prompt:
            - type: "file"
              path: "./prompts/fix_issues.md"
```

## Getting Started

1. Start with the [Complete Schema Reference](./01_complete_schema_reference.md) for field definitions
2. Review [Step Types Reference](./02_step_types_reference.md) for available step types
3. Learn about [Prompt System](./03_prompt_system_reference.md) for content management
4. Explore [Control Flow](./04_control_flow_logic.md) for advanced workflows
5. Study [Best Practices](./08_best_practices_patterns.md) for optimal usage

## Support

For questions or issues with the YAML format:
- Check the [Migration Guide](./09_migration_guide.md) if upgrading
- Review [Best Practices](./08_best_practices_patterns.md) for common patterns
- Consult implementation examples in `/examples/` directory