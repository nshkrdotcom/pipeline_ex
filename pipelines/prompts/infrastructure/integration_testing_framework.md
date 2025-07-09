# Integration Testing Framework Prompt

## Context Recontextualization

You are working on the pipeline_ex system, an Elixir-based pipeline generator that is being enhanced with new infrastructure components and needs a comprehensive integration testing framework to ensure all components work together seamlessly.

### New Enhanced Components Being Implemented
- **Dynamic step registry** - Runtime step type registration
- **Enhanced schema validator** - DSPy support and type preservation
- **JSON/YAML bridge** - Type-preserving format conversion
- **Plugin architecture** - Dynamic component loading
- **Enhanced configuration system** - Runtime schema extension
- **Backward compatibility layer** - Legacy component preservation

### Current Testing Architecture
- **Basic unit tests** - Individual module testing
- **Mock system** - `Pipeline.Test.Mocks.ClaudeProvider` for testing
- **Test mode** - Application-level test mode configuration
- **Limited integration** - No comprehensive integration testing

### Integration Testing Requirements
- **End-to-end testing** - Full pipeline execution with all components
- **Component interaction testing** - Verify all components work together
- **Performance testing** - Ensure no performance degradation
- **Backward compatibility testing** - Validate legacy functionality
- **Plugin integration testing** - Test plugin loading and execution

## Task

Implement a comprehensive integration testing framework that validates the entire enhanced pipeline_ex system works correctly with all components integrated.

### Required Components

1. **Integration Test Framework** (`test/integration/integration_test_framework.ex`)
   - Comprehensive test orchestration
   - Component interaction validation
   - End-to-end pipeline execution testing
   - Performance monitoring and validation

2. **Component Integration Tests** (`test/integration/component_integration_test.ex`)
   - Registry system integration testing
   - Schema validation integration testing
   - Configuration system integration testing
   - Plugin system integration testing

3. **Backward Compatibility Tests** (`test/integration/backward_compatibility_test.ex`)
   - Legacy pipeline execution validation
   - Existing configuration format testing
   - Performance regression testing
   - Error handling compatibility testing

4. **DSPy Integration Tests** (`test/integration/dspy_integration_test.ex`)
   - DSPy signature validation testing
   - Type preservation testing
   - Structured output validation testing
   - Optimization workflow testing

5. **Performance Integration Tests** (`test/integration/performance_integration_test.ex`)
   - Load testing with multiple components
   - Memory usage validation
   - Execution time benchmarking
   - Resource utilization monitoring

### Implementation Requirements

- **Comprehensive coverage** - Test all component interactions
- **Realistic scenarios** - Use real-world pipeline configurations
- **Performance validation** - Ensure no performance degradation
- **Error simulation** - Test error handling across components
- **Isolation** - Tests should not interfere with each other

### Integration Test Framework Structure

```elixir
defmodule Pipeline.Integration.TestFramework do
  @moduledoc """
  Comprehensive integration testing framework for pipeline_ex enhanced components.
  """
  
  def run_full_integration_suite do
    # Initialize test environment
    setup_test_environment()
    
    # Run component integration tests
    run_component_integration_tests()
    
    # Run backward compatibility tests
    run_backward_compatibility_tests()
    
    # Run DSPy integration tests
    run_dspy_integration_tests()
    
    # Run performance integration tests
    run_performance_integration_tests()
    
    # Generate comprehensive report
    generate_integration_report()
  end
  
  defp setup_test_environment do
    # Initialize all enhanced components
    {:ok, _} = Pipeline.Enhanced.StepRegistry.start_link([])
    {:ok, _} = Pipeline.Enhanced.ProviderRegistry.start_link([])
    {:ok, _} = Pipeline.Enhanced.ConfigurationSystem.start_link([])
    {:ok, _} = Pipeline.Enhanced.PluginManager.start_link([])
    
    # Ensure backward compatibility
    Pipeline.Enhanced.CompatibilityManager.ensure_backward_compatibility()
    
    # Set up test data
    create_test_configurations()
    create_test_plugins()
  end
end
```

### Component Integration Tests

