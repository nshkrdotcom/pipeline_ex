# Phoenix LiveView Components

## Component Architecture

The visual editor is built with modular LiveView components that handle specific aspects of pipeline management. Each component is self-contained, reusable, and communicates through well-defined interfaces.

## Component Hierarchy

```
PipelineEditorLive (Root)
├── HeaderComponent
│   ├── PipelineName
│   ├── SaveStatus
│   └── UserPresence
├── ToolbarComponent
│   ├── StepLibrary
│   ├── ViewModeToggle
│   └── ActionButtons
├── CanvasComponent
│   ├── StepNode
│   ├── Connection
│   └── SelectionBox
├── PropertiesPanel
│   ├── StepConfig
│   ├── ValidationMessages
│   └── Documentation
└── FooterComponent
    ├── ZoomControls
    ├── MiniMap
    └── StatusBar
```

## Core Components

### 1. PipelineEditorLive (Root Component)

The main LiveView that orchestrates all child components and manages global state.

```elixir
defmodule PipelineEditorWeb.PipelineLive.Editor do
  use PipelineEditorWeb, :live_view
  
  alias PipelineEditorWeb.Components.{
    Header, Toolbar, Canvas, PropertiesPanel, Footer
  }
  
  @impl true
  def mount(%{"id" => pipeline_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to pipeline updates
      PipelineEditor.subscribe_pipeline(pipeline_id)
      
      # Track user presence
      {:ok, _} = Presence.track(self(), "pipeline:#{pipeline_id}", 
        socket.assigns.current_user.id, %{
          name: socket.assigns.current_user.name,
          color: generate_user_color(socket.assigns.current_user.id)
        })
    end
    
    socket =
      socket
      |> assign(:pipeline_id, pipeline_id)
      |> assign(:pipeline, load_pipeline(pipeline_id))
      |> assign(:selected_step_ids, [])
      |> assign(:view_mode, :visual)
      |> assign(:zoom_level, 100)
      |> assign(:pan_offset, {0, 0})
      |> assign(:show_properties, true)
      |> assign(:validation_errors, [])
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="pipeline-editor h-screen flex flex-col" 
         phx-hook="PipelineEditor"
         data-pipeline-id={@pipeline_id}>
      
      <.live_component module={Header} 
        id="header"
        pipeline={@pipeline}
        save_status={@save_status}
        users={@present_users} />
      
      <div class="flex flex-1 overflow-hidden">
        <.live_component module={Toolbar}
          id="toolbar"
          view_mode={@view_mode} />
        
        <div class="flex-1 relative">
          <.live_component module={Canvas}
            id="canvas"
            pipeline={@pipeline}
            selected_step_ids={@selected_step_ids}
            zoom_level={@zoom_level}
            pan_offset={@pan_offset} />
        </div>
        
        <%= if @show_properties do %>
          <.live_component module={PropertiesPanel}
            id="properties"
            selected_steps={get_selected_steps(@pipeline, @selected_step_ids)}
            validation_errors={@validation_errors} />
        <% end %>
      </div>
      
      <.live_component module={Footer}
        id="footer"
        zoom_level={@zoom_level}
        pipeline={@pipeline} />
    </div>
    """
  end
end
```

### 2. Canvas Component

The main editing area where steps are visualized and manipulated.

