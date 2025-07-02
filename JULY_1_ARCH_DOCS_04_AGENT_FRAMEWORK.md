# JULY_1_ARCH_DOCS_04: Agent Framework Design

## Overview

The Agent Framework is the orchestration layer that transforms pipeline_ex from a command-line tool into an interactive AI assistant. It provides natural language interfaces, job management, and intelligent routing while maintaining the robust execution capabilities of the underlying pipeline system.

## Core Concepts

### 1. Agent as Service Architecture

Instead of manual pipeline execution:
```bash
# Old way - manual commands
mix pipeline.generate "analyze code quality"
mix pipeline.run generated_pipeline.yaml
```

We want autonomous agent interaction:
```elixir
# New way - conversational agents
AIAgent.chat("Please analyze the code quality in our main module")
# -> Automatically routes to appropriate pipeline
# -> Executes analysis
# -> Returns formatted results
# -> Learns from interaction
```

### 2. Multi-Agent Specialization

Different agents for different domains:

```elixir
# Specialized agents with domain expertise
CodeAnalysisAgent.analyze("lib/my_module.ex")
RefactoringAgent.suggest_improvements(analysis_result)
TestGenerationAgent.create_tests(refactored_code)
DeploymentAgent.plan_rollout(test_results)
```

### 3. Agent Memory and Learning

Agents maintain context across interactions:
```elixir
# Agents remember previous conversations
Agent.continue_conversation(session_id, "Now refactor based on that analysis")

# Agents learn from successful patterns  
Agent.record_success(interaction_id, outcome_quality: 9.2)
```

## Agent Framework Architecture

### Layer Structure

```
┌─────────────────────────────────────────────────────────────┐
│                  Agent Interface Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Web API   │  │    Chat     │  │     CLI     │        │
│  │             │  │ Interface   │  │  Commands   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                Agent Orchestration Layer                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Agent Router                           │    │
│  │  • Request classification                           │    │
│  │  • Agent selection                                  │    │
│  │  • Context management                               │    │
│  │  • Response formatting                              │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Specialized Agents                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Analysis  │  │ Refactoring │  │    Test     │        │
│  │    Agent    │  │    Agent    │  │ Generation  │        │
│  │             │  │             │  │   Agent     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Pipeline Execution Layer                    │
│                    (Existing System)                        │
└─────────────────────────────────────────────────────────────┘
```

## Core Agent Implementation

### 1. Base Agent Behavior

```elixir
defmodule Pipeline.Agent.Base do
  @callback handle_request(request :: String.t(), context :: map()) :: 
    {:ok, response :: map()} | {:error, reason :: String.t()}
    
  @callback get_capabilities() :: [atom()]
  
  @callback supports_request?(request :: String.t()) :: boolean()
  
  defmacro __using__(opts) do
    quote do
      @behaviour Pipeline.Agent.Base
      use GenServer
      require Logger
      
      # Default implementations
      def supports_request?(request) do
        capabilities = get_capabilities()
        request_type = classify_request(request)
        request_type in capabilities
      end
      
      defp classify_request(request) do
        request_lower = String.downcase(request)
        cond do
          String.contains?(request_lower, "analyze") -> :analysis
          String.contains?(request_lower, "refactor") -> :refactoring  
          String.contains?(request_lower, "test") -> :testing
          String.contains?(request_lower, "deploy") -> :deployment
          true -> :general
        end
      end
    end
  end
end
```

### 2. Master Agent Router

