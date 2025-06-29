#!/usr/bin/env elixir

# Simple Claude SDK test
IO.puts "🤖 Testing Claude SDK Integration..."

try do
  # Test basic SDK functionality
  result = ClaudeCodeSDK.query("Say exactly: 'Claude SDK working!'")
  |> Enum.to_list()
  
  IO.puts "✅ SDK query executed successfully"
  IO.puts "   Received #{length(result)} messages"
  
  # Show message types
  result
  |> Enum.each(fn msg ->
    IO.puts "   #{msg.type}: #{inspect(msg.subtype)}"
  end)
  
  # Extract assistant response
  assistant_msg = Enum.find(result, &(&1.type == :assistant))
  if assistant_msg do
    content = case assistant_msg.data.message do
      %{"content" => text} when is_binary(text) -> text
      %{"content" => [%{"text" => text}]} -> text
      _ -> inspect(assistant_msg.data.message)
    end
    IO.puts "   Claude said: #{content}"
  end
  
  # Check result
  result_msg = Enum.find(result, &(&1.type == :result))
  if result_msg && result_msg.subtype == :success do
    IO.puts "✅ SUCCESS! Cost: $#{result_msg.data.total_cost_usd}"
  end
  
rescue
  error ->
    IO.puts "❌ Error: #{inspect(error)}"
end

IO.puts "\n🧪 Testing Pipeline Step Integration..."

try do
  # Test the pipeline step
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
  
  result = Pipeline.Step.Claude.execute(test_step, test_orch)
  
  IO.puts "✅ Pipeline step executed"
  IO.puts "   Success: #{result[:success]}"
  IO.puts "   Response: #{String.slice(result[:text] || "", 0, 100)}"
  
rescue
  error ->
    IO.puts "❌ Pipeline step error: #{inspect(error)}"
end

IO.puts "\n🎉 Claude SDK Integration Test Complete!"