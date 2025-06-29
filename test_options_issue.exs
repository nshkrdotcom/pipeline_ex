#!/usr/bin/env elixir

# Test different option configurations to find the issue
IO.puts "🔍 Testing Options Issue..."

test_cases = [
  {nil, "Default (nil) options"},
  {%ClaudeCodeSDK.Options{}, "Empty options struct"},
  {%ClaudeCodeSDK.Options{max_turns: 1}, "Just max_turns"},
  {%ClaudeCodeSDK.Options{output_format: :text}, "Just output_format"},
  {%ClaudeCodeSDK.Options{cwd: "/tmp"}, "Just cwd"},
  {%ClaudeCodeSDK.Options{max_turns: 1, output_format: :text}, "max_turns + output_format"},
  {%ClaudeCodeSDK.Options{max_turns: 1, output_format: :text, cwd: "/tmp"}, "Full options (problematic)"}
]

test_cases
|> Enum.with_index()
|> Enum.each(fn {{opts, description}, i} ->
  IO.puts "\n📋 Test #{i + 1}: #{description}"
  IO.puts "   Options: #{inspect(opts)}"
  
  try do
    stream = ClaudeCodeSDK.query("Test #{i + 1}", opts)
    messages = Enum.take(stream, 3)  # Just get first 3 messages
    
    IO.puts "   Message types: #{inspect(Enum.map(messages, &(&1.type)))}"
    
    # Check if we got the right types
    types = Enum.map(messages, &(&1.type))
    if :system in types and :assistant in types and :result in types do
      IO.puts "   ✅ CORRECT: Got system, assistant, result types"
    else
      IO.puts "   ❌ ISSUE: Got unexpected types"
    end
    
  rescue
    error ->
      IO.puts "   ❌ ERROR: #{inspect(error)}"
  end
end)

IO.puts "\n🎯 Conclusion: Look for the option that causes 'unknown' types"