Must test all component interactions:
```elixir
defmodule Pipeline.Integration.ComponentIntegrationTest do
  use ExUnit.Case
  
  describe "Registry Integration" do
    test "step registry integrates with configuration system" do
      # Register a custom step type
      Pipeline.Enhanced.StepRegistry.register_step(
        "test_step",
        Pipeline.Test.TestStep,
        validator: &validate_test_step/1
      )
      
      # Create configuration using the step
      config = create_test_config_with_step("test_step")
      
      # Validate configuration recognizes the step
      assert {:ok, validated_config} = Pipeline.Enhanced.ConfigurationSystem.validate_config(config)
      
      # Execute pipeline with the step
      assert {:ok, result} = Pipeline.Enhanced.Executor.execute_pipeline(validated_config)
      
      # Verify step was executed correctly
      assert result["test_step"]["success"] == true
    end
    
    test "provider registry integrates with step execution" do
      # Register a custom provider
      Pipeline.Enhanced.ProviderRegistry.register_provider(
        "test_provider",
        Pipeline.Test.TestProvider,
        [:test_capability]
      )
      
      # Create step that uses the provider
      step = %{
        "name" => "test_step",
        "type" => "claude",
        "provider" => "test_provider"
      }
      
      # Execute step with custom provider
      context = create_test_context()
      assert {:ok, result} = Pipeline.Enhanced.Executor.execute_step(step, context)
      
      # Verify provider was used
      assert result["provider_used"] == "test_provider"
    end
  end
  
  describe "Schema Validation Integration" do
    test "enhanced validator integrates with configuration system" do
      # Create configuration with DSPy extensions
      config = create_dspy_test_config()
      
      # Validate with DSPy extensions
      assert {:ok, validated_config} = Pipeline.Enhanced.ConfigurationSystem.validate_config(
        config,
        ["dspy"]
      )
      
      # Verify DSPy-specific validation was applied
      assert validated_config["workflow"]["dspy_config"]["optimization_enabled"] == true
    end
  end
  
  describe "Plugin System Integration" do
    test "plugin loading integrates with all registries" do
      # Load test plugin
      plugin_config = create_test_plugin_config()
      
      assert {:ok, plugin_state} = Pipeline.Enhanced.PluginManager.load_plugin(
        "test_plugin",
        Pipeline.Test.TestPlugin,
        plugin_config
      )
      
      # Verify plugin components were registered
      assert {:ok, _} = Pipeline.Enhanced.StepRegistry.get_step_module("plugin_step")
      assert {:ok, _} = Pipeline.Enhanced.ProviderRegistry.get_provider("plugin_provider")
      
      # Verify plugin schema extensions were registered
      assert {:ok, schema} = Pipeline.Enhanced.ConfigurationSystem.get_compiled_schema(["plugin_extension"])
      assert schema["properties"]["plugin_config"] != nil
    end
  end
end
```

### Backward Compatibility Tests

