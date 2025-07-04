# Technical Architecture: Phoenix + ElectricSQL

## System Overview

The Pipeline Visual Editor v2 is built on a modern, distributed architecture that combines Phoenix LiveView's server-rendered reactivity with ElectricSQL's local-first sync engine. This architecture enables real-time collaboration, offline functionality, and seamless data synchronization.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Client Layer                            │
├─────────────────────────┬───────────────────┬───────────────────┤
│   Phoenix LiveView      │   Alpine.js       │   Local SQLite    │
│   (Server Components)   │   (Interactivity) │   (Offline Store) │
└───────────┬─────────────┴───────────────────┴──────┬────────────┘
            │              WebSocket                  │
            │              Connection                 │ ElectricSQL
            │                                         │ Sync Protocol
┌───────────▼─────────────────────────────────────────▼────────────┐
│                         Phoenix Server                            │
├─────────────────────────┬───────────────────┬───────────────────┤
│   LiveView Process      │   Presence        │   Electric        │
│   (Stateful UI)         │   Tracking        │   Sync Engine     │
├─────────────────────────┼───────────────────┼───────────────────┤
│   Business Logic        │   Validation      │   Auth/Authz      │
│   (Contexts)            │   Engine          │   Layer           │
└─────────────────────────┴───────────────────┴───────────────────┘
            │                                         │
            │              Ecto ORM                   │
            │                                         │
┌───────────▼─────────────────────────────────────────▼────────────┐
│                     PostgreSQL + Electric                         │
├───────────────────────────────────────────────────────────────────┤
│   Pipeline Schemas    │   User Data    │   Sync Metadata         │
│   Version History     │   Permissions  │   CRDT Operations       │
└───────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Client Layer

#### Phoenix LiveView
- Server-rendered HTML with reactive updates
- Maintains UI state on server
- Handles all user interactions
- Automatic DOM patching

```elixir
defmodule PipelineEditorWeb.PipelineLive.Editor do
  use PipelineEditorWeb, :live_view
  
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Electric.subscribe_pipeline(id)
      Presence.track(self(), "pipeline:#{id}", socket.assigns.current_user.id, %{
        cursor: nil,
        selection: nil
      })
    end
    
    {:ok, assign(socket, pipeline: Electric.get_pipeline(id))}
  end
end
```

#### Alpine.js Integration
- Handles local interactions (drag-drop, tooltips)
- Manages transient UI state
- Bridges LiveView with JavaScript libraries

```html
<div x-data="pipelineEditor()" 
     x-on:dragstart="handleDragStart($event)"
     x-on:drop="handleDrop($event)">
  <!-- Editor content -->
</div>
```

#### Local SQLite (via ElectricSQL)
- Embedded database for offline storage
- Automatic schema generation from PostgreSQL
- Transparent sync with server

### 2. Phoenix Server

#### LiveView Processes
- One process per connected editor
- Maintains UI state and subscriptions
- Handles real-time updates
- Automatic reconnection and state recovery

#### Presence Tracking
- Shows active users in real-time
- Cursor and selection tracking
- User status indicators
- Automatic cleanup on disconnect

```elixir
defmodule PipelineEditorWeb.Presence do
  use Phoenix.Presence,
    otp_app: :pipeline_editor,
    pubsub_server: PipelineEditor.PubSub
    
  def track_cursor(socket, pipeline_id, cursor_position) do
    track(self(), "pipeline:#{pipeline_id}:cursors", socket.assigns.current_user.id, %{
      position: cursor_position,
      color: socket.assigns.current_user.color,
      name: socket.assigns.current_user.name
    })
  end
end
```

#### Business Logic Layer
- Pipeline CRUD operations
- Step management
- Template handling
- Import/Export functionality

```elixir
defmodule PipelineEditor.Pipelines do
  def create_pipeline(attrs) do
    %Pipeline{}
    |> Pipeline.changeset(attrs)
    |> Repo.insert()
    |> broadcast_change(:pipeline_created)
  end
  
  def add_step(pipeline_id, step_attrs) do
    pipeline = get_pipeline!(pipeline_id)
    
    %Step{}
    |> Step.changeset(Map.put(step_attrs, :pipeline_id, pipeline_id))
    |> Repo.insert()
    |> broadcast_change(:step_added)
  end
end
```

### 3. Data Layer

#### PostgreSQL with Electric Extensions
- Primary source of truth
- JSONB columns for flexible schema
- Electric replication triggers
- Logical replication for sync

