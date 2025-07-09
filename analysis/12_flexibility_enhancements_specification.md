# Flexibility Enhancements Specification

## Overview

This specification outlines the architectural enhancements needed to make pipeline_ex sufficiently flexible for DSPy integration while maintaining backwards compatibility and extensibility for future enhancements.

## Current Flexibility Limitations

### 1. **Hard-Coded Step Types**

**Current Problem:**
```elixir
# In lib/pipeline/executor.ex
case step["type"] do
  "claude" -> Claude.execute(step, context)
  "gemini" -> Gemini.execute(step, context)
  "claude_smart" -> ClaudeSmart.execute(step, context)
  # ... all step types hard-coded
end
```

**Limitations:**
- Adding new step types requires code changes to executor
- No runtime step registration
- Difficult to add DSPy-specific steps
- No plugin architecture for custom steps

### 2. **Static Provider System**

**Current Problem:**
```elixir
# In lib/pipeline/providers/ai_provider.ex
def get_provider do
  case Pipeline.TestMode.get_mode() do
    :mock -> Pipeline.Test.Mocks.ClaudeProvider
    :live -> Pipeline.Providers.ClaudeProvider
    :mixed -> # complex logic
  end
end
```

**Limitations:**
- Only supports Claude and Gemini
- No dynamic provider registration
- Difficult to add DSPy-optimized providers
- No provider selection strategies

### 3. **Inflexible Configuration System**

**Current Problem:**
```elixir
# In lib/pipeline/enhanced_config.ex
@enhanced_step_types [
  "set_variable", "claude", "gemini", "parallel_claude",
  "gemini_instructor", "claude_smart", "claude_session",
  "claude_extract", "claude_batch", "claude_robust"
]
```

**Limitations:**
- Step types are compile-time constants
- No support for custom step configurations
- DSPy-specific options not supported
- No dynamic configuration validation

## Required Flexibility Enhancements

### 1. **Dynamic Step Registry**

#### Core Registry System
```elixir
defmodule Pipeline.Enhanced.StepRegistry do
  @moduledoc """
  Dynamic step type registration system.
  """
  
  use GenServer
  
  defstruct [
    :registered_steps,
    :step_validators,
    :step_metadata
  ]
  
  @type step_module :: module()
  @type step_type :: String.t()
  @type step_config :: map()
  @type validation_fun :: (step_config() -> {:ok, step_config()} | {:error, String.t()})
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{
      registered_steps: %{},
      step_validators: %{},
      step_metadata: %{}
    }, name: __MODULE__)
  end
  
  def register_step(step_type, step_module, opts \\ []) do
    GenServer.call(__MODULE__, {:register_step, step_type, step_module, opts})
  end
  
  def get_step_module(step_type) do
    GenServer.call(__MODULE__, {:get_step_module, step_type})
  end
  
  def list_registered_steps do
    GenServer.call(__MODULE__, :list_registered_steps)
  end
  
  def validate_step_config(step_type, config) do
    GenServer.call(__MODULE__, {:validate_step_config, step_type, config})
  end
  
  # GenServer callbacks
  def handle_call({:register_step, step_type, step_module, opts}, _from, state) do
    validator = Keyword.get(opts, :validator, &default_validator/1)
    metadata = Keyword.get(opts, :metadata, %{})
    
    new_state = %{
      state |
      registered_steps: Map.put(state.registered_steps, step_type, step_module),
      step_validators: Map.put(state.step_validators, step_type, validator),
      step_metadata: Map.put(state.step_metadata, step_type, metadata)
    }
    
    {:reply, :ok, new_state}
  end
  
  def handle_call({:get_step_module, step_type}, _from, state) do
    case Map.get(state.registered_steps, step_type) do
      nil -> {:reply, {:error, :not_found}, state}
      module -> {:reply, {:ok, module}, state}
    end
  end
  
  def handle_call({:validate_step_config, step_type, config}, _from, state) do
    case Map.get(state.step_validators, step_type) do
      nil -> {:reply, {:error, :validator_not_found}, state}
      validator -> {:reply, validator.(config), state}
    end
  end
  
  defp default_validator(config) do
    # Basic validation - ensure required fields exist
    case {config["name"], config["type"]} do
      {name, type} when is_binary(name) and is_binary(type) -> 
        {:ok, config}
      _ -> 
        {:error, "Step must have string 'name' and 'type' fields"}
    end
  end
end
```

