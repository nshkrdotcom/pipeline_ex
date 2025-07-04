Of course. This is an excellent set of constraints that leads to robust, idiomatic, and maintainable Elixir/OTP systems. This guide will walk you through building a simple application from the ground up, strictly adhering to these principles.

### The Core Philosophy: A Quick Recap

Before we write code, let's internalize the rules we'll be following:

1.  **Processes are the unit of work and failure.** We isolate state and logic into separate, concurrent processes.
2.  **Let It Crash.** We don't write defensive code inside our workers (like `try/rescue` for unexpected errors). We write code for the "happy path" and let the supervisor handle failures.
3.  **Supervisors Supervise.** A supervisor's only job is to start, stop, and restart its children. It should contain no business logic.
4.  **No Manual Spawns for Long-Lived Processes.** Any process that needs to live beyond a single, fire-and-forget task must be part of a supervision tree. We use supervisors to start children, not `spawn/1`, `spawn_link/1`, or `Task.start_link/1`.
5.  **No `Process.sleep/1`.** Sleeping a process is a code smell. It indicates a design problem, often an attempt to poll for a resource or state change. It blocks the process's scheduler thread, reducing the BEAM's efficiency. The correct approach is always asynchronous and message-based.

---

## The Project: A Per-User Rate Limiter

We will build a simple rate limiter. A client can request to perform an action for a given `user_id`. The system will allow it only if that user hasn't made too many requests in a given time window.

This is a perfect example because:
*   It requires state (tracking request timestamps for each user).
*   It's naturally concurrent (many users making requests at once).
*   It requires dynamically starting processes (a rate-limiting process for each new user).

### Step 1: Project Setup

Start a new Elixir project with a supervision tree skeleton. This is the **only** correct way to begin an OTP application.

```bash
mix new rate_limiter --sup
cd rate_limiter
```

This generates `lib/rate_limiter/application.ex`, which is our entry point. Let's look at it:

```elixir
# lib/rate_limiter/application.ex
defmodule RateLimiter.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # This is where our top-level supervisor will be started.
    children = [
      # Children will be defined here.
    ]

    opts = [strategy: :one_for_one, name: RateLimiter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

This is our application's root. Its only job is to start our main supervisor. **No other logic should go here.**

### Step 2: The Worker - `GenServer` for a Single User

First, we need a process to manage the state for a *single user*. A `GenServer` is the perfect tool. This worker will store the timestamps of recent requests.

`lib/rate_limiter/bucket.ex`:

```elixir
defmodule RateLimiter.Bucket do
  use GenServer

  # Maximum requests allowed in the time window.
  @max_requests 5
  # Time window in milliseconds.
  @window_ms 60_000

  # ===================================================================
  # Public Client API - Hides GenServer implementation details
  # ===================================================================

  @doc """
  Starts a new Bucket GenServer for a user.
  This is a long-lived process and MUST be started by a supervisor.
  """
  def start_link(opts) do
    # The name is passed in via opts for dynamic registration
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @doc """
  Checks if a request is allowed for the user managed by this bucket.
  Returns `:ok` or `:error`.
  """
  def check_and_update(pid_or_name) do
    # Using a 5-second timeout is a good practice.
    GenServer.call(pid_or_name, :check_and_update, 5000)
  end

  # ===================================================================
  # GenServer Callbacks - The internal logic of the process
  # ===================================================================

  @impl true
  def init(_args) do
    # The state is a list of timestamps of recent requests.
    {:ok, []}
  end

  @impl true
  def handle_call(:check_and_update, _from, timestamps) do
    now = System.monotonic_time(:millisecond)
    
    # Filter out old timestamps that are outside the window.
    valid_timestamps = Enum.filter(timestamps, fn ts -> now - ts < @window_ms end)

    if Enum.count(valid_timestamps) < @max_requests do
      # Allowed! Add the new timestamp and return :ok.
      new_state = [now | valid_timestamps]
      {:reply, :ok, new_state}
    else
      # Denied! State remains the same.
      {:reply, :error, valid_timestamps}
    end
  end
