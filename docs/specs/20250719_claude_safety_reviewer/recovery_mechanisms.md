# Recovery Mechanisms - Detailed Design

## Overview

Recovery Mechanisms provide ways to gracefully recover from interventions, errors, and unexpected situations during Claude Code SDK execution. The system focuses on maintaining progress while ensuring safety.

## Recovery Types

### 1. Automatic Recovery

Handles common issues without user intervention.

```elixir
defmodule Pipeline.Safety.Recovery.AutomaticRecovery do
  @moduledoc """
  Automatic recovery for common, well-understood issues
  """
  
  @recoverable_issues [
    :file_not_found,
    :permission_denied,
    :syntax_error,
    :import_error,
    :connection_timeout,
    :rate_limit_exceeded
  ]
  
  def attempt_recovery(state, error, context) do
    case categorize_error(error) do
      {:recoverable, error_type} ->
        recovery_strategy = select_recovery_strategy(error_type, context)
        execute_recovery(state, error, recovery_strategy)
        
      {:unrecoverable, reason} ->
        {:error, {:unrecoverable, reason}}
    end
  end
  
  defp select_recovery_strategy(error_type, context) do
    case error_type do
      :file_not_found ->
        %{
          strategy: :search_and_suggest,
          actions: [
            {:search_similar_files, context.working_directory},
            {:check_file_moves, context.git_history},
            {:suggest_alternatives, context.file_patterns}
          ]
        }
        
      :permission_denied ->
        %{
          strategy: :permission_adjustment,
          actions: [
            {:check_file_ownership, context.current_user},
            {:suggest_chmod, context.required_permissions},
            {:find_readable_alternative, context.file_type}
          ]
        }
        
      :syntax_error ->
        %{
          strategy: :syntax_correction,
          actions: [
            {:identify_syntax_issue, context.language},
            {:suggest_fix, context.error_location},
            {:validate_correction, context.linter}
          ]
        }
        
      :connection_timeout ->
        %{
          strategy: :retry_with_backoff,
          actions: [
            {:wait, :exponential_backoff},
            {:check_connectivity, context.endpoint},
            {:use_fallback, context.fallback_endpoints}
          ]
        }
    end
  end
  
  defp execute_recovery(state, error, strategy) do
    results = Enum.reduce_while(strategy.actions, state, fn action, acc_state ->
      case perform_action(action, acc_state, error) do
        {:ok, new_state} ->
          {:cont, new_state}
          
        {:recovered, final_state} ->
          {:halt, {:ok, final_state}}
          
        {:error, _reason} ->
          {:cont, acc_state}
      end
    end)
    
    case results do
      {:ok, recovered_state} -> 
        {:recovered, recovered_state}
      state ->
        {:partial_recovery, state}
    end
  end
end
```

### 2. Guided Recovery

Provides Claude with specific guidance to recover from issues.

