#!/usr/bin/env elixir

# Simple example runner for Pipeline
Mix.install([
  {:pipeline, path: "."}
])

# Use live adapters (remove test mode)
# System.put_env("TEST_MODE", "mock")

# Load the workflow
config_file = "test_simple_workflow.yaml"
{:ok, config} = Pipeline.Config.load_workflow(config_file)

IO.puts("🚀 Running workflow: #{config["workflow"]["name"]}")
IO.puts("📝 Description: #{config["workflow"]["description"]}")

# Create output directory
output_dir = "outputs/test_run_#{:os.system_time(:second)}"
File.mkdir_p!(output_dir)

# Run the pipeline
case Pipeline.Executor.execute(config, output_dir: output_dir) do
  {:ok, results} ->
    IO.puts("\n✅ Pipeline completed successfully!")
    IO.puts("📁 Results saved to: #{output_dir}")
    
    # Display results
    IO.puts("\n📊 Results:")
    Enum.each(results, fn {step_name, result} ->
      IO.puts("\n  Step: #{step_name}")
      # Handle both atom and string keys, and different result structures
      success = result[:success] || result["success"] || true  # Default to true if not specified
      IO.puts("  Status: #{if success, do: "✅ Success", else: "❌ Failed"}")
      if success do
        content = result[:content] || result["content"] || result[:text] || result["text"] || result["output"] || inspect(result, limit: 500)
        IO.puts("  Output: #{String.slice(to_string(content), 0, 1000)}#{if String.length(to_string(content)) > 1000, do: "...", else: ""}")
      else
        error = result[:error] || result["error"] || "Unknown error"
        IO.puts("  Error: #{error}")
      end
    end)
    
  {:error, reason} ->
    IO.puts("\n❌ Pipeline failed: #{reason}")
    System.halt(1)
end