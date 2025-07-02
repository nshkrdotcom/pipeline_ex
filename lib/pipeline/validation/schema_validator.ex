defmodule Pipeline.Validation.SchemaValidator do
  @moduledoc """
  JSON Schema-based validation for pipeline step outputs.

  Provides comprehensive validation of step outputs against JSON schemas,
  ensuring structured data exchange between pipeline steps.
  """

  require Logger

  @type schema :: map()
  @type validation_result :: {:ok, any()} | {:error, validation_errors()}
  @type validation_errors :: [validation_error()]
  @type validation_error :: %{
          path: String.t(),
          message: String.t(),
          value: any(),
          schema: map()
        }

  @doc """
  Validate data against a JSON schema.

  ## Examples

      iex> schema = %{"type" => "object", "required" => ["name"], "properties" => %{"name" => %{"type" => "string"}}}
      iex> data = %{"name" => "test"}
      iex> Pipeline.Validation.SchemaValidator.validate(data, schema)
      {:ok, %{"name" => "test"}}
      
      iex> data = %{"age" => 25}
      iex> Pipeline.Validation.SchemaValidator.validate(data, schema)
      {:error, [%{path: "", message: "Required property 'name' is missing", value: %{"age" => 25}, schema: schema}]}
  """
  @spec validate(any(), schema()) :: validation_result()
  def validate(data, schema) do
    case validate_value(data, schema, "") do
      [] -> {:ok, data}
      errors -> {:error, errors}
    end
  end

  @doc """
  Validate step output with detailed error reporting.

  Returns a structured result with validation status and detailed error information.
  """
  @spec validate_step_output(String.t(), any(), schema()) ::
          {:ok, any()} | {:error, String.t(), validation_errors()}
  def validate_step_output(step_name, data, schema) do
    case validate(data, schema) do
      {:ok, validated_data} ->
        Logger.debug("✅ Schema validation passed for step: #{step_name}")
        {:ok, validated_data}

      {:error, errors} ->
        error_message = format_validation_errors(step_name, errors)
        Logger.error("❌ Schema validation failed for step: #{step_name}")
        Logger.error(error_message)
        {:error, error_message, errors}
    end
  end

  @doc """
  Check if a schema is valid JSON Schema format.
  """
  @spec valid_schema?(schema()) :: boolean()
  def valid_schema?(schema) when is_map(schema) do
    # Basic schema validation - check for required fields
    case schema do
      %{"type" => type} when is_binary(type) ->
        valid_type?(type)

      _ ->
        false
    end
  end

  def valid_schema?(_), do: false

  @doc """
  Get supported JSON Schema types.
  """
  @spec supported_types() :: [String.t()]
  def supported_types do
    ["string", "number", "integer", "boolean", "object", "array", "null"]
  end

  # Private validation functions

  defp validate_value(data, schema, path) do
    case schema["type"] do
      "object" -> validate_object(data, schema, path)
      "array" -> validate_array(data, schema, path)
      "string" -> validate_string(data, schema, path)
      "number" -> validate_number(data, schema, path)
      "integer" -> validate_integer(data, schema, path)
      "boolean" -> validate_boolean(data, schema, path)
      "null" -> validate_null(data, schema, path)
      nil -> validate_any(data, schema, path)
      type -> [error(path, "Unsupported schema type: #{type}", data, schema)]
    end
  end

  defp validate_object(data, schema, path) when is_map(data) do
    # Check required properties
    required_errors = validate_required_properties(data, schema, path)

    # Validate properties
    property_errors = validate_object_properties(data, schema, path)

    # Check additional properties if specified
    additional_errors = validate_additional_properties(data, schema, path)

    required_errors ++ property_errors ++ additional_errors
  end

  defp validate_object(data, schema, path) do
    [error(path, "Expected object, got #{type_name(data)}", data, schema)]
  end

  defp validate_array(data, schema, path) when is_list(data) do
    # Validate array length constraints
    length_errors = validate_array_length(data, schema, path)

    # Validate items
    item_errors = validate_array_items(data, schema, path)

    length_errors ++ item_errors
  end

  defp validate_array(data, schema, path) do
    [error(path, "Expected array, got #{type_name(data)}", data, schema)]
  end

  defp validate_string(data, schema, path) when is_binary(data) do
    # Validate string length constraints
    length_errors = validate_string_length(data, schema, path)

    # Validate pattern if specified
    pattern_errors = validate_string_pattern(data, schema, path)

    # Validate enum if specified
    enum_errors = validate_enum(data, schema, path)

    length_errors ++ pattern_errors ++ enum_errors
  end

  defp validate_string(data, schema, path) do
    [error(path, "Expected string, got #{type_name(data)}", data, schema)]
  end

  defp validate_number(data, schema, path) when is_number(data) do
    validate_numeric_constraints(data, schema, path)
  end

  defp validate_number(data, schema, path) do
    [error(path, "Expected number, got #{type_name(data)}", data, schema)]
  end

  defp validate_integer(data, schema, path) when is_integer(data) do
    validate_numeric_constraints(data, schema, path)
  end

  defp validate_integer(data, schema, path) do
    [error(path, "Expected integer, got #{type_name(data)}", data, schema)]
  end

  defp validate_boolean(data, _schema, _path) when is_boolean(data) do
    []
  end

  defp validate_boolean(data, schema, path) do
    [error(path, "Expected boolean, got #{type_name(data)}", data, schema)]
  end

  defp validate_null(nil, _schema, _path), do: []

  defp validate_null(data, schema, path) do
    [error(path, "Expected null, got #{type_name(data)}", data, schema)]
  end

  defp validate_any(_data, _schema, _path), do: []

  defp validate_required_properties(data, schema, path) do
    required = schema["required"] || []

    Enum.flat_map(required, fn property ->
      if Map.has_key?(data, property) do
        []
      else
        [error(path, "Required property '#{property}' is missing", data, schema)]
      end
    end)
  end

  defp validate_object_properties(data, schema, path) do
    properties = schema["properties"] || %{}

    Enum.flat_map(data, fn {key, value} ->
      case Map.get(properties, key) do
        nil ->
          []

        property_schema ->
          property_path = if path == "", do: key, else: "#{path}.#{key}"
          validate_value(value, property_schema, property_path)
      end
    end)
  end

  defp validate_additional_properties(data, schema, path) do
    case schema["additionalProperties"] do
      false ->
        properties = schema["properties"] || %{}
        extra_keys = Map.keys(data) -- Map.keys(properties)

        Enum.map(extra_keys, fn key ->
          property_path = if path == "", do: key, else: "#{path}.#{key}"

          error(
            property_path,
            "Additional property '#{key}' is not allowed",
            Map.get(data, key),
            schema
          )
        end)

      nil ->
        []

      true ->
        []

      additional_schema when is_map(additional_schema) ->
        properties = schema["properties"] || %{}
        extra_keys = Map.keys(data) -- Map.keys(properties)

        Enum.flat_map(extra_keys, fn key ->
          property_path = if path == "", do: key, else: "#{path}.#{key}"
          validate_value(Map.get(data, key), additional_schema, property_path)
        end)
    end
  end

  defp validate_array_length(data, schema, path) do
    errors = []

    errors =
      if min_items = schema["minItems"] do
        if length(data) < min_items do
          [error(path, "Array must have at least #{min_items} items", data, schema) | errors]
        else
          errors
        end
      else
        errors
      end

    if max_items = schema["maxItems"] do
      if length(data) > max_items do
        [error(path, "Array must have at most #{max_items} items", data, schema) | errors]
      else
        errors
      end
    else
      errors
    end
  end

  defp validate_array_items(data, schema, path) do
    case schema["items"] do
      nil ->
        []

      item_schema when is_map(item_schema) ->
        data
        |> Enum.with_index()
        |> Enum.flat_map(fn {item, index} ->
          item_path = "#{path}[#{index}]"
          validate_value(item, item_schema, item_path)
        end)
    end
  end

  defp validate_string_length(data, schema, path) do
    errors = []

    errors =
      if min_length = schema["minLength"] do
        if String.length(data) < min_length do
          [
            error(path, "String must be at least #{min_length} characters long", data, schema)
            | errors
          ]
        else
          errors
        end
      else
        errors
      end

    if max_length = schema["maxLength"] do
      if String.length(data) > max_length do
        [
          error(path, "String must be at most #{max_length} characters long", data, schema)
          | errors
        ]
      else
        errors
      end
    else
      errors
    end
  end

  defp validate_string_pattern(data, schema, path) do
    case schema["pattern"] do
      nil ->
        []

      pattern ->
        case Regex.compile(pattern) do
          {:ok, regex} ->
            if Regex.match?(regex, data) do
              []
            else
              [error(path, "String does not match pattern: #{pattern}", data, schema)]
            end

          {:error, _} ->
            [error(path, "Invalid regex pattern: #{pattern}", data, schema)]
        end
    end
  end

  defp validate_enum(data, schema, path) do
    case schema["enum"] do
      nil ->
        []

      enum_values when is_list(enum_values) ->
        if data in enum_values do
          []
        else
          [error(path, "Value must be one of: #{inspect(enum_values)}", data, schema)]
        end

      _ ->
        []
    end
  end

  defp validate_numeric_constraints(data, schema, path) do
    errors = []

    errors =
      if minimum = schema["minimum"] do
        if data < minimum do
          [error(path, "Value must be >= #{minimum}", data, schema) | errors]
        else
          errors
        end
      else
        errors
      end

    errors =
      if maximum = schema["maximum"] do
        if data > maximum do
          [error(path, "Value must be <= #{maximum}", data, schema) | errors]
        else
          errors
        end
      else
        errors
      end

    errors =
      if exclusive_minimum = schema["exclusiveMinimum"] do
        if data <= exclusive_minimum do
          [error(path, "Value must be > #{exclusive_minimum}", data, schema) | errors]
        else
          errors
        end
      else
        errors
      end

    if exclusive_maximum = schema["exclusiveMaximum"] do
      if data >= exclusive_maximum do
        [error(path, "Value must be < #{exclusive_maximum}", data, schema) | errors]
      else
        errors
      end
    else
      errors
    end
  end

  defp valid_type?(type) do
    type in supported_types()
  end

  defp type_name(data) do
    cond do
      is_binary(data) -> "string"
      is_integer(data) -> "integer"
      is_float(data) -> "number"
      is_boolean(data) -> "boolean"
      is_list(data) -> "array"
      is_map(data) -> "object"
      is_nil(data) -> "null"
      true -> "unknown"
    end
  end

  defp error(path, message, value, schema) do
    %{
      path: path,
      message: message,
      value: value,
      schema: schema
    }
  end

  defp format_validation_errors(step_name, errors) do
    error_count = length(errors)

    header =
      "Schema validation failed for step '#{step_name}' (#{error_count} error#{if error_count == 1, do: "", else: "s"}):"

    formatted_errors =
      errors
      |> Enum.with_index(1)
      |> Enum.map(fn {error, index} ->
        path_display = if error.path == "", do: "(root)", else: error.path
        "  #{index}. #{path_display}: #{error.message}"
      end)
      |> Enum.join("\n")

    "#{header}\n#{formatted_errors}"
  end
end
