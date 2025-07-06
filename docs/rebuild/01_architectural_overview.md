# Pipeline.ex v2: Architectural Overview

## Vision

Pipeline.ex v2 is a complete rebuild focused on creating a **library-first, composable, and extensible** system for building AI pipelines. Unlike the current framework approach, v2 prioritizes:

- **Modularity**: Every component is independent and replaceable
- **Composability**: Components combine naturally to create complex behaviors
- **Extensibility**: Plugin architecture for all major subsystems
- **Type Safety**: Leveraging Elixir's type system and runtime validation
- **Performance**: Efficient execution with minimal overhead
- **Developer Experience**: Intuitive APIs that are hard to misuse

## Core Design Principles

### 1. **Hexagonal Architecture (Ports & Adapters)**

```
┌─────────────────────────────────────────────────────────┐
│                    Application Core                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │                 Domain Layer                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │   │
│  │  │  Graph   │  │  State   │  │  Step    │      │   │
│  │  │  Model   │  │  Model   │  │  Model   │      │   │
│  │  └──────────┘  └──────────┘  └──────────┘      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Application Services                │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │   │
│  │  │ Executor │  │Validator │  │ Builder  │      │   │
│  │  └──────────┘  └──────────┘  └──────────┘      │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
┌───────▼────────┐ ┌───────▼────────┐ ┌──────▼─────────┐
│ Provider Port  │ │ Storage Port   │ │ Format Port    │
│                │ │                │ │                │
│ ┌────────────┐ │ │ ┌────────────┐ │ │ ┌────────────┐ │
│ │Claude Impl │ │ │ │ ETS Impl   │ │ │ │ JSON Impl  │ │
│ └────────────┘ │ │ └────────────┘ │ │ └────────────┘ │
│ ┌────────────┐ │ │ ┌────────────┐ │ │ ┌────────────┐ │
│ │Gemini Impl │ │ │ │Redis Impl  │ │ │ │ YAML Impl  │ │
│ └────────────┘ │ │ └────────────┘ │ │ └────────────┘ │
└────────────────┘ └────────────────┘ └────────────────┘
```

### 2. **Component-Based Architecture**

Each component is:
- **Self-contained**: Has its own tests, documentation, and dependencies
- **Interface-driven**: Communicates through well-defined contracts
- **Pluggable**: Can be replaced without affecting other components
- **Composable**: Can be combined with other components

### 3. **Event-Driven Core**

```elixir
# All state changes emit events
Pipeline.Events.subscribe(:step_started)
Pipeline.Events.subscribe(:state_updated)
Pipeline.Events.subscribe(:validation_failed)

# Components react to events
defmodule Pipeline.Monitoring.Collector do
  use Pipeline.EventHandler
  
  def handle_event(:step_started, %{step: step, timestamp: ts}) do
    # Record metrics
  end
end
```

### 4. **Functional Core, Imperative Shell**

- Pure functions for business logic
- Side effects pushed to the boundaries
- Immutable data structures
- Explicit state transitions

## System Layers

### 1. **Domain Layer** (Pure Business Logic)

```elixir
defmodule Pipeline.Core.Graph do
  @moduledoc """
  Pure functional graph representation and operations.
  No side effects, no external dependencies.
  """
  
  defstruct nodes: %{}, edges: %{}, metadata: %{}
  
  @type t :: %__MODULE__{
    nodes: %{node_id() => Node.t()},
    edges: %{node_id() => [edge()]},
    metadata: map()
  }
  
  @spec add_node(t(), node_id(), Node.t()) :: t()
  def add_node(graph, id, node) do
    %{graph | nodes: Map.put(graph.nodes, id, node)}
  end
  
  @spec topological_sort(t()) :: {:ok, [node_id()]} | {:error, :cycle}
  def topological_sort(graph) do
    # Pure algorithm, no side effects
  end
end
```

### 2. **Application Layer** (Use Cases)

```elixir
defmodule Pipeline.Application.ExecutePipeline do
  @moduledoc """
  Use case for executing a pipeline.
  Orchestrates domain objects, handles side effects.
  """
  
  def execute(graph, initial_state, opts \\ []) do
    with {:ok, execution_plan} <- Pipeline.Core.Graph.topological_sort(graph),
         {:ok, executor} <- build_executor(opts),
         {:ok, result} <- run_execution(executor, execution_plan, initial_state) do
      {:ok, result}
    end
  end
  
  defp build_executor(opts) do
    # Dependency injection based on options
    %Pipeline.Execution.Engine{
      step_runner: opts[:step_runner] || Pipeline.Execution.DefaultStepRunner,
      state_store: opts[:state_store] || Pipeline.State.ETS,
      event_bus: opts[:event_bus] || Pipeline.Events.DefaultBus
    }
  end
end
```

### 3. **Infrastructure Layer** (Adapters)

```elixir
defmodule Pipeline.Providers.Claude do
  @moduledoc """
  Claude provider adapter.
  Implements the Provider behaviour.
  """
  
  @behaviour Pipeline.Provider
  
  @impl true
  def query(prompt, options) do
    # HTTP calls, error handling, retries
    # Converts external API to internal domain types
  end
  
  @impl true
  def stream(prompt, options) do
    # Streaming implementation
  end
end
```

## Core Abstractions

### 1. **Node** (Unit of Computation)

