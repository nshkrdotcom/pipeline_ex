#!/usr/bin/env elixir

# Debug Claude step issue
IO.puts "🐛 Debugging Claude Step Issue..."

try do
  # Test the exact scenario that's failing
  test_step = %{
    name: "test_step",
    prompt: [%{type: "static", content: "Say exactly: 'Pipeline step working!'"}],
    claude_options: %{max_turns: 1, output_format: "text"}
  }
  
  test_orch = %{
    results: %{},
    debug_log: "/tmp/test.log", 
    output_dir: "/tmp",
    workspace_dir: "/tmp"
  }
  
  IO.puts "Step: #{inspect(test_step)}"
  IO.puts "Claude options: #{inspect(test_step[:claude_options])}"
  IO.puts "Claude options type: #{inspect(test_step[:claude_options].__struct__)}"
  
  # Try the exact function that's failing
  claude_opts = test_step[:claude_options]
  IO.puts "Accessing max_turns: #{inspect(claude_opts[:max_turns])}"
  
rescue
  error ->
    IO.puts "❌ Error in setup: #{inspect(error)}"
end

# Test ClaudeCodeSDK.Options directly
IO.puts "\n🔧 Testing ClaudeCodeSDK.Options..."

try do
  opts = %ClaudeCodeSDK.Options{}
  IO.puts "Default options: #{inspect(opts)}"
  
  # Test field access
  IO.puts "Output format: #{opts.output_format}"
  
  # Test struct update
  new_opts = %{opts | max_turns: 5}
  IO.puts "Updated options: #{inspect(new_opts)}"
  
rescue
  error ->
    IO.puts "❌ Error with options: #{inspect(error)}"
end