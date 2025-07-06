# LangGraph Parity Implementation Roadmap

## Vision

Transform Pipeline_ex from a YAML-driven framework into a programmatic, extensible library that matches LangGraph's flexibility while leveraging Elixir's strengths. This roadmap follows the epic structure outlined in the provided document, with specific implementation details for achieving feature parity.

## Epic 1: Establish a Core Programmatic API

### Goal
Enable users to define and run pipelines entirely in Elixir code, without YAML files.

### Implementation Plan

#### 1.1 Create Pipeline.Graph Module (Week 1)

```elixir
defmodule Pipeline.Graph do
  defstruct nodes: %{}, 
            edges: %{}, 
            state_schema: nil, 
            entry_point: nil,
            conditional_edges: %{},
            metadata: %{}
  
  @type t :: %__MODULE__{
    nodes: %{String.t() => node_function()},
    edges: %{String.t() => String.t() | :end},
    state_schema: module() | nil,
    entry_point: String.t() | nil,
    conditional_edges: %{String.t() => conditional_edge()},
    metadata: map()
  }
  
  @type node_function :: (state :: map(), config :: map()) -> map()
  @type conditional_edge :: %{
    router: (state :: map()) -> String.t() | :end,
    mapping: %{String.t() => String.t()}
  }
end
```

#### 1.2 Graph Building API (Week 1)

```elixir
defmodule Pipeline.Graph do
  def new(opts \\ []) do
    state_schema = Keyword.get(opts, :state_schema)
    %__MODULE__{state_schema: state_schema}
  end
  
  def add_node(graph, name, function) when is_function(function, 2) do
    %{graph | nodes: Map.put(graph.nodes, name, function)}
  end
  
  def set_entry_point(graph, node_name) do
    %{graph | entry_point: node_name}
  end
  
  def add_edge(graph, from, to) do
    %{graph | edges: Map.put(graph.edges, from, to)}
  end
  
  def add_conditional_edges(graph, from, router, mapping) do
    conditional = %{router: router, mapping: mapping}
    %{graph | conditional_edges: Map.put(graph.conditional_edges, from, conditional)}
  end
end
```

#### 1.3 Graph Compilation and Execution (Week 2)

```elixir
defmodule Pipeline.Graph.Compiler do
  def compile(graph) do
    with :ok <- validate_graph_structure(graph),
         :ok <- validate_node_connectivity(graph),
         :ok <- validate_state_schema(graph) do
      {:ok, %Pipeline.Graph.Compiled{
        graph: graph,
        execution_order: topological_sort(graph),
        state_validator: build_state_validator(graph.state_schema)
      }}
    end
  end
end

defmodule Pipeline.Graph.Runtime do
  def stream(compiled_graph, initial_state, opts \\ []) do
    Stream.unfold(
      {initial_state, compiled_graph.execution_order},
      &execute_next_node/1
    )
  end
  
  def invoke(compiled_graph, initial_state, opts \\ []) do
    stream(compiled_graph, initial_state, opts)
    |> Enum.to_list()
    |> List.last()
  end
end
```

#### 1.4 Refactor Existing Executor (Week 2)

- Current YAML-based executor becomes a wrapper
- YAML parser builds Pipeline.Graph using new API
- Core execution logic moves to Graph.Runtime

### Deliverables
- [ ] Pipeline.Graph module with building API
- [ ] Graph compiler with validation
- [ ] Streaming execution engine
- [ ] YAML compatibility layer
- [ ] "Hello World" example working

## Epic 2: Decouple the Ecosystem for Extensibility

### Goal
Allow users to bring their own AI providers, tools, and state management.

### Implementation Plan

#### 2.1 Formalize AIProvider Behaviour (Week 3)

