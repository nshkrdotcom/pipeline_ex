#!/usr/bin/env elixir

# Focused test to reproduce the Claude SDK parsing issue

Mix.install([
  {:claude_code_sdk, path: "/home/home/p/g/n/claude_code_sdk_elixir"},
  {:jason, "~> 1.4"}
])

defmodule ClaudeParsingIssueTest do
  @moduledoc """
  Focused test to reproduce and analyze the Claude SDK parsing issue
  """

  def run_test do
    IO.puts("🐛 Claude SDK Parsing Issue Reproduction Test")
    IO.puts("=" |> String.duplicate(50))
    
    prompt = "What is 2+2? Answer with just the number."
    
    # Test 1: Show what Claude CLI outputs for different formats
    IO.puts("\n1️⃣ Testing Claude CLI output formats directly:")
    test_cli_outputs(prompt)
    
    # Test 2: Show what causes the SDK parsing error
    IO.puts("\n2️⃣ Testing SDK parsing with problematic formats:")
    test_sdk_parsing_issues(prompt)
    
    # Test 3: Show which formats work
    IO.puts("\n3️⃣ Testing SDK with working formats:")
    test_working_formats(prompt)
  end

  defp test_cli_outputs(prompt) do
    formats = [
      {"text", "Plain text - causes parsing error"},
      {"json", "JSON format - should work"},
      {"stream_json", "Streaming JSON - might work"}
    ]
    
    Enum.each(formats, fn {format, description} ->
      IO.puts("\n  📋 Format: #{format} (#{description})")
      
      args = ["--print", "--output-format", format, "--max-turns", "1", prompt]
      
      case System.cmd("claude", args, stderr_to_stdout: true) do
        {output, 0} ->
          IO.puts("    ✅ CLI Success")
          IO.puts("    📄 Raw output: #{inspect(output)}")
          IO.puts("    📏 Length: #{String.length(output)} chars")
          
          # Try to parse as JSON to see what happens
          case Jason.decode(output) do
            {:ok, json} ->
              IO.puts("    ✅ Valid JSON: #{inspect(json)}")
            {:error, reason} ->
              IO.puts("    ❌ Invalid JSON: #{inspect(reason)}")
          end
          
        {error, code} ->
          IO.puts("    ❌ CLI Error (#{code}): #{error}")
      end
    end)
  end

  defp test_sdk_parsing_issues(prompt) do
    # These are the formats that cause parsing errors
    problematic_formats = [
      {:text, "Text format - tries to parse '4' as JSON"},
      {:markdown, "Markdown format - if it exists"},
    ]
    
    Enum.each(problematic_formats, fn {format, description} ->
      IO.puts("\n  🐛 Testing: #{format} (#{description})")
      
      try do
        options = ClaudeCodeSDK.Options.new(
          max_turns: 1,
          output_format: format,
          verbose: false
        )
        
        IO.puts("    🎯 Creating stream...")
        stream = ClaudeCodeSDK.query(prompt, options)
        
        IO.puts("    🎯 Attempting to read first message...")
        [first_message] = Enum.take(stream, 1)
        
        IO.puts("    ✅ Unexpected success: #{inspect(first_message)}")
        
      rescue
        error ->
          IO.puts("    ❌ Expected error: #{Exception.message(error)}")
          IO.puts("    🔍 Error type: #{error.__struct__}")
          
          # Show the specific line that fails
          case error do
            %FunctionClauseError{} ->
              IO.puts("    💥 Function clause error - likely Access.get/3 with wrong type")
            _ ->
              IO.puts("    💥 Other error type")
          end
      end
    end)
  end

  defp test_working_formats(prompt) do
    # These formats should work (or at least not cause parsing errors)
    working_formats = [
      {:json, "JSON format - should work correctly"},
      {:stream_json, "Stream JSON - might work"},
    ]
    
    Enum.each(working_formats, fn {format, description} ->
      IO.puts("\n  ✅ Testing: #{format} (#{description})")
      
      try do
        options = ClaudeCodeSDK.Options.new(
          max_turns: 1,
          output_format: format,
          verbose: false
        )
        
        IO.puts("    🎯 Creating stream...")
        stream = ClaudeCodeSDK.query(prompt, options)
        
        IO.puts("    🎯 Reading messages...")
        messages = Enum.take(stream, 2)
        
        IO.puts("    ✅ Success! Got #{length(messages)} message(s)")
        
        Enum.each(messages, fn msg ->
          case msg do
            %{data: %{message: %{"content" => content}}} ->
              IO.puts("    📄 Content: #{inspect(content)}")
            _ ->
              IO.puts("    📄 Message: #{inspect(msg, limit: 2)}")
          end
        end)
        
      rescue
        error ->
          IO.puts("    ❌ Unexpected error: #{Exception.message(error)}")
      end
    end)
  end
end

# Run the focused test
ClaudeParsingIssueTest.run_test()