# Step Reviewer - Detailed Design

## Overview

The Step Reviewer is the core component responsible for reviewing every Claude action in real-time. It acts as a gatekeeper, analyzing actions before and after execution to ensure safety and alignment with objectives.

## Architecture

### Component Structure

```elixir
defmodule Pipeline.Safety.StepReviewer do
  use GenServer
  require Logger
  
  defstruct [
    :id,
    :context,
    :rules_engine,
    :risk_calculator,
    :rationality_checker,
    :side_effect_analyzer,
    :decision_engine,
    :audit_logger,
    :metrics_collector,
    :action_history,
    :review_cache
  ]
  
  @type t :: %__MODULE__{
    id: String.t(),
    context: ReviewContext.t(),
    rules_engine: RulesEngine.t(),
    risk_calculator: RiskCalculator.t(),
    rationality_checker: RationalityChecker.t(),
    side_effect_analyzer: SideEffectAnalyzer.t(),
    decision_engine: DecisionEngine.t(),
    audit_logger: AuditLogger.t(),
    metrics_collector: MetricsCollector.t(),
    action_history: ActionHistory.t(),
    review_cache: ReviewCache.t()
  }
end
```

## Core Functionality

### 1. Action Review Process

```elixir
def review_action(reviewer, action, timing) do
  review_id = generate_review_id()
  
  with {:ok, parsed_action} <- parse_action(action),
       {:ok, risk_analysis} <- analyze_risk(reviewer, parsed_action),
       {:ok, rationality_analysis} <- check_rationality(reviewer, parsed_action),
       {:ok, side_effects} <- analyze_side_effects(reviewer, parsed_action),
       {:ok, decision} <- make_decision(reviewer, %{
         action: parsed_action,
         risk: risk_analysis,
         rationality: rationality_analysis,
         side_effects: side_effects,
         timing: timing
       }) do
    
    # Log the review
    log_review(reviewer, review_id, decision)
    
    # Update metrics
    update_metrics(reviewer, decision)
    
    # Cache for future reference
    cache_review(reviewer, review_id, decision)
    
    {:ok, decision}
  else
    {:error, reason} -> handle_review_error(reviewer, action, reason)
  end
end
```

### 2. Action Parsing

```elixir
defmodule Pipeline.Safety.StepReviewer.ActionParser do
  @doc """
  Parses Claude actions from various formats
  """
  def parse_action(raw_action) do
    case identify_action_type(raw_action) do
      :tool_use -> parse_tool_use(raw_action)
      :message -> parse_message(raw_action)
      :file_operation -> parse_file_operation(raw_action)
      :system_command -> parse_system_command(raw_action)
      :unknown -> {:error, :unknown_action_type}
    end
  end
  
  defp parse_tool_use(action) do
    %ParsedAction{
      type: :tool_use,
      tool: action["tool"],
      parameters: action["parameters"],
      intent: extract_intent(action),
      scope: extract_scope(action)
    }
  end
  
  defp extract_intent(action) do
    # Use NLP or pattern matching to determine intent
    cond do
      action["tool"] == "Write" -> :file_creation
      action["tool"] == "Edit" -> :file_modification
      action["tool"] == "Delete" -> :file_deletion
      action["tool"] == "Bash" -> :system_command
      true -> :unknown
    end
  end
end
```

### 3. Risk Analysis

```elixir
defmodule Pipeline.Safety.StepReviewer.RiskCalculator do
  @risk_factors %{
    file_deletion: 0.8,
    system_command: 0.7,
    network_request: 0.6,
    file_modification: 0.4,
    file_creation: 0.3,
    file_read: 0.1
  }
  
  def calculate_risk(action, context) do
    base_risk = get_base_risk(action)
    
    modifiers = [
      scope_modifier(action, context),
      repetition_modifier(action, context),
      privilege_modifier(action, context),
      pattern_modifier(action, context)
    ]
    
    final_risk = apply_modifiers(base_risk, modifiers)
    
    %RiskAnalysis{
      score: final_risk,
      factors: identify_risk_factors(action),
      severity: categorize_severity(final_risk),
      details: build_risk_details(action, modifiers)
    }
  end
  
  defp scope_modifier(action, context) do
    # Higher risk if action is outside expected scope
    expected_paths = context.expected_scope.paths
    action_path = extract_path(action)
    
    if path_in_scope?(action_path, expected_paths) do
      0.0
    else
      0.3 # Significant risk increase for out-of-scope actions
    end
  end
  
  defp repetition_modifier(action, context) do
    # Higher risk for repeated failed actions
    similar_actions = find_similar_actions(action, context.history)
    failed_count = count_failures(similar_actions)
    
    case failed_count do
      0 -> 0.0
      1 -> 0.1
      2 -> 0.2
      _ -> 0.4 # High risk for repeated failures
    end
  end
end
```