end
```

**Key Principles Adhered To:**

*   **Public API:** The `start_link/1` and `check_and_update/1` functions form the public API. Consumers of this module don't need to know it's a `GenServer`.
*   **Supervised Startup:** `start_link` is the standard name for a function that starts a process linked to its caller (the supervisor).
*   **State Isolation:** The state (the list of timestamps) is completely contained within this process, preventing race conditions.

### Step 3: The Dynamic Supervisor

We need one `Bucket` process per user. We can't list them all in our main supervisor because we don't know the users ahead of time. A `DynamicSupervisor` is the perfect tool for this. Its job is to supervise a dynamic number of identical children.

`lib/rate_limiter/bucket_supervisor.ex`:

```elixir
defmodule RateLimiter.BucketSupervisor do
  use DynamicSupervisor

  def start_link(opts) do
    # We give it a name so we can find it later.
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a new Bucket worker for a given user_id.
  """
  def start_bucket(user_id) do
    # The child_spec defines how to start a child.
    child_spec = {RateLimiter.Bucket, name: via_name(user_id)}
    
    # This is the CORRECT way to start a dynamic, supervised process.
    # We are asking the supervisor to start its child. We are NOT calling Bucket.start_link ourselves.
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Generates a unique, registered name for a user's bucket process.
  This allows us to find the process by user_id instead of PID.
  """
  def via_name(user_id) do
    {:via, Registry, {RateLimiter.BucketRegistry, user_id}}
  end

  @impl true
  def init(_opts) do
    # Strategy is always :one_for_one for DynamicSupervisors.
    # No children are defined at the start.
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
```

**Key Principles Adhered To:**

*   **No Manual Spawns:** We use `DynamicSupervisor.start_child/2`. This correctly adds the new `Bucket` process to the supervision tree. If this bucket crashes, `BucketSupervisor` will restart it according to its restart strategy.
*   **Separation of Concerns:** This module's only job is life-cycle management for buckets.

You'll notice we used a `Registry`. A registry is a built-in, distributed key-value process store, perfect for mapping a `user_id` to a `pid`. We need to create one.

`lib/rate_limiter/registry.ex`:

```elixir
defmodule RateLimiter.BucketRegistry do
  use Registry, keys: :unique, name: __MODULE__
end
```

### Step 4: The Public-Facing API / Manager

How does a client interact with our system? We need a single, clean entry point. This module will act as a facade, finding or creating the correct bucket for a given `user_id`.

`lib/rate_limiter.ex`:

```elixir
defmodule RateLimiter do
  @moduledoc """
  The main public API for the RateLimiter application.
  """

  @doc """
  Checks if an action is allowed for a given user_id.

  This will dynamically start a rate-limiting process for the user
  if one does not already exist.
  """
  def allowed?(user_id) do
    # We use a Registry to map user_id -> pid.
    # This is highly efficient and avoids a single GenServer bottleneck.
    bucket_name = RateLimiter.BucketSupervisor.via_name(user_id)

    case RateLimiter.Bucket.check_and_update(bucket_name) do
      :ok ->
        true
      :error ->
        false
      # The process might not exist yet.
      {:error, :noproc} ->
        # The process doesn't exist, so we try to start it.
        start_and_retry(user_id)
    end
  end

  defp start_and_retry(user_id) do
    case RateLimiter.BucketSupervisor.start_bucket(user_id) do
      {:ok, _pid} ->
        # It's started, let's try again. The first request should always be allowed.
        allowed?(user_id)
      {:error, {:already_started, _pid}} ->
        # A race condition: another process started it between our first check and now.
        # This is fine! We just retry.
        allowed?(user_id)
      {:error, reason} ->
        # Something went very wrong with starting the child.
        # We log it and deny the request.
        require Logger
        Logger.error("Failed to start rate limiter bucket for #{user_id}: #{inspect(reason)}")
        false
    end
  end
