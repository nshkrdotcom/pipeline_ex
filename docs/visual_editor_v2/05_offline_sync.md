# Offline Sync: ElectricSQL Local-First Architecture

## Overview

The Pipeline Visual Editor v2 leverages ElectricSQL's local-first sync engine to provide seamless offline capabilities. Users can continue working without internet connectivity, with all changes automatically synchronized when connection is restored.

## Sync Architecture

### Three-Layer Sync Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     Client Application                           │
├─────────────────────────────────────────────────────────────────┤
│  Phoenix LiveView  │  Local SQLite  │  Electric Client Library  │
└────────────────────┬──────────────────┬─────────────────────────┘
                     │                  │
                     │   Satellite       │  Offline Queue
                     │   Protocol        │  & Conflict Resolution
                     │                  │
┌────────────────────▼──────────────────▼─────────────────────────┐
│                    Electric Sync Service                         │
├─────────────────────────────────────────────────────────────────┤
│  Shape Subscriptions  │  Change Detection  │  Conflict Merge    │
└────────────────────┬─────────────────────────────────────────────┘
                     │
                     │  Logical Replication
                     │
┌────────────────────▼─────────────────────────────────────────────┐
│                    PostgreSQL Database                           │
├─────────────────────────────────────────────────────────────────┤
│  Pipeline Tables  │  WAL  │  Replication Slots  │  Triggers    │
└─────────────────────────────────────────────────────────────────┘
```

## Shape-Based Partial Replication

### Pipeline Shape Definition

```elixir
defmodule PipelineEditor.Shapes do
  @doc """
  Define the shape subscription for a pipeline workspace
  """
  def pipeline_workspace_shape(pipeline_id, user_id) do
    %{
      root_table: :pipelines,
      where: "id = '#{pipeline_id}' AND team_id IN (
        SELECT team_id FROM team_members WHERE user_id = '#{user_id}'
      )",
      include: %{
        steps: %{
          include: %{
            connections: %{
              where: "from_step_id = steps.id OR to_step_id = steps.id"
            }
          }
        },
        comments: %{
          include: %{
            user: %{
              select: [:id, :name, :avatar_url]
            }
          }
        },
        pipeline_versions: %{
          where: "created_at > NOW() - INTERVAL '30 days'",
          limit: 10,
          order_by: "version_number DESC"
        }
      }
    }
  end
end
```

### Electric Client Configuration

```typescript
// lib/pipeline_editor_web/assets/js/electric.js

import { electrify, ElectricDatabase } from 'electric-sql/browser'
import { schema } from './generated/electric'

export async function initializeElectric() {
  // Initialize local SQLite database
  const conn = await ElectricDatabase.init('pipeline-editor.db')
  
  // Electrify the database connection
  const electric = await electrify(conn, schema, {
    url: process.env.ELECTRIC_URL,
    auth: {
      token: () => getAuthToken()
    }
  })
  
  // Set up shape subscriptions
  await setupShapeSubscriptions(electric)
  
  return electric
}

