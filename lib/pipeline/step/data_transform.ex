defmodule Pipeline.Step.DataTransform do
  @moduledoc """
  Data transformation step executor for manipulating structured data between pipeline steps.

  This step type provides powerful data transformation capabilities including:
  - Filtering data based on conditions
  - Mapping and transforming fields
  - Aggregating values with functions like sum, average, count
  - Joining data from multiple sources
  - Grouping data by field values
  - Sorting data by field values

  Uses JSONPath-like syntax for field access and supports chaining multiple operations.

  ## Configuration

  - `input_source` (required): Source of input data (e.g., "previous_response:step_name")
  - `operations` (required): List of transformation operations to apply
  - `output_field` (optional): Field name to store result in context (defaults to step name)

  ## Example YAML Configuration

  ```yaml
  - name: "process_results"
    type: "data_transform"
    input_source: "previous_response:analysis"
    operations:
      - operation: "filter"
        field: "recommendations"
        condition: "priority == 'high'"
      - operation: "aggregate"
        field: "scores"
        function: "average"
      - operation: "join"
        left_field: "files"
        right_source: "previous_response:file_metadata"
        join_key: "filename"
    output_field: "processed_data"
  ```

  ## Supported Operations

  ### Filter
  Filter items based on conditions.
  ```yaml
  - operation: "filter"
    field: "status"
    condition: "status == 'active'"
  ```

  ### Map
  Transform fields with mappings or expressions.
  ```yaml
  - operation: "map"
    field: "priority"
    mapping:
      "1": "high"
      "2": "medium"
      "3": "low"
  ```

  ### Aggregate
  Aggregate values using functions.
  ```yaml
  - operation: "aggregate"
    field: "scores"
    function: "average"  # sum, average, count, max, min, first, last, unique
  ```

  ### Join
  Join data from another source.
  ```yaml
  - operation: "join"
    left_field: "user_id"
    right_source: "previous_response:users"
    join_key: "id"
  ```

  ### Group By
  Group items by field values.
  ```yaml
  - operation: "group_by"
    field: "category"
  ```

  ### Sort
  Sort items by field values.
  ```yaml
  - operation: "sort"
    field: "created_at"
    order: "desc"  # asc or desc
  ```
  """

  require Logger
  alias Pipeline.Data.Transformer

  # Use lazy evaluation for datasets with >1000 items
  @lazy_threshold 1000

  @doc """
  Execute a data transformation step.
  """
  def execute(step, context) do
    Logger.info("🔄 Executing data_transform step: #{step["name"]}")

    with {:ok, input_data} <- get_input_data(step, context),
         {:ok, transformed_data} <- apply_transformations(input_data, step, context),
         {:ok, final_result} <- format_result(transformed_data, step) do
      output_field = step["output_field"] || step["name"]
      Logger.info("✅ Data transformation completed successfully")

      result = %{
        output_field => final_result,
        "metadata" => %{
          "operation_count" => length(step["operations"] || []),
          "input_type" => get_data_type(input_data),
          "output_type" => get_data_type(final_result),
          "processed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }

      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("❌ Data transformation failed: #{reason}")
        {:error, reason}
    end
  end

  # Private functions

  defp get_input_data(step, context) do
    input_source = step["input_source"]

    if input_source do
      case resolve_input_source(input_source, context) do
        nil ->
          {:error, "Input source '#{input_source}' not found"}

        data ->
          {:ok, data}
      end
    else
      {:error, "input_source is required for data_transform step"}
    end
  end

  defp resolve_input_source(source, context) do
    case String.split(source, ":", parts: 3) do
      ["previous_response", step_name, field_path] ->
        # Handle nested field paths like "previous_response:step_name:field"
        case get_in(context, [:results, step_name]) do
          nil -> nil
          step_result -> get_nested_field(step_result, field_path)
        end

      ["previous_response", step_name] ->
        get_in(context, [:results, step_name])

      ["context", field] ->
        get_nested_field(context, field)

      [step_name] ->
        # First try to get from variable state, then from step results
        case Map.get(context, :variable_state) do
          nil ->
            get_in(context, [:results, step_name])

          variable_state ->
            try do
              case Pipeline.State.VariableEngine.get_variable(variable_state, step_name) do
                nil -> get_in(context, [:results, step_name])
                variable_value -> variable_value
              end
            rescue
              _ -> get_in(context, [:results, step_name])
            end
        end

      _ ->
        nil
    end
  end

  defp apply_transformations(input_data, step, context) do
    operations = step["operations"] || []

    if Enum.empty?(operations) do
      Logger.warning("⚠️  No operations specified, returning input data unchanged")
      {:ok, input_data}
    else
      Logger.debug("Applying #{length(operations)} transformation operations")

      # Check if we should use lazy evaluation
      if should_use_lazy_evaluation?(input_data, operations, step) do
        Logger.info("📊 Using lazy evaluation for large dataset transformation")
        apply_lazy_transformations(input_data, operations, context)
      else
        Transformer.transform(input_data, operations, context)
      end
    end
  end

  defp should_use_lazy_evaluation?(input_data, operations, step) do
    # Enable lazy evaluation if:
    # 1. Explicitly enabled in step config
    # 2. Data size exceeds threshold
    # 3. Contains streaming operations (but only if data is large enough)

    lazy_enabled = get_in(step, ["lazy", "enabled"]) || false
    large_dataset = is_list(input_data) && length(input_data) > @lazy_threshold
    has_streaming_ops = Enum.any?(operations, &is_streaming_operation?/1) && large_dataset

    lazy_enabled || large_dataset || has_streaming_ops
  end

  defp is_streaming_operation?(operation) do
    streaming_ops = ["filter", "map", "sort"]
    operation["operation"] in streaming_ops
  end

  defp apply_lazy_transformations(input_data, operations, context) do
    try do
      # Convert input to stream if it's a list
      data_stream =
        case input_data do
          list when is_list(list) ->
            # Process in chunks of 100
            Stream.chunk_every(list, 100)

          _ ->
            [input_data] |> Stream.cycle() |> Stream.take(1)
        end

      # Apply operations lazily
      result_stream =
        operations
        |> Enum.reduce(data_stream, fn operation, acc_stream ->
          apply_lazy_operation(operation, acc_stream, context)
        end)

      # Materialize the result
      final_result =
        result_stream
        |> Stream.flat_map(fn chunk ->
          case chunk do
            list when is_list(list) -> list
            item -> [item]
          end
        end)
        |> Enum.to_list()

      {:ok, final_result}
    rescue
      error ->
        {:error, "Lazy transformation failed: #{Exception.message(error)}"}
    end
  end

  defp apply_lazy_operation(operation, data_stream, context) do
    case operation["operation"] do
      "filter" ->
        apply_lazy_filter(operation, data_stream, context)

      "map" ->
        apply_lazy_map(operation, data_stream, context)

      "sort" ->
        apply_lazy_sort(operation, data_stream, context)

      other ->
        # For non-streaming operations, materialize and use regular transformer
        Logger.debug("Materializing stream for non-lazy operation: #{other}")

        materialized =
          data_stream
          |> Stream.flat_map(fn chunk ->
            case chunk do
              list when is_list(list) -> list
              item -> [item]
            end
          end)
          |> Enum.to_list()

        case Transformer.transform(materialized, [operation], context) do
          {:ok, result} -> [result] |> Stream.cycle() |> Stream.take(1)
          {:error, _} -> Stream.cycle([]) |> Stream.take(0)
        end
    end
  end

  defp apply_lazy_filter(operation, data_stream, _context) do
    field = operation["field"]
    condition = operation["condition"]

    data_stream
    |> Stream.map(fn chunk ->
      case chunk do
        list when is_list(list) ->
          Enum.filter(list, fn item ->
            evaluate_filter_condition(item, field, condition)
          end)

        item ->
          if evaluate_filter_condition(item, field, condition) do
            [item]
          else
            []
          end
      end
    end)
    |> Stream.reject(&Enum.empty?/1)
  end

  defp apply_lazy_map(operation, data_stream, _context) do
    field = operation["field"]
    mapping = operation["mapping"] || %{}

    data_stream
    |> Stream.map(fn chunk ->
      case chunk do
        list when is_list(list) ->
          Enum.map(list, fn item ->
            apply_field_mapping(item, field, mapping)
          end)

        item ->
          [apply_field_mapping(item, field, mapping)]
      end
    end)
  end

  defp apply_lazy_sort(operation, data_stream, _context) do
    field = operation["field"]
    order = operation["order"] || "asc"

    # For sorting, we need to collect all data first
    materialized =
      data_stream
      |> Stream.flat_map(fn chunk ->
        case chunk do
          list when is_list(list) -> list
          item -> [item]
        end
      end)
      |> Enum.to_list()

    sorted = sort_data(materialized, field, order)

    # Return as chunked stream
    sorted
    |> Stream.chunk_every(100)
  end

  defp evaluate_filter_condition(item, field, condition) do
    field_value = get_nested_field(item, field)

    # Simple condition evaluation (could be enhanced)
    case String.split(condition, " ", parts: 3) do
      [field_name, "==", value] when field_name == field ->
        to_string(field_value) == String.trim(value, "'\"")

      [field_name, "!=", value] when field_name == field ->
        to_string(field_value) != String.trim(value, "'\"")

      [field_name, ">", value] when field_name == field ->
        case {field_value, Float.parse(value)} do
          {num, {target, _}} when is_number(num) -> num > target
          _ -> false
        end

      # Handle condition formats like "priority == 'high'"
      [condition_str] ->
        case String.split(condition_str, ~r/\s+(==|!=|>|<)\s+/, parts: 3, include_captures: true) do
          [field_name, "==", value] when field_name == field ->
            to_string(field_value) == String.trim(value, "'\"")

          [field_name, "!=", value] when field_name == field ->
            to_string(field_value) != String.trim(value, "'\"")

          [field_name, ">", value] when field_name == field ->
            case {field_value, Float.parse(value)} do
              {num, {target, _}} when is_number(num) -> num > target
              _ -> false
            end

          _ ->
            # Default to true for unknown conditions
            true
        end

      _ ->
        # Default to true for unknown conditions  
        true
    end
  end

  defp apply_field_mapping(item, field, mapping) when is_map(item) do
    current_value = get_nested_field(item, field)
    mapped_value = Map.get(mapping, to_string(current_value), current_value)
    put_nested_field(item, field, mapped_value)
  end

  defp apply_field_mapping(item, _field, _mapping), do: item

  defp sort_data(data, field, order) do
    data
    |> Enum.sort_by(fn item -> get_nested_field(item, field) end)
    |> then(fn sorted ->
      case order do
        "desc" -> Enum.reverse(sorted)
        _ -> sorted
      end
    end)
  end

  defp put_nested_field(data, field_path, value) when is_map(data) do
    fields = String.split(field_path, ".")
    put_in(data, Enum.map(fields, &Access.key(&1, %{})), value)
  end


  defp format_result(data, step) do
    # Apply any output formatting if specified
    case step["output_format"] do
      "json" ->
        try do
          json_data = Jason.encode!(data)
          {:ok, json_data}
        rescue
          error ->
            {:error, "Failed to encode result as JSON: #{Exception.message(error)}"}
        end

      "string" ->
        {:ok, to_string(data)}

      "count" when is_list(data) ->
        {:ok, length(data)}

      "count" ->
        {:ok, 1}

      nil ->
        {:ok, data}

      format ->
        Logger.warning("Unknown output format '#{format}', returning raw data")
        {:ok, data}
    end
  end

  defp get_data_type(data) when is_list(data), do: "list"
  defp get_data_type(data) when is_map(data), do: "map"
  defp get_data_type(data) when is_binary(data), do: "string"
  defp get_data_type(data) when is_number(data), do: "number"
  defp get_data_type(data) when is_boolean(data), do: "boolean"
  defp get_data_type(nil), do: "null"
  defp get_data_type(_), do: "unknown"

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
end
