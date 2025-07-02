defmodule Pipeline.Condition.Engine do
  @moduledoc """
  Enhanced conditional execution engine supporting complex boolean expressions.

  Supports:
  - Boolean operators: and, or, not
  - Comparison operators: >, <, ==, !=, contains, matches
  - Dot notation for nested field access: step_name.field.subfield
  - Backward compatibility with simple truthy conditions

  Example condition YAML:
  ```yaml
  condition:
    and:
      - "analysis.score > 7"
      - or:
        - "analysis.status == 'passed'"
        - "analysis.warnings.length < 3"
      - not: "analysis.errors.length > 0"
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

  # Private functions

  defp evaluate_simple_condition(condition_expr, context) do
    cond do
      # Check if it's a comparison expression
      String.contains?(condition_expr, [">", "<", "==", "!=", "contains", "matches"]) ->
        evaluate_comparison(condition_expr, context)

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

  defp evaluate_comparison(expression, context) do
    expression = String.trim(expression)

    cond do
      String.contains?(expression, " contains ") ->
        [left, right] = String.split(expression, " contains ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
        contains?(left_val, right_val)

      String.contains?(expression, " matches ") ->
        [left, right] = String.split(expression, " matches ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
        matches?(left_val, right_val)

      String.contains?(expression, " >= ") ->
        [left, right] = String.split(expression, " >= ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
        compare_values(left_val, right_val, :>=)

      String.contains?(expression, " <= ") ->
        [left, right] = String.split(expression, " <= ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
        compare_values(left_val, right_val, :<=)

      String.contains?(expression, " == ") ->
        [left, right] = String.split(expression, " == ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
        left_val == right_val

      String.contains?(expression, " != ") ->
        [left, right] = String.split(expression, " != ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
        left_val != right_val

      String.contains?(expression, " > ") ->
        [left, right] = String.split(expression, " > ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
        compare_values(left_val, right_val, :>)

      String.contains?(expression, " < ") ->
        [left, right] = String.split(expression, " < ", parts: 2)
        left_val = resolve_value(String.trim(left), context)
        right_val = resolve_value(String.trim(right), context)
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

  defp resolve_value(value, context) do
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
