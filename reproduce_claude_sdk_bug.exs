#!/usr/bin/env elixir

# STANDALONE SCRIPT TO REPRODUCE CLAUDE SDK PARSING BUG
# This script reproduces the exact Access.get(4.0, "type", nil) error

Mix.install([
  {:claude_code_sdk, path: "/home/home/p/g/n/claude_code_sdk_elixir"},
  {:jason, "~> 1.4"}
])

IO.puts("🐛 REPRODUCING CLAUDE SDK PARSING BUG")
IO.puts("=" |> String.duplicate(50))

prompt = "What is 2+2? Answer with just the number."

IO.puts("Testing Claude SDK with output_format: :text")
IO.puts("This WILL cause: Access.get(4.0, \"type\", nil) error")
IO.puts("")

try do
  # This is the exact configuration that causes the bug
  options = ClaudeCodeSDK.Options.new(
    max_turns: 1,
    output_format: :text,  # THIS CAUSES THE BUG
    verbose: false
  )
  
  IO.puts("Creating Claude SDK query with text format...")
  stream = ClaudeCodeSDK.query(prompt, options)
  
  IO.puts("Attempting to read from stream...")
  messages = Enum.take(stream, 1)
  
  IO.puts("❌ UNEXPECTED: No error occurred")
  IO.puts("Messages: #{inspect(messages)}")
  
rescue
  error ->
    IO.puts("✅ REPRODUCED THE BUG!")
    IO.puts("Error: #{Exception.message(error)}")
    IO.puts("Type: #{error.__struct__}")
    
    case error do
      %FunctionClauseError{} ->
        IO.puts("")
        IO.puts("🎯 This is the exact bug:")
        IO.puts("   Claude CLI returns: \"4\" (plain text)")
        IO.puts("   SDK tries to parse it as JSON")
        IO.puts("   Access.get(4.0, \"type\", nil) fails")
        IO.puts("   Because 4.0 is a number, not a map with a \"type\" key")
      _ ->
        IO.puts("Different error than expected")
    end
    
    IO.puts("")
    IO.puts("Stacktrace:")
    __STACKTRACE__
    |> Enum.take(5)
    |> Enum.each(fn frame ->
      IO.puts("  #{Exception.format_stacktrace_entry(frame)}")
    end)
end