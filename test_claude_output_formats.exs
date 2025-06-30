#!/usr/bin/env elixir

# Claude Code SDK Output Format Test
# This script tests all different output formats to identify parsing issues

Mix.install([
  {:claude_code_sdk, path: "/home/home/p/g/n/claude_code_sdk_elixir"},
  {:jason, "~> 1.4"}
])

defmodule ClaudeOutputFormatTest do
  @moduledoc """
  Comprehensive test of Claude Code SDK output format parsing issues
  """

  require Logger

  def run_test do
    IO.puts("🧪 Claude Code SDK Output Format Test")
    IO.puts("=" |> String.duplicate(60))
    
    # Check Claude CLI availability
    case System.find_executable("claude") do
      nil ->
        IO.puts("❌ Claude CLI not found")
        System.halt(1)
      claude_path ->
        IO.puts("✅ Claude CLI found at: #{claude_path}")
    end

    # Test all output formats
    test_formats = [
      # Basic formats
      %{name: "text", format: "text", description: "Plain text output"},
      %{name: "json", format: "json", description: "JSON structured output"},
      %{name: "stream_json", format: "stream_json", description: "Streaming JSON output"},
      
      # Advanced formats that might exist
      %{name: "markdown", format: "markdown", description: "Markdown formatted output"},
      %{name: "yaml", format: "yaml", description: "YAML structured output"},
      %{name: "xml", format: "xml", description: "XML structured output"},
    ]

    prompt = "What is 2+2? Answer with just the number."
    
    IO.puts("\n🔧 Testing Claude CLI direct calls with different formats...")
    test_claude_cli_formats(prompt, test_formats)
    
    IO.puts("\n🔧 Testing Claude SDK with different output formats...")
    test_sdk_formats(prompt, test_formats)
    
    IO.puts("\n🔧 Testing edge cases and problematic scenarios...")
    test_edge_cases()
    
    IO.puts("\n🔧 Testing with different prompt complexities...")
    test_prompt_variations()
  end

  defp test_claude_cli_formats(prompt, formats) do
    Enum.each(formats, fn %{name: name, format: format, description: description} ->
      IO.puts("\n  📋 Testing CLI format: #{name} (#{description})")
      
      args = [
        "--print",
        "--output-format", format,
        "--max-turns", "1",
        prompt
      ]
      
      IO.puts("    Command: claude #{Enum.join(args, " ")}")
      
      try do
        case System.cmd("claude", args, stderr_to_stdout: true) do
          {output, 0} ->
            IO.puts("    ✅ CLI succeeded")
            IO.puts("    📏 Output length: #{String.length(output)} characters")
            IO.puts("    📄 First 200 chars: #{String.slice(output, 0, 200)}")
            
            # Try to identify output structure
            analyze_output_structure(output, format)
            
          {error_output, exit_code} ->
            IO.puts("    ❌ CLI failed with exit code #{exit_code}")
            IO.puts("    📄 Error: #{String.slice(error_output, 0, 200)}")
        end
      rescue
        error ->
          IO.puts("    ❌ Exception: #{Exception.message(error)}")
      end
    end)
  end

  defp test_sdk_formats(prompt, formats) do
    # Test SDK with different output format options
    Enum.each(formats, fn %{name: name, format: format, description: description} ->
      IO.puts("\n  🔧 Testing SDK format: #{name} (#{description})")
      
      # Convert format string to atom for SDK
      format_atom = case format do
        "text" -> :text
        "json" -> :json
        "stream_json" -> :stream_json
        "markdown" -> :markdown
        "yaml" -> :yaml
        "xml" -> :xml
        _ -> String.to_atom(format)
      end
      
      try do
        options = ClaudeCodeSDK.Options.new(
          max_turns: 1,
          output_format: format_atom,
          verbose: false
        )
        
        IO.puts("    🎯 Options: #{inspect(options)}")
        
        # Try to create stream
        stream = ClaudeCodeSDK.query(prompt, options)
        IO.puts("    ✅ Stream created successfully")
        
        # Try to get first few messages
        IO.puts("    📤 Attempting to read messages...")
        messages = Enum.take(stream, 3)
        
        IO.puts("    ✅ Success! Got #{length(messages)} message(s)")
        
        messages
        |> Enum.with_index()
        |> Enum.each(fn {msg, idx} ->
          IO.puts("      📨 Message #{idx}: #{inspect(msg, limit: 3)}")
        end)
        
      rescue
        error ->
          IO.puts("    ❌ SDK Error: #{Exception.message(error)}")
          IO.puts("    📚 Error type: #{error.__struct__}")
          
          # Show relevant stacktrace
          stacktrace = __STACKTRACE__
          IO.puts("    📍 Stacktrace (first 3 lines):")
          stacktrace
          |> Enum.take(3)
          |> Enum.each(fn frame ->
            IO.puts("      #{Exception.format_stacktrace_entry(frame)}")
          end)
      end
    end)
  end

  defp test_edge_cases do
    edge_cases = [
      %{
        name: "empty_prompt",
        prompt: "",
        format: :text,
        description: "Empty prompt"
      },
      %{
        name: "very_long_prompt",
        prompt: String.duplicate("What is the meaning of life? ", 100),
        format: :json,
        description: "Very long prompt"
      },
      %{
        name: "unicode_prompt",
        prompt: "What is 🌟 + 🎯? Answer with emojis.",
        format: :text,
        description: "Unicode/emoji prompt"
      },
      %{
        name: "json_in_response",
        prompt: "Return this JSON: {\"answer\": 42, \"status\": \"ok\"}",
        format: :text,
        description: "JSON content in text format"
      },
      %{
        name: "multiline_response",
        prompt: "Write a haiku about programming.",
        format: :text,
        description: "Multiline response"
      },
      %{
        name: "special_characters",
        prompt: "What is 2+2? Include these: \"quotes\", 'apostrophes', and \\backslashes\\.",
        format: :json,
        description: "Special characters in response"
      }
    ]

    Enum.each(edge_cases, fn %{name: name, prompt: prompt, format: format, description: description} ->
      IO.puts("\n  🎯 Testing edge case: #{name} (#{description})")
      
      try do
        options = ClaudeCodeSDK.Options.new(
          max_turns: 1,
          output_format: format,
          verbose: false
        )
        
        stream = ClaudeCodeSDK.query(prompt, options)
        messages = Enum.take(stream, 2)
        
        IO.puts("    ✅ Success! Got #{length(messages)} message(s)")
        
        # Show first message content if available
        case messages do
          [first_msg | _] ->
            case first_msg do
              %{data: %{message: %{"content" => content}}} ->
                content_preview = String.slice(content, 0, 100)
                IO.puts("    📄 Content preview: #{content_preview}")
              _ ->
                IO.puts("    📄 Message structure: #{inspect(first_msg, limit: 2)}")
            end
          [] ->
            IO.puts("    📄 No messages received")
        end
        
      rescue
        error ->
          IO.puts("    ❌ Failed: #{Exception.message(error)}")
          IO.puts("    🔍 Error details: #{inspect(error, limit: 2)}")
      end
    end)
  end

  defp test_prompt_variations do
    prompt_tests = [
      %{
        name: "math_simple",
        prompt: "2+2=?",
        expected_response_type: "number"
      },
      %{
        name: "math_word_problem",
        prompt: "If I have 5 apples and eat 2, how many do I have left?",
        expected_response_type: "sentence"
      },
      %{
        name: "code_request",
        prompt: "Write a Python function that adds two numbers.",
        expected_response_type: "code"
      },
      %{
        name: "json_request",
        prompt: "Return a JSON object with name and age fields.",
        expected_response_type: "json"
      },
      %{
        name: "list_request",
        prompt: "List 3 programming languages.",
        expected_response_type: "list"
      }
    ]

    Enum.each(prompt_tests, fn %{name: name, prompt: prompt, expected_response_type: expected_type} ->
      IO.puts("\n  📝 Testing prompt type: #{name} (expecting #{expected_type})")
      
      # Test with both text and json formats
      formats_to_test = [:text, :json]
      
      Enum.each(formats_to_test, fn format ->
        IO.puts("    🎯 Format: #{format}")
        
        try do
          options = ClaudeCodeSDK.Options.new(
            max_turns: 1,
            output_format: format,
            verbose: false
          )
          
          stream = ClaudeCodeSDK.query(prompt, options)
          messages = Enum.take(stream, 1)
          
          case messages do
            [msg] ->
              IO.puts("      ✅ Got response")
              analyze_response_content(msg, expected_type)
            [] ->
              IO.puts("      ❌ No response received")
          end
          
        rescue
          error ->
            IO.puts("      ❌ Error: #{Exception.message(error)}")
        end
      end)
    end)
  end

  defp analyze_output_structure(output, format) do
    # Try to understand what the output looks like
    lines = String.split(output, "\n")
    non_empty_lines = Enum.filter(lines, &(String.trim(&1) != ""))
    
    IO.puts("    📊 Analysis:")
    IO.puts("      Total lines: #{length(lines)}")
    IO.puts("      Non-empty lines: #{length(non_empty_lines)}")
    
    # Check if it looks like JSON
    if format in ["json", "stream_json"] do
      Enum.each(non_empty_lines, fn line ->
        case Jason.decode(line) do
          {:ok, json} ->
            IO.puts("      ✅ Valid JSON line: #{inspect(Map.keys(json))}")
          {:error, _} ->
            IO.puts("      ❌ Invalid JSON line: #{String.slice(line, 0, 50)}")
        end
      end)
    else
      # For non-JSON formats, just show structure
      if length(non_empty_lines) > 0 do
        first_line = hd(non_empty_lines)
        IO.puts("      📄 First line type: #{classify_content(first_line)}")
      end
    end
  end

  defp analyze_response_content(msg, expected_type) do
    case msg do
      %{data: %{message: %{"content" => content}}} ->
        content_type = classify_content(content)
        match_result = if content_type == expected_type, do: "✅ matches", else: "❌ doesn't match"
        IO.puts("      📄 Content type: #{content_type} (#{match_result} expected #{expected_type})")
        IO.puts("      📄 Content preview: #{String.slice(content, 0, 80)}")
      _ ->
        IO.puts("      📄 Unexpected message structure: #{inspect(msg, limit: 2)}")
    end
  end

  defp classify_content(content) do
    content = String.trim(content)
    
    cond do
      # Check if it's a number
      String.match?(content, ~r/^\d+(\.\d+)?$/) ->
        "number"
        
      # Check if it's JSON
      String.starts_with?(content, "{") and String.ends_with?(content, "}") ->
        "json"
        
      # Check if it's code (contains common code patterns)
      String.contains?(content, "def ") or String.contains?(content, "function ") or 
      String.contains?(content, "```") ->
        "code"
        
      # Check if it's a list (contains bullet points or numbers)
      String.contains?(content, "\n- ") or String.contains?(content, "\n1. ") ->
        "list"
        
      # Check if it's a single sentence
      String.contains?(content, ".") and not String.contains?(content, "\n") ->
        "sentence"
        
      # Default
      true ->
        "text"
    end
  end
end

# Run the comprehensive test
ClaudeOutputFormatTest.run_test()