#### Enhanced Executor with Dynamic Step Support
```elixir
defmodule Pipeline.Enhanced.Executor do
  @moduledoc """
  Enhanced executor with dynamic step type support.
  """
  
  def execute_step(step, context) do
    case Pipeline.Enhanced.StepRegistry.get_step_module(step["type"]) do
      {:ok, step_module} ->
        # Validate step configuration
        case Pipeline.Enhanced.StepRegistry.validate_step_config(step["type"], step) do
          {:ok, validated_step} ->
            execute_with_module(step_module, validated_step, context)
          {:error, reason} ->
            {:error, "Step validation failed: #{reason}"}
        end
      
      {:error, :not_found} ->
        # Fallback to legacy step execution
        execute_legacy_step(step, context)
    end
  end
  
  defp execute_with_module(step_module, step, context) do
    # Check if module implements required behavior
    if function_exported?(step_module, :execute, 2) do
      step_module.execute(step, context)
    else
      {:error, "Step module #{inspect(step_module)} does not implement execute/2"}
    end
  end
  
  defp execute_legacy_step(step, context) do
    # Fallback to existing hard-coded execution
    Pipeline.Executor.do_execute_step(step, context)
  end
end
```

### 2. **Dynamic Provider Registry**

#### Provider Registry System
```elixir
defmodule Pipeline.Enhanced.ProviderRegistry do
  @moduledoc """
  Dynamic provider registration and selection system.
  """
  
  use GenServer
  
  defstruct [
    :registered_providers,
    :provider_capabilities,
    :selection_strategies
  ]
  
  @type provider_module :: module()
  @type provider_name :: String.t()
  @type capabilities :: [atom()]
  @type selection_strategy :: (provider_name(), map() -> boolean())
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{
      registered_providers: %{},
      provider_capabilities: %{},
      selection_strategies: %{}
    }, name: __MODULE__)
  end
  
  def register_provider(provider_name, provider_module, capabilities \\ []) do
    GenServer.call(__MODULE__, {:register_provider, provider_name, provider_module, capabilities})
  end
  
  def get_provider(provider_name) do
    GenServer.call(__MODULE__, {:get_provider, provider_name})
  end
  
  def select_provider(requirements) do
    GenServer.call(__MODULE__, {:select_provider, requirements})
  end
  
  def register_selection_strategy(name, strategy_fun) do
    GenServer.call(__MODULE__, {:register_selection_strategy, name, strategy_fun})
  end
  
  # GenServer callbacks
  def handle_call({:register_provider, name, module, capabilities}, _from, state) do
    new_state = %{
      state |
      registered_providers: Map.put(state.registered_providers, name, module),
      provider_capabilities: Map.put(state.provider_capabilities, name, capabilities)
    }
    
    {:reply, :ok, new_state}
  end
  
  def handle_call({:select_provider, requirements}, _from, state) do
    suitable_providers = find_suitable_providers(requirements, state)
    
    case suitable_providers do
      [] -> {:reply, {:error, :no_suitable_provider}, state}
      [provider | _] -> {:reply, {:ok, provider}, state}
      providers -> 
        # Use selection strategy to choose best provider
        best_provider = apply_selection_strategy(providers, requirements, state)
        {:reply, {:ok, best_provider}, state}
    end
  end
  
  defp find_suitable_providers(requirements, state) do
    required_capabilities = Map.get(requirements, :capabilities, [])
    
    Enum.filter(state.registered_providers, fn {provider_name, _module} ->
      provider_capabilities = Map.get(state.provider_capabilities, provider_name, [])
      required_capabilities -- provider_capabilities == []
    end)
  end
end
```

