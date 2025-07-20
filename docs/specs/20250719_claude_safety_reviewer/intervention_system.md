# Intervention System - Detailed Design

## Overview

The Intervention System is responsible for taking corrective actions when the Step Reviewer or Pattern Detector identifies issues with Claude's behavior. It implements a graduated response system from gentle guidance to emergency stops.

## Intervention Types

### 1. Soft Correction (Message Injection)

Injects helpful guidance into Claude's conversation to steer it back on track.

```elixir
defmodule Pipeline.Safety.Interventions.SoftCorrection do
  @behaviour Pipeline.Safety.Intervention
  
  @impl true
  def intervene(state, issue, context) do
    correction_prompt = generate_correction_prompt(issue, context)
    
    # Inject the correction into Claude's message stream
    updated_state = %{state |
      messages: state.messages ++ [correction_prompt],
      intervention_count: state.intervention_count + 1
    }
    
    {:continue, updated_state, log_intervention(issue, :soft_correction)}
  end
  
  defp generate_correction_prompt(issue, context) do
    base_prompt = case issue.type do
      :repetitive_errors ->
        """
        I notice you're encountering the same error repeatedly. Let's try a different approach:
        1. First, let's verify the file path exists: #{issue.details.file_path}
        2. Check if you have the necessary permissions
        3. Consider if there's a typo in the path
        
        What specific error message are you seeing?
        """
        
      :scope_creep ->
        """
        Let's refocus on the original task. You were asked to: #{context.original_prompt}
        
        The files you should be working with are in: #{Enum.join(context.expected_paths, ", ")}
        
        Is there a specific reason you need to access #{issue.details.out_of_scope_path}?
        """
        
      :goal_drift ->
        """
        Let's ensure we're still aligned with the main objective: #{context.primary_goal}
        
        Current progress:
        #{format_progress(context.completed_subtasks)}
        
        What's the next step toward completing the main goal?
        """
        
      :resource_spiral ->
        """
        Resource usage is increasing rapidly. Let's optimize:
        1. Are there any unnecessary operations we can eliminate?
        2. Can we process data in smaller batches?
        3. Should we clean up temporary files?
        
        Current resource usage: #{format_resources(issue.details.resources)}
        """
        
      _ ->
        """
        I've detected a potential issue: #{issue.description}
        Let's reconsider our approach. What are you trying to accomplish?
        """
    end
    
    %{
      role: "system",
      content: base_prompt,
      metadata: %{
        type: :intervention,
        intervention_type: :soft_correction,
        issue_type: issue.type,
        timestamp: DateTime.utc_now()
      }
    }
  end
end
```

### 2. Context Reinforcement

Reinforces the original context and constraints when Claude starts to deviate.

```elixir
defmodule Pipeline.Safety.Interventions.ContextReinforcement do
  @behaviour Pipeline.Safety.Intervention
  
  @impl true
  def intervene(state, issue, context) do
    reinforced_context = build_reinforced_context(state, issue, context)
    
    # Update Claude's context window
    updated_state = %{state |
      context: merge_contexts(state.context, reinforced_context),
      messages: add_reinforcement_message(state.messages, reinforced_context)
    }
    
    {:continue, updated_state, log_intervention(issue, :context_reinforcement)}
  end
  
  defp build_reinforced_context(state, issue, original_context) do
    %{
      original_prompt: original_context.original_prompt,
      constraints: emphasize_constraints(original_context.constraints, issue),
      boundaries: clarify_boundaries(original_context.boundaries, issue),
      goals: prioritize_goals(original_context.goals, state.progress),
      examples: provide_relevant_examples(issue)
    }
  end
  
  defp emphasize_constraints(constraints, issue) do
    emphasized = case issue.type do
      :scope_creep ->
        constraints ++ [
          "IMPORTANT: Only work with files in the specified directories",
          "Do not access system files or configuration outside the project"
        ]
        
      :resource_spiral ->
        constraints ++ [
          "IMPORTANT: Optimize for efficiency - avoid unnecessary operations",
          "Process data incrementally rather than loading everything at once"
        ]
        
      _ -> constraints
    end
    
    # Highlight the most relevant constraints
    Enum.map(emphasized, fn constraint ->
      if relevant_to_issue?(constraint, issue) do
        "**#{constraint}**"
      else
        constraint
      end
    end)
  end
  
  defp add_reinforcement_message(messages, reinforced_context) do
    reinforcement = %{
      role: "system",
      content: """
      Let me remind you of the key aspects of this task:
      
      **Original Request**: #{reinforced_context.original_prompt}
      
      **Key Constraints**:
      #{format_constraints(reinforced_context.constraints)}
      
      **Current Goals** (in priority order):
      #{format_goals(reinforced_context.goals)}
      
      **Boundaries**:
      #{format_boundaries(reinforced_context.boundaries)}
      
      Please proceed with these guidelines in mind.
      """,
      metadata: %{
        type: :intervention,
        intervention_type: :context_reinforcement
      }
    }
    
    messages ++ [reinforcement]
  end
end
```

