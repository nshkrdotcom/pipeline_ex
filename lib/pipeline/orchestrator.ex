defmodule Pipeline.Orchestrator do
  @moduledoc """
  Main orchestration engine that combines Gemini (Brain) and Claude (Muscle)
  to execute complex AI workflows.
  """

  alias Pipeline.{Config, Step, Debug}
  alias Pipeline.Tools.ToolRegistry
  require Logger

  defstruct [:config, :results, :debug_log, :output_dir, :workspace_dir]

  @doc """
  Initialize a new orchestrator with a config file path.
  """
  def new(config_path) do
    with {:ok, config} <- Config.load(config_path) do
      # Create directories
      output_dir = config.workflow.defaults[:output_dir] || "./outputs"
      workspace_dir = config.workflow[:workspace_dir] || "./workspace"
      
      File.mkdir_p!(output_dir)
      File.mkdir_p!(workspace_dir)
      
      # Start and initialize tool registry
      {:ok, _pid} = ToolRegistry.start_link()
      ToolRegistry.auto_register_tools()
      
      Logger.info("✅ Debug: Gemini API configured successfully")
      if config.workflow[:workspace_dir], do: Logger.info("✅ Created workspace directory: #{workspace_dir}")
      
      # Initialize debug log
      timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[:\s]/, "_")
      debug_log_path = Path.join(output_dir, "debug_#{timestamp}.log")
      
      {:ok, %__MODULE__{
        config: config,
        results: %{},
        debug_log: debug_log_path,
        output_dir: output_dir,
        workspace_dir: workspace_dir
      }}
    end
  end

  @doc """
  Run the pipeline workflow.
  """
  def run(%__MODULE__{} = orch) do
    workflow = orch.config.workflow
    steps = workflow.steps
    
    Logger.info("\n🚀 Starting pipeline: #{workflow.name}")
    Logger.info("📊 Total steps: #{length(steps)}")
    
    # Log to debug file
    Debug.log(orch.debug_log, "Pipeline started: #{workflow.name}")
    Debug.log(orch.debug_log, "Config: #{inspect(orch.config, pretty: true)}")
    
    # Execute steps
    final_orch = Enum.reduce(steps, orch, fn step, acc ->
      step_num = Enum.find_index(steps, &(&1 == step)) + 1
      total_steps = length(steps)
      
      # Check condition
      if should_execute_step?(step, acc.results) do
        Logger.info("\n🔄 Executing step #{step_num}/#{total_steps}: #{step.name}")
        
        result = execute_step(step, acc)
        
        # Update results
        updated_orch = %{acc | results: Map.put(acc.results, step.name, result)}
        
        # Save checkpoint if enabled
        if workflow[:checkpoint_enabled] do
          save_checkpoint(updated_orch)
        end
        
        Logger.info("✅ Step #{step.name} completed")
        
        updated_orch
      else
        Logger.info("\n⏭️  Skipping step #{step_num}/#{total_steps}: #{step.name} (condition not met)")
        acc
      end
    end)
    
    Logger.info("\n🎉 Pipeline completed successfully!")
    Logger.info("📋 Debug log: #{orch.debug_log}")
    Logger.info("💡 Tip: Run 'mix run view_debug.exs' to see the full debug log and outputs")
    
    {:ok, final_orch}
  end

  defp should_execute_step?(step, results) do
    case step[:condition] do
      nil -> true
      condition ->
        # Parse condition like "step_name.field_name"
        case String.split(condition, ".") do
          [step_name, field_name] ->
            case Map.get(results, step_name) do
              nil -> false
              result -> 
                # Check if result has the field and it's truthy
                get_in(result, [String.to_existing_atom(field_name)]) == true
            end
          _ -> true
        end
    end
  end

  defp execute_step(step, orch) do
    case step.type do
      "gemini" -> Step.GeminiInstructor.execute(step, orch)
      "claude" -> Step.Claude.execute(step, orch)
      "parallel_claude" -> Step.ParallelClaude.execute(step, orch)
      _ -> raise "Unknown step type: #{step.type}"
    end
  end

  defp save_checkpoint(orch) do
    checkpoint_dir = orch.config.workflow[:checkpoint_dir] || "./checkpoints"
    File.mkdir_p!(checkpoint_dir)
    
    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[:\s]/, "_")
    checkpoint_file = Path.join(checkpoint_dir, "checkpoint_#{timestamp}.json")
    
    checkpoint_data = %{
      results: orch.results,
      timestamp: DateTime.utc_now()
    }
    
    File.write!(checkpoint_file, Jason.encode!(checkpoint_data, pretty: true))
  end
end