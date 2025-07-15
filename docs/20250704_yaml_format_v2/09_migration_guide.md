# Migration Guide: v1 to v2

## Table of Contents

1. [Overview](#overview)
2. [What's New in v2](#whats-new-in-v2)
3. [Breaking Changes](#breaking-changes)
4. [Migration Steps](#migration-steps)
5. [Feature-by-Feature Migration](#feature-by-feature-migration)
6. [Automated Migration Tools](#automated-migration-tools)
7. [Testing Your Migration](#testing-your-migration)
8. [Rollback Strategy](#rollback-strategy)
9. [Common Issues & Solutions](#common-issues--solutions)
10. [Migration Checklist](#migration-checklist)

## Overview

This guide helps you migrate existing Pipeline YAML v1 configurations to the v2 format. While v2 maintains backward compatibility with most v1 features, taking advantage of new capabilities requires some updates to your pipelines.

### Compatibility Promise

- ✅ All v1 pipelines continue to work in v2
- ✅ No required changes for basic functionality
- ✅ Gradual migration path available
- ⚠️ Some deprecated features will be removed in v3

## What's New in v2

### Major Additions

1. **Recursive Pipeline Composition**
   ```yaml
   type: "pipeline"  # New step type
   ```

2. **Enhanced Claude Steps**
   ```yaml
   type: "claude_smart"    # Preset-based configuration
   type: "claude_session"  # Stateful conversations
   type: "claude_extract"  # Content extraction
   type: "claude_batch"    # Parallel processing
   type: "claude_robust"   # Enterprise error handling
   ```

3. **Model Selection & Cost Control**
   ```yaml
   claude_options:
     model: "sonnet"         # Cost-effective (~$0.01/query)
     model: "opus"           # High-quality (~$0.26/query)
     fallback_model: "sonnet" # Reliability fallback
   ```

4. **Advanced Control Flow**
   ```yaml
   type: "for_loop"     # Iteration
   type: "while_loop"   # Conditional loops
   type: "switch"       # Multi-branch logic
   ```

5. **Data Operations**
   ```yaml
   type: "data_transform"   # JSONPath transformations
   type: "file_ops"        # File manipulation
   type: "codebase_query"  # Code intelligence
   ```

5. **Enhanced Configuration**
   ```yaml
   claude_auth:      # Provider configuration
   environment:      # Environment-aware settings
   resource_limits:  # Safety controls
   ```

## Breaking Changes

### 1. Deprecated Features

The following v1 features are deprecated (but still functional):

```yaml
# v1: Simple error handling
on_error: "continue"

# v2: Use explicit configuration
continue_on_error: true
error_handler:
  - name: "handle_error"
    type: "pipeline"
    pipeline_file: "./error_handler.yaml"
```

### 2. Changed Defaults

Some defaults have changed for better safety:

| Setting | v1 Default | v2 Default |
|---------|-----------|-----------|
| `checkpoint_enabled` | `false` | `true` in production |
| `max_nesting_depth` | unlimited | `10` |
| `sandbox_mode` | `false` | `true` in production |

### 3. Renamed Fields

For consistency, some fields have been renamed:

```yaml
# v1
max_attempts: 3

# v2
max_retries: 3
```

## Migration Steps

### Step 1: Audit Your Pipelines

First, inventory your existing pipelines:

```bash
# Find all v1 pipeline files
find . -name "*.yaml" -type f | xargs grep -l "workflow:"

# Check for deprecated features
grep -r "on_error:" .
grep -r "max_attempts:" .
```

### Step 2: Update Configuration

Add v2 configuration sections:

```yaml
workflow:
  name: "my_pipeline"
  
  # Add v2 configuration
  environment:
    mode: "production"
    debug_level: "basic"
  
  claude_auth:
    auto_check: true
    provider: "anthropic"
  
  resource_limits:
    max_total_steps: 1000
    max_memory_mb: 4096
```

### Step 3: Enhance Step Types

Upgrade to enhanced step types where beneficial:

```yaml
# v1: Basic Claude step
- name: "implement"
  type: "claude"
  claude_options:
    max_turns: 20

# v2: Enhanced Claude step
- name: "implement"
  type: "claude_smart"
  preset: "development"
  claude_options:
    max_turns: 20  # Override preset default
```

### Step 4: Modularize Complex Pipelines

Break down monolithic pipelines:

```yaml
# v1: Single large pipeline
workflow:
  name: "do_everything"
  steps:
    # 50+ steps...

# v2: Composed pipeline
workflow:
  name: "main_workflow"
  steps:
    - name: "data_prep"
      type: "pipeline"
      pipeline_file: "./components/data_prep.yaml"
    
    - name: "analysis"
      type: "pipeline"
      pipeline_file: "./components/analysis.yaml"
```

## Feature-by-Feature Migration

### Migrating to Enhanced Claude Steps

#### Claude Smart

Use for simplified configuration:

```yaml
# v1
- name: "analyze"
  type: "claude"
  claude_options:
    max_turns: 3
    allowed_tools: ["Read"]
    output_format: "json"
    verbose: false

# v2
- name: "analyze"
  type: "claude_smart"
  preset: "analysis"  # Automatically configures for analysis
```

#### Claude Session

Use for multi-turn conversations:

```yaml
# v1: Manual session management
- name: "step1"
  type: "claude"
  claude_options:
    session_id: "manual_session"
    
- name: "step2"
  type: "claude"
  claude_options:
    session_id: "manual_session"
    resume_session: true

# v2: Explicit session management
- name: "conversation"
  type: "claude_session"
  session_config:
    session_name: "feature_development"
    persist: true
    checkpoint_frequency: 5
```

#### Claude Extract

Use for structured extraction:

```yaml
# v1: Manual extraction
- name: "analyze"
  type: "claude"
  prompt:
    - type: "static"
      content: "Extract key points and code blocks"

# v2: Automated extraction
- name: "analyze"
  type: "claude_extract"
  extraction_config:
    format: "structured"
    post_processing:
      - "extract_code_blocks"
      - "extract_key_points"
```

### Migrating to Loop Constructs

Replace repetitive steps with loops:

```yaml
# v1: Repetitive steps
- name: "process_file1"
  type: "claude"
  prompt:
    - type: "file"
      path: "file1.py"
      
- name: "process_file2"
  type: "claude"
  prompt:
    - type: "file"
      path: "file2.py"

# v2: Loop construct
- name: "process_files"
  type: "for_loop"
  iterator: "file"
  data_source: ["file1.py", "file2.py", "file3.py"]
  steps:
    - name: "process"
      type: "claude"
      prompt:
        - type: "file"
          path: "{{loop.file}}"
```

### Migrating to Pipeline Composition

Extract reusable components:

```yaml
# v1: Inline validation
steps:
  - name: "validate"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Validate data..."
  # More steps...

# v2: Extracted component
steps:
  - name: "validate"
    type: "pipeline"
    pipeline_file: "./components/validator.yaml"
    inputs:
      data: "{{inputs.data}}"
      schema: "{{inputs.schema}}"
```

### Migrating Error Handling

Improve error handling:

```yaml
# v1: Basic error handling
- name: "risky_step"
  type: "claude"
  on_error: "continue"

# v2: Comprehensive error handling
- name: "risky_step"
  type: "claude_robust"
  retry_config:
    max_retries: 3
    backoff_strategy: "exponential"
    fallback_action: "simplified_prompt"
  continue_on_error: true
  error_handler:
    - name: "log_error"
      type: "set_variable"
      variables:
        last_error: "{{error}}"
```

## Automated Migration Tools

### Migration Script

Use this script to automatically update common patterns:

```python
#!/usr/bin/env python3
# migrate_v1_to_v2.py

import yaml
import sys
from pathlib import Path

def migrate_pipeline(file_path):
    """Migrate a v1 pipeline to v2 format."""
    with open(file_path, 'r') as f:
        config = yaml.safe_load(f)
    
    if 'workflow' not in config:
        return None
    
    workflow = config['workflow']
    
    # Add v2 sections if missing
    if 'environment' not in workflow:
        workflow['environment'] = {
            'mode': 'production',
            'debug_level': 'basic'
        }
    
    if 'claude_auth' not in workflow:
        workflow['claude_auth'] = {
            'auto_check': True,
            'provider': 'anthropic'
        }
    
    # Update deprecated fields
    for step in workflow.get('steps', []):
        # Update max_attempts to max_retries
        if 'max_attempts' in step:
            step['max_retries'] = step.pop('max_attempts')
        
        # Convert on_error to continue_on_error
        if step.get('on_error') == 'continue':
            step.pop('on_error')
            step['continue_on_error'] = True
    
    return config

def main():
    for file_path in Path('.').glob('**/*.yaml'):
        try:
            migrated = migrate_pipeline(file_path)
            if migrated:
                # Create backup
                backup_path = file_path.with_suffix('.yaml.v1.bak')
                file_path.rename(backup_path)
                
                # Write migrated version
                with open(file_path, 'w') as f:
                    yaml.dump(migrated, f, default_flow_style=False)
                
                print(f"✓ Migrated: {file_path}")
        except Exception as e:
            print(f"✗ Error migrating {file_path}: {e}")

if __name__ == '__main__':
    main()
```

### Validation Tool

Validate migrated pipelines:

```bash
# Validate syntax
mix pipeline.validate my_pipeline.yaml

# Dry run to check execution
mix pipeline.run my_pipeline.yaml --dry-run

# Check v2 feature usage
mix pipeline.analyze my_pipeline.yaml --check-v2-features
```

## Testing Your Migration

### 1. Unit Test Individual Pipelines

```yaml
# test_migrated_pipeline.yaml
workflow:
  name: "test_migration"
  environment:
    mode: "test"
    force_mock_providers: true
  
  steps:
    - name: "test_component"
      type: "pipeline"
      pipeline_file: "./migrated_component.yaml"
      inputs:
        test_data: "{{test.input}}"
      expected_outputs:
        status: "success"
        result_count: 10
```

### 2. Integration Test Workflows

```bash
# Run with test data
TEST_MODE=mock mix pipeline.run migrated_workflow.yaml \
  --inputs test_inputs.yaml \
  --validate-outputs
```

### 3. Performance Comparison

Compare v1 and v2 performance:

```bash
# Benchmark v1
time mix pipeline.run v1_pipeline.yaml

# Benchmark v2
time mix pipeline.run v2_pipeline.yaml

# Compare outputs
diff -u v1_output.json v2_output.json
```

## Rollback Strategy

### Maintain Backward Compatibility

Keep v1 backups during migration:

```bash
# Before migration
cp my_pipeline.yaml my_pipeline.v1.yaml

# After migration, if issues arise
mv my_pipeline.v1.yaml my_pipeline.yaml
```

### Gradual Migration

Migrate incrementally:

```yaml
workflow:
  name: "hybrid_pipeline"
  
  steps:
    # Keep v1 steps that work well
    - name: "existing_step"
      type: "claude"
      # v1 configuration
    
    # Add v2 features gradually
    - name: "new_feature"
      type: "claude_smart"
      preset: "analysis"
```

## Common Issues & Solutions

### Issue 1: Nested Pipeline Path Resolution

**Problem**: Pipeline files not found after reorganization

**Solution**:
```yaml
# Use relative paths from project root
pipeline_file: "./pipelines/components/validator.yaml"

# Or use absolute paths
pipeline_file: "${PROJECT_ROOT}/pipelines/components/validator.yaml"
```

### Issue 2: Session State Loss

**Problem**: Claude sessions not persisting

**Solution**:
```yaml
- name: "session_step"
  type: "claude_session"
  session_config:
    persist: true  # Ensure persistence is enabled
    checkpoint_dir: "./sessions"  # Specify directory
```

### Issue 3: Loop Variable Access

**Problem**: Can't access loop variables in v2

**Solution**:
```yaml
# v1: Direct variable access
"{{file}}"

# v2: Loop namespace
"{{loop.file}}"
"{{loop.index}}"
"{{loop.parent.variable}}"  # For nested loops
```

### Issue 4: Resource Limits

**Problem**: Pipeline fails with resource limit errors

**Solution**:
```yaml
workflow:
  resource_limits:
    max_total_steps: 2000      # Increase from default
    max_memory_mb: 8192        # Increase memory limit
    max_nesting_depth: 15      # Allow deeper nesting
```

## Migration Checklist

### Pre-Migration

- [ ] Backup all pipeline files
- [ ] Document current pipeline behavior
- [ ] Identify deprecated features in use
- [ ] Plan migration phases
- [ ] Set up test environment

### During Migration

- [ ] Update workflow configuration sections
- [ ] Migrate to enhanced step types where beneficial
- [ ] Extract reusable components
- [ ] Update error handling patterns
- [ ] Add resource limits and safety features
- [ ] Update path references
- [ ] Test each migrated component

### Post-Migration

- [ ] Run comprehensive tests
- [ ] Compare outputs with v1
- [ ] Update documentation
- [ ] Train team on new features
- [ ] Monitor performance
- [ ] Remove v1 backups after verification

### Optimization Opportunities

After basic migration, consider:

- [ ] Convert repetitive steps to loops
- [ ] Use pipeline composition for modularity
- [ ] Implement parallel processing where applicable
- [ ] Add structured output validation
- [ ] Enhance error handling with retries
- [ ] Add telemetry and monitoring

## Next Steps

1. **Start Small**: Migrate one simple pipeline first
2. **Test Thoroughly**: Ensure behavior matches v1
3. **Iterate**: Gradually adopt v2 features
4. **Document**: Update your pipeline documentation
5. **Share**: Help team members understand changes

### Resources

- [Complete Schema Reference](./01_complete_schema_reference.md)
- [Step Types Reference](./02_step_types_reference.md)
- [Best Practices Guide](./08_best_practices_patterns.md)
- [Pipeline Examples](../examples/)

This migration guide helps you smoothly transition from Pipeline YAML v1 to v2, taking advantage of new features while maintaining compatibility.