### 3. Resource Throttling

Applies resource limits to prevent runaway consumption.

```elixir
defmodule Pipeline.Safety.Interventions.ResourceThrottling do
  @behaviour Pipeline.Safety.Intervention
  
  @impl true
  def intervene(state, issue, context) do
    current_limits = state.resource_limits
    throttled_limits = apply_throttling(current_limits, issue.details)
    
    # Apply new limits
    updated_state = %{state |
      resource_limits: throttled_limits,
      messages: add_throttling_notice(state.messages, throttled_limits)
    }
    
    # Also inject guidance on efficient resource usage
    guidance = generate_efficiency_guidance(issue.details)
    final_state = %{updated_state |
      messages: updated_state.messages ++ [guidance]
    }
    
    {:continue, final_state, log_intervention(issue, :resource_throttling)}
  end
  
  defp apply_throttling(current_limits, issue_details) do
    # Reduce limits based on the type of resource spiral
    %{
      max_file_operations: reduce_limit(
        current_limits.max_file_operations,
        issue_details.file_operation_growth
      ),
      max_memory_mb: reduce_limit(
        current_limits.max_memory_mb,
        issue_details.memory_growth
      ),
      max_tokens: reduce_limit(
        current_limits.max_tokens,
        issue_details.token_usage_growth
      ),
      max_execution_time: reduce_limit(
        current_limits.max_execution_time,
        issue_details.time_growth
      ),
      batch_size: max(current_limits.batch_size / 2, 1)
    }
  end
  
  defp reduce_limit(current, growth_rate) do
    reduction_factor = case growth_rate do
      r when r > 2.0 -> 0.5   # Halve the limit for extreme growth
      r when r > 1.5 -> 0.7   # 30% reduction for high growth
      r when r > 1.2 -> 0.85  # 15% reduction for moderate growth
      _ -> 1.0                # No reduction
    end
    
    round(current * reduction_factor)
  end
  
  defp add_throttling_notice(messages, new_limits) do
    notice = %{
      role: "system",
      content: """
      Resource limits have been adjusted to prevent system overload:
      - Max file operations: #{new_limits.max_file_operations}
      - Memory limit: #{new_limits.max_memory_mb}MB
      - Token limit: #{new_limits.max_tokens}
      - Batch size: #{new_limits.batch_size}
      
      Please work within these constraints.
      """,
      metadata: %{
        type: :intervention,
        intervention_type: :resource_throttling,
        limits: new_limits
      }
    }
    
    messages ++ [notice]
  end
end
```

### 4. Checkpoint and Rollback

Saves state and rolls back to a known good checkpoint.

```elixir
defmodule Pipeline.Safety.Interventions.CheckpointRollback do
  @behaviour Pipeline.Safety.Intervention
  
  @impl true
  def intervene(state, issue, context) do
    # Find the best checkpoint to roll back to
    checkpoint = select_rollback_checkpoint(state.checkpoints, issue)
    
    case checkpoint do
      nil ->
        # No suitable checkpoint, try recovery
        {:recovery_needed, state, create_recovery_plan(state, issue)}
        
      checkpoint ->
        # Perform rollback
        rolled_back_state = perform_rollback(state, checkpoint)
        
        # Add guidance for avoiding the issue
        guided_state = add_rollback_guidance(rolled_back_state, issue, checkpoint)
        
        {:continue, guided_state, log_intervention(issue, :checkpoint_rollback)}
    end
  end
  
  defp select_rollback_checkpoint(checkpoints, issue) do
    # Find the most recent checkpoint before the issue started
    issue_start_time = estimate_issue_start(issue)
    
    checkpoints
    |> Enum.filter(fn cp -> cp.timestamp < issue_start_time end)
    |> Enum.filter(fn cp -> checkpoint_is_safe?(cp, issue) end)
    |> Enum.max_by(fn cp -> cp.timestamp end, fn -> nil end)
  end
  
  defp perform_rollback(state, checkpoint) do
    %{
      # Restore file system state
      files: restore_files(checkpoint.file_snapshot),
      
      # Reset conversation to checkpoint
      messages: checkpoint.messages,
      
      # Restore context
      context: checkpoint.context,
      
      # Keep intervention history
      intervention_history: state.intervention_history ++ [
        %{
          type: :rollback,
          from_state: summarize_state(state),
          to_checkpoint: checkpoint.id,
          timestamp: DateTime.utc_now()
        }
      ],
      
      # Reset but remember resource limits
      resource_limits: checkpoint.resource_limits,
      resource_usage: %{},
      
      # Maintain pattern detection data
      pattern_history: state.pattern_history
    }
  end
  
  defp add_rollback_guidance(state, issue, checkpoint) do
    guidance = %{
      role: "system",
      content: """
      I've rolled back to a previous checkpoint due to: #{issue.description}
      
      **Checkpoint**: #{format_checkpoint_info(checkpoint)}
      
      **What went wrong**: #{analyze_issue(issue)}
      
      **Suggested approach**:
      #{generate_alternative_approach(issue, state.context)}
      
      Let's try again with this approach in mind.
      """,
      metadata: %{
        type: :intervention,
        intervention_type: :checkpoint_rollback,
        checkpoint_id: checkpoint.id
      }
    }
    
    %{state | messages: state.messages ++ [guidance]}
  end
  
  defp restore_files(file_snapshot) do
    Enum.each(file_snapshot, fn {path, content} ->
      case content do
        :deleted -> File.rm(path)
        content -> File.write!(path, content)
      end
    end)
  end
end
```

