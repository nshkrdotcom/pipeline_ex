defmodule Pipeline.Condition.Engine do
  @moduledoc """
  Enhanced conditional execution engine supporting complex boolean expressions and mathematical operations.

  Supports:
  - Boolean operators: and, or, not
  - Comparison operators: >, <, ==, !=, >=, <=, contains, matches
  - Mathematical expressions: +, -, *, /, % with proper precedence
  - Function calls: any(), all(), count(), sum(), length(), startsWith(), etc.
  - Date/time operations: now(), days(), hours(), minutes()
  - Pattern matching: regex matching and validation
  - Dot notation for nested field access: step_name.field.subfield
  - Backward compatibility with simple truthy conditions

  Example condition YAML:
  ```yaml
  condition:
    and:
      - "analysis.score * analysis.confidence > 0.8"
      - "any(analysis.issues, 'severity == \"high\"') == false"
      - "length(analysis.recommendations) between 3 and 10"
      - "analysis.timestamp > now() - days(7)"
      - "analysis.file_path matches '.*\\.ex'"
  ```
  """

  @type condition :: String.t() | map() | list()
  @type context :: map()
  @type evaluation_result :: boolean()

  @doc """
  Evaluates a condition expression against the execution context.

  Supports both simple conditions (strings) and complex boolean expressions (maps/lists).
  """
  @spec evaluate(condition, context) :: evaluation_result
  def evaluate(condition, context) when is_binary(condition) do
    # Handle simple string conditions (backward compatibility)
    evaluate_simple_condition(condition, context)
  end

  def evaluate(condition, context) when is_map(condition) do
    # Handle complex boolean expressions
    evaluate_boolean_expression(condition, context)
  end

  def evaluate(condition, context) when is_list(condition) do
    # Handle list of conditions (implicit AND)
    Enum.all?(condition, &evaluate(&1, context))
  end

  def evaluate(nil, _context), do: true

  @doc """
  Resolves a value expression in the given context.
  
  Public function for use by the Functions module.
  """
  @spec resolve_value(String.t(), context) :: any()
  def resolve_value(value, context) do
    resolve_value_private(value, context)
  end

  # Private functions

  defp evaluate_simple_condition(condition_expr, context) do
    cond do
      # Check if it's a mathematical expression with comparison operators
      String.contains?(condition_expr, ["+", "-", "*", "/", "%"]) and
      String.contains?(condition_expr, [">", "<", "==", "!=", ">=", "<=", "contains", "matches", "between"]) ->
        evaluate_mathematical_comparison(condition_expr, context)

      # Check if it contains function calls
      Regex.match?(~r/\w+\s*\(/, condition_expr) ->
        evaluate_expression_with_functions(condition_expr, context)

      # Check if it's a comparison expression
      String.contains?(condition_expr, [">", "<", "==", "!=", "contains", "matches", "between"]) ->
        evaluate_comparison(condition_expr, context)

      # Check if it's a mathematical expression without comparison (evaluate and check truthiness)
      String.contains?(condition_expr, ["+", "-", "*", "/", "%"]) ->
        result = evaluate_mathematical_expression(condition_expr, context)
        truthy?(result)

      # Simple dot notation field access (existing behavior)
      true ->
        evaluate_field_access(condition_expr, context)
    end
  end

  defp evaluate_boolean_expression(%{"and" => conditions}, context) do
    Enum.all?(conditions, &evaluate(&1, context))
  end

  defp evaluate_boolean_expression(%{"or" => conditions}, context) do
    Enum.any?(conditions, &evaluate(&1, context))
  end

  defp evaluate_boolean_expression(%{"not" => condition}, context) do
    not evaluate(condition, context)
  end

  defp evaluate_boolean_expression(condition, context) do
    # If it's not a recognized boolean operator, treat as simple condition
    evaluate_simple_condition(to_string(condition), context)
  end

  defp evaluate_mathematical_comparison(expression, context) do
    expression = String.trim(expression)
    
    # Find the comparison operator
    operators = [" between ", " >= ", " <= ", " == ", " != ", " > ", " < ", " contains ", " matches "]
    
    case find_operator(expression, operators) do
      {operator, left, right} ->
        left_val = evaluate_mathematical_expression(String.trim(left), context)
        
        case operator do
          " between " ->
            # Special handling for "between X and Y"
            case String.split(String.trim(right), " and ", parts: 2) do
              [min_expr, max_expr] ->
                min_val = evaluate_mathematical_expression(String.trim(min_expr), context)
                max_val = evaluate_mathematical_expression(String.trim(max_expr), context)
                Pipeline.Condition.Functions.call_function("between", [left_val, min_val, max_val], context)
              _ ->
                false
            end
          _ ->
            right_val = evaluate_mathematical_expression(String.trim(right), context)
            perform_comparison(left_val, right_val, String.trim(operator), context)
        end
      nil ->
        # No comparison operator found, evaluate as mathematical expression
        result = evaluate_mathematical_expression(expression, context)
        truthy?(result)
    end
  end

  defp evaluate_expression_with_functions(expression, context) do
    expression = String.trim(expression)
    
    # Check if it's a function call comparison
    if String.contains?(expression, [">", "<", "==", "!=", ">=", "<=", "contains", "matches", "between"]) do
      evaluate_mathematical_comparison(expression, context)
    else
      # Pure function call, evaluate and check truthiness
      result = evaluate_mathematical_expression(expression, context)
      truthy?(result)
    end
  end

  defp evaluate_comparison(expression, context) do
    expression = String.trim(expression)

    cond do
      String.contains?(expression, " contains ") ->
        [left, right] = String.split(expression, " contains ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        contains?(left_val, right_val)

      String.contains?(expression, " matches ") ->
        [left, right] = String.split(expression, " matches ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        matches?(left_val, right_val)

      String.contains?(expression, " >= ") ->
        [left, right] = String.split(expression, " >= ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        compare_values(left_val, right_val, :>=)

      String.contains?(expression, " <= ") ->
        [left, right] = String.split(expression, " <= ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        compare_values(left_val, right_val, :<=)

      String.contains?(expression, " == ") ->
        [left, right] = String.split(expression, " == ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        left_val == right_val

      String.contains?(expression, " != ") ->
        [left, right] = String.split(expression, " != ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        left_val != right_val

      String.contains?(expression, " > ") ->
        [left, right] = String.split(expression, " > ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        compare_values(left_val, right_val, :>)

      String.contains?(expression, " < ") ->
        [left, right] = String.split(expression, " < ", parts: 2)
        left_val = resolve_value_private(String.trim(left), context)
        right_val = resolve_value_private(String.trim(right), context)
        compare_values(left_val, right_val, :<)

      true ->
        # Fallback to field access if no comparison operator found
        evaluate_field_access(expression, context)
    end
  end

  defp evaluate_field_access(field_path, context) do
    case String.split(field_path, ".") do
      [step_name] ->
        get_in(context.results, [step_name]) |> truthy?()

      [step_name, field] ->
        get_in(context.results, [step_name, field]) |> truthy?()

      parts when length(parts) > 2 ->
        get_in(context.results, parts) |> truthy?()
    end
  end

  # Mathematical expression evaluation
  
  defp evaluate_mathematical_expression(expression, context) do
    expression = String.trim(expression)
    
    # Handle function calls first
    if Regex.match?(~r/\w+\s*\(/, expression) do
      evaluate_function_calls(expression, context)
    else
      # Handle mathematical operators with precedence
      evaluate_math_with_precedence(expression, context)
    end
  end
  
  defp evaluate_function_calls(expression, context) do
    # Check if the entire expression is just a single function call
    case Regex.run(~r/^(\w+)\s*\(([^)]*)\)$/, String.trim(expression)) do
      [_, func_name, args_str] ->
        # Single function call - evaluate directly
        args = parse_function_args(args_str, context)
        Pipeline.Condition.Functions.call_function(func_name, args, context)
      nil ->
        # Contains function calls mixed with other expressions
        # Replace function calls with their evaluated results
        replaced = Regex.replace(~r/(\w+)\s*\(([^)]*)\)/, expression, fn _, func_name, args_str ->
          args = parse_function_args(args_str, context)
          result = Pipeline.Condition.Functions.call_function(func_name, args, context)
          to_string(result)
        end)
        evaluate_math_with_precedence(replaced, context)
    end
  end
  
  defp parse_function_args("", _context), do: []
  defp parse_function_args(args_str, context) do
    # Simple comma-separated argument parsing
    # TODO: Handle nested parentheses and quoted strings properly
    args_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn arg ->
      # Remove quotes if present
      cond do
        String.starts_with?(arg, "'") and String.ends_with?(arg, "'") ->
          String.slice(arg, 1..-2//1)
        String.starts_with?(arg, "\"") and String.ends_with?(arg, "\"") ->
          String.slice(arg, 1..-2//1)
        true ->
          arg
      end
    end)
  end
  
  defp evaluate_math_with_precedence(expression, context) when is_binary(expression) do
    # Handle operator precedence: *, /, % before +, -
    expression = String.trim(expression)
    
    # First evaluate high-precedence operations (*, /, %)
    with_high_precedence = evaluate_operations(expression, context, ["*", "/", "%"])
    
    # Then evaluate low-precedence operations (+, -)
    evaluate_operations(with_high_precedence, context, ["+", "-"])
  end
  
  defp evaluate_math_with_precedence(value, _context) do
    # If it's not a string, return the value as is
    value
  end
  
  defp evaluate_operations(expression, context, operators) when is_binary(expression) do
    # Find the rightmost operator to maintain left-to-right evaluation
    case find_rightmost_operator(expression, operators) do
      {operator, left, right} ->
        left_val = evaluate_math_with_precedence(String.trim(left), context)
        right_val = evaluate_math_with_precedence(String.trim(right), context)
        perform_math_operation(left_val, right_val, operator)
      nil ->
        # No operator found, resolve as value
        resolve_value_private(expression, context)
    end
  end
  
  defp evaluate_operations(value, _context, _operators) do
    # If it's not a string, return the value as is
    value
  end
  
  defp find_rightmost_operator(expression, operators) when is_binary(expression) do
    # Find the rightmost occurrence of any operator
    # We need to find the last occurrence to handle left-to-right evaluation correctly
    operators
    |> Enum.reduce(nil, fn op, acc ->
      # Find all matches for this operator
      case String.split(expression, op) do
        [_single] ->
          # No matches found
          acc
        parts when length(parts) > 1 ->
          # Found matches, calculate the position of the last occurrence
          total_len = String.length(expression)
          op_len = String.length(op)
          # Calculate position by working backwards from the end
          last_part = List.last(parts)
          last_part_len = String.length(last_part)
          start = total_len - last_part_len - op_len
          
          case acc do
            {_, _, _, prev_start} when start <= prev_start -> acc
            _ -> {op, start, op_len, start}
          end
      end
    end)
    |> case do
      {operator, start, len, _} ->
        left = String.slice(expression, 0, start)
        right = String.slice(expression, start + len, String.length(expression))
        {operator, left, right}
      nil ->
        nil
    end
  end
  
  defp find_rightmost_operator(_expression, _operators), do: nil
  
  defp find_operator(expression, operators) do
    # Find the first occurrence of any operator, but prioritize by order
    operators
    |> Enum.reduce(nil, fn op, acc ->
      case acc do
        nil ->
          if String.contains?(expression, op) do
            parts = String.split(expression, op, parts: 2)
            if length(parts) == 2 do
              [left, right] = parts
              {op, left, right}
            else
              nil
            end
          else
            nil
          end
        result ->
          result
      end
    end)
  end
  
  defp perform_math_operation(left, right, operator) when is_number(left) and is_number(right) do
    case operator do
      "+" -> left + right
      "-" -> left - right
      "*" -> left * right
      "/" when right != 0 -> left / right
      "/" -> 0  # Division by zero protection
      "%" when right != 0 -> rem(trunc(left), trunc(right))
      "%" -> 0  # Modulo by zero protection
      _ -> 0
    end
  end
  
  defp perform_math_operation(left, right, operator) do
    # Try to convert to numbers if possible
    left_num = try_to_number(left)
    right_num = try_to_number(right)
    
    if is_number(left_num) and is_number(right_num) do
      perform_math_operation(left_num, right_num, operator)
    else
      0
    end
  end
  
  defp try_to_number(value) when is_number(value), do: value
  defp try_to_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> num
      _ ->
        case Integer.parse(value) do
          {num, ""} -> num
          _ -> value
        end
    end
  end
  defp try_to_number(value), do: value
  
  defp perform_comparison(left, right, operator, context) do
    case operator do
      ">" -> compare_values(left, right, :>)
      "<" -> compare_values(left, right, :<)
      ">=" -> compare_values(left, right, :>=)
      "<=" -> compare_values(left, right, :<=)
      "==" -> left == right
      "!=" -> left != right
      "contains" -> Pipeline.Condition.Functions.call_function("contains", [left, right], context)
      "matches" -> Pipeline.Condition.Functions.call_function("matches", [left, right], context)
      _ -> false
    end
  end

  defp resolve_value_private(value, context) when is_binary(value) do
    value = String.trim(value)

    cond do
      # String literal (quoted)
      String.starts_with?(value, "'") and String.ends_with?(value, "'") ->
        String.slice(value, 1..-2//1)

      String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
        String.slice(value, 1..-2//1)

      # Number literal
      Regex.match?(~r/^\d+$/, value) ->
        String.to_integer(value)

      Regex.match?(~r/^\d+\.\d+$/, value) ->
        String.to_float(value)

      # Boolean literal
      value == "true" ->
        true

      value == "false" ->
        false

      # Null literal
      value == "null" ->
        nil

      # Field access with special properties
      String.contains?(value, ".length") ->
        field_path = String.replace(value, ".length", "")
        field_val = resolve_field_value(field_path, context)
        get_length(field_val)

      # Regular field access
      String.contains?(value, ".") ->
        resolve_field_value(value, context)

      # Single field
      true ->
        resolve_field_value(value, context)
    end
  end

  defp resolve_value_private(value, _context) do
    # If it's not a string, return the value as is
    value
  end

  defp resolve_field_value(field_path, context) do
    case String.split(field_path, ".") do
      [step_name] ->
        get_in(context.results, [step_name])

      [step_name, field] ->
        get_in(context.results, [step_name, field])

      parts when length(parts) > 2 ->
        get_in(context.results, parts)
    end
  end

  defp get_length(value) when is_list(value), do: length(value)
  defp get_length(value) when is_binary(value), do: String.length(value)
  defp get_length(value) when is_map(value), do: map_size(value)
  defp get_length(_), do: 0

  defp compare_values(left, right, operator) when is_number(left) and is_number(right) do
    case operator do
      :> -> left > right
      :< -> left < right
      :>= -> left >= right
      :<= -> left <= right
    end
  end

  defp compare_values(left, right, operator) when is_binary(left) and is_binary(right) do
    case operator do
      :> -> left > right
      :< -> left < right
      :>= -> left >= right
      :<= -> left <= right
    end
  end

  defp compare_values(_left, _right, _operator), do: false

  defp contains?(haystack, needle) when is_binary(haystack) and is_binary(needle) do
    String.contains?(haystack, needle)
  end

  defp contains?(haystack, needle) when is_list(haystack) do
    Enum.member?(haystack, needle)
  end

  defp contains?(_haystack, _needle), do: false

  defp matches?(value, pattern) when is_binary(value) and is_binary(pattern) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, value)
      {:error, _} -> false
    end
  end

  defp matches?(_value, _pattern), do: false

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(""), do: false
  defp truthy?([]), do: false
  defp truthy?({}), do: false
  defp truthy?(%{} = map) when map_size(map) == 0, do: false
  defp truthy?(_), do: true
end
