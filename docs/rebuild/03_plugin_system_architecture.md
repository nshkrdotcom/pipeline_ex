# Plugin System Architecture

## Overview

The Pipeline.ex v2 plugin system provides a powerful, flexible mechanism for extending the core functionality without modifying the base code. The architecture supports runtime plugin loading, dependency management, and safe isolation of plugin code.

## Design Goals

1. **Zero Core Modification**: Add features without touching core code
2. **Runtime Loading**: Load/unload plugins without restart
3. **Dependency Management**: Plugins can depend on other plugins
4. **Resource Isolation**: Plugins cannot interfere with each other
5. **Type Safety**: Compile-time guarantees where possible
6. **Discovery**: Easy plugin discovery and introspection

## Plugin Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Plugin System                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   Plugin    │  │   Plugin    │  │   Plugin    │   │
│  │  Registry   │  │  Loader     │  │  Supervisor │   │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │
│         │                 │                 │          │
│  ┌──────▼─────────────────▼─────────────────▼──────┐   │
│  │              Plugin Manager                      │   │
│  └──────────────────────┬──────────────────────────┘   │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐   │
│  │              Hook System                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │   │
│  │  │ Lifecycle│  │  Event   │  │ Extension│     │   │
│  │  │  Hooks   │  │  Hooks   │  │  Points  │     │   │
│  │  └──────────┘  └──────────┘  └──────────┘     │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
                           │
    ┌──────────────────────┼──────────────────────┐
    │                      │                      │
┌───▼────────┐      ┌──────▼───────┐      ┌──────▼───────┐
│  Provider  │      │   Handler    │      │  Validator   │
│  Plugins   │      │   Plugins    │      │   Plugins    │
└────────────┘      └──────────────┘      └──────────────┘
```

## Core Components

### 1. Plugin Definition

```elixir
defmodule Pipeline.Plugin do
  @moduledoc """
  Base behaviour and macro for creating plugins.
  """
  
  @type plugin_id :: atom() | String.t()
  @type version :: Version.t()
  @type capability :: atom()
  @type config :: map()
  @type state :: term()
  
  @doc "Plugin metadata"
  @callback __plugin__() :: %{
    id: plugin_id(),
    name: String.t(),
    version: version(),
    description: String.t(),
    author: String.t(),
    capabilities: [capability()],
    dependencies: [plugin_id()],
    hooks: %{atom() => [atom()]}
  }
  
  @doc "Initialize plugin"
  @callback init(config()) :: {:ok, state()} | {:error, reason :: term()}
  
  @doc "Start plugin (called after all plugins loaded)"
  @callback start(state()) :: {:ok, state()} | {:error, reason :: term()}
  
  @doc "Stop plugin"
  @callback stop(state()) :: :ok
  
  @optional_callbacks [start: 1, stop: 1]
  
  defmacro __using__(opts) do
    quote do
      @behaviour Pipeline.Plugin
      
      Module.register_attribute(__MODULE__, :plugin_id, persist: true)
      Module.register_attribute(__MODULE__, :plugin_version, persist: true)
      Module.register_attribute(__MODULE__, :plugin_capabilities, accumulate: true)
      Module.register_attribute(__MODULE__, :plugin_dependencies, accumulate: true)
      Module.register_attribute(__MODULE__, :plugin_hooks, accumulate: true)
      
      @plugin_id unquote(opts[:id]) || __MODULE__
      @plugin_version unquote(opts[:version]) || "1.0.0"
      
      import Pipeline.Plugin.DSL
      
      @before_compile Pipeline.Plugin
    end
  end
  
  defmacro __before_compile__(_env) do
    quote do
      def __plugin__ do
        %{
          id: @plugin_id,
          name: to_string(@plugin_id),
          version: @plugin_version,
          description: @moduledoc || "",
          author: "Unknown",
          capabilities: @plugin_capabilities,
          dependencies: @plugin_dependencies,
          hooks: Enum.group_by(@plugin_hooks, &elem(&1, 0), &elem(&1, 1))
        }
      end
      
      def child_spec(opts) do
        %{
          id: @plugin_id,
          start: {Pipeline.Plugin.Wrapper, :start_link, [{__MODULE__, opts}]},
          type: :worker,
          restart: :permanent
        }
      end
    end
  end