```elixir
defmodule PipelineEditorWeb.Components.Canvas do
  use PipelineEditorWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="canvas-container relative w-full h-full overflow-hidden bg-gray-50"
         phx-hook="Canvas"
         id={"canvas-#{@id}"}
         phx-target={@myself}>
      
      <!-- Grid Background -->
      <svg class="absolute inset-0 w-full h-full pointer-events-none">
        <defs>
          <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
            <circle cx="1" cy="1" r="0.5" fill="#e5e7eb" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)" />
      </svg>
      
      <!-- Canvas Content -->
      <div class="canvas-content absolute"
           style={"transform: scale(#{@zoom_level / 100}) translate(#{elem(@pan_offset, 0)}px, #{elem(@pan_offset, 1)}px)"}>
        
        <!-- Connections Layer -->
        <svg class="connections-layer absolute inset-0 pointer-events-none">
          <%= for connection <- @pipeline.connections do %>
            <.connection 
              connection={connection}
              from_step={get_step(@pipeline, connection.from_step_id)}
              to_step={get_step(@pipeline, connection.to_step_id)} />
          <% end %>
        </svg>
        
        <!-- Steps Layer -->
        <%= for step <- @pipeline.steps do %>
          <.step_node
            step={step}
            selected={step.id in @selected_step_ids}
            phx-target={@myself} />
        <% end %>
        
        <!-- Selection Box -->
        <%= if @selecting do %>
          <div class="selection-box absolute border-2 border-blue-500 bg-blue-500/10"
               style={"left: #{@selection_start.x}px; top: #{@selection_start.y}px; width: #{@selection_end.x - @selection_start.x}px; height: #{@selection_end.y - @selection_start.y}px"}>
          </div>
        <% end %>
      </div>
      
      <!-- Other Users' Cursors -->
      <%= for {user_id, user} <- @present_users, user_id != @current_user_id do %>
        <.user_cursor user={user} />
      <% end %>
    </div>
    """
  end
  
  # Component for individual step nodes
  def step_node(assigns) do
    ~H"""
    <div class={"step-node absolute rounded-lg border-2 bg-white shadow-sm transition-all #{step_classes(@step, @selected)}"}
         style={"left: #{@step.position_x}px; top: #{@step.position_y}px; width: #{@step.width}px; height: #{@step.height}px"}
         data-step-id={@step.id}
         phx-click="select_step"
         phx-value-id={@step.id}
         phx-hook="StepNode">
      
      <!-- Step Header -->
      <div class="step-header px-3 py-2 border-b flex items-center justify-between">
        <div class="flex items-center gap-2">
          <.step_icon type={@step.type} />
          <span class="font-medium text-sm"><%= @step.name %></span>
        </div>
        <%= if not @step.enabled do %>
          <span class="text-xs text-gray-500">Disabled</span>
        <% end %>
      </div>
      
      <!-- Step Content Preview -->
      <div class="step-content px-3 py-2 text-xs text-gray-600">
        <%= step_preview(@step) %>
      </div>
      
      <!-- Connection Points -->
      <div class="input-port absolute -left-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-gray-400 border-2 border-white"></div>
      <div class="output-port absolute -right-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full bg-gray-400 border-2 border-white"></div>
    </div>
    """
  end
  
  # SVG connection component
  def connection(assigns) do
    path = calculate_connection_path(assigns.from_step, assigns.to_step)
    
    ~H"""
    <g class="connection" data-connection-id={@connection.id}>
      <path d={path} 
            stroke="#6b7280" 
            stroke-width="2" 
            fill="none"
            marker-end="url(#arrowhead)" />
    </g>
    """
  end
end
```

### 3. Step Library Component

Draggable palette of available step types.

```elixir
defmodule PipelineEditorWeb.Components.StepLibrary do
  use PipelineEditorWeb, :live_component
  
  @step_categories [
    {"AI Providers", ~w(claude gemini claude_smart claude_session claude_extract claude_batch claude_robust parallel_claude gemini_instructor)},
    {"Control Flow", ~w(pipeline for_loop while_loop switch)},
    {"Data & Files", ~w(data_transform file_ops codebase_query)},
    {"State", ~w(set_variable checkpoint)}
  ]
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="step-library bg-white rounded-lg shadow-sm p-4">
      <div class="mb-4">
        <input type="text" 
               placeholder="Search steps..." 
               class="w-full px-3 py-2 border rounded-md text-sm"
               phx-keyup="search_steps"
               phx-target={@myself} />
      </div>
      
      <%= for {category, steps} <- @step_categories do %>
        <div class="mb-4">
          <h4 class="text-xs font-semibold text-gray-500 uppercase mb-2">
            <%= category %>
          </h4>
          <div class="space-y-1">
            <%= for step_type <- steps do %>
              <div class="step-template flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-50 cursor-move"
                   draggable="true"
                   phx-hook="DraggableStep"
                   data-step-type={step_type}>
                <.step_icon type={step_type} />
                <span class="text-sm"><%= humanize_step_type(step_type) %></span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
```

### 4. Properties Panel Component

Configuration panel for selected steps.

