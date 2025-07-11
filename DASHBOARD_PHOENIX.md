# Pipeline Execution Dashboard - Phoenix LiveView Design

## Overview
A real-time Phoenix LiveView dashboard providing complete visibility into pipeline execution, from step-by-step progress to detailed prompt/response inspection and performance analytics.

## Core Architecture

### LiveView Components Structure
```
/lib/pipeline_dashboard_web/live/
├── pipeline_live.ex              # Main dashboard controller
├── components/
│   ├── pipeline_overview.ex      # Active pipelines grid
│   ├── step_execution.ex         # Individual step details
│   ├── prompt_inspector.ex       # Prompt/response viewer
│   ├── performance_metrics.ex    # Real-time performance charts
│   ├── log_viewer.ex            # Streaming log viewer
│   └── pipeline_controls.ex      # Start/stop/config controls
```

## Main Dashboard Layout

### Header Bar
```elixir
defmodule PipelineDashboardWeb.Components.HeaderBar do
  use Phoenix.LiveComponent
  
  # Real-time status indicators
  # - Active pipelines count
  # - Total token usage (live counter)
  # - Current cost estimate
  # - System health indicators
end
```

### Primary Grid Layout (4-quadrant)

#### Quadrant 1: Active Pipelines Overview
```elixir
defmodule PipelineDashboardWeb.Components.PipelineOverview do
  use Phoenix.LiveComponent
  
  # Features:
  # - Live grid of running pipelines
  # - Progress bars for each pipeline
  # - Current step indicators
  # - Status (running/waiting/error/complete)
  # - Click to drill-down to specific pipeline
  # - Quick actions (pause/resume/cancel)
end
```

#### Quadrant 2: Step Execution Detail
```elixir
defmodule PipelineDashboardWeb.Components.StepExecution do
  use Phoenix.LiveComponent
  
  # Features:
  # - Selected pipeline's current step details
  # - Step timeline/progress
  # - Provider being used (Gemini/Claude)
  # - Token budget vs actual usage
  # - Execution time (live timer)
  # - Step parameters and configuration
  # - Input/output preview
end
```

#### Quadrant 3: Prompt Inspector
```elixir
defmodule PipelineDashboardWeb.Components.PromptInspector do
  use Phoenix.LiveComponent
  
  # Features:
  # - Full prompt content viewer (syntax highlighted)
  # - Response content viewer (streaming if active)
  # - Prompt template breakdown
  # - Variable substitution details
  # - Token count analysis
  # - Copy/export functionality
  # - Search within content
end
```

#### Quadrant 4: Performance Metrics
```elixir
defmodule PipelineDashboardWeb.Components.PerformanceMetrics do
  use Phoenix.LiveComponent
  
  # Features:
  # - Real-time charts (using Chart.js via Hook)
  # - Token usage over time
  # - Response time distributions
  # - Cost tracking
  # - Error rate monitoring
  # - Throughput metrics
end
```

## Secondary Views

### Full-Screen Log Viewer
```elixir
defmodule PipelineDashboardWeb.Components.LogViewer do
  use Phoenix.LiveComponent
  
  # Features:
  # - Streaming log output (WebSocket based)
  # - Log level filtering
  # - Search and filtering
  # - Auto-scroll toggle
  # - Export log segments
  # - Syntax highlighting for structured logs
end
```

### Pipeline Configuration Panel
```elixir
defmodule PipelineDashboardWeb.Components.PipelineControls do
  use Phoenix.LiveComponent
  
  # Features:
  # - Load/select pipeline YAML files
  # - Real-time YAML editor with validation
  # - Start/stop pipeline execution
  # - Environment variable override
  # - Provider selection and API key management
  # - Batch execution controls
end
```

## Real-Time Data Flow

### WebSocket Events
```elixir
# Events the dashboard subscribes to:
%{
  "pipeline:started" => %{pipeline_id: string, config: map},
  "pipeline:completed" => %{pipeline_id: string, results: map},
  "pipeline:error" => %{pipeline_id: string, error: string},
  
  "step:started" => %{pipeline_id: string, step_name: string, provider: string},
  "step:completed" => %{pipeline_id: string, step_name: string, duration_ms: integer},
  "step:progress" => %{pipeline_id: string, step_name: string, tokens_used: integer},
  
  "prompt:sent" => %{pipeline_id: string, step_name: string, prompt: string, token_count: integer},
  "response:received" => %{pipeline_id: string, step_name: string, response: string, streaming: boolean},
  "response:streaming" => %{pipeline_id: string, step_name: string, chunk: string},
  
  "metrics:updated" => %{tokens_total: integer, cost_total: float, performance: map},
  "log:entry" => %{level: string, message: string, timestamp: string, context: map}
}
```

