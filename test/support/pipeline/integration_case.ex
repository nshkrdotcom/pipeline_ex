defmodule Pipeline.IntegrationCase do
  @moduledoc """
  Test case for integration tests.

  This module provides common testing utilities for integration tests
  across the pipeline system.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case, async: false
      import Pipeline.IntegrationCase
    end
  end

  @doc """
  Create a test pipeline context with common fields.
  """
  def create_test_context(pipeline_id, depth \\ 0) do
    %{
      pipeline_id: pipeline_id,
      nesting_depth: depth,
      start_time: DateTime.utc_now(),
      step_count: 0,
      parent_context:
        if(depth > 0, do: create_test_context("parent_#{depth - 1}", depth - 1), else: nil)
    }
  end

  @doc """
  Create a test step configuration.
  """
  def create_test_step(name, type \\ "claude") do
    %{
      "name" => name,
      "type" => type,
      "config" => %{"timeout" => 30}
    }
  end
end
