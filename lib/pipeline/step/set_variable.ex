defmodule Pipeline.Step.SetVariable do
  @moduledoc """
  Set variable step executor - handles variable assignment and state management.

  Supports:
  - Setting variables in different scopes (global, session, loop)
  - Variable interpolation and expressions
  - Type validation and coercion
  """

  require Logger
  alias Pipeline.State.VariableEngine

  @doc """
  Execute a set_variable step.

  ## Step Configuration

  ```yaml
  - name: "set_counter"
    type: "set_variable"
    variables:
      counter: 0
      name: "test_pipeline"
      items: []
    scope: "global"  # Optional: global (default), session, loop
    
  - name: "increment_counter"  
    type: "set_variable"
    variables:
      counter: "{{state.counter + 1}}"
      last_updated: "{{current_timestamp}}"
  ```
  """
  def execute(step, context) do
    Logger.info("📊 Executing set_variable step: #{step["name"]}")

    variables = step["variables"] || %{}
    scope = parse_scope(step["scope"])

    # Validate that we have variables to set
    if Enum.empty?(variables) do
      Logger.warning("⚠️  No variables specified in set_variable step")
      {:ok, %{}}
    else
      # Get current variable state or initialize new one
      current_state =
        case context do
          %{variable_state: state} -> state
          _ -> VariableEngine.new_state()
        end

      # Set the variables in the specified scope
      updated_state = VariableEngine.set_variables(current_state, variables, scope)

      # Create result with variable information
      result = %{
        "variables_set" => Map.keys(variables),
        "scope" => to_string(scope),
        "variable_count" => map_size(variables)
      }

      # Log variable assignments
      Enum.each(variables, fn {key, _value} ->
        resolved_value = VariableEngine.get_variable(updated_state, key)
        Logger.info("📊 Set variable #{key} = #{inspect(resolved_value)} (scope: #{scope})")
      end)

      Logger.info(
        "✅ Set variable step completed: #{map_size(variables)} variables in #{scope} scope"
      )

      # Return success with updated context
      {:ok, result, Map.put(context, :variable_state, updated_state)}
    end
  rescue
    error ->
      Logger.error("❌ Set variable step failed: #{inspect(error)}")
      {:error, "Variable assignment failed: #{Exception.message(error)}"}
  end

  @doc """
  Validate step configuration for set_variable type.
  """
  def validate_config(step) do
    errors = []

    # Check required fields
    errors =
      if Map.has_key?(step, "variables"), do: errors, else: ["Missing 'variables' field" | errors]

    # Validate variables is a map
    errors =
      case step["variables"] do
        variables when is_map(variables) -> errors
        _ -> ["'variables' must be a map" | errors]
      end

    # Validate scope if present
    errors =
      case step["scope"] do
        nil -> errors
        scope when scope in ["global", "session", "loop"] -> errors
        _ -> ["Invalid scope: must be 'global', 'session', or 'loop'" | errors]
      end

    case errors do
      [] -> :ok
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  # Private helper functions

  defp parse_scope(nil), do: :global
  defp parse_scope("global"), do: :global
  defp parse_scope("session"), do: :session
  defp parse_scope("loop"), do: :loop
  defp parse_scope(scope) when is_atom(scope) and scope in [:global, :session, :loop], do: scope
  defp parse_scope(_), do: :global
end