### 4. Rationality Checking

```elixir
defmodule Pipeline.Safety.StepReviewer.RationalityChecker do
  @doc """
  Checks if an action is rational given the context and goals
  """
  def check_rationality(action, context) do
    scores = %{
      goal_alignment: check_goal_alignment(action, context),
      logical_progression: check_logical_progression(action, context),
      efficiency: check_efficiency(action, context),
      completeness: check_completeness(action, context)
    }
    
    overall_score = calculate_overall_rationality(scores)
    
    %RationalityAnalysis{
      score: overall_score,
      components: scores,
      issues: identify_rationality_issues(scores),
      suggestions: generate_suggestions(scores, action, context)
    }
  end
  
  defp check_goal_alignment(action, context) do
    # Compare action intent with stated goals
    goals = context.goals
    action_contributes = Enum.any?(goals, fn goal ->
      contributes_to_goal?(action, goal)
    end)
    
    if action_contributes, do: 1.0, else: 0.0
  end
  
  defp check_logical_progression(action, context) do
    # Check if action follows logically from previous actions
    history = context.history
    
    cond do
      builds_on_previous?(action, history) -> 1.0
      explores_new_path?(action, history) -> 0.7
      repeats_previous?(action, history) -> 0.3
      contradicts_previous?(action, history) -> 0.0
    end
  end
  
  defp check_efficiency(action, context) do
    # Check if action is efficient way to achieve goal
    alternatives = identify_alternatives(action, context)
    
    if more_efficient_alternative?(alternatives, action) do
      0.5
    else
      1.0
    end
  end
end
```

### 5. Side Effect Analysis

```elixir
defmodule Pipeline.Safety.StepReviewer.SideEffectAnalyzer do
  def analyze_side_effects(action) do
    effects = []
    
    # File system effects
    effects = effects ++ analyze_file_effects(action)
    
    # Process/system effects
    effects = effects ++ analyze_system_effects(action)
    
    # Network effects
    effects = effects ++ analyze_network_effects(action)
    
    # Resource effects
    effects = effects ++ analyze_resource_effects(action)
    
    %SideEffectAnalysis{
      effects: effects,
      reversible: all_reversible?(effects),
      severity: max_severity(effects),
      mitigation: suggest_mitigations(effects)
    }
  end
  
  defp analyze_file_effects(action) do
    case action.type do
      :file_write ->
        [%Effect{
          type: :file_modification,
          target: action.parameters.path,
          reversible: file_backed_up?(action.parameters.path),
          severity: :medium
        }]
        
      :file_delete ->
        [%Effect{
          type: :file_deletion,
          target: action.parameters.path,
          reversible: file_backed_up?(action.parameters.path),
          severity: :high
        }]
        
      _ -> []
    end
  end
  
  defp analyze_system_effects(action) do
    case action.type do
      :system_command ->
        command = action.parameters.command
        
        effects = []
        
        if modifies_system_state?(command) do
          effects = effects ++ [%Effect{
            type: :system_modification,
            command: command,
            reversible: false,
            severity: :high
          }]
        end
        
        if creates_processes?(command) do
          effects = effects ++ [%Effect{
            type: :process_creation,
            command: command,
            reversible: true,
            severity: :medium
          }]
        end
        
        effects
        
      _ -> []
    end
  end
end
```

### 6. Decision Engine

