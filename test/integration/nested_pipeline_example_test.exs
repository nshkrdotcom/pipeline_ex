defmodule Pipeline.Integration.NestedPipelineExampleTest do
  use ExUnit.Case
  alias Pipeline.Executor

  @moduletag :integration

  test "example from prompt document works correctly" do
    # This is the example from the prompt specification
    pipeline = %{
      "workflow" => %{
        "name" => "test_nested_basic",
        "steps" => [
          %{
            "name" => "set_data",
            "type" => "test_echo",
            "value" => "test_data"
          },
          %{
            "name" => "nested_step",
            "type" => "pipeline",
            "pipeline" => %{
              "name" => "inline_test",
              "steps" => [
                %{
                  "name" => "echo",
                  "type" => "test_echo",
                  "value" => "nested_result"
                }
              ]
            }
          },
          %{
            "name" => "verify",
            "type" => "test_echo",
            "value" => "verification_complete"
          }
        ]
      }
    }

    assert {:ok, results} = Executor.execute(pipeline)

    # Verify all steps executed correctly
    assert results["set_data"] == "test_data"
    assert is_map(results["nested_step"])
    assert results["nested_step"]["echo"] == "nested_result"
    assert results["verify"] == "verification_complete"
  end
end