```elixir
defmodule Pipeline.Safety.Recovery.GuidedRecovery do
  @moduledoc """
  Guides Claude through recovery with specific instructions
  """
  
  def guide_recovery(state, issue, context) do
    recovery_plan = create_recovery_plan(issue, context)
    
    guided_state = inject_recovery_guidance(state, recovery_plan)
    
    monitor_recovery_progress(guided_state, recovery_plan)
  end
  
  defp create_recovery_plan(issue, context) do
    %RecoveryPlan{
      id: generate_plan_id(),
      issue: issue,
      steps: generate_recovery_steps(issue, context),
      checkpoints: define_checkpoints(issue),
      success_criteria: define_success_criteria(issue),
      timeout: calculate_timeout(issue),
      fallback: define_fallback_plan(issue)
    }
  end
  
  defp generate_recovery_steps(issue, context) do
    case issue.type do
      :stuck_in_loop ->
        [
          %Step{
            instruction: "Let's break out of this loop. First, summarize what you've tried so far.",
            validation: &validate_summary/1
          },
          %Step{
            instruction: "Now, let's identify why the current approach isn't working.",
            validation: &validate_analysis/1
          },
          %Step{
            instruction: "Try this alternative approach: #{suggest_alternative(issue, context)}",
            validation: &validate_progress/1
          }
        ]
        
      :lost_context ->
        [
          %Step{
            instruction: "Let's re-establish context. What was the original task?",
            validation: &validate_task_understanding/1
          },
          %Step{
            instruction: "Review these key files to regain context: #{list_key_files(context)}",
            validation: &validate_file_review/1
          },
          %Step{
            instruction: "Now, what should be the next step to complete the task?",
            validation: &validate_plan/1
          }
        ]
        
      :resource_exhaustion ->
        [
          %Step{
            instruction: "Resource limits reached. Let's optimize. First, identify what's consuming resources.",
            validation: &validate_resource_analysis/1
          },
          %Step{
            instruction: "Clean up unnecessary resources: #{list_cleanup_targets(state)}",
            validation: &validate_cleanup/1
          },
          %Step{
            instruction: "Proceed with a more efficient approach: #{suggest_efficient_approach(issue)}",
            validation: &validate_efficiency/1
          }
        ]
    end
  end
  
  defp inject_recovery_guidance(state, plan) do
    intro_message = %{
      role: "system",
      content: """
      I'm going to help you recover from the current issue: #{plan.issue.description}
      
      We'll work through this step by step:
      #{format_plan_overview(plan)}
      
      Let's start with the first step.
      """,
      metadata: %{
        type: :recovery_guidance,
        plan_id: plan.id
      }
    }
    
    %{state | 
      messages: state.messages ++ [intro_message],
      active_recovery_plan: plan,
      recovery_mode: true
    }
  end
end
```

### 3. Checkpoint-Based Recovery

Uses saved checkpoints to restore to a known good state.

```elixir
defmodule Pipeline.Safety.Recovery.CheckpointRecovery do
  @moduledoc """
  Recovery using checkpoint system
  """
  
  defstruct [:checkpoint_store, :recovery_policy, :state_validator]
  
  def recover_from_checkpoint(current_state, issue) do
    suitable_checkpoints = find_suitable_checkpoints(
      current_state.checkpoints,
      issue
    )
    
    case suitable_checkpoints do
      [] ->
        {:error, :no_suitable_checkpoint}
        
      checkpoints ->
        best_checkpoint = select_best_checkpoint(checkpoints, issue)
        perform_checkpoint_recovery(current_state, best_checkpoint, issue)
    end
  end
  
  defp find_suitable_checkpoints(checkpoints, issue) do
    checkpoints
    |> Enum.filter(&checkpoint_predates_issue?(&1, issue))
    |> Enum.filter(&checkpoint_is_valid?/1)
    |> Enum.filter(&compatible_with_current_state?/1)
  end
  
  defp perform_checkpoint_recovery(current_state, checkpoint, issue) do
    # Phase 1: Prepare recovery
    recovery_context = prepare_recovery_context(current_state, checkpoint, issue)
    
    # Phase 2: Restore state
    restored_state = restore_checkpoint_state(checkpoint)
    
    # Phase 3: Apply learned information
    enhanced_state = apply_learnings(restored_state, recovery_context)
    
    # Phase 4: Inject recovery guidance
    final_state = inject_checkpoint_guidance(enhanced_state, checkpoint, issue)
    
    {:ok, final_state}
  end
  
  defp apply_learnings(restored_state, recovery_context) do
    %{restored_state |
      # Add patterns to avoid
      known_issues: restored_state.known_issues ++ recovery_context.issues_encountered,
      
      # Add successful paths discovered
      verified_paths: restored_state.verified_paths ++ recovery_context.working_paths,
      
      # Update constraints based on failures
      constraints: merge_constraints(
        restored_state.constraints,
        recovery_context.discovered_constraints
      ),
      
      # Add recovery metadata
      recovery_metadata: %{
        recovered_from: recovery_context.issue_type,
        recovery_time: DateTime.utc_now(),
        lessons_learned: recovery_context.lessons
      }
    }
  end
  
  defp inject_checkpoint_guidance(state, checkpoint, issue) do
    guidance = %{
      role: "system",
      content: """
      I've restored to a previous checkpoint to help you recover from: #{issue.description}
      
      **Restored to**: #{format_checkpoint(checkpoint)}
      
      **What we learned**:
      #{format_learnings(state.recovery_metadata.lessons_learned)}
      
      **Suggested approach**:
      #{suggest_new_approach(issue, state)}
      
      Let's continue from here with this knowledge.
      """,
      metadata: %{
        type: :checkpoint_recovery,
        checkpoint_id: checkpoint.id,
        issue_type: issue.type
      }
    }
    
    %{state | messages: state.messages ++ [guidance]}
  end
end
```

