#!/usr/bin/env elixir

# EXACT REPRODUCTION OF CLAUDE SDK BUG FROM PIPELINE
# This uses the EXACT same options that cause the pipeline to fail

Mix.install([
  {:claude_code_sdk, path: "/home/home/p/g/n/claude_code_sdk_elixir"},
  {:jason, "~> 1.4"}
])

IO.puts("🐛 EXACT CLAUDE SDK BUG REPRODUCTION")
IO.puts("=" |> String.duplicate(50))
IO.puts("Using EXACT options from pipeline that cause the bug")
IO.puts("")

prompt = "What is 2+2? Answer with just the number."

# These are the EXACT options from the pipeline enhanced provider
# that cause the Access.get(4.0, "type", nil) error
options = ClaudeCodeSDK.Options.new(
  max_turns: 1,
  output_format: :text,  # THIS IS THE PROBLEMATIC SETTING
  verbose: true,         # Pipeline sets this to true
  system_prompt: "You are a helpful development assistant. Focus on writing clean, maintainable code.",
  append_system_prompt: "Use detailed logging and provide comprehensive explanations.",
  allowed_tools: ["Write", "Edit", "Read", "Bash", "Search", "Glob", "Grep"],
  cwd: "./workspace"
)

IO.puts("Prompt: #{prompt}")
IO.puts("Options: #{inspect(options)}")
IO.puts("")
IO.puts("This should cause: Access.get(4.0, \"type\", nil) error")
IO.puts("Because Claude CLI will return plain text '4' instead of JSON")
IO.puts("")

try do
  IO.puts("🎯 Creating Claude SDK query...")
  stream = ClaudeCodeSDK.query(prompt, options)
  
  IO.puts("🎯 Attempting to read first message...")
  messages = Enum.take(stream, 1)
  
  IO.puts("❌ BUG NOT REPRODUCED - This should have failed!")
  IO.puts("Got messages: #{inspect(messages)}")
  
rescue
  error ->
    case error do
      %FunctionClauseError{} ->
        IO.puts("✅ BUG SUCCESSFULLY REPRODUCED!")
        IO.puts("Error: #{Exception.message(error)}")
        IO.puts("")
        IO.puts("🎯 ROOT CAUSE:")
        IO.puts("   1. Claude CLI called with --output-format text")
        IO.puts("   2. Claude CLI returns plain text: '4'")
        IO.puts("   3. SDK tries to parse '4' as JSON")
        IO.puts("   4. Access.get(4.0, \"type\", nil) fails")
        IO.puts("   5. Because 4.0 is a number, not a map")
        IO.puts("")
        IO.puts("🔧 SOLUTION:")
        IO.puts("   SDK needs format-aware parsing:")
        IO.puts("   - Check output_format before parsing")  
        IO.puts("   - Handle text responses differently from JSON")
        
      _ ->
        IO.puts("❌ DIFFERENT ERROR:")
        IO.puts("Type: #{error.__struct__}")
        IO.puts("Message: #{Exception.message(error)}")
    end
end