async function setupShapeSubscriptions(electric) {
  const pipelineId = getCurrentPipelineId()
  
  // Subscribe to pipeline shape
  const shape = await electric.db.pipelines.sync({
    where: {
      id: pipelineId
    },
    include: {
      steps: {
        include: {
          connections: true
        }
      },
      comments: {
        include: {
          user: true
        }
      }
    }
  })
  
  // Monitor sync status
  shape.subscribe((status) => {
    updateSyncIndicator(status)
  })
}
```

## Offline Write Queue

### Local Change Management

```elixir
defmodule PipelineEditor.OfflineQueue do
  use GenServer
  
  @table :offline_operations
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    # Create ETS table for offline operations
    :ets.new(@table, [:set, :public, :named_table])
    
    # Start monitoring connection status
    Electric.ConnectionMonitor.subscribe()
    
    {:ok, %{connected: false, queue: []}}
  end
  
  @doc """
  Queue an operation for offline execution
  """
  def queue_operation(operation) do
    GenServer.cast(__MODULE__, {:queue_operation, operation})
  end
  
  def handle_cast({:queue_operation, operation}, state) do
    # Add to queue with timestamp and unique ID
    queued_op = %{
      id: Ecto.UUID.generate(),
      operation: operation,
      timestamp: DateTime.utc_now(),
      retry_count: 0
    }
    
    :ets.insert(@table, {queued_op.id, queued_op})
    
    # Try to execute if connected
    if state.connected do
      send(self(), :process_queue)
    end
    
    {:noreply, state}
  end
  
  def handle_info(:connection_restored, state) do
    # Process all queued operations
    send(self(), :process_queue)
    {:noreply, %{state | connected: true}}
  end
  
  def handle_info(:process_queue, state) do
    # Get all queued operations
    operations = :ets.tab2list(@table)
    |> Enum.sort_by(fn {_, op} -> op.timestamp end)
    
    # Process each operation
    Enum.each(operations, fn {id, op} ->
      case execute_operation(op.operation) do
        :ok ->
          :ets.delete(@table, id)
        {:error, :conflict} ->
          handle_conflict(op)
        {:error, _reason} ->
          retry_operation(op)
      end
    end)
    
    {:noreply, state}
  end
end
```

## Conflict Resolution

### CRDT-Based Merge Strategy

```elixir
defmodule PipelineEditor.ConflictResolution do
  @moduledoc """
  Implements CRDT-based conflict resolution for pipeline operations
  """
  
  alias PipelineEditor.{Pipeline, Step, Connection}
  
  @doc """
  Resolve conflicts for step positions using Last-Write-Wins with vector clocks
  """
  def resolve_step_position_conflict(local_step, remote_step) do
    case VectorClock.compare(local_step.vector_clock, remote_step.vector_clock) do
      :before -> remote_step
      :after -> local_step
      :concurrent ->
        # Use deterministic tie-breaker (user ID)
        if local_step.updated_by > remote_step.updated_by do
          local_step
        else
          remote_step
        end
    end
  end
  
  @doc """
  Merge concurrent step additions using set union
  """
  def merge_step_additions(local_steps, remote_steps) do
    # Union of steps, deduplicated by ID
    all_steps = Map.merge(
      Map.new(local_steps, &{&1.id, &1}),
      Map.new(remote_steps, &{&1.id, &1})
    )
    
    Map.values(all_steps)
  end
  
  @doc """
  Resolve connection conflicts using observed-remove set
  """
  def resolve_connection_conflicts(local_conns, remote_conns) do
    # Track additions and removals separately
    local_adds = MapSet.new(local_conns.added)
    local_removes = MapSet.new(local_conns.removed)
    remote_adds = MapSet.new(remote_conns.added)
    remote_removes = MapSet.new(remote_conns.removed)
    
    # Apply CRDT merge rules
    final_adds = MapSet.union(local_adds, remote_adds)
    final_removes = MapSet.union(local_removes, remote_removes)
    
    # Compute final set
    MapSet.difference(final_adds, final_removes)
    |> MapSet.to_list()
  end
end
```

## Optimistic UI Updates

### Client-Side State Management

```javascript
// lib/pipeline_editor_web/assets/js/hooks/offline_state.js