#### DSPy Provider Integration
```elixir
defmodule Pipeline.Enhanced.DSPyProvider do
  @moduledoc """
  DSPy-optimized provider that can be dynamically registered.
  """
  
  @behaviour Pipeline.Providers.AIProvider
  
  def query(prompt, options) do
    case options["dspy_optimized"] do
      true -> 
        query_with_dspy_optimization(prompt, options)
      _ -> 
        query_traditional(prompt, options)
    end
  end
  
  defp query_with_dspy_optimization(prompt, options) do
    # Get optimized prompt from DSPy system
    signature = options["dspy_signature"]
    
    case Pipeline.DSPy.Optimizer.get_optimized_prompt(signature, prompt, options) do
      {:ok, optimized_prompt} ->
        # Execute with optimized prompt
        result = execute_optimized_query(optimized_prompt, options)
        
        # Record metrics for future optimization
        Pipeline.DSPy.Metrics.record_execution(signature, result, options)
        
        result
      
      {:error, reason} ->
        Logger.warning("DSPy optimization failed: #{reason}, falling back to traditional")
        query_traditional(prompt, options)
    end
  end
  
  defp query_traditional(prompt, options) do
    # Use traditional provider
    Pipeline.Providers.ClaudeProvider.query(prompt, options)
  end
end

# Register DSPy provider at startup
Pipeline.Enhanced.ProviderRegistry.register_provider(
  "dspy_claude", 
  Pipeline.Enhanced.DSPyProvider,
  [:dspy_optimization, :claude_compatible, :structured_output]
)
```

### 3. **Flexible Configuration System**

#### Dynamic Configuration Schema
```elixir
defmodule Pipeline.Enhanced.ConfigurationSystem do
  @moduledoc """
  Dynamic configuration system with extensible schemas.
  """
  
  use GenServer
  
  defstruct [
    :base_schema,
    :schema_extensions,
    :validation_rules
  ]
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{
      base_schema: load_base_schema(),
      schema_extensions: %{},
      validation_rules: %{}
    }, name: __MODULE__)
  end
  
  def register_schema_extension(name, extension_schema) do
    GenServer.call(__MODULE__, {:register_schema_extension, name, extension_schema})
  end
  
  def get_compiled_schema(extensions \\ []) do
    GenServer.call(__MODULE__, {:get_compiled_schema, extensions})
  end
  
  def validate_config(config, schema_extensions \\ []) do
    GenServer.call(__MODULE__, {:validate_config, config, schema_extensions})
  end
  
  # GenServer callbacks
  def handle_call({:register_schema_extension, name, extension}, _from, state) do
    new_state = %{
      state |
      schema_extensions: Map.put(state.schema_extensions, name, extension)
    }
    
    {:reply, :ok, new_state}
  end
  
  def handle_call({:get_compiled_schema, extensions}, _from, state) do
    compiled_schema = compile_schema_with_extensions(state.base_schema, extensions, state.schema_extensions)
    {:reply, {:ok, compiled_schema}, state}
  end
  
  def handle_call({:validate_config, config, extensions}, _from, state) do
    case get_compiled_schema(extensions) do
      {:ok, schema} ->
        result = Pipeline.Enhanced.SchemaValidator.validate(config, schema)
        {:reply, result, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  defp compile_schema_with_extensions(base_schema, extension_names, available_extensions) do
    # Compile base schema with requested extensions
    Enum.reduce(extension_names, base_schema, fn extension_name, acc_schema ->
      case Map.get(available_extensions, extension_name) do
        nil -> 
          Logger.warning("Schema extension #{extension_name} not found")
          acc_schema
        
        extension ->
          Pipeline.Enhanced.SchemaComposer.compose_schemas(acc_schema, extension)
      end
    end)
  end
end
```

#### DSPy Configuration Extension
```elixir
defmodule Pipeline.Enhanced.DSPyConfigExtension do
  @moduledoc """
  DSPy-specific configuration schema extension.
  """
  
  def get_dspy_schema_extension do
    %{
      "properties" => %{
        "workflow" => %{
          "properties" => %{
            "dspy_config" => %{
              "type" => "object",
              "properties" => %{
                "optimization_enabled" => %{"type" => "boolean"},
                "evaluation_mode" => %{
                  "type" => "string",
                  "enum" => ["bootstrap_few_shot", "copro", "mipro"]
                },
                "training_data_path" => %{"type" => "string"},
                "cache_enabled" => %{"type" => "boolean"},
                "optimization_frequency" => %{
                  "type" => "string",
                  "enum" => ["daily", "weekly", "monthly", "adaptive"]
                }
              }
            },
            "steps" => %{
              "items" => %{
                "properties" => %{
                  "dspy_signature" => %{
                    "type" => "object",
                    "properties" => %{
                      "input_fields" => %{
                        "type" => "array",
                        "items" => %{
                          "type" => "object",
                          "required" => ["name", "type"],
                          "properties" => %{
                            "name" => %{"type" => "string"},
                            "type" => %{"type" => "string"},
                            "description" => %{"type" => "string"},
                            "schema" => %{"type" => "object"}
                          }
                        }
                      },
                      "output_fields" => %{
                        "type" => "array",
                        "items" => %{
                          "type" => "object",
                          "required" => ["name", "type"],
                          "properties" => %{
                            "name" => %{"type" => "string"},
                            "type" => %{"type" => "string"},
                            "description" => %{"type" => "string"},
                            "schema" => %{"type" => "object"}
                          }
                        }
                      }
                    }
                  },
                  "dspy_config" => %{
                    "type" => "object",
                    "properties" => %{
                      "optimization_enabled" => %{"type" => "boolean"},
                      "few_shot_examples" => %{"type" => "integer", "minimum" => 0},
                      "bootstrap_iterations" => %{"type" => "integer", "minimum" => 1}
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end
end

# Register DSPy extension at startup
Pipeline.Enhanced.ConfigurationSystem.register_schema_extension(
  "dspy",
  Pipeline.Enhanced.DSPyConfigExtension.get_dspy_schema_extension()
)
```

