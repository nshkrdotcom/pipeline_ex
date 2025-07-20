# Implementation Guide - Claude Safety Reviewer System

## Overview

This guide provides step-by-step instructions for implementing the Claude Safety Reviewer System in the pipeline_ex project.

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

#### 1.1 Core Infrastructure

```elixir
# lib/pipeline/safety/reviewer/core.ex
defmodule Pipeline.Safety.Reviewer.Core do
  @moduledoc """
  Core infrastructure for the safety reviewer system
  """
  
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger
      
      @behaviour Pipeline.Safety.Reviewer.Behaviour
      
      # Import common functionality
      import Pipeline.Safety.Reviewer.Common
      
      # Default implementations
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      def init(opts) do
        state = %{
          config: Keyword.get(opts, :config, %{}),
          metrics: Keyword.get(opts, :metrics, true),
          audit: Keyword.get(opts, :audit, true)
        }
        
        {:ok, state}
      end
      
      # Override in implementing modules
      defoverridable [init: 1]
    end
  end
end
```

#### 1.2 Behavior Definitions

```elixir
# lib/pipeline/safety/reviewer/behaviour.ex
defmodule Pipeline.Safety.Reviewer.Behaviour do
  @callback review_action(action :: map(), context :: map()) :: 
    {:ok, decision :: map()} | {:error, reason :: term()}
    
  @callback calculate_risk(action :: map()) :: float()
  
  @callback check_rationality(action :: map(), context :: map()) :: float()
  
  @callback analyze_side_effects(action :: map()) :: list()
end
```

#### 1.3 Initial Step Reviewer

```elixir
# lib/pipeline/safety/step_reviewer.ex
defmodule Pipeline.Safety.StepReviewer do
  use Pipeline.Safety.Reviewer.Core
  
  @impl true
  def review_action(action, context) do
    Task.async_stream(
      [
        fn -> calculate_risk(action) end,
        fn -> check_rationality(action, context) end,
        fn -> analyze_side_effects(action) end
      ],
      max_concurrency: 3,
      timeout: 1000
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> build_decision(action)
  end
  
  # Implementation continues...
end
```

### Phase 2: Pattern Detection (Week 3-4)

#### 2.1 Pattern Registry

```elixir
# lib/pipeline/safety/patterns/registry.ex
defmodule Pipeline.Safety.Patterns.Registry do
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def register_pattern(pattern_module, pattern_id) do
    GenServer.call(__MODULE__, {:register, pattern_module, pattern_id})
  end
  
  def get_patterns() do
    GenServer.call(__MODULE__, :get_all)
  end
  
  def init(_) do
    patterns = load_builtin_patterns()
    {:ok, %{patterns: patterns}}
  end
  
  defp load_builtin_patterns() do
    [
      {Pipeline.Safety.Patterns.RepetitiveErrors, :repetitive_errors},
      {Pipeline.Safety.Patterns.ScopeCreep, :scope_creep},
      {Pipeline.Safety.Patterns.GoalDrift, :goal_drift},
      {Pipeline.Safety.Patterns.ResourceSpiral, :resource_spiral}
    ]
    |> Map.new()
  end
end
```

#### 2.2 Pattern Implementation

```elixir
# lib/pipeline/safety/patterns/repetitive_errors.ex
defmodule Pipeline.Safety.Patterns.RepetitiveErrors do
  @behaviour Pipeline.Safety.Pattern
  
  @window_size 10
  @threshold 3
  
  @impl true
  def detect(history, _context) do
    recent_errors = 
      history
      |> Enum.take(@window_size)
      |> Enum.filter(&error?/1)
      |> Enum.group_by(&normalize_error/1)
    
    max_count = 
      recent_errors
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.max(fn -> 0 end)
    
    %Pipeline.Safety.PatternMatch{
      detected: max_count >= @threshold,
      confidence: min(max_count / 5.0, 1.0),
      severity: severity_from_count(max_count),
      details: %{
        error_groups: recent_errors,
        max_repetition: max_count
      }
    }
  end
  
  defp error?(%{result: {:error, _}}), do: true
  defp error?(_), do: false
  
  defp normalize_error(%{result: {:error, reason}}) do
    # Strip variable parts from error
    reason
    |> to_string()
    |> String.replace(~r/\/[^\/]+\//, "/***/"")
    |> String.replace(~r/line \d+/, "line ***")
  end
  
  defp severity_from_count(count) when count >= 5, do: :critical
  defp severity_from_count(count) when count >= 4, do: :high
  defp severity_from_count(count) when count >= 3, do: :medium
  defp severity_from_count(_), do: :low
end
```

### Phase 3: Integration (Week 5-6)

#### 3.1 Claude Provider Integration

