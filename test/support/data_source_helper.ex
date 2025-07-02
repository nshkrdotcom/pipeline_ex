defmodule Pipeline.Test.DataSourceHelper do
  @moduledoc """
  Helper utilities for testing data source resolution.
  """

  def create_test_context(step_name, variables) when is_map(variables) do
    %{
      results: %{
        step_name => %{
          "variables" => variables,
          "success" => true
        }
      }
    }
  end
  
  def create_test_context(step_name, data) do
    %{
      results: %{
        step_name => data
      }
    }
  end
  
  def format_variable_source(step_name, variable_name) do
    "previous_response:#{step_name}.variables.#{variable_name}"
  end
  
  def format_result_source(step_name, field_path \\ nil) do
    if field_path do
      "previous_response:#{step_name}.#{field_path}"
    else
      "previous_response:#{step_name}"
    end
  end
end