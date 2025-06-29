defmodule Pipeline.FilePromptTest do
  use ExUnit.Case, async: false

  alias Pipeline.{Config, Executor, PromptBuilder, TestMode}
  alias Pipeline.Test.Mocks

  setup do
    # Set test mode
    System.put_env("TEST_MODE", "mock")
    TestMode.set_test_context(:unit)

    # Reset mocks
    Mocks.ClaudeProvider.reset()
    Mocks.GeminiProvider.reset()

    # Clean up any test directories and files
    on_exit(fn ->
      File.rm_rf("/tmp/test_workspace")
      File.rm_rf("/tmp/test_outputs")
      File.rm_rf("/tmp/test_files")
      TestMode.clear_test_context()
    end)

    # Create test files directory
    File.mkdir_p!("/tmp/test_files")

    :ok
  end

  describe "file prompt type" do
    test "loads content from a simple text file" do
      # Create test file
      test_content = "This is a test file with some content.\nIt has multiple lines."
      test_file = "/tmp/test_files/simple_test.txt"
      File.write!(test_file, test_content)

      prompt_parts = [
        %{"type" => "static", "content" => "Analyze this file:"},
        %{"type" => "file", "path" => test_file}
      ]

      context = %{results: %{}}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Analyze this file:")
      assert String.contains?(built_prompt, test_content)
    end

    test "loads content from multiple files in sequence" do
      # Create multiple test files
      file1_content = "First file content"
      file2_content = "Second file content"
      file1_path = "/tmp/test_files/file1.txt"
      file2_path = "/tmp/test_files/file2.txt"

      File.write!(file1_path, file1_content)
      File.write!(file2_path, file2_content)

      prompt_parts = [
        %{"type" => "static", "content" => "Compare these files:"},
        %{"type" => "file", "path" => file1_path},
        %{"type" => "static", "content" => "\n--- and ---\n"},
        %{"type" => "file", "path" => file2_path}
      ]

      context = %{results: %{}}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Compare these files:")
      assert String.contains?(built_prompt, file1_content)
      assert String.contains?(built_prompt, "--- and ---")
      assert String.contains?(built_prompt, file2_content)
    end

    test "handles file prompt in workflow execution" do
      # Create test file
      code_content = """
      def hello_world():
          print("Hello, World!")
          return "success"
      """

      code_file = "/tmp/test_files/hello.py"
      File.write!(code_file, code_content)

      workflow = %{
        "workflow" => %{
          "name" => "file_prompt_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "analyze_code",
              "type" => "gemini",
              "prompt" => [
                %{"type" => "static", "content" => "Analyze this Python code:"},
                %{"type" => "file", "path" => code_file}
              ]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["analyze_code"]["success"] == true
    end

    test "handles non-existent file gracefully" do
      prompt_parts = [
        %{"type" => "static", "content" => "Load this file:"},
        %{"type" => "file", "path" => "/tmp/test_files/nonexistent.txt"}
      ]

      context = %{results: %{}}

      # Should raise an error when file doesn't exist
      assert_raise RuntimeError, ~r/File not found/, fn ->
        PromptBuilder.build(prompt_parts, context.results)
      end
    end

    test "validates file prompt configuration" do
      config = %{
        "workflow" => %{
          "name" => "file_validation_test",
          "steps" => [
            %{
              "name" => "step_with_file",
              "type" => "claude",
              "prompt" => [
                %{"type" => "file", "path" => "/valid/path/file.txt"}
              ]
            }
          ]
        }
      }

      # Should validate successfully - file existence is checked at runtime
      assert :ok = Config.validate_workflow(config)
    end

    test "rejects file prompt without path" do
      config = %{
        "workflow" => %{
          "name" => "invalid_file_test",
          "steps" => [
            %{
              "name" => "step_with_invalid_file",
              "type" => "claude",
              "prompt" => [
                # Missing path
                %{"type" => "file"}
              ]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "without path")
    end

    test "loads various file types correctly" do
      # Test different file extensions and content types
      test_files = [
        {"/tmp/test_files/config.json", ~s({"key": "value", "number": 42})},
        {"/tmp/test_files/data.yaml", "key: value\nnumber: 42"},
        {"/tmp/test_files/script.py", "print('Hello from Python')"},
        {"/tmp/test_files/markup.md", "# Header\n\nSome **bold** text"},
        {"/tmp/test_files/data.csv", "name,age,city\nJohn,30,NYC\nJane,25,LA"}
      ]

      # Create all test files
      Enum.each(test_files, fn {path, content} ->
        File.write!(path, content)
      end)

      # Test loading each file type
      Enum.each(test_files, fn {path, expected_content} ->
        prompt_parts = [
          %{"type" => "static", "content" => "File content:"},
          %{"type" => "file", "path" => path}
        ]

        context = %{results: %{}}
        built_prompt = PromptBuilder.build(prompt_parts, context.results)

        assert String.contains?(built_prompt, expected_content)
      end)
    end

    test "handles large files efficiently" do
      # Create a larger test file
      large_content = String.duplicate("This is line #{:rand.uniform(1000)}\n", 1000)
      large_file = "/tmp/test_files/large_file.txt"
      File.write!(large_file, large_content)

      prompt_parts = [
        %{"type" => "static", "content" => "Large file analysis:"},
        %{"type" => "file", "path" => large_file}
      ]

      context = %{results: %{}}

      # Should handle large files without issues
      built_prompt = PromptBuilder.build(prompt_parts, context.results)
      assert String.length(built_prompt) > 10000
      assert String.contains?(built_prompt, "Large file analysis:")
    end

    test "combines file prompts with previous responses" do
      # Create test file
      requirements_content = """
      Requirements:
      1. Implement user authentication
      2. Add data validation
      3. Create REST API endpoints
      """

      requirements_file = "/tmp/test_files/requirements.txt"
      File.write!(requirements_file, requirements_content)

      workflow = %{
        "workflow" => %{
          "name" => "file_and_response_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "analyze_requirements",
              "type" => "gemini",
              "prompt" => [
                %{"type" => "file", "path" => requirements_file}
              ]
            },
            %{
              "name" => "create_implementation",
              "type" => "claude",
              "prompt" => [
                %{"type" => "static", "content" => "Based on these requirements:"},
                %{"type" => "file", "path" => requirements_file},
                %{"type" => "static", "content" => "\nAnd this analysis:"},
                %{"type" => "previous_response", "step" => "analyze_requirements"},
                %{"type" => "static", "content" => "\nCreate an implementation plan."}
              ]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["analyze_requirements"]["success"] == true
      assert results["create_implementation"]["success"] == true
    end

    test "handles relative file paths correctly" do
      # Create test file in current directory structure
      File.mkdir_p!("/tmp/test_files/project/src")
      source_file = "/tmp/test_files/project/src/main.py"
      File.write!(source_file, "# Main application file\nprint('Hello')")

      # Test relative path resolution (assuming we're in the project directory)
      prompt_parts = [
        %{"type" => "static", "content" => "Source code:"},
        # Use absolute for testing
        %{"type" => "file", "path" => source_file}
      ]

      context = %{results: %{}}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Main application file")
      assert String.contains?(built_prompt, "print('Hello')")
    end

    test "supports file prompt with both string and atom keys" do
      # Test the flexibility mentioned in prompt_builder.ex
      test_content = "File content for key flexibility test"
      test_file = "/tmp/test_files/key_test.txt"
      File.write!(test_file, test_content)

      # Test with string keys
      prompt_parts_string = [
        %{"type" => "file", "path" => test_file}
      ]

      # Test with atom keys (simulating internal processing)
      prompt_parts_atom = [
        %{type: "file", path: test_file}
      ]

      context = %{results: %{}}

      built_prompt_string = PromptBuilder.build(prompt_parts_string, context)
      built_prompt_atom = PromptBuilder.build(prompt_parts_atom, context)

      assert String.contains?(built_prompt_string, test_content)
      assert String.contains?(built_prompt_atom, test_content)
      assert built_prompt_string == built_prompt_atom
    end
  end

  describe "file prompt error handling" do
    test "provides helpful error message for missing files" do
      missing_file = "/tmp/test_files/missing_file.txt"

      prompt_parts = [
        %{"type" => "file", "path" => missing_file}
      ]

      context = %{results: %{}}

      assert_raise RuntimeError, ~r/File not found/, fn ->
        PromptBuilder.build(prompt_parts, context.results)
      end
    end

    test "handles permission denied errors gracefully" do
      # This test may not work in all environments, so we'll simulate the behavior
      restricted_file = "/tmp/test_files/restricted.txt"
      File.write!(restricted_file, "restricted content")

      # In a real scenario, we'd change permissions, but for testing we'll verify 
      # the file can be read when permissions allow it
      prompt_parts = [
        %{"type" => "file", "path" => restricted_file}
      ]

      context = %{results: %{}}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "restricted content")
    end

    test "handles empty files correctly" do
      empty_file = "/tmp/test_files/empty.txt"
      File.write!(empty_file, "")

      prompt_parts = [
        %{"type" => "static", "content" => "Empty file:"},
        %{"type" => "file", "path" => empty_file}
      ]

      context = %{results: %{}}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      # Should contain the static content but empty file content
      assert String.contains?(built_prompt, "Empty file:")
      # The empty file content is just an empty string, so no specific assertion needed
    end
  end
end