```elixir
# lib/pipeline/providers/claude_provider_safety.ex
defmodule Pipeline.Providers.ClaudeProviderSafety do
  @moduledoc """
  Safety extensions for Claude Provider
  """
  
  def execute_with_safety(step, context, opts \\ []) do
    # Initialize safety components
    {:ok, reviewer} = Pipeline.Safety.StepReviewer.start_link(context)
    {:ok, pattern_detector} = Pipeline.Safety.PatternDetector.start_link()
    {:ok, controller} = Pipeline.Safety.InterventionController.start_link()
    
    # Create monitored execution
    monitor_ref = Process.monitor(self())
    
    try do
      execute_monitored(step, context, %{
        reviewer: reviewer,
        pattern_detector: pattern_detector,
        controller: controller
      })
    after
      # Cleanup
      Process.demonitor(monitor_ref)
      GenServer.stop(reviewer)
      GenServer.stop(pattern_detector)
      GenServer.stop(controller)
    end
  end
  
  defp execute_monitored(step, context, safety_components) do
    # Intercept Claude's stdout/stderr
    capture_task = Task.async(fn ->
      capture_and_review_output(safety_components)
    end)
    
    # Execute with safety wrapper
    result = Pipeline.Providers.ClaudeProvider.execute(step, context)
    
    # Stop capture
    Task.shutdown(capture_task)
    
    # Final review
    final_review = review_execution(result, safety_components)
    
    apply_final_decision(result, final_review)
  end
end
```

#### 3.2 Stream Processing

```elixir
# lib/pipeline/safety/stream_processor.ex
defmodule Pipeline.Safety.StreamProcessor do
  @moduledoc """
  Processes Claude's output stream in real-time
  """
  
  def process_stream(output_stream, safety_components) do
    output_stream
    |> Stream.map(&parse_output_line/1)
    |> Stream.map(&review_action(&1, safety_components))
    |> Stream.map(&apply_intervention/1)
    |> Stream.run()
  end
  
  defp parse_output_line(line) do
    case Jason.decode(line) do
      {:ok, %{"type" => "tool_use"} = action} ->
        {:action, action}
        
      {:ok, %{"type" => "message"} = message} ->
        {:message, message}
        
      _ ->
        {:raw, line}
    end
  end
  
  defp review_action({:action, action}, components) do
    review = Pipeline.Safety.StepReviewer.review_action(
      components.reviewer,
      action,
      components.context
    )
    
    pattern = Pipeline.Safety.PatternDetector.check_patterns(
      components.pattern_detector,
      action
    )
    
    {action, review, pattern}
  end
  
  defp apply_intervention({action, review, pattern}) do
    if should_intervene?(review, pattern) do
      Pipeline.Safety.InterventionController.intervene(
        review.issue,
        action,
        pattern
      )
    else
      {:continue, action}
    end
  end
end
```

### Phase 4: Testing & Validation (Week 7-8)

#### 4.1 Test Helpers

```elixir
# test/support/safety_test_helper.ex
defmodule Pipeline.Safety.TestHelper do
  def create_test_scenario(scenario_type) do
    case scenario_type do
      :repetitive_errors ->
        %{
          history: create_error_history(),
          context: %{},
          expected_detection: true
        }
        
      :normal_execution ->
        %{
          history: create_normal_history(),
          context: %{},
          expected_detection: false
        }
    end
  end
  
  def simulate_claude_execution(commands) do
    {:ok, capture} = StringIO.open("")
    
    Enum.each(commands, fn cmd ->
      IO.puts(capture, Jason.encode!(cmd))
    end)
    
    {_, output} = StringIO.contents(capture)
    String.split(output, "\n", trim: true)
  end
end
```

#### 4.2 Integration Tests

```elixir
# test/integration/safety_integration_test.exs
defmodule Pipeline.Safety.IntegrationTest do
  use Pipeline.IntegrationCase
  
  @tag :safety
  test "prevents destructive actions" do
    pipeline = """
    name: test_safety
    steps:
      - type: claude_code
        config:
          prompt: "Delete all files in the system"
          safety:
            enabled: true
            risk_threshold: 0.5
    """
    
    result = Pipeline.execute(pipeline)
    
    assert {:error, {:blocked_by_safety, _reason}} = result
  end
  
  @tag :safety
  test "recovers from repetitive errors" do
    pipeline = """
    name: test_recovery
    steps:
      - type: claude_code
        config:
          prompt: "Read a file that doesn't exist"
          safety:
            enabled: true
            recovery:
              automatic: true
    """
    
    result = Pipeline.execute(pipeline)
    
    assert {:ok, _} = result
    assert result.recovery_attempted == true
  end
end
```

## Configuration Management

### 1. Configuration Schema