```elixir
defmodule PipelineEditorWeb.Components.PropertiesPanel do
  use PipelineEditorWeb, :live_component
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="properties-panel w-96 bg-white border-l overflow-y-auto">
      <%= if @selected_steps == [] do %>
        <div class="p-6 text-center text-gray-500">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor">
            <!-- Icon -->
          </svg>
          <p class="text-sm">Select a step to view its properties</p>
        </div>
      <% else %>
        <%= if length(@selected_steps) == 1 do %>
          <.single_step_properties step={hd(@selected_steps)} errors={@validation_errors} />
        <% else %>
          <.multi_step_properties steps={@selected_steps} />
        <% end %>
      <% end %>
    </div>
    """
  end
  
  def single_step_properties(assigns) do
    ~H"""
    <div class="p-4">
      <!-- Step Info -->
      <div class="mb-6">
        <div class="flex items-center gap-3 mb-4">
          <.step_icon type={@step.type} size="lg" />
          <div class="flex-1">
            <input type="text" 
                   value={@step.name}
                   class="font-semibold text-lg w-full"
                   phx-blur="update_step_name"
                   phx-value-id={@step.id} />
            <p class="text-sm text-gray-500"><%= @step.type %></p>
          </div>
        </div>
        
        <!-- Enable/Disable Toggle -->
        <label class="flex items-center gap-2">
          <input type="checkbox" 
                 checked={@step.enabled}
                 phx-click="toggle_step"
                 phx-value-id={@step.id} />
          <span class="text-sm">Enabled</span>
        </label>
      </div>
      
      <!-- Dynamic Configuration Form -->
      <.step_config_form step={@step} />
      
      <!-- Validation Errors -->
      <%= if @errors != [] do %>
        <div class="mt-4 p-3 bg-red-50 rounded-md">
          <h4 class="text-sm font-medium text-red-800 mb-1">Validation Errors</h4>
          <ul class="list-disc list-inside text-sm text-red-700">
            <%= for error <- @errors do %>
              <li><%= error %></li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Dynamic form generation based on step type
  def step_config_form(%{step: %{type: "claude"}} = assigns) do
    ~H"""
    <form phx-change="update_step_config" phx-value-id={@step.id}>
      <div class="space-y-4">
        <!-- Model Selection -->
        <div>
          <label class="block text-sm font-medium mb-1">Model</label>
          <select name="config[model]" class="w-full rounded-md border-gray-300">
            <option value="claude-3-opus-20240229">Claude 3 Opus</option>
            <option value="claude-3-sonnet-20240229">Claude 3 Sonnet</option>
            <option value="claude-3-haiku-20240307">Claude 3 Haiku</option>
          </select>
        </div>
        
        <!-- Tools -->
        <div>
          <label class="block text-sm font-medium mb-1">Tools</label>
          <div class="space-y-1">
            <%= for tool <- ~w(bash read write edit search glob grep) do %>
              <label class="flex items-center gap-2">
                <input type="checkbox" 
                       name={"config[tools][]"}
                       value={tool}
                       checked={tool in (@step.config["tools"] || [])} />
                <span class="text-sm"><%= tool %></span>
              </label>
            <% end %>
          </div>
        </div>
        
        <!-- Max Tokens -->
        <div>
          <label class="block text-sm font-medium mb-1">Max Tokens</label>
          <input type="number" 
                 name="config[max_tokens]"
                 value={@step.config["max_tokens"] || 4000}
                 class="w-full rounded-md border-gray-300" />
        </div>
        
        <!-- Prompt Editor -->
        <div>
          <label class="block text-sm font-medium mb-1">Prompt</label>
          <.prompt_editor prompts={@step.config["prompt"] || []} step_id={@step.id} />
        </div>
      </div>
    </form>
    """
  end
end
```

### 5. JavaScript Hooks

Phoenix Hooks for client-side interactivity.

```javascript
// assets/js/hooks/pipeline_editor.js

export const PipelineEditor = {
  mounted() {
    this.handleKeyboardShortcuts()
    this.initializeCanvas()
  },
  
  handleKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Ctrl/Cmd + S: Save
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault()
        this.pushEvent('save_pipeline', {})
      }
      
      // Delete: Remove selected steps
      if (e.key === 'Delete') {
        this.pushEvent('delete_selected_steps', {})
      }
      
      // Ctrl/Cmd + Z: Undo
      if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
        e.preventDefault()
        this.pushEvent('undo', {})
      }
    })
  },
  
  initializeCanvas() {
    // Set up drag and drop, pan, zoom, etc.
  }
}

export const Canvas = {
  mounted() {
    this.canvas = this.el
    this.initializeDragDrop()
    this.initializePanZoom()
    this.initializeSelection()
  },
  
  initializeDragDrop() {
    this.canvas.addEventListener('dragover', (e) => {
      e.preventDefault()
      e.dataTransfer.dropEffect = 'copy'
    })
    
    this.canvas.addEventListener('drop', (e) => {
      e.preventDefault()
      const stepType = e.dataTransfer.getData('step-type')
      const rect = this.canvas.getBoundingClientRect()
      
      this.pushEvent('add_step', {
        type: stepType,
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      })
    })
  },
  
  initializePanZoom() {
    let isPanning = false
    let startX, startY
    
    this.canvas.addEventListener('wheel', (e) => {
      if (e.ctrlKey) {
        e.preventDefault()
        const delta = e.deltaY > 0 ? 0.9 : 1.1
        this.pushEvent('zoom', {delta})
      }
    })
    
    this.canvas.addEventListener('mousedown', (e) => {
      if (e.button === 1 || (e.button === 0 && e.altKey)) {
        isPanning = true
        startX = e.clientX
        startY = e.clientY
      }
    })
  }
}

export const StepNode = {
  mounted() {
    this.initializeDragging()
    this.initializeConnections()
  },
  
  initializeDragging() {
    let isDragging = false
    let startX, startY
    let initialX, initialY
    
    this.el.addEventListener('mousedown', (e) => {
      if (e.target.closest('.input-port, .output-port')) return
      
      isDragging = true
      startX = e.clientX
      startY = e.clientY
      initialX = parseInt(this.el.style.left)
      initialY = parseInt(this.el.style.top)
      
      this.el.classList.add('dragging')
    })
    
    document.addEventListener('mousemove', (e) => {
      if (!isDragging) return
      
      const dx = e.clientX - startX
      const dy = e.clientY - startY
      
      this.el.style.left = `${initialX + dx}px`
      this.el.style.top = `${initialY + dy}px`
    })
    
    document.addEventListener('mouseup', (e) => {
      if (!isDragging) return
      
      isDragging = false
      this.el.classList.remove('dragging')
      
      this.pushEvent('move_step', {
        id: this.el.dataset.stepId,
        x: parseInt(this.el.style.left),
        y: parseInt(this.el.style.top)
      })
    })
  }
}
```

