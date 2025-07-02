defmodule PipelineTest do
  use ExUnit.Case
  doctest Pipeline

  test "pipeline module loads correctly" do
    assert is_atom(Pipeline)
    assert function_exported?(Pipeline, :execute, 2)
    assert function_exported?(Pipeline, :load_workflow, 1)
  end
end
