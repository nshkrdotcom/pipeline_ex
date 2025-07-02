defmodule Pipeline.State.VariableEngine do
  @moduledoc """
  Manages pipeline variables and state interpolation.
  
  Provides variable assignment, retrieval, and interpolation capabilities
  for pipeline execution with support for different scoping levels.
  """

  require Logger

  @doc """
  Initialize a new variable state.
  """
  def new_state do
    %{
      global: %{},
      session: %{},
      loop: %{},
      current_step: nil,
      step_index: 0
    }
  end

  @doc """
  Set variables in the specified scope.
  
  ## Parameters
  - `state`: Current variable state
  - `variables`: Map of variable names to values
  - `scope`: Variable scope (:global, :session, :loop)
  
  ## Examples
      iex> state = Pipeline.State.VariableEngine.new_state()
      iex> Pipeline.State.VariableEngine.set_variables(state, %{"count" => 1}, :global)
      %{global: %{"count" => 1}, session: %{}, loop: %{}, current_step: nil, step_index: 0}
  """
  def set_variables(state, variables, scope \\ :global) when scope in [:global, :session, :loop] do
    resolved_variables = resolve_variables(variables, state)
    
    case scope do
      :global -> put_in(state.global, Map.merge(state.global, resolved_variables))
      :session -> put_in(state.session, Map.merge(state.session, resolved_variables))
      :loop -> put_in(state.loop, Map.merge(state.loop, resolved_variables))
    end
  end

  @doc """
  Get a variable value from the state with scope precedence.
  
  Lookup order: loop -> session -> global
  
  ## Parameters
  - `state`: Current variable state
  - `var_name`: Variable name to retrieve
  
  ## Returns
  Variable value or nil if not found
  """
  def get_variable(state, var_name) do
    cond do
      Map.has_key?(state.loop, var_name) -> state.loop[var_name]
      Map.has_key?(state.session, var_name) -> state.session[var_name]
      Map.has_key?(state.global, var_name) -> state.global[var_name]
      true -> nil
    end
  end

  @doc """
  Get all variables as a flattened map with scope precedence.
  """
  def get_all_variables(state) do
    state.global
    |> Map.merge(state.session)
    |> Map.merge(state.loop)
  end

  @doc """
  Clear variables in a specific scope.
  """
  def clear_scope(state, scope) when scope in [:global, :session, :loop] do
    case scope do
      :global -> put_in(state.global, %{})
      :session -> put_in(state.session, %{})
      :loop -> put_in(state.loop, %{})
    end
  end

  @doc """
  Update the current step information in state.
  """
  def update_step_info(state, step_name, step_index) do
    state
    |> Map.put(:current_step, step_name)
    |> Map.put(:step_index, step_index)
  end

  @doc """
  Interpolate variables in a string using {{variable_name}} syntax.
  
  Supports:
  - Simple variables: {{variable_name}}
  - State references: {{state.variable_name}}
  - Nested access: {{state.nested.value}}
  - Arithmetic expressions: {{state.count + 1}}
  
  ## Examples
      iex> state = %{global: %{"name" => "test", "count" => 5}}
      iex> Pipeline.State.VariableEngine.interpolate_string("Hello {{name}}, count: {{count}}", state)
      "Hello test, count: 5"
  """
  def interpolate_string(text, state) when is_binary(text) do
    # Find all {{...}} patterns
    Regex.replace(~r/\{\{([^}]+)\}\}/, text, fn _, expression ->
      expression
      |> String.trim()
      |> evaluate_expression(state)
      |> to_string()
    end)
  end

  def interpolate_string(value, _state), do: value

  @doc """
  Interpolate variables in any data structure recursively.
  """
  def interpolate_data(data, state) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, interpolate_data(v, state)} end)
    |> Map.new()
  end

  def interpolate_data(data, state) when is_list(data) do
    Enum.map(data, &interpolate_data(&1, state))
  end

  def interpolate_data(data, state) when is_binary(data) do
    interpolate_string(data, state)
  end

  def interpolate_data(data, _state), do: data

  @doc """
  Serialize state for checkpoint persistence.
  """
  def serialize_state(state) do
    %{
      "global" => state.global,
      "session" => state.session,
      "loop" => state.loop,
      "current_step" => state.current_step,
      "step_index" => state.step_index
    }
  end

  @doc """
  Deserialize state from checkpoint data.
  """
  def deserialize_state(data) when is_map(data) do
    %{
      global: data["global"] || %{},
      session: data["session"] || %{},
      loop: data["loop"] || %{},
      current_step: data["current_step"],
      step_index: data["step_index"] || 0
    }
  end

  def deserialize_state(_), do: new_state()

  # Private functions

  defp resolve_variables(variables, state) when is_map(variables) do
    variables
    |> Enum.map(fn {k, v} -> {k, resolve_value(v, state)} end)
    |> Map.new()
  end

  defp resolve_value(value, state) when is_binary(value) do
    # Check if it's a variable expression
    case Regex.run(~r/^\{\{(.+)\}\}$/, String.trim(value)) do
      [_, expression] ->
        expression
        |> String.trim()
        |> evaluate_expression(state)
        
      nil ->
        # Not a variable expression, interpolate any embedded variables
        interpolate_string(value, state)
    end
  end

  defp resolve_value(value, _state), do: value

  defp evaluate_expression(expression, state) do
    # Handle state references
    cond do
      String.starts_with?(expression, "state.") ->
        var_path = String.replace_leading(expression, "state.", "")
        get_nested_variable(state, var_path)
        
      # Handle arithmetic expressions (basic support)
      String.contains?(expression, ["+", "-", "*", "/"]) ->
        result = evaluate_arithmetic(expression, state)
        result
        
      # Simple variable lookup
      true ->
        get_variable(state, expression)
    end
  end

  defp get_nested_variable(state, path) do
    path_parts = String.split(path, ".")
    all_vars = get_all_variables(state)
    
    Enum.reduce(path_parts, all_vars, fn key, acc ->
      case acc do
        %{} -> Map.get(acc, key)
        _ -> nil
      end
    end)
  end

  defp evaluate_arithmetic(expression, state) do
    # Basic arithmetic evaluation
    # This is a simplified implementation - could be enhanced with a proper expression parser
    
    # First handle state.variable references
    resolved_expr = Regex.replace(~r/state\.([a-zA-Z_][a-zA-Z0-9_.]*)/, expression, fn _, var_path ->
      case get_nested_variable(state, var_path) do
        nil -> "0"
        value when is_number(value) -> to_string(value)
        value -> to_string(value)
      end
    end)
    
    # Then handle simple variable names, but skip if we already processed state references
    resolved_expr = 
      if String.contains?(expression, "state.") do
        # Expression had state references, they're already resolved
        resolved_expr
      else
        # No state references, process simple variable names
        Regex.replace(~r/\b([a-zA-Z_][a-zA-Z0-9_]*)\b/, resolved_expr, fn _, var_name ->
          case get_variable(state, var_name) do
            nil -> "0"  # Default missing variables to 0 for arithmetic
            value when is_number(value) -> to_string(value)
            value -> to_string(value)
          end
        end)
      end
    
    # Basic arithmetic evaluation (unsafe - for demonstration only)
    try do
      # This is a simplified approach - in production, use a proper expression evaluator
      case evaluate_simple_arithmetic(resolved_expr) do
        {:ok, result} -> result
        {:error, _} -> resolved_expr  # Return resolved expression if arithmetic fails
      end
    rescue
      _ -> resolved_expr
    end
  end

  defp evaluate_simple_arithmetic(expr) do
    # Very basic arithmetic - supports +, -, *, / with integers
    trimmed_expr = String.trim(expr)
    
    case trimmed_expr do
      "" -> {:ok, 0}
      _ ->
        cond do
          String.contains?(trimmed_expr, " + ") ->
            [left, right] = String.split(trimmed_expr, " + ", parts: 2)
            with {left_val, ""} <- Integer.parse(String.trim(left)),
                 {right_val, ""} <- Integer.parse(String.trim(right)) do
              {:ok, left_val + right_val}
            else
              _ -> {:error, :invalid_expression}
            end
            
          String.contains?(trimmed_expr, "+") ->
            [left, right] = String.split(trimmed_expr, "+", parts: 2)
            with {left_val, ""} <- Integer.parse(String.trim(left)),
                 {right_val, ""} <- Integer.parse(String.trim(right)) do
              {:ok, left_val + right_val}
            else
              _ -> {:error, :invalid_expression}
            end
            
          String.contains?(trimmed_expr, " - ") ->
            [left, right] = String.split(trimmed_expr, " - ", parts: 2)
            with {left_val, ""} <- Integer.parse(String.trim(left)),
                 {right_val, ""} <- Integer.parse(String.trim(right)) do
              {:ok, left_val - right_val}
            else
              _ -> {:error, :invalid_expression}
            end
            
          String.contains?(trimmed_expr, "-") and not String.starts_with?(trimmed_expr, "-") ->
            # Handle subtraction but not negative numbers at the start
            [left, right] = String.split(trimmed_expr, "-", parts: 2)
            case {String.trim(left), String.trim(right)} do
              {left_str, right_str} when left_str != "" ->
                with {left_val, ""} <- Integer.parse(left_str),
                     {right_val, ""} <- Integer.parse(right_str) do
                  {:ok, left_val - right_val}
                else
                  _ -> {:error, :invalid_expression}
                end
              _ -> {:error, :invalid_expression}
            end
            
          String.contains?(trimmed_expr, " * ") ->
            [left, right] = String.split(trimmed_expr, " * ", parts: 2)
            with {left_val, ""} <- Integer.parse(String.trim(left)),
                 {right_val, ""} <- Integer.parse(String.trim(right)) do
              {:ok, left_val * right_val}
            else
              _ -> {:error, :invalid_expression}
            end
            
          String.contains?(trimmed_expr, "*") ->
            [left, right] = String.split(trimmed_expr, "*", parts: 2)
            with {left_val, ""} <- Integer.parse(String.trim(left)),
                 {right_val, ""} <- Integer.parse(String.trim(right)) do
              {:ok, left_val * right_val}
            else
              _ -> {:error, :invalid_expression}
            end
            
          true ->
            case Integer.parse(trimmed_expr) do
              {val, ""} -> {:ok, val}
              _ -> {:error, :invalid_expression}
            end
        end
    end
  end
end