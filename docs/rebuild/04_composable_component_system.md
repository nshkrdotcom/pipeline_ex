# Composable Component System

## Overview

The composable component system is the heart of Pipeline.ex v2's flexibility. It enables developers to build complex pipelines by combining simple, reusable components in intuitive ways. This document details how components compose, interact, and maintain their contracts.

## Design Philosophy

### Core Principles

1. **Composition over Inheritance**: Build complex behavior by combining simple components
2. **Explicit over Implicit**: All compositions are explicit and traceable
3. **Type-Safe Composition**: Compile-time guarantees where possible
4. **Functional Composition**: Pure functions that combine predictably
5. **Context Preservation**: Composed components maintain their context

## Component Categories

### 1. Atomic Components (Indivisible Units)

```elixir
defmodule Pipeline.Components.Atomic do
  @moduledoc """
  Base atomic components that cannot be decomposed further.
  """
  
  defmodule Transform do
    @behaviour Pipeline.Component
    
    @impl true
    def process(data, config) do
      # Pure transformation
      {:ok, transform_data(data, config)}
    end
    
    @impl true
    def compose(_other) do
      {:error, :atomic_component}
    end
  end
  
  defmodule Validate do
    @behaviour Pipeline.Component
    
    @impl true
    def process(data, config) do
      case validate_data(data, config.schema) do
        :ok -> {:ok, data}
        {:error, errors} -> {:error, {:validation_failed, errors}}
      end
    end
  end
end
```

### 2. Composite Components (Combinations)

```elixir
defmodule Pipeline.Components.Composite do
  @moduledoc """
  Components built from other components.
  """
  
  defmodule Sequential do
    @behaviour Pipeline.Component
    
    defstruct components: []
    
    @impl true
    def process(data, %__MODULE__{components: components}) do
      Enum.reduce_while(components, {:ok, data}, fn component, {:ok, acc} ->
        case component.process(acc, component.config) do
          {:ok, result} -> {:cont, {:ok, result}}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
    
    @impl true
    def compose(%__MODULE__{} = other) do
      {:ok, %__MODULE__{components: components ++ other.components}}
    end
  end
  
  defmodule Parallel do
    @behaviour Pipeline.Component
    
    defstruct components: [], strategy: :all
    
    @impl true
    def process(data, %__MODULE__{components: components, strategy: strategy}) do
      tasks = Enum.map(components, fn component ->
        Task.async(fn -> component.process(data, component.config) end)
      end)
      
      results = Task.await_many(tasks)
      
      case strategy do
        :all -> merge_all_results(results)
        :first -> first_success(results)
        :majority -> majority_consensus(results)
      end
    end
  end
end
```

### 3. Higher-Order Components (Component Transformers)

```elixir
defmodule Pipeline.Components.HigherOrder do
  @moduledoc """
  Components that transform other components.
  """
  
  defmodule Retry do
    @behaviour Pipeline.Component
    
    defstruct component: nil, max_attempts: 3, backoff: :exponential
    
    @impl true
    def process(data, %__MODULE__{component: component, max_attempts: max} = config) do
      retry_with_backoff(
        fn -> component.process(data, component.config) end,
        max,
        config.backoff
      )
    end
    
    @impl true
    def compose(other) do
      {:ok, %__MODULE__{component: other}}
    end
  end
  
  defmodule Cache do
    @behaviour Pipeline.Component
    
    defstruct component: nil, ttl: 300, key_fn: nil
    
    @impl true
    def process(data, %__MODULE__{component: component} = config) do
      cache_key = compute_key(data, config.key_fn)
      
      case get_from_cache(cache_key) do
        {:ok, cached} -> 
          {:ok, cached}
        :miss ->
          case component.process(data, component.config) do
            {:ok, result} = success ->
              put_in_cache(cache_key, result, config.ttl)
              success
            error ->
              error
          end
      end
    end
  end
  
  defmodule RateLimited do
    @behaviour Pipeline.Component
    
    defstruct component: nil, rate: 10, window: :second
    
    @impl true
    def process(data, %__MODULE__{component: component} = config) do
      case acquire_token(config.rate, config.window) do
        :ok ->
          component.process(data, component.config)
        :rate_limited ->
          {:error, :rate_limited}
      end
    end
  end
end
```

