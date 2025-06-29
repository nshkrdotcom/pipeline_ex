#!/usr/bin/env elixir

# Demo script showing different execution modes
Mix.install([
  {:pipeline, path: "."}
])

defmodule ModesDemo do
  def run do
    IO.puts("🎯 Pipeline Modes Demonstration")
    IO.puts("=" |> String.duplicate(50))
    
    # Demo mock mode
    demo_mock_mode()
    
    IO.puts("\n" <> "=" |> String.duplicate(50))
    
    # Demo live mode (if APIs available)
    demo_live_mode()
  end
  
  defp demo_mock_mode do
    IO.puts("\n🎭 MOCK MODE - Fast, no API costs")
    IO.puts("-" |> String.duplicate(30))
    
    # Force mock mode
    System.put_env("TEST_MODE", "mock")
    
    config_file = "test_simple_workflow.yaml"
    {:ok, config} = Pipeline.Config.load_workflow(config_file)
    
    start_time = System.monotonic_time(:millisecond)
    
    case Pipeline.Executor.execute(config, output_dir: "outputs/demo_mock") do
      {:ok, results} ->
        duration = System.monotonic_time(:millisecond) - start_time
        
        IO.puts("✅ Mock pipeline completed in #{duration}ms")
        IO.puts("📊 Results:")
        
        Enum.each(results, fn {step_name, result} ->
          content = extract_content(result)
          IO.puts("  • #{step_name}: #{String.slice(content, 0, 100)}...")
        end)
        
      {:error, reason} ->
        IO.puts("❌ Mock pipeline failed: #{reason}")
    end
  end
  
  defp demo_live_mode do
    IO.puts("\n🚀 LIVE MODE - Real AI APIs")
    IO.puts("-" |> String.duplicate(30))
    
    # Check if APIs are available
    claude_available = System.find_executable("claude") != nil
    gemini_available = System.get_env("GEMINI_API_KEY") != nil
    
    cond do
      claude_available and gemini_available ->
        run_live_demo()
        
      claude_available ->
        IO.puts("⚠️  Claude available, but GEMINI_API_KEY not set")
        IO.puts("   Set GEMINI_API_KEY to test live Gemini integration")
        run_claude_only_demo()
        
      gemini_available ->
        IO.puts("⚠️  Gemini API key available, but Claude CLI not found")
        IO.puts("   Run 'claude login' to test live Claude integration")
        
      true ->
        IO.puts("⚠️  No live APIs available")
        IO.puts("   • Run 'claude login' for Claude")
        IO.puts("   • Set GEMINI_API_KEY for Gemini")
        IO.puts("   • Then run: elixir demo_modes.exs")
    end
  end
  
  defp run_live_demo do
    # Set live mode
    System.delete_env("TEST_MODE")
    
    config_file = "test_simple_workflow.yaml"
    {:ok, config} = Pipeline.Config.load_workflow(config_file)
    
    IO.puts("🔄 Running live pipeline (this may take 10-30 seconds)...")
    start_time = System.monotonic_time(:millisecond)
    
    case Pipeline.Executor.execute(config, output_dir: "outputs/demo_live") do
      {:ok, results} ->
        duration = System.monotonic_time(:millisecond) - start_time
        
        IO.puts("✅ Live pipeline completed in #{duration}ms")
        IO.puts("📊 Results:")
        
        Enum.each(results, fn {step_name, result} ->
          content = extract_content(result)
          IO.puts("  • #{step_name}: #{String.slice(content, 0, 200)}...")
        end)
        
      {:error, reason} ->
        IO.puts("❌ Live pipeline failed: #{reason}")
    end
  end
  
  defp run_claude_only_demo do
    IO.puts("🔄 Testing Claude only...")
    # Implementation for Claude-only demo
    IO.puts("   (Claude-only demo would go here)")
  end
  
  defp extract_content(result) do
    cond do
      is_map(result) and Map.has_key?(result, :content) -> result.content
      is_map(result) and Map.has_key?(result, "content") -> result["content"]
      is_map(result) and Map.has_key?(result, :text) -> result.text
      is_map(result) and Map.has_key?(result, "text") -> result["text"]
      is_binary(result) -> result
      true -> inspect(result)
    end
  end
end

# Run the demo
ModesDemo.run()