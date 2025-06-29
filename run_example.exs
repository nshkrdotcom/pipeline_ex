#!/usr/bin/env elixir

# Simple example runner for Pipeline
Mix.install([
  {:pipeline, path: "."}
])

# Set test mode to use mocks
System.put_env("TEST_MODE", "mock")

# Load the workflow
config_file = "test_simple_workflow.yaml"
{:ok, config} = Pipeline.Config.load_workflow(config_file)

IO.puts("🚀 Running workflow: #{config["workflow"]["name"]}")
IO.puts("📝 Description: #{config["workflow"]["description"]}")

# Create output directory
output_dir = "outputs/test_run_#{:os.system_time(:second)}"
File.mkdir_p!(output_dir)

# Run the pipeline
case Pipeline.Executor.execute(config, output_dir: output_dir, test_mode: :mock) do
  {:ok, results} ->
    IO.puts("\n✅ Pipeline completed successfully!")
    IO.puts("📁 Results saved to: #{output_dir}")
    
    # Display results
    IO.puts("\n📊 Results:")
    Enum.each(results, fn {step_name, result} ->
      IO.puts("\n  Step: #{step_name}")
      IO.puts("  Status: #{if result["success"], do: "✅ Success", else: "❌ Failed"}")
      if result["success"] do
        IO.puts("  Output: #{inspect(result["text"] || result["output"], pretty: true, limit: :infinity)}")
      else
        IO.puts("  Error: #{result["error"]}")
      end
    end)
    
  {:error, reason} ->
    IO.puts("\n❌ Pipeline failed: #{reason}")
    System.halt(1)
end