### 5. Emergency Stop

Immediately halts execution when critical issues are detected.

```elixir
defmodule Pipeline.Safety.Interventions.EmergencyStop do
  @behaviour Pipeline.Safety.Intervention
  
  @impl true
  def intervene(state, issue, context) do
    # Save current state for analysis
    incident_id = save_incident(state, issue, context)
    
    # Create detailed report
    report = create_incident_report(incident_id, state, issue)
    
    # Notify relevant parties
    notify_emergency_stop(incident_id, report)
    
    # Return stop signal with explanation
    {:stop, 
     %{
       reason: :emergency_stop,
       issue: issue,
       incident_id: incident_id,
       report: report,
       recovery_options: suggest_recovery_options(state, issue)
     },
     log_intervention(issue, :emergency_stop)
    }
  end
  
  defp save_incident(state, issue, context) do
    incident_id = generate_incident_id()
    
    incident_data = %{
      id: incident_id,
      timestamp: DateTime.utc_now(),
      issue: issue,
      state_snapshot: sanitize_state(state),
      context: context,
      pattern_detections: get_recent_patterns(state),
      resource_usage: state.resource_usage,
      action_history: get_recent_actions(state, 50)
    }
    
    # Persist to disk for debugging
    save_incident_to_disk(incident_id, incident_data)
    
    incident_id
  end
  
  defp create_incident_report(incident_id, state, issue) do
    %{
      incident_id: incident_id,
      summary: "Emergency stop triggered due to #{issue.type}",
      severity: issue.severity,
      
      timeline: build_incident_timeline(state, issue),
      
      impact: %{
        files_affected: count_affected_files(state),
        resources_consumed: summarize_resources(state.resource_usage),
        duration: calculate_duration(state)
      },
      
      root_cause: analyze_root_cause(state, issue),
      
      contributing_factors: identify_contributing_factors(state, issue),
      
      recommendations: %{
        immediate: immediate_actions(issue),
        preventive: preventive_measures(issue),
        configuration: suggested_config_changes(issue)
      }
    }
  end
  
  defp suggest_recovery_options(state, issue) do
    [
      %{
        option: :resume_with_limits,
        description: "Resume with stricter safety limits",
        changes: %{
          resource_limits: calculate_strict_limits(state.resource_limits),
          allowed_tools: filter_dangerous_tools(state.allowed_tools),
          monitoring_level: :strict
        }
      },
      %{
        option: :rollback_and_retry,
        description: "Roll back to last safe checkpoint and retry",
        checkpoint: find_last_safe_checkpoint(state.checkpoints)
      },
      %{
        option: :manual_intervention,
        description: "Require manual approval for each action",
        approval_config: %{
          require_approval_for: [:file_write, :file_delete, :system_command],
          auto_approve: [:file_read]
        }
      },
      %{
        option: :abort,
        description: "Abort the pipeline execution",
        cleanup_required: identify_cleanup_tasks(state)
      }
    ]
  end
end
```

## Intervention Controller

The main controller that orchestrates interventions based on detected issues.

