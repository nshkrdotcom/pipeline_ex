defmodule Mix.Tasks.Pipeline.Test.Live do
  @moduledoc """
  Runs Pipeline tests in live mode with real API calls.

  ## Usage

      mix pipeline.test.live            # Run all tests with live APIs
      mix pipeline.test.live integration # Run only integration tests with live APIs

  ⚠️ This will make real API calls and incur costs!
  """
  use Mix.Task

  @shortdoc "Run Pipeline tests with live API calls (costs money!)"

  def run(args) do
    # Set live mode BEFORE running tests
    System.put_env("TEST_MODE", "live")

    IO.puts("🚀 RUNNING TESTS IN LIVE MODE")
    IO.puts("⚠️  This will make real API calls and cost money!")
    IO.puts("")

    # Check authentication
    unless check_authentication() do
      IO.puts("❌ Authentication not ready for live mode")
      System.halt(1)
    end

    IO.puts("✅ Authentication ready")
    IO.puts("🎯 Running integration tests with live APIs...")
    IO.puts("")

    # Filter out Mix-specific args and add our own
    filtered_args =
      Enum.reject(args, fn arg ->
        String.starts_with?(arg, "--") and arg in ["--no-start", "--start"]
      end)

    # Run integration tests only - they're designed to work with live APIs
    test_args =
      if length(filtered_args) > 0 do
        filtered_args
      else
        ["--only", "integration"]
      end

    Mix.Task.run("test", test_args)
  end

  defp check_authentication do
    claude_ok = System.find_executable("claude") != nil
    gemini_ok = System.get_env("GEMINI_API_KEY") != nil

    unless claude_ok do
      IO.puts("❌ Claude CLI not found")
      IO.puts("   Install: npm install -g @anthropic-ai/claude-code")
      IO.puts("   Authenticate: claude login")
    end

    unless gemini_ok do
      IO.puts("❌ GEMINI_API_KEY not set")
      IO.puts("   Get key: https://aistudio.google.com/app/apikey")
      IO.puts("   Set: export GEMINI_API_KEY=\"your_key\"")
    end

    claude_ok and gemini_ok
  end
end