end
```

### 2. Plugin DSL

```elixir
defmodule Pipeline.Plugin.DSL do
  @moduledoc """
  DSL for defining plugins declaratively.
  """
  
  defmacro capability(name, opts \\ []) do
    quote do
      @plugin_capabilities {unquote(name), unquote(opts)}
    end
  end
  
  defmacro depends_on(plugin_id, opts \\ []) do
    quote do
      @plugin_dependencies {unquote(plugin_id), unquote(opts)}
    end
  end
  
  defmacro hook(type, name, opts \\ []) do
    quote do
      @plugin_hooks {unquote(type), unquote(name), unquote(opts)}
      
      def unquote(name)(context, next) do
        # Default implementation calls next
        next.(context)
      end
      
      defoverridable [{unquote(name), 2}]
    end
  end
  
  defmacro provides(module_type, module) do
    quote do
      capability(unquote(module_type), module: unquote(module))
    end
  end
end
```

### 3. Plugin Manager

```elixir
defmodule Pipeline.Plugin.Manager do
  @moduledoc """
  Central manager for all plugins.
  Handles loading, dependency resolution, and lifecycle.
  """
  
  use GenServer
  
  defstruct [
    :plugins,      # %{plugin_id => plugin_state}
    :registry,     # Plugin.Registry
    :loader,       # Plugin.Loader
    :supervisor,   # Plugin.Supervisor
    :hooks         # Hook.Manager
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc "Load a plugin"
  def load_plugin(plugin_module, config \\ %{}) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_module, config})
  end
  
  @doc "Unload a plugin"
  def unload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin_id})
  end
  
  @doc "Get plugin by capability"
  def get_by_capability(capability) do
    GenServer.call(__MODULE__, {:get_by_capability, capability})
  end
  
  @doc "List all plugins"
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end
  
  # Server implementation
  
  @impl GenServer
  def init(opts) do
    state = %__MODULE__{
      plugins: %{},
      registry: Pipeline.Plugin.Registry.new(),
      loader: Pipeline.Plugin.Loader.new(),
      supervisor: opts[:supervisor] || Pipeline.Plugin.Supervisor,
      hooks: Pipeline.Hook.Manager.new()
    }
    
    # Load core plugins
    load_core_plugins(state)
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_call({:load_plugin, module, config}, _from, state) do
    case do_load_plugin(module, config, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end
  
  defp do_load_plugin(module, config, state) do
    with :ok <- validate_plugin(module),
         :ok <- check_dependencies(module, state),
         {:ok, plugin_state} <- start_plugin(module, config, state),
         :ok <- register_plugin(module, plugin_state, state),
         :ok <- install_hooks(module, state) do
      
      new_state = put_in(state.plugins[module.__plugin__().id], plugin_state)
      {:ok, new_state}
    end
  end
  
  defp validate_plugin(module) do
    if function_exported?(module, :__plugin__, 0) do
      :ok
    else
      {:error, :not_a_plugin}
    end
  end
  
  defp check_dependencies(module, state) do
    deps = module.__plugin__().dependencies
    
    missing = Enum.reject(deps, fn {dep_id, _opts} ->
      Map.has_key?(state.plugins, dep_id)
    end)
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_dependencies, missing}}
    end
  end
end
```

### 4. Plugin Registry

```elixir
defmodule Pipeline.Plugin.Registry do
  @moduledoc """
  Registry for plugin discovery and capability lookup.
  """
  
  defstruct [
    :plugins,      # %{plugin_id => plugin_info}
    :capabilities, # %{capability => [plugin_id]}
    :providers     # %{provider_type => plugin_id}
  ]
  
  def new do
    %__MODULE__{
      plugins: %{},
      capabilities: %{},
      providers: %{}
    }
  end
  
  def register(registry, plugin_info) do
    registry
    |> register_plugin(plugin_info)
    |> index_capabilities(plugin_info)
    |> index_providers(plugin_info)
  end
  
  def find_by_capability(registry, capability) do
    Map.get(registry.capabilities, capability, [])
  end
  
  def get_provider(registry, provider_type) do
    Map.get(registry.providers, provider_type)
  end
  
  defp index_capabilities(registry, %{id: id, capabilities: caps}) do
    new_caps = Enum.reduce(caps, registry.capabilities, fn {cap, _opts}, acc ->
      Map.update(acc, cap, [id], &[id | &1])
    end)
    
    %{registry | capabilities: new_caps}
  end
