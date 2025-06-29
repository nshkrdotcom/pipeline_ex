defmodule Mix.Tasks.Pipeline.Run.Live do
  @moduledoc """
  Runs a Pipeline workflow from a YAML configuration file in LIVE mode.

  ## Usage

      mix pipeline.run.live <config_file>  # Run with real API calls

  ## Examples

      # Run the comprehensive example with real AI providers (requires API keys)
      mix pipeline.run.live examples/comprehensive_config_example.yaml

      # Run with debug output
      PIPELINE_DEBUG=true mix pipeline.run.live examples/comprehensive_config_example.yaml

  ## Environment Variables

  - `PIPELINE_DEBUG`: "true" to enable detailed logging
  - `PIPELINE_LOG_LEVEL`: "debug", "info" (default), "warn", "error"
  - `GEMINI_API_KEY`: Required for Gemini API calls

  """
  use Mix.Task

  alias Mix.Tasks.Pipeline.Run

  @shortdoc "Run a Pipeline workflow in LIVE mode with real API calls"

  def run(args) do
    # Set TEST_MODE to live before delegating
    System.put_env("TEST_MODE", "live")

    # Delegate to the main pipeline.run task
    Run.run(args)
  end
end