```elixir
defmodule Pipeline.Providers.Behaviour do
  @callback initialize(config :: map()) :: {:ok, state :: term()} | {:error, term()}
  @callback query(prompt :: term(), options :: map(), state :: term()) :: 
    {:ok, response :: term(), new_state :: term()} | {:error, term()}
  @callback stream(prompt :: term(), options :: map(), state :: term()) ::
    {:ok, stream :: Enumerable.t(), new_state :: term()} | {:error, term()}
end

# Example implementation
defmodule MyCustomProvider do
  @behaviour Pipeline.Providers.Behaviour
  
  def initialize(config) do
    # Provider-specific initialization
  end
  
  def query(prompt, options, state) do
    # Provider-specific query logic
  end
end
```

#### 2.2 Pluggable Tool Registry (Week 3)

```elixir
defmodule Pipeline.Tools.Registry do
  use GenServer
  
  # Public API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end
  
  def register(registry \\ __MODULE__, tool_module) do
    GenServer.call(registry, {:register, tool_module})
  end
  
  def list_tools(registry \\ __MODULE__) do
    GenServer.call(registry, :list_tools)
  end
  
  def get_tool(registry \\ __MODULE__, name) do
    GenServer.call(registry, {:get_tool, name})
  end
end

# Usage in graph
def my_agent_node(state, config) do
  registry = config[:tool_registry] || Pipeline.Tools.Registry
  tools = Pipeline.Tools.Registry.list_tools(registry)
  # Use tools...
end
```

#### 2.3 State Schema Support (Week 4)

Using Exdantic for state definition:

```elixir
defmodule Pipeline.State do
  defmacro defstate(name, do: block) do
    quote do
      defmodule unquote(name) do
        use Exdantic, define_struct: true
        
        schema "Pipeline State" do
          unquote(block)
        end
        
        # Add state-specific helpers
        def new(attrs \\ %{}) do
          __MODULE__.new!(attrs)
        end
        
        def update(state, changes) do
          Pipeline.State.Engine.update(state, changes, __MODULE__)
        end
      end
    end
  end
end

# User defines their state
Pipeline.State.defstate MyAgentState do
  field :messages, {:array, :map} do
    required()
    default([])
  end
  
  field :current_agent, :string do
    optional()
  end
  
  field :context, :map do
    default(%{})
  end
end
```

### Deliverables
- [ ] Provider behaviour and adapter system
- [ ] Pluggable tool registry
- [ ] State schema support via Exdantic
- [ ] Migration guide for existing providers

## Epic 3: Improve Developer Experience and Documentation

### Goal
Make the library approachable and ready for community adoption.

### Implementation Plan

#### 3.1 Getting Started Guide (Week 5)

Create comprehensive documentation:
- `GETTING_STARTED.md` - Build first agent in 5 minutes
- `docs/core_concepts.md` - State, Nodes, Edges explained
- `docs/api_reference.md` - Complete API documentation
- `docs/migration_from_yaml.md` - For existing users

#### 3.2 Example Applications (Week 5)

```elixir
# examples/basic_agent.exs
defmodule BasicAgent do
  def build_graph do
    Pipeline.Graph.new()
    |> Pipeline.Graph.add_node("agent", &agent_node/2)
    |> Pipeline.Graph.set_entry_point("agent")
  end
  
  def agent_node(state, _config) do
    # Simple agent logic
    %{messages: state.messages ++ [%{role: "assistant", content: "Hello!"}]}
  end
end

# examples/multi_agent.exs
defmodule MultiAgent do
  def build_graph do
    Pipeline.Graph.new(state_schema: MultiAgentState)
    |> Pipeline.Graph.add_node("supervisor", &supervisor_node/2)
    |> Pipeline.Graph.add_node("researcher", &researcher_node/2)
    |> Pipeline.Graph.add_node("writer", &writer_node/2)
    |> Pipeline.Graph.set_entry_point("supervisor")
    |> Pipeline.Graph.add_conditional_edges("supervisor", &route_task/1, %{
      "research" => "researcher",
      "write" => "writer",
      "done" => :end
    })
  end
end
```

#### 3.3 Hex.pm Preparation (Week 6)

