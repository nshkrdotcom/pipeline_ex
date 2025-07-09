# Dynamic Step Registry System Prompt

## Context Recontextualization

You are working on the pipeline_ex system, an Elixir-based pipeline generator that currently has a hard-coded step execution system that needs to be enhanced with dynamic step registration capabilities.

### Current System Architecture
- **Hard-coded executor**: `lib/pipeline/executor.ex` uses case statements for step type dispatch
- **Fixed step types**: All step types are compile-time constants in enhanced_config.ex
- **Static validation**: Step validation is hard-coded in configuration modules
- **Provider system**: Basic provider selection in `lib/pipeline/providers/ai_provider.ex`

### Current Limitations
```elixir
# Current problematic pattern in executor.ex
case step["type"] do
  "claude" -> Claude.execute(step, context)
  "gemini" -> Gemini.execute(step, context)
  "claude_smart" -> ClaudeSmart.execute(step, context)
  # ... all step types must be hard-coded
end
```

### DSPy Integration Requirements
- **Dynamic step registration** - Add DSPy-specific steps without code changes
- **Runtime extensibility** - Support plugins and custom step types
- **Validation flexibility** - Custom validation rules per step type
- **Provider abstraction** - Support multiple AI providers dynamically
- **Backward compatibility** - All existing steps must continue working

## Task

Implement a dynamic step registry system that enables runtime registration of step types while maintaining backward compatibility with existing hard-coded steps.

### Required Components

1. **Step Registry** (`lib/pipeline/enhanced/step_registry.ex`)
   - GenServer-based registry for step types
   - Dynamic step registration with metadata
   - Step-specific validation function support
   - Runtime step discovery and listing

2. **Enhanced Executor** (`lib/pipeline/enhanced/executor.ex`)
   - Dynamic step type resolution
   - Fallback to legacy hard-coded steps
   - Enhanced error handling and logging
   - Performance optimization for lookups

3. **Provider Registry** (`lib/pipeline/enhanced/provider_registry.ex`)
   - Dynamic provider registration
   - Capability-based provider selection
   - Selection strategies for optimal provider choice
   - Provider health monitoring

4. **Step Behavior Definition** (`lib/pipeline/enhanced/step_behaviour.ex`)
   - Standardized step interface
   - Validation requirements
   - Metadata specification
   - Error handling patterns

5. **Compatibility Manager** (`lib/pipeline/enhanced/compatibility_manager.ex`)
   - Automatic registration of existing steps
   - Seamless transition from hard-coded system
   - Migration utilities and helpers
   - Version compatibility checks

### Implementation Requirements

- **Zero-downtime migration** - Existing pipelines must continue working
- **Performance optimization** - Registry lookups must be fast
- **Thread safety** - Support concurrent step registration/execution
- **Error resilience** - Graceful handling of registration failures
- **Comprehensive logging** - Debug and monitoring capabilities

### Step Registration Pattern

The registry must support registrations like:
```elixir
# Register new step type
Pipeline.Enhanced.StepRegistry.register_step(
  "dspy_claude",
  Pipeline.DSPy.Steps.OptimizedClaudeStep,
  validator: &validate_dspy_claude_config/1,
  metadata: %{
    description: "DSPy-optimized Claude step",
    required_fields: ["prompt", "dspy_signature"],
    optional_fields: ["optimization_config"],
    capabilities: [:optimization, :structured_output]
  }
)
```

### Provider Registration Pattern

Must support dynamic provider registration:
```elixir
# Register new provider
Pipeline.Enhanced.ProviderRegistry.register_provider(
  "dspy_claude",
  Pipeline.DSPy.Providers.OptimizedClaudeProvider,
  [:dspy_optimization, :claude_compatible, :structured_output]
)
```

### Legacy Step Integration

All existing step types must be automatically registered:
```elixir
# Existing steps from current system
[
  {"claude", Pipeline.Step.Claude},
  {"gemini", Pipeline.Step.Gemini},
  {"claude_smart", Pipeline.Step.ClaudeSmart},
  {"claude_session", Pipeline.Step.ClaudeSession},
  {"claude_extract", Pipeline.Step.ClaudeExtract},
  {"claude_batch", Pipeline.Step.ClaudeBatch},
  {"claude_robust", Pipeline.Step.ClaudeRobust},
  {"parallel_claude", Pipeline.Step.ParallelClaude},
  {"gemini_instructor", Pipeline.Step.GeminiInstructor},
  {"set_variable", Pipeline.Step.SetVariable}
]
```

### Validation Integration

Must integrate with enhanced schema validation:
```elixir
# Step-specific validation
def validate_dspy_claude_config(step_config) do
  case Pipeline.Enhanced.SchemaValidator.validate_dspy_signature(step_config) do
    {:ok, validated_config} -> {:ok, validated_config}
    {:error, reason} -> {:error, "DSPy Claude validation failed: #{reason}"}
  end
end
```

### Performance Requirements

- **Registry lookups**: < 1ms for step type resolution
- **Registration**: < 10ms for new step registration
- **Memory usage**: Minimal overhead for registry storage
- **Concurrent access**: Support multiple simultaneous registrations

### Code Style Requirements

- Follow existing Elixir patterns from the codebase
- Use GenServer for stateful registry components
- Include comprehensive documentation and type specs
- Add detailed logging for debugging and monitoring
- Structure with clear module separation

### Testing Requirements

- Test dynamic step registration and execution
- Validate backward compatibility with all existing steps
- Test concurrent registration scenarios
- Include performance benchmarks
- Add error handling and edge case tests

### Integration Points

- **Executor enhancement** - Replace hard-coded case statements
- **Configuration system** - Support dynamic step type validation
- **Plugin system** - Enable step registration via plugins
- **Monitoring** - Add metrics for step execution and registry health

### Error Handling

Must provide comprehensive error handling:
```elixir
# Step not found fallback
case Pipeline.Enhanced.StepRegistry.get_step_module(step_type) do
  {:ok, step_module} -> execute_with_module(step_module, step, context)
  {:error, :not_found} -> execute_legacy_step(step, context)
end
```

### Startup Integration

Registry must be initialized during application startup:
```elixir
# Add to application supervision tree
def start(_type, _args) do
  children = [
    Pipeline.Enhanced.StepRegistry,
    Pipeline.Enhanced.ProviderRegistry,
    Pipeline.Enhanced.CompatibilityManager,
    # ... other supervisors
  ]
  
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Implement this dynamic step registry system as a complete, production-ready solution that seamlessly integrates with the existing pipeline_ex architecture while providing the extensibility needed for DSPy integration.