```elixir
defmodule Pipeline.Agent.Router do
  use GenServer
  
  # Agent registry and routing
  defstruct [
    :agents,           # %{agent_name => agent_pid}
    :active_sessions,  # %{session_id => %{agent: agent_name, context: map()}}
    :routing_rules,    # Learned routing preferences
    :performance_metrics # Agent success rates
  ]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  ## Public API
  
  def handle_request(request, opts \\ []) do
    session_id = Keyword.get(opts, :session_id, generate_session_id())
    context = Keyword.get(opts, :context, %{})
    
    GenServer.call(__MODULE__, {:handle_request, request, session_id, context})
  end
  
  def continue_session(session_id, request) do
    GenServer.call(__MODULE__, {:continue_session, session_id, request})
  end
  
  def get_session_status(session_id) do
    GenServer.call(__MODULE__, {:get_session_status, session_id})
  end
  
  ## Implementation
  
  def handle_call({:handle_request, request, session_id, context}, _from, state) do
    # 1. Analyze request to determine best agent
    agent_name = select_best_agent(request, state)
    
    # 2. Get or create session context
    session_context = get_session_context(session_id, state)
    full_context = Map.merge(session_context, context)
    
    # 3. Route to selected agent
    case route_to_agent(agent_name, request, full_context) do
      {:ok, response} ->
        # Update session and metrics
        new_state = update_session(state, session_id, agent_name, response)
        record_success(agent_name, request, response)
        
        {:reply, {:ok, response}, new_state}
        
      {:error, reason} ->
        # Try fallback agent
        fallback_response = handle_agent_failure(request, reason, full_context)
        {:reply, fallback_response, state}
    end
  end
  
  defp select_best_agent(request, state) do
    # Score each agent based on capabilities and performance
    agent_scores = Enum.map(state.agents, fn {agent_name, agent_pid} ->
      capability_score = if agent_supports_request?(agent_pid, request), do: 1.0, else: 0.0
      performance_score = get_agent_performance(agent_name, state)
      
      {agent_name, capability_score * 0.7 + performance_score * 0.3}
    end)
    
    # Select highest scoring agent
    {best_agent, _score} = Enum.max_by(agent_scores, fn {_agent, score} -> score end)
    best_agent
  end
  
  defp route_to_agent(agent_name, request, context) do
    case Map.get(state.agents, agent_name) do
      nil -> {:error, "Agent not available: #{agent_name}"}
      agent_pid -> 
        try do
          GenServer.call(agent_pid, {:handle_request, request, context}, 30_000)
        catch
          :exit, {:timeout, _} -> {:error, "Agent timeout"}
          :exit, reason -> {:error, "Agent crashed: #{inspect(reason)}"}
        end
    end
  end
end
```

### 3. Specialized Analysis Agent

```elixir
defmodule Pipeline.Agent.CodeAnalysis do
  use Pipeline.Agent.Base
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_capabilities() do
    [:analysis, :code_review, :quality_assessment, :anti_pattern_detection]
  end
  
  def handle_request(request, context) do
    # Analyze the request to determine specific analysis type
    analysis_type = determine_analysis_type(request)
    
    # Select appropriate pipeline
    pipeline_path = select_analysis_pipeline(analysis_type)
    
    # Prepare pipeline input
    pipeline_input = prepare_analysis_input(request, context, analysis_type)
    
    # Execute pipeline
    case execute_pipeline(pipeline_path, pipeline_input) do
      {:ok, result} ->
        formatted_response = format_analysis_response(result, analysis_type)
        {:ok, formatted_response}
        
      {:error, reason} ->
        {:error, "Analysis failed: #{reason}"}
    end
  end
  
  defp determine_analysis_type(request) do
    request_lower = String.downcase(request)
    
    cond do
      String.contains?(request_lower, "otp") or String.contains?(request_lower, "supervision") ->
        :otp_analysis
        
      String.contains?(request_lower, "performance") or String.contains?(request_lower, "bottleneck") ->
        :performance_analysis
        
      String.contains?(request_lower, "security") or String.contains?(request_lower, "vulnerability") ->
        :security_analysis
        
      String.contains?(request_lower, "quality") or String.contains?(request_lower, "code review") ->
        :quality_analysis
        
      true ->
        :general_analysis
    end
  end
  
  defp select_analysis_pipeline(analysis_type) do
    case analysis_type do
      :otp_analysis -> "pipelines/analysis/otp_analysis.yaml"
      :performance_analysis -> "pipelines/analysis/performance_analysis.yaml"
      :security_analysis -> "pipelines/analysis/security_analysis.yaml"
      :quality_analysis -> "pipelines/analysis/quality_analysis.yaml"
      :general_analysis -> "pipelines/analysis/general_analysis.yaml"
    end
  end
  
  defp format_analysis_response(result, analysis_type) do
    %{
      type: "analysis_response",
      analysis_type: analysis_type,
      summary: extract_summary(result),
      findings: extract_findings(result),
      recommendations: extract_recommendations(result),
      confidence: calculate_confidence(result),
      next_actions: suggest_next_actions(result, analysis_type),
      raw_result: result
    }
  end
end
```

