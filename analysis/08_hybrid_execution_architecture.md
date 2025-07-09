# Hybrid Execution Architecture for DSPy Integration

## Overview

This document outlines the hybrid execution architecture that seamlessly integrates DSPy optimization with the existing pipeline_ex system, providing both traditional execution and optimized execution modes within a unified framework.

## Architectural Principles

### 1. **Backward Compatibility**
- Existing pipelines continue to work without modification
- Progressive enhancement model
- Graceful degradation when DSPy is unavailable

### 2. **Seamless Integration**
- Single configuration format supports both modes
- Unified API for execution
- Transparent optimization

### 3. **Performance Optimization**
- Intelligent caching of optimization results
- Lazy optimization initialization
- Resource-efficient execution

## Core Architecture Components

### 1. **Unified Execution Engine**

#### Master Executor
```elixir
defmodule Pipeline.HybridExecutor do
  @moduledoc """
  Unified execution engine supporting both traditional and DSPy-optimized execution.
  """
  
  def execute(workflow, opts \\ []) do
    # Determine execution mode
    execution_mode = determine_execution_mode(workflow, opts)
    
    # Initialize execution context
    context = initialize_hybrid_context(workflow, opts, execution_mode)
    
    # Execute based on mode
    case execution_mode do
      :traditional ->
        execute_traditional(workflow, context)
        
      :dspy_optimized ->
        execute_dspy_optimized(workflow, context)
        
      :hybrid ->
        execute_hybrid(workflow, context)
        
      :evaluation ->
        execute_evaluation(workflow, context)
    end
  end
  
  defp determine_execution_mode(workflow, opts) do
    # Check explicit mode override
    case Keyword.get(opts, :execution_mode) do
      mode when mode in [:traditional, :dspy_optimized, :hybrid, :evaluation] ->
        mode
        
      nil ->
        # Determine from workflow configuration
        determine_from_workflow_config(workflow)
    end
  end
  
  defp determine_from_workflow_config(workflow) do
    dspy_config = get_in(workflow, ["workflow", "dspy_config"])
    
    cond do
      is_nil(dspy_config) ->
        :traditional
        
      dspy_config["optimization_enabled"] == true ->
        :dspy_optimized
        
      dspy_config["hybrid_mode"] == true ->
        :hybrid
        
      true ->
        :traditional
    end
  end
end
```

#### Hybrid Context Manager
```elixir
defmodule Pipeline.HybridContext do
  @moduledoc """
  Manages execution context for hybrid execution.
  """
  
  defstruct [
    :workflow_name,
    :execution_mode,
    :traditional_context,
    :dspy_context,
    :optimization_cache,
    :metrics_collector,
    :fallback_enabled
  ]
  
  def new(workflow, opts, execution_mode) do
    %__MODULE__{
      workflow_name: workflow["workflow"]["name"],
      execution_mode: execution_mode,
      traditional_context: Pipeline.Executor.initialize_context(workflow, opts),
      dspy_context: initialize_dspy_context(workflow, opts),
      optimization_cache: Pipeline.DSPy.Cache.new(),
      metrics_collector: Pipeline.DSPy.Metrics.new_collector(),
      fallback_enabled: Keyword.get(opts, :fallback_enabled, true)
    }
  end
  
  def initialize_dspy_context(workflow, opts) do
    case workflow["workflow"]["dspy_config"] do
      nil ->
        nil
        
      dspy_config ->
        %Pipeline.DSPy.Context{
          optimization_enabled: dspy_config["optimization_enabled"],
          evaluation_mode: dspy_config["evaluation_mode"],
          training_data_path: dspy_config["training_data_path"],
          cache_enabled: dspy_config["cache_enabled"] || true,
          fallback_strategy: dspy_config["fallback_strategy"] || "traditional"
        }
    end
  end
end
```

### 2. **Intelligent Step Routing**