### 4. **Plugin Architecture**

#### Plugin Manager
```elixir
defmodule Pipeline.Enhanced.PluginManager do
  @moduledoc """
  Plugin management system for extensible functionality.
  """
  
  use GenServer
  
  defstruct [
    :loaded_plugins,
    :plugin_metadata,
    :plugin_dependencies
  ]
  
  @type plugin_name :: String.t()
  @type plugin_module :: module()
  @type plugin_config :: map()
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %__MODULE__{
      loaded_plugins: %{},
      plugin_metadata: %{},
      plugin_dependencies: %{}
    }, name: __MODULE__)
  end
  
  def load_plugin(plugin_name, plugin_module, config \\ %{}) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_name, plugin_module, config})
  end
  
  def unload_plugin(plugin_name) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin_name})
  end
  
  def get_plugin(plugin_name) do
    GenServer.call(__MODULE__, {:get_plugin, plugin_name})
  end
  
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end
  
  # GenServer callbacks
  def handle_call({:load_plugin, name, module, config}, _from, state) do
    case validate_plugin(module) do
      :ok ->
        # Initialize plugin
        case apply(module, :init, [config]) do
          {:ok, plugin_state} ->
            # Register plugin components
            register_plugin_components(name, module, plugin_state)
            
            new_state = %{
              state |
              loaded_plugins: Map.put(state.loaded_plugins, name, {module, plugin_state}),
              plugin_metadata: Map.put(state.plugin_metadata, name, get_plugin_metadata(module))
            }
            
            {:reply, :ok, new_state}
          
          {:error, reason} ->
            {:reply, {:error, "Plugin initialization failed: #{reason}"}, state}
        end
      
      {:error, reason} ->
        {:reply, {:error, "Plugin validation failed: #{reason}"}, state}
    end
  end
  
  defp validate_plugin(module) do
    required_functions = [:init, :terminate, :get_metadata]
    
    missing_functions = Enum.filter(required_functions, fn func ->
      not function_exported?(module, func, 1)
    end)
    
    case missing_functions do
      [] -> :ok
      missing -> {:error, "Plugin missing required functions: #{inspect(missing)}"}
    end
  end
  
  defp register_plugin_components(plugin_name, module, plugin_state) do
    # Register step types provided by plugin
    if function_exported?(module, :get_step_types, 1) do
      step_types = apply(module, :get_step_types, [plugin_state])
      
      Enum.each(step_types, fn {step_type, step_module} ->
        Pipeline.Enhanced.StepRegistry.register_step(
          step_type, 
          step_module,
          metadata: %{plugin: plugin_name}
        )
      end)
    end
    
    # Register providers provided by plugin
    if function_exported?(module, :get_providers, 1) do
      providers = apply(module, :get_providers, [plugin_state])
      
      Enum.each(providers, fn {provider_name, provider_module, capabilities} ->
        Pipeline.Enhanced.ProviderRegistry.register_provider(
          provider_name,
          provider_module,
          capabilities
        )
      end)
    end
    
    # Register schema extensions provided by plugin
    if function_exported?(module, :get_schema_extensions, 1) do
      extensions = apply(module, :get_schema_extensions, [plugin_state])
      
      Enum.each(extensions, fn {extension_name, extension_schema} ->
        Pipeline.Enhanced.ConfigurationSystem.register_schema_extension(
          extension_name,
          extension_schema
        )
      end)
    end
  end
end
```