end
```

### 5. Hook System

```elixir
defmodule Pipeline.Hook do
  @moduledoc """
  Hook system for plugin integration points.
  """
  
  @type hook_type :: :before | :after | :around | :replace
  @type hook_name :: atom()
  @type context :: map()
  @type next :: (context() -> result :: term())
  
  defmodule Manager do
    @moduledoc """
    Manages hook registration and execution.
    """
    
    defstruct hooks: %{} # %{hook_name => [hook_fn]}
    
    def new, do: %__MODULE__{}
    
    def register(manager, hook_name, hook_fn, opts \\ []) do
      priority = opts[:priority] || 50
      hook = {priority, hook_fn}
      
      new_hooks = Map.update(manager.hooks, hook_name, [hook], &insert_by_priority(&1, hook))
      %{manager | hooks: new_hooks}
    end
    
    def run(manager, hook_name, context) do
      case Map.get(manager.hooks, hook_name, []) do
        [] -> 
          {:ok, context}
        hooks ->
          run_hook_chain(hooks, context)
      end
    end
    
    defp run_hook_chain(hooks, initial_context) do
      # Build the chain of functions
      chain = Enum.reduce(hooks, &identity/1, fn {_priority, hook_fn}, next ->
        fn context -> hook_fn.(context, next) end
      end)
      
      try do
        {:ok, chain.(initial_context)}
      catch
        :throw, {:hook_error, reason} -> {:error, reason}
      end
    end
    
    defp identity(x), do: x
  end
end
```

## Plugin Types

### 1. Provider Plugins

```elixir
defmodule Pipeline.Plugins.OpenAIProvider do
  use Pipeline.Plugin, 
    id: :openai_provider,
    version: "1.0.0"
  
  @moduledoc """
  OpenAI provider plugin.
  """
  
  provides :provider, Pipeline.Providers.OpenAI
  
  capability :models, [:gpt_4, :gpt_35_turbo]
  capability :embeddings, true
  capability :streaming, true
  
  @impl Pipeline.Plugin
  def init(config) do
    {:ok, %{api_key: config[:api_key]}}
  end
end
```

### 2. Handler Plugins

```elixir
defmodule Pipeline.Plugins.DataTransformHandler do
  use Pipeline.Plugin,
    id: :data_transform_handler,
    version: "1.0.0"
    
  @moduledoc """
  Adds data transformation node type.
  """
  
  provides :node_handler, Pipeline.Handlers.DataTransform
  
  capability :node_types, [:transform, :map, :filter, :reduce]
  
  hook :before, :validate_node do
    def validate_node(%{node: %{type: type}} = context, next) when type in [:transform, :map, :filter, :reduce] do
      # Custom validation for transform nodes
      if valid_transform_config?(context.node.config) do
        next.(context)
      else
        throw {:hook_error, :invalid_transform_config}
      end
    end
    def validate_node(context, next), do: next.(context)
  end
end
```

### 3. Extension Plugins

```elixir
defmodule Pipeline.Plugins.TelemetryPlugin do
  use Pipeline.Plugin,
    id: :telemetry,
    version: "2.0.0"
    
  @moduledoc """
  Adds comprehensive telemetry to pipeline execution.
  """
  
  capability :telemetry, true
  capability :metrics, [:prometheus, :statsd]
  
  hook :around, :execute_node do
    def execute_node(context, next) do
      start_time = System.monotonic_time()
      metadata = extract_metadata(context)
      
      :telemetry.span(
        [:pipeline, :node, :execution],
        metadata,
        fn ->
          result = next.(context)
          {result, Map.put(metadata, :result, elem(result, 0))}
        end
      )
    end
  end
  
  hook :after, :pipeline_complete do
    def pipeline_complete(context, next) do
      emit_pipeline_metrics(context)
      next.(context)
    end
  end
