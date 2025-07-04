defmodule Pipeline.Integration.NestedPipelinePhase2Test do
  use ExUnit.Case
  alias Pipeline.Executor

  @moduletag :integration

  describe "Phase 2: Context Management Features" do
    test "passes variables between parent and child pipelines" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_context_management",
          "steps" => [
            %{
              "name" => "prepare_data",
              "type" => "test_echo",
              "value" => %{
                "name" => "test_item",
                "count" => 42
              }
            },
            %{
              "name" => "process",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/nested_processor.yaml",
              "inputs" => %{
                "item_name" => "{{steps.prepare_data.name}}",
                "item_count" => "{{steps.prepare_data.count}}",
                "multiplier" => 2
              }
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(pipeline)
      assert results["prepare_data"]["name"] == "test_item"
      assert results["prepare_data"]["count"] == 42

      # The nested pipeline should have processed the inputs (unwrapped by smart extraction)
      assert results["process"]["result"]["process_input"] == "Processing test_item with count 42"
      assert results["process"]["result"]["multiply_count"] == 84
      assert results["process"]["result"]["final_count"] == 84
    end

    test "extracts multiple outputs from nested pipeline" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_output_extraction",
          "steps" => [
            %{
              "name" => "analyze",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/output_extraction_test.yaml",
              "outputs" => [
                "step1",
                %{"path" => "analysis.metrics.accuracy", "as" => "accuracy_score"},
                %{"path" => "step2.nested.value", "as" => "nested_value"}
              ]
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(pipeline)

      # Should only have the extracted outputs
      assert results["analyze"]["step1"] == "Simple result"
      assert results["analyze"]["accuracy_score"] == 0.95
      assert results["analyze"]["nested_value"] == "Deep nested value"

      # Should not have other outputs
      refute Map.has_key?(results["analyze"], "step2")
      refute Map.has_key?(results["analyze"], "analysis")
    end

    test "inherits context when configured" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_context_inheritance",
          "global_vars" => %{
            "parent_var" => "parent_value"
          },
          "steps" => [
            %{
              "name" => "nested_with_inheritance",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/context_inherit_test.yaml",
              "inputs" => %{
                "test_input" => "input_value"
              },
              "config" => %{
                "inherit_context" => true
              }
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(pipeline)

      # Should be able to access parent variables
      assert results["nested_with_inheritance"]["result"]["use_parent_var"] ==
               "Using parent variable: parent_value"

      assert results["nested_with_inheritance"]["result"]["use_input"] ==
               "Using input: input_value"

      assert results["nested_with_inheritance"]["result"]["combined_result"] ==
               "Using parent variable: parent_value and Using input: input_value"
    end

    test "isolates context when inheritance disabled" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_context_isolation",
          "global_vars" => %{
            "parent_var" => "parent_value"
          },
          "steps" => [
            %{
              "name" => "nested_without_inheritance",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/context_inherit_test.yaml",
              "inputs" => %{
                "test_input" => "input_value"
              },
              "config" => %{
                "inherit_context" => false
              }
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(pipeline)

      # Should not be able to access parent variables
      assert results["nested_without_inheritance"]["result"]["use_parent_var"] ==
               "Using parent variable: {{global_vars.parent_var}}"

      assert results["nested_without_inheritance"]["result"]["use_input"] ==
               "Using input: input_value"
    end

    test "complex variable resolution with nested structures" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_complex_variables",
          "steps" => [
            %{
              "name" => "setup",
              "type" => "test_echo",
              "value" => %{
                "config" => %{
                  "database" => %{
                    "host" => "localhost",
                    "port" => 5432
                  }
                },
                "credentials" => %{
                  "username" => "admin",
                  "password" => "secret123"
                }
              }
            },
            %{
              "name" => "process",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "inline_processor",
                "steps" => [
                  %{
                    "name" => "connect",
                    "type" => "test_echo",
                    "value" =>
                      "Connecting to {{inputs.db_host}}:{{inputs.db_port}} as {{inputs.user}}"
                  },
                  %{
                    "name" => "result",
                    "type" => "test_echo",
                    "value" => "Connected successfully"
                  }
                ]
              },
              "inputs" => %{
                "db_host" => "{{steps.setup.config.database.host}}",
                "db_port" => "{{steps.setup.config.database.port}}",
                "user" => "{{steps.setup.credentials.username}}"
              },
              "outputs" => [
                "connect",
                "result"
              ]
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(pipeline)

      assert results["process"]["result"]["connect"] == "Connecting to localhost:5432 as admin"
      assert results["process"]["result"]["result"] == "Connected successfully"
    end

    test "handles missing inputs gracefully" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_missing_inputs",
          "steps" => [
            %{
              "name" => "process",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "inline_processor",
                "steps" => [
                  %{
                    "name" => "result",
                    "type" => "test_echo",
                    "value" => "Input: {{inputs.missing_input}}"
                  }
                ]
              },
              "inputs" => %{
                "missing_input" => "{{steps.nonexistent.result}}"
              }
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(pipeline)

      # Should use template string when variable not found
      assert results["process"]["result"]["result"] == "Input: {{steps.nonexistent.result}}"
    end

    test "error handling in output extraction" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_output_extraction_error",
          "steps" => [
            %{
              "name" => "analyze",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/output_extraction_test.yaml",
              "outputs" => [
                "step1",
                "nonexistent_step"
              ]
            }
          ]
        }
      }

      assert {:error, reason} = Executor.execute(pipeline)
      assert reason =~ "Output 'nonexistent_step' not found"
    end

    test "deeply nested variable resolution" do
      pipeline = %{
        "workflow" => %{
          "name" => "test_deep_nesting",
          "steps" => [
            %{
              "name" => "level1",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "level1_pipeline",
                "steps" => [
                  %{
                    "name" => "level2",
                    "type" => "pipeline",
                    "pipeline" => %{
                      "name" => "level2_pipeline",
                      "steps" => [
                        %{
                          "name" => "result",
                          "type" => "test_echo",
                          "value" => "Deep nested result"
                        }
                      ]
                    },
                    "outputs" => ["result"]
                  }
                ]
              },
              "outputs" => [
                %{"path" => "level2.result", "as" => "deep_result"}
              ]
            }
          ]
        }
      }

      assert {:ok, results} = Executor.execute(pipeline)
      assert results["level1"]["deep_result"] == "Deep nested result"
    end
  end
end
