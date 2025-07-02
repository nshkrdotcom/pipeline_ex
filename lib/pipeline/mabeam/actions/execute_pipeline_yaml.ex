defmodule Pipeline.MABEAM.Actions.ExecutePipelineYaml do
  @moduledoc """
  Jido Action that executes a pipeline_ex YAML workflow.
  
  This action wraps the existing Pipeline.run/2 API with Jido's
  built-in validation, error handling, and execution framework.
  """
  
  use Jido.Action,
    name: "execute_pipeline_yaml",
    description: "Executes a pipeline_ex YAML workflow",
    schema: [
      pipeline_file: [type: :string, required: true, doc: "Path to YAML pipeline file"],
      workspace_dir: [type: :string, default: "./workspace", doc: "Directory for AI workspace operations"],
      output_dir: [type: :string, default: "./outputs", doc: "Directory for pipeline outputs"],
      debug: [type: :boolean, default: false, doc: "Enable debug logging"],
      timeout: [type: :pos_integer, default: 300_000, doc: "Execution timeout in milliseconds"]
    ]

  @impl true
  def run(params, _context) do
    # Extract parameters with defaults
    pipeline_file = Map.fetch!(params, :pipeline_file)
    workspace_dir = Map.get(params, :workspace_dir, "./workspace")
    output_dir = Map.get(params, :output_dir, "./outputs")
    debug = Map.get(params, :debug, false)
    
    # Use existing Pipeline.run/2 API
    case Pipeline.run(pipeline_file,
         workspace_dir: workspace_dir,
         output_dir: output_dir,
         debug: debug) do
      {:ok, result} -> 
        {:ok, %{
          pipeline_file: pipeline_file,
          execution_time: DateTime.utc_now(),
          result: result,
          status: :completed
        }}
      {:error, reason} -> 
        {:error, "Pipeline execution failed: #{reason}"}
    end
  end
end