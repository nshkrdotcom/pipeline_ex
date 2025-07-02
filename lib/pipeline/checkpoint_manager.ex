defmodule Pipeline.CheckpointManager do
  @moduledoc """
  Manages checkpoint creation and restoration for pipeline execution.

  Provides state persistence to allow pipeline resumption after failures
  or interruptions.
  """

  @type checkpoint_data :: %{
          workflow_name: String.t(),
          step_index: non_neg_integer(),
          results: map(),
          execution_log: list(),
          timestamp: DateTime.t(),
          variable_state: map()
        }

  @doc """
  Save a checkpoint for the current pipeline state.
  """
  @spec save(String.t(), String.t(), map()) :: :ok | {:error, any()}
  def save(checkpoint_dir, workflow_name, context) do
    timestamp = DateTime.utc_now()
    filename = generate_checkpoint_filename(workflow_name, timestamp)
    filepath = Path.join(checkpoint_dir, filename)

    # Serialize variable state if present
    variable_state = 
      case Map.get(context, :variable_state) do
        nil -> %{}
        state -> Pipeline.State.VariableEngine.serialize_state(state)
      end

    checkpoint_data = %{
      workflow_name: workflow_name,
      step_index: context.step_index,
      results: context.results,
      execution_log: context.execution_log,
      timestamp: timestamp,
      variable_state: variable_state,
      version: "1.1"
    }

    case Jason.encode(checkpoint_data, pretty: true) do
      {:ok, json} ->
        File.mkdir_p!(checkpoint_dir)

        case File.write(filepath, json) do
          :ok ->
            # Also create a "latest" symlink for easy access
            latest_path = Path.join(checkpoint_dir, "#{workflow_name}_latest.json")
            # Remove existing symlink if it exists
            _ = File.rm(latest_path)
            File.write!(latest_path, json)
            :ok

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Load the latest checkpoint for a workflow.
  """
  @spec load_latest(String.t(), String.t()) :: {:ok, checkpoint_data} | {:error, any()}
  def load_latest(checkpoint_dir, workflow_name) do
    latest_path = Path.join(checkpoint_dir, "#{workflow_name}_latest.json")

    case File.read(latest_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            # Deserialize variable state
            variable_state = Pipeline.State.VariableEngine.deserialize_state(data["variable_state"])

            checkpoint = %{
              workflow_name: data["workflow_name"],
              step_index: data["step_index"] || 0,
              results: data["results"] || %{},
              execution_log: data["execution_log"] || [],
              timestamp: parse_timestamp(data["timestamp"]),
              variable_state: variable_state
            }

            {:ok, checkpoint}

          error ->
            error
        end

      {:error, :enoent} ->
        {:error, :no_checkpoint}

      error ->
        error
    end
  end

  @doc """
  Load a specific checkpoint by filename.
  """
  @spec load_checkpoint(String.t(), String.t()) :: {:ok, checkpoint_data} | {:error, any()}
  def load_checkpoint(checkpoint_dir, filename) do
    filepath = Path.join(checkpoint_dir, filename)

    case File.read(filepath) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            # Deserialize variable state
            variable_state = Pipeline.State.VariableEngine.deserialize_state(data["variable_state"])

            checkpoint = %{
              workflow_name: data["workflow_name"],
              step_index: data["step_index"] || 0,
              results: data["results"] || %{},
              execution_log: data["execution_log"] || [],
              timestamp: parse_timestamp(data["timestamp"]),
              variable_state: variable_state
            }

            {:ok, checkpoint}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  List all checkpoints for a workflow.
  """
  @spec list_checkpoints(String.t(), String.t()) :: {:ok, list(String.t())} | {:error, any()}
  def list_checkpoints(checkpoint_dir, workflow_name) do
    case File.ls(checkpoint_dir) do
      {:ok, files} ->
        checkpoint_files =
          files
          |> Enum.filter(&String.starts_with?(&1, "#{workflow_name}_"))
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.reject(&String.ends_with?(&1, "_latest.json"))
          # Most recent first
          |> Enum.sort(:desc)

        {:ok, checkpoint_files}

      error ->
        error
    end
  end

  @doc """
  Delete old checkpoints, keeping only the most recent N.
  """
  @spec cleanup_old_checkpoints(String.t(), String.t(), pos_integer()) :: :ok | {:error, any()}
  def cleanup_old_checkpoints(checkpoint_dir, workflow_name, keep_count \\ 5) do
    case list_checkpoints(checkpoint_dir, workflow_name) do
      {:ok, checkpoints} ->
        checkpoints_to_delete = Enum.drop(checkpoints, keep_count)

        Enum.each(checkpoints_to_delete, fn filename ->
          filepath = Path.join(checkpoint_dir, filename)
          File.rm(filepath)
        end)

        :ok

      error ->
        error
    end
  end

  @doc """
  Get checkpoint metadata without loading the full data.
  """
  @spec get_checkpoint_info(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_checkpoint_info(checkpoint_dir, filename) do
    filepath = Path.join(checkpoint_dir, filename)

    case File.read(filepath) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            info = %{
              filename: filename,
              workflow_name: data["workflow_name"],
              step_index: data["step_index"] || 0,
              timestamp: parse_timestamp(data["timestamp"]),
              version: data["version"] || "unknown",
              file_size: byte_size(content),
              step_count: length(data["execution_log"] || [])
            }

            {:ok, info}

          error ->
            error
        end

      error ->
        error
    end
  end

  # Private helper functions

  defp generate_checkpoint_filename(workflow_name, timestamp) do
    formatted_time =
      timestamp
      |> DateTime.to_iso8601()
      |> String.replace(~r/[:\-T]/, "")
      |> String.replace("Z", "")
      # YYYYMMDDHHMMSS
      |> String.slice(0, 14)

    "#{workflow_name}_#{formatted_time}.json"
  end

  defp parse_timestamp(timestamp_string) when is_binary(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(_), do: DateTime.utc_now()
end