### 4. Collaborative Recovery

Involves the user in the recovery process when automatic recovery isn't possible.

```elixir
defmodule Pipeline.Safety.Recovery.CollaborativeRecovery do
  @moduledoc """
  Recovery that involves user interaction
  """
  
  def initiate_collaborative_recovery(state, issue, context) do
    case assess_user_involvement_need(issue) do
      :required ->
        request_user_intervention(state, issue, context)
        
      :optional ->
        offer_user_assistance(state, issue, context)
        
      :not_needed ->
        {:continue_automatic, state}
    end
  end
  
  defp request_user_intervention(state, issue, context) do
    request = build_intervention_request(issue, context)
    
    # Pause execution and wait for user input
    paused_state = %{state |
      execution_status: :paused_for_user,
      pending_request: request
    }
    
    {:pause, paused_state, request}
  end
  
  defp build_intervention_request(issue, context) do
    %InterventionRequest{
      id: generate_request_id(),
      issue: issue,
      
      title: generate_title(issue),
      
      description: """
      Claude needs your help to proceed. 
      
      **Issue**: #{issue.description}
      **Context**: #{summarize_context(context)}
      
      **Options**:
      #{format_intervention_options(issue, context)}
      """,
      
      options: generate_intervention_options(issue, context),
      
      default_option: suggest_default_option(issue),
      
      additional_info: %{
        logs: get_relevant_logs(context),
        state_summary: summarize_state(context),
        attempted_solutions: list_attempted_solutions(context)
      }
    }
  end
  
  defp generate_intervention_options(issue, context) do
    base_options = [
      %Option{
        id: :provide_guidance,
        label: "Provide guidance",
        description: "Give Claude specific instructions on how to proceed",
        action: :inject_user_guidance
      },
      %Option{
        id: :modify_approach,
        label: "Modify approach",
        description: "Change the strategy or constraints",
        action: :update_strategy
      },
      %Option{
        id: :skip_step,
        label: "Skip this step",
        description: "Move on to the next task",
        action: :skip_current
      },
      %Option{
        id: :abort,
        label: "Stop execution",
        description: "Halt the pipeline execution",
        action: :abort_execution
      }
    ]
    
    # Add context-specific options
    specific_options = case issue.type do
      :permission_denied ->
        [%Option{
          id: :fix_permissions,
          label: "Fix permissions",
          description: "Manually adjust file permissions",
          action: :wait_for_permission_fix
        }]
        
      :missing_dependency ->
        [%Option{
          id: :install_dependency,
          label: "Install dependency",
          description: "Install the missing dependency",
          action: :wait_for_dependency
        }]
        
      _ -> []
    end
    
    base_options ++ specific_options
  end
  
  def handle_user_response(paused_state, user_response) do
    case user_response.selected_option do
      :provide_guidance ->
        inject_guidance_and_resume(paused_state, user_response.guidance)
        
      :modify_approach ->
        update_strategy_and_resume(paused_state, user_response.new_strategy)
        
      :skip_step ->
        skip_and_continue(paused_state)
        
      :abort ->
        graceful_abort(paused_state, user_response.reason)
        
      custom_action ->
        handle_custom_action(paused_state, custom_action, user_response)
    end
  end
end
```

