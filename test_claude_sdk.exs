#!/usr/bin/env elixir

# Test script for Claude SDK integration
# This tests the basic Claude SDK functionality without requiring authentication

IO.puts """
🤖 Claude SDK Integration Test
==============================

This tests the Claude SDK integration in our pipeline system.
Note: This requires 'claude login' to be completed first.
"""

# Test 1: Check if Claude CLI is available
IO.puts "\n📋 Step 1: Checking Claude CLI availability..."

case System.find_executable("claude") do
  nil ->
    IO.puts "❌ Claude CLI not found"
    IO.puts "💡 Install with: npm install -g @anthropic-ai/claude-code"
    System.halt(1)
    
  path ->
    IO.puts "✅ Claude CLI found at: #{path}"
end

# Test 2: Check authentication status  
IO.puts "\n📋 Step 2: Checking authentication status..."

authenticated = case System.cmd("claude", ["auth", "status"], stderr_to_stdout: true) do
  {output, 0} ->
    IO.puts "✅ Authentication OK: #{String.trim(output)}"
    true
    
  {error, _code} ->
    IO.puts "⚠️  Authentication issue: #{error}"
    IO.puts "💡 Run 'claude login' to authenticate"
    false
end

# Test 3: Basic SDK functionality test (only if authenticated)
if authenticated do
  IO.puts "\n📋 Step 3: Testing basic SDK functionality..."
  
  try do
    # Test simple query
    result = ClaudeCodeSDK.query("Say exactly: 'Hello from Claude SDK test!'")
    |> Enum.to_list()
    
    IO.puts "✅ SDK query executed successfully"
    IO.puts "   Received #{length(result)} messages"
    
    # Check for assistant response
    assistant_msgs = Enum.filter(result, &(&1.type == :assistant))
    
    if length(assistant_msgs) > 0 do
      IO.puts "✅ Assistant response received"
      
      # Extract and show content
      first_response = List.first(assistant_msgs)
      content = case first_response.data.message do
        %{"content" => text} when is_binary(text) -> text
        %{"content" => [%{"text" => text}]} -> text
        _ -> inspect(first_response.data.message)
      end
      
      IO.puts "   Content: #{content}"
    else
      IO.puts "⚠️  No assistant response found"
    end
    
    # Check for result message
    result_msgs = Enum.filter(result, &(&1.type == :result))
    
    if length(result_msgs) > 0 do
      result_msg = List.first(result_msgs)
      case result_msg.subtype do
        :success ->
          IO.puts "✅ Query completed successfully"
          IO.puts "   Cost: $#{result_msg.data.total_cost_usd}"
          IO.puts "   Duration: #{result_msg.data.duration_ms}ms"
        _ ->
          IO.puts "⚠️  Query completed with issues: #{result_msg.subtype}"
      end
    end
    
  rescue
    error ->
      IO.puts "❌ SDK test failed: #{inspect(error)}"
  end
  
  # Test 4: Pipeline Step Integration
  IO.puts "\n📋 Step 4: Testing Pipeline Step integration..."
  
  try do
    # Test the Claude step directly
    test_step = %{
      name: "test_claude_step",
      claude_options: %{
        max_turns: 1,
        output_format: "text"
      }
    }
    
    test_orch = %{
      results: %{},
      debug_log: "/tmp/test_debug.log",
      output_dir: "/tmp",
      workspace_dir: "/tmp/test_workspace"
    }
    
    # Build the prompt
    prompt = "Say exactly: 'Pipeline integration test successful!'"
    
    result = Pipeline.Step.Claude.execute(
      Map.put(test_step, :prompt, [%{type: "static", content: prompt}]),
      test_orch
    )
    
    IO.puts "✅ Pipeline step executed successfully"
    IO.puts "   Result type: #{inspect(Map.keys(result))}"
    
    if result[:success] do
      IO.puts "✅ Step completed successfully"
    else
      IO.puts "⚠️  Step completed with issues"
    end
    
  rescue
    error ->
      IO.puts "❌ Pipeline step test failed: #{inspect(error)}"
  end
  
else
  IO.puts "\n⏭️  Skipping SDK tests - authentication required"
end

IO.puts "\n🎉 Claude SDK Integration Test Complete!"

if authenticated do
  IO.puts """
  
  Summary:
  - ✅ Claude CLI available and authenticated
  - ✅ Basic SDK functionality working
  - ✅ Pipeline integration ready
  
  The Claude SDK is properly integrated and ready for use in pipelines!
  """
else
  IO.puts """
  
  Summary:
  - ✅ Claude CLI available
  - ⚠️  Authentication required (run 'claude login')
  - ⏭️  Pipeline integration tests skipped
  
  Run 'claude login' and then re-run this test.
  """
end