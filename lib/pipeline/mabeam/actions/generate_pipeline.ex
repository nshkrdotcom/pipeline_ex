defmodule Pipeline.MABEAM.Actions.GeneratePipeline do
  @moduledoc """
  Jido Action that generates a new pipeline using the Genesis system.
  
  This action integrates with the existing Genesis pipeline generation
  capabilities, allowing MABEAM agents to create new pipelines dynamically.
  """
  
  use Jido.Action,
    name: "generate_pipeline",
    description: "Generates a new pipeline using Genesis system",
    schema: [
      description: [type: :string, required: true, doc: "Description of pipeline to generate"],
      output_file: [type: :string, required: true, doc: "Output file path for generated pipeline"],
      workspace_dir: [type: :string, default: "./workspace", doc: "Workspace directory for generation"]
    ]

  @impl true
  def run(params, _context) do
    # Integration with existing Genesis pipeline generation
    # Use existing mix task functionality via System.cmd
    case System.cmd("mix", ["pipeline.generate.live", params.description], 
         into: "", stderr_to_stdout: true, cd: File.cwd!()) do
      {output, 0} -> 
        {:ok, %{
          description: params.description,
          output_file: params.output_file,
          generation_output: output,
          generated_at: DateTime.utc_now(),
          status: :generated
        }}
      {error, exit_code} -> 
        {:error, "Generation failed (exit #{exit_code}): #{error}"}
    end
  rescue
    error ->
      {:error, "Generation error: #{Exception.message(error)}"}
  end
end