### 5. Self-Healing Recovery

System attempts to automatically fix common issues.

```elixir
defmodule Pipeline.Safety.Recovery.SelfHealing do
  @moduledoc """
  Automatic self-healing for common issues
  """
  
  @healing_strategies %{
    syntax_error: &heal_syntax_error/2,
    import_error: &heal_import_error/2,
    type_error: &heal_type_error/2,
    missing_file: &heal_missing_file/2,
    circular_dependency: &heal_circular_dependency/2
  }
  
  def attempt_self_heal(state, error) do
    error_type = categorize_for_healing(error)
    
    case Map.get(@healing_strategies, error_type) do
      nil ->
        {:error, :no_healing_strategy}
        
      strategy ->
        apply_healing_strategy(strategy, state, error)
    end
  end
  
  defp heal_syntax_error(state, error) do
    with {:ok, location} <- extract_error_location(error),
         {:ok, file_content} <- read_file(location.file),
         {:ok, fixed_content} <- auto_fix_syntax(file_content, location),
         :ok <- write_file(location.file, fixed_content) do
      
      healing_message = %{
        role: "system",
        content: """
        I detected and fixed a syntax error:
        - File: #{location.file}
        - Line: #{location.line}
        - Fix: #{describe_fix(file_content, fixed_content, location)}
        
        Continuing with the corrected code.
        """,
        metadata: %{type: :self_healing, healed: :syntax_error}
      }
      
      {:healed, %{state | messages: state.messages ++ [healing_message]}}
    else
      _ -> {:error, :healing_failed}
    end
  end
  
  defp heal_import_error(state, error) do
    with {:ok, import_info} <- extract_import_info(error),
         {:ok, resolution} <- resolve_import(import_info) do
      
      case resolution do
        {:install, package} ->
          install_and_continue(state, package)
          
        {:fix_path, correct_path} ->
          fix_import_path(state, import_info, correct_path)
          
        {:add_missing, file_path} ->
          create_missing_module(state, file_path)
      end
    end
  end
  
  defp auto_fix_syntax(content, location) do
    # Common syntax fixes
    fixes = [
      # Missing closing bracket
      {~r/^(.+)[\[\{\(]([^\]\}\)]+)$/, "\\1\\2#{closing_bracket(\\1)}"},
      
      # Missing comma in list/object
      {~r/(\w+)\s*\n\s*(\w+:)/, "\\1,\n  \\2"},
      
      # Unclosed string
      {~r/^(.+)(["'])([^"']+)$/, "\\1\\2\\3\\2"},
      
      # Missing semicolon (JS/TS)
      {~r/^(.+\S)\s*\n/, "\\1;\n"}
    ]
    
    lines = String.split(content, "\n")
    fixed_line = Enum.at(lines, location.line - 1)
    
    fixed_line = Enum.reduce(fixes, fixed_line, fn {pattern, replacement}, line ->
      Regex.replace(pattern, line, replacement)
    end)
    
    fixed_lines = List.replace_at(lines, location.line - 1, fixed_line)
    {:ok, Enum.join(fixed_lines, "\n")}
  end
end
```

## Recovery Coordination

### 1. Recovery Manager

