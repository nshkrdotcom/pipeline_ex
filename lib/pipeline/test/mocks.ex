defmodule Pipeline.Test.Mocks do
  @moduledoc """
  Mock implementations for testing pipeline components without external dependencies.
  """

  defmodule GeminiMock do
    @moduledoc """
    Mock implementation of Gemini AI provider for testing.
    """
    
    @behaviour Pipeline.Test.AIProvider
    
    @impl true
    def generate(prompt, opts \\ []) do
      # Return predictable responses based on prompt patterns
      cond do
        String.contains?(prompt, "analyze") or String.contains?(prompt, "review") ->
          {:ok, %{
            "analysis" => "Code review completed",
            "issues" => ["Missing error handling", "Needs optimization"],
            "quality_score" => 7,
            "needs_fixes" => true,
            "recommendations" => ["Add tests", "Improve documentation"]
          }}
          
        String.contains?(prompt, "plan") or String.contains?(prompt, "design") ->
          {:ok, %{
            "plan" => "Implementation plan created",
            "steps" => [
              "Setup project structure",
              "Implement core functionality", 
              "Add tests",
              "Documentation"
            ],
            "estimated_time" => "4 hours",
            "priority" => "high"
          }}
          
        String.contains?(prompt, "function") and opts[:functions] ->
          {:ok, %{
            "function_call" => %{
              "name" => "evaluate_code",
              "arguments" => %{
                "quality_score" => 8,
                "security_issues" => [],
                "needs_refactoring" => false
              }
            }
          }}
          
        String.contains?(prompt, "error") or String.contains?(prompt, "fail") ->
          {:error, "Simulated API failure"}
          
        true ->
          {:ok, %{
            "response" => "Mock response for: #{String.slice(prompt, 0, 50)}...",
            "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "model" => opts[:model] || "gemini-mock",
            "tokens_used" => 150
          }}
      end
    end
  end

  defmodule ClaudeSDKMock do
    @moduledoc """
    Mock implementation of Claude Code SDK for testing.
    """
    
    @behaviour Pipeline.Test.ClaudeProvider
    
    @impl true
    def query(prompt, options) do
      # Return a stream of mock messages based on prompt and options
      messages = generate_mock_messages(prompt, options)
      Stream.cycle([messages]) |> Stream.take(1) |> Stream.flat_map(&Function.identity/1)
    end
    
    defp generate_mock_messages(prompt, options) do
      base_messages = [
        %{
          type: "message",
          content: "Starting task: #{String.slice(prompt, 0, 30)}...",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]
      
      task_messages = cond do
        String.contains?(prompt, "write") or String.contains?(prompt, "create") ->
          [
            %{
              type: "tool_use",
              content: "Writing file: example.txt",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            },
            %{
              type: "tool_result", 
              content: "File created successfully",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            }
          ]
          
        String.contains?(prompt, "implement") ->
          [
            %{
              type: "thinking",
              content: "Planning implementation approach...",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            },
            %{
              type: "tool_use",
              content: "Creating implementation files",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            }
          ]
          
        String.contains?(prompt, "test") ->
          [
            %{
              type: "tool_use",
              content: "Running tests...",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            },
            %{
              type: "tool_result",
              content: "All tests passed ✓",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            }
          ]
          
        true ->
          [
            %{
              type: "response",
              content: "Task completed successfully",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            }
          ]
      end
      
      result_message = case options.output_format do
        :json ->
          %{
            type: "result",
            content: Jason.encode!(%{
              "status" => "completed",
              "files_created" => ["example.txt", "implementation.py"],
              "summary" => "Mock task execution completed",
              "working_directory" => options.cwd || "./workspace"
            }),
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
          
        _ ->
          %{
            type: "result",
            content: "Task completed successfully. Created files in workspace.",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
      end
      
      base_messages ++ task_messages ++ [result_message]
    end
  end

  defmodule FileMock do
    @moduledoc """
    Mock implementation of file system operations for testing.
    """
    
    @behaviour Pipeline.Test.FileSystem
    
    # Store mock file system state in process dictionary
    defp get_fs_state do
      Process.get(:mock_fs, %{})
    end
    
    defp put_fs_state(state) do
      Process.put(:mock_fs, state)
    end
    
    @impl true
    def read(path) do
      state = get_fs_state()
      case Map.get(state, path) do
        nil -> {:error, :enoent}
        content -> {:ok, content}
      end
    end
    
    @impl true
    def write(path, content) do
      state = get_fs_state()
      new_state = Map.put(state, path, content)
      put_fs_state(new_state)
      :ok
    end
    
    @impl true
    def mkdir_p(_path) do
      # Mock always succeeds
      :ok
    end
    
    @impl true
    def exists?(path) do
      state = get_fs_state()
      Map.has_key?(state, path)
    end
    
    @impl true
    def ls(path) do
      state = get_fs_state()
      files = state
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, path))
      |> Enum.map(&Path.basename/1)
      |> Enum.uniq()
      
      {:ok, files}
    end
    
    @doc "Reset the mock file system state (useful for tests)"
    def reset do
      Process.delete(:mock_fs)
      :ok
    end
    
    @doc "Set a file in the mock file system"
    def set_file(path, content) do
      write(path, content)
    end
    
    @doc "Get current mock file system state"
    def get_state do
      get_fs_state()
    end
  end

  defmodule LoggerMock do
    @moduledoc """
    Mock implementation of Logger for testing.
    """
    
    @behaviour Pipeline.Test.Logger
    
    # Store log messages in process dictionary
    defp get_logs do
      Process.get(:mock_logs, [])
    end
    
    defp add_log(level, message) do
      logs = get_logs()
      new_log = %{
        level: level,
        message: message,
        timestamp: DateTime.utc_now()
      }
      Process.put(:mock_logs, [new_log | logs])
    end
    
    @impl true
    def info(message) do
      add_log(:info, message)
      :ok
    end
    
    @impl true
    def debug(message) do
      add_log(:debug, message)
      :ok
    end
    
    @impl true
    def error(message) do
      add_log(:error, message)
      :ok
    end
    
    @impl true
    def warn(message) do
      add_log(:warn, message)
      :ok
    end
    
    @doc "Get all logged messages"
    def get_all_logs do
      get_logs() |> Enum.reverse()
    end
    
    @doc "Reset logged messages"
    def reset do
      Process.delete(:mock_logs)
      :ok
    end
    
    @doc "Get logs by level"
    def get_logs_by_level(level) do
      get_all_logs()
      |> Enum.filter(&(&1.level == level))
    end
  end
end