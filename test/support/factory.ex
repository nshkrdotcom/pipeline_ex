defmodule Pipeline.Test.Factory do
  @moduledoc """
  Factory for creating test data structures.
  """

  @doc """
  Build test data structures.
  """
  def build(type, overrides \\ %{})

  def build(:workflow, overrides) do
    base = %{
      "workflow" => %{
        "name" => "test_workflow",
        "checkpoint_enabled" => false,
        "workspace_dir" => "./test_workspace",
        "defaults" => %{
          "output_dir" => "./test_outputs"
        },
        "steps" => [
          build(:claude_step),
          build(:gemini_step)
        ]
      }
    }

    deep_merge(base, overrides)
  end

  def build(:simple_workflow, overrides) do
    base = %{
      "workflow" => %{
        "name" => "simple_test",
        "steps" => [
          build(:claude_step, %{"name" => "simple_task"})
        ]
      }
    }

    deep_merge(base, overrides)
  end

  def build(:complex_workflow, overrides) do
    base = %{
      "workflow" => %{
        "name" => "complex_test",
        "checkpoint_enabled" => true,
        "workspace_dir" => "./complex_workspace",
        "steps" => [
          build(:gemini_step, %{"name" => "analyze_requirements"}),
          build(:gemini_step, %{"name" => "create_plan"}),
          build(:claude_step, %{"name" => "implement_code"}),
          build(:gemini_step, %{"name" => "review_code"}),
          build(:claude_step, %{"name" => "fix_issues"})
        ]
      }
    }

    deep_merge(base, overrides)
  end

  def build(:claude_step, overrides) do
    base = %{
      "name" => "claude_task",
      "type" => "claude",
      "role" => "muscle",
      "claude_options" => %{
        "max_turns" => 3,
        "allowed_tools" => ["Write", "Read", "Edit"]
      },
      "prompt" => [
        %{
          "type" => "static",
          "content" => "Create a simple Python program"
        }
      ],
      "output_to_file" => "claude_result.json"
    }

    deep_merge(base, overrides)
  end

  def build(:gemini_step, overrides) do
    base = %{
      "name" => "gemini_task",
      "type" => "gemini",
      "role" => "brain",
      "model" => "gemini-2.5-flash-lite-preview-06-17",
      "token_budget" => %{
        "max_output_tokens" => 2048,
        "temperature" => 0.7
      },
      "prompt" => [
        %{
          "type" => "static",
          "content" => "Analyze the requirements and create a plan"
        }
      ],
      "output_to_file" => "gemini_result.json"
    }

    deep_merge(base, overrides)
  end

  def build(:claude_step_with_previous, overrides) do
    base =
      build(:claude_step, %{
        "name" => "claude_with_previous",
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Based on the previous analysis:"
          },
          %{
            "type" => "previous_response",
            "step" => "gemini_task"
          }
        ]
      })

    deep_merge(base, overrides)
  end

  def build(:gemini_function_calling_step, overrides) do
    base =
      build(:gemini_step, %{
        "name" => "gemini_function_calling",
        "tools" => ["file_creator", "code_analyzer"],
        "prompt" => [
          %{
            "type" => "static",
            "content" => "Use available tools to create and analyze code"
          }
        ]
      })

    deep_merge(base, overrides)
  end

  def build(:test_orchestrator, overrides) do
    base = %{
      results: %{},
      debug_log: "/tmp/test.log",
      output_dir: "/tmp/test_outputs",
      workspace_dir: "/tmp/test_workspace"
    }

    Map.merge(base, overrides)
  end

  def build(:claude_response, overrides) do
    base = %{
      text: "Mock Claude response",
      success: true,
      cost: 0.002
    }

    Map.merge(base, overrides)
  end

  def build(:gemini_response, overrides) do
    base = %{
      content: """
      {
        "analysis": "Mock Gemini analysis",
        "confidence": 0.95
      }
      """,
      success: true,
      cost: 0.003,
      function_calls: []
    }

    Map.merge(base, overrides)
  end

  def build(:error_response, overrides) do
    base = %{
      text: "Mock error occurred",
      success: false,
      error: "Test error scenario"
    }

    Map.merge(base, overrides)
  end

  # Helper function to deep merge maps
  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn
      _k, v1, v2 when is_map(v1) and is_map(v2) -> deep_merge(v1, v2)
      _k, _v1, v2 -> v2
    end)
  end

  @doc """
  Build a list of items.
  """
  def build_list(count, type, overrides \\ %{}) when is_integer(count) and count >= 0 do
    1..count
    |> Enum.map(fn i ->
      item_overrides = Map.put(overrides, "name", "#{type}_#{i}")
      build(type, item_overrides)
    end)
  end

  @doc """
  Build with sequential naming.
  """
  def build_sequence(type, names) when is_list(names) do
    names
    |> Enum.map(fn name ->
      build(type, %{"name" => name})
    end)
  end
end
