defmodule Pipeline.WorkflowScenariosTest do
  use Pipeline.Test.Case, mode: :mixed

  alias Pipeline.{Config, Executor}
  alias Pipeline.Test.Mocks

  @moduletag :integration

  setup do
    # Set up mocks only in mock mode (Pipeline.Test.Case handles TEST_MODE)
    if Pipeline.TestMode.mock_mode?() do
      # Setup mock responses for integration scenarios
      setup_integration_mocks()
    end

    # Clean up any test directories
    on_exit(fn ->
      File.rm_rf("/tmp/integration_workspace")
      File.rm_rf("/tmp/integration_outputs")
      File.rm_rf("/tmp/integration_files")
      File.rm_rf("./checkpoints")
    end)

    # Create test files directory
    File.mkdir_p!("/tmp/integration_files")

    :ok
  end

  describe "complete workflow scenarios" do
    test "code review and improvement workflow" do
      # Create source file to review
      source_code = """
      def calculate_total(items):
          total = 0
          for item in items:
              if item.price > 0:
                  total += item.price
          return total

      def process_payment(amount, method="credit"):
          if method == "credit":
              return charge_credit_card(amount)
          else:
              return process_cash(amount)
      """

      source_file = "/tmp/integration_files/payment.py"
      File.write!(source_file, source_code)

      workflow = %{
        "workflow" => %{
          "name" => "code_review_workflow",
          "workspace_dir" => "/tmp/integration_workspace",
          "checkpoint_enabled" => false,
          "defaults" => %{
            "output_dir" => "/tmp/integration_outputs",
            "gemini_model" => "gemini-2.5-flash"
          },
          "gemini_functions" => %{
            "analyze_code_quality" => %{
              "description" => "Analyze code quality and identify issues",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "quality_score" => %{"type" => "integer", "minimum" => 1, "maximum" => 10},
                  "issues" => %{
                    "type" => "array",
                    "items" => %{
                      "type" => "object",
                      "properties" => %{
                        "type" => %{
                          "type" => "string",
                          "enum" => ["bug", "style", "performance", "security"]
                        },
                        "severity" => %{
                          "type" => "string",
                          "enum" => ["low", "medium", "high", "critical"]
                        },
                        "description" => %{"type" => "string"},
                        "line" => %{"type" => "integer"}
                      }
                    }
                  },
                  "suggestions" => %{"type" => "array", "items" => %{"type" => "string"}}
                },
                "required" => ["quality_score", "issues", "suggestions"]
              }
            }
          },
          "steps" => [
            %{
              "name" => "code_analysis",
              "type" => "gemini",
              "functions" => ["analyze_code_quality"],
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Analyze this Python code for quality, bugs, and improvements:"
                },
                %{"type" => "file", "path" => source_file}
              ],
              "output_to_file" => "code_analysis.json"
            },
            %{
              "name" => "generate_improvements",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 15,
                "allowed_tools" => ["Write", "Edit", "Read"],
                "system_prompt" => "You are an expert Python developer focused on code quality."
              },
              "prompt" => [
                %{"type" => "static", "content" => "Based on this code analysis:"},
                %{"type" => "previous_response", "step" => "code_analysis"},
                %{
                  "type" => "static",
                  "content" =>
                    "\nImprove the original code addressing all identified issues. Create an improved version."
                }
              ],
              "output_to_file" => "improved_code.py"
            },
            %{
              "name" => "create_tests",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 10,
                "allowed_tools" => ["Write", "Read"],
                "cwd" => "/tmp/integration_workspace/tests"
              },
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Create comprehensive unit tests for the improved code:"
                },
                %{"type" => "previous_response", "step" => "generate_improvements"},
                %{
                  "type" => "static",
                  "content" => "\nInclude edge cases and error handling tests."
                }
              ],
              "output_to_file" => "test_payment.py"
            },
            %{
              "name" => "final_review",
              "type" => "gemini",
              "prompt" => [
                %{"type" => "static", "content" => "Review the complete solution:"},
                %{"type" => "static", "content" => "\n\nOriginal Analysis:"},
                %{
                  "type" => "previous_response",
                  "step" => "code_analysis",
                  "extract" => "suggestions"
                },
                %{"type" => "static", "content" => "\n\nImproved Code:"},
                %{"type" => "previous_response", "step" => "generate_improvements"},
                %{"type" => "static", "content" => "\n\nTest Coverage:"},
                %{"type" => "previous_response", "step" => "create_tests"},
                %{
                  "type" => "static",
                  "content" => "\n\nProvide a final assessment of the improvements."
                }
              ],
              "output_to_file" => "final_review.json"
            }
          ]
        }
      }

      # Mocks are set up automatically in setup() for mock mode

      result = Executor.execute(workflow)

      case result do
        {:ok, results} ->
          IO.inspect(results, label: "Workflow results")
          # Verify all steps completed successfully
          assert results["code_analysis"]["success"] == true
          assert results["generate_improvements"]["success"] == true
          assert results["create_tests"]["success"] == true
          assert results["final_review"]["success"] == true

        {:error, reason} ->
          IO.puts("Workflow failed: #{reason}")
          # Re-assert to fail the test with the original assertion
          assert {:ok, _results} = result
      end

      # Verify outputs were created
      assert File.exists?("/tmp/integration_outputs/code_analysis.json")
      assert File.exists?("/tmp/integration_outputs/improved_code.py")
      assert File.exists?("/tmp/integration_outputs/test_payment.py")
      assert File.exists?("/tmp/integration_outputs/final_review.json")
    end

    test "full-stack application development workflow" do
      # Create requirements file
      requirements = """
      # E-commerce API Requirements

      ## Core Features
      1. User authentication and authorization
      2. Product catalog management
      3. Shopping cart functionality
      4. Order processing
      5. Payment integration

      ## Technical Requirements
      - REST API using FastAPI
      - PostgreSQL database
      - Redis for caching
      - JWT authentication
      - Docker containerization

      ## Performance Goals
      - Handle 1000 concurrent users
      - Response time < 200ms
      - 99.9% uptime
      """

      requirements_file = "/tmp/integration_files/requirements.md"
      File.write!(requirements_file, requirements)

      workflow = %{
        "workflow" => %{
          "name" => "fullstack_development",
          "workspace_dir" => "/tmp/integration_workspace",
          "checkpoint_enabled" => false,
          "defaults" => %{
            "output_dir" => "/tmp/integration_outputs",
            "gemini_model" => "gemini-2.5-pro",
            "gemini_token_budget" => %{
              "max_output_tokens" => 4096,
              "temperature" => 0.7
            }
          },
          "gemini_functions" => %{
            "design_architecture" => %{
              "description" => "Design application architecture",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "services" => %{
                    "type" => "array",
                    "items" => %{
                      "type" => "object",
                      "properties" => %{
                        "name" => %{"type" => "string"},
                        "purpose" => %{"type" => "string"},
                        "technologies" => %{"type" => "array", "items" => %{"type" => "string"}}
                      }
                    }
                  },
                  "database_schema" => %{
                    "type" => "array",
                    "items" => %{
                      "type" => "object",
                      "properties" => %{
                        "table" => %{"type" => "string"},
                        "purpose" => %{"type" => "string"}
                      }
                    }
                  },
                  "api_endpoints" => %{"type" => "array", "items" => %{"type" => "string"}}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "architecture_design",
              "type" => "gemini",
              "functions" => ["design_architecture"],
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Design a comprehensive architecture for these requirements:"
                },
                %{"type" => "file", "path" => requirements_file}
              ],
              "output_to_file" => "architecture.json"
            },
            %{
              "name" => "backend_implementation",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 25,
                "allowed_tools" => ["Write", "Edit", "Read", "Bash"],
                "cwd" => "/tmp/integration_workspace/backend",
                "system_prompt" =>
                  "You are a senior backend developer specializing in FastAPI and microservices."
              },
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Implement the backend based on this architecture:"
                },
                %{"type" => "previous_response", "step" => "architecture_design"},
                %{
                  "type" => "static",
                  "content" =>
                    "\nCreate the FastAPI application with all required endpoints and models."
                }
              ],
              "output_to_file" => "backend_code.py"
            },
            %{
              "name" => "database_setup",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 15,
                "allowed_tools" => ["Write", "Read"],
                "cwd" => "/tmp/integration_workspace/database"
              },
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Create database migrations and setup based on:"
                },
                %{
                  "type" => "previous_response",
                  "step" => "architecture_design",
                  "extract" => "database_schema"
                },
                %{
                  "type" => "static",
                  "content" => "\nInclude Alembic migrations and SQLAlchemy models."
                }
              ],
              "output_to_file" => "database_schema.sql"
            },
            %{
              "name" => "docker_setup",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 10,
                "allowed_tools" => ["Write", "Read"],
                "cwd" => "/tmp/integration_workspace"
              },
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Create Docker configuration for the entire application:"
                },
                %{
                  "type" => "previous_response",
                  "step" => "architecture_design",
                  "extract" => "services"
                },
                %{
                  "type" => "static",
                  "content" => "\nInclude Dockerfile, docker-compose.yml, and deployment scripts."
                }
              ],
              "output_to_file" => "docker-compose.yml"
            },
            %{
              "name" => "testing_strategy",
              "type" => "gemini",
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Design a comprehensive testing strategy for:"
                },
                %{"type" => "static", "content" => "\n\nArchitecture:"},
                %{"type" => "previous_response", "step" => "architecture_design"},
                %{"type" => "static", "content" => "\n\nBackend Implementation:"},
                %{"type" => "previous_response", "step" => "backend_implementation"},
                %{
                  "type" => "static",
                  "content" => "\n\nInclude unit, integration, and load testing approaches."
                }
              ],
              "output_to_file" => "testing_strategy.json"
            }
          ]
        }
      }

      # Mocks are set up automatically in setup() for mock mode

      assert {:ok, results} = Executor.execute(workflow)

      # Verify all steps completed
      assert results["architecture_design"]["success"] == true
      assert results["backend_implementation"]["success"] == true
      assert results["database_setup"]["success"] == true
      assert results["docker_setup"]["success"] == true
      assert results["testing_strategy"]["success"] == true

      # Verify structure was created
      assert File.exists?("/tmp/integration_outputs/architecture.json")
      assert File.exists?("/tmp/integration_outputs/backend_code.py")
      assert File.exists?("/tmp/integration_outputs/database_schema.sql")
      assert File.exists?("/tmp/integration_outputs/docker-compose.yml")
      assert File.exists?("/tmp/integration_outputs/testing_strategy.json")
    end

    test "data analysis and reporting workflow" do
      # Create sample data file
      sample_data = """
      timestamp,user_id,action,value,category
      2024-01-01 10:00:00,1001,purchase,59.99,electronics
      2024-01-01 10:15:00,1002,view,0,clothing
      2024-01-01 10:30:00,1001,purchase,29.99,books
      2024-01-01 11:00:00,1003,purchase,199.99,electronics
      2024-01-01 11:15:00,1002,purchase,49.99,clothing
      2024-01-01 12:00:00,1004,view,0,electronics
      2024-01-01 12:30:00,1001,return,29.99,books
      """

      data_file = "/tmp/integration_files/user_data.csv"
      File.write!(data_file, sample_data)

      workflow = %{
        "workflow" => %{
          "name" => "data_analysis_workflow",
          "workspace_dir" => "/tmp/integration_workspace",
          "defaults" => %{
            "output_dir" => "/tmp/integration_outputs",
            "gemini_model" => "gemini-2.5-flash"
          },
          "gemini_functions" => %{
            "analyze_patterns" => %{
              "description" => "Analyze data patterns and trends",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "key_insights" => %{"type" => "array", "items" => %{"type" => "string"}},
                  "metrics" => %{
                    "type" => "object",
                    "properties" => %{
                      "total_revenue" => %{"type" => "number"},
                      "unique_users" => %{"type" => "integer"},
                      "conversion_rate" => %{"type" => "number"}
                    }
                  },
                  "recommendations" => %{"type" => "array", "items" => %{"type" => "string"}}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "data_exploration",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 15,
                "allowed_tools" => ["Read", "Write", "Bash"],
                "system_prompt" => "You are a data analyst expert in Python and pandas."
              },
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Analyze this CSV data and provide initial exploration:"
                },
                %{"type" => "file", "path" => data_file},
                %{
                  "type" => "static",
                  "content" => "\nCreate Python code to load and explore the data."
                }
              ],
              "output_to_file" => "data_exploration.py"
            },
            %{
              "name" => "pattern_analysis",
              "type" => "gemini",
              "functions" => ["analyze_patterns"],
              "prompt" => [
                %{"type" => "static", "content" => "Based on the data exploration:"},
                %{"type" => "previous_response", "step" => "data_exploration"},
                %{
                  "type" => "static",
                  "content" => "\nAnalyze patterns and extract business insights."
                }
              ],
              "output_to_file" => "patterns.json"
            },
            %{
              "name" => "visualization",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 12,
                "allowed_tools" => ["Write", "Read"],
                "system_prompt" => "Create data visualizations using matplotlib and seaborn."
              },
              "prompt" => [
                %{"type" => "static", "content" => "Create visualizations for these insights:"},
                %{"type" => "previous_response", "step" => "pattern_analysis"},
                %{
                  "type" => "static",
                  "content" => "\nGenerate Python code for charts and graphs."
                }
              ],
              "output_to_file" => "visualizations.py"
            },
            %{
              "name" => "report_generation",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 10,
                "allowed_tools" => ["Write", "Read"]
              },
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Generate a comprehensive business report including:"
                },
                %{"type" => "static", "content" => "\n\nData Analysis:"},
                %{"type" => "previous_response", "step" => "data_exploration"},
                %{"type" => "static", "content" => "\n\nKey Insights:"},
                %{
                  "type" => "previous_response",
                  "step" => "pattern_analysis",
                  "extract" => "key_insights"
                },
                %{"type" => "static", "content" => "\n\nRecommendations:"},
                %{
                  "type" => "previous_response",
                  "step" => "pattern_analysis",
                  "extract" => "recommendations"
                },
                %{"type" => "static", "content" => "\n\nCreate a professional markdown report."}
              ],
              "output_to_file" => "business_report.md"
            }
          ]
        }
      }

      # Mocks are set up automatically in setup() for mock mode

      assert {:ok, results} = Executor.execute(workflow)

      # Verify completion
      assert results["data_exploration"]["success"] == true
      assert results["pattern_analysis"]["success"] == true
      assert results["visualization"]["success"] == true
      assert results["report_generation"]["success"] == true

      # Verify outputs
      assert File.exists?("/tmp/integration_outputs/data_exploration.py")
      assert File.exists?("/tmp/integration_outputs/patterns.json")
      assert File.exists?("/tmp/integration_outputs/visualizations.py")
      assert File.exists?("/tmp/integration_outputs/business_report.md")
    end

    test "complex workflow with error recovery" do
      workflow = %{
        "workflow" => %{
          "name" => "error_recovery_test",
          "workspace_dir" => "/tmp/integration_workspace",
          "checkpoint_enabled" => false,
          "defaults" => %{"output_dir" => "/tmp/integration_outputs"},
          "steps" => [
            %{
              "name" => "success_step",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "This will succeed"}]
            },
            %{
              "name" => "failing_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "error test"}]
            },
            %{
              "name" => "unreachable_step",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "This should not execute"}]
            }
          ]
        }
      }

      # Mocks are set up automatically in setup() for mock mode

      assert {:error, reason} = Executor.execute(workflow)
      assert String.contains?(reason, "failing_step")
    end

    test "workflow with all configuration features combined" do
      # Create configuration file
      config_content = """
      # Application Configuration

      database:
        host: localhost
        port: 5432
        name: myapp

      redis:
        host: localhost
        port: 6379

      features:
        - authentication
        - caching
        - logging
      """

      config_file = "/tmp/integration_files/app_config.yaml"
      File.write!(config_file, config_content)

      workflow = %{
        "workflow" => %{
          "name" => "comprehensive_feature_test",
          "workspace_dir" => "/tmp/integration_workspace",
          "checkpoint_enabled" => false,
          "checkpoint_dir" => "/tmp/integration_workspace/.checkpoints",
          "defaults" => %{
            "output_dir" => "/tmp/integration_outputs",
            "gemini_model" => "gemini-2.5-flash",
            "gemini_token_budget" => %{
              "max_output_tokens" => 2048,
              "temperature" => 0.5
            },
            "claude_options" => %{
              "max_turns" => 8,
              "verbose" => true
            }
          },
          "gemini_functions" => %{
            "validate_config" => %{
              "description" => "Validate application configuration",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "is_valid" => %{"type" => "boolean"},
                  "issues" => %{"type" => "array", "items" => %{"type" => "string"}},
                  "suggestions" => %{"type" => "array", "items" => %{"type" => "string"}}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "config_validation",
              "type" => "gemini",
              "functions" => ["validate_config"],
              "token_budget" => %{
                "max_output_tokens" => 1024,
                "temperature" => 0.3
              },
              "prompt" => [
                %{"type" => "static", "content" => "Validate this application configuration:"},
                %{"type" => "file", "path" => config_file}
              ],
              "output_to_file" => "config_validation.json"
            },
            %{
              "name" => "setup_implementation",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 12,
                "allowed_tools" => ["Write", "Edit", "Read"],
                "cwd" => "/tmp/integration_workspace/setup",
                "system_prompt" => "Create production-ready setup scripts."
              },
              "prompt" => [
                %{"type" => "static", "content" => "Based on this config validation:"},
                %{"type" => "previous_response", "step" => "config_validation"},
                %{"type" => "static", "content" => "\nAnd the original configuration:"},
                %{"type" => "file", "path" => config_file},
                %{"type" => "static", "content" => "\nCreate setup and deployment scripts."}
              ],
              "output_to_file" => "setup_scripts.sh"
            },
            %{
              "name" => "documentation",
              "type" => "claude",
              "claude_options" => %{
                "max_turns" => 6,
                "allowed_tools" => ["Write", "Read"]
              },
              "prompt" => [
                %{
                  "type" => "static",
                  "content" => "Create comprehensive documentation including:"
                },
                %{"type" => "static", "content" => "\n\nConfig Validation Results:"},
                %{
                  "type" => "previous_response",
                  "step" => "config_validation",
                  "extract" => "suggestions"
                },
                %{"type" => "static", "content" => "\n\nSetup Instructions:"},
                %{"type" => "previous_response", "step" => "setup_implementation"},
                %{"type" => "static", "content" => "\n\nGenerate markdown documentation."}
              ],
              "output_to_file" => "README.md"
            }
          ]
        }
      }

      # Mocks are set up automatically in setup() for mock mode

      assert {:ok, results} = Executor.execute(workflow)

      # Verify all advanced features worked
      assert results["config_validation"]["success"] == true
      assert results["setup_implementation"]["success"] == true
      assert results["documentation"]["success"] == true

      # Verify all outputs created
      assert File.exists?("/tmp/integration_outputs/config_validation.json")
      assert File.exists?("/tmp/integration_outputs/setup_scripts.sh")
      assert File.exists?("/tmp/integration_outputs/README.md")

      # Verify checkpoint directory was created
      assert File.exists?("/tmp/integration_workspace/.checkpoints")
    end
  end

  describe "workflow validation and error scenarios" do
    test "validates complete workflow configuration" do
      config = %{
        "workflow" => %{
          "name" => "validation_workflow",
          "workspace_dir" => "/tmp/workspace",
          "checkpoint_enabled" => false,
          "defaults" => %{
            "gemini_model" => "gemini-2.5-flash",
            "output_dir" => "/tmp/outputs"
          },
          "gemini_functions" => %{
            "test_function" => %{
              "description" => "Test function",
              "parameters" => %{
                "type" => "object",
                "properties" => %{
                  "result" => %{"type" => "string"}
                }
              }
            }
          },
          "steps" => [
            %{
              "name" => "step1",
              "type" => "gemini",
              "functions" => ["test_function"],
              "prompt" => [%{"type" => "static", "content" => "Test"}]
            },
            %{
              "name" => "step2",
              "type" => "claude",
              "prompt" => [
                %{"type" => "previous_response", "step" => "step1"}
              ]
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "handles workflow with missing dependencies gracefully" do
      workflow = %{
        "workflow" => %{
          "name" => "missing_deps_test",
          "workspace_dir" => "/tmp/integration_workspace",
          "defaults" => %{"output_dir" => "/tmp/integration_outputs"},
          "steps" => [
            %{
              "name" => "dependent_step",
              "type" => "claude",
              "prompt" => [
                %{"type" => "previous_response", "step" => "missing_step"}
              ]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(workflow)
      assert String.contains?(reason, "references non-existent steps")
    end
  end

  # Helper function to set up mocks for integration tests
  defp setup_integration_mocks do
    # Set up default mock responses that work for most integration scenarios

    # Claude responses
    Mocks.ClaudeProvider.set_response_pattern("", %{
      "success" => true,
      "text" => "Integration test mock response"
    })

    # Error test pattern
    Mocks.ClaudeProvider.set_response_pattern("error test", %{
      "success" => false,
      "error" => "Simulated error for testing"
    })

    Mocks.ClaudeProvider.set_response_pattern("improve", %{
      "success" => true,
      "text" => "Improved code with better error handling and validation"
    })

    Mocks.ClaudeProvider.set_response_pattern("tests", %{
      "success" => true,
      "text" => "Comprehensive unit tests for the module"
    })

    Mocks.ClaudeProvider.set_response_pattern("backend", %{
      "success" => true,
      "text" => "Complete FastAPI backend implementation"
    })

    Mocks.ClaudeProvider.set_response_pattern("database", %{
      "success" => true,
      "text" => "Database schema and migration scripts"
    })

    Mocks.ClaudeProvider.set_response_pattern("docker", %{
      "success" => true,
      "text" => "Complete Docker containerization setup"
    })

    Mocks.ClaudeProvider.set_response_pattern("exploration", %{
      "success" => true,
      "text" => "Python data exploration code with pandas analysis"
    })

    Mocks.ClaudeProvider.set_response_pattern("visualization", %{
      "success" => true,
      "text" => "Python visualization code with matplotlib charts"
    })

    Mocks.ClaudeProvider.set_response_pattern("report", %{
      "success" => true,
      "text" => "Comprehensive business analysis report"
    })

    Mocks.ClaudeProvider.set_response_pattern("setup", %{
      "success" => true,
      "text" => "Complete setup and deployment scripts"
    })

    Mocks.ClaudeProvider.set_response_pattern("documentation", %{
      "success" => true,
      "text" => "Comprehensive project documentation"
    })

    # Error response for testing failure scenarios
    Mocks.ClaudeProvider.set_response_pattern("error", %{
      "success" => false,
      "error" => "Intentional failure for testing"
    })

    # Gemini responses
    Mocks.GeminiProvider.set_response_pattern("", %{
      "success" => true,
      "content" => "Integration test mock response"
    })

    Mocks.GeminiProvider.set_response_pattern("analysis", %{
      "success" => true,
      "content" => "Code analysis: Found patterns and potential improvements",
      "key_insights" => [
        "Data shows strong seasonal patterns",
        "Customer retention is increasing",
        "Revenue growth is consistent"
      ],
      "recommendations" => [
        "Focus on Q4 marketing",
        "Expand customer success team",
        "Invest in automation"
      ]
    })

    Mocks.GeminiProvider.set_response_pattern("review", %{
      "success" => true,
      "content" => "Final review: All issues addressed, quality improved"
    })

    Mocks.GeminiProvider.set_response_pattern("testing", %{
      "success" => true,
      "content" => "Comprehensive testing strategy for the application"
    })

    Mocks.GeminiProvider.set_response_pattern("succeed", %{
      "success" => true,
      "content" => "Successful step completed"
    })

    # Function calling responses
    Mocks.GeminiProvider.set_function_response("analyze_code_quality", %{
      "success" => true,
      "function_calls" => [
        %{
          "name" => "analyze_code_quality",
          "arguments" => %{
            "quality_score" => 7,
            "issues" => [
              %{
                "type" => "style",
                "severity" => "medium",
                "description" => "Consider adding type hints",
                "line" => 1
              }
            ],
            "suggestions" => [
              "Add input validation",
              "Implement proper error handling",
              "Add type hints"
            ]
          }
        }
      ],
      # Also include merged fields for template extraction
      "quality_score" => 7,
      "issues" => [
        %{
          "type" => "style",
          "severity" => "medium",
          "description" => "Consider adding type hints",
          "line" => 1
        }
      ],
      "suggestions" => [
        "Add input validation",
        "Implement proper error handling",
        "Add type hints"
      ]
    })

    Mocks.GeminiProvider.set_function_response("design_architecture", %{
      "success" => true,
      "function_calls" => [
        %{
          "name" => "design_architecture",
          "arguments" => %{
            "services" => [
              %{
                "name" => "auth-service",
                "purpose" => "Authentication",
                "technologies" => ["FastAPI", "JWT"]
              },
              %{
                "name" => "api-service",
                "purpose" => "Main API",
                "technologies" => ["FastAPI", "SQLAlchemy"]
              }
            ],
            "database_schema" => [
              %{"table" => "users", "purpose" => "User accounts"},
              %{"table" => "data", "purpose" => "Application data"}
            ],
            "api_endpoints" => ["/auth/login", "/api/data", "/api/status"]
          }
        }
      ],
      # Also include merged fields for template extraction
      "services" => [
        %{
          "name" => "auth-service",
          "purpose" => "Authentication",
          "technologies" => ["FastAPI", "JWT"]
        },
        %{
          "name" => "api-service",
          "purpose" => "Main API",
          "technologies" => ["FastAPI", "SQLAlchemy"]
        }
      ],
      "database_schema" => [
        %{"table" => "users", "purpose" => "User accounts"},
        %{"table" => "data", "purpose" => "Application data"}
      ],
      "api_endpoints" => ["/auth/login", "/api/data", "/api/status"]
    })

    Mocks.GeminiProvider.set_function_response("analyze_patterns", %{
      "success" => true,
      "function_calls" => [
        %{
          "name" => "analyze_patterns",
          "arguments" => %{
            "key_insights" => [
              "Data shows consistent growth patterns",
              "Key metrics are within expected ranges"
            ],
            "metrics" => %{
              "total_revenue" => 1000.0,
              "unique_users" => 50,
              "conversion_rate" => 0.8
            },
            "recommendations" => [
              "Continue current strategy",
              "Monitor key metrics closely"
            ]
          }
        }
      ],
      # Also include merged fields for template extraction
      "key_insights" => [
        "Data shows consistent growth patterns",
        "Key metrics are within expected ranges"
      ],
      "metrics" => %{
        "total_revenue" => 1000.0,
        "unique_users" => 50,
        "conversion_rate" => 0.8
      },
      "recommendations" => [
        "Continue current strategy",
        "Monitor key metrics closely"
      ]
    })

    Mocks.GeminiProvider.set_function_response("validate_config", %{
      "success" => true,
      "function_calls" => [
        %{
          "name" => "validate_config",
          "arguments" => %{
            "is_valid" => true,
            "issues" => [],
            "suggestions" => [
              "Consider adding SSL configuration",
              "Add monitoring setup"
            ]
          }
        }
      ],
      # Also include merged fields for template extraction
      "is_valid" => true,
      "issues" => [],
      "suggestions" => [
        "Consider adding SSL configuration",
        "Add monitoring setup"
      ]
    })
  end
end
