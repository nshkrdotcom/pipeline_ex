# Backward Compatibility Layer Prompt

## Context Recontextualization

You are working on the pipeline_ex system, an Elixir-based pipeline generator that is being enhanced with new infrastructure components (dynamic registries, enhanced validation, plugin architecture) while maintaining full backward compatibility.

### Current System Components
- **Existing executor**: `lib/pipeline/executor.ex` with hard-coded step dispatch
- **Legacy configuration**: `lib/pipeline/config.ex` and `lib/pipeline/enhanced_config.ex`
- **Static step types**: All step types are compile-time constants
- **Fixed providers**: Static provider selection in `lib/pipeline/providers/ai_provider.ex`
- **Basic validation**: Current schema validation in `lib/pipeline/validation/schema_validator.ex`

### New Enhanced Components (Being Implemented)
- **Dynamic step registry** - Runtime step type registration
- **Enhanced schema validator** - DSPy support and type preservation
- **JSON/YAML bridge** - Type-preserving format conversion
- **Plugin architecture** - Dynamic component loading
- **Enhanced configuration system** - Runtime schema extension

### Backward Compatibility Requirements
- **Zero-breaking changes** - All existing pipelines must continue working
- **Seamless transition** - New features should be opt-in
- **Migration path** - Clear upgrade path for existing configurations
- **Performance preservation** - No performance degradation for existing workflows

## Task

Implement a comprehensive backward compatibility layer that ensures all existing pipeline_ex functionality continues to work unchanged while enabling seamless adoption of new enhanced features.

### Required Components

1. **Compatibility Manager** (`lib/pipeline/enhanced/compatibility_manager.ex`)
   - Automatic registration of legacy components
   - Seamless bridging between old and new systems
   - Migration utilities and helpers
   - Compatibility validation and testing

2. **Legacy Step Registration** (`lib/pipeline/enhanced/legacy_step_registration.ex`)
   - Automatic registration of all existing step types
   - Backward-compatible step execution
   - Legacy validation preservation
   - Metadata generation for existing steps

3. **Legacy Provider Registration** (`lib/pipeline/enhanced/legacy_provider_registration.ex`)
   - Automatic registration of existing providers
   - Provider capability mapping
   - Legacy provider selection logic
   - Compatibility with existing test modes

4. **Configuration Compatibility** (`lib/pipeline/enhanced/configuration_compatibility.ex`)
   - Legacy configuration format support
   - Automatic schema extension for compatibility
   - Validation rule migration
   - Configuration format bridging

5. **Execution Flow Compatibility** (`lib/pipeline/enhanced/execution_flow_compatibility.ex`)
   - Seamless integration between legacy and enhanced execution
   - Fallback mechanisms for unsupported features
   - Context format preservation
   - Result format compatibility

### Implementation Requirements

- **Transparent operation** - Users should not notice any changes
- **Performance optimization** - No performance impact on existing workflows
- **Error preservation** - Maintain existing error handling behavior
- **Feature parity** - All existing functionality must work identically
- **Testing integration** - Maintain all existing test compatibility

### Legacy Step Registration Pattern

Must automatically register all existing step types:
```elixir
defmodule Pipeline.Enhanced.LegacyStepRegistration do
  def register_all_legacy_steps do
    legacy_steps = [
      {"claude", Pipeline.Step.Claude},
      {"gemini", Pipeline.Step.Gemini},
      {"claude_smart", Pipeline.Step.ClaudeSmart},
      {"claude_session", Pipeline.Step.ClaudeSession},
      {"claude_extract", Pipeline.Step.ClaudeExtract},
      {"claude_batch", Pipeline.Step.ClaudeBatch},
      {"claude_robust", Pipeline.Step.ClaudeRobust},
      {"parallel_claude", Pipeline.Step.ParallelClaude},
      {"gemini_instructor", Pipeline.Step.GeminiInstructor},
      {"set_variable", Pipeline.Step.SetVariable},
      {"data_transform", Pipeline.Step.DataTransform},
      {"file_ops", Pipeline.Step.FileOps},
      {"pipeline", Pipeline.Step.NestedPipeline}
    ]
    
    Enum.each(legacy_steps, fn {step_type, module} ->
      Pipeline.Enhanced.StepRegistry.register_step(
        step_type,
        module,
        validator: &validate_legacy_step/1,
        metadata: %{
          legacy: true,
          description: "Legacy #{step_type} step",
          migrated_from: "hard_coded_executor"
        }
      )
    end)
  end
end
```