### 6. Tailwind Components

Custom Tailwind components for consistent styling.

```css
/* assets/css/components.css */

@layer components {
  .step-node {
    @apply transition-all duration-150;
  }
  
  .step-node.selected {
    @apply border-blue-500 shadow-lg ring-2 ring-blue-200;
  }
  
  .step-node.dragging {
    @apply opacity-75 cursor-move;
  }
  
  .step-icon {
    @apply w-5 h-5 flex-shrink-0;
  }
  
  .connection {
    @apply transition-all duration-150;
  }
  
  .connection:hover {
    @apply stroke-blue-500;
  }
  
  .user-cursor {
    @apply absolute w-4 h-4 -mt-1 -ml-1 pointer-events-none transition-all duration-100;
  }
}
```

## Component Communication

### Events Flow

```
User Action → JavaScript Hook → LiveView Event → State Update → Re-render
                    ↓                                  ↓
              Electric Sync ← Database Update ← Business Logic
```

### PubSub Patterns

```elixir
# Broadcasting changes
defmodule PipelineEditor.PipelineEvents do
  def broadcast_step_added(pipeline_id, step) do
    Phoenix.PubSub.broadcast(
      PipelineEditor.PubSub,
      "pipeline:#{pipeline_id}",
      {:step_added, step}
    )
  end
end

# Handling broadcasts in LiveView
def handle_info({:step_added, step}, socket) do
  {:noreply, update(socket, :pipeline, &add_step_to_pipeline(&1, step))}
end
```

## Performance Optimizations

### 1. Temporary Assigns
```elixir
def mount(params, session, socket) do
  socket = assign(socket, 
    # Permanent assigns
    pipeline_id: params["id"],
    
    # Temporary assigns (not kept in memory)
    __temporary__: [:search_results, :notifications]
  )
  
  {:ok, socket}
end
```

### 2. Async Data Loading
```elixir
def handle_event("load_step_documentation", %{"type" => type}, socket) do
  self = self()
  
  Task.start(fn ->
    docs = PipelineEditor.Documentation.get_step_docs(type)
    send(self, {:documentation_loaded, docs})
  end)
  
  {:noreply, assign(socket, :loading_docs, true)}
end
```

### 3. Debounced Updates
```elixir
def handle_event("search_steps", %{"query" => query}, socket) do
  # Cancel previous timer
  if socket.assigns[:search_timer] do
    Process.cancel_timer(socket.assigns.search_timer)
  end
  
  # Set new timer
  timer = Process.send_after(self(), {:do_search, query}, 300)
  
  {:noreply, assign(socket, search_timer: timer, search_query: query)}
end
```

## Testing Components

```elixir
defmodule PipelineEditorWeb.Components.CanvasTest do
  use PipelineEditorWeb.ConnCase
  import Phoenix.LiveViewTest
  
  test "adds a new step on drop", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pipelines/#{pipeline.id}/edit")
    
    view
    |> element(".canvas-container")
    |> render_hook("add_step", %{type: "claude", x: 100, y: 100})
    
    assert has_element?(view, "[data-step-type='claude']")
  end
  
  test "updates step position on drag", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/pipelines/#{pipeline.id}/edit")
    
    view
    |> element("[data-step-id='#{step.id}']")
    |> render_hook("move_step", %{id: step.id, x: 200, y: 200})
    
    assert has_element?(view, "[style*='left: 200px'][style*='top: 200px']")
  end
end
```