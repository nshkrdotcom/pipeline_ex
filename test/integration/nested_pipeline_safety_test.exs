defmodule Pipeline.Integration.NestedPipelineSafetyTest do
  use ExUnit.Case

  @moduletag :integration

  describe "safety features integration" do
    test "prevents infinite recursion with depth limits" do
      # Create a pipeline that tries to call itself
      recursive_pipeline = %{
        "workflow" => %{
          "name" => "recursive_test",
          "steps" => [
            %{
              "name" => "recursive_call",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "self_calling",
                "steps" => [
                  %{
                    "name" => "call_self",
                    "type" => "pipeline",
                    "pipeline_file" => "./test/fixtures/pipelines/recursive_pipeline.yaml",
                    "config" => %{
                      "max_depth" => 3
                    }
                  }
                ]
              },
              "config" => %{
                "max_depth" => 3
              }
            }
          ]
        }
      }

      # Create a fixture file that calls itself
      recursive_fixture = %{
        "workflow" => %{
          "name" => "recursive_fixture",
          "steps" => [
            %{
              "name" => "recurse",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/recursive_pipeline.yaml",
              "config" => %{
                "max_depth" => 3
              }
            }
          ]
        }
      }

      # Write the recursive fixture
      fixture_path = "./test/fixtures/pipelines/recursive_pipeline.yaml"
      File.mkdir_p!(Path.dirname(fixture_path))
      File.write!(fixture_path, Jason.encode!(recursive_fixture))

      # Execute and expect it to fail with recursion limit
      assert {:error, error_message} = Pipeline.execute(recursive_pipeline)
      assert error_message =~ "Maximum nesting depth"

      # Clean up
      File.rm_rf!(fixture_path)
    end

    test "detects circular dependencies" do
      # Create pipeline A that calls pipeline B
      pipeline_a = %{
        "workflow" => %{
          "name" => "pipeline_a",
          "steps" => [
            %{
              "name" => "call_b",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/pipeline_b.yaml"
            }
          ]
        }
      }

      # Create pipeline B that calls pipeline A (circular)
      pipeline_b = %{
        "workflow" => %{
          "name" => "pipeline_b",
          "steps" => [
            %{
              "name" => "call_a",
              "type" => "pipeline",
              "pipeline_file" => "./test/fixtures/pipelines/pipeline_a.yaml"
            }
          ]
        }
      }

      # Write fixtures
      File.mkdir_p!("./test/fixtures/pipelines")
      File.write!("./test/fixtures/pipelines/pipeline_a.yaml", Jason.encode!(pipeline_a))
      File.write!("./test/fixtures/pipelines/pipeline_b.yaml", Jason.encode!(pipeline_b))

      # Execute and expect circular dependency error
      assert {:error, error_message} = Pipeline.execute(pipeline_a)
      assert error_message =~ "Circular dependency detected"

      # Clean up
      File.rm!("./test/fixtures/pipelines/pipeline_a.yaml")
      File.rm!("./test/fixtures/pipelines/pipeline_b.yaml")
    end

    test "enforces step count limits" do
      # Create a pipeline with many steps that would exceed the limit
      many_steps =
        for i <- 1..50 do
          %{
            "name" => "step_#{i}",
            "type" => "test_echo",
            "value" => "step #{i} result"
          }
        end

      large_nested_pipeline = %{
        "workflow" => %{
          "name" => "large_nested",
          "steps" => many_steps
        }
      }

      main_pipeline = %{
        "workflow" => %{
          "name" => "step_limit_test",
          "steps" => [
            # Create multiple nested pipelines to exceed step count
            %{
              "name" => "nested1",
              "type" => "pipeline",
              "pipeline" => large_nested_pipeline["workflow"],
              "config" => %{
                # Set low limit
                "max_total_steps" => 100
              }
            },
            %{
              "name" => "nested2",
              "type" => "pipeline",
              "pipeline" => large_nested_pipeline["workflow"],
              "config" => %{
                "max_total_steps" => 100
              }
            },
            %{
              "name" => "nested3",
              "type" => "pipeline",
              "pipeline" => large_nested_pipeline["workflow"],
              "config" => %{
                "max_total_steps" => 100
              }
            }
          ]
        }
      }

      # Execute and expect step count limit error
      assert {:error, error_message} = Pipeline.execute(main_pipeline)
      assert error_message =~ "Maximum total steps" or error_message =~ "Safety violation"
    end

    test "handles memory pressure monitoring" do
      # Create a pipeline that should trigger memory monitoring
      pipeline = %{
        "workflow" => %{
          "name" => "memory_test",
          "steps" => [
            %{
              "name" => "nested_with_limits",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "memory_limited",
                "steps" => [
                  %{
                    "name" => "echo_step",
                    "type" => "test_echo",
                    "value" => "memory test"
                  }
                ]
              },
              "config" => %{
                # 2GB - reasonable limit
                "memory_limit_mb" => 2048,
                "timeout_seconds" => 30
              }
            }
          ]
        }
      }

      # This should succeed with normal memory usage
      assert {:ok, results} = Pipeline.execute(pipeline)
      assert results["nested_with_limits"] == "memory test"
    end

    test "handles execution timeout monitoring" do
      # Create a pipeline with very short timeout to test monitoring
      pipeline = %{
        "workflow" => %{
          "name" => "timeout_test",
          "steps" => [
            %{
              "name" => "quick_nested",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "quick_task",
                "steps" => [
                  %{
                    "name" => "fast_echo",
                    "type" => "test_echo",
                    "value" => "quick result"
                  }
                ]
              },
              "config" => %{
                # Should be plenty for a simple echo
                "timeout_seconds" => 30
              }
            }
          ]
        }
      }

      # This should succeed as it's a quick operation
      assert {:ok, results} = Pipeline.execute(pipeline)
      assert results["quick_nested"] == "quick result"
    end

    test "workspace isolation and cleanup" do
      # Create a pipeline that uses workspace
      pipeline = %{
        "workflow" => %{
          "name" => "workspace_test",
          "steps" => [
            %{
              "name" => "workspace_step",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "workspace_user",
                "steps" => [
                  %{
                    "name" => "echo_in_workspace",
                    "type" => "test_echo",
                    "value" => "workspace result"
                  }
                ]
              },
              "config" => %{
                "workspace_enabled" => true,
                "cleanup_on_error" => true
              }
            }
          ]
        }
      }

      # Execute successfully
      assert {:ok, results} = Pipeline.execute(pipeline)
      assert results["workspace_step"] == "workspace result"

      # Workspace should be cleaned up after execution
      # We can't easily test this without more introspection into the workspace paths
    end

    test "error handling and cleanup on failure" do
      # Create a pipeline that will fail to test cleanup
      failing_pipeline = %{
        "workflow" => %{
          "name" => "failing_test",
          "steps" => [
            %{
              "name" => "will_fail",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "failure_nested",
                "steps" => [
                  %{
                    "name" => "good_step",
                    "type" => "test_echo",
                    "value" => "this works"
                  },
                  %{
                    "name" => "bad_step",
                    # This will cause failure
                    "type" => "nonexistent_type",
                    "value" => "this fails"
                  }
                ]
              },
              "config" => %{
                "cleanup_on_error" => true,
                "workspace_enabled" => true
              }
            }
          ]
        }
      }

      # Execute and expect failure
      assert {:error, error_message} = Pipeline.execute(failing_pipeline)
      assert error_message =~ "nonexistent_type" or error_message =~ "unknown step type"

      # Cleanup should have happened automatically
    end

    test "nested safety contexts maintain proper hierarchy" do
      # Create deeply nested pipelines to test context hierarchy
      level3_pipeline = %{
        "name" => "level3",
        "steps" => [
          %{
            "name" => "deep_echo",
            "type" => "test_echo",
            "value" => "level 3 result"
          }
        ]
      }

      level2_pipeline = %{
        "name" => "level2",
        "steps" => [
          %{
            "name" => "call_level3",
            "type" => "pipeline",
            "pipeline" => level3_pipeline,
            "config" => %{
              "max_depth" => 5
            }
          }
        ]
      }

      level1_pipeline = %{
        "name" => "level1",
        "steps" => [
          %{
            "name" => "call_level2",
            "type" => "pipeline",
            "pipeline" => level2_pipeline,
            "config" => %{
              "max_depth" => 5
            }
          }
        ]
      }

      main_pipeline = %{
        "workflow" => %{
          "name" => "hierarchy_test",
          "steps" => [
            %{
              "name" => "call_level1",
              "type" => "pipeline",
              "pipeline" => level1_pipeline,
              "config" => %{
                "max_depth" => 5
              }
            }
          ]
        }
      }

      # This should succeed with proper depth tracking
      assert {:ok, results} = Pipeline.execute(main_pipeline)
      assert results["call_level1"] == "level 3 result"
    end

    test "custom safety limits override defaults" do
      # Create a pipeline with custom safety limits
      pipeline = %{
        "workflow" => %{
          "name" => "custom_limits_test",
          "steps" => [
            %{
              "name" => "limited_nested",
              "type" => "pipeline",
              "pipeline" => %{
                "name" => "simple_nested",
                "steps" => [
                  %{
                    "name" => "echo_result",
                    "type" => "test_echo",
                    "value" => "custom limits work"
                  }
                ]
              },
              "config" => %{
                "max_depth" => 2,
                "max_total_steps" => 50,
                "memory_limit_mb" => 512,
                "timeout_seconds" => 60,
                "workspace_enabled" => false,
                "cleanup_on_error" => false
              }
            }
          ]
        }
      }

      # Should succeed with custom limits
      assert {:ok, results} = Pipeline.execute(pipeline)
      assert results["limited_nested"] == "custom limits work"
    end
  end
end

