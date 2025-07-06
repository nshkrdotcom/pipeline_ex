# State Generalization Requirements for Pipeline_ex

## Executive Summary

To achieve feature parity with LangGraph and transform Pipeline_ex from a framework into a universal library, we need to fundamentally redesign state management. This document outlines the specific requirements and changes needed to support generalized, type-safe, and extensible state management.

## Core Requirements

### 1. Programmatic State Definition

**Current**: State structure is implicit and scattered across modules.

**Required**: Users must be able to define custom state schemas programmatically.

```elixir
# User-defined state schema
defmodule MyAgentState do
  use Pipeline.State.Schema
  
  state_field :messages, {:array, Message}, reducer: :append
  state_field :current_agent, :string
  state_field :tool_calls, {:array, ToolCall}, reducer: :append
  state_field :metadata, {:map, :string, :any}, reducer: :deep_merge
end

# Usage in graph definition
graph = Pipeline.Graph.new(state_schema: MyAgentState)
```

### 2. Type-Safe State Access

**Current**: Direct map access with string keys, no compile-time safety.

**Required**: Structured access with validation and type checking.

```elixir
# Instead of:
state.results["step_name"]["content"]

# We need:
state.messages |> List.last() |> Map.get(:content)
# With compile-time field verification
```

### 3. Reducer-Based State Updates

**Current**: Direct map updates with `Map.put` and manual merging.

**Required**: Declarative reducers that define how state updates are combined.

```elixir
defmodule Pipeline.State.Reducers do
  # Built-in reducers
  def append(old_list, new_items), do: old_list ++ List.wrap(new_items)
  def replace(_old, new), do: new
  def merge(old_map, new_map), do: Map.merge(old_map, new_map)
  def deep_merge(old, new), do: DeepMerge.deep_merge(old, new)
  
  # Custom reducers
  def merge_with_timestamp(old, new) do
    Map.merge(old, new, fn _k, _v1, v2 -> 
      {v2, DateTime.utc_now()}
    end)
  end
end
```

### 4. State Channels (Critical for Graphs)

**Current**: All state updates go to a single context map.

**Required**: Named channels for different aspects of state, similar to LangGraph.

```elixir
# Define multiple state channels
defmodule MultiAgentState do
  use Pipeline.State.Schema
  
  channel :messages do
    state_field :history, {:array, Message}, reducer: :append
    state_field :pending, {:array, Message}, reducer: :replace
  end
  
  channel :routing do
    state_field :next_agent, :string
    state_field :previous_agents, {:array, :string}, reducer: :append
  end
  
  channel :shared_memory do
    state_field :facts, {:map, :string, :string}, reducer: :merge
    state_field :decisions, {:array, Decision}, reducer: :append
  end
end
```

### 5. State Persistence Interface

**Current**: Hardcoded checkpoint format tied to specific state structure.

**Required**: Pluggable persistence with schema-aware serialization.

```elixir
defmodule Pipeline.State.Persistence do
  @callback save(state :: struct(), metadata :: map()) :: {:ok, reference} | {:error, term()}
  @callback load(reference :: term()) :: {:ok, state :: struct()} | {:error, term()}
  @callback list(filter :: map()) :: {:ok, [reference]} | {:error, term()}
end

# Implementations
defmodule Pipeline.State.Persistence.FileSystem do
  @behaviour Pipeline.State.Persistence
  # Implementation...
end

defmodule Pipeline.State.Persistence.Redis do
  @behaviour Pipeline.State.Persistence
  # Implementation...
end
```

### 6. State Validation and Constraints

**Current**: Limited validation, mostly for step outputs.

**Required**: Comprehensive state validation with custom rules.

```elixir
defmodule AgentStateWithValidation do
  use Pipeline.State.Schema
  
  state_field :messages, {:array, Message} do
    reducer :append
    validate :max_messages_limit
    validate {:min_items, 1}
  end
  
  state_field :temperature, :float do
    validate {:in_range, 0.0, 2.0}
  end
  
  @impl true
  def validate_max_messages_limit(messages) do
    if length(messages) <= 100 do
      :ok
    else
      {:error, "Message history exceeds 100 messages"}
    end
  end
end
```

### 7. State Streaming and Observability

**Current**: Limited visibility into state changes.

**Required**: Stream of state updates for debugging and monitoring.

