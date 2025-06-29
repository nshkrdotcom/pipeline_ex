defmodule Pipeline.ResultManager do
  @moduledoc """
  Manages step results throughout pipeline execution.
  
  Provides structured storage, retrieval, and transformation of results
  between pipeline steps with support for serialization and validation.
  """

  @type result :: map()
  @type result_key :: String.t()
  @type result_store :: map()

  defstruct results: %{}, metadata: %{}

  @doc """
  Create a new result manager.
  """
  @spec new() :: %__MODULE__{}
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
    
    %{manager |
      results: Map.put(manager.results, step_name, validated_result),
      metadata: Map.put(manager.metadata, :last_updated, DateTime.utc_now())
    }
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
      error -> error
    end
  end

  @doc """
  Transform results for consumption by next step.
  """
  @spec transform_for_prompt(%__MODULE__{}, result_key, keyword()) :: {:ok, String.t()} | {:error, atom()}
  def transform_for_prompt(%__MODULE__{} = manager, step_name, opts \\ []) do
    case get_result(manager, step_name) do
      {:ok, result} ->
        format = Keyword.get(opts, :format, :auto)
        field = Keyword.get(opts, :field, nil)
        
        content = if field do
          get_nested_field(result, field) || result
        else
          result
        end
        
        formatted = format_for_prompt(content, format)
        {:ok, formatted}
        
      error -> error
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
        restored_results = Map.new(results, fn {step_name, result} ->
          {step_name, atomize_keys(result)}
        end)
        
        manager = %__MODULE__{
          results: restored_results,
          metadata: data["metadata"] || %{}
        }
        {:ok, manager}
      error -> error
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
      {:error, _} = error -> error
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

  defp get_nested_field(map, field_path) when is_map(map) do
    fields = String.split(field_path, ".")
    Enum.reduce(fields, map, fn field, acc ->
      case acc do
        %{} -> Map.get(acc, field) || Map.get(acc, String.to_atom(field))
        _ -> nil
      end
    end)
  end

  defp get_nested_field(_, _), do: nil

  defp format_for_prompt(content, format) do
    case format do
      :json ->
        case Jason.encode(content, pretty: true) do
          {:ok, json} -> json
          {:error, _} -> inspect(content)
        end
      
      :text ->
        cond do
          is_binary(content) -> content
          is_map(content) and Map.has_key?(content, :text) -> content.text
          is_map(content) and Map.has_key?(content, "text") -> content["text"]
          is_map(content) and Map.has_key?(content, :content) -> content.content
          is_map(content) and Map.has_key?(content, "content") -> content["content"]
          true -> inspect(content)
        end
      
      :auto ->
        cond do
          is_binary(content) -> content
          is_map(content) -> format_for_prompt(content, :text)
          true -> inspect(content)
        end
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
      cost = case result do
        %{cost: cost} when is_number(cost) -> cost
        %{"cost" => cost} when is_number(cost) -> cost
        _ -> 0.0
      end
      acc + cost
    end)
  end
end