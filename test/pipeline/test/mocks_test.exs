defmodule Pipeline.Test.MocksTest do
  @moduledoc """
  Test the mock system to ensure it works correctly.
  """
  
  use Pipeline.TestCase
  
  alias Pipeline.Test.Mocks.{GeminiMock, ClaudeSDKMock, FileMock, LoggerMock}
  
  describe "GeminiMock" do
    test "returns analysis response for analyze prompts" do
      {:ok, response} = GeminiMock.generate("Please analyze this code", [])
      
      assert response["analysis"] == "Code review completed"
      assert response["needs_fixes"] == true
      assert is_list(response["issues"])
    end
    
    test "returns plan response for planning prompts" do
      {:ok, response} = GeminiMock.generate("Create a plan for implementation", [])
      
      assert response["plan"] == "Implementation plan created"
      assert is_list(response["steps"])
      assert response["priority"] == "high"
    end
    
    test "returns error for error prompts" do
      {:error, message} = GeminiMock.generate("This should fail", [])
      
      assert message == "Simulated API failure"
    end
    
    test "returns generic response for other prompts" do
      {:ok, response} = GeminiMock.generate("Some other prompt", model: "test-model")
      
      assert String.contains?(response["response"], "Mock response")
      assert response["model"] == "test-model"
      assert response["tokens_used"] == 150
    end
  end
  
  describe "ClaudeSDKMock" do
    test "returns message stream for basic prompts" do
      options = %ClaudeCodeSDK.Options{output_format: :json}
      messages = ClaudeSDKMock.query("Test prompt", options)
      |> Enum.to_list()
      
      assert length(messages) >= 2
      
      first_message = List.first(messages)
      assert first_message.type == "message"
      assert String.contains?(first_message.content, "Starting task")
      
      last_message = List.last(messages)
      assert last_message.type == "result"
    end
    
    test "returns JSON result for json output format" do
      options = %ClaudeCodeSDK.Options{output_format: :json}
      messages = ClaudeSDKMock.query("write a file", options)
      |> Enum.to_list()
      
      result_message = List.last(messages)
      assert result_message.type == "result"
      
      result_data = Jason.decode!(result_message.content)
      assert result_data["status"] == "completed"
      assert is_list(result_data["files_created"])
    end
  end
  
  describe "FileMock" do
    setup do
      FileMock.reset()
      :ok
    end
    
    test "stores and retrieves files" do
      # Initially file doesn't exist
      refute FileMock.exists?("test.txt")
      assert {:error, :enoent} = FileMock.read("test.txt")
      
      # Write file
      :ok = FileMock.write("test.txt", "Hello World")
      
      # Now file exists and can be read
      assert FileMock.exists?("test.txt")
      assert {:ok, "Hello World"} = FileMock.read("test.txt")
    end
    
    test "lists files in directory" do
      FileMock.write("/tmp/file1.txt", "content1")
      FileMock.write("/tmp/file2.txt", "content2")
      
      {:ok, files} = FileMock.ls("/tmp")
      assert "file1.txt" in files
      assert "file2.txt" in files
    end
    
    test "mkdir_p always succeeds" do
      assert :ok = FileMock.mkdir_p("/some/deep/path")
    end
    
    test "reset clears all files" do
      FileMock.write("test.txt", "content")
      assert FileMock.exists?("test.txt")
      
      FileMock.reset()
      refute FileMock.exists?("test.txt")
    end
  end
  
  describe "LoggerMock" do
    setup do
      LoggerMock.reset()
      :ok
    end
    
    test "captures log messages by level" do
      LoggerMock.info("Info message")
      LoggerMock.error("Error message")
      LoggerMock.debug("Debug message")
      
      all_logs = LoggerMock.get_all_logs()
      assert length(all_logs) == 3
      
      info_logs = LoggerMock.get_logs_by_level(:info)
      assert length(info_logs) == 1
      assert List.first(info_logs).message == "Info message"
      
      error_logs = LoggerMock.get_logs_by_level(:error)
      assert length(error_logs) == 1
      assert List.first(error_logs).message == "Error message"
    end
    
    test "log entries have timestamps" do
      LoggerMock.info("Test message")
      
      logs = LoggerMock.get_all_logs()
      log = List.first(logs)
      
      assert %DateTime{} = log.timestamp
      assert log.level == :info
      assert log.message == "Test message"
    end
    
    test "reset clears all logs" do
      LoggerMock.info("Test message")
      assert length(LoggerMock.get_all_logs()) == 1
      
      LoggerMock.reset()
      assert length(LoggerMock.get_all_logs()) == 0
    end
  end
end