```elixir
defmodule Pipeline.Safety.InterventionController do
  use GenServer
  
  @intervention_modules %{
    soft_correction: Pipeline.Safety.Interventions.SoftCorrection,
    context_reinforcement: Pipeline.Safety.Interventions.ContextReinforcement,
    resource_throttling: Pipeline.Safety.Interventions.ResourceThrottling,
    checkpoint_rollback: Pipeline.Safety.Interventions.CheckpointRollback,
    emergency_stop: Pipeline.Safety.Interventions.EmergencyStop
  }
  
  def intervene(issue, state, context) do
    GenServer.call(__MODULE__, {:intervene, issue, state, context})
  end
  
  def handle_call({:intervene, issue, state, context}, _from, controller_state) do
    # Select appropriate intervention
    intervention_type = select_intervention(issue, state, controller_state)
    
    # Execute intervention
    intervention_module = @intervention_modules[intervention_type]
    result = intervention_module.intervene(state, issue, context)
    
    # Update controller state
    updated_controller = update_intervention_history(
      controller_state,
      intervention_type,
      issue,
      result
    )
    
    # Check if escalation is needed
    final_result = maybe_escalate(result, issue, updated_controller)
    
    {:reply, final_result, updated_controller}
  end
  
  defp select_intervention(issue, state, controller_state) do
    # Base selection on severity and history
    severity_score = calculate_severity_score(issue)
    
    # Check intervention history
    recent_interventions = get_recent_interventions(
      controller_state.intervention_history,
      :timer.minutes(5)
    )
    
    # Escalate if previous interventions failed
    escalation_level = calculate_escalation_level(
      recent_interventions,
      issue
    )
    
    select_by_severity_and_escalation(severity_score, escalation_level)
  end
  
  defp calculate_severity_score(issue) do
    base_score = case issue.severity do
      :low -> 0.2
      :medium -> 0.5
      :high -> 0.8
      :critical -> 1.0
    end
    
    # Adjust based on confidence and impact
    base_score * issue.confidence * (1 + issue.impact_factor)
  end
  
  defp select_by_severity_and_escalation(severity, escalation) do
    combined_score = severity + (escalation * 0.3)
    
    cond do
      combined_score >= 0.9 -> :emergency_stop
      combined_score >= 0.7 -> :checkpoint_rollback
      combined_score >= 0.5 -> :resource_throttling
      combined_score >= 0.3 -> :context_reinforcement
      true -> :soft_correction
    end
  end
  
  defp maybe_escalate({:continue, state, log}, issue, controller_state) do
    if should_escalate?(issue, controller_state) do
      # Escalate to next level
      escalated_intervention = get_next_intervention_level(
        controller_state.last_intervention_type
      )
      
      intervention_module = @intervention_modules[escalated_intervention]
      intervention_module.intervene(state, issue, controller_state.context)
    else
      {:continue, state, log}
    end
  end
  
  defp should_escalate?(issue, controller_state) do
    # Escalate if same issue persists after intervention
    similar_issues = count_similar_recent_issues(
      controller_state.issue_history,
      issue
    )
    
    similar_issues >= 2
  end
end
```

## Intervention Strategies

### 1. Progressive Intervention

```elixir
defmodule Pipeline.Safety.Strategies.ProgressiveIntervention do
  @doc """
  Implements a progressive intervention strategy that gradually
  increases intervention severity based on effectiveness
  """
  
  @progression [
    :soft_correction,
    :context_reinforcement,
    :resource_throttling,
    :checkpoint_rollback,
    :emergency_stop
  ]
  
  def next_intervention(current_level, effectiveness) do
    current_index = Enum.find_index(@progression, &(&1 == current_level))
    
    next_index = if effectiveness < 0.5 do
      # Ineffective, escalate
      min(current_index + 1, length(@progression) - 1)
    else
      # Effective, maintain or de-escalate
      max(current_index - 1, 0)
    end
    
    Enum.at(@progression, next_index)
  end
end
```

### 2. Pattern-Specific Interventions

```elixir
defmodule Pipeline.Safety.Strategies.PatternSpecific do
  @pattern_interventions %{
    repetitive_errors: [
      :soft_correction,
      :context_reinforcement,
      :checkpoint_rollback
    ],
    scope_creep: [
      :context_reinforcement,
      :resource_throttling,
      :emergency_stop
    ],
    resource_spiral: [
      :resource_throttling,
      :checkpoint_rollback,
      :emergency_stop
    ],
    goal_drift: [
      :soft_correction,
      :context_reinforcement,
      :checkpoint_rollback
    ],
    hallucination: [
      :context_reinforcement,
      :checkpoint_rollback,
      :emergency_stop
    ]
  }
  
  def select_intervention(pattern_type, severity) do
    interventions = @pattern_interventions[pattern_type] || @pattern_interventions[:default]
    
    index = case severity do
      :low -> 0
      :medium -> 1
      :high -> 2
      :critical -> length(interventions) - 1
    end
    
    Enum.at(interventions, index)
  end
end
```