## Composition Patterns

### 1. Pipeline Composition

```elixir
defmodule Pipeline.Composition do
  @moduledoc """
  Composition utilities for building complex pipelines.
  """
  
  import Pipeline.Operators
  
  @doc """
  Sequential composition using the pipe operator.
  
  ## Example
      
      pipeline = 
        load_data()
        ~> validate(schema)
        ~> transform(rules)
        ~> enrich(api_client)
        ~> save()
  """
  def sequential(components) when is_list(components) do
    %Pipeline.Components.Composite.Sequential{
      components: components
    }
  end
  
  @doc """
  Parallel composition with different strategies.
  
  ## Example
      
      analyzer = 
        parallel([
          sentiment_analysis(),
          entity_extraction(),
          language_detection()
        ], strategy: :all)
  """
  def parallel(components, opts \\ []) do
    %Pipeline.Components.Composite.Parallel{
      components: components,
      strategy: opts[:strategy] || :all
    }
  end
  
  @doc """
  Conditional composition based on data.
  
  ## Example
      
      router = 
        conditional(
          fn data -> data.type end,
          %{
            image: image_processor(),
            text: text_processor(),
            video: video_processor()
          },
          default: error_handler()
        )
  """
  def conditional(condition_fn, branches, opts \\ []) do
    %Pipeline.Components.Composite.Conditional{
      condition: condition_fn,
      branches: branches,
      default: opts[:default]
    }
  end
end
```

### 2. Component Operators

```elixir
defmodule Pipeline.Operators do
  @moduledoc """
  Operators for intuitive component composition.
  """
  
  @doc """
  Sequential composition operator.
  
      a ~> b  # a then b
  """
  def a ~> b do
    Pipeline.Composition.sequential([a, b])
  end
  
  @doc """
  Parallel composition operator.
  
      a <|> b  # a and b in parallel
  """
  def a <|> b do
    Pipeline.Composition.parallel([a, b])
  end
  
  @doc """
  Alternative composition operator.
  
      a <~> b  # try a, fallback to b
  """
  def a <~> b do
    Pipeline.Components.Composite.Alternative.new(a, b)
  end
  
  @doc """
  Transformation operator.
  
      component >>> transformer  # wrap component
  """
  def component >>> transformer do
    transformer.compose(component)
  end
end
```

### 3. Builder Pattern

```elixir
defmodule Pipeline.Builder do
  @moduledoc """
  Fluent interface for building complex components.
  """
  
  defstruct components: [], modifiers: []
  
  def new do
    %__MODULE__{}
  end
  
  def add(builder, component) do
    %{builder | components: builder.components ++ [component]}
  end
  
  def with_retry(builder, opts \\ []) do
    modifier = {:retry, opts}
    %{builder | modifiers: builder.modifiers ++ [modifier]}
  end
  
  def with_cache(builder, opts \\ []) do
    modifier = {:cache, opts}
    %{builder | modifiers: builder.modifiers ++ [modifier]}
  end
  
  def with_timeout(builder, timeout) do
    modifier = {:timeout, timeout}
    %{builder | modifiers: builder.modifiers ++ [modifier]}
  end
  
  def build(builder) do
    base = Pipeline.Composition.sequential(builder.components)
    
    Enum.reduce(builder.modifiers, base, fn
      {:retry, opts}, component ->
        %Pipeline.Components.HigherOrder.Retry{
          component: component,
          max_attempts: opts[:max_attempts] || 3
        }
        
      {:cache, opts}, component ->
        %Pipeline.Components.HigherOrder.Cache{
          component: component,
          ttl: opts[:ttl] || 300
        }
        
      {:timeout, timeout}, component ->
        %Pipeline.Components.HigherOrder.Timeout{
          component: component,
          timeout: timeout
        }
    end)
  end
end

# Usage example
pipeline = 
  Pipeline.Builder.new()
  |> Pipeline.Builder.add(load_step)
  |> Pipeline.Builder.add(validate_step)
  |> Pipeline.Builder.add(transform_step)
  |> Pipeline.Builder.with_retry(max_attempts: 5)
  |> Pipeline.Builder.with_cache(ttl: 600)
  |> Pipeline.Builder.build()
```

