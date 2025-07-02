defmodule Pipeline.Step.FileOpsTest do
  use ExUnit.Case, async: false

  alias Pipeline.Step.FileOps
  alias Pipeline.Utils.FileUtils

  @test_workspace "/tmp/pipeline_test_workspace"

  setup do
    # Clean up and create test workspace
    File.rm_rf(@test_workspace)
    File.mkdir_p!(@test_workspace)

    context = %{
      workspace_dir: @test_workspace,
      results: %{}
    }

    {:ok, context: context}
  end

  describe "copy operation" do
    test "copies file successfully", %{context: context} do
      # Create source file
      source_content = "test content"
      source_path = Path.join(@test_workspace, "source.txt")
      File.write!(source_path, source_content)

      step = %{
        "name" => "copy_test",
        "operation" => "copy",
        "source" => "source.txt",
        "destination" => "dest.txt"
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "copy"
      assert result["status"] == "completed"

      # Verify file was copied
      dest_path = Path.join(@test_workspace, "dest.txt")
      assert File.exists?(dest_path)
      assert File.read!(dest_path) == source_content
    end

    test "handles missing source file", %{context: context} do
      step = %{
        "name" => "copy_missing",
        "operation" => "copy",
        "source" => "nonexistent.txt",
        "destination" => "dest.txt"
      }

      assert {:error, error} = FileOps.execute(step, context)
      assert String.contains?(error, "Source file does not exist")
    end
  end

  describe "move operation" do
    test "moves file successfully", %{context: context} do
      # Create source file
      source_content = "move test content"
      source_path = Path.join(@test_workspace, "move_source.txt")
      File.write!(source_path, source_content)

      step = %{
        "name" => "move_test",
        "operation" => "move",
        "source" => "move_source.txt",
        "destination" => "moved.txt"
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "move"
      assert result["status"] == "completed"

      # Verify file was moved
      dest_path = Path.join(@test_workspace, "moved.txt")
      assert File.exists?(dest_path)
      assert File.read!(dest_path) == source_content
      assert not File.exists?(source_path)
    end
  end

  describe "delete operation" do
    test "deletes file successfully", %{context: context} do
      # Create file to delete
      file_path = Path.join(@test_workspace, "delete_me.txt")
      File.write!(file_path, "delete content")

      step = %{
        "name" => "delete_test",
        "operation" => "delete",
        "path" => "delete_me.txt"
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "delete"
      assert result["status"] == "completed"

      # Verify file was deleted
      assert not File.exists?(file_path)
    end

    test "deletes directory successfully", %{context: context} do
      # Create directory to delete
      dir_path = Path.join(@test_workspace, "delete_dir")
      File.mkdir_p!(dir_path)
      File.write!(Path.join(dir_path, "file.txt"), "content")

      step = %{
        "name" => "delete_dir_test",
        "operation" => "delete",
        "path" => "delete_dir"
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "delete"
      assert result["status"] == "completed"

      # Verify directory was deleted
      assert not File.exists?(dir_path)
    end
  end

  describe "validate operation" do
    test "validates files successfully", %{context: context} do
      # Create test files
      File.write!(Path.join(@test_workspace, "valid_file.txt"), "content with sufficient length")
      File.mkdir_p!(Path.join(@test_workspace, "valid_dir"))

      step = %{
        "name" => "validate_test",
        "operation" => "validate",
        "files" => [
          %{
            "path" => "valid_file.txt",
            "must_exist" => true,
            "must_be_file" => true,
            "min_size" => 10
          },
          %{
            "path" => "valid_dir",
            "must_exist" => true,
            "must_be_dir" => true
          }
        ]
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "validate"
      assert result["status"] == "all_valid"
      assert length(result["results"]) == 2
      assert Enum.all?(result["results"], &(&1["status"] == "valid"))
    end

    test "handles validation failures", %{context: context} do
      step = %{
        "name" => "validate_fail_test",
        "operation" => "validate",
        "files" => [
          %{
            "path" => "nonexistent.txt",
            "must_exist" => true
          }
        ]
      }

      assert {:error, error} = FileOps.execute(step, context)
      assert String.contains?(error, "Validation failed")
    end
  end

  describe "list operation" do
    test "lists files in directory", %{context: context} do
      # Create test files
      File.write!(Path.join(@test_workspace, "file1.txt"), "content1")
      File.write!(Path.join(@test_workspace, "file2.txt"), "content2")
      File.write!(Path.join(@test_workspace, "file3.log"), "content3")

      step = %{
        "name" => "list_test",
        "operation" => "list",
        "path" => "."
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "list"
      assert result["count"] == 3
      assert length(result["files"]) == 3
    end

    test "lists files with pattern", %{context: context} do
      # Create test files
      File.write!(Path.join(@test_workspace, "test1.txt"), "content1")
      File.write!(Path.join(@test_workspace, "test2.txt"), "content2")
      File.write!(Path.join(@test_workspace, "other.log"), "content3")

      step = %{
        "name" => "list_pattern_test",
        "operation" => "list",
        "path" => ".",
        "pattern" => "txt"
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "list"
      assert result["count"] == 2
      assert Enum.all?(result["files"], &String.ends_with?(&1, ".txt"))
    end
  end

  describe "convert operation" do
    test "converts CSV to JSON", %{context: context} do
      # Create CSV file
      csv_content = "name,age,city\nJohn,30,NYC\nJane,25,LA"
      csv_path = Path.join(@test_workspace, "data.csv")
      File.write!(csv_path, csv_content)

      step = %{
        "name" => "convert_test",
        "operation" => "convert",
        "source" => "data.csv",
        "destination" => "data.json",
        "format" => "csv_to_json"
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["operation"] == "convert"
      assert result["format"] == "csv_to_json"
      assert result["status"] == "completed"

      # Verify JSON file was created
      json_path = Path.join(@test_workspace, "data.json")
      assert File.exists?(json_path)

      json_content = File.read!(json_path)
      {:ok, data} = Jason.decode(json_content)

      assert length(data) == 2
      assert hd(data)["name"] == "John"
      assert hd(data)["age"] == "30"
    end

    test "handles JSON to YAML conversion (not implemented)", %{context: context} do
      # Create JSON file
      json_data = %{"name" => "test", "values" => [1, 2, 3]}
      json_content = Jason.encode!(json_data)
      json_path = Path.join(@test_workspace, "data.json")
      File.write!(json_path, json_content)

      step = %{
        "name" => "json_to_yaml_test",
        "operation" => "convert",
        "source" => "data.json",
        "destination" => "data.yaml",
        "format" => "json_to_yaml"
      }

      assert {:error, error} = FileOps.execute(step, context)
      assert String.contains?(error, "JSON to YAML conversion not yet implemented")
    end

    test "handles unsupported format conversion", %{context: context} do
      # Create source file first
      File.write!(Path.join(@test_workspace, "data.txt"), "test content")

      step = %{
        "name" => "unsupported_convert",
        "operation" => "convert",
        "source" => "data.txt",
        "destination" => "data.bin",
        "format" => "unsupported_format"
      }

      assert {:error, error} = FileOps.execute(step, context)
      assert String.contains?(error, "Unsupported format conversion")
    end
  end

  describe "error handling" do
    test "handles unsupported operation", %{context: context} do
      step = %{
        "name" => "unsupported_test",
        "operation" => "unsupported_op"
      }

      assert {:error, error} = FileOps.execute(step, context)
      assert String.contains?(error, "Unsupported operation")
    end
  end

  describe "path resolution" do
    test "handles absolute paths", %{context: context} do
      # Create file with absolute path
      abs_path = "/tmp/absolute_test.txt"
      File.write!(abs_path, "absolute content")

      step = %{
        "name" => "absolute_path_test",
        "operation" => "copy",
        "source" => abs_path,
        "destination" => "copied_absolute.txt"
      }

      assert {:ok, result} = FileOps.execute(step, context)
      assert result["status"] == "completed"

      # Verify file was copied to workspace
      dest_path = Path.join(@test_workspace, "copied_absolute.txt")
      assert File.exists?(dest_path)
      assert File.read!(dest_path) == "absolute content"

      # Cleanup
      File.rm(abs_path)
    end
  end
end
