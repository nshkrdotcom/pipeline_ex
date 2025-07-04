defmodule Pipeline.Step.DataTransformTest do
  use ExUnit.Case, async: true

  alias Pipeline.Step.DataTransform
  alias Pipeline.Data.Transformer

  describe "DataTransform.execute/2" do
    test "successfully transforms data with filter operation" do
      step = %{
        "name" => "filter_high_priority",
        "type" => "data_transform",
        "input_source" => "previous_response:analysis",
        "operations" => [
          %{
            "operation" => "filter",
            "field" => "priority",
            "condition" => "priority == 'high'"
          }
        ]
      }

      context = %{
        results: %{
          "analysis" => [
            %{"id" => 1, "priority" => "high", "score" => 95},
            %{"id" => 2, "priority" => "medium", "score" => 75},
            %{"id" => 3, "priority" => "high", "score" => 88}
          ]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      assert length(result["filter_high_priority"]) == 2
      assert Enum.all?(result["filter_high_priority"], &(&1["priority"] == "high"))
    end

    test "successfully aggregates data with average function" do
      step = %{
        "name" => "average_scores",
        "type" => "data_transform",
        "input_source" => "previous_response:scores",
        "operations" => [
          %{
            "operation" => "aggregate",
            "field" => "value",
            "function" => "average"
          }
        ]
      }

      context = %{
        results: %{
          "scores" => [
            %{"value" => 85},
            %{"value" => 92},
            %{"value" => 78},
            %{"value" => 88}
          ]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      assert result["average_scores"] == 85.75
    end

    test "successfully joins data from multiple sources" do
      step = %{
        "name" => "join_user_data",
        "type" => "data_transform",
        "input_source" => "previous_response:orders",
        "operations" => [
          %{
            "operation" => "join",
            "left_field" => "user_id",
            "right_source" => "previous_response:users",
            "join_key" => "id"
          }
        ]
      }

      context = %{
        results: %{
          "orders" => [
            %{"id" => 1, "user_id" => 10, "total" => 100.0},
            %{"id" => 2, "user_id" => 20, "total" => 75.0}
          ],
          "users" => [
            %{"id" => 10, "name" => "Alice", "email" => "alice@example.com"},
            %{"id" => 20, "name" => "Bob", "email" => "bob@example.com"}
          ]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      joined_data = result["join_user_data"]
      assert length(joined_data) == 2
      assert Enum.find(joined_data, &(&1["user_id"] == 10))["name"] == "Alice"
      assert Enum.find(joined_data, &(&1["user_id"] == 20))["name"] == "Bob"
    end

    test "successfully groups data by field" do
      step = %{
        "name" => "group_by_status",
        "type" => "data_transform",
        "input_source" => "previous_response:tasks",
        "operations" => [
          %{
            "operation" => "group_by",
            "field" => "status"
          }
        ]
      }

      context = %{
        results: %{
          "tasks" => [
            %{"id" => 1, "status" => "completed"},
            %{"id" => 2, "status" => "pending"},
            %{"id" => 3, "status" => "completed"},
            %{"id" => 4, "status" => "in_progress"}
          ]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      grouped = result["group_by_status"]
      assert length(grouped["completed"]) == 2
      assert length(grouped["pending"]) == 1
      assert length(grouped["in_progress"]) == 1
    end

    test "successfully sorts data by field" do
      step = %{
        "name" => "sort_by_score",
        "type" => "data_transform",
        "input_source" => "previous_response:results",
        "operations" => [
          %{
            "operation" => "sort",
            "field" => "score",
            "order" => "desc"
          }
        ]
      }

      context = %{
        results: %{
          "results" => [
            %{"id" => 1, "score" => 85},
            %{"id" => 2, "score" => 92},
            %{"id" => 3, "score" => 78}
          ]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      sorted = result["sort_by_score"]
      assert sorted |> hd() |> Map.get("score") == 92
      assert sorted |> List.last() |> Map.get("score") == 78
    end

    test "successfully chains multiple operations" do
      step = %{
        "name" => "complex_transform",
        "type" => "data_transform",
        "input_source" => "previous_response:data",
        "operations" => [
          %{
            "operation" => "filter",
            "field" => "active",
            "condition" => "active == true"
          },
          %{
            "operation" => "sort",
            "field" => "score",
            "order" => "desc"
          },
          %{
            "operation" => "map",
            "field" => "grade",
            "mapping" => %{
              "A" => "excellent",
              "B" => "good",
              "C" => "average"
            }
          }
        ]
      }

      context = %{
        results: %{
          "data" => [
            %{"id" => 1, "active" => true, "score" => 85, "grade" => "B"},
            %{"id" => 2, "active" => false, "score" => 92, "grade" => "A"},
            %{"id" => 3, "active" => true, "score" => 95, "grade" => "A"},
            %{"id" => 4, "active" => true, "score" => 78, "grade" => "C"}
          ]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      transformed = result["complex_transform"]

      # Should have 3 items (filtered out inactive)
      assert length(transformed) == 3

      # Should be sorted by score desc
      scores = Enum.map(transformed, & &1["score"])
      assert scores == [95, 85, 78]

      # Should have grade mapping applied
      assert Enum.find(transformed, &(&1["score"] == 95))["grade"] == "excellent"
      assert Enum.find(transformed, &(&1["score"] == 85))["grade"] == "good"
      assert Enum.find(transformed, &(&1["score"] == 78))["grade"] == "average"
    end

    test "handles missing input source" do
      step = %{
        "name" => "missing_input",
        "type" => "data_transform",
        "operations" => [
          %{
            "operation" => "filter",
            "field" => "status",
            "condition" => "status == 'active'"
          }
        ]
      }

      context = %{results: %{}}

      assert {:error, "input_source is required for data_transform step"} =
               DataTransform.execute(step, context)
    end

    test "handles non-existent input source" do
      step = %{
        "name" => "non_existent_input",
        "type" => "data_transform",
        "input_source" => "previous_response:non_existent",
        "operations" => [
          %{
            "operation" => "filter",
            "field" => "status",
            "condition" => "status == 'active'"
          }
        ]
      }

      context = %{results: %{}}

      assert {:error, "Input source 'previous_response:non_existent' not found"} =
               DataTransform.execute(step, context)
    end

    test "handles empty operations list" do
      step = %{
        "name" => "no_operations",
        "type" => "data_transform",
        "input_source" => "previous_response:data",
        "operations" => []
      }

      context = %{
        results: %{
          "data" => [%{"id" => 1, "value" => "test"}]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      assert result["no_operations"] == [%{"id" => 1, "value" => "test"}]
    end

    test "includes metadata in result" do
      step = %{
        "name" => "with_metadata",
        "type" => "data_transform",
        "input_source" => "previous_response:data",
        "operations" => [
          %{
            "operation" => "filter",
            "field" => "active",
            "condition" => "active == true"
          }
        ]
      }

      context = %{
        results: %{
          "data" => [
            %{"id" => 1, "active" => true},
            %{"id" => 2, "active" => false}
          ]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)

      metadata = result["metadata"]
      assert metadata["operation_count"] == 1
      assert metadata["input_type"] == "list"
      assert metadata["output_type"] == "list"
      assert metadata["processed_at"]
    end

    test "supports custom output field" do
      step = %{
        "name" => "custom_output",
        "type" => "data_transform",
        "input_source" => "previous_response:data",
        "output_field" => "transformed_results",
        "operations" => [
          %{
            "operation" => "filter",
            "field" => "active",
            "condition" => "active == true"
          }
        ]
      }

      context = %{
        results: %{
          "data" => [%{"id" => 1, "active" => true}]
        }
      }

      assert {:ok, result} = DataTransform.execute(step, context)
      assert Map.has_key?(result, "transformed_results")
      assert result["transformed_results"] == [%{"id" => 1, "active" => true}]
    end
  end

  describe "Transformer operations" do
    test "filter operation with various conditions" do
      data = [
        %{"score" => 85, "name" => "Alice"},
        %{"score" => 92, "name" => "Bob"},
        %{"score" => 78, "name" => "Charlie"}
      ]

      # Greater than condition
      operations = [%{"operation" => "filter", "field" => "score", "condition" => "score > 80"}]
      assert {:ok, result} = Transformer.transform(data, operations)
      assert length(result) == 2

      # String equality condition
      operations = [%{"operation" => "filter", "field" => "name", "condition" => "name == 'Bob'"}]
      assert {:ok, result} = Transformer.transform(data, operations)
      assert length(result) == 1
      assert hd(result)["name"] == "Bob"
    end

    test "map operation with field mapping" do
      data = [
        %{"grade" => "A", "student" => "Alice"},
        %{"grade" => "B", "student" => "Bob"}
      ]

      operations = [
        %{
          "operation" => "map",
          "field" => "grade",
          "mapping" => %{"A" => "excellent", "B" => "good"}
        }
      ]

      assert {:ok, result} = Transformer.transform(data, operations)
      assert Enum.find(result, &(&1["student"] == "Alice"))["grade"] == "excellent"
      assert Enum.find(result, &(&1["student"] == "Bob"))["grade"] == "good"
    end

    test "aggregate operations with different functions" do
      data = [
        %{"value" => 10},
        %{"value" => 20},
        %{"value" => 30}
      ]

      # Sum
      operations = [%{"operation" => "aggregate", "field" => "value", "function" => "sum"}]
      assert {:ok, 60} = Transformer.transform(data, operations)

      # Average
      operations = [%{"operation" => "aggregate", "field" => "value", "function" => "average"}]
      assert {:ok, 20.0} = Transformer.transform(data, operations)

      # Count
      operations = [%{"operation" => "aggregate", "field" => "value", "function" => "count"}]
      assert {:ok, 3} = Transformer.transform(data, operations)

      # Max
      operations = [%{"operation" => "aggregate", "field" => "value", "function" => "max"}]
      assert {:ok, 30} = Transformer.transform(data, operations)

      # Min
      operations = [%{"operation" => "aggregate", "field" => "value", "function" => "min"}]
      assert {:ok, 10} = Transformer.transform(data, operations)
    end

    test "nested field access" do
      data = [
        %{"user" => %{"profile" => %{"age" => 25}}, "active" => true},
        %{"user" => %{"profile" => %{"age" => 30}}, "active" => false},
        %{"user" => %{"profile" => %{"age" => 35}}, "active" => true}
      ]

      operations = [
        %{
          "operation" => "filter",
          "field" => "user.profile.age",
          "condition" => "user.profile.age > 28"
        }
      ]

      assert {:ok, result} = Transformer.transform(data, operations)
      assert length(result) == 2
    end

    test "error handling for invalid operations" do
      data = [%{"value" => 1}]
      operations = [%{"operation" => "invalid_operation"}]

      assert {:error, _reason} = Transformer.transform(data, operations)
    end
  end
end
