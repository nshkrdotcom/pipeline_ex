# Core Abstractions and Interfaces

## Overview

This document defines the core abstractions and interfaces that form the foundation of Pipeline.ex v2. These abstractions are designed to be minimal, composable, and extensible while providing clear contracts for implementation.

## Core Domain Models

### 1. Node - The Unit of Computation

```elixir
defmodule Pipeline.Core.Node do
  @moduledoc """
  A Node represents a single unit of computation in a pipeline.
  It is pure data with no behavior - behavior is provided by handlers.
  """
  
  @type id :: String.t()
  @type node_type :: atom()
  @type metadata :: map()
  
  @type t :: %__MODULE__{
    id: id(),
    type: node_type(),
    config: map(),
    metadata: metadata()
  }
  
  @enforce_keys [:id, :type]
  defstruct [:id, :type, config: %{}, metadata: %{}]
  
  @doc "Create a new node"
  @spec new(id(), node_type(), config :: map()) :: t()
  def new(id, type, config \\ %{}) do
    %__MODULE__{
      id: id,
      type: type,
      config: config,
      metadata: %{created_at: DateTime.utc_now()}
    }
  end
end
```

### 2. Edge - Connections and Control Flow

```elixir
defmodule Pipeline.Core.Edge do
  @moduledoc """
  An Edge represents a connection between nodes with optional conditions.
  Edges define the control flow of the pipeline.
  """
  
  alias Pipeline.Core.Node
  
  @type edge_type :: :direct | :conditional | :parallel | :broadcast
  @type target :: Node.id() | :end | {:error, term()}
  @type condition :: (State.t() -> boolean()) | nil
  
  @type t :: %__MODULE__{
    from: Node.id(),
    to: target() | [target()],
    type: edge_type(),
    condition: condition(),
    metadata: map()
  }
  
  @enforce_keys [:from, :to]
  defstruct [:from, :to, type: :direct, condition: nil, metadata: %{}]
  
  @doc "Create a direct edge"
  @spec direct(Node.id(), Node.id()) :: t()
  def direct(from, to) do
    %__MODULE__{from: from, to: to, type: :direct}
  end
  
  @doc "Create a conditional edge"
  @spec conditional(Node.id(), condition(), target(), target()) :: t()
  def conditional(from, condition, true_branch, false_branch) do
    %__MODULE__{
      from: from,
      to: %{true: true_branch, false: false_branch},
      type: :conditional,
      condition: condition
    }
  end
  
  @doc "Create parallel edges (fork)"
  @spec parallel(Node.id(), [target()]) :: t()
  def parallel(from, targets) do
    %__MODULE__{from: from, to: targets, type: :parallel}
  end
end
```

### 3. Graph - The Pipeline Structure

```elixir
defmodule Pipeline.Core.Graph do
  @moduledoc """
  A Graph represents the complete pipeline structure.
  It is an immutable data structure that can be validated and executed.
  """
  
  alias Pipeline.Core.{Node, Edge}
  
  @type t :: %__MODULE__{
    id: String.t(),
    nodes: %{Node.id() => Node.t()},
    edges: [Edge.t()],
    entry_point: Node.id() | nil,
    metadata: map()
  }
  
  @enforce_keys [:id]
  defstruct [:id, :entry_point, nodes: %{}, edges: [], metadata: %{}]
  
  @doc "Create a new empty graph"
  @spec new(String.t()) :: t()
  def new(id) do
    %__MODULE__{id: id, metadata: %{version: "2.0"}}
  end
  
  @doc "Add a node to the graph"
  @spec add_node(t(), Node.t()) :: {:ok, t()} | {:error, :duplicate_node}
  def add_node(%__MODULE__{nodes: nodes} = graph, %Node{id: id} = node) do
    if Map.has_key?(nodes, id) do
      {:error, :duplicate_node}
    else
      {:ok, %{graph | nodes: Map.put(nodes, id, node)}}
    end
  end
  
  @doc "Add an edge to the graph"
  @spec add_edge(t(), Edge.t()) :: {:ok, t()} | {:error, term()}
  def add_edge(%__MODULE__{edges: edges} = graph, %Edge{} = edge) do
    with :ok <- validate_edge(graph, edge) do
      {:ok, %{graph | edges: [edge | edges]}}
    end
  end
  
  @doc "Set the entry point for the graph"
  @spec set_entry_point(t(), Node.id()) :: {:ok, t()} | {:error, :node_not_found}
  def set_entry_point(%__MODULE__{nodes: nodes} = graph, node_id) do
    if Map.has_key?(nodes, node_id) do
      {:ok, %{graph | entry_point: node_id}}
    else
      {:error, :node_not_found}
    end
  end
  
  # Private functions
  defp validate_edge(%{nodes: nodes}, %Edge{from: from}) do
    if Map.has_key?(nodes, from) do
      :ok
    else
      {:error, {:invalid_edge, :from_node_not_found}}
    end
  end
end
```