end
```

### 4. Integration Plugins

```elixir
defmodule Pipeline.Plugins.LangChainIntegration do
  use Pipeline.Plugin,
    id: :langchain_integration,
    version: "1.0.0"
    
  @moduledoc """
  Integrates with Python LangChain via Erlport.
  """
  
  depends_on :python_bridge
  
  capability :langchain_tools, true
  capability :vector_stores, [:chroma, :pinecone, :weaviate]
  
  @impl Pipeline.Plugin
  def init(config) do
    # Initialize Python interpreter
    {:ok, python} = :python.start_link(python_path: config[:python_path])
    {:ok, %{python: python, config: config}}
  end
  
  provides :node_handler, Pipeline.Handlers.LangChain
end
```

## Plugin Lifecycle

### 1. Discovery Phase
```elixir
# Automatic discovery from configured paths
defmodule Pipeline.Plugin.Discovery do
  def discover_plugins(paths) do
    paths
    |> Enum.flat_map(&find_beam_files/1)
    |> Enum.map(&extract_plugin_info/1)
    |> Enum.filter(&valid_plugin?/1)
  end
end
```

### 2. Loading Phase
```elixir
# Dependency resolution and loading order
defmodule Pipeline.Plugin.Loader do
  def load_plugins(plugins) do
    plugins
    |> build_dependency_graph()
    |> topological_sort()
    |> Enum.map(&load_plugin/1)
  end
end
```

### 3. Runtime Phase
```elixir
# Plugin supervision and monitoring
defmodule Pipeline.Plugin.Supervisor do
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Pipeline.Plugin.DynamicSupervisor}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  def start_plugin(plugin_module, config) do
    spec = plugin_module.child_spec(config)
    DynamicSupervisor.start_child(Pipeline.Plugin.DynamicSupervisor, spec)
  end
end
```

## Plugin Communication

### 1. Event Bus
```elixir
defmodule Pipeline.Plugin.Events do
  def emit(event_type, payload) do
    Pipeline.Events.emit({:plugin, event_type}, payload)
  end
  
  def subscribe(plugin_id, event_type) do
    Pipeline.Events.subscribe({:plugin, event_type})
  end
end
```

### 2. Inter-Plugin Communication
```elixir
defmodule Pipeline.Plugin.RPC do
  def call(plugin_id, request, timeout \\ 5000) do
    GenServer.call(plugin_id, {:plugin_rpc, request}, timeout)
  end
  
  def cast(plugin_id, message) do
    GenServer.cast(plugin_id, {:plugin_message, message})
  end
end
```

## Security and Isolation

### 1. Capability-Based Security
```elixir
defmodule Pipeline.Plugin.Security do
  def check_capability(plugin_id, capability) do
    plugin_info = Pipeline.Plugin.Registry.get(plugin_id)
    capability in plugin_info.capabilities
  end
  
  def sandbox_call(plugin_id, fun) do
    # Execute in restricted context
    Pipeline.Sandbox.run(fun, allowed_modules: get_allowed_modules(plugin_id))
  end
end
```

### 2. Resource Limits
```elixir
defmodule Pipeline.Plugin.Resources do
  def monitor_plugin(plugin_id) do
    :recon.proc_count(plugin_id, 10)
    |> check_resource_limits()
  end
end
```

## Plugin Development Kit

### 1. Generator
```bash
mix pipeline.gen.plugin my_plugin --type provider --capability llm
```

### 2. Testing Utilities
```elixir
defmodule Pipeline.Plugin.Test do
  defmacro test_plugin(plugin_module, do: block) do
    quote do
      setup do
        {:ok, manager} = Pipeline.Plugin.Manager.start_link()
        {:ok, _} = Pipeline.Plugin.Manager.load_plugin(unquote(plugin_module))
        {:ok, manager: manager}
      end
      
      unquote(block)
    end
  end
end
```

## Best Practices

1. **Minimal Dependencies**: Plugins should be self-contained
2. **Graceful Degradation**: Handle missing capabilities
3. **Version Compatibility**: Use semantic versioning
4. **Resource Awareness**: Don't block or consume excessive resources
5. **Error Handling**: Fail gracefully with informative errors

## Conclusion

This plugin system provides a robust foundation for extending Pipeline.ex v2 while maintaining system integrity and performance. The architecture supports everything from simple function additions to complex third-party integrations, all while maintaining type safety and runtime reliability.