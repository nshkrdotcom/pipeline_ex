defmodule Pipeline.ResultManager do
  @moduledoc """
  Manages step results throughout pipeline execution.

  Provides structured storage, retrieval, and transformation of results
  between pipeline steps with support for serialization and validation.

  Features include:
  - JSON Schema validation for step outputs
  - Structured result storage and retrieval
  - Result transformation for prompt consumption
  - Serialization and persistence
  """

  alias Pipeline.Validation.SchemaValidator
  require Logger

  @type result :: map()
  @type result_key :: String.t()
  @type result_store :: map()
  @type schema :: map()

  defstruct results: %{}, metadata: %{}

  @doc """
  Create a new result manager.
  """
  @spec new() :: %__MODULE__{
          results: map(),
          metadata: %{
            created_at: DateTime.t(),
            last_updated: DateTime.t()
          }
        }
  def new do
    %__MODULE__{
      results: %{},
      metadata: %{
        created_at: DateTime.utc_now(),
        last_updated: DateTime.utc_now()
      }
    }
  end

  @doc """
  Store a result for a step.
  """
  @spec store_result(%__MODULE__{}, result_key, result) :: %__MODULE__{}
  def store_result(%__MODULE__{} = manager, step_name, result) do
    validated_result = validate_and_transform_result(result)

    %{
      manager
      | results: Map.put(manager.results, step_name, validated_result),
        metadata: Map.put(manager.metadata, :last_updated, DateTime.utc_now())
    }
  end

  @doc """
  Store a result for a step with optional schema validation.
  """
  @spec store_result_with_schema(%__MODULE__{}, result_key, result, schema | nil) ::
          {:ok, %__MODULE__{}} | {:error, String.t()}
  def store_result_with_schema(%__MODULE__{} = manager, step_name, result, schema \\ nil) do
    case validate_result_with_schema(step_name, result, schema) do
      {:ok, validated_result} ->
        new_manager = %{
          manager
          | results: Map.put(manager.results, step_name, validated_result),
            metadata: Map.put(manager.metadata, :last_updated, DateTime.utc_now())
        }

        {:ok, new_manager}

      {:error, error_message} ->
        {:error, error_message}
    end
  end

  @doc """
  Retrieve a result by step name.
  """
  @spec get_result(%__MODULE__{}, result_key) :: {:ok, result} | {:error, :not_found}
  def get_result(%__MODULE__{} = manager, step_name) do
    case Map.get(manager.results, step_name) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Get all results.
  """
  @spec get_all_results(%__MODULE__{}) :: result_store
  def get_all_results(%__MODULE__{} = manager) do
    manager.results
  end

  @doc """
  Check if a result exists for a step.
  """
  @spec has_result?(%__MODULE__{}, result_key) :: boolean()
  def has_result?(%__MODULE__{} = manager, step_name) do
    Map.has_key?(manager.results, step_name)
  end

  @doc """
  Extract a specific field from a step result.
  """
  @spec extract_field(%__MODULE__{}, result_key, String.t()) :: {:ok, any()} | {:error, atom()}
  def extract_field(%__MODULE__{} = manager, step_name, field_name) do
    case get_result(manager, step_name) do
      {:ok, result} ->
        case get_nested_field(result, field_name) do
          nil -> {:error, :field_not_found}
          value -> {:ok, value}
        end

      error ->
        error
    end
  end

  @doc """
  Transform results for consumption by next step.
  """
  @spec transform_for_prompt(%__MODULE__{}, result_key, keyword()) ::
          {:ok, String.t()} | {:error, atom()}
  def transform_for_prompt(%__MODULE__{} = manager, step_name, opts \\ []) do
    case get_result(manager, step_name) do
      {:ok, result} ->
        format = Keyword.get(opts, :format, :auto)
        field = Keyword.get(opts, :field, nil)

        content =
          if field do
            get_nested_field(result, field) || result
          else
            result
          end

        formatted = format_for_prompt(content, format)
        {:ok, formatted}

      error ->
        error
    end
  end

  @doc """
  Get summary statistics about stored results.
  """
  @spec get_summary(%__MODULE__{}) :: map()
  def get_summary(%__MODULE__{} = manager) do
    results = manager.results

    %{
      total_steps: map_size(results),
      successful_steps: count_successful_results(results),
      failed_steps: count_failed_results(results),
      total_cost: calculate_total_cost(results),
      steps: Map.keys(results),
      created_at: manager.metadata.created_at,
      last_updated: manager.metadata.last_updated
    }
  end

  @doc """
  Serialize results to JSON for storage.
  """
  @spec to_json(%__MODULE__{}) :: {:ok, String.t()} | {:error, Jason.EncodeError.t()}
  def to_json(%__MODULE__{} = manager) do
    data = %{
      results: manager.results,
      metadata: manager.metadata
    }

    Jason.encode(data, pretty: true)
  end

  @doc """
  Deserialize results from JSON.
  """
  @spec from_json(String.t()) :: {:ok, %__MODULE__{}} | {:error, Jason.DecodeError.t()}
  def from_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} ->
        # Restore atomized keys for results
        results = data["results"] || %{}

        restored_results =
          Map.new(results, fn {step_name, result} ->
            {step_name, atomize_keys(result)}
          end)

        manager = %__MODULE__{
          results: restored_results,
          metadata: data["metadata"] || %{}
        }

        {:ok, manager}

      error ->
        error
    end
  end

  @doc """
  Save results to file.
  """
  @spec save_to_file(%__MODULE__{}, String.t()) :: :ok | {:error, File.posix()}
  def save_to_file(%__MODULE__{} = manager, file_path) do
    case to_json(manager) do
      {:ok, json} ->
        File.mkdir_p!(Path.dirname(file_path))
        File.write(file_path, json)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Load results from file.
  """
  @spec load_from_file(String.t()) :: {:ok, %__MODULE__{}} | {:error, any()}
  def load_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} -> from_json(content)
      error -> error
    end
  end

  # Private helper functions

  defp validate_and_transform_result(result) do
    case result do
      %{success: success} when is_boolean(success) ->
        # Standard result format - keep as is
        result

      %{"success" => success} when is_boolean(success) ->
        # Convert string keys to atoms for consistency
        atomize_keys(result)

      result when is_map(result) ->
        # Ensure we have a success field
        Map.put_new(result, :success, true)

      result when is_binary(result) ->
        # Text result - wrap in standard format
        %{success: true, text: result, cost: 0.0}

      result ->
        # Unknown format - wrap safely
        %{success: true, data: result, cost: 0.0}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp get_nested_field(data, field_path) when is_map(data) do
    fields = String.split(field_path, ".")

    Enum.reduce(fields, data, fn field, acc ->
      case acc do
        %{} when is_map(acc) -> Map.get(acc, field) || Map.get(acc, String.to_atom(field))
        _ -> nil
      end
    end)
  end

  defp get_nested_field(_non_map, _field_path), do: nil

  defp format_for_prompt(content, format) do
    case format do
      :json -> format_as_json(content)
      :text -> format_as_text(content)
      :auto -> format_as_auto(content)
    end
  end

  defp format_as_json(content) do
    case Jason.encode(content, pretty: true) do
      {:ok, json} -> json
      {:error, _} -> inspect(content)
    end
  end

  defp format_as_text(content) do
    cond do
      is_binary(content) -> content
      is_map(content) -> extract_text_from_map(content)
      true -> inspect(content)
    end
  end

  defp extract_text_from_map(content) do
    content[:text] || content["text"] || content[:content] || content["content"] ||
      inspect(content)
  end

  defp format_as_auto(content) do
    cond do
      is_binary(content) -> content
      is_map(content) -> format_as_text(content)
      true -> inspect(content)
    end
  end

  defp count_successful_results(results) do
    Enum.count(results, fn {_name, result} ->
      case result do
        %{success: true} -> true
        %{"success" => true} -> true
        _ -> false
      end
    end)
  end

  defp count_failed_results(results) do
    Enum.count(results, fn {_name, result} ->
      case result do
        %{success: false} -> true
        %{"success" => false} -> true
        _ -> false
      end
    end)
  end

  defp calculate_total_cost(results) do
    Enum.reduce(results, 0.0, fn {_name, result}, acc ->
      cost =
        case result do
          %{cost: cost} when is_number(cost) -> cost
          %{"cost" => cost} when is_number(cost) -> cost
          _ -> 0.0
        end

      acc + cost
    end)
  end

  defp validate_result_with_schema(step_name, result, schema) do
    case schema do
      nil ->
        # No schema validation - use existing validation
        validated_result = validate_and_transform_result(result)
        {:ok, validated_result}

      schema when is_map(schema) ->
        # Extract the actual data from the result for validation
        data_to_validate = extract_validation_data(result)

        case SchemaValidator.validate_step_output(step_name, data_to_validate, schema) do
          {:ok, _validated_data} ->
            # If validation passes, apply standard transformation
            validated_result = validate_and_transform_result(result)
            {:ok, validated_result}

          {:error, error_message, _errors} ->
            {:error, error_message}
        end

      _ ->
        Logger.warning("Invalid schema format for step #{step_name}, skipping schema validation")
        validated_result = validate_and_transform_result(result)
        {:ok, validated_result}
    end
  end

  defp extract_validation_data(result) do
    data =
      case result do
        # For structured results, extract the main content for validation
        %{data: data} ->
          data

        %{"data" => data} ->
          data

        %{content: content} ->
          content

        %{"content" => content} ->
          content

        %{text: text} ->
          text

        %{"text" => text} ->
          text

        %{response: response} ->
          response

        %{"response" => response} ->
          response

        # For maps that look like they contain the actual data
        %{success: true} = result ->
          # Remove metadata fields and validate the rest
          filtered_result =
            result
            |> Map.drop([
              :success,
              "success",
              :cost,
              "cost",
              :duration,
              "duration",
              :timestamp,
              "timestamp"
            ])

          case map_size(filtered_result) do
            # If nothing left, validate the whole result
            0 -> result
            # Otherwise validate the filtered data
            _ -> filtered_result
          end

        # For any other format, validate as-is
        data ->
          data
      end

    # Convert atom keys to strings for JSON Schema validation
    stringify_keys(data)
  end

  defp stringify_keys(data) when is_map(data) do
    Map.new(data, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} -> {key, stringify_keys(value)}
    end)
  end

  defp stringify_keys(data) when is_list(data) do
    Enum.map(data, &stringify_keys/1)
  end

  defp stringify_keys(data), do: data
end