### 4. Specialized Refactoring Agent

```elixir
defmodule Pipeline.Agent.Refactoring do
  use Pipeline.Agent.Base
  
  def get_capabilities() do
    [:refactoring, :code_generation, :architecture_improvement, :pattern_application]
  end
  
  def handle_request(request, context) do
    # Check if we have analysis results in context
    case Map.get(context, :analysis_results) do
      nil ->
        # Need to analyze first
        suggest_analysis_first(request)
        
      analysis_results ->
        # Proceed with refactoring based on analysis
        perform_refactoring(request, analysis_results, context)
    end
  end
  
  defp perform_refactoring(request, analysis_results, context) do
    # Determine refactoring strategy
    strategy = determine_refactoring_strategy(request, analysis_results)
    
    # Select appropriate pipeline
    pipeline_path = select_refactoring_pipeline(strategy)
    
    # Prepare pipeline input
    pipeline_input = %{
      "refactoring_request" => request,
      "analysis_results" => analysis_results,
      "strategy" => strategy,
      "context" => context
    }
    
    # Execute refactoring pipeline
    case execute_pipeline(pipeline_path, pipeline_input) do
      {:ok, result} ->
        formatted_response = format_refactoring_response(result, strategy)
        {:ok, formatted_response}
        
      {:error, reason} ->
        {:error, "Refactoring failed: #{reason}"}
    end
  end
  
  defp suggest_analysis_first(request) do
    {:ok, %{
      type: "suggestion",
      message: "I need to analyze the code first before suggesting refactoring changes.",
      suggested_action: "analysis",
      suggested_request: "Please analyze the codebase for issues that need refactoring"
    }}
  end
end
```

## Session Management

### 1. Conversation Context

```elixir
defmodule Pipeline.Agent.Session do
  use GenServer
  
  defstruct [
    :session_id,
    :user_id,
    :start_time,
    :last_activity,
    :conversation_history,
    :accumulated_context,
    :active_agent,
    :pipeline_results
  ]
  
  def start_session(user_id) do
    session_id = generate_session_id()
    
    {:ok, session_pid} = GenServer.start_link(__MODULE__, %{
      session_id: session_id,
      user_id: user_id,
      start_time: DateTime.utc_now(),
      conversation_history: [],
      accumulated_context: %{},
      pipeline_results: %{}
    })
    
    # Register session
    :gproc.reg({:n, :l, {:session, session_id}}, session_pid)
    
    {:ok, session_id}
  end
  
  def add_interaction(session_id, request, response) do
    case find_session(session_id) do
      {:ok, session_pid} ->
        GenServer.cast(session_pid, {:add_interaction, request, response})
        
      {:error, _} ->
        {:error, "Session not found"}
    end
  end
  
  def get_context(session_id) do
    case find_session(session_id) do
      {:ok, session_pid} ->
        GenServer.call(session_pid, :get_context)
        
      {:error, _} ->
        %{}
    end
  end
  
  defp find_session(session_id) do
    case :gproc.whereis_name({:n, :l, {:session, session_id}}) do
      :undefined -> {:error, "Session not found"}
      pid -> {:ok, pid}
    end
  end
  
  def handle_cast({:add_interaction, request, response}, state) do
    interaction = %{
      timestamp: DateTime.utc_now(),
      request: request,
      response: response,
      agent: state.active_agent
    }
    
    new_state = %{state | 
      conversation_history: [interaction | state.conversation_history],
      last_activity: DateTime.utc_now(),
      accumulated_context: accumulate_context(state.accumulated_context, response)
    }
    
    {:noreply, new_state}
  end
  
  defp accumulate_context(current_context, response) do
    # Extract relevant context from response
    case response do
      %{type: "analysis_response", findings: findings} ->
        Map.put(current_context, :analysis_results, findings)
        
      %{type: "refactoring_response", changes: changes} ->
        Map.put(current_context, :refactoring_changes, changes)
        
      _ ->
        current_context
    end
  end
end
```

