defmodule Mix.Tasks.Pipeline.Showcase do
  @moduledoc """
  Demonstrates the Pipeline with both mock and live modes.

  ## Usage

      mix pipeline.showcase          # Mock mode (safe, no API costs)
      mix pipeline.showcase --live   # Live mode (real API calls, costs money)

  """
  use Mix.Task

  @shortdoc "Showcase Pipeline features in mock or live mode"
  @preferred_cli_env :dev

  def run(args) do
    Mix.Task.run("app.start")

    live_mode = "--live" in args or "--real" in args

    if live_mode do
      run_live_showcase()
    else
      run_mock_showcase()
    end
  end

  defp run_mock_showcase do
    IO.puts("🎭 PIPELINE SHOWCASE - MOCK MODE")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("✅ Safe mode: No API calls, no costs, no authentication needed")
    IO.puts("")

    # Set mock mode
    System.put_env("TEST_MODE", "mock")

    showcase_pipeline("Mock Mode")
  end

  defp run_live_showcase do
    IO.puts("🚀 PIPELINE SHOWCASE - LIVE MODE")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("⚠️  LIVE MODE: Real API calls will be made!")
    IO.puts("")

    # Check authentication
    unless check_authentication() do
      System.halt(1)
    end

    # Set live mode
    System.delete_env("TEST_MODE")

    showcase_pipeline("Live Mode")
  end

  defp showcase_pipeline(mode_name) do
    IO.puts("📋 Loading workflow configuration...")

    config_file = "test_simple_workflow.yaml"

    case Pipeline.Config.load_workflow(config_file) do
      {:ok, config} ->
        IO.puts("✅ Workflow loaded: #{config["workflow"]["name"]}")
        IO.puts("📝 Description: #{config["workflow"]["description"]}")
        IO.puts("")

        output_dir =
          "outputs/showcase_#{mode_name |> String.downcase() |> String.replace(" ", "_")}_#{:os.system_time(:second)}"

        IO.puts("🎯 Executing pipeline in #{mode_name}...")
        start_time = System.monotonic_time(:millisecond)

        case Pipeline.Executor.execute(config, output_dir: output_dir) do
          {:ok, results} ->
            duration = System.monotonic_time(:millisecond) - start_time

            IO.puts("")
            IO.puts("✅ Pipeline completed successfully!")
            IO.puts("⏱️  Duration: #{duration}ms")
            IO.puts("📁 Results saved to: #{output_dir}")
            IO.puts("")

            display_results(results, mode_name)

          {:error, reason} ->
            IO.puts("")
            IO.puts("❌ Pipeline failed: #{reason}")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts("❌ Failed to load workflow: #{reason}")
        System.halt(1)
    end
  end

  defp check_authentication do
    IO.puts("🔍 Checking authentication...")

    # Check Claude CLI
    claude_available =
      case System.find_executable("claude") do
        nil ->
          IO.puts("❌ Claude CLI not found. Install with:")
          IO.puts("   npm install -g @anthropic-ai/claude-code")
          false

        _path ->
          IO.puts("✅ Claude CLI found")
          true
      end

    # Check Gemini API key
    gemini_available =
      case System.get_env("GEMINI_API_KEY") do
        nil ->
          IO.puts("❌ GEMINI_API_KEY not set. Get your key from:")
          IO.puts("   https://aistudio.google.com/app/apikey")
          IO.puts("   Then set: export GEMINI_API_KEY=\"your_key_here\"")
          false

        _key ->
          IO.puts("✅ Gemini API key found")
          true
      end

    if claude_available and gemini_available do
      IO.puts("✅ Authentication ready for live mode")
      IO.puts("")
      true
    else
      IO.puts("")
      IO.puts("💡 To run in live mode, set up authentication above")
      IO.puts("💡 Or use mock mode: mix pipeline.showcase")
      false
    end
  end

  defp display_results(results, mode_name) do
    IO.puts("📊 RESULTS (#{mode_name})")
    IO.puts("-" |> String.duplicate(30))

    Enum.each(results, fn {step_name, result} ->
      IO.puts("")
      IO.puts("🎯 Step: #{step_name}")

      success = result[:success] || result["success"]
      success = if is_nil(success), do: true, else: success
      status = if success, do: "✅ Success", else: "❌ Failed"
      IO.puts("   Status: #{status}")

      if success do
        display_success_output(result)
      else
        display_error_output(result)
      end
    end)

    IO.puts("")
    IO.puts("🎉 Showcase complete!")

    if mode_name == "Mock Mode" do
      IO.puts("")
      IO.puts("💡 Ready to try live mode? Run: mix pipeline.showcase --live")
      IO.puts("   (Make sure to set up authentication first)")
    end
  end

  defp extract_content(result) when is_binary(result), do: result
  defp extract_content(result) when is_map(result), do: extract_content_from_map(result)
  defp extract_content(result), do: inspect(result, limit: 200)

  defp extract_content_from_map(result) when is_map(result) do
    result[:content] || result["content"] || result[:text] || result["text"] ||
      inspect(result, limit: 200)
  end

  defp display_success_output(result) do
    content = extract_content(result)
    preview = String.slice(content, 0, 200)
    preview = if String.length(content) > 200, do: preview <> "...", else: preview
    IO.puts("   Output: #{preview}")
  end

  defp display_error_output(result) do
    error = result[:error] || result["error"] || "Unknown error"
    IO.puts("   Error: #{error}")
  end
end
