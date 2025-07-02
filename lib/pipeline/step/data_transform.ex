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
    case String.split(source, ":", parts: 2) do
      ["previous_response", step_name] ->
        get_in(context, [:results, step_name])

      ["context", field] ->
        get_nested_field(context, field)

      [step_name] ->
        get_in(context, [:results, step_name])

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
      Transformer.transform(input_data, operations, context)
    end
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
