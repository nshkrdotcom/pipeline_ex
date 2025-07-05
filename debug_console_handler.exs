# Debug console handler to see what messages are coming through
alias Pipeline.Providers.ClaudeProvider
alias Pipeline.Streaming.AsyncResponse

prompt = "Output only these three numbers, one per line:\n1\n2\n3"

options = %{
  "async_streaming" => true,
  "stream_handler" => "console", 
  "max_turns" => 1,
  "allowed_tools" => [],
  "system_prompt" => "Output exactly what is requested, nothing more.",
  "verbose" => true,
  "step_name" => "debug_test"
}

IO.puts("Starting debug test...")

case ClaudeProvider.query(prompt, options) do
  {:ok, %AsyncResponse{} = async_response} ->
    IO.puts("\nProcessing stream with debug handler...")
    
    # Process stream manually to debug
    async_response.stream
    |> Stream.with_index()
    |> Enum.each(fn {msg, idx} ->
      IO.puts("\n=== Message #{idx + 1} ===")
      IO.puts("Type: #{inspect(msg.__struct__)}")
      IO.puts("Message type: #{inspect(msg.type)}")
      IO.puts("Subtype: #{inspect(msg.subtype)}")
      IO.puts("Data keys: #{inspect(Map.keys(msg.data))}")
      
      if msg.type == :assistant do
        IO.puts("Assistant data: #{inspect(msg.data, pretty: true, limit: :infinity)}")
      end
    end)
    
  error ->
    IO.puts("Error: #{inspect(error)}")
end