## Component Contracts

### 1. Interface Contract

```elixir
defmodule Pipeline.Component do
  @moduledoc """
  Core behaviour that all components must implement.
  """
  
  @type data :: term()
  @type config :: term()
  @type result :: {:ok, data()} | {:error, reason :: term()}
  
  @doc "Process data through the component"
  @callback process(data(), config()) :: result()
  
  @doc "Compose with another component"
  @callback compose(component :: t()) :: {:ok, t()} | {:error, reason :: term()}
  
  @doc "Component metadata"
  @callback metadata() :: %{
    name: String.t(),
    version: String.t(),
    input_schema: term(),
    output_schema: term()
  }
  
  @doc "Validate component configuration"
  @callback validate_config(config()) :: :ok | {:error, reason :: term()}
  
  @optional_callbacks [compose: 1, validate_config: 1]
end
```

### 2. Composition Rules

```elixir
defmodule Pipeline.Composition.Rules do
  @moduledoc """
  Rules and validation for component composition.
  """
  
  @doc """
  Check if two components can be composed.
  """
  def composable?(component_a, component_b) do
    with :ok <- matching_schemas?(component_a, component_b),
         :ok <- compatible_types?(component_a, component_b),
         :ok <- resource_compatible?(component_a, component_b) do
      true
    else
      _ -> false
    end
  end
  
  defp matching_schemas?(a, b) do
    a_meta = a.metadata()
    b_meta = b.metadata()
    
    if Schema.compatible?(a_meta.output_schema, b_meta.input_schema) do
      :ok
    else
      {:error, :schema_mismatch}
    end
  end
  
  defp compatible_types?(a, b) do
    # Check if component types can be composed
    # e.g., can't compose two exclusive resources
    :ok
  end
end
```

## Advanced Composition Patterns

### 1. Lens-Based Composition

```elixir
defmodule Pipeline.Components.Lens do
  @moduledoc """
  Focus on and transform parts of complex data structures.
  """
  
  defstruct focus: nil, component: nil
  
  def new(path, component) when is_list(path) do
    %__MODULE__{
      focus: path,
      component: component
    }
  end
  
  def process(data, %__MODULE__{focus: path, component: component}) do
    case get_in(data, path) do
      nil ->
        {:error, :path_not_found}
      focused_data ->
        case component.process(focused_data, component.config) do
          {:ok, result} ->
            {:ok, put_in(data, path, result)}
          error ->
            error
        end
    end
  end
end

# Usage
user_name_normalizer = 
  Pipeline.Components.Lens.new(
    [:user, :profile, :name],
    Pipeline.Components.Atomic.Transform.new(:normalize_name)
  )
```

### 2. Monadic Composition

```elixir
defmodule Pipeline.Components.Monadic do
  @moduledoc """
  Monadic composition for complex error handling and state.
  """
  
  defmodule Result do
    defstruct [:value, :errors, :warnings, :metadata]
    
    def ok(value, metadata \\ %{}) do
      %__MODULE__{value: {:ok, value}, metadata: metadata}
    end
    
    def error(error, metadata \\ %{}) do
      %__MODULE__{value: {:error, error}, metadata: metadata}
    end
    
    def bind(%__MODULE__{value: {:ok, value}} = result, fun) do
      case fun.(value) do
        %__MODULE__{} = new_result ->
          merge_results(result, new_result)
        other ->
          %__MODULE__{value: other, metadata: result.metadata}
      end
    end
    
    def bind(%__MODULE__{value: {:error, _}} = result, _fun) do
      result
    end
  end
end
```

