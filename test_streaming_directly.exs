# Direct test of streaming with proper message handling
alias Pipeline.Providers.ClaudeProvider
alias Pipeline.Streaming.AsyncResponse
alias Pipeline.Streaming.Handlers.ConsoleHandler

# Test prompt that should make Claude output numbers directly
prompt = """
Output exactly this:
1

Then wait 5 seconds and output:
2

Then wait 5 seconds and output:
3

Output ONLY these three numbers, nothing else.
"""

options = %{
  "async_streaming" => true,
  "stream_handler" => "console", 
  "max_turns" => 1,
  "allowed_tools" => [],
  "system_prompt" => "You output exactly what is requested, nothing more.",
  "verbose" => true,
  "step_name" => "test_streaming"
}

IO.puts("Starting streaming test...")
IO.puts("=" <> String.duplicate("=", 50))

case ClaudeProvider.query(prompt, options) do
  {:ok, %AsyncResponse{} = async_response} ->
    IO.puts("\nGot AsyncResponse, processing stream...")
    
    # Process the stream with console handler
    handler_options = %{
      handler_module: ConsoleHandler,
      handler_opts: %{
        show_header: false,
        show_stats: true,
        show_timestamps: true,
        use_colors: true
      }
    }
    
    case Pipeline.Streaming.AsyncHandler.process_stream(async_response.stream, handler_options) do
      {:ok, _result} ->
        IO.puts("\nStream processing completed successfully!")
      
      {:error, reason} ->
        IO.puts("\nStream processing failed: #{inspect(reason)}")
    end
    
  {:ok, response} ->
    IO.puts("\nGot synchronous response (not streaming):")
    IO.inspect(response, pretty: true)
    
  {:error, reason} ->
    IO.puts("\nError: #{inspect(reason)}")
end