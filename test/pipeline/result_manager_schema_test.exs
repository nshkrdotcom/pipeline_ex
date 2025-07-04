defmodule Pipeline.ResultManagerSchemaTest do
  use ExUnit.Case, async: true

  alias Pipeline.ResultManager

  describe "store_result_with_schema/4" do
    test "stores result when no schema is provided" do
      manager = ResultManager.new()
      result = %{text: "Hello world", success: true}

      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(manager, "test_step", result)

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "test_step")
      assert stored_result.text == "Hello world"
      assert stored_result.success == true
    end

    test "validates result against schema successfully" do
      manager = ResultManager.new()

      result = %{
        data: %{
          "analysis" => "This is a detailed analysis of the code",
          "score" => 8.5
        },
        success: true
      }

      schema = %{
        "type" => "object",
        "required" => ["analysis", "score"],
        "properties" => %{
          "analysis" => %{"type" => "string", "minLength" => 10},
          "score" => %{"type" => "number", "minimum" => 0, "maximum" => 10}
        }
      }

      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(manager, "analysis_step", result, schema)

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "analysis_step")
      assert stored_result.success == true
    end

    test "rejects result that fails schema validation" do
      manager = ResultManager.new()

      result = %{
        data: %{
          "analysis" => "Too short",
          "score" => 15
        },
        success: true
      }

      schema = %{
        "type" => "object",
        "required" => ["analysis", "score"],
        "properties" => %{
          "analysis" => %{"type" => "string", "minLength" => 10},
          "score" => %{"type" => "number", "minimum" => 0, "maximum" => 10}
        }
      }

      assert {:error, error_message} =
               ResultManager.store_result_with_schema(manager, "analysis_step", result, schema)

      assert error_message =~ "Schema validation failed for step 'analysis_step'"
      assert error_message =~ "String must be at least 10 characters long"
      assert error_message =~ "Value must be <= 10"
    end

    test "handles missing required properties" do
      manager = ResultManager.new()

      result = %{
        data: %{
          "score" => 8.5
        },
        success: true
      }

      schema = %{
        "type" => "object",
        "required" => ["analysis", "score"],
        "properties" => %{
          "analysis" => %{"type" => "string"},
          "score" => %{"type" => "number"}
        }
      }

      assert {:error, error_message} =
               ResultManager.store_result_with_schema(manager, "analysis_step", result, schema)

      assert error_message =~ "Required property 'analysis' is missing"
    end

    test "extracts validation data from different result formats" do
      manager = ResultManager.new()

      schema = %{
        "type" => "object",
        "required" => ["name"],
        "properties" => %{
          "name" => %{"type" => "string"}
        }
      }

      # Test data field extraction
      result1 = %{data: %{"name" => "John"}, success: true}
      assert {:ok, _} = ResultManager.store_result_with_schema(manager, "step1", result1, schema)

      # Test content field extraction
      result2 = %{content: %{"name" => "Jane"}, success: true}
      assert {:ok, _} = ResultManager.store_result_with_schema(manager, "step2", result2, schema)

      # Test text field extraction
      result3 = %{text: %{"name" => "Bob"}, success: true}
      assert {:ok, _} = ResultManager.store_result_with_schema(manager, "step3", result3, schema)

      # Test response field extraction
      result4 = %{response: %{"name" => "Alice"}, success: true}
      assert {:ok, _} = ResultManager.store_result_with_schema(manager, "step4", result4, schema)
    end

    test "handles results with success=true by filtering metadata" do
      manager = ResultManager.new()

      result = %{
        name: "John",
        age: 30,
        success: true,
        cost: 0.05,
        duration: 1500,
        timestamp: "2024-01-01T12:00:00Z"
      }

      schema = %{
        "type" => "object",
        "required" => ["name", "age"],
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer", "minimum" => 0}
        },
        "additionalProperties" => false
      }

      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(manager, "user_step", result, schema)

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "user_step")
      assert stored_result.success == true
    end

    test "validates direct data when no nested structure found" do
      manager = ResultManager.new()

      result = %{
        "name" => "John",
        "age" => 30
      }

      schema = %{
        "type" => "object",
        "required" => ["name", "age"],
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }

      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(manager, "direct_step", result, schema)

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "direct_step")
      assert stored_result.success == true
    end

    test "handles invalid schema gracefully" do
      manager = ResultManager.new()
      result = %{data: %{"test" => "value"}, success: true}
      invalid_schema = "not a map"

      # Should log warning and proceed with normal validation
      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(
                 manager,
                 "test_step",
                 result,
                 invalid_schema
               )

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "test_step")
      assert stored_result.success == true
    end

    test "preserves result structure after validation" do
      manager = ResultManager.new()

      result = %{
        data: %{
          "analysis" => "This is a comprehensive analysis",
          "score" => 9.0
        },
        success: true,
        cost: 0.02,
        duration: 2000
      }

      schema = %{
        "type" => "object",
        "required" => ["analysis", "score"],
        "properties" => %{
          "analysis" => %{"type" => "string", "minLength" => 10},
          "score" => %{"type" => "number", "minimum" => 0, "maximum" => 10}
        }
      }

      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(manager, "analysis_step", result, schema)

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "analysis_step")

      # Verify the original structure is preserved
      assert stored_result.success == true
      assert stored_result.cost == 0.02
      assert stored_result.duration == 2000
      assert is_map(stored_result.data)
    end
  end

  describe "integration with common schemas" do
    test "validates against analysis result schema" do
      manager = ResultManager.new()

      result = %{
        data: %{
          "analysis" =>
            "This code demonstrates good practices with clear variable names and proper error handling throughout the implementation.",
          "score" => 8.5,
          "recommendations" => [
            %{
              "priority" => "high",
              "action" => "Add comprehensive unit tests for edge cases"
            },
            %{
              "priority" => "medium",
              "action" => "Consider extracting complex logic into separate functions"
            }
          ]
        },
        success: true
      }

      schema = Pipeline.Schemas.CommonSchemas.analysis_result_schema()

      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(manager, "code_analysis", result, schema)

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "code_analysis")
      assert stored_result.success == true
    end

    test "validates against test results schema" do
      manager = ResultManager.new()

      result = %{
        data: %{
          "total_tests" => 50,
          "passed" => 48,
          "failed" => 2,
          "status" => "failed",
          "duration" => 12.5,
          "failures" => [
            %{
              "test_name" => "should handle empty input",
              "error_message" => "Expected nil but got empty string",
              "file" => "test/user_test.ex",
              "line" => 45
            }
          ]
        },
        success: true
      }

      schema = Pipeline.Schemas.CommonSchemas.test_results_schema()

      assert {:ok, new_manager} =
               ResultManager.store_result_with_schema(manager, "test_run", result, schema)

      assert {:ok, stored_result} = ResultManager.get_result(new_manager, "test_run")
      assert stored_result.success == true
    end
  end
end