#### Step Router
```elixir
defmodule Pipeline.HybridStepRouter do
  @moduledoc """
  Routes steps to appropriate execution engines based on optimization availability.
  """
  
  def route_step(step, context) do
    case determine_step_execution_mode(step, context) do
      :traditional ->
        execute_traditional_step(step, context)
        
      :dspy_optimized ->
        execute_dspy_step(step, context)
        
      :hybrid ->
        execute_hybrid_step(step, context)
        
      :fallback ->
        execute_fallback_step(step, context)
    end
  end
  
  defp determine_step_execution_mode(step, context) do
    cond do
      # Step explicitly requests traditional execution
      step["execution_mode"] == "traditional" ->
        :traditional
        
      # Step has DSPy optimization available
      has_dspy_optimization?(step) and context.execution_mode == :dspy_optimized ->
        :dspy_optimized
        
      # Hybrid mode with intelligent routing
      context.execution_mode == :hybrid ->
        determine_hybrid_routing(step, context)
        
      # DSPy unavailable, fallback to traditional
      context.execution_mode == :dspy_optimized and not dspy_available?() ->
        :fallback
        
      true ->
        :traditional
    end
  end
  
  defp determine_hybrid_routing(step, context) do
    # Intelligent routing based on step characteristics
    optimization_available = has_dspy_optimization?(step)
    performance_benefit = estimate_performance_benefit(step, context)
    
    cond do
      optimization_available and performance_benefit > 0.2 ->
        :dspy_optimized
        
      optimization_available and performance_benefit > 0.1 ->
        # A/B test between traditional and optimized
        if should_ab_test?(step, context) do
          :hybrid
        else
          :dspy_optimized
        end
        
      true ->
        :traditional
    end
  end
  
  defp execute_hybrid_step(step, context) do
    # Execute both traditional and DSPy versions
    traditional_result = execute_traditional_step(step, context)
    dspy_result = execute_dspy_step(step, context)
    
    # Compare results and choose best
    best_result = select_best_result(traditional_result, dspy_result, step, context)
    
    # Record A/B test results
    record_ab_test_result(step, traditional_result, dspy_result, best_result, context)
    
    best_result
  end
end
```

### 3. **Optimization Cache System**

#### Multi-Level Caching
```elixir
defmodule Pipeline.DSPy.Cache do
  @moduledoc """
  Multi-level caching system for DSPy optimizations.
  """
  
  defstruct [
    :memory_cache,
    :disk_cache,
    :distributed_cache,
    :cache_config
  ]
  
  def new(config \\ %{}) do
    %__MODULE__{
      memory_cache: :ets.new(:dspy_memory_cache, [:set, :public]),
      disk_cache: initialize_disk_cache(config),
      distributed_cache: initialize_distributed_cache(config),
      cache_config: config
    }
  end
  
  def get_optimization(cache, signature_hash, optimization_params) do
    cache_key = build_cache_key(signature_hash, optimization_params)
    
    # Try memory cache first
    case :ets.lookup(cache.memory_cache, cache_key) do
      [{^cache_key, cached_result}] ->
        {:ok, cached_result}
        
      [] ->
        # Try disk cache
        case get_from_disk_cache(cache.disk_cache, cache_key) do
          {:ok, cached_result} ->
            # Store in memory cache for faster access
            :ets.insert(cache.memory_cache, {cache_key, cached_result})
            {:ok, cached_result}
            
          :not_found ->
            # Try distributed cache
            get_from_distributed_cache(cache.distributed_cache, cache_key)
        end
    end
  end
  
  def store_optimization(cache, signature_hash, optimization_params, result) do
    cache_key = build_cache_key(signature_hash, optimization_params)
    
    # Store in all cache levels
    :ets.insert(cache.memory_cache, {cache_key, result})
    store_in_disk_cache(cache.disk_cache, cache_key, result)
    store_in_distributed_cache(cache.distributed_cache, cache_key, result)
    
    :ok
  end
  
  def invalidate_optimization(cache, signature_hash) do
    # Find all cache keys for this signature
    pattern = build_cache_pattern(signature_hash)
    
    # Invalidate from all cache levels
    :ets.match_delete(cache.memory_cache, pattern)
    invalidate_from_disk_cache(cache.disk_cache, pattern)
    invalidate_from_distributed_cache(cache.distributed_cache, pattern)
    
    :ok
  end
end
```

### 4. **Fallback and Error Handling**

#### Graceful Degradation System
```elixir
defmodule Pipeline.HybridFallback do
  @moduledoc """
  Handles graceful degradation when DSPy optimization fails.
  """
  
  def execute_with_fallback(step, context, primary_mode) do
    try do
      case primary_mode do
        :dspy_optimized ->
          execute_dspy_with_fallback(step, context)
          
        :hybrid ->
          execute_hybrid_with_fallback(step, context)
      end
    rescue
      error ->
        handle_execution_error(step, context, error, primary_mode)
    end
  end
  
  defp execute_dspy_with_fallback(step, context) do
    case Pipeline.DSPy.StepExecutor.execute(step, context) do
      {:ok, result} ->
        {:ok, result}
        
      {:error, :dspy_unavailable} ->
        Logger.warning("DSPy unavailable for step #{step["name"]}, falling back to traditional")
        execute_traditional_fallback(step, context)
        
      {:error, :optimization_failed} ->
        Logger.warning("DSPy optimization failed for step #{step["name"]}, falling back to traditional")
        execute_traditional_fallback(step, context)
        
      {:error, :timeout} ->
        Logger.warning("DSPy optimization timeout for step #{step["name"]}, falling back to traditional")
        execute_traditional_fallback(step, context)
        
      {:error, reason} ->
        # Other errors should be propagated
        {:error, reason}
    end
  end
  
  defp execute_traditional_fallback(step, context) do
    # Remove DSPy-specific configuration
    traditional_step = prepare_traditional_step(step)
    
    # Execute using traditional pipeline
    Pipeline.Executor.execute_step(traditional_step, context.traditional_context)
  end
  
  defp prepare_traditional_step(step) do
    step
    |> Map.drop(["dspy_config", "signature"])
    |> ensure_traditional_compatibility()
  end
  
  def handle_execution_error(step, context, error, primary_mode) do
    # Log error
    Logger.error("Execution error in #{primary_mode} mode for step #{step["name"]}: #{inspect(error)}")
    
    # Record error metrics
    Pipeline.DSPy.Metrics.record_execution_error(step, error, primary_mode)
    
    # Attempt fallback if enabled
    if context.fallback_enabled do
      Logger.info("Attempting fallback execution for step #{step["name"]}")
      execute_traditional_fallback(step, context)
    else
      {:error, "Execution failed: #{inspect(error)}"}
    end
  end
end
```