### State Management
```elixir
defmodule PipelineDashboardWeb.PipelineLive do
  use Phoenix.LiveView
  
  def mount(_params, _session, socket) do
    # Subscribe to pipeline events
    Pipeline.PubSub.subscribe("pipeline:*")
    Pipeline.PubSub.subscribe("metrics:*")
    Pipeline.PubSub.subscribe("logs:*")
    
    {:ok, assign(socket,
      active_pipelines: %{},
      selected_pipeline: nil,
      selected_step: nil,
      metrics: %{},
      logs: [],
      page_title: "Pipeline Dashboard"
    )}
  end
  
  def handle_info({:pipeline_event, event, data}, socket) do
    # Update state based on pipeline events
    # Trigger LiveView updates for real-time UI
  end
end
```

## Advanced Features

### Interactive Prompt Debugging
```elixir
defmodule PipelineDashboardWeb.Components.PromptDebugger do
  use Phoenix.LiveComponent
  
  # Features:
  # - Step-through prompt construction
  # - Variable inspection and manipulation
  # - Template preview with test data
  # - A/B test prompt variations
  # - Prompt optimization suggestions
  # - Token usage prediction
end
```

### Pipeline Analytics Dashboard
```elixir
defmodule PipelineDashboardWeb.Components.Analytics do
  use Phoenix.LiveComponent
  
  # Features:
  # - Historical pipeline performance
  # - Cost analysis and optimization suggestions
  # - Success/failure rate trends
  # - Provider performance comparison
  # - Peak usage time analysis
  # - Custom metric dashboards
end
```

### Error Diagnostics Panel
```elixir
defmodule PipelineDashboardWeb.Components.ErrorDiagnostics do
  use Phoenix.LiveComponent
  
  # Features:
  # - Real-time error detection and alerts
  # - Error categorization and frequency
  # - Stack trace and context inspection
  # - Suggested fixes and retry mechanisms
  # - Error rate alerts and notifications
end
```

## Technical Implementation

### Database Schema (for persistence)
```sql
-- Store pipeline execution history
CREATE TABLE pipeline_executions (
  id UUID PRIMARY KEY,
  pipeline_name VARCHAR NOT NULL,
  config JSONB NOT NULL,
  started_at TIMESTAMP NOT NULL,
  completed_at TIMESTAMP,
  status VARCHAR NOT NULL, -- running, completed, failed
  total_tokens INTEGER,
  total_cost DECIMAL,
  results JSONB
);

-- Store step execution details
CREATE TABLE step_executions (
  id UUID PRIMARY KEY,
  pipeline_execution_id UUID REFERENCES pipeline_executions(id),
  step_name VARCHAR NOT NULL,
  provider VARCHAR NOT NULL,
  started_at TIMESTAMP NOT NULL,
  completed_at TIMESTAMP,
  prompt_text TEXT,
  response_text TEXT,
  tokens_used INTEGER,
  duration_ms INTEGER,
  status VARCHAR NOT NULL
);

-- Store metrics snapshots
CREATE TABLE metrics_snapshots (
  id UUID PRIMARY KEY,
  timestamp TIMESTAMP NOT NULL,
  total_pipelines_running INTEGER,
  total_tokens_used INTEGER,
  total_cost DECIMAL,
  avg_response_time_ms INTEGER,
  error_rate DECIMAL
);
```

### CSS/Styling Framework
- TailwindCSS for responsive layout
- Custom dark theme optimized for monitoring
- Color-coded status indicators
- Smooth animations for state transitions
- Mobile-responsive breakpoints

### JavaScript Hooks for Enhanced Interactivity
```javascript
// Chart.js integration for real-time metrics
Hooks.MetricsChart = {
  mounted() {
    this.initChart();
    this.handleEvent("metrics:update", (data) => {
      this.updateChart(data);
    });
  }
};

// Code syntax highlighting
Hooks.CodeHighlight = {
  mounted() {
    Prism.highlightElement(this.el);
  },
  updated() {
    Prism.highlightElement(this.el);
  }
};

// Auto-scroll log viewer
Hooks.AutoScroll = {
  mounted() {
    this.shouldAutoScroll = true;
    this.handleEvent("log:new", () => {
      if (this.shouldAutoScroll) {
        this.el.scrollTop = this.el.scrollHeight;
      }
    });
  }
};
```

## Navigation & UX

### Keyboard Shortcuts
- `Space`: Pause/resume selected pipeline
- `Esc`: Clear selection/go back
- `Ctrl+F`: Search in current view
- `Ctrl+L`: Focus log viewer
- `Ctrl+P`: Open pipeline selector
- `F5`: Refresh/reload current view

### Context Menus
- Right-click pipeline → copy config, export results, view logs
- Right-click step → copy prompt, copy response, view raw data
- Right-click metrics → export data, create alert

### Responsive Design
- Desktop: 4-quadrant layout
- Tablet: 2x2 grid with collapsible panels
- Mobile: Single-column stack with navigation tabs

This dashboard provides complete visibility into pipeline execution while maintaining excellent UX for monitoring, debugging, and optimizing AI workflows.