- Clean up mix.exs for library publication
- Add proper package metadata
- Define public API modules
- Set up documentation generation
- Create CHANGELOG.md

### Deliverables
- [ ] Comprehensive documentation
- [ ] 5+ example applications
- [ ] Hex.pm package ready
- [ ] Documentation site (ExDoc)

## Epic 4: Generalize Advanced Features

### Goal
Transform framework-specific features into reusable library components.

### Implementation Plan

#### 4.1 Agentified Pipeline Generator (Week 7)

```elixir
defmodule Pipeline.Generators.PipelineBuilder do
  @moduledoc """
  A pre-built graph that generates other graphs from natural language.
  """
  
  def build_generator_graph do
    Pipeline.Graph.new(state_schema: GeneratorState)
    |> Pipeline.Graph.add_node("understand_request", &understand_request/2)
    |> Pipeline.Graph.add_node("design_pipeline", &design_pipeline/2)
    |> Pipeline.Graph.add_node("generate_code", &generate_code/2)
    |> Pipeline.Graph.add_node("validate_pipeline", &validate_pipeline/2)
    |> Pipeline.Graph.set_entry_point("understand_request")
    |> Pipeline.Graph.add_edge("understand_request", "design_pipeline")
    |> Pipeline.Graph.add_edge("design_pipeline", "generate_code")
    |> Pipeline.Graph.add_edge("generate_code", "validate_pipeline")
  end
  
  # Usage
  def generate_pipeline(description) do
    graph = build_generator_graph()
    {:ok, compiled} = Pipeline.Graph.compile(graph)
    
    initial_state = %GeneratorState{
      request: description,
      target_language: "elixir"
    }
    
    Pipeline.Graph.invoke(compiled, initial_state)
  end
end
```

#### 4.2 OpenTelemetry Integration (Week 8)

```elixir
defmodule Pipeline.Telemetry do
  def setup do
    # Attach to pipeline telemetry events
    :telemetry.attach_many(
      "pipeline-otel",
      [
        [:pipeline, :node, :start],
        [:pipeline, :node, :stop],
        [:pipeline, :graph, :start],
        [:pipeline, :graph, :stop]
      ],
      &handle_event/4,
      nil
    )
  end
  
  defp handle_event([:pipeline, :node, :start], measurements, metadata, _) do
    # Create OpenTelemetry span
    ctx = OpenTelemetry.Tracer.start_span("pipeline.node.#{metadata.node_name}")
    # Store context for later
  end
end
```

### Deliverables
- [ ] Pipeline generator as a reusable graph
- [ ] OpenTelemetry integration
- [ ] Performance profiling tools
- [ ] Advanced examples repository

## Timeline Summary

### Phase 1: Core API (Weeks 1-2)
- Graph building API
- Execution engine
- Basic examples working

### Phase 2: Extensibility (Weeks 3-4)
- Provider abstraction
- Tool registry
- State schemas

### Phase 3: Developer Experience (Weeks 5-6)
- Documentation
- Examples
- Hex.pm preparation

### Phase 4: Advanced Features (Weeks 7-8)
- Generator graph
- Telemetry
- Performance tools

## Success Metrics

1. **API Simplicity**: "Hello World" agent in < 20 lines of code
2. **Performance**: < 10% overhead vs direct execution
3. **Adoption**: 50+ GitHub stars within 3 months
4. **Community**: 5+ community-contributed providers
5. **Documentation**: 100% public API documented

## Migration Strategy for Existing Users

1. **Compatibility Mode**: YAML files continue to work
2. **Migration Tool**: Automated YAML → Code converter
3. **Gradual Adoption**: Mix YAML and code approaches
4. **Documentation**: Step-by-step migration guide

## Conclusion

This roadmap transforms Pipeline_ex into a true LangGraph competitor while preserving its unique strengths. The key is maintaining backward compatibility while opening up the programmatic API that modern developers expect. By following this plan, Pipeline_ex will become the go-to choice for building AI applications in Elixir.