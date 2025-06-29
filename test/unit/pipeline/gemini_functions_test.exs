defmodule Pipeline.GeminiFunctionsTest do
  use ExUnit.Case, async: false

  alias Pipeline.{Config, Executor, TestMode}
  alias Pipeline.Test.Mocks

  setup do
    # Set test mode
    System.put_env("TEST_MODE", "mock")
    TestMode.set_test_context(:unit)

    # Reset mocks
    Mocks.GeminiProvider.reset()
    Mocks.ClaudeProvider.reset()

    # Clean up any test directories
    on_exit(fn ->
      File.rm_rf("/tmp/test_workspace")
      File.rm_rf("/tmp/test_outputs")
      TestMode.clear_test_context()
    end)

    :ok
  end

  describe "gemini_functions configuration" do
    test "validates gemini_functions configuration in workflow" do
      config = %{
        "workflow" => %{
          "name" => "functions_test",
          "gemini_functions" => %{
            "evaluate_code" => %{
              "description" => "Evaluate code quality and security",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "quality_score" => %{
                    "type" => "integer",
                    "description" => "Score from 1-10"
                  },
                  "security_issues" => %{
                    "type" => "array",
                    "items" => %{"type" => "string"}
                  }
                },
                "required" => ["quality_score", "security_issues"]
              }
            }
          },
          "steps" => [
            %{
              "name" => "analyze",
              "type" => "gemini",
              "functions" => ["evaluate_code"],
              "prompt" => [%{"type" => "static", "content" => "Analyze code"}]
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "executes gemini step with function calling" do
      workflow = %{
        "workflow" => %{
          "name" => "function_calling_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "gemini_functions" => %{
            "analyze_requirements" => %{
              "description" => "Analyze project requirements",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "complexity" => %{"type" => "string", "enum" => ["low", "medium", "high"]},
                  "technologies" => %{"type" => "array", "items" => %{"type" => "string"}},
                  "estimated_hours" => %{"type" => "integer"}
                },
                "required" => ["complexity", "technologies"]
              }
            }
          },
          "steps" => [
            %{
              "name" => "analyze_project",
              "type" => "gemini",
              "functions" => ["analyze_requirements"],
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Analyze these requirements and call analyze_requirements function"
                }
              ]
            }
          ]
        }
      }

      # Mock function calling response
      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["analyze_project"]["success"] == true
      assert Map.has_key?(results["analyze_project"], "function_calls")
    end

    test "handles multiple function definitions" do
      workflow = %{
        "workflow" => %{
          "name" => "multiple_functions_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "gemini_functions" => %{
            "evaluate_security" => %{
              "description" => "Evaluate security aspects",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "vulnerabilities" => %{"type" => "array", "items" => %{"type" => "string"}},
                  "security_score" => %{"type" => "integer", "minimum" => 1, "maximum" => 10}
                }
              }
            },
            "evaluate_performance" => %{
              "description" => "Evaluate performance aspects",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "bottlenecks" => %{"type" => "array", "items" => %{"type" => "string"}},
                  "performance_score" => %{"type" => "integer", "minimum" => 1, "maximum" => 10}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "comprehensive_analysis",
              "type" => "gemini",
              "functions" => ["evaluate_security", "evaluate_performance"],
              "prompt" => [
                %{
                  "type" => "static",
                  "content" =>
                    "Perform comprehensive analysis using both security and performance evaluation"
                }
              ]
            }
          ]
        }
      }

      # Mock multiple function calls
      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["comprehensive_analysis"]["success"] == true
      assert length(results["comprehensive_analysis"]["function_calls"]) == 2
    end

    test "validates function references in steps" do
      config = %{
        "workflow" => %{
          "name" => "invalid_function_ref",
          "gemini_functions" => %{
            "valid_function" => %{
              "description" => "A valid function",
              "parameters" => %{"type" => "object", "properties" => %{}}
            }
          },
          "steps" => [
            %{
              "name" => "invalid_step",
              "type" => "gemini",
              "functions" => ["nonexistent_function"],
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "references undefined function")
    end

    test "handles function calling with previous response context" do
      workflow = %{
        "workflow" => %{
          "name" => "function_with_context_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "gemini_functions" => %{
            "generate_tests" => %{
              "description" => "Generate test cases based on code analysis",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "test_type" => %{"type" => "string", "enum" => ["unit", "integration", "e2e"]},
                  "test_cases" => %{"type" => "array", "items" => %{"type" => "string"}},
                  "coverage_target" => %{"type" => "integer", "minimum" => 50, "maximum" => 100}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "code_analysis",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "Analyze this code structure"}]
            },
            %{
              "name" => "test_generation",
              "type" => "gemini",
              "functions" => ["generate_tests"],
              "prompt" => [
                %{"type" => "static", "content" => "Based on this analysis:"},
                %{"type" => "previous_response", "step" => "code_analysis"},
                %{
                  "type" => "static",
                  "content" => "Generate appropriate tests using generate_tests function"
                }
              ]
            }
          ]
        }
      }

      # Mock responses
      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["code_analysis"]["success"] == true
      assert results["test_generation"]["success"] == true
      assert Map.has_key?(results["test_generation"], "function_calls")
    end

    test "handles function calling errors gracefully" do
      workflow = %{
        "workflow" => %{
          "name" => "function_error_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "gemini_functions" => %{
            "failing_function" => %{
              "description" => "A function that will fail",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "input" => %{"type" => "string"}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "failing_step",
              "type" => "gemini",
              "functions" => ["failing_function"],
              "prompt" => [%{"type" => "static", "content" => "This will fail"}]
            }
          ]
        }
      }

      # Mock function calling failure
      # Mock responses are handled automatically by pattern matching

      assert {:error, reason} = Executor.execute(workflow)
      assert String.contains?(reason, "failing_step")
    end

    test "validates complex function parameter schemas" do
      config = %{
        "workflow" => %{
          "name" => "complex_schema_test",
          "gemini_functions" => %{
            "complex_function" => %{
              "description" => "Function with complex parameter schema",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "metadata" => %{
                    "type" => "object",
                    "properties" => %{
                      "version" => %{"type" => "string"},
                      "author" => %{"type" => "string"},
                      "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
                    },
                    "required" => ["version", "author"]
                  },
                  "configurations" => %{
                    "type" => "array",
                    "items" => %{
                      "type" => "object",
                      "properties" => %{
                        "name" => %{"type" => "string"},
                        "enabled" => %{"type" => "boolean"},
                        "settings" => %{"type" => "object"}
                      }
                    }
                  }
                },
                "required" => ["metadata"]
              }
            }
          },
          "steps" => [
            %{
              "name" => "complex_step",
              "type" => "gemini",
              "functions" => ["complex_function"],
              "prompt" => [%{"type" => "static", "content" => "Use complex function"}]
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "supports function calling with different gemini models" do
      workflow = %{
        "workflow" => %{
          "name" => "model_specific_functions",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{
            "output_dir" => "/tmp/test_outputs",
            "gemini_model" => "gemini-2.5-pro"
          },
          "gemini_functions" => %{
            "advanced_analysis" => %{
              "description" => "Advanced analysis requiring pro model",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "analysis_depth" => %{
                    "type" => "string",
                    "enum" => ["shallow", "deep", "comprehensive"]
                  },
                  "insights" => %{"type" => "array", "items" => %{"type" => "string"}}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "pro_analysis",
              "type" => "gemini",
              "model" => "gemini-2.5-pro",
              "functions" => ["advanced_analysis"],
              "prompt" => [%{"type" => "static", "content" => "Perform advanced analysis"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["pro_analysis"]["success"] == true
    end

    test "handles functions field as empty list" do
      workflow = %{
        "workflow" => %{
          "name" => "empty_functions_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "gemini_functions" => %{
            "unused_function" => %{
              "description" => "An unused function",
              "parameters" => %{"type" => "object", "properties" => %{}}
            }
          },
          "steps" => [
            %{
              "name" => "no_functions_step",
              "type" => "gemini",
              "functions" => [],
              "prompt" => [
                %{"type" => "static", "content" => "Regular gemini step without functions"}
              ]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["no_functions_step"]["success"] == true
      refute Map.has_key?(results["no_functions_step"], "function_calls")
    end

    test "handles missing functions field" do
      workflow = %{
        "workflow" => %{
          "name" => "missing_functions_test",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "gemini_functions" => %{
            "available_function" => %{
              "description" => "An available function",
              "parameters" => %{"type" => "object", "properties" => %{}}
            }
          },
          "steps" => [
            %{
              "name" => "step_without_functions",
              "type" => "gemini",
              # No functions field specified
              "prompt" => [%{"type" => "static", "content" => "Regular gemini step"}]
            }
          ]
        }
      }

      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["step_without_functions"]["success"] == true
    end
  end

  describe "function definition validation" do
    test "validates function definition structure" do
      config = %{
        "workflow" => %{
          "name" => "validation_test",
          "gemini_functions" => %{
            "valid_function" => %{
              "description" => "A properly defined function",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "param1" => %{"type" => "string"},
                  "param2" => %{"type" => "integer"}
                },
                "required" => ["param1"]
              }
            }
          },
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "gemini",
              "functions" => ["valid_function"],
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "rejects function definition without description" do
      config = %{
        "workflow" => %{
          "name" => "invalid_function_test",
          "gemini_functions" => %{
            "invalid_function" => %{
              # Missing description
              "parameters" => %{
                "type" => "object",
                "properties" => %{}
              }
            }
          },
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "gemini",
              "functions" => ["invalid_function"],
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "missing 'description'")
    end

    test "rejects function definition without parameters" do
      config = %{
        "workflow" => %{
          "name" => "invalid_function_test",
          "gemini_functions" => %{
            "invalid_function" => %{
              "description" => "Function without parameters"
              # Missing parameters
            }
          },
          "steps" => [
            %{
              "name" => "test_step",
              "type" => "gemini",
              "functions" => ["invalid_function"],
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "missing 'parameters'")
    end
  end
end