export const OfflineState = {
  pendingOperations: new Map(),
  
  // Apply optimistic update immediately
  applyOptimisticUpdate(operation) {
    const tempId = `temp_${Date.now()}_${Math.random()}`
    
    switch (operation.type) {
      case 'add_step':
        this.addOptimisticStep(tempId, operation.data)
        break
      case 'update_step':
        this.updateOptimisticStep(operation.stepId, operation.data)
        break
      case 'delete_step':
        this.deleteOptimisticStep(operation.stepId)
        break
    }
    
    // Queue for sync
    this.pendingOperations.set(tempId, {
      operation,
      status: 'pending',
      timestamp: Date.now()
    })
    
    return tempId
  },
  
  // Reconcile with server response
  reconcileOperation(tempId, serverResponse) {
    const pending = this.pendingOperations.get(tempId)
    if (!pending) return
    
    if (serverResponse.success) {
      // Replace temp ID with real ID
      this.replaceTempId(tempId, serverResponse.id)
      this.pendingOperations.delete(tempId)
    } else {
      // Rollback optimistic update
      this.rollbackOperation(pending.operation)
      this.pendingOperations.delete(tempId)
      
      // Show error to user
      this.showConflictResolution(serverResponse.conflict)
    }
  }
}
```

### Phoenix Hook Integration

```javascript
// lib/pipeline_editor_web/assets/js/hooks/pipeline_editor_hooks.js

export const PipelineEditorHooks = {
  mounted() {
    this.electric = null
    this.initializeElectric()
    this.setupOfflineHandlers()
  },
  
  async initializeElectric() {
    try {
      this.electric = await initializeElectric()
      this.bindToLocalDatabase()
    } catch (error) {
      console.error('Failed to initialize Electric:', error)
      this.fallbackToOnlineOnly()
    }
  },
  
  setupOfflineHandlers() {
    // Monitor connection status
    window.addEventListener('online', () => {
      this.pushEvent('connection_restored', {})
      this.syncPendingOperations()
    })
    
    window.addEventListener('offline', () => {
      this.pushEvent('connection_lost', {})
      this.enableOfflineMode()
    })
    
    // Intercept operations
    this.handleEvent('operation', (operation) => {
      if (navigator.onLine) {
        // Normal operation
        this.performOperation(operation)
      } else {
        // Queue for offline
        const tempId = OfflineState.applyOptimisticUpdate(operation)
        this.pushEvent('operation_queued', { tempId })
      }
    })
  },
  
  async syncPendingOperations() {
    for (const [tempId, pending] of OfflineState.pendingOperations) {
      try {
        const result = await this.electric.db[pending.operation.table]
          .create(pending.operation.data)
        
        OfflineState.reconcileOperation(tempId, {
          success: true,
          id: result.id
        })
      } catch (error) {
        OfflineState.reconcileOperation(tempId, {
          success: false,
          conflict: error
        })
      }
    }
  }
}
```

## Sync Status Indicators

### UI Components

```elixir
defmodule PipelineEditorWeb.Components.SyncStatus do
  use PipelineEditorWeb, :live_component
  
  def render(assigns) do
    ~H"""
    <div class="sync-status flex items-center gap-2">
      <%= case @sync_state do %>
        <% :synced -> %>
          <div class="flex items-center gap-1 text-green-600">
            <.icon name="hero-check-circle" class="w-4 h-4" />
            <span class="text-sm">All changes saved</span>
          </div>
          
        <% :syncing -> %>
          <div class="flex items-center gap-1 text-blue-600">
            <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
            <span class="text-sm">Syncing...</span>
          </div>
          
        <% :offline -> %>
          <div class="flex items-center gap-1 text-yellow-600">
            <.icon name="hero-cloud-arrow-up" class="w-4 h-4" />
            <span class="text-sm">Working offline</span>
            <%= if @pending_count > 0 do %>
              <span class="text-xs bg-yellow-100 px-2 py-0.5 rounded-full">
                <%= @pending_count %> pending
              </span>
            <% end %>
          </div>
          
        <% :error -> %>
          <div class="flex items-center gap-1 text-red-600">
            <.icon name="hero-exclamation-triangle" class="w-4 h-4" />
            <span class="text-sm">Sync error</span>
            <button phx-click="retry_sync" class="text-xs underline">
              Retry
            </button>
          </div>
      <% end %>
    </div>
    """
  end
  
  def handle_event("retry_sync", _, socket) do
    send(self(), :retry_sync)
    {:noreply, socket}
  end