### 4. State - Immutable Data Container

```elixir
defmodule Pipeline.Core.State do
  @moduledoc """
  State represents the data flowing through the pipeline.
  It provides immutable updates and change tracking.
  """
  
  @type data :: map()
  @type version :: non_neg_integer()
  @type changes :: map()
  
  @type t :: %__MODULE__{
    data: data(),
    version: version(),
    changes: [changes()],
    metadata: map()
  }
  
  defstruct data: %{}, version: 0, changes: [], metadata: %{}
  
  @doc "Create a new state with initial data"
  @spec new(data()) :: t()
  def new(initial_data \\ %{}) do
    %__MODULE__{
      data: initial_data,
      metadata: %{created_at: DateTime.utc_now()}
    }
  end
  
  @doc "Update state with new data"
  @spec update(t(), changes()) :: t()
  def update(%__MODULE__{data: data, version: v, changes: history} = state, changes) do
    %{state |
      data: DeepMerge.deep_merge(data, changes),
      version: v + 1,
      changes: [%{version: v, changes: changes, timestamp: DateTime.utc_now()} | history]
    }
  end
  
  @doc "Get a value from state"
  @spec get(t(), key :: term(), default :: term()) :: term()
  def get(%__MODULE__{data: data}, key, default \\ nil) do
    Map.get(data, key, default)
  end
  
  @doc "Get nested value using path"
  @spec get_in(t(), [term()]) :: term()
  def get_in(%__MODULE__{data: data}, path) do
    Kernel.get_in(data, path)
  end
end
```

## Core Behaviours (Ports)

### 1. NodeHandler - Processing Logic

```elixir
defmodule Pipeline.NodeHandler do
  @moduledoc """
  Behaviour for implementing node processing logic.
  Handlers are stateless and pure functions.
  """
  
  alias Pipeline.Core.{Node, State}
  
  @doc """
  Process a node with the given state.
  Must return either updated state or an error.
  """
  @callback handle(node :: Node.t(), state :: State.t(), context :: map()) :: 
    {:ok, State.t()} | 
    {:error, reason :: term()} |
    {:suspend, State.t(), continuation :: term()}
    
  @doc """
  Validate node configuration.
  Called during graph construction.
  """
  @callback validate_config(config :: map()) :: 
    :ok | {:error, reason :: term()}
    
  @doc """
  Return metadata about the handler.
  """
  @callback metadata() :: %{
    name: String.t(),
    version: String.t(),
    capabilities: [atom()]
  }
  
  @optional_callbacks [validate_config: 1]
end
```

### 2. Provider - External Service Integration

```elixir
defmodule Pipeline.Provider do
  @moduledoc """
  Behaviour for external service providers (LLMs, APIs, etc).
  Providers handle all external communication.
  """
  
  @type config :: map()
  @type prompt :: String.t() | map()
  @type options :: keyword()
  @type response :: map()
  
  @doc "Initialize the provider with configuration"
  @callback init(config()) :: {:ok, state :: term()} | {:error, reason :: term()}
  
  @doc "Make a synchronous query"
  @callback query(prompt(), options(), state :: term()) :: 
    {:ok, response(), new_state :: term()} | 
    {:error, reason :: term()}
    
  @doc "Make a streaming query"
  @callback stream(prompt(), options(), state :: term()) ::
    {:ok, Enumerable.t(), new_state :: term()} |
    {:error, reason :: term()}
    
  @doc "Provider capabilities"
  @callback capabilities() :: %{
    streaming: boolean(),
    tools: boolean(),
    max_tokens: pos_integer(),
    models: [String.t()]
  }
  
  @optional_callbacks [stream: 3]
end
```

