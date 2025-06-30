#!/usr/bin/env elixir

# Quick test to demonstrate the Claude SDK parsing issue

Mix.install([
  {:claude_code_sdk, path: "/home/home/p/g/n/claude_code_sdk_elixir"},
  {:jason, "~> 1.4"}
])

IO.puts("🐛 Quick Claude SDK Parsing Issue Test")
IO.puts("=" |> String.duplicate(40))

prompt = "What is 2+2?"

# Show what Claude CLI returns for different formats
IO.puts("\n📋 Claude CLI outputs:")

IO.puts("  Text format:")
{text_output, _} = System.cmd("claude", ["--print", "--output-format", "text", "--max-turns", "1", prompt])
IO.puts("    Raw: #{inspect(text_output)}")
IO.puts("    Type: #{text_output |> String.trim() |> (&(if String.match?(&1, ~r/^\d+$/), do: "number", else: "text")).()}")

IO.puts("  JSON format:")
{json_output, _} = System.cmd("claude", ["--print", "--output-format", "json", "--max-turns", "1", prompt])
IO.puts("    Raw: #{inspect(String.slice(json_output, 0, 100))}")
case Jason.decode(json_output) do
  {:ok, json} -> IO.puts("    Parsed: #{inspect(Map.keys(json))}")
  {:error, e} -> IO.puts("    Parse error: #{inspect(e)}")
end

# Show the SDK parsing issue
IO.puts("\n🐛 SDK Parsing Test:")

IO.puts("  Text format (will fail):")
try do
  options = ClaudeCodeSDK.Options.new(max_turns: 1, output_format: :text, verbose: false)
  stream = ClaudeCodeSDK.query(prompt, options)
  [msg] = Enum.take(stream, 1)
  IO.puts("    ✅ Unexpected success: #{inspect(msg)}")
rescue
  error ->
    IO.puts("    ❌ Expected error: #{Exception.message(error)}")
    IO.puts("    🔍 Root cause: SDK tries to parse '4' (number) as JSON with Access.get(4.0, \"type\", nil)")
end

IO.puts("  JSON format (should work):")
try do
  options = ClaudeCodeSDK.Options.new(max_turns: 1, output_format: :json, verbose: false)
  stream = ClaudeCodeSDK.query(prompt, options)
  [msg] = Enum.take(stream, 1)
  IO.puts("    ✅ Success: #{inspect(msg.data.message["content"])}")
rescue
  error ->
    IO.puts("    ❌ Unexpected error: #{Exception.message(error)}")
end

IO.puts("\n💡 Conclusion:")
IO.puts("   The SDK parsing fails when output_format is :text because:")
IO.puts("   1. Claude CLI returns plain text: '4'")  
IO.puts("   2. SDK tries to parse it as JSON")
IO.puts("   3. Access.get(4.0, \"type\", nil) fails - number doesn't have 'type' key")
IO.puts("   4. Solution: SDK needs format-aware parsing logic")