Must ensure legacy functionality works:
```elixir
defmodule Pipeline.Integration.BackwardCompatibilityTest do
  use ExUnit.Case
  
  describe "Legacy Pipeline Execution" do
    test "existing pipelines execute without modification" do
      # Load existing pipeline configuration
      {:ok, legacy_config} = Pipeline.Config.load_config("test/fixtures/legacy_pipeline.yaml")
      
      # Execute with enhanced system
      assert {:ok, result} = Pipeline.Enhanced.Executor.execute_pipeline(legacy_config)
      
      # Verify results match legacy behavior
      assert result["claude_step"]["success"] == true
      assert result["gemini_step"]["success"] == true
    end
    
    test "legacy step types work with enhanced executor" do
      legacy_step_types = [
        "claude", "gemini", "claude_smart", "claude_session",
        "claude_extract", "claude_batch", "claude_robust",
        "parallel_claude", "gemini_instructor", "set_variable"
      ]
      
      Enum.each(legacy_step_types, fn step_type ->
        step = create_legacy_step(step_type)
        context = create_test_context()
        
        assert {:ok, result} = Pipeline.Enhanced.Executor.execute_step(step, context)
        assert result["success"] == true
      end)
    end
    
    test "legacy configurations load correctly" do
      legacy_configs = [
        "test/fixtures/claude_pipeline.yaml",
        "test/fixtures/gemini_pipeline.yaml",
        "test/fixtures/mixed_pipeline.yaml"
      ]
      
      Enum.each(legacy_configs, fn config_path ->
        assert {:ok, config} = Pipeline.Enhanced.ConfigurationManager.load_config(config_path)
        assert config["workflow"]["name"] != nil
        assert length(config["workflow"]["steps"]) > 0
      end)
    end
  end
  
  describe "Performance Regression Tests" do
    test "enhanced system performance matches legacy system" do
      # Load test pipeline
      {:ok, config} = Pipeline.Config.load_config("test/fixtures/performance_test_pipeline.yaml")
      
      # Measure legacy execution time
      {legacy_time, {:ok, legacy_result}} = :timer.tc(fn ->
        Pipeline.Executor.execute_pipeline(config)
      end)
      
      # Measure enhanced execution time
      {enhanced_time, {:ok, enhanced_result}} = :timer.tc(fn ->
        Pipeline.Enhanced.Executor.execute_pipeline(config)
      end)
      
      # Verify performance is not significantly degraded (within 20%)
      assert enhanced_time <= legacy_time * 1.2
      
      # Verify results are equivalent
      assert normalize_result(enhanced_result) == normalize_result(legacy_result)
    end
  end
end
```

### DSPy Integration Tests

Must test DSPy-specific functionality:
```elixir
defmodule Pipeline.Integration.DSPyIntegrationTest do
  use ExUnit.Case
  
  describe "DSPy Pipeline Execution" do
    test "DSPy signature validation works end-to-end" do
      # Create DSPy-enhanced pipeline
      dspy_config = create_dspy_pipeline_config()
      
      # Load plugin if needed
      Pipeline.Enhanced.PluginManager.load_plugin(
        "dspy_plugin",
        Pipeline.Plugins.DSPyPlugin,
        %{"optimization_enabled" => true}
      )
      
      # Validate configuration with DSPy extensions
      assert {:ok, validated_config} = Pipeline.Enhanced.ConfigurationSystem.validate_config(
        dspy_config,
        ["dspy"]
      )
      
      # Execute pipeline
      assert {:ok, result} = Pipeline.Enhanced.Executor.execute_pipeline(validated_config)
      
      # Verify DSPy-specific results
      assert result["dspy_claude_step"]["dspy_optimization_applied"] == true
      assert result["dspy_claude_step"]["signature_validated"] == true
    end
    
    test "type preservation works with DSPy signatures" do
      # Create DSPy signature with specific types
      signature = create_typed_dspy_signature()
      
      # Convert through JSON/YAML bridge
      {:ok, json_signature} = Pipeline.Bridge.DSPySupport.convert_dspy_signature(signature)
      
      # Verify types are preserved
      assert json_signature["input_fields"][0]["type"] == "string"
      assert json_signature["output_fields"][0]["schema"]["properties"]["score"]["type"] == "number"
    end
  end
  
  describe "Structured Output Validation" do
    test "DSPy structured outputs are validated correctly" do
      # Create DSPy signature
      signature = create_analysis_dspy_signature()
      
      # Create mock structured output
      structured_output = %{
        "analysis" => %{
          "issues" => ["Issue 1", "Issue 2"],
          "score" => 85
        }
      }
      
      # Validate against signature
      assert {:ok, validated_output} = Pipeline.DSPy.OutputValidator.validate_structured_output(
        structured_output,
        signature
      )
      
      # Verify validation results
      assert validated_output["analysis"]["score"] == 85
      assert length(validated_output["analysis"]["issues"]) == 2
    end
  end
end
```

### Performance Integration Tests