```sql
-- Enable Electric extensions
CREATE EXTENSION IF NOT EXISTS electric;

-- Pipelines table with Electric sync
CREATE TABLE pipelines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  yaml_version VARCHAR(10) DEFAULT 'v2',
  config JSONB DEFAULT '{}',
  created_by UUID REFERENCES users(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Electric sync
ALTER TABLE pipelines ENABLE ELECTRIC;

-- Steps table
CREATE TABLE steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id UUID REFERENCES pipelines(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  config JSONB NOT NULL,
  position INTEGER NOT NULL,
  parent_step_id UUID REFERENCES steps(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE steps ENABLE ELECTRIC;
```

## Data Flow

### 1. Read Path
```
User Request → LiveView Mount → Electric.get_pipeline() → Local SQLite → UI Render
                                            ↓
                                   PostgreSQL (if needed)
```

### 2. Write Path
```
User Action → LiveView Event → Business Logic → Ecto Insert/Update
                                                      ↓
                                               PostgreSQL Write
                                                      ↓
                                              Electric Replication
                                                      ↓
                                          All Connected Clients Update
```

### 3. Real-time Sync
```
PostgreSQL Change → Electric CDC → WebSocket Broadcast → Client SQLite Update
                                                              ↓
                                                      LiveView Re-render
```

## Security Architecture

### Authentication
- Phoenix Session-based auth
- JWT tokens for API access
- OAuth2 integration support

### Authorization
- Row-level security in PostgreSQL
- Pipeline-level permissions
- Team-based access control

```elixir
defmodule PipelineEditor.Pipelines.Policy do
  def can?(%User{} = user, :edit, %Pipeline{} = pipeline) do
    pipeline.created_by == user.id or
    user.id in pipeline.collaborator_ids or
    user.role == :admin
  end
end
```

### Data Isolation
- User data segregation
- Team boundaries
- Audit logging

## Performance Optimizations

### 1. Smart Diffing
- Only sync changed fields
- Compressed WebSocket messages
- Efficient DOM patching

### 2. Lazy Loading
- Load pipeline steps on demand
- Virtualized lists for large pipelines
- Progressive enhancement

### 3. Caching Strategy
- ETS cache for frequently accessed data
- PostgreSQL query optimization
- CDN for static assets

```elixir
defmodule PipelineEditor.Cache do
  use GenServer
  
  def get_pipeline(id) do
    case :ets.lookup(:pipeline_cache, id) do
      [{^id, pipeline}] -> {:ok, pipeline}
      [] -> 
        pipeline = Repo.get(Pipeline, id)
        :ets.insert(:pipeline_cache, {id, pipeline})
        {:ok, pipeline}
    end
  end
end
```

## Scalability Considerations

### Horizontal Scaling
- Phoenix nodes behind load balancer
- Shared PostgreSQL with read replicas
- Redis for PubSub (optional)

### Connection Limits
- LiveView process pooling
- WebSocket connection management
- Graceful degradation

### Database Scaling
- PostgreSQL partitioning for large datasets
- Archive old pipelines
- Separate read/write connections

## Development Workflow

### Local Development
```bash
# Start PostgreSQL with Electric
docker-compose up -d postgres electric

# Start Phoenix server
mix phx.server

# Access at http://localhost:4000
```

### Testing Strategy
- LiveView integration tests
- Electric sync tests
- End-to-end Wallaby tests

```elixir
defmodule PipelineEditorWeb.PipelineLive.EditorTest do
  use PipelineEditorWeb.ConnCase
  import Phoenix.LiveViewTest
  
  test "creates a new step", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pipelines/#{pipeline.id}/edit")
    
    view
    |> element("#add-step-button")
    |> render_click()
    
    assert has_element?(view, "#step-form")
  end
end
```

## Error Handling

### Network Failures
- Automatic reconnection
- Offline queue for changes
- Conflict resolution

### Validation Errors
- Client-side pre-validation
- Server-side enforcement
- Clear error messages

### System Failures
- Graceful degradation
- Error boundaries
- Automatic recovery

## Monitoring & Observability

### Metrics
- LiveView connection count
- Sync latency
- Database performance
- Error rates

### Logging
- Structured logging with metadata
- Distributed tracing
- User action tracking

### Alerting
- Slow query detection
- High error rate alerts
- System resource monitoring

## Technology Decisions

### Why Phoenix LiveView?
- Reduced complexity vs SPA
- Server-side state management
- Built-in real-time features
- Excellent Elixir ecosystem

### Why ElectricSQL?
- True offline-first capability
- Automatic conflict resolution
- PostgreSQL compatibility
- Active-active replication

### Why Not React/Vue?
- Simpler architecture
- Fewer moving parts
- Better SEO
- Reduced JavaScript complexity

## Future Considerations

### Potential Enhancements
- GraphQL subscriptions
- Plugin architecture
- Mobile native apps
- Advanced visualization

### Scaling Challenges
- Global distribution
- Multi-region deployment
- Edge computing
- Federation support