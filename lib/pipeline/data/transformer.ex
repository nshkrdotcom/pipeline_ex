defmodule Pipeline.Data.Transformer do
  @moduledoc """
  Data transformation engine for manipulating structured data between pipeline steps.

  Supports operations:
  - filter: Filter items based on conditions
  - map: Transform each item
  - aggregate: Aggregate values (sum, average, count, etc.)
  - join: Join with data from another source
  - group_by: Group items by field values
  - sort: Sort items by field values
  - transform: Apply custom transformations

  Uses JSONPath-like syntax for field access and supports chaining operations.
  """

  require Logger

  @type operation :: %{
          required(:operation) => String.t(),
          optional(:field) => String.t(),
          optional(:condition) => String.t(),
          optional(:function) => String.t(),
          optional(:value) => any(),
          optional(:mapping) => map(),
          optional(:left_field) => String.t(),
          optional(:right_source) => String.t(),
          optional(:join_key) => String.t(),
          optional(:order) => String.t(),
          optional(:expression) => String.t()
        }

  @doc """
  Apply a series of transformation operations to data.
  """
  @spec transform(any(), [operation()], map()) :: {:ok, any()} | {:error, String.t()}
  def transform(data, operations, context \\ %{}) do
    Logger.debug("🔄 Starting data transformation with #{length(operations)} operations")

    try do
      result =
        Enum.reduce(operations, data, fn operation, acc ->
          case apply_operation(acc, operation, context) do
            {:ok, transformed_data} ->
              transformed_data

            {:error, reason} ->
              throw({:transformation_error, reason})
          end
        end)

      Logger.debug("✅ Data transformation completed successfully")
      {:ok, result}
    rescue
      error ->
        error_msg = "Data transformation crashed: #{Exception.message(error)}"
        Logger.error("💥 #{error_msg}")
        {:error, error_msg}
    catch
      {:transformation_error, reason} ->
        Logger.error("❌ Data transformation failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Apply a single transformation operation.
  """
  @spec apply_operation(any(), operation(), map()) :: {:ok, any()} | {:error, String.t()}
  def apply_operation(data, operation, context \\ %{})

  def apply_operation(data, %{"operation" => "filter"} = op, context) do
    field = Map.get(op, "field")
    condition = Map.get(op, "condition")

    case filter_data(data, field, condition, context) do
      {:ok, filtered} -> {:ok, filtered}
      {:error, reason} -> {:error, "Filter operation failed: #{reason}"}
    end
  end

  def apply_operation(data, %{"operation" => "map"} = op, context) do
    field = Map.get(op, "field")
    mapping = Map.get(op, "mapping")
    expression = Map.get(op, "expression")

    case map_data(data, field, mapping, expression, context) do
      {:ok, mapped} -> {:ok, mapped}
      {:error, reason} -> {:error, "Map operation failed: #{reason}"}
    end
  end

  def apply_operation(data, %{"operation" => "aggregate"} = op, context) do
    field = Map.get(op, "field")
    function = Map.get(op, "function", "sum")

    case aggregate_data(data, field, function, context) do
      {:ok, aggregated} -> {:ok, aggregated}
      {:error, reason} -> {:error, "Aggregate operation failed: #{reason}"}
    end
  end

  def apply_operation(data, %{"operation" => "join"} = op, context) do
    left_field = Map.get(op, "left_field")
    right_source = Map.get(op, "right_source")
    join_key = Map.get(op, "join_key")

    case join_data(data, left_field, right_source, join_key, context) do
      {:ok, joined} -> {:ok, joined}
      {:error, reason} -> {:error, "Join operation failed: #{reason}"}
    end
  end

  def apply_operation(data, %{"operation" => "group_by"} = op, context) do
    field = Map.get(op, "field")

    case group_data(data, field, context) do
      {:ok, grouped} -> {:ok, grouped}
      {:error, reason} -> {:error, "Group by operation failed: #{reason}"}
    end
  end

  def apply_operation(data, %{"operation" => "sort"} = op, context) do
    field = Map.get(op, "field")
    order = Map.get(op, "order", "asc")

    case sort_data(data, field, order, context) do
      {:ok, sorted} -> {:ok, sorted}
      {:error, reason} -> {:error, "Sort operation failed: #{reason}"}
    end
  end

  def apply_operation(_data, %{"operation" => unknown}, _context) do
    {:error, "Unknown operation: #{unknown}"}
  end

  # Operation implementations

  defp filter_data(data, field, condition, context) when is_list(data) do
    try do
      filtered =
        Enum.filter(data, fn item ->
          evaluate_condition(item, field, condition, context)
        end)

      {:ok, filtered}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp filter_data(data, field, condition, context) do
    if evaluate_condition(data, field, condition, context) do
      {:ok, data}
    else
      {:ok, nil}
    end
  end

  defp map_data(data, field, mapping, expression, context) when is_list(data) do
    try do
      mapped =
        Enum.map(data, fn item ->
          apply_mapping(item, field, mapping, expression, context)
        end)

      {:ok, mapped}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp map_data(data, field, mapping, expression, context) do
    try do
      result = apply_mapping(data, field, mapping, expression, context)
      {:ok, result}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp aggregate_data(data, field, function, _context) when is_list(data) do
    try do
      values =
        if field do
          data
          |> Enum.map(&get_nested_field(&1, field))
          |> Enum.reject(&is_nil/1)
        else
          data
        end

      result = apply_aggregate_function(values, function)
      {:ok, result}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp aggregate_data(data, field, function, _context) do
    value = if field, do: get_nested_field(data, field), else: data
    result = apply_aggregate_function([value], function)
    {:ok, result}
  end

  defp join_data(data, left_field, right_source, join_key, context) when is_list(data) do
    try do
      right_data = resolve_source(right_source, context)

      joined =
        Enum.map(data, fn item ->
          left_value = get_nested_field(item, left_field || join_key)
          matched_item = find_matching_item(right_data, join_key, left_value)

          if matched_item do
            Map.merge(item, matched_item)
          else
            item
          end
        end)

      {:ok, joined}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp join_data(data, left_field, right_source, join_key, context) do
    try do
      right_data = resolve_source(right_source, context)
      left_value = get_nested_field(data, left_field || join_key)
      matched_item = find_matching_item(right_data, join_key, left_value)

      result =
        if matched_item do
          Map.merge(data, matched_item)
        else
          data
        end

      {:ok, result}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp group_data(data, field, _context) when is_list(data) do
    try do
      grouped = Enum.group_by(data, &get_nested_field(&1, field))
      {:ok, Map.new(grouped, fn {k, v} -> {to_string(k), v} end)}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp group_data(data, _field, _context) do
    {:ok, %{"default" => data}}
  end

  defp sort_data(data, field, order, _context) when is_list(data) do
    try do
      sorted =
        case order do
          "desc" ->
            Enum.sort_by(data, &get_nested_field(&1, field), :desc)

          _ ->
            Enum.sort_by(data, &get_nested_field(&1, field), :asc)
        end

      {:ok, sorted}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp sort_data(data, _field, _order, _context) do
    {:ok, data}
  end

  # Helper functions

  defp evaluate_condition(item, field, condition, context) do
    value = if field, do: get_nested_field(item, field), else: item
    evaluate_expression(condition, value, item, context)
  end

  defp evaluate_expression(condition, value, item, context) do
    # Parse and evaluate condition expressions like "priority == 'high'" or "score > 7"
    cond do
      String.contains?(condition, "==") ->
        [left, right] = String.split(condition, "==", parts: 2)
        left_val = resolve_expression_value(String.trim(left), value, item, context)
        right_val = parse_literal_value(String.trim(right))
        left_val == right_val

      String.contains?(condition, "!=") ->
        [left, right] = String.split(condition, "!=", parts: 2)
        left_val = resolve_expression_value(String.trim(left), value, item, context)
        right_val = parse_literal_value(String.trim(right))
        left_val != right_val

      String.contains?(condition, ">=") ->
        [left, right] = String.split(condition, ">=", parts: 2)
        left_val = resolve_expression_value(String.trim(left), value, item, context)
        right_val = parse_literal_value(String.trim(right))
        compare_values(left_val, right_val) >= 0

      String.contains?(condition, "<=") ->
        [left, right] = String.split(condition, "<=", parts: 2)
        left_val = resolve_expression_value(String.trim(left), value, item, context)
        right_val = parse_literal_value(String.trim(right))
        compare_values(left_val, right_val) <= 0

      String.contains?(condition, ">") ->
        [left, right] = String.split(condition, ">", parts: 2)
        left_val = resolve_expression_value(String.trim(left), value, item, context)
        right_val = parse_literal_value(String.trim(right))
        compare_values(left_val, right_val) > 0

      String.contains?(condition, "<") ->
        [left, right] = String.split(condition, "<", parts: 2)
        left_val = resolve_expression_value(String.trim(left), value, item, context)
        right_val = parse_literal_value(String.trim(right))
        compare_values(left_val, right_val) < 0

      String.contains?(condition, "contains") ->
        [left, right] = String.split(condition, "contains", parts: 2)
        left_val = resolve_expression_value(String.trim(left), value, item, context)
        right_val = parse_literal_value(String.trim(right))
        contains_value?(left_val, right_val)

      true ->
        # Simple truthy check
        !!resolve_expression_value(condition, value, item, context)
    end
  end

  defp resolve_expression_value(expr, default_value, item, _context) do
    cond do
      expr == "value" -> default_value
      String.contains?(expr, ".") -> get_nested_field(item, expr)
      true -> get_nested_field(item, expr) || default_value
    end
  end

  defp parse_literal_value(value) do
    value = String.trim(value)

    cond do
      # String literal
      String.starts_with?(value, "'") and String.ends_with?(value, "'") ->
        String.slice(value, 1..-2//1)

      String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
        String.slice(value, 1..-2//1)

      # Number
      String.match?(value, ~r/^\d+$/) ->
        String.to_integer(value)

      String.match?(value, ~r/^\d+\.\d+$/) ->
        String.to_float(value)

      # Boolean
      value == "true" ->
        true

      value == "false" ->
        false

      # Null
      value in ["null", "nil"] ->
        nil

      true ->
        value
    end
  end

  defp compare_values(left, right) when is_number(left) and is_number(right) do
    cond do
      left > right -> 1
      left < right -> -1
      true -> 0
    end
  end

  defp compare_values(left, right) when is_binary(left) and is_binary(right) do
    cond do
      left > right -> 1
      left < right -> -1
      true -> 0
    end
  end

  defp compare_values(left, right) do
    cond do
      left > right -> 1
      left < right -> -1
      true -> 0
    end
  end

  defp contains_value?(haystack, needle) when is_list(haystack) do
    Enum.any?(haystack, &(&1 == needle))
  end

  defp contains_value?(haystack, needle) when is_binary(haystack) and is_binary(needle) do
    String.contains?(haystack, needle)
  end

  defp contains_value?(_, _), do: false

  defp apply_mapping(item, field, mapping, expression, context) do
    cond do
      mapping ->
        apply_field_mapping(item, field, mapping, context)

      expression ->
        apply_expression_mapping(item, field, expression, context)

      true ->
        item
    end
  end

  defp apply_field_mapping(item, field, mapping, _context) when is_map(mapping) do
    if field do
      current_value = get_nested_field(item, field)
      new_value = Map.get(mapping, to_string(current_value), current_value)
      set_nested_field(item, field, new_value)
    else
      Map.merge(item, mapping)
    end
  end

  defp apply_expression_mapping(item, field, expression, _context) do
    # Simple expression evaluation - can be extended
    case expression do
      "uppercase" when is_binary(field) ->
        current_value = get_nested_field(item, field)

        if is_binary(current_value) do
          set_nested_field(item, field, String.upcase(current_value))
        else
          item
        end

      "lowercase" when is_binary(field) ->
        current_value = get_nested_field(item, field)

        if is_binary(current_value) do
          set_nested_field(item, field, String.downcase(current_value))
        else
          item
        end

      _ ->
        item
    end
  end

  defp apply_aggregate_function(values, function) do
    case function do
      "sum" ->
        values |> Enum.filter(&is_number/1) |> Enum.sum()

      "average" ->
        numeric_values = Enum.filter(values, &is_number/1)

        if length(numeric_values) > 0 do
          Enum.sum(numeric_values) / length(numeric_values)
        else
          0
        end

      "count" ->
        length(values)

      "max" ->
        values |> Enum.filter(&is_number/1) |> Enum.max(&>=/2, fn -> 0 end)

      "min" ->
        values |> Enum.filter(&is_number/1) |> Enum.min(&<=/2, fn -> 0 end)

      "first" ->
        List.first(values)

      "last" ->
        List.last(values)

      "unique" ->
        Enum.uniq(values)

      _ ->
        values
    end
  end

  defp resolve_source(source, context) do
    # Parse source like "previous_response:step_name" or "context:field"
    case String.split(source, ":", parts: 2) do
      ["previous_response", step_name] ->
        get_in(context, [:results, step_name]) || []

      ["context", field] ->
        get_nested_field(context, field) || []

      [step_name] ->
        get_in(context, [:results, step_name]) || []

      _ ->
        []
    end
  end

  defp find_matching_item(data, join_key, target_value) when is_list(data) do
    Enum.find(data, fn item ->
      get_nested_field(item, join_key) == target_value
    end)
  end

  defp find_matching_item(data, join_key, target_value) when is_map(data) do
    if get_nested_field(data, join_key) == target_value do
      data
    else
      nil
    end
  end

  defp find_matching_item(_, _, _), do: nil

  defp get_nested_field(data, field_path) when is_binary(field_path) do
    keys = String.split(field_path, ".")
    get_nested_field(data, keys)
  end

  defp get_nested_field(data, [key]) when is_map(data) do
    Map.get(data, key) || Map.get(data, String.to_atom(key))
  end

  defp get_nested_field(data, [key | rest]) when is_map(data) do
    next_data = Map.get(data, key) || Map.get(data, String.to_atom(key))
    get_nested_field(next_data, rest)
  end

  defp get_nested_field(_, _), do: nil

  defp set_nested_field(data, field_path, value) when is_binary(field_path) do
    keys = String.split(field_path, ".")
    set_nested_field(data, keys, value)
  end

  defp set_nested_field(data, [key], value) when is_map(data) do
    Map.put(data, key, value)
  end

  defp set_nested_field(data, [key | rest], value) when is_map(data) do
    current_value = Map.get(data, key, %{})
    new_value = set_nested_field(current_value, rest, value)
    Map.put(data, key, new_value)
  end

  defp set_nested_field(data, _, _), do: data
end