### 5. **Performance Monitoring and Metrics**

#### Hybrid Performance Monitor
```elixir
defmodule Pipeline.HybridPerformanceMonitor do
  @moduledoc """
  Monitors performance across traditional and DSPy execution modes.
  """
  
  def monitor_execution(step, context, execution_mode) do
    start_time = System.monotonic_time(:millisecond)
    
    # Start monitoring
    monitor_ref = start_monitoring(step, execution_mode)
    
    try do
      # Execute step
      result = execute_monitored_step(step, context, execution_mode)
      
      # Record successful execution
      end_time = System.monotonic_time(:millisecond)
      record_execution_success(step, execution_mode, end_time - start_time, result)
      
      result
    rescue
      error ->
        # Record failed execution
        end_time = System.monotonic_time(:millisecond)
        record_execution_failure(step, execution_mode, end_time - start_time, error)
        
        reraise error, __STACKTRACE__
    after
      # Stop monitoring
      stop_monitoring(monitor_ref)
    end
  end
  
  def compare_execution_modes(step, context) do
    # Execute with both modes
    traditional_metrics = execute_and_measure(step, context, :traditional)
    dspy_metrics = execute_and_measure(step, context, :dspy_optimized)
    
    # Compare metrics
    comparison = %{
      traditional: traditional_metrics,
      dspy_optimized: dspy_metrics,
      performance_difference: calculate_performance_difference(traditional_metrics, dspy_metrics),
      recommendation: generate_mode_recommendation(traditional_metrics, dspy_metrics)
    }
    
    # Store comparison results
    store_mode_comparison(step, comparison)
    
    comparison
  end
  
  defp calculate_performance_difference(traditional, dspy) do
    %{
      execution_time_diff: dspy.execution_time - traditional.execution_time,
      cost_diff: dspy.cost - traditional.cost,
      quality_diff: dspy.quality_score - traditional.quality_score,
      success_rate_diff: dspy.success_rate - traditional.success_rate
    }
  end
  
  defp generate_mode_recommendation(traditional, dspy) do
    cond do
      # DSPy is significantly better
      dspy.quality_score > traditional.quality_score + 0.1 and
      dspy.cost < traditional.cost * 1.2 ->
        {:recommend_dspy, "DSPy provides better quality at reasonable cost"}
        
      # Traditional is more cost-effective
      traditional.cost < dspy.cost * 0.8 and
      traditional.quality_score > dspy.quality_score - 0.05 ->
        {:recommend_traditional, "Traditional execution is more cost-effective"}
        
      # Performance is similar
      abs(dspy.quality_score - traditional.quality_score) < 0.05 ->
        {:recommend_hybrid, "Performance is similar, use hybrid mode for A/B testing"}
        
      true ->
        {:recommend_evaluation, "Need more data to make recommendation"}
    end
  end
end
```

### 6. **Configuration Management**