### 3. Storage - Persistence Layer

```elixir
defmodule Pipeline.Storage do
  @moduledoc """
  Behaviour for storage backends.
  Supports different storage strategies.
  """
  
  @type key :: term()
  @type value :: term()
  @type options :: keyword()
  
  @callback init(config :: map()) :: {:ok, state :: term()} | {:error, reason :: term()}
  
  @callback get(key(), state :: term()) :: 
    {:ok, value()} | {:error, :not_found | term()}
    
  @callback put(key(), value(), state :: term()) :: 
    {:ok, state :: term()} | {:error, reason :: term()}
    
  @callback delete(key(), state :: term()) :: 
    {:ok, state :: term()} | {:error, reason :: term()}
    
  @callback list(pattern :: term(), state :: term()) :: 
    {:ok, [{key(), value()}]} | {:error, reason :: term()}
    
  @callback transaction(fun :: (state :: term() -> term()), state :: term()) ::
    {:ok, result :: term(), state :: term()} | {:error, reason :: term()}
    
  @optional_callbacks [transaction: 2]
end
```

### 4. Validator - Data Validation

```elixir
defmodule Pipeline.Validator do
  @moduledoc """
  Behaviour for implementing validators.
  Validators can be composed and chained.
  """
  
  @type data :: term()
  @type schema :: term()
  @type errors :: [error()]
  @type error :: %{
    path: [term()],
    message: String.t(),
    rule: atom()
  }
  
  @callback validate(data(), schema()) :: :ok | {:error, errors()}
  
  @callback validate_partial(data(), schema()) :: 
    {:ok, valid_data :: term()} | {:error, errors()}
    
  @callback merge_errors(errors(), errors()) :: errors()
  
  @optional_callbacks [validate_partial: 2, merge_errors: 2]
end
```

### 5. Serializer - Format Conversion

```elixir
defmodule Pipeline.Serializer do
  @moduledoc """
  Behaviour for format serialization/deserialization.
  """
  
  @type format :: atom()
  
  @callback encode(data :: term(), opts :: keyword()) :: 
    {:ok, encoded :: binary()} | {:error, reason :: term()}
    
  @callback decode(encoded :: binary(), opts :: keyword()) :: 
    {:ok, data :: term()} | {:error, reason :: term()}
    
  @callback format() :: format()
  
  @callback extensions() :: [String.t()]
end
```

## Composite Interfaces

### 1. ExecutionEngine - Pipeline Execution

```elixir
defmodule Pipeline.ExecutionEngine do
  @moduledoc """
  The main interface for executing pipelines.
  Coordinates nodes, state, and control flow.
  """
  
  alias Pipeline.Core.{Graph, State}
  
  @type options :: [
    {:strategy, atom()},
    {:timeout, timeout()},
    {:telemetry, boolean()},
    {:checkpoint, boolean()}
  ]
  
  @doc "Execute a graph with initial state"
  @callback execute(Graph.t(), State.t(), options()) ::
    {:ok, State.t()} |
    {:error, reason :: term()} |
    {:suspended, State.t(), continuation :: term()}
    
  @doc "Resume a suspended execution"
  @callback resume(continuation :: term(), State.t()) ::
    {:ok, State.t()} |
    {:error, reason :: term()} |
    {:suspended, State.t(), continuation :: term()}
    
  @doc "Stream execution results"
  @callback stream(Graph.t(), State.t(), options()) :: Enumerable.t()
end
```

### 2. GraphBuilder - Programmatic Graph Construction