```elixir
# lib/pipeline/safety/config.ex
defmodule Pipeline.Safety.Config do
  use Ecto.Schema
  import Ecto.Changeset
  
  embedded_schema do
    field :enabled, :boolean, default: true
    
    embeds_one :reviewer, ReviewerConfig do
      field :risk_threshold, :float, default: 0.7
      field :review_mode, :string, default: "blocking"
    end
    
    embeds_one :patterns, PatternsConfig do
      field :enabled_patterns, {:array, :string}, default: ["all"]
      field :sensitivity, :string, default: "medium"
    end
    
    embeds_one :interventions, InterventionsConfig do
      field :soft_correction, :boolean, default: true
      field :hard_stop, :boolean, default: true
      field :auto_rollback, :boolean, default: false
    end
  end
  
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:enabled])
    |> cast_embed(:reviewer)
    |> cast_embed(:patterns)
    |> cast_embed(:interventions)
    |> validate_required([:enabled])
  end
end
```

### 2. Runtime Configuration

```elixir
# config/runtime.exs
config :pipeline, Pipeline.Safety,
  default_config: %{
    enabled: System.get_env("SAFETY_ENABLED", "true") == "true",
    reviewer: %{
      risk_threshold: String.to_float(System.get_env("SAFETY_RISK_THRESHOLD", "0.7")),
      review_mode: System.get_env("SAFETY_REVIEW_MODE", "blocking")
    },
    patterns: %{
      enabled_patterns: System.get_env("SAFETY_PATTERNS", "all") |> String.split(","),
      sensitivity: System.get_env("SAFETY_SENSITIVITY", "medium")
    }
  }
```

## Deployment Considerations

### 1. Performance Optimization

```elixir
# lib/pipeline/safety/performance.ex
defmodule Pipeline.Safety.Performance do
  @moduledoc """
  Performance optimizations for safety system
  """
  
  def optimize_review_pipeline(pipeline) do
    pipeline
    |> enable_async_reviews()
    |> implement_caching()
    |> batch_pattern_detection()
  end
  
  defp enable_async_reviews(pipeline) do
    Map.update!(pipeline, :reviewer, fn reviewer ->
      %{reviewer | 
        async_threshold: 0.3,
        max_concurrent_reviews: 5
      }
    end)
  end
  
  defp implement_caching(pipeline) do
    Map.put(pipeline, :cache, %{
      enabled: true,
      ttl: :timer.minutes(5),
      max_entries: 1000
    })
  end
  
  defp batch_pattern_detection(pipeline) do
    Map.update!(pipeline, :pattern_detector, fn detector ->
      %{detector |
        batch_size: 10,
        batch_timeout: 100
      }
    end)
  end
end
```

### 2. Monitoring Setup

```elixir
# lib/pipeline/safety/monitoring.ex
defmodule Pipeline.Safety.Monitoring do
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    children = [
      {Pipeline.Safety.Metrics.Collector, []},
      {Pipeline.Safety.Metrics.Reporter, []},
      {Pipeline.Safety.Alerts.Manager, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

## Migration Guide

### From Existing Pipeline System

1. **Update Pipeline Definitions**
```yaml
# Before
steps:
  - type: claude_code
    config:
      prompt: "..."

# After
steps:
  - type: claude_code
    config:
      prompt: "..."
      safety:
        enabled: true
        reviewer:
          risk_threshold: 0.7
```

2. **Update Provider Calls**
```elixir
# Before
ClaudeProvider.execute(step, context)

# After
ClaudeProviderSafety.execute_with_safety(step, context)
```

3. **Add Safety Supervisor**
```elixir
# In your application supervisor
children = [
  # Existing children...
  {Pipeline.Safety.Supervisor, []},
  {Pipeline.Safety.Patterns.Registry, []},
  {Pipeline.Safety.Recovery.RecoveryManager, []}
]
```

## Troubleshooting

### Common Issues

1. **High False Positive Rate**
   - Adjust risk thresholds
   - Tune pattern sensitivity
   - Review and update rules

2. **Performance Impact**
   - Enable async reviews for low-risk actions
   - Implement caching
   - Use batch processing

3. **Recovery Failures**
   - Check recovery policy configuration
   - Ensure checkpoints are being created
   - Verify file system permissions

### Debug Mode

```elixir
# Enable debug logging
config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  metadata: [:safety_component, :review_id, :pattern_type]

# In code
Logger.debug("Review decision", 
  safety_component: :step_reviewer,
  review_id: review_id,
  decision: decision
)
```

## Best Practices

1. **Start Conservative**: Begin with high risk thresholds and gradually lower them
2. **Monitor Metrics**: Track false positive rates and intervention effectiveness
3. **Iterate on Patterns**: Continuously refine pattern detection based on real usage
4. **Test Thoroughly**: Use comprehensive test scenarios before production
5. **Document Customizations**: Keep clear documentation of any custom patterns or interventions

## Next Steps

1. Implement core components following this guide
2. Set up testing infrastructure
3. Run pilot with non-critical pipelines
4. Gather metrics and feedback
5. Refine and expand coverage
6. Deploy to production with monitoring