#### Unified Configuration System
```elixir
defmodule Pipeline.HybridConfig do
  @moduledoc """
  Unified configuration system supporting both traditional and DSPy modes.
  """
  
  def parse_hybrid_config(yaml_config) do
    workflow = yaml_config["workflow"]
    
    base_config = %{
      name: workflow["name"],
      description: workflow["description"],
      steps: workflow["steps"],
      traditional_config: extract_traditional_config(workflow),
      dspy_config: extract_dspy_config(workflow),
      hybrid_config: extract_hybrid_config(workflow)
    }
    
    validate_hybrid_config(base_config)
  end
  
  defp extract_dspy_config(workflow) do
    case workflow["dspy_config"] do
      nil ->
        %{optimization_enabled: false}
        
      dspy_config ->
        %{
          optimization_enabled: dspy_config["optimization_enabled"] || false,
          evaluation_mode: dspy_config["evaluation_mode"] || "bootstrap_few_shot",
          training_data_path: dspy_config["training_data_path"],
          cache_enabled: dspy_config["cache_enabled"] || true,
          fallback_strategy: dspy_config["fallback_strategy"] || "traditional",
          optimization_frequency: dspy_config["optimization_frequency"] || "weekly"
        }
    end
  end
  
  defp extract_hybrid_config(workflow) do
    case workflow["hybrid_config"] do
      nil ->
        %{mode: :traditional}
        
      hybrid_config ->
        %{
          mode: String.to_atom(hybrid_config["mode"] || "traditional"),
          intelligent_routing: hybrid_config["intelligent_routing"] || false,
          ab_testing_enabled: hybrid_config["ab_testing_enabled"] || false,
          performance_threshold: hybrid_config["performance_threshold"] || 0.1,
          fallback_enabled: hybrid_config["fallback_enabled"] || true
        }
    end
  end
  
  def validate_hybrid_config(config) do
    with :ok <- validate_traditional_compatibility(config),
         :ok <- validate_dspy_compatibility(config),
         :ok <- validate_hybrid_compatibility(config) do
      {:ok, config}
    else
      {:error, reason} ->
        {:error, "Invalid hybrid configuration: #{reason}"}
    end
  end
end
```

### 7. **Migration and Compatibility**

#### Migration Helper
```elixir
defmodule Pipeline.HybridMigration do
  @moduledoc """
  Helps migrate existing pipelines to hybrid execution.
  """
  
  def migrate_to_hybrid(traditional_pipeline_path, migration_config) do
    # Load traditional pipeline
    {:ok, traditional_config} = Pipeline.Config.load_workflow(traditional_pipeline_path)
    
    # Generate DSPy configuration
    dspy_config = generate_dspy_config(traditional_config, migration_config)
    
    # Create hybrid configuration
    hybrid_config = merge_configurations(traditional_config, dspy_config)
    
    # Validate hybrid configuration
    case Pipeline.HybridConfig.validate_hybrid_config(hybrid_config) do
      {:ok, validated_config} ->
        # Save hybrid pipeline
        hybrid_path = generate_hybrid_path(traditional_pipeline_path)
        save_hybrid_pipeline(hybrid_path, validated_config)
        
        {:ok, hybrid_path}
        
      {:error, reason} ->
        {:error, "Migration failed: #{reason}"}
    end
  end
  
  defp generate_dspy_config(traditional_config, migration_config) do
    steps = traditional_config["workflow"]["steps"]
    
    # Analyze steps to determine DSPy candidates
    dspy_candidates = identify_dspy_candidates(steps)
    
    # Generate DSPy signatures for candidates
    signatures = generate_signatures_for_candidates(dspy_candidates)
    
    %{
      "dspy_config" => %{
        "optimization_enabled" => migration_config.enable_optimization,
        "evaluation_mode" => migration_config.evaluation_mode || "bootstrap_few_shot",
        "signatures" => signatures,
        "fallback_strategy" => "traditional"
      }
    }
  end
  
  defp identify_dspy_candidates(steps) do
    # Identify steps that would benefit from DSPy optimization
    Enum.filter(steps, fn step ->
      step_type = step["type"]
      
      step_type in ["claude", "gemini", "claude_smart", "claude_extract"] and
      has_complex_prompt?(step) and
      suitable_for_optimization?(step)
    end)
  end
end
```

## Example Hybrid Pipeline Configuration

```yaml
workflow:
  name: hybrid_code_analyzer
  description: "Code analysis with hybrid execution"
  
  # Traditional configuration (backward compatible)
  steps:
    - name: analyze_structure
      type: claude
      prompt:
        - type: static
          content: "Analyze this code structure"
      
    - name: generate_docs
      type: claude_smart
      prompt:
        - type: static
          content: "Generate documentation"
  
  # DSPy configuration
  dspy_config:
    optimization_enabled: true
    evaluation_mode: "bootstrap_few_shot"
    cache_enabled: true
    fallback_strategy: "traditional"
    
  # Hybrid execution configuration
  hybrid_config:
    mode: "hybrid"
    intelligent_routing: true
    ab_testing_enabled: true
    performance_threshold: 0.1
    fallback_enabled: true
```

## Benefits of Hybrid Architecture

### 1. **Gradual Migration**
- Existing pipelines work unchanged
- Step-by-step optimization adoption
- Risk-free experimentation

### 2. **Intelligent Optimization**
- Automatic routing based on performance
- A/B testing for continuous improvement
- Fallback ensures reliability

### 3. **Comprehensive Monitoring**
- Performance comparison across modes
- Cost-benefit analysis
- Optimization recommendations

### 4. **Production Ready**
- Graceful degradation
- Error handling and recovery
- Caching for performance

This hybrid architecture provides a robust foundation for integrating DSPy optimization while maintaining the reliability and usability that makes pipeline_ex effective for real-world software development tasks.