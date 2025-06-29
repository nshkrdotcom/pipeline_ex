#!/usr/bin/env elixir

# Debug Claude response processing
IO.puts "🔍 Debugging Claude Response Processing..."

try do
  # Test the pipeline step with detailed output
  test_step = %{
    name: "debug_step",
    prompt: [%{type: "static", content: "Say exactly: 'Debug response test!'"}],
    claude_options: %{max_turns: 1, output_format: "text"}
  }
  
  test_orch = %{
    results: %{},
    debug_log: "/tmp/debug.log", 
    output_dir: "/tmp",
    workspace_dir: "/tmp"
  }
  
  IO.puts "📋 Executing pipeline step..."
  result = Pipeline.Step.Claude.execute(test_step, test_orch)
  
  IO.puts "\n🔍 Detailed Result Analysis:"
  IO.puts "   Result keys: #{inspect(Map.keys(result))}"
  IO.puts "   Full result: #{inspect(result)}"
  
  if result[:text] do
    IO.puts "   Text length: #{String.length(result[:text])}"
    IO.puts "   Text content: '#{result[:text]}'"
  end
  
  if result[:success] do
    IO.puts "   Success: #{result[:success]}"
  end
  
  if result[:cost] do
    IO.puts "   Cost: $#{result[:cost]}"
  end
  
rescue
  error ->
    IO.puts "❌ Error: #{inspect(error)}"
end

IO.puts "\n🧪 Testing Raw SDK Response..."

try do
  # Test the raw SDK to see what messages we get (with default options)
  IO.puts "Raw SDK call with default options (nil)"
  stream = ClaudeCodeSDK.query("Say exactly: 'Raw SDK test!'")
  messages = Enum.to_list(stream)
  
  IO.puts "📦 Raw SDK Messages:"
  messages
  |> Enum.with_index()
  |> Enum.each(fn {msg, i} ->
    IO.puts "   [#{i}] Type: #{msg.type}, Subtype: #{inspect(msg.subtype)}"
    IO.puts "       Data keys: #{inspect(Map.keys(msg.data))}"
    
    if msg.type == :assistant do
      IO.puts "       Message: #{inspect(msg.data.message)}"
    end
    
    if msg.type == :result do
      IO.puts "       Result: #{inspect(msg.data)}"
    end
  end)
  
rescue
  error ->
    IO.puts "❌ Raw SDK Error: #{inspect(error)}"
end