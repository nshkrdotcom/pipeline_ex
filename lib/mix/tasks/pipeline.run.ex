defmodule Mix.Tasks.Pipeline.Run do
  @moduledoc """
  Runs a Pipeline workflow from a YAML configuration file.

  ## Usage

      mix pipeline.run <config_file>          # Run in mock mode (safe, no API costs)
      TEST_MODE=live mix pipeline.run <config_file>  # Run with real API calls

  ## Examples

      # Run the comprehensive example in mock mode
      mix pipeline.run examples/comprehensive_config_example.yaml

      # Run with real AI providers (requires API keys)
      TEST_MODE=live mix pipeline.run examples/comprehensive_config_example.yaml

      # Run with debug output
      PIPELINE_DEBUG=true mix pipeline.run examples/comprehensive_config_example.yaml

  ## Environment Variables

  - `TEST_MODE`: "mock" (default), "live", or "mixed"
  - `PIPELINE_DEBUG`: "true" to enable detailed logging
  - `PIPELINE_LOG_LEVEL`: "debug", "info" (default), "warn", "error"
  - `GEMINI_API_KEY`: Required for live mode with Gemini

  """
  use Mix.Task

  @shortdoc "Run a Pipeline workflow from YAML configuration"

  def run([]) do
    Mix.shell().error("Usage: mix pipeline.run <config_file>")
    Mix.shell().error("")
    Mix.shell().error("Examples:")
    Mix.shell().error("  mix pipeline.run examples/comprehensive_config_example.yaml")

    Mix.shell().error(
      "  TEST_MODE=live mix pipeline.run examples/comprehensive_config_example.yaml"
    )

    System.halt(1)
  end

  def run([config_file | _rest]) do
    Mix.Task.run("app.start")

    # Determine execution mode (default to mock for safety)
    test_mode = System.get_env("TEST_MODE", "mock")
    debug_enabled = System.get_env("PIPELINE_DEBUG", "false") == "true"
    # Ensure TEST_MODE is set for the TestMode module
    unless System.get_env("TEST_MODE") do
      System.put_env("TEST_MODE", "mock")
    end

    # Display execution info
    display_execution_info(config_file, test_mode, debug_enabled)

    # Check if file exists
    unless File.exists?(config_file) do
      Mix.shell().error("❌ Configuration file not found: #{config_file}")
      System.halt(1)
    end

    # Check authentication for live mode
    if test_mode == "live" and not check_authentication() do
      Mix.shell().error("❌ Authentication not ready for live mode")
      System.halt(1)
    end

    # Load and execute workflow
    case Pipeline.Config.load_workflow(config_file) do
      {:ok, config} ->
        execute_workflow(config, debug_enabled)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to load configuration: #{reason}")
        System.halt(1)
    end
  end

  defp display_execution_info(config_file, test_mode, debug_enabled) do
    Mix.shell().info("🚀 Running Pipeline Workflow")
    Mix.shell().info("📁 Config: #{config_file}")
    Mix.shell().info("🎭 Mode: #{format_mode(test_mode)}")

    if debug_enabled do
      Mix.shell().info("🐛 Debug: Enabled")
    end

    if test_mode == "live" do
      Mix.shell().info("⚠️  Live mode will make real API calls and incur costs!")
    end

    Mix.shell().info("")
  end

  defp format_mode("mock"), do: "Mock (safe, no API costs)"
  defp format_mode("live"), do: "Live (real API calls, costs money)"
  defp format_mode("mixed"), do: "Mixed (context-dependent)"
  defp format_mode(mode), do: mode

  defp check_authentication do
    claude_ok = check_claude_auth()
    gemini_ok = check_gemini_auth()

    unless claude_ok do
      Mix.shell().error("❌ Claude CLI not available")
      Mix.shell().error("   Install Claude CLI: https://claude.ai/download")
      Mix.shell().error("   Authenticate: claude auth")
    end

    unless gemini_ok do
      Mix.shell().error("❌ Gemini authentication not ready")
      Mix.shell().error("   Set API key: export GEMINI_API_KEY=\"your_key\"")
      Mix.shell().error("   Get key from: https://aistudio.google.com/app/apikey")
    end

    claude_ok and gemini_ok
  end

  defp check_claude_auth do
    System.find_executable("claude") != nil
  end

  defp check_gemini_auth do
    System.get_env("GEMINI_API_KEY") != nil
  end

  defp execute_workflow(config, debug_enabled) do
    # Set up output directory
    output_dir = System.get_env("PIPELINE_OUTPUT_DIR", "./outputs")

    # Configure logging if debug is enabled
    if debug_enabled do
      Logger.configure(level: :debug)
    end

    # Execute the pipeline
    case Pipeline.Executor.execute(config, output_dir: output_dir) do
      {:ok, results} ->
        Mix.shell().info("✅ Pipeline completed successfully!")

        if debug_enabled do
          Mix.shell().info("📊 Results:")
          Mix.shell().info(inspect(results, pretty: true, limit: :infinity))
        else
          Mix.shell().info("📁 Check #{output_dir} for detailed results")
        end

      {:error, reason} ->
        Mix.shell().error("❌ Pipeline failed: #{reason}")
        System.halt(1)
    end
  end
end