```elixir
defmodule Pipeline.Safety.Recovery.RecoveryManager do
  use GenServer
  
  @recovery_modules [
    AutomaticRecovery,
    GuidedRecovery,
    CheckpointRecovery,
    CollaborativeRecovery,
    SelfHealing
  ]
  
  def handle_failure(state, failure, context) do
    GenServer.call(__MODULE__, {:handle_failure, state, failure, context})
  end
  
  def handle_call({:handle_failure, state, failure, context}, _from, mgr_state) do
    recovery_plan = create_recovery_plan(failure, state, context, mgr_state)
    
    result = execute_recovery_plan(recovery_plan, state, mgr_state)
    
    updated_mgr_state = update_recovery_history(mgr_state, recovery_plan, result)
    
    {:reply, result, updated_mgr_state}
  end
  
  defp create_recovery_plan(failure, state, context, mgr_state) do
    %RecoveryPlan{
      id: generate_plan_id(),
      failure: failure,
      
      strategies: prioritize_strategies(failure, state, context),
      
      constraints: %{
        max_attempts: get_max_attempts(failure),
        timeout: get_recovery_timeout(failure),
        resource_limits: calculate_recovery_limits(state)
      },
      
      success_metrics: define_success_metrics(failure),
      
      escalation_path: define_escalation_path(failure, mgr_state)
    }
  end
  
  defp prioritize_strategies(failure, state, context) do
    all_strategies = @recovery_modules
    |> Enum.map(&{&1, &1.assess_applicability(failure, state, context)})
    |> Enum.filter(fn {_, score} -> score > 0 end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.map(fn {module, _} -> module end)
    
    # Add learned preferences
    apply_learned_preferences(all_strategies, failure.type, context)
  end
  
  defp execute_recovery_plan(plan, state, mgr_state) do
    Enum.reduce_while(plan.strategies, {:error, :no_recovery}, fn strategy, _acc ->
      case apply_recovery_strategy(strategy, state, plan) do
        {:recovered, new_state} ->
          {:halt, {:ok, new_state}}
          
        {:partial, partial_state} ->
          # Try next strategy with partially recovered state
          {:cont, {:partial, partial_state}}
          
        {:error, _reason} ->
          {:cont, {:error, :no_recovery}}
      end
    end)
  end
end
```

### 2. Recovery Policies

```elixir
defmodule Pipeline.Safety.Recovery.Policies do
  @moduledoc """
  Defines recovery policies for different scenarios
  """
  
  defmodule Policy do
    defstruct [
      :name,
      :description,
      :applicable_to,
      :strategies,
      :max_attempts,
      :escalation_threshold,
      :user_approval_required
    ]
  end
  
  @policies [
    %Policy{
      name: :development,
      description: "Aggressive recovery for development environments",
      applicable_to: [:all],
      strategies: [:self_healing, :automatic, :guided],
      max_attempts: 5,
      escalation_threshold: 0.8,
      user_approval_required: false
    },
    %Policy{
      name: :production,
      description: "Conservative recovery for production",
      applicable_to: [:specific_errors],
      strategies: [:checkpoint, :collaborative],
      max_attempts: 2,
      escalation_threshold: 0.5,
      user_approval_required: true
    },
    %Policy{
      name: :testing,
      description: "Balanced recovery for testing",
      applicable_to: [:non_critical],
      strategies: [:automatic, :checkpoint, :guided],
      max_attempts: 3,
      escalation_threshold: 0.7,
      user_approval_required: false
    }
  ]
  
  def select_policy(environment, context) do
    policy = Enum.find(@policies, &(&1.name == environment))
    
    # Adjust policy based on context
    adjust_policy_for_context(policy, context)
  end
end
```

## Recovery Configuration

### 1. Recovery Settings

```yaml
recovery:
  # Global recovery settings
  enabled: true
  default_policy: development
  max_recovery_time_seconds: 300
  
  # Strategy-specific settings
  automatic:
    enabled: true
    timeout_seconds: 60
    retry_attempts: 3
    backoff_multiplier: 2
    
  guided:
    enabled: true
    max_guidance_steps: 10
    step_timeout_seconds: 30
    
  checkpoint:
    enabled: true
    checkpoint_interval_seconds: 60
    max_checkpoints: 20
    checkpoint_compression: true
    
  collaborative:
    enabled: true
    user_timeout_seconds: 300
    default_action: continue
    notification_channels:
      - console
      - email
      
  self_healing:
    enabled: true
    auto_fix_syntax: true
    auto_fix_imports: true
    auto_create_files: false
    
  # Recovery patterns
  patterns:
    file_not_found:
      strategies: [automatic, guided]
      max_attempts: 3
      
    syntax_error:
      strategies: [self_healing, guided]
      max_attempts: 2
      
    permission_denied:
      strategies: [collaborative]
      max_attempts: 1
      
    resource_exhaustion:
      strategies: [checkpoint, automatic]
      max_attempts: 2
```