```elixir
defmodule Pipeline.Core.Node do
  @type t :: %{
    id: String.t(),
    type: atom(),
    handler: handler(),
    config: map(),
    metadata: map()
  }
  
  @type handler :: (State.t(), config :: map() -> State.t())
end
```

### 2. **Edge** (Connection Between Nodes)

```elixir
defmodule Pipeline.Core.Edge do
  @type t :: %{
    from: Node.id(),
    to: Node.id() | :end,
    condition: condition()
  }
  
  @type condition :: :always | (State.t() -> boolean())
end
```

### 3. **State** (Immutable Data Container)

```elixir
defmodule Pipeline.Core.State do
  @type t :: %{
    data: map(),
    metadata: map(),
    version: integer()
  }
  
  @spec update(t(), changes :: map()) :: t()
  def update(state, changes) do
    %{state | 
      data: Map.merge(state.data, changes),
      version: state.version + 1
    }
  end
end
```

## Plugin Architecture

### 1. **Plugin Definition**

```elixir
defmodule Pipeline.Plugin do
  @doc """
  Defines the plugin behaviour.
  """
  
  @callback init(config :: map()) :: {:ok, state :: term()} | {:error, reason :: term()}
  @callback capabilities() :: [atom()]
  
  defmacro __using__(opts) do
    quote do
      @behaviour Pipeline.Plugin
      
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker
        }
      end
    end
  end
end
```

### 2. **Plugin Manager**

```elixir
defmodule Pipeline.PluginManager do
  use GenServer
  
  def register_plugin(plugin_module, config) do
    GenServer.call(__MODULE__, {:register, plugin_module, config})
  end
  
  def get_plugin(capability) do
    GenServer.call(__MODULE__, {:get_by_capability, capability})
  end
end
```

## Key Architectural Patterns

### 1. **Repository Pattern** (Data Access)

```elixir
defmodule Pipeline.Repository do
  @callback save(entity :: struct()) :: {:ok, struct()} | {:error, term()}
  @callback find(id :: term()) :: {:ok, struct()} | {:error, :not_found}
  @callback all(filters :: map()) :: [struct()]
end

defmodule Pipeline.Repositories.Graph do
  @behaviour Pipeline.Repository
  
  # Implementation can be swapped (ETS, PostgreSQL, etc.)
end
```

### 2. **Strategy Pattern** (Algorithms)

```elixir
defmodule Pipeline.Execution.Strategy do
  @callback execute(graph :: Graph.t(), state :: State.t()) :: {:ok, State.t()} | {:error, term()}
end

defmodule Pipeline.Execution.Sequential do
  @behaviour Pipeline.Execution.Strategy
  
  def execute(graph, state) do
    # Sequential execution logic
  end
end

defmodule Pipeline.Execution.Parallel do
  @behaviour Pipeline.Execution.Strategy
  
  def execute(graph, state) do
    # Parallel execution logic
  end
end
```

### 3. **Observer Pattern** (Events)

```elixir
defmodule Pipeline.Events do
  def emit(event_type, payload) do
    Registry.dispatch(Pipeline.Events, event_type, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:event, event_type, payload})
      end
    end)
  end
  
  def subscribe(event_type) do
    Registry.register(Pipeline.Events, event_type, [])
  end
end
```

## Quality Attributes

### 1. **Modularity**
- Bounded contexts with clear interfaces
- Minimal coupling between components
- High cohesion within components

### 2. **Testability**
- Dependency injection everywhere
- Pure functions for logic
- Mocks/stubs for external services

### 3. **Performance**
- Lazy evaluation where possible
- Efficient data structures
- Minimal allocations

### 4. **Observability**
- Structured logging
- Metrics collection
- Distributed tracing support

### 5. **Security**
- Input validation at boundaries
- Principle of least privilege
- Secure defaults

## Directory Structure

```
lib/
├── pipeline/
│   ├── core/           # Domain models (pure)
│   │   ├── graph.ex
│   │   ├── node.ex
│   │   ├── edge.ex
│   │   └── state.ex
│   │
│   ├── application/    # Use cases
│   │   ├── build_graph.ex
│   │   ├── execute_pipeline.ex
│   │   └── validate_pipeline.ex
│   │
│   ├── ports/          # Port definitions (behaviours)
│   │   ├── provider.ex
│   │   ├── storage.ex
│   │   └── serializer.ex
│   │
│   ├── adapters/       # Adapter implementations
│   │   ├── providers/
│   │   ├── storage/
│   │   └── serializers/
│   │
│   ├── plugins/        # Plugin system
│   │   ├── manager.ex
│   │   └── registry.ex
│   │
│   └── pipeline.ex     # Public API
```

## Migration Strategy

### Phase 1: Core Foundation
1. Implement domain models
2. Create port definitions
3. Build minimal adapters
4. Establish plugin system

### Phase 2: Feature Parity
1. Migrate existing functionality
2. Create compatibility layer
3. Build migration tools

### Phase 3: Advanced Features
1. Performance optimizations
2. Advanced plugin ecosystem
3. Cloud-native features

## Conclusion

This architecture provides:
- **Flexibility**: Easy to extend and modify
- **Maintainability**: Clear boundaries and responsibilities
- **Testability**: Everything can be tested in isolation
- **Performance**: Efficient by design
- **Developer Experience**: Intuitive and hard to misuse

The rebuild focuses on creating a solid foundation that can evolve with changing requirements while maintaining backward compatibility where needed.