### 3. Streaming Composition

```elixir
defmodule Pipeline.Components.Stream do
  @moduledoc """
  Components that work with streams of data.
  """
  
  defmodule Map do
    defstruct component: nil
    
    def process(stream, %__MODULE__{component: component}) do
      mapped_stream = Stream.map(stream, fn item ->
        case component.process(item, component.config) do
          {:ok, result} -> result
          {:error, _} -> nil  # Or handle errors differently
        end
      end)
      
      {:ok, mapped_stream}
    end
  end
  
  defmodule Batch do
    defstruct component: nil, size: 100
    
    def process(stream, %__MODULE__{component: component, size: size}) do
      batched_stream = 
        stream
        |> Stream.chunk_every(size)
        |> Stream.map(fn batch ->
          component.process(batch, component.config)
        end)
      
      {:ok, batched_stream}
    end
  end
end
```

## Component Registry

```elixir
defmodule Pipeline.Components.Registry do
  @moduledoc """
  Central registry for discovering and managing components.
  """
  
  use GenServer
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def register(component_module, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register, component_module, metadata})
  end
  
  def lookup(name) do
    GenServer.call(__MODULE__, {:lookup, name})
  end
  
  def search(criteria) do
    GenServer.call(__MODULE__, {:search, criteria})
  end
  
  # Find components that can process certain data types
  def find_compatible(input_schema, output_schema) do
    GenServer.call(__MODULE__, {:find_compatible, input_schema, output_schema})
  end
end
```

## Testing Composable Components

```elixir
defmodule Pipeline.Components.Test do
  @moduledoc """
  Testing utilities for components.
  """
  
  defmacro assert_composable(component_a, component_b) do
    quote do
      assert Pipeline.Composition.Rules.composable?(
        unquote(component_a), 
        unquote(component_b)
      )
    end
  end
  
  def mock_component(process_fn, metadata \\ %{}) do
    %Pipeline.Components.Mock{
      process_fn: process_fn,
      metadata: metadata
    }
  end
  
  def test_composition(components, test_data) do
    composed = Pipeline.Composition.sequential(components)
    composed.process(test_data, composed.config)
  end
end
```

## Performance Considerations

### 1. Lazy Composition
```elixir
defmodule Pipeline.Components.Lazy do
  @moduledoc """
  Lazy evaluation of component chains.
  """
  
  def lazy_sequential(component_fns) do
    %{
      type: :lazy_sequential,
      thunks: component_fns,
      process: fn data, _config ->
        Enum.reduce_while(component_fns, {:ok, data}, fn thunk, {:ok, acc} ->
          case thunk.() |> apply(:process, [acc, %{}]) do
            {:ok, result} -> {:cont, {:ok, result}}
            error -> {:halt, error}
          end
        end)
      end
    }
  end
end
```

### 2. Compile-Time Optimization
```elixir
defmodule Pipeline.Components.Compiler do
  @moduledoc """
  Compile-time optimization of component chains.
  """
  
  defmacro compile_pipeline(components) do
    # Analyze and optimize at compile time
    optimized = optimize_component_chain(components)
    quote do
      unquote(optimized)
    end
  end
  
  defp optimize_component_chain(components) do
    components
    |> merge_adjacent_transforms()
    |> eliminate_redundant_validations()
    |> inline_simple_components()
  end
end
```

## Best Practices

1. **Keep Components Pure**: Side effects at the edges only
2. **Design for Composition**: Make components naturally composable
3. **Use Type Contracts**: Define clear input/output schemas
4. **Fail Fast**: Validate early in the composition chain
5. **Document Composition**: Make component relationships clear

## Conclusion

The composable component system provides a powerful, flexible foundation for building complex pipelines from simple, reusable parts. By following functional programming principles and providing clear contracts, components can be combined in predictable, type-safe ways to create sophisticated data processing pipelines.