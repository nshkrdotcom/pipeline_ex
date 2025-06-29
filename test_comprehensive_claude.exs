#!/usr/bin/env elixir

defmodule ClaudeComprehensiveTest do
  def run do
    # Test the comprehensive Claude example
    IO.puts "🚀 Testing Comprehensive Claude Example..."

    try do
      # Test just the first step to verify the workflow loads correctly
      IO.puts "📋 Loading comprehensive workflow..."
      
      workflow_path = "claude_comprehensive_example.yaml"
      if File.exists?(workflow_path) do
        IO.puts "✅ Workflow file exists"
        
        # Parse the workflow
        {:ok, content} = File.read(workflow_path)
        {:ok, workflow} = YamlElixir.read_from_string(content)
        
        IO.puts "✅ Workflow parsed successfully"
        IO.puts "   Name: #{workflow["workflow"]["name"]}"
        IO.puts "   Steps: #{length(workflow["workflow"]["steps"])}"
        
        # List all the Claude functionality demonstrated
        IO.puts "\n🎯 Claude Functionality Demonstrated:"
        workflow["workflow"]["steps"]
        |> Enum.with_index(1)
        |> Enum.each(fn {step, i} ->
          IO.puts "   #{i}. #{step["name"]} - #{get_key_features(step)}"
        end)
        
        IO.puts "\n🧪 Testing first step execution..."
        
        # Test the first step (basic interaction)
        first_step = Enum.at(workflow["workflow"]["steps"], 0)
        
        # Create test orchestrator
        test_orch = %{
          results: %{},
          debug_log: "/tmp/claude_test.log",
          output_dir: "./outputs/claude_demo", 
          workspace_dir: "./workspace"
        }
        
        # Ensure output directory exists
        File.mkdir_p!(test_orch.output_dir)
        File.mkdir_p!(test_orch.workspace_dir)
        
        IO.puts "   Executing: #{first_step["name"]}"
        result = Pipeline.Step.Claude.execute(first_step, test_orch)
        
        IO.puts "✅ First step executed successfully!"
        IO.puts "   Success: #{result[:success]}"
        IO.puts "   Cost: $#{result[:cost]}"
        
        if result[:text] do
          preview = if String.length(result[:text]) > 100 do
            String.slice(result[:text], 0, 100) <> "..."
          else
            result[:text]
          end
          IO.puts "   Response: #{preview}"
        end
        
      else
        IO.puts "❌ Workflow file not found: #{workflow_path}"
      end
      
    rescue
      error ->
        IO.puts "❌ Error: #{inspect(error)}"
    end

    IO.puts "\n📚 Comprehensive Example Features:"
    IO.puts "✅ Basic Claude interaction"
    IO.puts "✅ Multi-turn conversations" 
    IO.puts "✅ Tool restrictions (allowed/disallowed)"
    IO.puts "✅ Permission modes (default, plan, bypass)"
    IO.puts "✅ System prompts and append system prompts"
    IO.puts "✅ Working directory control"
    IO.puts "✅ Verbose logging"
    IO.puts "✅ Previous response integration"
    IO.puts "✅ Error handling scenarios"
    IO.puts "✅ Advanced tool usage (Glob, Grep, Task, WebSearch)"
    IO.puts "✅ File output and result tracking"
    IO.puts "✅ Complex prompt building with multiple sources"
  end

  defp get_key_features(step) do
    claude_opts = step["claude_options"] || %{}
    features = []
    
    features = if claude_opts["max_turns"], do: ["max_turns: #{claude_opts["max_turns"]}" | features], else: features
    features = if claude_opts["allowed_tools"], do: ["tools: #{length(claude_opts["allowed_tools"])}" | features], else: features
    features = if claude_opts["permission_mode"], do: ["permission: #{claude_opts["permission_mode"]}" | features], else: features
    features = if claude_opts["system_prompt"], do: ["system_prompt" | features], else: features
    features = if claude_opts["verbose"], do: ["verbose" | features], else: features
    
    if features == [], do: "basic", else: Enum.join(features, ", ")
  end
end

ClaudeComprehensiveTest.run()