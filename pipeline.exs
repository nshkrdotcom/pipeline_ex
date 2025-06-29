# Pipeline CLI Runner
# Usage: mix run pipeline.exs <config.yaml>

# Configure Gemini API key
gemini_api_key = System.get_env("GEMINI_API_KEY")
if !gemini_api_key do
  IO.puts("Error: GEMINI_API_KEY environment variable not set")
  IO.puts("Please run: export GEMINI_API_KEY=your_api_key")
  System.halt(1)
end

# Store API key for InstructorLite to use
Application.put_env(:pipeline, :gemini_api_key, gemini_api_key)

# Get config file path
config_path = case System.argv() do
  [path] -> path
  _ ->
    IO.puts("Usage: mix run pipeline.exs <config.yaml>")
    System.halt(1)
end

# Run the pipeline
case Pipeline.Orchestrator.new(config_path) do
  {:ok, orchestrator} ->
    case Pipeline.Orchestrator.run(orchestrator) do
      {:ok, _result} ->
        IO.puts("\n✅ Pipeline completed successfully!")
      {:error, error} ->
        IO.puts("\n❌ Pipeline failed: #{inspect(error)}")
        System.halt(1)
    end
  {:error, error} ->
    IO.puts("\n❌ Failed to initialize pipeline: #{inspect(error)}")
    System.halt(1)
end