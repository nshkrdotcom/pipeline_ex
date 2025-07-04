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
  def set_variables(state, variables, scope \\ :global)
      when scope in [:global, :session, :loop] do
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
  Interpolate variables in a string with execution context access.
  This handles both variable state and step result patterns.
  """
  def interpolate_string_with_context(text, state, context) when is_binary(text) do
    # Find all {{...}} patterns
    Regex.replace(~r/\{\{([^}]+)\}\}/, text, fn _, expression ->
      expression
      |> String.trim()
      |> evaluate_expression_with_context(state, context)
      |> to_string()
    end)
  end

  def interpolate_string_with_context(value, _state, _context), do: value

  @doc """
  Interpolate variables with type preservation for single templates.
  This is used for nested pipeline execution where types should be preserved.
  """
  def interpolate_with_type_preservation(text, state, context) when is_binary(text) do
    # Check if the entire string is a single template
    case Regex.run(~r/^\{\{([^}]+)\}\}$/, String.trim(text)) do
      [_, expression] ->
        # Single template, return the actual value (preserve type)
        expression
        |> String.trim()
        |> evaluate_expression_with_context(state, context)

      nil ->
        # Multiple templates or mixed content, do string replacement
        Regex.replace(~r/\{\{([^}]+)\}\}/, text, fn _, expression ->
          expression
          |> String.trim()
          |> evaluate_expression_with_context(state, context)
          |> to_string()
        end)
    end
  end

  def interpolate_with_type_preservation(value, _state, _context), do: value

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
  Interpolate variables in any data structure with execution context access.
  This allows resolving step results and other execution-time data.
  """
  def interpolate_data_with_context(data, state, context) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, interpolate_data_with_context(v, state, context)} end)
    |> Map.new()
  end

  def interpolate_data_with_context(data, state, context) when is_list(data) do
    Enum.map(data, &interpolate_data_with_context(&1, state, context))
  end

  def interpolate_data_with_context(data, state, context) when is_binary(data) do
    interpolate_string_with_context(data, state, context)
  end

  def interpolate_data_with_context(data, _state, _context), do: data

  @doc """
  Interpolate variables in any data structure with type preservation for single templates.
  """
  def interpolate_data_with_type_preservation(data, state, context) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {k, interpolate_data_with_type_preservation(v, state, context)} end)
    |> Map.new()
  end

  def interpolate_data_with_type_preservation(data, state, context) when is_list(data) do
    Enum.map(data, &interpolate_data_with_type_preservation(&1, state, context))
  end

  def interpolate_data_with_type_preservation(data, state, context) when is_binary(data) do
    interpolate_with_type_preservation(data, state, context)
  end

  def interpolate_data_with_type_preservation(data, _state, _context), do: data

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
    # Handle expressions in priority order
    cond do
      # Handle function calls first
      String.match?(expression, ~r/^[a-zA-Z_][a-zA-Z0-9_]*\s*\(/) ->
        evaluate_function_call(expression, state)

      # Handle arithmetic expressions (basic support)
      String.contains?(expression, ["+", "-", "*", "/"]) ->
        evaluate_arithmetic(expression, state)

      # Handle state references (only simple ones without operators)
      String.starts_with?(expression, "state.") ->
        var_path = String.replace_leading(expression, "state.", "")
        get_nested_variable(state, var_path)

      # Simple variable lookup
      true ->
        get_variable(state, expression)
    end
  end

  defp evaluate_expression_with_context(expression, state, context) do
    # Handle expressions in priority order, including step results
    cond do
      # Handle function calls first
      String.match?(expression, ~r/^[a-zA-Z_][a-zA-Z0-9_]*\s*\(/) ->
        evaluate_function_call_with_context(expression, state, context)

      # Handle inputs patterns (for nested pipeline execution)
      String.starts_with?(expression, "inputs.") ->
        resolve_inputs_variable(expression, context)

      # Handle global_vars patterns (for nested pipeline execution)
      String.starts_with?(expression, "global_vars.") ->
        resolve_global_vars_variable(expression, context)

      # Handle step result patterns
      String.starts_with?(expression, "steps.") ->
        resolve_step_result(expression, context)

      # Handle arithmetic expressions
      String.contains?(expression, ["+", "-", "*", "/"]) ->
        evaluate_arithmetic_with_context(expression, state, context)

      # Handle state references
      String.starts_with?(expression, "state.") ->
        var_path = String.replace_leading(expression, "state.", "")
        get_nested_variable(state, var_path)

      # Simple variable lookup
      true ->
        get_variable(state, expression)
    end
  end

  defp resolve_step_result(expression, context) do
    # Remove "steps." prefix and parse the path
    path = String.replace_leading(expression, "steps.", "")
    path_parts = String.split(path, ".")

    case path_parts do
      [step_name | rest] ->
        # Get the step result from execution context
        step_result = get_in(context, [:results, step_name])

        cond do
          # Step not found - preserve template
          step_result == nil ->
            "{{#{expression}}}"

          # Step found and has more path parts
          length(rest) > 0 ->
            # Smart template resolution: try both new format (with "result" key) and old format
            result =
              case get_nested_value_from_map(step_result, rest) do
                nil ->
                  # If not found, try looking inside "result" key for new format (only if step_result is a map)
                  case step_result do
                    %{} = map_result ->
                      case Map.get(map_result, "result") do
                        nil ->
                          # Final fallback: if looking for "result" specifically and step_result is not wrapped,
                          # return the step_result itself (for nested pipeline compatibility)
                          if rest == ["result"] do
                            step_result
                          else
                            nil
                          end

                        result_data ->
                          get_nested_value_from_map(result_data, rest)
                      end

                    _ ->
                      # step_result is not a map, but if looking for "result" specifically,
                      # return the step_result itself (for nested pipeline compatibility)
                      if rest == ["result"] do
                        step_result
                      else
                        nil
                      end
                  end

                value ->
                  value
              end

            # If we still couldn't find the value, preserve the template
            if result == nil do
              "{{#{expression}}}"
            else
              result
            end

          # Step found with no more path parts - return the step result
          true ->
            step_result
        end

      [] ->
        nil
    end
  end

  defp get_nested_value_from_map(data, []), do: data

  defp get_nested_value_from_map(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      value -> get_nested_value_from_map(value, rest)
    end
  end

  defp get_nested_value_from_map(_data, _path), do: nil

  defp evaluate_arithmetic_with_context(expression, state, _context) do
    # For now, fall back to the original arithmetic evaluation
    # TODO: Could be enhanced to support step results in arithmetic
    evaluate_arithmetic(expression, state)
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
    resolved_expr =
      Regex.replace(~r/state\.([a-zA-Z_][a-zA-Z0-9_.]*)/, expression, fn _, var_path ->
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
            # Default missing variables to 0 for arithmetic
            nil -> "0"
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
        # Return resolved expression if arithmetic fails
        {:error, _} -> resolved_expr
      end
    rescue
      _ -> resolved_expr
    end
  end

  defp evaluate_simple_arithmetic(expr) do
    # Very basic arithmetic - supports +, -, *, / with integers
    trimmed_expr = String.trim(expr)

    case trimmed_expr do
      "" ->
        {:ok, 0}

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

              _ ->
                {:error, :invalid_expression}
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

  # Function call evaluation

  defp evaluate_function_call(expression, state) do
    evaluate_function_call_with_context(expression, state, %{})
  end

  defp evaluate_function_call_with_context(expression, state, context) do
    # Parse function call: function_name(arg1, arg2, ...)
    case Regex.run(~r/^([a-zA-Z_][a-zA-Z0-9_]*)\s*\((.*)\)$/, String.trim(expression)) do
      [_, function_name, args_str] ->
        # Parse arguments
        args = parse_function_arguments(args_str, state, context)

        # Call the function
        call_function(function_name, args)

      nil ->
        # Not a valid function call, return original expression
        expression
    end
  end

  defp parse_function_arguments(args_str, state, context) do
    # Split arguments by comma (simplified - doesn't handle nested commas)
    args_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn arg ->
      # Resolve each argument as a variable or literal
      cond do
        # Check if it's a template variable
        String.starts_with?(arg, "inputs.") ->
          resolve_input_variable(arg, context)

        String.starts_with?(arg, "steps.") ->
          resolve_step_result(arg, context)

        String.starts_with?(arg, "global_vars.") ->
          var_name = String.replace_leading(arg, "global_vars.", "")
          get_in(context, [:global_vars, var_name])

        String.starts_with?(arg, "state.") ->
          var_path = String.replace_leading(arg, "state.", "")
          get_nested_variable(state, var_path)

        # Check if it's a number
        String.match?(arg, ~r/^\d+(\.\d+)?$/) ->
          case Float.parse(arg) do
            {float_val, ""} ->
              if String.contains?(arg, "."), do: float_val, else: trunc(float_val)

            _ ->
              arg
          end

        # Check if it's a variable name
        String.match?(arg, ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/) ->
          get_variable(state, arg) || arg

        # Otherwise treat as literal string
        true ->
          arg
      end
    end)
  end

  defp resolve_input_variable(arg, context) do
    # Remove "inputs." prefix and get from context
    var_name = String.replace_leading(arg, "inputs.", "")
    get_in(context, [:inputs, var_name])
  end

  defp resolve_inputs_variable(expression, context) do
    # Remove "inputs." prefix and parse the path
    path = String.replace_leading(expression, "inputs.", "")
    path_parts = String.split(path, ".")

    case path_parts do
      [var_name | rest] ->
        # Get the input variable from execution context
        input_value = get_in(context, [:inputs, var_name])

        cond do
          # If we found the input and need to navigate deeper
          input_value && length(rest) > 0 ->
            get_nested_value_from_map(input_value, rest) || "{{#{expression}}}"

          # If we found the input, return it
          input_value != nil ->
            input_value

          # If input not found, preserve the template for nested pipeline resolution
          true ->
            "{{#{expression}}}"
        end

      [] ->
        "{{#{expression}}}"
    end
  end

  defp resolve_global_vars_variable(expression, context) do
    # Remove "global_vars." prefix
    var_name = String.replace_leading(expression, "global_vars.", "")

    # Get the global variable from execution context
    case get_in(context, [:global_vars, var_name]) do
      nil ->
        # If not found, preserve the template for nested pipeline resolution
        "{{#{expression}}}"

      value ->
        value
    end
  end

  defp call_function(function_name, args) do
    case function_name do
      "multiply" when length(args) == 2 ->
        [a, b] = args
        ensure_number(a) * ensure_number(b)

      "add" when length(args) == 2 ->
        [a, b] = args
        ensure_number(a) + ensure_number(b)

      "subtract" when length(args) == 2 ->
        [a, b] = args
        ensure_number(a) - ensure_number(b)

      "divide" when length(args) == 2 ->
        [a, b] = args

        if ensure_number(b) == 0 do
          0
        else
          ensure_number(a) / ensure_number(b)
        end

      "max" when length(args) >= 1 ->
        args |> Enum.map(&ensure_number/1) |> Enum.max()

      "min" when length(args) >= 1 ->
        args |> Enum.map(&ensure_number/1) |> Enum.min()

      "round" when length(args) == 1 ->
        [a] = args
        round(ensure_number(a))

      "floor" when length(args) == 1 ->
        [a] = args
        floor(ensure_number(a))

      "ceil" when length(args) == 1 ->
        [a] = args
        ceil(ensure_number(a))

      _ ->
        # Unknown function, return original expression
        "#{function_name}(#{Enum.join(args, ", ")})"
    end
  end

  defp ensure_number(value) when is_number(value), do: value

  defp ensure_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> if String.contains?(value, "."), do: num, else: trunc(num)
      _ -> 0
    end
  end

  defp ensure_number(_), do: 0
end
