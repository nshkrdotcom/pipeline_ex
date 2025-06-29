defmodule Pipeline.ResultManagerTest do
  use ExUnit.Case, async: true
  
  alias Pipeline.ResultManager

  describe "new/0" do
    test "creates a new result manager" do
      manager = ResultManager.new()
      
      assert %ResultManager{} = manager
      assert manager.results == %{}
      assert Map.has_key?(manager.metadata, :created_at)
    end
  end

  describe "store_result/3 and get_result/2" do
    test "stores and retrieves a result" do
      manager = ResultManager.new()
      result = %{text: "Hello world", success: true, cost: 0.001}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:ok, retrieved_result} = ResultManager.get_result(updated_manager, "step1")
      assert retrieved_result[:text] == "Hello world"
      assert retrieved_result[:success] == true
    end

    test "returns error for non-existent result" do
      manager = ResultManager.new()
      
      assert {:error, :not_found} = ResultManager.get_result(manager, "nonexistent")
    end

    test "validates and transforms results on storage" do
      manager = ResultManager.new()
      
      # Test string result transformation
      updated_manager = ResultManager.store_result(manager, "string_step", "Simple text result")
      {:ok, result} = ResultManager.get_result(updated_manager, "string_step")
      
      assert result[:success] == true
      assert result[:text] == "Simple text result"
      assert result[:cost] == 0.0
    end

    test "handles results with string keys" do
      manager = ResultManager.new()
      result = %{"text" => "Hello", "success" => true, "cost" => 0.5}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      {:ok, retrieved_result} = ResultManager.get_result(updated_manager, "step1")
      
      assert retrieved_result[:text] == "Hello"
      assert retrieved_result[:success] == true
      assert retrieved_result[:cost] == 0.5
    end
  end

  describe "has_result?/2" do
    test "returns true for existing results" do
      manager = ResultManager.new()
      result = %{text: "Hello", success: true}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert ResultManager.has_result?(updated_manager, "step1")
      refute ResultManager.has_result?(updated_manager, "step2")
    end
  end

  describe "extract_field/3" do
    test "extracts simple fields from results" do
      manager = ResultManager.new()
      result = %{text: "Hello world", success: true, cost: 0.001}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:ok, "Hello world"} = ResultManager.extract_field(updated_manager, "step1", "text")
      assert {:ok, true} = ResultManager.extract_field(updated_manager, "step1", "success")
    end

    test "extracts nested fields from results" do
      manager = ResultManager.new()
      result = %{
        data: %{
          analysis: %{
            score: 95,
            summary: "Good quality"
          }
        },
        success: true
      }
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:ok, 95} = ResultManager.extract_field(updated_manager, "step1", "data.analysis.score")
      assert {:ok, "Good quality"} = ResultManager.extract_field(updated_manager, "step1", "data.analysis.summary")
    end

    test "returns error for missing fields" do
      manager = ResultManager.new()
      result = %{text: "Hello", success: true}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:error, :field_not_found} = ResultManager.extract_field(updated_manager, "step1", "missing_field")
    end
  end

  describe "transform_for_prompt/3" do
    test "transforms text results for prompts" do
      manager = ResultManager.new()
      result = %{text: "Hello world", success: true}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:ok, "Hello world"} = ResultManager.transform_for_prompt(updated_manager, "step1")
    end

    test "transforms content results for prompts" do
      manager = ResultManager.new()
      result = %{content: "Analysis result", success: true}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:ok, "Analysis result"} = ResultManager.transform_for_prompt(updated_manager, "step1")
    end

    test "formats JSON for prompts when requested" do
      manager = ResultManager.new()
      result = %{data: %{score: 95}, success: true}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:ok, json_result} = ResultManager.transform_for_prompt(updated_manager, "step1", format: :json)
      assert String.contains?(json_result, "score")
      assert String.contains?(json_result, "95")
    end

    test "extracts specific fields for prompts" do
      manager = ResultManager.new()
      result = %{text: "Main text", metadata: "Extra info", success: true}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      assert {:ok, "Extra info"} = ResultManager.transform_for_prompt(updated_manager, "step1", field: "metadata")
    end
  end

  describe "get_summary/1" do
    test "provides summary statistics" do
      manager = ResultManager.new()
      
      # Add successful result
      manager = ResultManager.store_result(manager, "step1", %{text: "Success", success: true, cost: 0.01})
      
      # Add failed result
      manager = ResultManager.store_result(manager, "step2", %{text: "Failed", success: false, cost: 0.005})
      
      summary = ResultManager.get_summary(manager)
      
      assert summary.total_steps == 2
      assert summary.successful_steps == 1
      assert summary.failed_steps == 1
      assert summary.total_cost == 0.015
      assert "step1" in summary.steps
      assert "step2" in summary.steps
    end
  end

  describe "JSON serialization" do
    test "serializes and deserializes results" do
      manager = ResultManager.new()
      result1 = %{text: "Hello", success: true, cost: 0.01}
      result2 = %{content: "World", success: true, cost: 0.02}
      
      manager = manager
                |> ResultManager.store_result("step1", result1)
                |> ResultManager.store_result("step2", result2)
      
      assert {:ok, json} = ResultManager.to_json(manager)
      assert {:ok, restored_manager} = ResultManager.from_json(json)
      
      assert {:ok, retrieved1} = ResultManager.get_result(restored_manager, "step1")
      assert {:ok, retrieved2} = ResultManager.get_result(restored_manager, "step2")
      
      assert retrieved1[:text] == "Hello"
      assert retrieved2[:content] == "World"
    end
  end

  describe "file operations" do
    test "saves and loads results from file" do
      manager = ResultManager.new()
      result = %{text: "File test", success: true, cost: 0.001}
      
      updated_manager = ResultManager.store_result(manager, "step1", result)
      
      file_path = "/tmp/test_results_#{System.unique_integer()}.json"
      
      assert :ok = ResultManager.save_to_file(updated_manager, file_path)
      assert File.exists?(file_path)
      
      assert {:ok, loaded_manager} = ResultManager.load_from_file(file_path)
      assert {:ok, loaded_result} = ResultManager.get_result(loaded_manager, "step1")
      
      assert loaded_result[:text] == "File test"
      
      File.rm!(file_path)
    end

    test "handles file operation errors" do
      _manager = ResultManager.new()
      
      # Try to load from non-existent file
      assert {:error, _} = ResultManager.load_from_file("/nonexistent/file.json")
    end
  end
end