### 2. Multi-Agent Workflows

```elixir
defmodule Pipeline.Agent.Workflow do
  # Coordinate multiple agents for complex tasks
  
  def execute_analysis_and_refactor_workflow(request, context) do
    # Step 1: Analysis
    {:ok, analysis_response} = Pipeline.Agent.Router.handle_request(
      "Analyze code quality and identify refactoring opportunities",
      context: context
    )
    
    # Step 2: Generate refactoring plan
    refactor_context = Map.put(context, :analysis_results, analysis_response)
    {:ok, refactor_response} = Pipeline.Agent.Router.handle_request(
      "Create a refactoring plan based on the analysis",
      context: refactor_context
    )
    
    # Step 3: Generate tests for proposed changes
    test_context = Map.merge(refactor_context, %{refactoring_plan: refactor_response})
    {:ok, test_response} = Pipeline.Agent.Router.handle_request(
      "Generate tests for the proposed refactoring changes",
      context: test_context
    )
    
    # Return comprehensive workflow result
    %{
      type: "workflow_response",
      workflow: "analysis_and_refactor",
      steps: [
        %{step: "analysis", result: analysis_response},
        %{step: "refactoring", result: refactor_response},
        %{step: "testing", result: test_response}
      ],
      summary: generate_workflow_summary([analysis_response, refactor_response, test_response])
    }
  end
end
```

## Interface Implementations

### 1. Web API

```elixir
defmodule PipelineWeb.AgentController do
  use PipelineWeb, :controller
  
  def chat(conn, %{"message" => message} = params) do
    session_id = get_session_id(conn, params)
    context = build_context(conn, params)
    
    case Pipeline.Agent.Router.handle_request(message, 
      session_id: session_id, 
      context: context
    ) do
      {:ok, response} ->
        json(conn, %{
          status: "success",
          response: response,
          session_id: session_id
        })
        
      {:error, reason} ->
        json(conn, %{
          status: "error",
          error: reason,
          session_id: session_id
        })
    end
  end
  
  def session_status(conn, %{"session_id" => session_id}) do
    status = Pipeline.Agent.Router.get_session_status(session_id)
    json(conn, status)
  end
  
  def start_workflow(conn, %{"workflow" => workflow_type} = params) do
    context = build_context(conn, params)
    
    case Pipeline.Agent.Workflow.execute_workflow(workflow_type, context) do
      {:ok, result} ->
        json(conn, %{status: "success", workflow: result})
        
      {:error, reason} ->
        json(conn, %{status: "error", error: reason})
    end
  end
  
  defp get_session_id(conn, params) do
    case Map.get(params, "session_id") do
      nil -> 
        # Create new session
        {:ok, session_id} = Pipeline.Agent.Session.start_session(get_user_id(conn))
        session_id
        
      existing_id -> 
        existing_id
    end
  end
end
```

### 2. Chat Interface (Frontend)

