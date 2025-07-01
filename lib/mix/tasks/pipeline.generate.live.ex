defmodule Mix.Tasks.Pipeline.Generate.Live do
  @moduledoc """
  Generates a new pipeline using the Genesis Pipeline in LIVE mode.

  ## Usage

      mix pipeline.generate.live "Create a pipeline that analyzes code quality"
      
  ## Options

    * `--output` - Output file path (defaults to generated_pipeline.yaml)
    * `--profile` - Performance profile: speed_optimized, accuracy_optimized, balanced
    * `--complexity` - Target complexity: simple, moderate, complex
    * `--dry-run` - Show what would be generated without creating files
    
  ## Examples

      # Generate a simple data processing pipeline with real AI
      mix pipeline.generate.live "Process CSV data and extract insights"
      
      # Generate an optimized pipeline with specific profile
      mix pipeline.generate.live "Analyze customer feedback" --profile accuracy_optimized
      
      # Preview pipeline without creating files
      mix pipeline.generate.live "Generate API documentation" --dry-run
      
  ## Environment Variables

  - `PIPELINE_DEBUG`: "true" to enable detailed logging
  - `CLAUDE_API_KEY`: Required for Claude API calls
  - `GEMINI_API_KEY`: Required for Gemini API calls
  """

  use Mix.Task

  alias Mix.Tasks.Pipeline.Generate

  @shortdoc "Generate a new pipeline using the Genesis Pipeline in LIVE mode"

  @impl Mix.Task
  def run(args) do
    # Set TEST_MODE to live before delegating
    System.put_env("TEST_MODE", "live")

    # Delegate to the main pipeline.generate task
    Generate.run(args)
  end
end
