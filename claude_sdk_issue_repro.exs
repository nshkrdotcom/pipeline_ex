#!/usr/bin/env elixir

# Isolated test case to reproduce Claude SDK max_turns error issue
# Run with: elixir claude_sdk_issue_repro.exs

Mix.install([
  {:claude_code_sdk, github: "nshkrdotcom/claude_code_sdk_elixir", ref: "main", force: true}
])

defmodule ClaudeSDKIssueRepro do
  def test_max_turns_error do
    IO.puts("Testing Claude SDK max_turns error...")

    prompt = "Please list the files in the current directory and read the README.md file. Provide a brief summary."
    
    # This configuration should cause the max_turns error
    options = %ClaudeCodeSDK.Options{
      max_turns: 2,           # This is too low for the task
      verbose: true
    }

    IO.puts("Prompt: #{prompt}")
    IO.puts("Options: #{inspect(options)}")
    IO.puts("Starting query...")

    try do
      stream = ClaudeCodeSDK.query(prompt, options)
      messages = Enum.to_list(stream)

      IO.puts("Collected #{length(messages)} messages:")
      
      Enum.with_index(messages, 1)
      |> Enum.each(fn {msg, i} ->
        IO.puts("Message #{i}: type=#{msg.type}, subtype=#{inspect(msg.subtype)}")
        
        case msg.type do
          :result ->
            IO.puts("  Result data: #{inspect(msg.data, limit: 200)}")
            
            if msg.subtype == :error_max_turns do
              IO.puts("  ⚠️  MAX TURNS ERROR DETECTED!")
              
              # Check what error information is available
              error_info = cond do
                Map.has_key?(msg.data, :error) ->
                  "Error field: '#{msg.data.error}'"
                Map.has_key?(msg.data, :message) ->
                  "Message field: '#{msg.data.message}'"
                Map.has_key?(msg.data, :result) ->
                  "Result field: '#{msg.data.result}'"
                true ->
                  "No obvious error field, data: #{inspect(msg.data)}"
              end
              
              IO.puts("  Error info: #{error_info}")
            end
            
          :assistant ->
            if content = get_in(msg.data, [:message, "content"]) do
              IO.puts("  Content: #{inspect(content, limit: 100)}")
            end
            
          _ ->
            IO.puts("  Data keys: #{inspect(Map.keys(msg.data))}")
        end
      end)
      
    rescue
      error ->
        IO.puts("Exception during query: #{inspect(error)}")
    end
  end

  def test_with_higher_max_turns do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("Testing with higher max_turns to see if it works...")

    prompt = "List the files in the current directory."
    
    options = %ClaudeCodeSDK.Options{
      max_turns: 5,           # Higher limit
      verbose: true
    }

    IO.puts("Prompt: #{prompt}")
    IO.puts("Options: #{inspect(options)}")

    try do
      stream = ClaudeCodeSDK.query(prompt, options)
      messages = Enum.to_list(stream)

      IO.puts("Collected #{length(messages)} messages")
      
      result_msg = Enum.find(messages, fn msg -> msg.type == :result end)
      if result_msg do
        IO.puts("Result: type=#{result_msg.type}, subtype=#{inspect(result_msg.subtype)}")
        if result_msg.subtype == :success do
          IO.puts("✅ SUCCESS with higher max_turns!")
        else
          IO.puts("❌ Still failed with subtype: #{result_msg.subtype}")
        end
      else
        IO.puts("❌ No result message found")
      end
      
    rescue
      error ->
        IO.puts("Exception: #{inspect(error)}")
    end
  end
end

# Run the tests
ClaudeSDKIssueRepro.test_max_turns_error()
ClaudeSDKIssueRepro.test_with_higher_max_turns()

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("ISSUE SUMMARY:")
IO.puts("The Claude SDK returns result:error_max_turns when max_turns is too low")
IO.puts("for the requested task, but the error field appears to be empty.")
IO.puts("This makes it hard to provide meaningful error messages to users.")