end
```

## Performance Optimizations

### Selective Sync

```elixir
defmodule PipelineEditor.SelectiveSync do
  @doc """
  Only sync relevant data based on user's current view
  """
  def configure_sync_shapes(user_id, view_context) do
    base_shape = base_pipeline_shape(user_id)
    
    case view_context do
      {:pipeline_editor, pipeline_id} ->
        # Full sync for active pipeline
        Map.merge(base_shape, %{
          where: "id = '#{pipeline_id}'",
          include_all: true
        })
        
      {:pipeline_list, team_id} ->
        # Minimal sync for list view
        Map.merge(base_shape, %{
          where: "team_id = '#{team_id}'",
          include: %{steps: false, connections: false},
          select: [:id, :name, :updated_at, :status]
        })
        
      {:dashboard, _} ->
        # Recent pipelines only
        Map.merge(base_shape, %{
          where: "updated_at > NOW() - INTERVAL '7 days'",
          limit: 20
        })
    end
  end
end
```

### Incremental Sync

```javascript
// Efficient incremental updates
export const IncrementalSync = {
  lastSyncTimestamp: null,
  
  async syncChanges(electric) {
    const changes = await electric.db.raw({
      sql: `
        SELECT * FROM pipeline_changes 
        WHERE timestamp > ? 
        ORDER BY timestamp ASC
      `,
      args: [this.lastSyncTimestamp || 0]
    })
    
    for (const change of changes) {
      await this.applyChange(change)
    }
    
    this.lastSyncTimestamp = Date.now()
  }
}
```

## Error Handling

### Connection Recovery

```elixir
defmodule PipelineEditor.ConnectionRecovery do
  use GenServer
  
  @retry_intervals [1_000, 2_000, 5_000, 10_000, 30_000]
  
  def handle_info(:check_connection, %{retry_count: count} = state) do
    case Electric.check_connection() do
      :ok ->
        broadcast_connection_restored()
        {:noreply, %{state | connected: true, retry_count: 0}}
        
      :error ->
        # Schedule next retry with exponential backoff
        interval = Enum.at(@retry_intervals, min(count, length(@retry_intervals) - 1))
        Process.send_after(self(), :check_connection, interval)
        
        {:noreply, %{state | retry_count: count + 1}}
    end
  end
end
```

## Testing Offline Scenarios

```elixir
defmodule PipelineEditorWeb.OfflineSyncTest do
  use PipelineEditorWeb.ConnCase
  
  describe "offline operations" do
    test "queues operations when offline", %{conn: conn} do
      {:ok, view, _} = live(conn, "/pipelines/#{pipeline.id}/edit")
      
      # Simulate offline
      view |> render_hook("connection_lost", %{})
      
      # Perform operation
      view |> element("#add-step") |> render_click()
      
      # Verify queued
      assert view |> element(".sync-status") |> render() =~ "1 pending"
    end
    
    test "syncs queued operations when reconnected", %{conn: conn} do
      # ... test implementation
    end
  end
end
```

## Configuration

### Electric Service Setup

```yaml
# config/electric.yml
electric:
  database_url: ${DATABASE_URL}
  auth:
    mode: secure
    jwt_secret: ${ELECTRIC_JWT_SECRET}
  
  replication:
    publications:
      - pipeline_sync
    
    conflict_resolution:
      strategy: lww_crdt
      clock_source: hybrid_logical_clock
  
  shapes:
    max_shape_size: 10MB
    shape_cache_ttl: 3600
    
  client:
    max_offline_queue: 1000
    sync_batch_size: 100
```

## Best Practices

1. **Shape Design**
   - Keep shapes focused and minimal
   - Use where clauses to limit data
   - Consider user context for shape definition

2. **Conflict Prevention**
   - Use optimistic locking where possible
   - Design operations to be commutative
   - Implement field-level rather than record-level updates

3. **Performance**
   - Monitor shape size and sync performance
   - Implement progressive sync for large datasets
   - Use sync status indicators to set user expectations

4. **Error Recovery**
   - Implement automatic retry with backoff
   - Provide manual sync triggers
   - Clear error messaging for sync failures