### Legacy Provider Registration

Must register existing providers with capabilities:
```elixir
defmodule Pipeline.Enhanced.LegacyProviderRegistration do
  def register_all_legacy_providers do
    legacy_providers = [
      {"claude", Pipeline.Providers.ClaudeProvider, [:claude_compatible, :text_generation]},
      {"enhanced_claude", Pipeline.Providers.EnhancedClaudeProvider, [:claude_compatible, :enhanced_features]},
      {"gemini", Pipeline.Providers.GeminiProvider, [:gemini_compatible, :multimodal]},
      {"mock_claude", Pipeline.Test.Mocks.ClaudeProvider, [:claude_compatible, :testing]}
    ]
    
    Enum.each(legacy_providers, fn {name, module, capabilities} ->
      Pipeline.Enhanced.ProviderRegistry.register_provider(
        name,
        module,
        capabilities,
        metadata: %{legacy: true}
      )
    end)
  end
end
```

### Configuration Compatibility

Must support existing configuration formats:
```elixir
defmodule Pipeline.Enhanced.ConfigurationCompatibility do
  def ensure_legacy_configuration_support do
    # Register legacy configuration schema
    Pipeline.Enhanced.ConfigurationSystem.register_schema_extension(
      "legacy_compatibility",
      get_legacy_compatibility_schema()
    )
    
    # Set up legacy configuration loader
    Pipeline.Enhanced.ConfigurationManager.register_loader(
      "legacy_yaml",
      &load_legacy_yaml_config/1
    )
  end
  
  def load_legacy_yaml_config(file_path) do
    # Use existing config loading logic
    case Pipeline.Config.load_config(file_path) do
      {:ok, config} ->
        # Convert to enhanced format if needed
        {:ok, convert_legacy_config(config)}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Execution Flow Compatibility

Must provide seamless execution compatibility:
```elixir
defmodule Pipeline.Enhanced.ExecutionFlowCompatibility do
  def execute_with_compatibility(step, context) do
    # Try enhanced execution first
    case Pipeline.Enhanced.Executor.execute_step(step, context) do
      {:ok, result} ->
        {:ok, result}
      
      {:error, :step_not_found} ->
        # Fallback to legacy execution
        execute_legacy_step(step, context)
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp execute_legacy_step(step, context) do
    # Use original executor logic
    Pipeline.Executor.do_execute_step(step, context)
  end
end
```

### Migration Utilities

Must provide migration utilities:
```elixir
defmodule Pipeline.Enhanced.MigrationUtilities do
  def migrate_configuration_to_enhanced(legacy_config) do
    # Convert legacy configuration to enhanced format
    enhanced_config = %{
      "workflow" => legacy_config["workflow"],
      "metadata" => %{
        "migrated_from" => "legacy_format",
        "migration_timestamp" => DateTime.utc_now()
      }
    }
    
    {:ok, enhanced_config}
  end
  
  def analyze_compatibility(config_path) do
    # Analyze configuration for compatibility issues
    case Pipeline.Config.load_config(config_path) do
      {:ok, config} ->
        issues = check_compatibility_issues(config)
        recommendations = generate_migration_recommendations(issues)
        
        %{
          compatible: Enum.empty?(issues),
          issues: issues,
          recommendations: recommendations
        }
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Test Mode Compatibility

Must maintain test mode compatibility:
```elixir
defmodule Pipeline.Enhanced.TestModeCompatibility do
  def ensure_test_mode_compatibility do
    # Register test mode providers
    register_test_providers()
    
    # Set up test mode configuration
    setup_test_mode_config()
    
    # Ensure test mode execution paths
    setup_test_execution_paths()
  end
  
  defp register_test_providers do
    # Register mock providers with enhanced registry
    Pipeline.Enhanced.ProviderRegistry.register_provider(
      "mock_claude",
      Pipeline.Test.Mocks.ClaudeProvider,
      [:claude_compatible, :testing, :mock]
    )
  end
end
```

