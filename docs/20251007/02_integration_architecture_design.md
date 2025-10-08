# Enterprise Integration Architecture Design

**Date:** 2025-10-07
**Version:** 1.0
**Status:** Detailed Design Specification
**Companion Document:** `01_enterprise_feasibility_assessment.md`

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Core Integration Layers](#2-core-integration-layers)
3. [Snakepit Integration Patterns](#3-snakepit-integration-patterns)
4. [Distributed State Management](#4-distributed-state-management)
5. [Evaluation Pipeline Integration](#5-evaluation-pipeline-integration)
6. [External Service Integration](#6-external-service-integration)
7. [Data Flow & Protocols](#7-data-flow--protocols)
8. [Implementation Specifications](#8-implementation-specifications)

---

## 1. Architecture Overview

### 1.1 Design Principles

The integration architecture follows these core principles:

1. **Elixir-First** - Leverage OTP capabilities before external integrations
2. **Fail-Fast with Recovery** - Embrace let-it-crash, but recover gracefully
3. **Observable by Default** - Every integration point emits telemetry
4. **Polyglot When Needed** - Use Snakepit for Python-specific capabilities
5. **Stateless Workers** - State lives in distributed stores, not processes
6. **Contract-Based** - All integrations use explicit schemas/protocols

### 1.2 Layered Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Presentation Layer                         │
│  - CLI (Mix Tasks)                                              │
│  - HTTP API (optional Phoenix endpoint)                         │
│  - gRPC API (for external clients)                              │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│  - Pipeline.Orchestrator (main coordinator)                     │
│  - Pipeline.Evaluation.Manager (eval workflows)                 │
│  - Pipeline.Execution.Supervisor (process supervision)          │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                     Domain Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Step Engine  │  │ Eval Metrics │  │ State Mgmt   │          │
│  │ - Execution  │  │ - Calculators│  │ - Variables  │          │
│  │ - Validation │  │ - Aggregation│  │ - Checkpoints│          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                   Integration Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ AI Providers │  │ Snakepit     │  │ Storage      │          │
│  │ - Claude     │  │ - Python Pool│  │ - S3/Local   │          │
│  │ - Gemini     │  │ - gRPC Comms │  │ - ETS Cache  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                           │
│  - OTP (GenServer, Supervisor, Registry)                        │
│  - Distributed Erlang (clustering)                              │
│  - Telemetry (metrics, traces, logs)                            │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Process Topology

```
Pipeline.Application (Supervisor)
│
├── Pipeline.MonitoringRegistry (Registry)
│
├── Pipeline.ExecutionSupervisor (DynamicSupervisor)
│   ├── Pipeline.WorkflowRunner (GenServer) [per workflow]
│   ├── Pipeline.StepExecutor (Task) [per step]
│   └── Pipeline.Monitoring.Performance (GenServer) [per workflow]
│
├── Pipeline.CheckpointSupervisor (Supervisor)
│   ├── Pipeline.Checkpoint.LocalStore (GenServer)
│   ├── Pipeline.Checkpoint.S3Store (GenServer)
│   └── Pipeline.Checkpoint.Coordinator (GenServer)
│
├── Pipeline.EvaluationSupervisor (DynamicSupervisor)
│   ├── Pipeline.Evaluation.Runner (GenServer) [per eval suite]
│   └── Pipeline.Evaluation.MetricsCollector (GenServer)
│
├── Pipeline.SnakepitSupervisor (Supervisor)
│   ├── Snakepit.Pool (:eval_python_pool)
│   └── Snakepit.HealthCheck (GenServer)
│
└── Pipeline.TelemetrySupervisor (Supervisor)
    ├── TelemetryMetricsPrometheus (GenServer)
    └── OpenTelemetry.Exporter (GenServer) [optional]
```

---

## 2. Core Integration Layers

### 2.1 AI Provider Integration

#### 2.1.1 Provider Abstraction

```elixir
defmodule Pipeline.Providers.AIProvider do
  @moduledoc """
  Behaviour defining the contract for AI provider integrations.
  All providers (Claude, Gemini, future providers) must implement this.
  """

  @type provider_config :: map()
  @type prompt :: String.t() | list()
  @type options :: keyword()
  @type response :: %{
    content: String.t(),
    metadata: %{
      model: String.t(),
      tokens: %{input: pos_integer(), output: pos_integer()},
      cost: float(),
      latency_ms: pos_integer()
    }
  }

  @callback query(prompt, options) :: {:ok, response} | {:error, term()}
  @callback stream_query(prompt, options, handler :: function()) ::
    {:ok, response} | {:error, term()}
  @callback validate_config(provider_config) :: :ok | {:error, String.t()}
  @callback health_check() :: :ok | {:error, term()}

  @doc """
  Execute query with automatic retry and fallback.
  """
  def execute_with_fallback(providers, prompt, options \\ []) do
    providers
    |> Enum.reduce_while({:error, :no_providers}, fn provider, _acc ->
      case provider.query(prompt, options) do
        {:ok, result} -> {:halt, {:ok, result}}
        {:error, reason} ->
          Logger.warning("Provider #{inspect(provider)} failed: #{inspect(reason)}")
          {:cont, {:error, reason}}
      end
    end)
  end
end
```

#### 2.1.2 Provider Router

```elixir
defmodule Pipeline.Providers.Router do
  @moduledoc """
  Routes requests to appropriate AI provider based on:
  - Model requirements
  - Cost constraints
  - Availability/health
  - Load balancing
  """

  alias Pipeline.Providers.{ClaudeProvider, GeminiProvider}

  @type routing_strategy :: :cheapest | :fastest | :most_capable | :round_robin

  def route_request(prompt, options) do
    strategy = Keyword.get(options, :routing_strategy, :cheapest)
    providers = available_providers()

    case strategy do
      :cheapest ->
        providers
        |> Enum.sort_by(&estimate_cost(&1, prompt, options))
        |> List.first()

      :fastest ->
        providers
        |> Enum.min_by(&average_latency/1)

      :most_capable ->
        select_by_capability(providers, options[:required_capabilities])

      :round_robin ->
        # Use ETS counter for round-robin state
        index = :atomics.add_get(routing_counter(), 1, 1)
        Enum.at(providers, rem(index, length(providers)))
    end
  end

  defp available_providers do
    [ClaudeProvider, GeminiProvider]
    |> Enum.filter(&healthy?/1)
  end

  defp healthy?(provider) do
    case provider.health_check() do
      :ok -> true
      {:error, _} -> false
    end
  end

  defp estimate_cost(provider, prompt, options) do
    token_count = estimate_tokens(prompt)
    provider.cost_per_token() * token_count
  end
end
```

#### 2.1.3 Provider Circuit Breaker

```elixir
defmodule Pipeline.Providers.CircuitBreaker do
  @moduledoc """
  Circuit breaker pattern for AI provider calls.
  Prevents cascade failures when provider is down.
  """

  use GenServer

  @type state :: :closed | :open | :half_open
  @type config :: %{
    failure_threshold: pos_integer(),
    success_threshold: pos_integer(),
    timeout_ms: pos_integer(),
    half_open_timeout_ms: pos_integer()
  }

  defstruct [
    :provider,
    :state,
    :failure_count,
    :success_count,
    :last_failure_time,
    :config
  ]

  def call(provider, function, args, config \\ default_config()) do
    case get_state(provider) do
      :open ->
        # Circuit is open - fast fail
        {:error, :circuit_breaker_open}

      :half_open ->
        # Try one request to test recovery
        execute_with_state_transition(provider, function, args)

      :closed ->
        # Normal operation
        execute_with_monitoring(provider, function, args)
    end
  end

  defp execute_with_monitoring(provider, function, args) do
    start_time = System.monotonic_time(:millisecond)

    case apply(provider, function, args) do
      {:ok, result} = success ->
        record_success(provider)
        emit_telemetry(provider, function, success: true,
          latency: System.monotonic_time(:millisecond) - start_time)
        success

      {:error, reason} = error ->
        record_failure(provider, reason)
        emit_telemetry(provider, function, success: false,
          error: reason)

        # Check if should open circuit
        if should_open_circuit?(provider) do
          open_circuit(provider)
        end

        error
    end
  end

  defp should_open_circuit?(provider) do
    state = get_provider_state(provider)
    config = state.config

    state.failure_count >= config.failure_threshold
  end

  defp open_circuit(provider) do
    Logger.warning("Opening circuit breaker for provider: #{inspect(provider)}")

    update_state(provider, fn state ->
      %{state |
        state: :open,
        last_failure_time: DateTime.utc_now()
      }
    end)

    # Schedule half-open transition
    config = get_provider_state(provider).config
    Process.send_after(self(), {:transition_half_open, provider},
      config.half_open_timeout_ms)
  end

  # GenServer callbacks...
end
```

### 2.2 Result Storage Integration

#### 2.2.1 Multi-Backend Storage

```elixir
defmodule Pipeline.Storage.Backend do
  @moduledoc """
  Pluggable storage backend for checkpoints, results, and artifacts.
  """

  @callback write(key :: String.t(), data :: binary(), opts :: keyword()) ::
    {:ok, location :: String.t()} | {:error, term()}

  @callback read(key :: String.t(), opts :: keyword()) ::
    {:ok, binary()} | {:error, term()}

  @callback delete(key :: String.t(), opts :: keyword()) ::
    :ok | {:error, term()}

  @callback list(prefix :: String.t(), opts :: keyword()) ::
    {:ok, [String.t()]} | {:error, term()}
end

defmodule Pipeline.Storage.Coordinator do
  @moduledoc """
  Coordinates multi-backend storage with replication and failover.
  """

  @backends %{
    primary: Pipeline.Storage.S3Backend,
    cache: Pipeline.Storage.ETSBackend,
    archive: Pipeline.Storage.LocalBackend
  }

  def write(key, data, opts \\ []) do
    strategy = Keyword.get(opts, :replication, :primary_with_cache)

    case strategy do
      :primary_only ->
        primary_backend().write(key, data, opts)

      :primary_with_cache ->
        # Write to primary, async cache
        with {:ok, location} <- primary_backend().write(key, data, opts) do
          Task.start(fn -> cache_backend().write(key, data, opts) end)
          {:ok, location}
        end

      :replicate_all ->
        # Write to all backends, succeed if primary succeeds
        tasks =
          @backends
          |> Map.values()
          |> Enum.map(fn backend ->
            Task.async(fn -> backend.write(key, data, opts) end)
          end)

        # Wait for primary
        primary_result = Task.await(hd(tasks))

        # Don't wait for others (fire-and-forget)
        primary_result
    end
  end

  def read(key, opts \\ []) do
    # Try cache first, then primary, then archive
    case cache_backend().read(key, opts) do
      {:ok, data} ->
        {:ok, data}

      {:error, :not_found} ->
        case primary_backend().read(key, opts) do
          {:ok, data} = result ->
            # Async warm cache
            Task.start(fn -> cache_backend().write(key, data, []) end)
            result

          {:error, :not_found} ->
            archive_backend().read(key, opts)

          error ->
            error
        end

      error ->
        error
    end
  end

  defp primary_backend, do: @backends.primary
  defp cache_backend, do: @backends.cache
  defp archive_backend, do: @backends.archive
end
```

#### 2.2.2 S3 Backend Implementation

```elixir
defmodule Pipeline.Storage.S3Backend do
  @behaviour Pipeline.Storage.Backend

  alias ExAws.S3

  @bucket Application.compile_env(:pipeline, :s3_bucket)

  def write(key, data, opts) do
    bucket = Keyword.get(opts, :bucket, @bucket)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    put_opts = [
      content_type: content_type,
      metadata: build_metadata(opts)
    ]

    case S3.put_object(bucket, key, data, put_opts) |> ExAws.request() do
      {:ok, %{status_code: 200}} ->
        {:ok, "s3://#{bucket}/#{key}"}

      {:error, reason} ->
        Logger.error("S3 write failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def read(key, opts) do
    bucket = Keyword.get(opts, :bucket, @bucket)

    case S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status_code: 404}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("S3 read failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def list(prefix, opts) do
    bucket = Keyword.get(opts, :bucket, @bucket)

    case S3.list_objects_v2(bucket, prefix: prefix) |> ExAws.request() do
      {:ok, %{status_code: 200, body: %{contents: objects}}} ->
        keys = Enum.map(objects, & &1.key)
        {:ok, keys}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_metadata(opts) do
    %{
      "x-pipeline-version" => "1.0",
      "x-created-at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "x-workflow" => Keyword.get(opts, :workflow_name, "unknown")
    }
  end
end
```

#### 2.2.3 ETS Cache Backend

```elixir
defmodule Pipeline.Storage.ETSBackend do
  @behaviour Pipeline.Storage.Backend

  use GenServer

  @table :pipeline_storage_cache
  @max_size 1000
  @ttl_seconds 3600

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    table = :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Start TTL cleanup
    schedule_cleanup()

    {:ok, %{table: table, max_size: @max_size}}
  end

  def write(key, data, _opts) do
    expiry = System.system_time(:second) + @ttl_seconds
    :ets.insert(@table, {key, data, expiry})
    {:ok, "cache://#{key}"}
  end

  def read(key, _opts) do
    case :ets.lookup(@table, key) do
      [{^key, data, expiry}] ->
        if System.system_time(:second) < expiry do
          {:ok, data}
        else
          :ets.delete(@table, key)
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  def delete(key, _opts) do
    :ets.delete(@table, key)
    :ok
  end

  def list(prefix, _opts) do
    # Simple prefix matching (not efficient for large sets)
    keys =
      :ets.tab2list(@table)
      |> Enum.filter(fn {key, _data, _expiry} ->
        String.starts_with?(key, prefix)
      end)
      |> Enum.map(fn {key, _data, _expiry} -> key end)

    {:ok, keys}
  end

  # Cleanup expired entries
  def handle_info(:cleanup, state) do
    now = System.system_time(:second)

    :ets.select_delete(@table, [
      {{:"$1", :"$2", :"$3"},
       [{:<, :"$3", now}],
       [true]}
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Run every 5 minutes
    Process.send_after(self(), :cleanup, 300_000)
  end
end
```

---

## 3. Snakepit Integration Patterns

### 3.1 Pool Management

```elixir
defmodule Pipeline.Snakepit.Manager do
  @moduledoc """
  Manages Snakepit Python worker pools with health monitoring.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      # Main evaluation pool
      {Snakepit.Pool,
        name: :eval_python_pool,
        adapter: Snakepit.Adapters.Python,
        script: python_script_path("eval_metrics.py"),
        size: pool_size(),
        max_overflow: 10,
        worker_config: worker_config()
      },

      # Separate pool for model inference (memory-intensive)
      {Snakepit.Pool,
        name: :model_inference_pool,
        adapter: Snakepit.Adapters.Python,
        script: python_script_path("model_inference.py"),
        size: 2,  # Fewer workers due to memory
        max_overflow: 0,
        worker_config: %{
          memory_limit_mb: 2048,
          timeout_ms: 60_000
        }
      },

      # Health monitor
      Pipeline.Snakepit.HealthMonitor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp pool_size do
    Application.get_env(:pipeline, :python_pool_size, 5)
  end

  defp worker_config do
    %{
      memory_limit_mb: 512,
      cpu_limit_percent: 80,
      timeout_ms: 30_000,
      max_restarts: 3,
      restart_delay_ms: 1_000
    }
  end

  defp python_script_path(filename) do
    Path.join([
      :code.priv_dir(:pipeline),
      "python",
      filename
    ])
  end
end
```

### 3.2 Health Monitoring

```elixir
defmodule Pipeline.Snakepit.HealthMonitor do
  @moduledoc """
  Monitors health of Python worker pools and triggers recovery.
  """

  use GenServer

  @check_interval 30_000  # 30 seconds

  defstruct [
    :pools,
    :health_status,
    :consecutive_failures
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %__MODULE__{
      pools: [:eval_python_pool, :model_inference_pool],
      health_status: %{},
      consecutive_failures: %{}
    }

    schedule_health_check()
    {:ok, state}
  end

  def handle_info(:health_check, state) do
    new_state =
      Enum.reduce(state.pools, state, fn pool_name, acc ->
        case check_pool_health(pool_name) do
          :healthy ->
            update_health_status(acc, pool_name, :healthy, 0)

          :unhealthy ->
            failures = Map.get(acc.consecutive_failures, pool_name, 0) + 1
            new_acc = update_health_status(acc, pool_name, :unhealthy, failures)

            if failures >= 3 do
              Logger.error("Pool #{pool_name} unhealthy for #{failures} checks, restarting")
              restart_pool(pool_name)
              update_health_status(new_acc, pool_name, :restarting, 0)
            else
              new_acc
            end
        end
      end)

    schedule_health_check()
    {:noreply, new_state}
  end

  defp check_pool_health(pool_name) do
    case Snakepit.execute(pool_name, :health_check, [], timeout: 5_000) do
      {:ok, %{status: "ok"}} ->
        :healthy

      _ ->
        :unhealthy
    end
  rescue
    _ -> :unhealthy
  end

  defp restart_pool(pool_name) do
    # Snakepit should handle this internally
    # But we can also manually restart via Supervisor
    case Process.whereis(pool_name) do
      nil -> :ok
      pid ->
        Supervisor.terminate_child(Pipeline.Snakepit.Manager, pid)
        Supervisor.restart_child(Pipeline.Snakepit.Manager, pool_name)
    end
  end

  defp update_health_status(state, pool_name, status, failures) do
    %{state |
      health_status: Map.put(state.health_status, pool_name, status),
      consecutive_failures: Map.put(state.consecutive_failures, pool_name, failures)
    }
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @check_interval)
  end
end
```

### 3.3 Python Bridge Interface

```elixir
defmodule Pipeline.External.PythonBridge do
  @moduledoc """
  High-level interface to Python evaluation tools via Snakepit.
  Handles serialization, error recovery, and metric caching.
  """

  require Logger

  @type metric_result :: %{
    score: float(),
    metric: String.t(),
    metadata: map()
  }

  @doc """
  Calculate BLEU score with caching.
  """
  @spec calculate_bleu(String.t(), String.t(), keyword()) ::
    {:ok, metric_result()} | {:error, term()}
  def calculate_bleu(predicted, reference, opts \\ []) do
    # Check cache first
    cache_key = cache_key_for(:bleu, predicted, reference, opts)

    case get_cached_metric(cache_key) do
      {:ok, cached} ->
        Logger.debug("BLEU cache hit")
        {:ok, cached}

      {:error, :not_found} ->
        execute_python_metric(:calculate_bleu, [predicted, reference, opts],
          cache_key: cache_key,
          timeout: 5_000
        )
    end
  end

  @doc """
  Calculate embedding similarity using sentence-transformers.
  """
  @spec embedding_similarity(String.t(), String.t(), keyword()) ::
    {:ok, metric_result()} | {:error, term()}
  def embedding_similarity(text1, text2, opts \\ []) do
    model = Keyword.get(opts, :model, "all-MiniLM-L6-v2")

    execute_python_metric(:embedding_similarity, [text1, text2, model],
      pool: :model_inference_pool,
      timeout: 10_000
    )
  end

  @doc """
  Execute custom Python function with automatic retry.
  """
  def execute_function(function_name, args, opts \\ []) do
    pool = Keyword.get(opts, :pool, :eval_python_pool)
    timeout = Keyword.get(opts, :timeout, 30_000)
    retry_count = Keyword.get(opts, :retry, 3)

    execute_with_retry(pool, function_name, args, timeout, retry_count)
  end

  # Private functions

  defp execute_python_metric(function, args, opts) do
    pool = Keyword.get(opts, :pool, :eval_python_pool)
    timeout = Keyword.get(opts, :timeout, 30_000)
    cache_key = Keyword.get(opts, :cache_key)

    case Snakepit.execute(pool, function, args, timeout: timeout) do
      {:ok, result} ->
        # Cache if cache_key provided
        if cache_key do
          cache_metric(cache_key, result)
        end

        {:ok, standardize_metric_result(result)}

      {:error, :timeout} ->
        Logger.warning("Python metric timeout for #{function}")
        {:error, :timeout}

      {:error, reason} = error ->
        Logger.error("Python metric failed: #{inspect(reason)}")
        error
    end
  end

  defp execute_with_retry(_pool, _function, _args, _timeout, 0) do
    {:error, :max_retries_exceeded}
  end

  defp execute_with_retry(pool, function, args, timeout, retry_count) do
    case Snakepit.execute(pool, function, args, timeout: timeout) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when reason in [:timeout, :connection_refused] ->
        Logger.warning("Retrying Python call (#{retry_count} left): #{inspect(reason)}")
        :timer.sleep(backoff_delay(retry_count))
        execute_with_retry(pool, function, args, timeout, retry_count - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp backoff_delay(retries_left) do
    # Exponential backoff: 100ms, 200ms, 400ms
    round(100 * :math.pow(2, 3 - retries_left))
  end

  defp cache_key_for(metric, predicted, reference, opts) do
    # Simple hash-based cache key
    data = {metric, predicted, reference, opts}
    hash = :erlang.phash2(data)
    "metric_cache:#{metric}:#{hash}"
  end

  defp get_cached_metric(cache_key) do
    Pipeline.Storage.ETSBackend.read(cache_key, [])
  end

  defp cache_metric(cache_key, result) do
    # Cache for 1 hour
    Pipeline.Storage.ETSBackend.write(cache_key, result, ttl: 3600)
  end

  defp standardize_metric_result(result) when is_map(result) do
    %{
      score: Map.get(result, "score") || Map.get(result, :score) || 0.0,
      metric: Map.get(result, "metric") || Map.get(result, :metric) || "unknown",
      metadata: Map.drop(result, ["score", "metric", :score, :metric])
    }
  end
end
```

### 3.4 Python Script Structure

```python
# priv/python/eval_metrics.py
"""
Python evaluation metrics for Pipeline.
Compatible with Snakepit gRPC/MessagePack communication.
"""

import sys
import json
from typing import Dict, Any, List
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Import ML libraries (lazy load for faster startup)
_bleu_scorer = None
_rouge_scorer = None
_sentence_model = None

def health_check() -> Dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok", "version": "1.0"}

def calculate_bleu(predicted: str, reference: str, opts: Dict[str, Any]) -> Dict[str, Any]:
    """Calculate BLEU score."""
    global _bleu_scorer

    if _bleu_scorer is None:
        from nltk.translate.bleu_score import sentence_bleu
        _bleu_scorer = sentence_bleu

    n_gram = opts.get('n_gram', 4)
    weights = tuple([1.0/n_gram] * n_gram)

    reference_tokens = [reference.split()]
    predicted_tokens = predicted.split()

    try:
        score = _bleu_scorer(reference_tokens, predicted_tokens, weights=weights)
        return {
            'score': float(score),
            'n_gram': n_gram,
            'metric': 'bleu',
            'tokens_predicted': len(predicted_tokens),
            'tokens_reference': len(reference_tokens[0])
        }
    except Exception as e:
        logger.error(f"BLEU calculation failed: {e}")
        return {'score': 0.0, 'error': str(e), 'metric': 'bleu'}

def calculate_rouge(predicted: str, reference: str, opts: Dict[str, Any]) -> Dict[str, Any]:
    """Calculate ROUGE scores."""
    global _rouge_scorer

    if _rouge_scorer is None:
        from rouge_score import rouge_scorer as rs
        _rouge_scorer = rs

    rouge_type = opts.get('rouge_type', 'rouge-l')

    try:
        scorer = _rouge_scorer.RougeScorer([rouge_type], use_stemmer=True)
        scores = scorer.score(reference, predicted)

        return {
            'precision': float(scores[rouge_type].precision),
            'recall': float(scores[rouge_type].recall),
            'fmeasure': float(scores[rouge_type].fmeasure),
            'score': float(scores[rouge_type].fmeasure),  # Main score
            'metric': rouge_type
        }
    except Exception as e:
        logger.error(f"ROUGE calculation failed: {e}")
        return {'score': 0.0, 'error': str(e), 'metric': rouge_type}

def embedding_similarity(text1: str, text2: str, model_name: str) -> Dict[str, Any]:
    """Calculate cosine similarity using sentence embeddings."""
    global _sentence_model

    # Lazy load model (heavy)
    if _sentence_model is None:
        from sentence_transformers import SentenceTransformer, util
        _sentence_model = {
            'transformer': SentenceTransformer,
            'util': util,
            'models': {}
        }

    # Load specific model if not cached
    if model_name not in _sentence_model['models']:
        logger.info(f"Loading model: {model_name}")
        _sentence_model['models'][model_name] = _sentence_model['transformer'](model_name)

    try:
        model = _sentence_model['models'][model_name]
        embeddings = model.encode([text1, text2])
        similarity = _sentence_model['util'].cos_sim(embeddings[0], embeddings[1]).item()

        return {
            'similarity': float(similarity),
            'score': float(similarity),
            'model': model_name,
            'metric': 'embedding_similarity',
            'embedding_dim': len(embeddings[0])
        }
    except Exception as e:
        logger.error(f"Embedding similarity failed: {e}")
        return {'score': 0.0, 'error': str(e), 'metric': 'embedding_similarity'}

# Snakepit automatically handles function routing based on function name
```

---

## 4. Distributed State Management

### 4.1 Cluster Coordination

```elixir
defmodule Pipeline.Cluster.Coordinator do
  @moduledoc """
  Coordinates distributed pipeline execution across cluster.
  Uses libcluster for node discovery and Horde for distributed registry.
  """

  use GenServer

  alias Pipeline.Cluster.WorkDistributor

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Setup cluster with libcluster
    topologies = [
      gossip: [
        strategy: Cluster.Strategy.Gossip,
        config: [
          port: 45892,
          if_addr: "0.0.0.0",
          multicast_addr: "230.1.1.251",
          multicast_ttl: 1,
          secret: cluster_secret()
        ]
      ]
    ]

    {:ok, _pid} = Cluster.Supervisor.start_link(topologies)

    # Setup Horde for distributed process registry
    {:ok, _} = Horde.Registry.start_link(
      name: Pipeline.HordeRegistry,
      keys: :unique,
      members: :auto
    )

    {:ok, _} = Horde.DynamicSupervisor.start_link(
      name: Pipeline.HordeSupervisor,
      strategy: :one_for_one,
      members: :auto,
      distribution_strategy: Horde.UniformDistribution
    )

    {:ok, %{nodes: [Node.self()]}}
  end

  def handle_info({:nodeup, node}, state) do
    Logger.info("Node joined cluster: #{node}")

    # Trigger checkpoint synchronization
    Pipeline.Checkpoint.Sync.sync_with_node(node)

    {:noreply, %{state | nodes: [node | state.nodes]}}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.warning("Node left cluster: #{node}")

    # Redistribute work from failed node
    WorkDistributor.redistribute_from_node(node)

    {:noreply, %{state | nodes: List.delete(state.nodes, node)}}
  end

  defp cluster_secret do
    Application.get_env(:pipeline, :cluster_secret) ||
      raise "CLUSTER_SECRET environment variable required"
  end
end
```

### 4.2 Distributed Checkpoints

```elixir
defmodule Pipeline.Checkpoint.Distributed do
  @moduledoc """
  Distributed checkpoint storage with consensus.
  Uses CRDTs for conflict-free replication.
  """

  alias Pipeline.Checkpoint.CRDT

  @doc """
  Save checkpoint across cluster with quorum write.
  """
  def save_distributed(workflow_name, checkpoint_data) do
    nodes = [Node.self() | Node.list()]
    quorum_size = quorum(length(nodes))

    # Concurrent write to all nodes
    tasks =
      Enum.map(nodes, fn node ->
        Task.async(fn ->
          :rpc.call(node, Pipeline.CheckpointManager, :save, [workflow_name, checkpoint_data])
        end)
      end)

    # Wait for quorum
    results = Task.await_many(tasks, 5_000)

    successful = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)

    if successful >= quorum_size do
      {:ok, :quorum_reached}
    else
      {:error, :quorum_not_reached}
    end
  rescue
    e ->
      Logger.error("Distributed checkpoint save failed: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Load checkpoint with conflict resolution.
  """
  def load_distributed(workflow_name) do
    nodes = [Node.self() | Node.list()]

    # Read from all nodes
    checkpoints =
      Enum.map(nodes, fn node ->
        case :rpc.call(node, Pipeline.CheckpointManager, :load_latest, [workflow_name]) do
          {:ok, checkpoint} -> {node, checkpoint}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case checkpoints do
      [] ->
        {:error, :no_checkpoint}

      checkpoints ->
        # Resolve conflicts using timestamp (last-write-wins)
        {_node, latest} =
          Enum.max_by(checkpoints, fn {_node, cp} ->
            DateTime.to_unix(cp.timestamp)
          end)

        {:ok, latest}
    end
  end

  defp quorum(node_count) when node_count > 0 do
    div(node_count, 2) + 1
  end
end
```

---

## 5. Evaluation Pipeline Integration

### 5.1 Evaluation Orchestrator

```elixir
defmodule Pipeline.Evaluation.Orchestrator do
  @moduledoc """
  Orchestrates evaluation pipeline execution with parallel test execution.
  """

  use GenServer

  alias Pipeline.Evaluation.{TestSuite, MetricsCalculator, ResultAggregator}

  defstruct [
    :eval_id,
    :test_suite,
    :config,
    :results,
    :status,
    :start_time
  ]

  def start_evaluation(test_suite_path, config \\ %{}) do
    eval_id = generate_eval_id()

    {:ok, pid} = GenServer.start_link(__MODULE__, {eval_id, test_suite_path, config},
      name: via_tuple(eval_id))

    GenServer.cast(pid, :start)
    {:ok, eval_id}
  end

  def init({eval_id, test_suite_path, config}) do
    {:ok, test_suite} = TestSuite.load(test_suite_path)

    state = %__MODULE__{
      eval_id: eval_id,
      test_suite: test_suite,
      config: config,
      results: [],
      status: :initializing,
      start_time: DateTime.utc_now()
    }

    {:ok, state}
  end

  def handle_cast(:start, state) do
    Logger.info("Starting evaluation: #{state.eval_id}")

    # Execute test cases in parallel batches
    batch_size = Map.get(state.config, :batch_size, 10)

    results =
      state.test_suite.test_cases
      |> Enum.chunk_every(batch_size)
      |> Enum.flat_map(fn batch ->
        execute_batch_parallel(batch, state.config)
      end)

    # Aggregate results
    aggregated = ResultAggregator.aggregate(results)

    # Save results
    save_evaluation_results(state.eval_id, aggregated)

    Logger.info("Evaluation complete: #{state.eval_id}")

    {:noreply, %{state | results: aggregated, status: :completed}}
  end

  defp execute_batch_parallel(test_cases, config) do
    test_cases
    |> Enum.map(fn test_case ->
      Task.async(fn -> execute_test_case(test_case, config) end)
    end)
    |> Task.await_many(60_000)
  end

  defp execute_test_case(test_case, config) do
    # Run the pipeline/model
    {:ok, prediction} = run_pipeline(test_case.input, config)

    # Calculate metrics
    metrics = MetricsCalculator.calculate_all(
      prediction,
      test_case.expected_output,
      config.metrics
    )

    %{
      test_case_id: test_case.id,
      input: test_case.input,
      expected: test_case.expected_output,
      predicted: prediction,
      metrics: metrics,
      passed: all_metrics_pass?(metrics, config.thresholds)
    }
  end

  defp run_pipeline(input, config) do
    # Execute the pipeline being evaluated
    pipeline_path = Map.get(config, :pipeline_path)
    variables = %{"input" => input}

    case Pipeline.execute_workflow(pipeline_path, variables: variables) do
      {:ok, results} ->
        # Extract output from results
        output = extract_pipeline_output(results, config)
        {:ok, output}

      error ->
        error
    end
  end

  defp via_tuple(eval_id) do
    {:via, Registry, {Pipeline.MonitoringRegistry, "eval_#{eval_id}"}}
  end

  defp generate_eval_id do
    "eval_#{System.system_time(:millisecond)}_#{:rand.uniform(10000)}"
  end
end
```

### 5.2 Metrics Calculator

```elixir
defmodule Pipeline.Evaluation.MetricsCalculator do
  @moduledoc """
  Calculates evaluation metrics using both Elixir and Python implementations.
  """

  alias Pipeline.Evaluation.Metrics.{ExactMatch, LLMJudge}
  alias Pipeline.External.PythonBridge

  @type metric_config :: %{
    type: atom(),
    threshold: float(),
    opts: keyword()
  }

  @doc """
  Calculate all configured metrics for a prediction.
  """
  def calculate_all(predicted, expected, metric_configs) do
    metric_configs
    |> Enum.map(fn config ->
      Task.async(fn -> calculate_metric(predicted, expected, config) end)
    end)
    |> Task.await_many(30_000)
  end

  defp calculate_metric(predicted, expected, %{type: type} = config) do
    opts = Map.get(config, :opts, [])

    result =
      case type do
        # Elixir-based metrics
        :exact_match ->
          ExactMatch.calculate(predicted, expected, opts)

        :fuzzy_match ->
          Pipeline.Evaluation.Metrics.FuzzyMatch.calculate(predicted, expected, opts)

        :semantic_similarity ->
          LLMJudge.semantic_similarity(predicted, expected, opts)

        :faithfulness ->
          LLMJudge.faithfulness(predicted, expected, opts)

        # Python-based metrics (via Snakepit)
        :bleu ->
          PythonBridge.calculate_bleu(predicted, expected, opts)

        :rouge ->
          PythonBridge.calculate_rouge(predicted, expected, opts)

        :embedding_similarity ->
          PythonBridge.embedding_similarity(predicted, expected, opts)

        # Unknown metric
        _ ->
          {:error, :unknown_metric}
      end

    case result do
      {:ok, metric_result} ->
        %{
          type: type,
          score: metric_result.score,
          passed: metric_result.score >= Map.get(config, :threshold, 0.0),
          metadata: Map.get(metric_result, :metadata, %{})
        }

      {:error, reason} ->
        Logger.error("Metric calculation failed for #{type}: #{inspect(reason)}")
        %{
          type: type,
          score: 0.0,
          passed: false,
          error: reason
        }
    end
  end
end
```

---

## 6. External Service Integration

### 6.1 Telemetry & Monitoring

```elixir
defmodule Pipeline.Integration.Telemetry do
  @moduledoc """
  Telemetry integration for monitoring and observability.
  """

  def setup do
    # Attach telemetry handlers
    :telemetry.attach_many(
      "pipeline-integration-metrics",
      [
        [:pipeline, :provider, :query, :start],
        [:pipeline, :provider, :query, :stop],
        [:pipeline, :provider, :query, :exception],
        [:pipeline, :storage, :write, :start],
        [:pipeline, :storage, :write, :stop],
        [:pipeline, :python, :execute, :start],
        [:pipeline, :python, :execute, :stop],
        [:pipeline, :evaluation, :metric, :calculate]
      ],
      &handle_event/4,
      nil
    )
  end

  def handle_event([:pipeline, :provider, :query, :stop], measurements, metadata, _config) do
    # Emit Prometheus metrics
    TelemetryMetricsPrometheus.observe(
      :pipeline_provider_query_duration_seconds,
      measurements.duration,
      %{provider: metadata.provider, model: metadata.model}
    )

    TelemetryMetricsPrometheus.increment(
      :pipeline_provider_query_total,
      %{provider: metadata.provider, status: "success"}
    )

    # Emit OpenTelemetry span (if configured)
    if Application.get_env(:pipeline, :opentelemetry_enabled, false) do
      OpenTelemetry.Tracer.set_attribute(:provider, metadata.provider)
      OpenTelemetry.Tracer.set_attribute(:tokens, measurements.tokens)
      OpenTelemetry.Tracer.add_event("query_completed", %{
        duration_ms: measurements.duration
      })
    end
  end

  def handle_event([:pipeline, :python, :execute, :stop], measurements, metadata, _config) do
    TelemetryMetricsPrometheus.observe(
      :pipeline_python_execute_duration_seconds,
      measurements.duration,
      %{function: metadata.function, pool: metadata.pool}
    )
  end

  def handle_event([:pipeline, :evaluation, :metric, :calculate], measurements, metadata, _config) do
    TelemetryMetricsPrometheus.histogram(
      :pipeline_evaluation_metric_score,
      measurements.score,
      %{metric_type: metadata.metric_type}
    )
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
```

### 6.2 Secrets Management

```elixir
defmodule Pipeline.Integration.SecretsManager do
  @moduledoc """
  Integration with secrets management systems (Vault, AWS Secrets Manager).
  """

  @callback get_secret(key :: String.t()) :: {:ok, String.t()} | {:error, term()}

  def get_api_key(provider) do
    adapter = secrets_adapter()
    key = secret_key_for_provider(provider)

    case adapter.get_secret(key) do
      {:ok, secret} -> {:ok, secret}
      error -> error
    end
  end

  defp secrets_adapter do
    case Application.get_env(:pipeline, :secrets_backend) do
      :vault -> Pipeline.Integration.Secrets.VaultAdapter
      :aws -> Pipeline.Integration.Secrets.AWSAdapter
      :env -> Pipeline.Integration.Secrets.EnvAdapter
      _ -> Pipeline.Integration.Secrets.EnvAdapter
    end
  end

  defp secret_key_for_provider(:claude), do: "pipeline/claude_api_key"
  defp secret_key_for_provider(:gemini), do: "pipeline/gemini_api_key"
end

defmodule Pipeline.Integration.Secrets.VaultAdapter do
  @behaviour Pipeline.Integration.SecretsManager

  def get_secret(key) do
    # Use Vault library
    vault_addr = Application.get_env(:pipeline, :vault_addr)
    vault_token = System.get_env("VAULT_TOKEN")

    case Vault.read(vault_addr, key, vault_token) do
      {:ok, %{"data" => %{"value" => value}}} -> {:ok, value}
      error -> error
    end
  end
end
```

---

## 7. Data Flow & Protocols

### 7.1 Request Flow

```
Client Request
      │
      ├─→ Pipeline.Orchestrator
      │        │
      │        ├─→ Load Workflow Config (YAML)
      │        ├─→ Initialize Context
      │        ├─→ Start Performance Monitoring
      │        │
      │        └─→ Pipeline.Executor
      │                 │
      │                 ├─→ For Each Step:
      │                 │      │
      │                 │      ├─→ Load Checkpoint (if resuming)
      │                 │      ├─→ Validate Preconditions
      │                 │      ├─→ Execute Step
      │                 │      │     │
      │                 │      │     ├─→ AI Provider (Claude/Gemini)
      │                 │      │     │     │
      │                 │      │     │     ├─→ Circuit Breaker Check
      │                 │      │     │     ├─→ API Call
      │                 │      │     │     └─→ Telemetry Emission
      │                 │      │     │
      │                 │      │     ├─→ Snakepit (if Python metric)
      │                 │      │     │     │
      │                 │      │     │     ├─→ Pool Acquisition
      │                 │      │     │     ├─→ gRPC/MessagePack
      │                 │      │     │     └─→ Result Deserialization
      │                 │      │     │
      │                 │      │     └─→ Local Processing (Elixir)
      │                 │      │
      │                 │      ├─→ Store Result
      │                 │      │     │
      │                 │      │     ├─→ ResultManager (memory)
      │                 │      │     └─→ Multi-Backend Storage
      │                 │      │           │
      │                 │      │           ├─→ ETS Cache (fast)
      │                 │      │           └─→ S3/Local (persistent)
      │                 │      │
      │                 │      └─→ Save Checkpoint
      │                 │            │
      │                 │            ├─→ Serialize State
      │                 │            └─→ Distributed Write
      │                 │
      │                 └─→ Aggregate Results
      │                        │
      │                        └─→ Generate Report
      │
      └─→ Response to Client
```

### 7.2 Snakepit Communication Protocol

```
Elixir Process                           Python Worker
     │                                        │
     ├─→ Snakepit.execute(                   │
     │      pool: :eval_python_pool,         │
     │      function: :calculate_bleu,       │
     │      args: [pred, ref, opts]          │
     │   )                                    │
     │                                        │
     ├─────── gRPC Request ───────────────→  │
     │        (Protocol Buffer)               │
     │        {                                │
     │          function: "calculate_bleu",   │
     │          args: [...],                  │
     │          timeout_ms: 5000              │
     │        }                                │
     │                                        │
     │                                        ├─→ Deserialize Args
     │                                        ├─→ Execute Function
     │                                        ├─→ Calculate BLEU
     │                                        └─→ Serialize Result
     │                                        │
     │  ←─────── gRPC Response ─────────────  │
     │        (Protocol Buffer)               │
     │        {                                │
     │          success: true,                │
     │          result: {                     │
     │            score: 0.85,                │
     │            metric: "bleu"              │
     │          }                             │
     │        }                                │
     │                                        │
     │←─ {:ok, %{score: 0.85, ...}}          │
     │                                        │
```

### 7.3 Distributed Checkpoint Protocol

```
Node 1 (Primary)                Node 2                Node 3
     │                             │                    │
     ├─→ Save Checkpoint          │                    │
     │   (workflow state)          │                    │
     │                             │                    │
     ├────── Distributed Write ───┼───────────────────→│
     │      (Quorum = 2/3)         │                    │
     │                             │                    │
     │                             ├─→ Validate        │
     │                             ├─→ Write Local     │
     │                             └─→ ACK             │
     │                             │                    │
     │                             │                    ├─→ Validate
     │                             │                    ├─→ Write Local
     │                             │                    └─→ ACK
     │                             │                    │
     │ ←──────── Quorum Reached ──┴────────────────────┘
     │        (2 successful writes)
     │
     └─→ Checkpoint Confirmed
```

---

## 8. Implementation Specifications

### 8.1 Module Organization

```
lib/pipeline/
├── integration/
│   ├── ai_provider.ex          # Provider behaviour & router
│   ├── circuit_breaker.ex      # Circuit breaker pattern
│   ├── secrets_manager.ex      # Secrets management
│   └── telemetry.ex            # Telemetry integration
│
├── storage/
│   ├── backend.ex              # Storage backend behaviour
│   ├── coordinator.ex          # Multi-backend coordinator
│   ├── s3_backend.ex           # S3 implementation
│   ├── ets_backend.ex          # ETS cache implementation
│   └── local_backend.ex        # Local filesystem
│
├── external/
│   └── python_bridge.ex        # High-level Snakepit interface
│
├── snakepit/
│   ├── manager.ex              # Pool management
│   ├── health_monitor.ex       # Health checking
│   └── metrics_adapter.ex      # Metrics-specific adapter
│
├── evaluation/
│   ├── orchestrator.ex         # Eval orchestration
│   ├── test_suite.ex           # Test case management
│   ├── metrics_calculator.ex   # Metric calculation
│   ├── result_aggregator.ex    # Result aggregation
│   └── metrics/
│       ├── exact_match.ex      # Elixir metric
│       ├── fuzzy_match.ex      # Elixir metric
│       └── llm_judge.ex        # LLM-based evaluation
│
├── cluster/
│   ├── coordinator.ex          # Cluster coordination
│   ├── work_distributor.ex     # Work distribution
│   └── checkpoint_sync.ex      # Checkpoint synchronization
│
└── checkpoint/
    ├── distributed.ex          # Distributed checkpoints
    └── crdt.ex                 # Conflict resolution
```

### 8.2 Configuration Schema

```elixir
# config/config.exs
import Config

config :pipeline,
  # Clustering
  cluster_enabled: false,
  cluster_strategy: :gossip,
  cluster_secret: nil,

  # Storage
  checkpoint_backend: :local,  # :local | :s3 | :multi
  checkpoint_replication: :primary_with_cache,
  s3_bucket: nil,
  s3_region: "us-east-1",

  # Snakepit
  python_pool_size: 5,
  python_worker_memory_mb: 512,
  python_script_dir: "priv/python",

  # Evaluation
  eval_batch_size: 10,
  eval_parallel_workers: 5,

  # Monitoring
  telemetry_enabled: true,
  opentelemetry_enabled: false,
  prometheus_port: 9568,

  # Secrets
  secrets_backend: :env,  # :env | :vault | :aws
  vault_addr: nil

# Environment-specific overrides
import_config "#{config_env()}.exs"
```

### 8.3 Deployment Configuration

```yaml
# docker-compose.yml
version: '3.8'

services:
  pipeline_node_1:
    image: pipeline_ex:latest
    environment:
      - RELEASE_COOKIE=secret_cookie_for_clustering
      - RELEASE_NODE=pipeline1@pipeline_node_1
      - PIPELINE_CLUSTER_ENABLED=true
      - CHECKPOINT_BACKEND=s3
      - S3_CHECKPOINT_BUCKET=my-pipeline-checkpoints
      - PYTHON_POOL_SIZE=5
    volumes:
      - ./priv/python:/app/priv/python

  pipeline_node_2:
    image: pipeline_ex:latest
    environment:
      - RELEASE_COOKIE=secret_cookie_for_clustering
      - RELEASE_NODE=pipeline2@pipeline_node_2
      - PIPELINE_CLUSTER_ENABLED=true
      - CHECKPOINT_BACKEND=s3
      - S3_CHECKPOINT_BUCKET=my-pipeline-checkpoints

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

---

## Conclusion

This integration architecture provides a comprehensive, production-ready design for enterprise deployment of pipeline_ex with:

- **Elixir-first approach** leveraging OTP primitives
- **Strategic Snakepit integration** for Python-specific capabilities
- **Multi-backend storage** with replication and failover
- **Distributed coordination** for cluster deployments
- **Robust evaluation framework** for AI testing
- **Comprehensive observability** with telemetry and monitoring

All components are designed to be modular, testable, and independently deployable while maintaining strong integration contracts.

---

**Document Status:** Ready for Implementation
**Next Steps:** See `01_enterprise_feasibility_assessment.md` Phase 1-5 Roadmap