Must validate system performance:
```elixir
defmodule Pipeline.Integration.PerformanceIntegrationTest do
  use ExUnit.Case
  
  describe "Load Testing" do
    test "system handles concurrent pipeline execution" do
      # Create multiple pipeline configurations
      configs = create_concurrent_test_configs(10)
      
      # Execute pipelines concurrently
      tasks = Enum.map(configs, fn config ->
        Task.async(fn ->
          Pipeline.Enhanced.Executor.execute_pipeline(config)
        end)
      end)
      
      # Wait for all tasks to complete
      results = Task.await_many(tasks, 30_000)
      
      # Verify all executions succeeded
      Enum.each(results, fn result ->
        assert {:ok, _} = result
      end)
    end
    
    test "memory usage remains stable under load" do
      # Measure initial memory usage
      initial_memory = :erlang.memory(:total)
      
      # Execute multiple pipelines
      Enum.each(1..50, fn _ ->
        config = create_test_config()
        {:ok, _} = Pipeline.Enhanced.Executor.execute_pipeline(config)
      end)
      
      # Force garbage collection
      :erlang.garbage_collect()
      
      # Measure final memory usage
      final_memory = :erlang.memory(:total)
      
      # Verify memory usage hasn't grown excessively (within 50%)
      assert final_memory <= initial_memory * 1.5
    end
  end
  
  describe "Registry Performance" do
    test "step registry lookups remain fast under load" do
      # Register many step types
      Enum.each(1..1000, fn i ->
        Pipeline.Enhanced.StepRegistry.register_step(
          "test_step_#{i}",
          Pipeline.Test.TestStep,
          metadata: %{test_id: i}
        )
      end)
      
      # Measure lookup performance
      {lookup_time, {:ok, _}} = :timer.tc(fn ->
        Pipeline.Enhanced.StepRegistry.get_step_module("test_step_500")
      end)
      
      # Verify lookup is fast (< 1ms)
      assert lookup_time < 1_000
    end
  end
end
```

### Test Utilities and Fixtures

Must provide comprehensive test utilities:
```elixir
defmodule Pipeline.Integration.TestUtilities do
  def create_test_config do
    %{
      "workflow" => %{
        "name" => "integration_test_pipeline",
        "steps" => [
          %{
            "name" => "test_step",
            "type" => "claude",
            "prompt" => "Test prompt"
          }
        ]
      }
    }
  end
  
  def create_dspy_pipeline_config do
    %{
      "workflow" => %{
        "name" => "dspy_test_pipeline",
        "dspy_config" => %{
          "optimization_enabled" => true,
          "evaluation_mode" => "bootstrap_few_shot"
        },
        "steps" => [
          %{
            "name" => "dspy_analysis",
            "type" => "dspy_claude",
            "dspy_signature" => create_test_dspy_signature()
          }
        ]
      }
    }
  end
  
  def create_test_dspy_signature do
    %{
      "input_fields" => [
        %{
          "name" => "code",
          "type" => "string",
          "description" => "Source code to analyze"
        }
      ],
      "output_fields" => [
        %{
          "name" => "analysis",
          "type" => "object",
          "description" => "Analysis results",
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "issues" => %{"type" => "array", "items" => %{"type" => "string"}},
              "score" => %{"type" => "number", "minimum" => 0, "maximum" => 100}
            }
          }
        }
      ]
    }
  end
end
```

### Test Reporting and Monitoring

Must provide comprehensive test reporting:
```elixir
defmodule Pipeline.Integration.TestReporting do
  def generate_integration_report(test_results) do
    report = %{
      summary: generate_summary(test_results),
      component_integration: test_results.component_integration,
      backward_compatibility: test_results.backward_compatibility,
      dspy_integration: test_results.dspy_integration,
      performance: test_results.performance,
      recommendations: generate_recommendations(test_results)
    }
    
    write_report_to_file(report)
    send_report_to_monitoring(report)
    
    report
  end
  
  defp generate_summary(test_results) do
    %{
      total_tests: count_total_tests(test_results),
      passed_tests: count_passed_tests(test_results),
      failed_tests: count_failed_tests(test_results),
      success_rate: calculate_success_rate(test_results),
      execution_time: calculate_total_execution_time(test_results)
    }
  end
end
```

Implement this integration testing framework as a complete, production-ready solution that ensures all enhanced components work together seamlessly while maintaining backward compatibility and performance.