```elixir
defmodule Pipeline.Safety.StepReviewer.DecisionEngine do
  @decision_matrix %{
    # {risk_level, rationality_level} => decision
    {:low, :high} => :allow,
    {:low, :medium} => :allow,
    {:low, :low} => :warn,
    {:medium, :high} => :allow,
    {:medium, :medium} => :warn,
    {:medium, :low} => :modify,
    {:high, :high} => :warn,
    {:high, :medium} => :modify,
    {:high, :low} => :block,
    {:critical, _} => :block
  }
  
  def make_decision(analysis) do
    risk_level = categorize_risk(analysis.risk.score)
    rationality_level = categorize_rationality(analysis.rationality.score)
    
    base_decision = @decision_matrix[{risk_level, rationality_level}]
    
    # Apply additional rules
    final_decision = apply_decision_rules(base_decision, analysis)
    
    %Decision{
      action: final_decision,
      reasoning: build_reasoning(analysis, final_decision),
      confidence: calculate_confidence(analysis),
      alternatives: suggest_alternatives(analysis),
      metadata: build_metadata(analysis)
    }
  end
  
  defp apply_decision_rules(base_decision, analysis) do
    cond do
      # Always block critical side effects
      analysis.side_effects.severity == :critical -> :block
      
      # Allow with warning for first-time actions
      first_time_action?(analysis) && base_decision == :warn -> :allow
      
      # Escalate if pattern detected
      dangerous_pattern?(analysis) && base_decision == :warn -> :modify
      
      # Default to base decision
      true -> base_decision
    end
  end
  
  defp build_reasoning(analysis, decision) do
    reasons = []
    
    if analysis.risk.score > 0.7 do
      reasons = reasons ++ ["High risk action: #{format_risk_factors(analysis.risk)}"]
    end
    
    if analysis.rationality.score < 0.5 do
      reasons = reasons ++ ["Low rationality: #{format_rationality_issues(analysis.rationality)}"]
    end
    
    if length(analysis.side_effects.effects) > 0 do
      reasons = reasons ++ ["Side effects: #{format_side_effects(analysis.side_effects)}"]
    end
    
    %{
      decision: decision,
      primary_reason: List.first(reasons),
      all_reasons: reasons,
      explanation: generate_explanation(decision, reasons)
    }
  end
end
```

## Review Rules

### 1. Rule Definition

```elixir
defmodule Pipeline.Safety.StepReviewer.Rules do
  defmacro defrule(name, condition, action) do
    quote do
      def unquote(name)(context) do
        if unquote(condition).(context) do
          unquote(action).(context)
        else
          :no_match
        end
      end
    end
  end
  
  # Example rules
  defrule :prevent_recursive_deletion,
    fn ctx -> 
      ctx.action.type == :file_delete && 
      ctx.action.parameters.recursive == true 
    end,
    fn _ctx -> 
      {:block, "Recursive deletion is not allowed"}
    end
  
  defrule :limit_file_operations,
    fn ctx -> 
      count_file_operations(ctx.history) > ctx.config.max_file_operations 
    end,
    fn _ctx -> 
      {:block, "File operation limit exceeded"}
    end
  
  defrule :warn_external_network,
    fn ctx -> 
      ctx.action.type == :network_request &&
      external_url?(ctx.action.parameters.url)
    end,
    fn ctx -> 
      {:warn, "External network request to #{ctx.action.parameters.url}"}
    end
end
```

### 2. Rule Engine

```elixir
defmodule Pipeline.Safety.StepReviewer.RulesEngine do
  def evaluate_rules(action, context, rules) do
    results = Enum.map(rules, fn rule ->
      try do
        rule.evaluate(action, context)
      rescue
        e -> {:error, "Rule #{rule.name} failed: #{inspect(e)}"}
      end
    end)
    
    # Aggregate results
    aggregate_rule_results(results)
  end
  
  defp aggregate_rule_results(results) do
    # Priority: block > modify > warn > allow
    cond do
      Enum.any?(results, &match?({:block, _}, &1)) ->
        Enum.find(results, &match?({:block, _}, &1))
        
      Enum.any?(results, &match?({:modify, _}, &1)) ->
        Enum.find(results, &match?({:modify, _}, &1))
        
      Enum.any?(results, &match?({:warn, _}, &1)) ->
        Enum.find(results, &match?({:warn, _}, &1))
        
      true ->
        {:allow, "All rules passed"}
    end
  end
end
```

## Caching Strategy

### 1. Review Cache

```elixir
defmodule Pipeline.Safety.StepReviewer.ReviewCache do
  use GenServer
  
  @cache_ttl :timer.minutes(5)
  @max_cache_size 1000
  
  def cache_review(review_id, decision) do
    GenServer.call(__MODULE__, {:cache, review_id, decision})
  end
  
  def get_cached_review(action_hash) do
    GenServer.call(__MODULE__, {:get, action_hash})
  end
  
  def handle_call({:cache, review_id, decision}, _from, state) do
    action_hash = hash_action(decision.action)
    
    new_state = 
      state
      |> add_to_cache(action_hash, decision)
      |> prune_cache()
    
    {:reply, :ok, new_state}
  end
  
  defp add_to_cache(state, hash, decision) do
    entry = %{
      decision: decision,
      cached_at: System.monotonic_time(),
      hits: 0
    }
    
    Map.put(state.cache, hash, entry)
  end
  
  defp prune_cache(state) do
    if map_size(state.cache) > @max_cache_size do
      # Remove least recently used entries
      pruned = 
        state.cache
        |> Enum.sort_by(fn {_, v} -> v.hits end)
        |> Enum.take(@max_cache_size - 100)
        |> Map.new()
      
      %{state | cache: pruned}
    else
      state
    end
  end
end
```

