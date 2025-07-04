# ELIXIR_DEV_GUIDE.md

Building fault-tolerant, maintainable Elixir/OTP systems starts with a clear philosophy and disciplined patterns. This guide shows you how to create a per-user rate limiter from scratch—complete with specs, docs, tests, telemetry, and CI.

---

## 1. Core Philosophy

Every OTP system rests on a handful of rules. Keep these at the forefront as you design:

- Processes are your unit of work and failure isolation.
- Embrace “Let It Crash” rather than littering code with defensive `try/rescue`.  
- Supervisors only start, stop, and restart children. They never hold business logic.
- Any long-lived process belongs under a supervisor. Do not `spawn/1`, `spawn_link/1`, or call `Task.start_link/1` manually.
- Avoid `Process.sleep/1`. If you find yourself polling or sleeping, refactor to an asynchronous, message-driven design.  

---

## 2. Project Setup

```bash
mix new rate_limiter --sup
cd rate_limiter
```

This generates:

- `mix.exs`  
- `lib/rate_limiter/application.ex` — your application’s root supervisor.  

Add dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:telemetry, "~> 1.0"},
    {:telemetry_metrics, "~> 0.6"},
    {:dialyxir, "~> 1.1", only: [:dev], runtime: false}
  ]
end
```

Run:

```bash
mix deps.get
mix dialyzer --plt
```

---

## 3. Application Supervision Tree

Open `lib/rate_limiter/application.ex` and wire up your top-level children:

```elixir
defmodule RateLimiter.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: RateLimiter.BucketRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: RateLimiter.BucketSupervisor},
      RateLimiter.Metrics   # Telemetry reporter (optional)
    ]

    opts = [strategy: :one_for_one, name: RateLimiter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## 4. Bucket GenServer

State: timestamps of recent requests.  

`lib/rate_limiter/bucket.ex`:

```elixir
defmodule RateLimiter.Bucket do
  @moduledoc """
  Tracks request timestamps for one user over a sliding time window.
  """

  use GenServer
  require Logger

  @max_requests 5
  @window_ms    60_000

  @type state :: [integer()]

  @doc """
  Starts the bucket linked to the current process.
  Name is given via `:name` for Registry lookup.
  """
  @spec start_link(name: GenServer.name()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc """
  Returns `:ok` if under limit, else `:error`.
  """
  @spec check_and_update(GenServer.name()) :: :ok | :error | {:error, :noproc}
  def check_and_update(name) do
    GenServer.call(name, :check_and_update, 5_000)
  end

  ## Callbacks

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
  def handle_call(:check_and_update, _from, timestamps) do
    now = System.monotonic_time(:millisecond)

    valid = Enum.filter(timestamps, fn ts -> now - ts < @window_ms end)

    case length(valid) < @max_requests do
      true ->
        :telemetry.execute([:rate_limiter, :allowed], %{count: 1})
        {:reply, :ok, [now | valid]}

      false ->
        :telemetry.execute([:rate_limiter, :denied], %{count: 1})
        {:reply, :error, valid}
    end
  end
end
```

---

## 5. Dynamic Supervisor & Registry

`lib/rate_limiter/bucket_supervisor.ex`:

```elixir
defmodule RateLimiter.BucketSupervisor do
  @moduledoc false
  use DynamicSupervisor

  @doc false
  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Ensures one bucket per `user_id`. Returns `{:ok, pid}` or error.
  """
  @spec start_bucket(term()) :: DynamicSupervisor.on_start_child()
  def start_bucket(user_id) do
    child = {RateLimiter.Bucket, name: via_name(user_id)}
    DynamicSupervisor.start_child(__MODULE__, child)
  end

  @doc """
  Registry lookup tuple for a user’s bucket.
  """
  @spec via_name(term()) :: {:via, Registry, {module(), term()}}
  def via_name(user_id) do
    {:via, Registry, {RateLimiter.BucketRegistry, user_id}}
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
```

---

## 6. Public API

`lib/rate_limiter.ex`:

```elixir
defmodule RateLimiter do
  @moduledoc """
  Facade for checking per-user rate limits.
  """

  @spec allowed?(term()) :: boolean()
  def allowed?(user_id) do
    name = RateLimiter.BucketSupervisor.via_name(user_id)

    case RateLimiter.Bucket.check_and_update(name) do
      :ok -> true
      :error -> false
      {:error, :noproc} -> create_and_retry(user_id)
    end
  end

  defp create_and_retry(user_id) do
    case RateLimiter.BucketSupervisor.start_bucket(user_id) do
      {:ok, _pid} -> true
      {:error, {:already_started, _pid}} -> allowed?(user_id)
      {:error, reason} ->
        Logger.error("Bucket start failed for #{inspect(user_id)}: #{inspect(reason)}")
        false
    end
  end
end
```

---

## 7. Telemetry & Metrics

Add a telemetry reporter:

`lib/rate_limiter/metrics.ex`:

```elixir
defmodule RateLimiter.Metrics do
  use Supervisor
  import Telemetry.Metrics

  def start_link(_), do: Supervisor.start_link(__MODULE__, :ok)

  def init(:ok) do
    metrics = [
      counter("rate_limiter.allowed.count"),
      counter("rate_limiter.denied.count")
    ]

    children = [
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics, period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

This emits counts to the console every 10 seconds.

---

## 8. Testing with ExUnit

Example spec for `Bucket`:

`test/rate_limiter/bucket_test.exs`:

```elixir
defmodule RateLimiter.BucketTest do
  use ExUnit.Case, async: true

  setup do
    name = :test_bucket
    {:ok, pid} = RateLimiter.Bucket.start_link(name: name)
    %{name: name, pid: pid}
  end

  test "allows up to max requests within window", %{name: name} do
    1..5 |> Enum.each(fn _ -> assert :ok = RateLimiter.Bucket.check_and_update(name) end)
    assert :error = RateLimiter.Bucket.check_and_update(name)
  end
end
```

Run:

```bash
mix test
```

---

## 9. Dialyzer & CI

Add to `.github/workflows/ci.yml`:

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.15"
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix dialyzer
      - run: mix test
```

---

## 10. Next Steps

- **TTL eviction**: periodically prune idle buckets or leverage `:ets` with `:heir` for fast access.  
- **Distributed mode**: swap `Registry` for `Swarm` or `Horde` for clustering.  
- **Backoff strategies**: implement exponential backoff for repeated denials.  
- **Dashboard**: hook into Prometheus via `telemetry_metrics_prometheus` for real-time monitoring.  

With these patterns—OTP structuring, specs, docs, telemetry, tests, and CI—you’ll build Elixir systems that are resilient, observable, and easy to evolve.
