alias Pipeline.Providers.ClaudeProvider
alias ClaudeCodeSDK

# Simple direct test of ClaudeCodeSDK streaming
prompt = """
Please output exactly this sequence:
1. Output the number "1"
2. Wait 5 seconds
3. Output the number "2"
4. Wait 5 seconds
5. Output the number "3"
6. Stop

Output only the numbers, nothing else.
"""

sdk_options = ClaudeCodeSDK.Options.new(
  max_turns: 1,
  verbose: true,
  allowed_tools: [],
  disallowed_tools: [],
  cwd: "./workspace",
  timeout_ms: 60000,
  async: true
)

IO.puts("Starting ClaudeCodeSDK stream test...")
IO.puts("=" <> String.duplicate("=", 50))

stream = ClaudeCodeSDK.query(prompt, sdk_options)

IO.puts("\nProcessing stream messages:")
IO.puts("-" <> String.duplicate("-", 50))

stream
|> Stream.with_index()
|> Enum.each(fn {message, index} ->
  IO.puts("\nMessage #{index + 1}:")
  IO.inspect(message, pretty: true, limit: :infinity)
  IO.puts("-" <> String.duplicate("-", 30))
end)

IO.puts("\nStream test complete!")