### Performance Preservation

Must ensure no performance degradation:
```elixir
defmodule Pipeline.Enhanced.PerformancePreservation do
  def optimize_for_legacy_performance do
    # Pre-warm registries with legacy components
    Pipeline.Enhanced.StepRegistry.warm_cache()
    
    # Optimize legacy execution paths
    optimize_legacy_execution_paths()
    
    # Set up performance monitoring
    setup_performance_monitoring()
  end
  
  defp optimize_legacy_execution_paths do
    # Ensure legacy steps have fast lookup paths
    legacy_steps = get_legacy_step_types()
    
    Enum.each(legacy_steps, fn step_type ->
      Pipeline.Enhanced.StepRegistry.preload_step(step_type)
    end)
  end
end
```

### Error Handling Compatibility

Must maintain existing error handling:
```elixir
defmodule Pipeline.Enhanced.ErrorHandlingCompatibility do
  def ensure_error_compatibility do
    # Maintain existing error formats
    setup_error_format_compatibility()
    
    # Preserve error handling behavior
    setup_error_handling_compatibility()
  end
  
  def format_error_for_compatibility(error) do
    # Convert enhanced error format to legacy format if needed
    case error do
      {:error, %{type: :validation_error, details: details}} ->
        {:error, "Validation failed: #{details}"}
      
      {:error, %{type: :step_not_found, step_type: step_type}} ->
        {:error, "Unknown step type: #{step_type}"}
      
      other ->
        other
    end
  end
end
```

### Startup Integration

Must integrate with application startup:
```elixir
defmodule Pipeline.Enhanced.CompatibilityManager do
  def ensure_backward_compatibility do
    # Register all legacy components
    Pipeline.Enhanced.LegacyStepRegistration.register_all_legacy_steps()
    Pipeline.Enhanced.LegacyProviderRegistration.register_all_legacy_providers()
    
    # Set up configuration compatibility
    Pipeline.Enhanced.ConfigurationCompatibility.ensure_legacy_configuration_support()
    
    # Ensure test mode compatibility
    Pipeline.Enhanced.TestModeCompatibility.ensure_test_mode_compatibility()
    
    # Optimize for legacy performance
    Pipeline.Enhanced.PerformancePreservation.optimize_for_legacy_performance()
    
    # Set up error handling compatibility
    Pipeline.Enhanced.ErrorHandlingCompatibility.ensure_error_compatibility()
    
    Logger.info("Backward compatibility layer initialized successfully")
  end
end
```

### Validation and Testing

Must include comprehensive validation:
```elixir
defmodule Pipeline.Enhanced.CompatibilityValidator do
  def validate_compatibility do
    # Test all legacy step types
    test_legacy_step_execution()
    
    # Test legacy configuration loading
    test_legacy_configuration()
    
    # Test legacy provider functionality
    test_legacy_providers()
    
    # Test performance compatibility
    test_performance_compatibility()
  end
  
  defp test_legacy_step_execution do
    legacy_steps = get_all_legacy_step_types()
    
    Enum.each(legacy_steps, fn step_type ->
      case test_step_execution(step_type) do
        :ok ->
          Logger.info("Legacy step #{step_type} compatible")
        
        {:error, reason} ->
          Logger.error("Legacy step #{step_type} compatibility issue: #{reason}")
      end
    end)
  end
end
```

### Documentation and Migration Guide

Must provide clear migration guidance:
```elixir
defmodule Pipeline.Enhanced.MigrationGuide do
  def generate_migration_report(config_path) do
    analysis = Pipeline.Enhanced.MigrationUtilities.analyze_compatibility(config_path)
    
    report = %{
      summary: generate_summary(analysis),
      compatibility_status: analysis.compatible,
      issues: analysis.issues,
      recommendations: analysis.recommendations,
      migration_steps: generate_migration_steps(analysis)
    }
    
    {:ok, report}
  end
end
```

Implement this backward compatibility layer as a complete, production-ready solution that ensures zero-breaking changes while providing a smooth transition path to enhanced features.