## Configuration

### 1. Intervention Configuration

```yaml
interventions:
  # Global settings
  enabled: true
  max_interventions_per_execution: 10
  intervention_cooldown_seconds: 30
  
  # Intervention-specific settings
  soft_correction:
    enabled: true
    max_attempts: 3
    custom_prompts_path: ./config/intervention_prompts.yaml
    
  context_reinforcement:
    enabled: true
    reinforcement_strength: medium  # light | medium | strong
    include_examples: true
    
  resource_throttling:
    enabled: true
    reduction_factors:
      moderate: 0.85
      aggressive: 0.5
      severe: 0.25
    metrics_window_seconds: 60
    
  checkpoint_rollback:
    enabled: true
    max_rollback_depth: 3
    checkpoint_retention_minutes: 30
    safe_checkpoint_criteria:
      min_success_rate: 0.8
      no_errors_duration_seconds: 60
      
  emergency_stop:
    enabled: true
    auto_cleanup: false
    notification_channels:
      - email
      - slack
    preserve_incident_data_days: 30
    
  # Strategy configuration
  strategy:
    type: progressive  # progressive | pattern_specific | custom
    effectiveness_threshold: 0.6
    escalation_delay_seconds: 120
```

### 2. Custom Intervention Handlers

```elixir
defmodule MyCustomIntervention do
  @behaviour Pipeline.Safety.Intervention
  
  @impl true
  def intervene(state, issue, context) do
    # Custom intervention logic
    case issue.type do
      :my_custom_pattern ->
        handle_custom_pattern(state, issue, context)
      _ ->
        {:continue, state, %{}}
    end
  end
  
  defp handle_custom_pattern(state, issue, context) do
    # Implementation
  end
end

# Register custom intervention
Pipeline.Safety.InterventionController.register_intervention(
  :my_custom_intervention,
  MyCustomIntervention
)
```

## Monitoring and Metrics

### 1. Intervention Metrics

```elixir
defmodule Pipeline.Safety.Interventions.Metrics do
  def record_intervention(type, issue, outcome) do
    labels = %{
      intervention_type: to_string(type),
      issue_type: to_string(issue.type),
      outcome: to_string(outcome)
    }
    
    :telemetry.execute(
      [:pipeline, :safety, :intervention],
      %{count: 1},
      labels
    )
    
    # Record intervention effectiveness
    if outcome in [:success, :failure] do
      effectiveness = calculate_effectiveness(issue, outcome)
      
      :telemetry.execute(
        [:pipeline, :safety, :intervention, :effectiveness],
        %{value: effectiveness},
        labels
      )
    end
  end
  
  def intervention_dashboard() do
    %{
      graphs: [
        %{
          title: "Interventions by Type",
          query: "sum by (intervention_type) (rate(pipeline_safety_intervention_total[5m]))"
        },
        %{
          title: "Intervention Effectiveness",
          query: "avg by (intervention_type) (pipeline_safety_intervention_effectiveness)"
        },
        %{
          title: "Escalation Rate",
          query: "rate(pipeline_safety_intervention_escalation_total[5m])"
        }
      ]
    }
  end
end
```

## Testing

### 1. Intervention Testing Framework

```elixir
defmodule Pipeline.Safety.InterventionTest do
  use ExUnit.Case
  
  describe "soft correction" do
    test "generates appropriate correction for repetitive errors" do
      issue = %{
        type: :repetitive_errors,
        details: %{file_path: "/test/file.ex"},
        severity: :medium
      }
      
      state = %{messages: [], intervention_count: 0}
      
      {:continue, new_state, _log} = 
        SoftCorrection.intervene(state, issue, %{})
      
      assert length(new_state.messages) == 1
      assert new_state.messages |> List.last() |> Map.get(:content) =~ "different approach"
    end
  end
  
  describe "emergency stop" do
    test "creates incident and stops execution" do
      issue = %{
        type: :critical_security_violation,
        severity: :critical,
        details: %{violated_rule: "no_system_access"}
      }
      
      {:stop, result, _log} = 
        EmergencyStop.intervene(%{}, issue, %{})
      
      assert result.reason == :emergency_stop
      assert result.incident_id != nil
      assert length(result.recovery_options) > 0
    end
  end
end
```