defmodule Pipeline.ConfigAsyncStreamingTest do
  use ExUnit.Case, async: true
  @moduletag :skip
  alias Pipeline.Config

  describe "async streaming validation" do
    test "accepts valid async streaming configuration" do
      config = %{
        "workflow" => %{
          "name" => "test_async_streaming",
          "steps" => [
            %{
              "name" => "claude_with_streaming",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "console",
                "stream_buffer_size" => 100
              }
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "accepts async streaming disabled" do
      config = %{
        "workflow" => %{
          "name" => "test_no_streaming",
          "steps" => [
            %{
              "name" => "claude_no_streaming",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => false
              }
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "accepts missing async streaming configuration" do
      config = %{
        "workflow" => %{
          "name" => "test_default",
          "steps" => [
            %{
              "name" => "claude_default",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "max_turns" => 10
              }
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "rejects non-boolean async_streaming value" do
      config = %{
        "workflow" => %{
          "name" => "test_invalid_bool",
          "steps" => [
            %{
              "name" => "claude_bad_bool",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => "yes"
              }
            }
          ]
        }
      }

      assert {:error, message} = Config.validate_workflow(config)
      assert message =~ "async_streaming must be a boolean"
    end

    test "accepts all valid stream handlers" do
      valid_handlers = ["console", "file", "callback", "buffer"]

      for handler <- valid_handlers do
        config = %{
          "workflow" => %{
            "name" => "test_#{handler}_handler",
            "steps" => [
              %{
                "name" => "claude_#{handler}",
                "type" => "claude",
                "prompt" => [%{"type" => "static", "content" => "test"}],
                "claude_options" => %{
                  "async_streaming" => true,
                  "stream_handler" => handler
                }
              }
            ]
          }
        }

        assert :ok = Config.validate_workflow(config), "Failed for handler: #{handler}"
      end
    end

    test "rejects invalid stream handler" do
      config = %{
        "workflow" => %{
          "name" => "test_invalid_handler",
          "steps" => [
            %{
              "name" => "claude_bad_handler",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "invalid"
              }
            }
          ]
        }
      }

      assert {:error, message} = Config.validate_workflow(config)

      assert message =~
               "stream_handler must be one of: console, simple, debug, file, callback, buffer"
    end

    test "accepts valid stream buffer sizes" do
      valid_sizes = [1, 10, 100, 1000, 10_000]

      for size <- valid_sizes do
        config = %{
          "workflow" => %{
            "name" => "test_buffer_#{size}",
            "steps" => [
              %{
                "name" => "claude_buffer_#{size}",
                "type" => "claude",
                "prompt" => [%{"type" => "static", "content" => "test"}],
                "claude_options" => %{
                  "async_streaming" => true,
                  "stream_buffer_size" => size
                }
              }
            ]
          }
        }

        assert :ok = Config.validate_workflow(config), "Failed for buffer size: #{size}"
      end
    end

    test "rejects invalid stream buffer sizes" do
      invalid_sizes = [0, -1, -100, "large", 1.5]

      for size <- invalid_sizes do
        config = %{
          "workflow" => %{
            "name" => "test_invalid_buffer",
            "steps" => [
              %{
                "name" => "claude_bad_buffer",
                "type" => "claude",
                "prompt" => [%{"type" => "static", "content" => "test"}],
                "claude_options" => %{
                  "async_streaming" => true,
                  "stream_buffer_size" => size
                }
              }
            ]
          }
        }

        assert {:error, message} = Config.validate_workflow(config)
        assert message =~ "stream_buffer_size must be"
      end
    end

    test "validates streaming options only when async_streaming is true" do
      # Invalid handler and buffer size, but async_streaming is false
      config = %{
        "workflow" => %{
          "name" => "test_no_validation",
          "steps" => [
            %{
              "name" => "claude_no_validation",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => false,
                "stream_handler" => "invalid",
                "stream_buffer_size" => -1
              }
            }
          ]
        }
      }

      # Should pass because async_streaming is false
      assert :ok = Config.validate_workflow(config)
    end

    test "streaming configuration works with non-claude steps" do
      config = %{
        "workflow" => %{
          "name" => "test_gemini",
          "steps" => [
            %{
              "name" => "gemini_step",
              "type" => "gemini",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "model" => "gemini-1.5-flash",
              # These options should be ignored for gemini
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "console"
              }
            }
          ]
        }
      }

      assert :ok = Config.validate_workflow(config)
    end

    test "loads example streaming configuration file" do
      # Test that our example file is valid
      assert {:ok, _config} = Config.load_workflow("examples/claude_streaming_example.yaml")
    end
  end

  describe "apply_defaults with async streaming" do
    test "preserves explicit async streaming configuration" do
      config = %{
        "workflow" => %{
          "name" => "test_preserve",
          "defaults" => %{
            "claude_options" => %{
              "output_format" => "json"
            }
          },
          "steps" => [
            %{
              "name" => "claude_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => true,
                "stream_handler" => "file",
                "stream_buffer_size" => 200
              }
            }
          ]
        }
      }

      result = Config.apply_defaults(config)
      step = hd(result["workflow"]["steps"])

      assert step["claude_options"]["async_streaming"] == true
      assert step["claude_options"]["stream_handler"] == "file"
      assert step["claude_options"]["stream_buffer_size"] == 200
      assert step["claude_options"]["output_format"] == "json"
    end

    test "applies defaults without overriding streaming config" do
      config = %{
        "workflow" => %{
          "name" => "test_defaults",
          "defaults" => %{
            "claude_options" => %{
              "output_format" => "text",
              "verbose" => true
            }
          },
          "steps" => [
            %{
              "name" => "claude_step",
              "type" => "claude",
              "prompt" => [%{"type" => "static", "content" => "test"}],
              "claude_options" => %{
                "async_streaming" => true
              }
            }
          ]
        }
      }

      result = Config.apply_defaults(config)
      step = hd(result["workflow"]["steps"])

      assert step["claude_options"]["async_streaming"] == true
      assert step["claude_options"]["output_format"] == "text"
      assert step["claude_options"]["verbose"] == true
    end
  end
end