```javascript
class PipelineAgentChat {
  constructor(apiBaseUrl) {
    this.apiBaseUrl = apiBaseUrl;
    this.sessionId = null;
    this.messageHistory = [];
  }
  
  async sendMessage(message) {
    try {
      const response = await fetch(`${this.apiBaseUrl}/agent/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: message,
          session_id: this.sessionId
        })
      });
      
      const result = await response.json();
      
      if (result.status === 'success') {
        this.sessionId = result.session_id;
        this.messageHistory.push({
          type: 'user',
          message: message,
          timestamp: new Date()
        });
        this.messageHistory.push({
          type: 'agent',
          message: result.response,
          timestamp: new Date()
        });
        
        this.displayResponse(result.response);
        return result.response;
      } else {
        this.displayError(result.error);
        throw new Error(result.error);
      }
    } catch (error) {
      this.displayError(`Communication error: ${error.message}`);
      throw error;
    }
  }
  
  displayResponse(response) {
    const chatContainer = document.getElementById('chat-messages');
    
    if (response.type === 'analysis_response') {
      this.renderAnalysisResponse(response);
    } else if (response.type === 'refactoring_response') {
      this.renderRefactoringResponse(response);
    } else if (response.type === 'workflow_response') {
      this.renderWorkflowResponse(response);
    } else {
      this.renderGenericResponse(response);
    }
  }
  
  renderAnalysisResponse(response) {
    const messageEl = document.createElement('div');
    messageEl.className = 'agent-message analysis-response';
    messageEl.innerHTML = `
      <h3>Code Analysis Results</h3>
      <div class="analysis-summary">${response.summary}</div>
      <div class="findings">
        <h4>Key Findings:</h4>
        <ul>
          ${response.findings.map(f => `<li>${f}</li>`).join('')}
        </ul>
      </div>
      <div class="recommendations">
        <h4>Recommendations:</h4>
        <ul>
          ${response.recommendations.map(r => `<li>${r}</li>`).join('')}
        </ul>
      </div>
      <div class="next-actions">
        <h4>Suggested Next Steps:</h4>
        ${response.next_actions.map(action => 
          `<button onclick="agent.sendMessage('${action}')">${action}</button>`
        ).join('')}
      </div>
    `;
    
    document.getElementById('chat-messages').appendChild(messageEl);
  }
}

// Initialize the chat interface
const agent = new PipelineAgentChat('/api');
```

### 3. CLI Commands

```elixir
defmodule Mix.Tasks.Agent.Chat do
  use Mix.Task
  
  @shortdoc "Start an interactive chat session with the AI agent"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _, _} = OptionParser.parse(args, 
      switches: [session: :string, agent: :string]
    )
    
    session_id = case Keyword.get(opts, :session) do
      nil -> 
        {:ok, session_id} = Pipeline.Agent.Session.start_session("cli_user")
        session_id
      existing -> existing
    end
    
    IO.puts("🤖 AI Agent Chat Session: #{session_id}")
    IO.puts("Type 'quit' to exit\n")
    
    chat_loop(session_id)
  end
  
  defp chat_loop(session_id) do
    input = IO.gets("You: ") |> String.trim()
    
    case input do
      "quit" -> 
        IO.puts("Goodbye!")
        
      "" ->
        chat_loop(session_id)
        
      message ->
        case Pipeline.Agent.Router.handle_request(message, session_id: session_id) do
          {:ok, response} ->
            format_cli_response(response)
            
          {:error, reason} ->
            IO.puts("❌ Error: #{reason}")
        end
        
        chat_loop(session_id)
    end
  end
  
  defp format_cli_response(response) do
    case response.type do
      "analysis_response" ->
        IO.puts("\n🔍 Analysis Results:")
        IO.puts("Summary: #{response.summary}")
        IO.puts("\nFindings:")
        Enum.each(response.findings, fn finding ->
          IO.puts("  • #{finding}")
        end)
        
      "refactoring_response" ->
        IO.puts("\n🔧 Refactoring Plan:")
        IO.puts("Strategy: #{response.strategy}")
        IO.puts("\nChanges:")
        Enum.each(response.changes, fn change ->
          IO.puts("  • #{change}")
        end)
        
      _ ->
        IO.puts("\n🤖 Agent: #{inspect(response)}")
    end
    
    IO.puts("")
  end
end
```

The Agent Framework transforms pipeline_ex from a tool into an intelligent assistant, providing natural language interfaces while leveraging the robust execution capabilities of the underlying pipeline system. This enables users to interact with complex AI workflows through conversation rather than manual command execution.