#!/usr/bin/env elixir

# Test script to directly test the ClaudeCodeSDK
Mix.install([
  {:claude_code_sdk, git: "https://github.com/nshkrdotcom/claude_code_sdk_elixir.git", branch: "main"},
  {:jason, "~> 1.4"}
])

IO.puts("Testing ClaudeCodeSDK directly...")

# Simple test prompt
prompt = "What is 2+2?"
options = ClaudeCodeSDK.Options.new(
  max_turns: 1,
  verbose: true
)

IO.puts("Prompt: #{prompt}")
IO.puts("Options: #{inspect(options)}")

try do
  stream = ClaudeCodeSDK.query(prompt, options)
  messages = Enum.to_list(stream)
  
  IO.puts("\nMessages received:")
  Enum.each(messages, fn msg ->
    IO.puts("Type: #{msg.type}, Subtype: #{msg.subtype}")
    IO.puts("Data: #{inspect(msg.data, limit: :infinity)}")
    IO.puts("---")
  end)
  
rescue
  error ->
    IO.puts("Error: #{inspect(error)}")
end
