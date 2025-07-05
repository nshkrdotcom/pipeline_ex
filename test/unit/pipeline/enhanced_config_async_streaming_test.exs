defmodule Pipeline.EnhancedConfigAsyncStreamingTest do
  use ExUnit.Case, async: true
  alias Pipeline.EnhancedConfig

  describe "enhanced config async streaming validation" do
    test "validates async streaming in enhanced claude steps" do
      enhanced_steps = [
        "claude_smart",
        "claude_session",
        "claude_extract",
        "claude_batch",
        "claude_robust"
      ]

      for step_type <- enhanced_steps do
        config =
          build_enhanced_config(step_type, %{
            "async_streaming" => true,
            "stream_handler" => "console",
            "stream_buffer_size" => 100
          })

        assert {:ok, _} = EnhancedConfig.load_from_map(config),
               "Failed for step type: #{step_type}"
      end
    end

    test "validates all stream handler types in enhanced config" do
      handlers = ["console", "file", "callback", "buffer"]

      for handler <- handlers do
        config =
          build_enhanced_config("claude_smart", %{
            "async_streaming" => true,
            "stream_handler" => handler
          })

        assert {:ok, _} = EnhancedConfig.load_from_map(config),
               "Failed for handler: #{handler}"
      end
    end

    test "rejects invalid stream handler in enhanced config" do
      config =
        build_enhanced_config("claude_smart", %{
          "async_streaming" => true,
          "stream_handler" => "websocket"
        })

      assert {:error, message} = EnhancedConfig.load_from_map(config)
      assert message =~ "stream_handler must be one of"
    end

    test "validates stream buffer size in enhanced config" do
      # Valid sizes
      for size <- [1, 50, 100, 1000] do
        config =
          build_enhanced_config("claude_session", %{
            "async_streaming" => true,
            "stream_buffer_size" => size
          })

        assert {:ok, _} = EnhancedConfig.load_from_map(config),
               "Failed for buffer size: #{size}"
      end

      # Invalid sizes
      for size <- [0, -1, "big", 1.5] do
        config =
          build_enhanced_config("claude_session", %{
            "async_streaming" => true,
            "stream_buffer_size" => size
          })

        assert {:error, message} = EnhancedConfig.load_from_map(config)
        assert message =~ "stream_buffer_size must be"
      end
    end

    test "accepts async streaming with preset configurations" do
      config = %{
        "workflow" => %{
          "name" => "test_preset_streaming",
          "steps" => [
            %{
              "name" => "smart_with_streaming",
              "type" => "claude_smart",
              "preset" => "development",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "console"
              }
            }
          ]
        }
      }

      assert {:ok, _} = EnhancedConfig.load_from_map(config)
    end

    test "validates async streaming in parallel claude tasks" do
      config = %{
        "workflow" => %{
          "name" => "test_parallel_streaming",
          "steps" => [
            %{
              "name" => "parallel_tasks",
              "type" => "parallel_claude",
              "parallel_tasks" => [
                %{
                  "id" => "task1",
                  "prompt" => [%{"type" => "static", "content" => "task 1"}],
                  "claude_options" => %{
                    "async_streaming" => true,
                    "stream_handler" => "file"
                  }
                },
                %{
                  "id" => "task2",
                  "prompt" => [%{"type" => "static", "content" => "task 2"}],
                  "claude_options" => %{
                    "async_streaming" => true,
                    "stream_handler" => "buffer",
                    "stream_buffer_size" => 200
                  }
                }
              ]
            }
          ]
        }
      }

      assert {:ok, _} = EnhancedConfig.load_from_map(config)
    end

    test "validates async streaming with session configuration" do
      config = %{
        "workflow" => %{
          "name" => "test_session_streaming",
          "steps" => [
            %{
              "name" => "interactive_session",
              "type" => "claude_session",
              "prompt" => [%{"type" => "static", "content" => "start session"}],
              "session_config" => %{
                "session_name" => "streaming_session",
                "persist" => true
              },
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "console",
                "stream_buffer_size" => 25
              }
            }
          ]
        }
      }

      assert {:ok, _} = EnhancedConfig.load_from_map(config)
    end

    test "validates async streaming with batch configuration" do
      config = %{
        "workflow" => %{
          "name" => "test_batch_streaming",
          "steps" => [
            %{
              "name" => "batch_process",
              "type" => "claude_batch",
              "prompt" => [%{"type" => "static", "content" => "batch task"}],
              "batch_config" => %{
                "max_parallel" => 3
              },
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "buffer"
              }
            }
          ]
        }
      }

      assert {:ok, _} = EnhancedConfig.load_from_map(config)
    end

    test "validates async streaming with robust retry configuration" do
      config = %{
        "workflow" => %{
          "name" => "test_robust_streaming",
          "steps" => [
            %{
              "name" => "robust_task",
              "type" => "claude_robust",
              "prompt" => [%{"type" => "static", "content" => "critical task"}],
              "retry_config" => %{
                "max_retries" => 3,
                "backoff_strategy" => "exponential"
              },
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "file",
                "stream_buffer_size" => 150
              }
            }
          ]
        }
      }

      assert {:ok, _} = EnhancedConfig.load_from_map(config)
    end
  end

  describe "enhanced config defaults with async streaming" do
    test "preserves streaming configuration when applying defaults" do
      config = %{
        "workflow" => %{
          "name" => "test_defaults",
          "defaults" => %{
            "claude_preset" => "production"
          },
          "steps" => [
            %{
              "name" => "smart_step",
              "type" => "claude_smart",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "console"
              }
            }
          ]
        }
      }

      assert {:ok, result} = EnhancedConfig.load_from_map(config)
      step = hd(result["workflow"]["steps"])

      # Streaming config should be preserved
      assert step["claude_options"]["async_streaming"] == true
      assert step["claude_options"]["stream_handler"] == "console"

      # Other defaults should be applied
      assert step["preset"] == "production"
    end
  end

  # Helper function to build enhanced config
  defp build_enhanced_config(step_type, claude_options) do
    base_config = %{
      "workflow" => %{
        "name" => "test_#{step_type}",
        "steps" => [
          %{
            "name" => "test_step",
            "type" => step_type,
            "prompt" => [%{"type" => "static", "content" => "test"}],
            "claude_options" => claude_options
          }
        ]
      }
    }

    # Add required fields for specific step types
    case step_type do
      "claude_session" ->
        put_in(base_config, ["workflow", "steps", Access.at(0), "session_config"], %{
          "session_name" => "test_session"
        })

      _ ->
        base_config
    end
  end
end