### 2. Custom Recovery Handlers

```elixir
defmodule MyCustomRecovery do
  @behaviour Pipeline.Safety.Recovery
  
  @impl true
  def assess_applicability(failure, _state, _context) do
    case failure.type do
      :my_custom_error -> 1.0
      _ -> 0.0
    end
  end
  
  @impl true
  def attempt_recovery(state, failure, context) do
    # Custom recovery logic
  end
end

# Register custom recovery
Pipeline.Safety.Recovery.register_strategy(MyCustomRecovery)
```

## Testing Recovery

### 1. Recovery Test Framework

```elixir
defmodule Pipeline.Safety.RecoveryTest do
  use ExUnit.Case
  
  describe "automatic recovery" do
    test "recovers from file not found error" do
      state = create_test_state()
      error = %{type: :file_not_found, file: "/test/missing.ex"}
      
      {:recovered, new_state} = 
        AutomaticRecovery.attempt_recovery(state, error, %{})
      
      assert new_state.recovered_from == :file_not_found
      assert new_state.messages |> List.last() |> Map.get(:content) =~ "alternative"
    end
  end
  
  describe "checkpoint recovery" do
    test "restores from checkpoint after failure" do
      state = create_state_with_checkpoints()
      issue = %{type: :resource_spiral, started_at: time_after_checkpoint()}
      
      {:ok, recovered_state} = 
        CheckpointRecovery.recover_from_checkpoint(state, issue)
      
      assert recovered_state.checkpoint_restored == true
      assert recovered_state.recovery_metadata.recovered_from == :resource_spiral
    end
  end
  
  describe "recovery coordination" do
    test "tries multiple strategies in order" do
      state = create_complex_failure_state()
      failure = %{type: :complex_error, recoverable: true}
      
      {:ok, final_state} = 
        RecoveryManager.handle_failure(state, failure, %{})
      
      assert final_state.recovery_attempts == 2
      assert final_state.successful_strategy == :guided_recovery
    end
  end
end
```

## Monitoring and Analytics

### 1. Recovery Metrics

```elixir
defmodule Pipeline.Safety.Recovery.Metrics do
  def record_recovery_attempt(strategy, failure_type, outcome) do
    labels = %{
      strategy: to_string(strategy),
      failure_type: to_string(failure_type),
      outcome: to_string(outcome)
    }
    
    :telemetry.execute(
      [:pipeline, :safety, :recovery, :attempt],
      %{count: 1},
      labels
    )
    
    if outcome == :success do
      :telemetry.execute(
        [:pipeline, :safety, :recovery, :success_rate],
        %{value: 1},
        labels
      )
    end
  end
  
  def recovery_dashboard() do
    %{
      graphs: [
        %{
          title: "Recovery Success Rate by Strategy",
          query: "avg by (strategy) (rate(pipeline_safety_recovery_success_rate[5m]))"
        },
        %{
          title: "Recovery Attempts by Failure Type",
          query: "sum by (failure_type) (increase(pipeline_safety_recovery_attempt_total[1h]))"
        },
        %{
          title: "Average Recovery Time",
          query: "histogram_quantile(0.95, pipeline_safety_recovery_duration_seconds)"
        }
      ],
      alerts: [
        %{
          name: "low_recovery_success_rate",
          expr: "avg(rate(pipeline_safety_recovery_success_rate[5m])) < 0.5",
          message: "Recovery success rate below 50%"
        }
      ]
    }
  end
end
```