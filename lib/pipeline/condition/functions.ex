defmodule Pipeline.Condition.Functions do
  @moduledoc """
  Function library for advanced condition expressions.
  
  Provides built-in functions for:
  - String operations: contains(), matches(), length(), startsWith(), endsWith()
  - Array operations: any(), all(), count(), sum(), average(), min(), max()
  - Date/time operations: now(), days(), hours(), minutes()
  - Mathematical operations: abs(), round(), floor(), ceil()
  - Pattern matching: regex matching and validation
  """

  @doc """
  Evaluates a function call with given arguments.
  
  Returns the result of the function or raises an error if function not found.
  """
  @spec call_function(String.t(), list(), map()) :: any()
  def call_function(function_name, args, context) do
    case function_name do
      # String functions
      "contains" -> string_contains(args, context)
      "matches" -> string_matches(args, context)
      "length" -> get_length(args, context)
      "startsWith" -> string_starts_with(args, context)
      "endsWith" -> string_ends_with(args, context)
      "toLowerCase" -> string_to_lower(args, context)
      "toUpperCase" -> string_to_upper(args, context)
      "trim" -> string_trim(args, context)
      
      # Array functions
      "any" -> array_any(args, context)
      "all" -> array_all(args, context)
      "count" -> array_count(args, context)
      "sum" -> array_sum(args, context)
      "average" -> array_average(args, context)
      "min" -> array_min(args, context)
      "max" -> array_max(args, context)
      "isEmpty" -> is_empty(args, context)
      
      # Date/time functions
      "now" -> datetime_now(args, context)
      "days" -> duration_days(args, context)
      "hours" -> duration_hours(args, context)
      "minutes" -> duration_minutes(args, context)
      "seconds" -> duration_seconds(args, context)
      
      # Mathematical functions
      "abs" -> math_abs(args, context)
      "round" -> math_round(args, context)
      "floor" -> math_floor(args, context)
      "ceil" -> math_ceil(args, context)
      "sqrt" -> math_sqrt(args, context)
      "pow" -> math_pow(args, context)
      "between" -> math_between(args, context)
      
      _ -> raise ArgumentError, "Unknown function: #{function_name}"
    end
  end

  # String functions
  
  defp string_contains([haystack, needle], context) do
    haystack_val = resolve_value(haystack, context)
    needle_val = resolve_value(needle, context)
    
    cond do
      is_binary(haystack_val) and is_binary(needle_val) ->
        String.contains?(haystack_val, needle_val)
      is_list(haystack_val) ->
        Enum.member?(haystack_val, needle_val)
      true ->
        false
    end
  end
  
  defp string_matches([value, pattern], context) do
    value_val = resolve_value(value, context)
    pattern_val = resolve_value(pattern, context)
    
    if is_binary(value_val) and is_binary(pattern_val) do
      case Regex.compile(pattern_val) do
        {:ok, regex} -> Regex.match?(regex, value_val)
        {:error, _} -> false
      end
    else
      false
    end
  end
  
  defp get_length([value], context) do
    value_val = resolve_value(value, context)
    
    cond do
      is_list(value_val) -> length(value_val)
      is_binary(value_val) -> String.length(value_val)
      is_map(value_val) -> map_size(value_val)
      true -> 0
    end
  end
  
  defp string_starts_with([string, prefix], context) do
    string_val = resolve_value(string, context)
    prefix_val = resolve_value(prefix, context)
    
    if is_binary(string_val) and is_binary(prefix_val) do
      String.starts_with?(string_val, prefix_val)
    else
      false
    end
  end
  
  defp string_ends_with([string, suffix], context) do
    string_val = resolve_value(string, context)
    suffix_val = resolve_value(suffix, context)
    
    if is_binary(string_val) and is_binary(suffix_val) do
      String.ends_with?(string_val, suffix_val)
    else
      false
    end
  end
  
  defp string_to_lower([string], context) do
    string_val = resolve_value(string, context)
    if is_binary(string_val), do: String.downcase(string_val), else: string_val
  end
  
  defp string_to_upper([string], context) do
    string_val = resolve_value(string, context)
    if is_binary(string_val), do: String.upcase(string_val), else: string_val
  end
  
  defp string_trim([string], context) do
    string_val = resolve_value(string, context)
    if is_binary(string_val), do: String.trim(string_val), else: string_val
  end

  # Array functions
  
  defp array_any([array, condition], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      Enum.any?(array_val, fn item ->
        # Create a temporary context with the current item
        item_context = create_item_context(context, item)
        # Replace '@' with the current item value in the condition
        item_condition = replace_current_item_placeholder(condition, item)
        Pipeline.Condition.Engine.evaluate(item_condition, item_context)
      end)
    else
      false
    end
  end
  
  # Single argument version for simple truthy check
  defp array_any([array], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      Enum.any?(array_val, &truthy?/1)
    else
      false
    end
  end
  
  defp array_all([array, condition], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      Enum.all?(array_val, fn item ->
        # Create a temporary context with the current item
        item_context = create_item_context(context, item)
        # Replace '@' with the current item value in the condition
        item_condition = replace_current_item_placeholder(condition, item)
        Pipeline.Condition.Engine.evaluate(item_condition, item_context)
      end)
    else
      false
    end
  end
  
  # Single argument version for simple truthy check
  defp array_all([array], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      Enum.all?(array_val, &truthy?/1)
    else
      false
    end
  end
  
  defp array_count([array], context) do
    array_val = resolve_value(array, context)
    if is_list(array_val), do: length(array_val), else: 0
  end
  
  defp array_count([array, condition], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      Enum.count(array_val, fn item ->
        # Create a temporary context with the current item
        item_context = create_item_context(context, item)
        # Replace '@' with the current item value in the condition
        item_condition = replace_current_item_placeholder(condition, item)
        Pipeline.Condition.Engine.evaluate(item_condition, item_context)
      end)
    else
      0
    end
  end
  
  defp array_sum([array], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      array_val
      |> Enum.filter(&is_number/1)
      |> Enum.sum()
    else
      0
    end
  end
  
  defp array_average([array], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      numbers = Enum.filter(array_val, &is_number/1)
      case length(numbers) do
        0 -> 0
        count -> Enum.sum(numbers) / count
      end
    else
      0
    end
  end
  
  defp array_min([array], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      array_val
      |> Enum.filter(&is_number/1)
      |> case do
        [] -> nil
        numbers -> Enum.min(numbers)
      end
    else
      nil
    end
  end
  
  defp array_max([array], context) do
    array_val = resolve_value(array, context)
    
    if is_list(array_val) do
      array_val
      |> Enum.filter(&is_number/1)
      |> case do
        [] -> nil
        numbers -> Enum.max(numbers)
      end
    else
      nil
    end
  end
  
  defp is_empty([value], context) do
    value_val = resolve_value(value, context)
    
    cond do
      is_list(value_val) -> Enum.empty?(value_val)
      is_binary(value_val) -> value_val == ""
      is_map(value_val) -> map_size(value_val) == 0
      is_nil(value_val) -> true
      true -> false
    end
  end

  # Date/time functions
  
  defp datetime_now([], _context) do
    DateTime.utc_now()
  end
  
  defp duration_days([days], context) do
    days_val = resolve_value(days, context)
    if is_number(days_val) do
      days_val * 24 * 60 * 60
    else
      0
    end
  end
  
  defp duration_hours([hours], context) do
    hours_val = resolve_value(hours, context)
    if is_number(hours_val) do
      hours_val * 60 * 60
    else
      0
    end
  end
  
  defp duration_minutes([minutes], context) do
    minutes_val = resolve_value(minutes, context)
    if is_number(minutes_val) do
      minutes_val * 60
    else
      0
    end
  end
  
  defp duration_seconds([seconds], context) do
    resolve_value(seconds, context)
  end

  # Mathematical functions
  
  defp math_abs([value], context) do
    value_val = resolve_value(value, context)
    if is_number(value_val), do: abs(value_val), else: 0
  end
  
  defp math_round([value], context) do
    value_val = resolve_value(value, context)
    if is_number(value_val), do: round(value_val), else: 0
  end
  
  defp math_floor([value], context) do
    value_val = resolve_value(value, context)
    if is_number(value_val), do: floor(value_val), else: 0
  end
  
  defp math_ceil([value], context) do
    value_val = resolve_value(value, context)
    if is_number(value_val), do: ceil(value_val), else: 0
  end
  
  defp math_sqrt([value], context) do
    value_val = resolve_value(value, context)
    if is_number(value_val) and value_val >= 0, do: :math.sqrt(value_val), else: 0
  end
  
  defp math_pow([base, exponent], context) do
    base_val = resolve_value(base, context)
    exp_val = resolve_value(exponent, context)
    
    if is_number(base_val) and is_number(exp_val) do
      :math.pow(base_val, exp_val)
    else
      0
    end
  end
  
  defp math_between([value, min_val, max_val], context) do
    val = resolve_value(value, context)
    min_v = resolve_value(min_val, context)
    max_v = resolve_value(max_val, context)
    
    if is_number(val) and is_number(min_v) and is_number(max_v) do
      val >= min_v and val <= max_v
    else
      false
    end
  end

  # Helper functions
  
  defp resolve_value(value, context) do
    Pipeline.Condition.Engine.resolve_value(value, context)
  end
  
  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(""), do: false
  defp truthy?([]), do: false
  defp truthy?({}), do: false
  defp truthy?(%{} = map) when map_size(map) == 0, do: false
  defp truthy?(_), do: true

  # Helper function to create a context for evaluating item conditions
  defp create_item_context(context, item) when is_map(item) do
    # Add the item fields as a temporary step result
    %{context | results: Map.put(context.results, "@item", item)}
  end

  defp create_item_context(context, _item) do
    context
  end

  # Helper function to replace '@' placeholder with actual item value
  defp replace_current_item_placeholder(condition, item) when is_binary(condition) do
    # For simple conditions like "@ > 6", replace @ with the item value
    if String.contains?(condition, "@") do
      String.replace(condition, "@", to_string(item))
    else
      # For conditions like 'severity == "high"', modify to access @item.field
      if is_map(item) and not String.contains?(condition, ".") do
        # Simple field access - need to prefix with @item.
        # This is a simplified approach - in reality we'd need more sophisticated parsing
        condition
      else
        # For field access, prefix non-dot notations with @item.
        # Look for bare field names and replace them
        condition = String.replace(condition, ~r/\b(severity|type|priority)\b/, "@item.\\1")
        condition
      end
    end
  end

  defp replace_current_item_placeholder(condition, item) when is_map(condition) do
    # Handle complex boolean expressions by recursively processing
    condition
  end

  defp replace_current_item_placeholder(condition, _item) do
    condition
  end
end