#### DSPy Plugin Example
```elixir
defmodule Pipeline.Plugins.DSPyPlugin do
  @moduledoc """
  DSPy integration plugin.
  """
  
  @behaviour Pipeline.Enhanced.PluginBehaviour
  
  def init(config) do
    # Initialize DSPy components
    case initialize_dspy_system(config) do
      {:ok, dspy_state} ->
        plugin_state = %{
          dspy_state: dspy_state,
          optimization_enabled: config["optimization_enabled"] || false,
          evaluation_mode: config["evaluation_mode"] || "bootstrap_few_shot"
        }
        
        {:ok, plugin_state}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def terminate(plugin_state) do
    # Cleanup DSPy resources
    cleanup_dspy_system(plugin_state.dspy_state)
    :ok
  end
  
  def get_metadata(_plugin_state) do
    %{
      name: "DSPy Integration",
      version: "1.0.0",
      description: "DSPy optimization and evaluation support",
      author: "Pipeline Team",
      capabilities: [:optimization, :evaluation, :structured_output]
    }
  end
  
  def get_step_types(plugin_state) do
    if plugin_state.optimization_enabled do
      [
        {"dspy_claude", Pipeline.DSPy.Steps.OptimizedClaudeStep},
        {"dspy_gemini", Pipeline.DSPy.Steps.OptimizedGeminiStep},
        {"dspy_chain", Pipeline.DSPy.Steps.ChainStep}
      ]
    else
      []
    end
  end
  
  def get_providers(plugin_state) do
    if plugin_state.optimization_enabled do
      [
        {"dspy_claude", Pipeline.Enhanced.DSPyProvider, [:dspy_optimization, :claude_compatible]},
        {"dspy_gemini", Pipeline.DSPy.Providers.GeminiProvider, [:dspy_optimization, :gemini_compatible]}
      ]
    else
      []
    end
  end
  
  def get_schema_extensions(_plugin_state) do
    [
      {"dspy", Pipeline.Enhanced.DSPyConfigExtension.get_dspy_schema_extension()}
    ]
  end
end
```

### 5. **Backward Compatibility Layer**

#### Compatibility Manager
```elixir
defmodule Pipeline.Enhanced.CompatibilityManager do
  @moduledoc """
  Maintains backward compatibility while enabling new features.
  """
  
  def ensure_backward_compatibility do
    # Register all existing step types
    register_legacy_step_types()
    
    # Register existing providers
    register_legacy_providers()
    
    # Set up legacy configuration support
    setup_legacy_configuration()
  end
  
  defp register_legacy_step_types do
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
        metadata: %{legacy: true}
      )
    end)
  end
  
  defp register_legacy_providers do
    legacy_providers = [
      {"claude", Pipeline.Providers.ClaudeProvider, [:claude_compatible]},
      {"enhanced_claude", Pipeline.Providers.EnhancedClaudeProvider, [:claude_compatible, :enhanced]},
      {"gemini", Pipeline.Providers.GeminiProvider, [:gemini_compatible]}
    ]
    
    Enum.each(legacy_providers, fn {name, module, capabilities} ->
      Pipeline.Enhanced.ProviderRegistry.register_provider(name, module, capabilities)
    end)
  end
  
  defp setup_legacy_configuration do
    # Ensure existing configuration files continue to work
    Pipeline.Enhanced.ConfigurationSystem.register_schema_extension(
      "legacy_compatibility",
      get_legacy_compatibility_schema()
    )
  end
end
```

## Implementation Benefits

### 1. **Extensibility**
- Easy addition of new step types without core changes
- Plugin system for complex integrations
- Dynamic provider registration

### 2. **DSPy Integration**
- Seamless DSPy step type integration
- Optimization-aware providers
- Structured output validation

### 3. **Maintainability**
- Clear separation of concerns
- Modular architecture
- Comprehensive plugin system

### 4. **Performance**
- Efficient registry lookups
- Lazy loading of components
- Caching of compiled schemas

### 5. **Backward Compatibility**
- Existing pipelines continue to work
- Gradual migration path
- Legacy support maintained

This flexible architecture provides the foundation needed for DSPy integration while ensuring the system remains extensible and maintainable for future enhancements.