## Metrics Collection

### 1. Review Metrics

```elixir
defmodule Pipeline.Safety.StepReviewer.Metrics do
  @metrics [
    :total_reviews,
    :allowed_actions,
    :warned_actions,
    :modified_actions,
    :blocked_actions,
    :avg_review_time,
    :cache_hit_rate,
    :false_positive_rate
  ]
  
  def record_review(decision, duration) do
    # Increment counters
    increment_counter(:total_reviews)
    increment_counter(decision_to_metric(decision.action))
    
    # Record timing
    record_histogram(:review_duration, duration)
    
    # Calculate rates
    update_rate(:cache_hit_rate, decision.cache_hit)
  end
  
  def get_metrics() do
    @metrics
    |> Enum.map(fn metric ->
      {metric, get_metric_value(metric)}
    end)
    |> Map.new()
  end
end
```

## Configuration

### 1. Reviewer Configuration

```yaml
step_reviewer:
  # General settings
  enabled: true
  mode: blocking  # blocking | async
  
  # Risk thresholds
  risk:
    low_threshold: 0.3
    medium_threshold: 0.6
    high_threshold: 0.8
    critical_threshold: 0.95
  
  # Rationality thresholds  
  rationality:
    high_threshold: 0.8
    medium_threshold: 0.5
    low_threshold: 0.3
  
  # Rule sets
  rules:
    builtin: all  # all | essential | none
    custom_rules_path: ./config/custom_rules.exs
  
  # Caching
  cache:
    enabled: true
    ttl_minutes: 5
    max_size: 1000
  
  # Performance
  performance:
    max_review_time_ms: 100
    async_threshold: 0.3  # Use async for risk < threshold
```

### 2. Per-Pipeline Overrides

```yaml
# In pipeline definition
safety:
  step_reviewer:
    risk:
      high_threshold: 0.7  # More permissive for this pipeline
    rules:
      disabled:
        - prevent_recursive_deletion
        - limit_file_operations
```

## Testing

### 1. Unit Tests

```elixir
defmodule Pipeline.Safety.StepReviewerTest do
  use ExUnit.Case
  
  describe "risk calculation" do
    test "calculates high risk for file deletion" do
      action = %Action{
        type: :file_delete,
        parameters: %{path: "/important/file.txt"}
      }
      
      risk = RiskCalculator.calculate_risk(action, %Context{})
      
      assert risk.score > 0.7
      assert risk.severity == :high
    end
    
    test "applies scope modifier correctly" do
      action = %Action{
        type: :file_write,
        parameters: %{path: "/outside/scope/file.txt"}
      }
      
      context = %Context{
        expected_scope: %{paths: ["/project/**"]}
      }
      
      risk = RiskCalculator.calculate_risk(action, context)
      
      assert risk.score > 0.5
      assert :out_of_scope in risk.factors
    end
  end
  
  describe "decision making" do
    test "blocks high risk low rationality actions" do
      analysis = %{
        risk: %{score: 0.9},
        rationality: %{score: 0.2},
        side_effects: %{severity: :high}
      }
      
      decision = DecisionEngine.make_decision(analysis)
      
      assert decision.action == :block
      assert decision.reasoning.primary_reason =~ "High risk"
    end
  end
end
```

### 2. Integration Tests

```elixir
defmodule Pipeline.Safety.StepReviewerIntegrationTest do
  use Pipeline.IntegrationCase
  
  test "reviewer prevents destructive actions" do
    pipeline = """
    name: test_destructive
    steps:
      - type: claude_code
        config:
          prompt: "Delete all files in /tmp"
    """
    
    result = Pipeline.execute(pipeline, safety: true)
    
    assert {:error, :blocked_by_reviewer} = result
    assert length(result.blocked_actions) > 0
  end
  
  test "reviewer allows safe actions" do
    pipeline = """
    name: test_safe
    steps:
      - type: claude_code
        config:
          prompt: "Read the README file"
    """
    
    result = Pipeline.execute(pipeline, safety: true)
    
    assert {:ok, _} = result
    assert result.review_summary.blocked_count == 0
  end
end
```