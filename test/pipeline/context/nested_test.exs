defmodule Pipeline.Context.NestedTest do
  use ExUnit.Case, async: true
  alias Pipeline.Context.Nested

  describe "create_nested_context/2" do
    test "creates isolated context by default" do
      parent_context = %{
        results: %{"step1" => "result1"},
        step_index: 2,
        execution_log: ["log1", "log2"],
        global_vars: %{"var1" => "value1"},
        nesting_depth: 1
      }

      step_config = %{
        "name" => "nested_step",
        "type" => "pipeline",
        "pipeline_file" => "test.yaml"
      }

      assert {:ok, nested_context} = Nested.create_nested_context(parent_context, step_config)

      # Should have fresh mutable state
      assert nested_context.results == %{}
      assert nested_context.step_index == 0
      assert nested_context.execution_log == []

      # Should track nesting
      assert nested_context.nesting_depth == 2
      assert nested_context.parent_context == parent_context

      # Should have basic metadata
      assert nested_context.pipeline_source == {:file, "test.yaml"}
      assert nested_context.step_name == "nested_step"
    end

    test "inherits context when configured" do
      parent_context = %{
        results: %{"step1" => "result1"},
        global_vars: %{"var1" => "value1"},
        functions: %{"func1" => "definition1"},
        providers: %{"provider1" => "config1"},
        inputs: %{"input1" => "value1"}
      }

      step_config = %{
        "name" => "nested_step",
        "type" => "pipeline",
        "pipeline_file" => "test.yaml",
        "config" => %{
          "inherit_context" => true
        }
      }

      assert {:ok, nested_context} = Nested.create_nested_context(parent_context, step_config)

      # Should inherit read-only data
      assert nested_context.global_vars == %{"var1" => "value1"}
      assert nested_context.functions == %{"func1" => "definition1"}
      assert nested_context.providers == %{"provider1" => "config1"}
      assert nested_context.inputs == %{"input1" => "value1"}

      # Should still have fresh mutable state
      assert nested_context.results == %{}
      assert nested_context.step_index == 0
    end

    test "maps inputs from parent context" do
      parent_context = %{
        results: %{"prepare" => %{"data" => "processed_data", "count" => 42}},
        global_vars: %{"base_url" => "https://api.example.com"}
      }

      step_config = %{
        "name" => "nested_step",
        "type" => "pipeline",
        "pipeline_file" => "test.yaml",
        "inputs" => %{
          "data_source" => "{{steps.prepare.result.data}}",
          "item_count" => "{{steps.prepare.result.count}}",
          "api_url" => "{{global_vars.base_url}}",
          "static_value" => "constant"
        }
      }

      assert {:ok, nested_context} = Nested.create_nested_context(parent_context, step_config)

      expected_inputs = %{
        "data_source" => "processed_data",
        "item_count" => 42,
        "api_url" => "https://api.example.com",
        "static_value" => "constant"
      }

      assert nested_context.inputs == expected_inputs
    end

    test "handles missing input gracefully" do
      parent_context = %{
        results: %{"step1" => "result1"}
      }

      step_config = %{
        "name" => "nested_step",
        "type" => "pipeline",
        "pipeline_file" => "test.yaml",
        "inputs" => %{
          "missing_data" => "{{steps.nonexistent.result}}"
        }
      }

      assert {:ok, nested_context} = Nested.create_nested_context(parent_context, step_config)

      # Should fallback to original template string
      assert nested_context.inputs["missing_data"] == "{{steps.nonexistent.result}}"
    end

    test "handles empty inputs" do
      parent_context = %{results: %{}}

      step_config = %{
        "name" => "nested_step",
        "type" => "pipeline",
        "pipeline_file" => "test.yaml"
      }

      assert {:ok, nested_context} = Nested.create_nested_context(parent_context, step_config)
      assert nested_context.inputs == %{}
    end
  end

  describe "extract_outputs/2" do
    setup do
      results = %{
        "step1" => "simple_result",
        "step2" => %{
          "nested" => %{
            "value" => "deep_value"
          },
          "array" => [1, 2, 3]
        },
        "analysis" => %{
          "metrics" => %{
            "accuracy" => 0.95,
            "precision" => 0.88
          },
          "summary" => "Good performance"
        }
      }

      {:ok, results: results}
    end

    test "extracts simple outputs", %{results: results} do
      output_config = ["step1", "step2"]

      assert {:ok, extracted} = Nested.extract_outputs(results, output_config)
      assert extracted["step1"] == "simple_result"
      assert extracted["step2"] == results["step2"]
    end

    test "extracts nested outputs with paths", %{results: results} do
      output_config = [
        %{"path" => "step2.nested.value"},
        %{"path" => "analysis.metrics.accuracy"}
      ]

      assert {:ok, extracted} = Nested.extract_outputs(results, output_config)
      assert extracted["step2.nested.value"] == "deep_value"
      assert extracted["analysis.metrics.accuracy"] == 0.95
    end

    test "extracts outputs with aliases", %{results: results} do
      output_config = [
        %{"path" => "step2.nested.value", "as" => "deep_result"},
        %{"path" => "analysis.metrics.accuracy", "as" => "accuracy_score"}
      ]

      assert {:ok, extracted} = Nested.extract_outputs(results, output_config)
      assert extracted["deep_result"] == "deep_value"
      assert extracted["accuracy_score"] == 0.95
    end

    test "handles missing outputs gracefully", %{results: results} do
      output_config = ["nonexistent_step"]

      assert {:error, reason} = Nested.extract_outputs(results, output_config)
      assert reason =~ "Output 'nonexistent_step' not found"
    end

    test "handles missing nested paths gracefully", %{results: results} do
      output_config = [
        %{"path" => "step2.missing.path"}
      ]

      assert {:error, reason} = Nested.extract_outputs(results, output_config)
      assert reason =~ "Path 'step2.missing.path' not found"
    end

    test "returns all results when no output config provided", %{results: results} do
      assert {:ok, extracted} = Nested.extract_outputs(results, nil)
      assert extracted == results

      assert {:ok, extracted} = Nested.extract_outputs(results, [])
      assert extracted == results
    end

    test "mixes simple and complex extractions", %{results: results} do
      output_config = [
        "step1",
        %{"path" => "analysis.metrics.accuracy", "as" => "accuracy"},
        %{"path" => "step2.nested.value"}
      ]

      assert {:ok, extracted} = Nested.extract_outputs(results, output_config)
      assert extracted["step1"] == "simple_result"
      assert extracted["accuracy"] == 0.95
      assert extracted["step2.nested.value"] == "deep_value"
    end

    test "stops on first error in extraction" do
      results = %{"step1" => "result1"}

      output_config = [
        "step1",
        "missing_step",
        %{"path" => "step1.some.path"}
      ]

      assert {:error, reason} = Nested.extract_outputs(results, output_config)
      assert reason =~ "Output 'missing_step' not found"
    end
  end
end