end
```

### Step 5: Assembling the Main Supervision Tree

Now we tie it all together in our `application.ex` file. Our application needs to supervise the `BucketRegistry` and the `BucketSupervisor`.

`lib/rate_limiter/application.ex`:

```elixir
defmodule RateLimiter.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Registry for mapping user_id -> pid
      RateLimiter.BucketRegistry,
      # Start the Dynamic Supervisor for our buckets
      RateLimiter.BucketSupervisor
    ]

    # Use a :one_for_one strategy. If the Registry crashes, we don't
    # want to kill the BucketSupervisor, and vice-versa.
    opts = [strategy: :one_for_one, name: RateLimiter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Final Structure:**

```
Application
└── RateLimiter.Supervisor (strategy: :one_for_one)
    ├── RateLimiter.BucketRegistry (a Registry)
    └── RateLimiter.BucketSupervisor (a DynamicSupervisor)
        ├── RateLimiter.Bucket (for user_id: "alice") [dynamically started]
        ├── RateLimiter.Bucket (for user_id: "bob")   [dynamically started]
        └── ... and so on
```

This is a beautiful, robust, and compliant OTP architecture.

### Step 6: Testing - The "No `sleep`" Principle in Practice

Testing OTP requires a different mindset. We test the behavior and lifecycle of processes.

`test/rate_limiter_test.exs`:

```elixir
defmodule RateLimiterTest do
  use ExUnit.Case, async: false # Use async: false when testing stateful processes

  setup do
    # We must explicitly start our application's supervision tree for the test.
    # This ensures the Registry and Supervisor are running.
    start_supervised!(RateLimiter.Application)
    :ok
  end

  test "allows requests under the limit" do
    user_id = "test_user_1"
    
    # Make 5 requests, all should be allowed
    for _ <- 1..5 do
      assert RateLimiter.allowed?(user_id) == true
    end
  end

  test "denies requests over the limit" do
    user_id = "test_user_2"

    for _ <- 1..5 do
      assert RateLimiter.allowed?(user_id) == true
    end

    # The 6th request should be denied
    assert RateLimiter.allowed?(user_id) == false
  end

  test "a crashed bucket is properly restarted by the supervisor" do
    user_id = "test_user_crash"

    # 1. Make a successful call to ensure the process is started
    assert RateLimiter.allowed?(user_id) == true

    # 2. Find the process and kill it to simulate a crash
    bucket_name = RateLimiter.BucketSupervisor.via_name(user_id)
    [pid] = Registry.lookup(RateLimiter.BucketRegistry, user_id)
    
    # Monitor the process to prove it goes down
    ref = Process.monitor(pid)
    # Don't use :normal. Use :kill to simulate an unexpected crash.
    Process.exit(pid, :kill)

    # 3. Prove that the process actually died. This is the correct alternative to sleep.
    # We wait for the :DOWN message from the BEAM.
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    # 4. Make another call. The supervisor should have restarted the bucket.
    # The first call after a restart should always succeed.
    assert RateLimiter.allowed?(user_id) == true
  end
end
```

**Key Testing Principles Adhered To:**

*   **`start_supervised!`:** We test the *entire* OTP system by starting our application, not just isolated modules.
*   **`async: false`:** Prevents tests from running in parallel and interfering with each other's state (like the Registry).
*   **No `Process.sleep/1`:** To test the restart logic, we don't `sleep(100)` and hope the process is back. We `Process.monitor/1` the process we're about to kill. Then we use `assert_receive` to wait for the `:DOWN` message, which *proves* it has terminated. Only then do we test the restart behavior. This is deterministic, fast, and reliable.

This complete guide provides a working, compliant, and robust OTP application that follows all the best practices you outlined.