```elixir
defmodule Pipeline.GraphBuilder do
  @moduledoc """
  Fluent interface for building graphs programmatically.
  """
  
  alias Pipeline.Core.{Graph, Node, Edge}
  
  @type t :: %__MODULE__{
    graph: Graph.t(),
    current_node: Node.id() | nil,
    errors: [term()]
  }
  
  defstruct [:graph, :current_node, errors: []]
  
  @doc "Start building a new graph"
  def new(id) do
    %__MODULE__{graph: Graph.new(id)}
  end
  
  @doc "Add a node and make it current"
  def add_node(builder, id, type, config \\ %{})
  
  @doc "Connect current node to another"
  def connect_to(builder, target)
  
  @doc "Add conditional branching"
  def branch(builder, condition, true_branch, false_branch)
  
  @doc "Build the final graph"
  def build(builder)
end
```

### 3. Plugin - Extension System

```elixir
defmodule Pipeline.Plugin do
  @moduledoc """
  Behaviour for creating plugins.
  Plugins can extend any part of the system.
  """
  
  @type config :: map()
  @type capability :: atom()
  
  @callback init(config()) :: {:ok, state :: term()} | {:error, reason :: term()}
  
  @callback capabilities() :: [capability()]
  
  @callback handle_call(request :: term(), from :: GenServer.from(), state :: term()) ::
    {:reply, reply :: term(), state :: term()} |
    {:noreply, state :: term()}
    
  @callback handle_event(event :: term(), state :: term()) :: 
    {:ok, state :: term()} | {:error, reason :: term()}
    
  @optional_callbacks [handle_call: 3, handle_event: 2]
  
  defmacro __using__(opts) do
    quote do
      @behaviour Pipeline.Plugin
      use GenServer
      
      def start_link(config) do
        GenServer.start_link(__MODULE__, config, name: __MODULE__)
      end
      
      @impl GenServer
      def init(config) do
        case __MODULE__.init(config) do
          {:ok, state} -> {:ok, state}
          {:error, reason} -> {:stop, reason}
        end
      end
    end
  end
end
```

## Type Specifications

### Common Types

```elixir
defmodule Pipeline.Types do
  @moduledoc """
  Common type definitions used throughout the system.
  """
  
  @type result(ok) :: {:ok, ok} | {:error, reason :: term()}
  @type result(ok, error) :: {:ok, ok} | {:error, error}
  
  @type id :: String.t()
  @type config :: map()
  @type metadata :: map()
  @type timestamp :: DateTime.t()
  
  @type event :: {event_type :: atom(), payload :: map()}
  @type telemetry_metadata :: %{
    start_time: integer(),
    duration: integer(),
    node_id: id(),
    graph_id: id()
  }
end
```

## Interface Composition Examples

### Building Complex Behaviors

```elixir
# Composing validators
defmodule Pipeline.Validators.Composite do
  @behaviour Pipeline.Validator
  
  def new(validators) do
    %{validators: validators}
  end
  
  @impl true
  def validate(data, %{validators: validators}) do
    validators
    |> Enum.reduce({:ok, data}, fn
      validator, {:ok, data} -> validator.validate(data)
      _validator, error -> error
    end)
  end
end

# Composing node handlers
defmodule Pipeline.NodeHandlers.Pipeline do
  @moduledoc "A handler that executes another pipeline"
  @behaviour Pipeline.NodeHandler
  
  @impl true
  def handle(%{config: %{pipeline: pipeline_id}}, state, context) do
    sub_pipeline = Pipeline.Registry.get_pipeline(pipeline_id)
    Pipeline.execute(sub_pipeline, state, context: context)
  end
end
```

## Design Principles

1. **Interface Segregation**: Small, focused interfaces
2. **Dependency Inversion**: Depend on abstractions, not concretions
3. **Open/Closed**: Open for extension, closed for modification
4. **Single Responsibility**: Each interface has one reason to change
5. **Composability**: Interfaces can be combined to create complex behaviors

## Conclusion

These core abstractions provide the foundation for a flexible, extensible pipeline system. By keeping interfaces minimal and focused, we enable maximum composability while maintaining clarity and type safety.