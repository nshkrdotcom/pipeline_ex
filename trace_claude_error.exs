#!/usr/bin/env elixir

# Trace Claude error step by step
IO.puts "🔍 Tracing Claude Error Step by Step..."

try do
  # Step 1: Create the step and orch data
  test_step = %{
    name: "test_step",
    prompt: [%{type: "static", content: "Say: 'Test'"}],
    claude_options: %{max_turns: 1, output_format: "text"}
  }
  
  test_orch = %{
    results: %{},
    debug_log: "/tmp/test.log", 
    output_dir: "/tmp",
    workspace_dir: "/tmp"
  }
  
  IO.puts "✅ Step 1: Created test data"
  
  # Step 2: Build prompt
  prompt = Pipeline.PromptBuilder.build(test_step[:prompt], test_orch.results)
  IO.puts "✅ Step 2: Built prompt: #{inspect(prompt)}"
  
  # Step 3: Build Claude options (this is where the issue might be)
  IO.puts "🔧 Step 3: Building Claude options..."
  IO.puts "   Input claude_options: #{inspect(test_step[:claude_options])}"
  
  # Let's call the private function manually by copying the logic
  claude_opts = test_step[:claude_options]
  
  # Start with default options
  opts = %ClaudeCodeSDK.Options{}
  IO.puts "   Default opts struct: #{inspect(opts)}"
  
  # Handle working directory first
  cwd = case claude_opts["cwd"] || claude_opts[:cwd] do
    nil -> test_orch.workspace_dir
    relative_path ->
      Path.join(test_orch.workspace_dir, relative_path)
      |> Path.expand()
  end
  
  IO.puts "   Working directory: #{cwd}"
  File.mkdir_p!(cwd)
  
  # Build final options
  final_opts = %ClaudeCodeSDK.Options{
    max_turns: claude_opts["max_turns"] || claude_opts[:max_turns],
    output_format: case claude_opts["output_format"] || claude_opts[:output_format] do
      nil -> :text
      "json" -> :json
      "text" -> :text
      "stream-json" -> :stream_json
      "stream_json" -> :stream_json
      _ -> :text
    end,
    cwd: cwd
  }
  
  IO.puts "✅ Step 3: Built final options: #{inspect(final_opts)}"
  
  # Step 4: Test accessing the struct fields
  IO.puts "🔧 Step 4: Testing struct field access..."
  IO.puts "   max_turns: #{final_opts.max_turns}"
  IO.puts "   output_format: #{final_opts.output_format}"
  IO.puts "   cwd: #{final_opts.cwd}"
  
  # Step 5: Try calling ClaudeCodeSDK.query with our options
  IO.puts "🔧 Step 5: Testing ClaudeCodeSDK.query..."
  stream = ClaudeCodeSDK.query(prompt, final_opts)
  IO.puts "   Created stream: #{inspect(stream)}"
  
  # Try to consume one message
  first_msg = Enum.take(stream, 1)
  IO.puts "✅ Step 5: Got first message: #{inspect(first_msg)}"
  
rescue
  error ->
    IO.puts "❌ Error at step: #{inspect(error)}"
    IO.puts "❌ Error details: #{inspect(Exception.format(:error, error, __STACKTRACE__))}"
end