```elixir
# Stream state changes
Pipeline.Graph.stream(compiled_graph, initial_state)
|> Stream.map(fn {node_name, state_before, state_after} ->
  changes = Pipeline.State.diff(state_before, state_after)
  Logger.info("Node #{node_name} modified: #{inspect(changes)}")
  state_after
end)
```

### 8. State Migration System

**Current**: No support for state schema evolution.

**Required**: Versioned schemas with migration support.

```elixir
defmodule MyStateV2 do
  use Pipeline.State.Schema
  
  version 2
  
  migrates_from MyStateV1 do
    # Define migration logic
    add_field :new_field, default: "value"
    rename_field :old_name, :new_name
    transform_field :messages, &migrate_message_format/1
  end
end
```

## Implementation Requirements

### 1. State Schema DSL

Create a macro-based DSL for defining state schemas:

```elixir
defmodule Pipeline.State.Schema do
  defmacro __using__(_opts) do
    quote do
      import Pipeline.State.Schema
      @before_compile Pipeline.State.Schema
      
      Module.register_attribute(__MODULE__, :state_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :state_channels, accumulate: true)
      Module.register_attribute(__MODULE__, :state_validators, accumulate: true)
    end
  end
  
  defmacro state_field(name, type, opts \\ []) do
    # Implementation
  end
  
  defmacro channel(name, do: block) do
    # Implementation
  end
end
```

### 2. State Update Engine

Replace direct map updates with a reducer-based engine:

```elixir
defmodule Pipeline.State.Engine do
  def update_state(state_schema, current_state, updates) do
    # 1. Validate updates against schema
    # 2. Apply reducers for each field
    # 3. Run post-update validations
    # 4. Return new state or error
  end
  
  def apply_reducer(field_spec, old_value, new_value) do
    case field_spec.reducer do
      :append -> old_value ++ List.wrap(new_value)
      :replace -> new_value
      :merge -> Map.merge(old_value, new_value)
      custom when is_function(custom) -> custom.(old_value, new_value)
    end
  end
end
```

### 3. State Access API

Provide both dynamic and compile-time safe access:

```elixir
defmodule Pipeline.State.Access do
  # Dynamic access (current style)
  def get_field(state, field_path) when is_list(field_path) do
    get_in(state, field_path)
  end
  
  # Compile-time safe access via macros
  defmacro state_get(state, field_path) do
    # Verify field exists in schema at compile time
    # Generate optimized access code
  end
end
```

### 4. Integration with Execution

Modify the executor to work with structured state:

```elixir
defmodule Pipeline.Executor do
  def execute_with_schema(workflow, initial_state, opts) do
    state_schema = Keyword.fetch!(opts, :state_schema)
    
    # Validate initial state
    {:ok, state} = state_schema.validate(initial_state)
    
    # Execute with state tracking
    execute_steps(workflow.steps, state, state_schema)
  end
  
  defp update_step_state(state, step_updates, state_schema) do
    Pipeline.State.Engine.update_state(state_schema, state, step_updates)
  end
end
```

## Migration Strategy

### Phase 1: Foundation (Weeks 1-2)
1. Implement basic state schema DSL
2. Create state validation engine
3. Add reducer system
4. Build state access API

### Phase 2: Integration (Weeks 3-4)
1. Integrate with existing executor
2. Maintain backward compatibility
3. Create migration utilities
4. Add comprehensive tests

### Phase 3: Advanced Features (Weeks 5-6)
1. Implement state channels
2. Add persistence interface
3. Create state migration system
4. Build debugging tools

### Phase 4: Polish (Week 7-8)
1. Performance optimization
2. Documentation
3. Migration guides
4. Example applications

## Benefits of Generalized State

1. **Type Safety**: Catch errors at compile time
2. **Self-Documentation**: State structure is explicit
3. **Reusability**: Users can share state schemas
4. **Debugging**: Clear view of state changes
5. **Testing**: Easy to create test states
6. **Evolution**: Handle schema changes gracefully
7. **Integration**: Works with external tools
8. **Performance**: Optimized access patterns

## Conclusion

Implementing these state generalization requirements will transform Pipeline_ex from a rigid framework into a flexible library that rivals LangGraph's capabilities while leveraging Elixir's strengths. The investment in proper state management will pay dividends in developer experience, maintainability, and extensibility.