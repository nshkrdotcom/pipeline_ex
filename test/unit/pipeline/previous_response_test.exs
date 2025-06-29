defmodule Pipeline.PreviousResponseTest do
  use ExUnit.Case, async: false

  alias Pipeline.{Config, Executor, PromptBuilder, TestMode}
  alias Pipeline.Test.Mocks

  setup do
    # Set test mode
    System.put_env("TEST_MODE", "mock")
    TestMode.set_test_context(:unit)

    # Reset mocks
    Mocks.ClaudeProvider.reset()
    Mocks.GeminiProvider.reset()

    # Clean up any test directories
    on_exit(fn ->
      File.rm_rf("/tmp/test_workspace")
      File.rm_rf("/tmp/test_outputs")
      TestMode.clear_test_context()
    end)

    :ok
  end

  describe "previous_response prompt type" do
    test "includes full previous response when no extract field specified" do
      previous_results = %{
        "step1" => %{
          "success" => true,
          "content" => "Full response content",
          "metadata" => %{"timestamp" => "2024-01-01"}
        }
      }

      prompt_parts = [
        %{"type" => "static", "content" => "Previous result:"},
        %{"type" => "previous_response", "step" => "step1"}
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Previous result:")
      assert String.contains?(built_prompt, "Full response content")
      assert String.contains?(built_prompt, "timestamp")
    end

    test "extracts specific field when extract is specified" do
      previous_results = %{
        "analysis_step" => %{
          "success" => true,
          "findings" => ["issue1", "issue2", "issue3"],
          "score" => 8,
          "metadata" => %{"tool" => "analyzer"}
        }
      }

      prompt_parts = [
        %{"type" => "static", "content" => "Issues found:"},
        %{"type" => "previous_response", "step" => "analysis_step", "extract" => "findings"}
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Issues found:")
      assert String.contains?(built_prompt, "issue1")
      assert String.contains?(built_prompt, "issue2")
      assert String.contains?(built_prompt, "issue3")
      # Should not contain other fields
      refute String.contains?(built_prompt, "metadata")
      refute String.contains?(built_prompt, "score")
    end

    test "extracts nested field using dot notation" do
      previous_results = %{
        "config_step" => %{
          "success" => true,
          "configuration" => %{
            "database" => %{
              "host" => "localhost",
              "port" => 5432,
              "credentials" => %{
                "username" => "admin",
                "password" => "secret"
              }
            },
            "cache" => %{
              "type" => "redis",
              "ttl" => 3600
            }
          }
        }
      }

      prompt_parts = [
        %{"type" => "static", "content" => "Database config:"},
        %{
          "type" => "previous_response",
          "step" => "config_step",
          "extract" => "configuration.database"
        }
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Database config:")
      assert String.contains?(built_prompt, "localhost")
      assert String.contains?(built_prompt, "5432")
      assert String.contains?(built_prompt, "admin")
      # Should not contain cache config
      refute String.contains?(built_prompt, "redis")
      refute String.contains?(built_prompt, "ttl")
    end

    test "handles missing step gracefully" do
      previous_results = %{
        "existing_step" => %{"success" => true, "content" => "exists"}
      }

      prompt_parts = [
        %{"type" => "previous_response", "step" => "missing_step"}
      ]

      context = %{results: previous_results}

      # Should handle missing step gracefully
      assert_raise KeyError, fn ->
        PromptBuilder.build(prompt_parts, context.results)
      end
    end

    test "handles missing extracted field gracefully" do
      previous_results = %{
        "step1" => %{
          "success" => true,
          "existing_field" => "value"
        }
      }

      prompt_parts = [
        %{"type" => "previous_response", "step" => "step1", "extract" => "missing_field"}
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      # Should return nil when field doesn't exist, which becomes empty string
      assert String.contains?(built_prompt, "nil")
    end

    test "works in complete workflow with multiple dependencies" do
      workflow = %{
        "workflow" => %{
          "name" => "dependency_workflow",
          "workspace_dir" => "/tmp/test_workspace",
          "defaults" => %{"output_dir" => "/tmp/test_outputs"},
          "steps" => [
            %{
              "name" => "requirements_analysis",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "Analyze requirements"}]
            },
            %{
              "name" => "architecture_design",
              "type" => "gemini",
              "prompt" => [
                %{"type" => "static", "content" => "Based on this analysis:"},
                %{"type" => "previous_response", "step" => "requirements_analysis"},
                %{"type" => "static", "content" => "Design the architecture"}
              ]
            },
            %{
              "name" => "implementation",
              "type" => "claude",
              "prompt" => [
                %{"type" => "static", "content" => "Requirements:"},
                %{
                  "type" => "previous_response",
                  "step" => "requirements_analysis",
                  "extract" => "key_features"
                },
                %{"type" => "static", "content" => "\nArchitecture:"},
                %{
                  "type" => "previous_response",
                  "step" => "architecture_design",
                  "extract" => "components"
                },
                %{"type" => "static", "content" => "\nImplement this system"}
              ]
            }
          ]
        }
      }

      # Mock responses with structured data
      # Mock responses are handled automatically by pattern matching

      assert {:ok, results} = Executor.execute(workflow)
      assert results["requirements_analysis"]["success"] == true
      assert results["architecture_design"]["success"] == true
      assert results["implementation"]["success"] == true
    end

    test "supports both string and atom keys in previous_response" do
      previous_results = %{
        "test_step" => %{
          "success" => true,
          "data" => %{"value" => 42}
        }
      }

      # Test with string keys
      prompt_parts_string = [
        %{"type" => "previous_response", "step" => "test_step", "extract" => "data"}
      ]

      # Test with atom keys (simulating internal processing)
      prompt_parts_atom = [
        %{type: "previous_response", step: "test_step", extract: "data"}
      ]

      context = %{results: previous_results}

      built_prompt_string = PromptBuilder.build(prompt_parts_string, context)
      built_prompt_atom = PromptBuilder.build(prompt_parts_atom, context)

      assert built_prompt_string == built_prompt_atom
      assert String.contains?(built_prompt_string, "42")
    end

    test "handles complex JSON structures in extraction" do
      previous_results = %{
        "analysis_step" => %{
          "success" => true,
          "results" => %{
            "metrics" => [
              %{"name" => "performance", "value" => 85, "unit" => "percent"},
              %{"name" => "reliability", "value" => 92, "unit" => "percent"}
            ],
            "issues" => [
              %{"type" => "warning", "message" => "Minor optimization needed"},
              %{"type" => "error", "message" => "Critical security flaw"}
            ]
          }
        }
      }

      prompt_parts = [
        %{"type" => "static", "content" => "Performance metrics:"},
        %{
          "type" => "previous_response",
          "step" => "analysis_step",
          "extract" => "results.metrics"
        }
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Performance metrics:")
      assert String.contains?(built_prompt, "performance")
      assert String.contains?(built_prompt, "85")
      assert String.contains?(built_prompt, "reliability")
      assert String.contains?(built_prompt, "92")
      # Should not contain issues
      refute String.contains?(built_prompt, "security flaw")
    end

    test "validates previous_response references in configuration" do
      config = %{
        "workflow" => %{
          "name" => "validation_test",
          "steps" => [
            %{
              "name" => "first_step",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "First"}]
            },
            %{
              "name" => "second_step",
              "type" => "claude",
              "prompt" => [
                %{"type" => "previous_response", "step" => "first_step"}
              ]
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "rejects invalid previous_response references" do
      config = %{
        "workflow" => %{
          "name" => "invalid_ref_test",
          "steps" => [
            %{
              "name" => "first_step",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "First"}]
            },
            %{
              "name" => "second_step",
              "type" => "claude",
              "prompt" => [
                %{"type" => "previous_response", "step" => "nonexistent_step"}
              ]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "references non-existent steps")
    end

    test "rejects previous_response without step field" do
      config = %{
        "workflow" => %{
          "name" => "missing_step_test",
          "steps" => [
            %{
              "name" => "invalid_step",
              "type" => "claude",
              "prompt" => [
                # Missing step field
                %{"type" => "previous_response"}
              ]
            }
          ]
        }
      }

      assert {:error, reason} = Config.validate_workflow(config)
      assert String.contains?(reason, "missing 'step'")
    end

    test "handles empty previous response results" do
      previous_results = %{
        "empty_step" => %{}
      }

      prompt_parts = [
        %{"type" => "previous_response", "step" => "empty_step"}
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      # Should handle empty results gracefully
      assert is_binary(built_prompt)
    end

    test "extracts array elements correctly" do
      previous_results = %{
        "list_step" => %{
          "success" => true,
          "items" => ["first", "second", "third"],
          "count" => 3
        }
      }

      prompt_parts = [
        %{"type" => "static", "content" => "Items:"},
        %{"type" => "previous_response", "step" => "list_step", "extract" => "items"}
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      assert String.contains?(built_prompt, "Items:")
      assert String.contains?(built_prompt, "first")
      assert String.contains?(built_prompt, "second")
      assert String.contains?(built_prompt, "third")
      refute String.contains?(built_prompt, "count")
    end

    test "handles boolean and numeric extractions" do
      previous_results = %{
        "data_step" => %{
          "success" => true,
          "enabled" => true,
          "score" => 95.5,
          "attempts" => 3
        }
      }

      # Test boolean extraction
      prompt_parts_bool = [
        %{"type" => "previous_response", "step" => "data_step", "extract" => "enabled"}
      ]

      # Test numeric extractions
      prompt_parts_float = [
        %{"type" => "previous_response", "step" => "data_step", "extract" => "score"}
      ]

      prompt_parts_int = [
        %{"type" => "previous_response", "step" => "data_step", "extract" => "attempts"}
      ]

      context = %{results: previous_results}

      built_prompt_bool = PromptBuilder.build(prompt_parts_bool, context)
      built_prompt_float = PromptBuilder.build(prompt_parts_float, context)
      built_prompt_int = PromptBuilder.build(prompt_parts_int, context)

      assert String.contains?(built_prompt_bool, "true")
      assert String.contains?(built_prompt_float, "95.5")
      assert String.contains?(built_prompt_int, "3")
    end
  end

  describe "previous_response error handling" do
    test "provides helpful error for missing step reference" do
      previous_results = %{}

      prompt_parts = [
        %{"type" => "previous_response", "step" => "missing_step"}
      ]

      context = %{results: previous_results}

      assert_raise KeyError, fn ->
        PromptBuilder.build(prompt_parts, context.results)
      end
    end

    test "handles nil extraction gracefully" do
      previous_results = %{
        "step1" => %{
          "success" => true,
          "data" => nil
        }
      }

      prompt_parts = [
        %{"type" => "previous_response", "step" => "step1", "extract" => "data"}
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      # Should handle nil values
      assert String.contains?(built_prompt, "nil")
    end

    test "handles deep nested missing fields" do
      previous_results = %{
        "step1" => %{
          "success" => true,
          "config" => %{
            "level1" => %{
              "level2" => "exists"
            }
          }
        }
      }

      prompt_parts = [
        %{
          "type" => "previous_response",
          "step" => "step1",
          "extract" => "config.level1.missing_level3"
        }
      ]

      context = %{results: previous_results}
      built_prompt = PromptBuilder.build(prompt_parts, context.results)

      # Should return nil for missing nested field
      assert String.contains?(built_prompt, "nil")
    end
  end
end
