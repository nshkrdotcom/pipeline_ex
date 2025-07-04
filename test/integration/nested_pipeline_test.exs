defmodule Pipeline.Integration.NestedPipelineTest do
  use ExUnit.Case
  alias Pipeline.Executor

  @moduletag :integration

  test "simple nested pipeline end-to-end" do
    pipeline = %{
      "workflow" => %{
        "name" => "parent_pipeline",
        "steps" => [
          %{
            "name" => "prepare_data",
            "type" => "test_echo",
            "value" => "parent_data"
          },
          %{
            "name" => "nested_processing",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "child_pipeline",
              "steps" => [
                %{
                  "name" => "process_data",
                  "type" => "test_echo",
                  "value" => "nested_processed"
                },
                %{
                  "name" => "finalize",
                  "type" => "test_echo",
                  "value" => "nested_complete"
                }
              ]
            }
          },
          %{
            "name" => "verify_result",
            "type" => "test_echo",
            "value" => "parent_complete"
          }
        ]
      }
    }

    assert {:ok, results} = Executor.execute(pipeline)

    # Parent pipeline results
    assert results["prepare_data"] == "parent_data"
    assert results["verify_result"] == "parent_complete"

    # Nested pipeline results
    assert is_map(results["nested_processing"])
    assert results["nested_processing"]["process_data"] == "nested_processed"
    assert results["nested_processing"]["finalize"] == "nested_complete"
  end

  test "nested pipeline with test_echo steps" do
    # Create a test file for nested pipeline
    nested_pipeline_path =
      Path.join(System.tmp_dir!(), "nested_vars_#{:rand.uniform(10000)}.yaml")

    nested_content = """
    workflow:
      name: "variable_pipeline"
      steps:
        - name: "var1"
          type: "test_echo"
          value: "first_value"
        - name: "var2"
          type: "test_echo"
          value: "second_value"
        - name: "combined"
          type: "test_echo"
          value: "combined_result"
    """

    File.write!(nested_pipeline_path, nested_content)

    pipeline = %{
      "workflow" => %{
        "name" => "main_with_nested_vars",
        "steps" => [
          %{
            "name" => "setup",
            "type" => "test_echo",
            "value" => "main_setup"
          },
          %{
            "name" => "run_nested",
            "type" => "pipeline",
            "pipeline_file" => nested_pipeline_path
          }
        ]
      }
    }

    try do
      assert {:ok, results} = Executor.execute(pipeline)

      assert results["setup"] == "main_setup"
      assert results["run_nested"]["var1"] == "first_value"
      assert results["run_nested"]["var2"] == "second_value"
      assert results["run_nested"]["combined"] == "combined_result"
    after
      File.rm(nested_pipeline_path)
    end
  end

  test "error propagation from nested to parent" do
    pipeline = %{
      "workflow" => %{
        "name" => "parent_with_error",
        "steps" => [
          %{
            "name" => "setup",
            "type" => "test_echo",
            "value" => "setup_done"
          },
          %{
            "name" => "nested_with_error",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "error_pipeline",
              "steps" => [
                %{
                  "name" => "good_step",
                  "type" => "test_echo",
                  "value" => "ok"
                },
                %{
                  "name" => "bad_step",
                  # This will cause an error
                  "type" => "unsupported_type",
                  "value" => "should_fail"
                }
              ]
            }
          },
          %{
            "name" => "should_not_run",
            "type" => "test_echo",
            "value" => "unreachable"
          }
        ]
      }
    }

    assert {:error, reason} = Executor.execute(pipeline)
    assert reason =~ "Nested pipeline 'error_pipeline' failed"
  end

  test "multiple nested pipelines in sequence" do
    pipeline = %{
      "workflow" => %{
        "name" => "multi_nested",
        "steps" => [
          %{
            "name" => "first_nested",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "first",
              "steps" => [
                %{"name" => "step1", "type" => "test_echo", "value" => "first_result"}
              ]
            }
          },
          %{
            "name" => "second_nested",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "second",
              "steps" => [
                %{"name" => "step2", "type" => "test_echo", "value" => "second_result"}
              ]
            }
          },
          %{
            "name" => "third_nested",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "third",
              "steps" => [
                %{"name" => "step3", "type" => "test_echo", "value" => "third_result"}
              ]
            }
          }
        ]
      }
    }

    assert {:ok, results} = Executor.execute(pipeline)

    assert results["first_nested"]["step1"] == "first_result"
    assert results["second_nested"]["step2"] == "second_result"
    assert results["third_nested"]["step3"] == "third_result"
  end

  test "deeply nested pipelines" do
    # Test pipeline nesting multiple levels deep
    pipeline = %{
      "workflow" => %{
        "name" => "level_0",
        "steps" => [
          %{
            "name" => "level_0_step",
            "type" => "test_echo",
            "value" => "level_0_data"
          },
          %{
            "name" => "level_1_nested",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "level_1",
              "steps" => [
                %{
                  "name" => "level_1_step",
                  "type" => "test_echo",
                  "value" => "level_1_data"
                },
                %{
                  "name" => "level_2_nested",
                  "type" => "pipeline",
                  "pipeline" => %{
                    "name" => "level_2",
                    "steps" => [
                      %{
                        "name" => "level_2_step",
                        "type" => "test_echo",
                        "value" => "level_2_data"
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }

    assert {:ok, results} = Executor.execute(pipeline)

    assert results["level_0_step"] == "level_0_data"
    assert results["level_1_nested"]["level_1_step"] == "level_1_data"
    assert results["level_1_nested"]["level_2_nested"]["level_2_step"] == "level_2_data"
  end
end
