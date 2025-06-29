defmodule Pipeline.Config do
  @moduledoc """
  Configuration management system for the pipeline.

  Handles loading and validation of workflow configurations,
  environment variables, and runtime settings.
  """

  @type config :: map()
  @type validation_result :: :ok | {:error, String.t()}

  @doc """
  Load and validate a workflow configuration from file.
  """
  @spec load_workflow(String.t()) :: {:ok, config} | {:error, String.t()}
  def load_workflow(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case YamlElixir.read_from_string(content) do
          {:ok, config} ->
            case validate_workflow(config) do
              :ok -> {:ok, config}
              {:error, reason} -> {:error, "Invalid workflow: #{reason}"}
            end

          {:error, reason} ->
            {:error, "Failed to parse YAML: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Get application configuration with environment variable overrides.
  """
  @spec get_app_config() :: config
  def get_app_config do
    base_config = %{
      workspace_dir: System.get_env("PIPELINE_WORKSPACE_DIR") || "./workspace",
      output_dir: System.get_env("PIPELINE_OUTPUT_DIR") || "./outputs",
      checkpoint_dir: System.get_env("PIPELINE_CHECKPOINT_DIR") || "./checkpoints",
      log_level: String.to_atom(System.get_env("PIPELINE_LOG_LEVEL") || "info"),
      test_mode: System.get_env("TEST_MODE") || "live",
      debug_enabled: System.get_env("PIPELINE_DEBUG") == "true"
    }

    # Merge with application environment
    app_env = Application.get_all_env(:pipeline)
    Map.merge(base_config, Map.new(app_env))
  end

  @doc """
  Get provider configuration for external services.
  """
  @spec get_provider_config(atom()) :: config
  def get_provider_config(:claude) do
    %{
      base_url: System.get_env("CLAUDE_BASE_URL"),
      api_key: System.get_env("CLAUDE_API_KEY"),
      model: System.get_env("CLAUDE_MODEL") || "claude-3-sonnet-20240229",
      timeout: String.to_integer(System.get_env("CLAUDE_TIMEOUT") || "30000")
    }
  end

  def get_provider_config(:gemini) do
    %{
      api_key: System.get_env("GEMINI_API_KEY"),
      model: System.get_env("GEMINI_MODEL") || "gemini-2.5-flash-lite-preview-06-17",
      base_url: System.get_env("GEMINI_BASE_URL"),
      timeout: String.to_integer(System.get_env("GEMINI_TIMEOUT") || "30000")
    }
  end

  def get_provider_config(provider) do
    raise ArgumentError, "Unknown provider: #{provider}"
  end

  @doc """
  Validate a workflow configuration.
  """
  @spec validate_workflow(config) :: validation_result
  def validate_workflow(config) do
    with :ok <- validate_required_fields(config),
         :ok <- validate_steps(config),
         :ok <- validate_step_dependencies(config) do
      :ok
    end
  end

  # Private validation functions

  defp validate_required_fields(config) do
    workflow = config["workflow"]

    cond do
      is_nil(workflow) ->
        {:error, "Missing 'workflow' section"}

      is_nil(workflow["name"]) ->
        {:error, "Missing workflow name"}

      is_nil(workflow["steps"]) or not is_list(workflow["steps"]) ->
        {:error, "Missing or invalid 'steps' section"}

      Enum.empty?(workflow["steps"]) ->
        {:error, "Workflow must have at least one step"}

      true ->
        :ok
    end
  end

  defp validate_steps(config) do
    steps = config["workflow"]["steps"]

    # Check each step
    Enum.reduce_while(steps, :ok, fn step, _acc ->
      case validate_step(step) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_step(step) do
    cond do
      is_nil(step["name"]) ->
        {:error, "Step missing 'name' field"}

      is_nil(step["type"]) ->
        {:error, "Step '#{step["name"]}' missing 'type' field"}

      step["type"] not in ["claude", "gemini"] ->
        {:error, "Step '#{step["name"]}' has invalid type: #{step["type"]}"}

      is_nil(step["prompt"]) ->
        {:error, "Step '#{step["name"]}' missing 'prompt' field"}

      not is_list(step["prompt"]) ->
        {:error, "Step '#{step["name"]}' prompt must be a list"}

      true ->
        validate_prompt_parts(step["prompt"], step["name"])
    end
  end

  defp validate_prompt_parts(prompt_parts, step_name) do
    Enum.reduce_while(prompt_parts, :ok, fn part, _acc ->
      case validate_prompt_part(part, step_name) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_prompt_part(part, step_name) do
    type = part["type"]

    case type do
      "static" ->
        if is_nil(part["content"]) do
          {:error, "Step '#{step_name}' has static prompt part without content"}
        else
          :ok
        end

      "file" ->
        if is_nil(part["path"]) do
          {:error, "Step '#{step_name}' has file prompt part without path"}
        else
          :ok
        end

      "previous_response" ->
        if is_nil(part["step"]) do
          {:error, "Step '#{step_name}' has previous_response prompt part without step reference"}
        else
          :ok
        end

      nil ->
        {:error, "Step '#{step_name}' has prompt part without type"}

      _ ->
        {:error, "Step '#{step_name}' has prompt part with invalid type: #{type}"}
    end
  end

  defp validate_step_dependencies(config) do
    steps = config["workflow"]["steps"]
    step_names = MapSet.new(steps, & &1["name"])

    # Check that all previous_response references point to valid steps
    Enum.reduce_while(steps, :ok, fn step, _acc ->
      case find_invalid_references(step, step_names) do
        [] ->
          {:cont, :ok}

        invalid_refs ->
          {:halt,
           {:error,
            "Step '#{step["name"]}' references non-existent steps: #{Enum.join(invalid_refs, ", ")}"}}
      end
    end)
  end

  defp find_invalid_references(step, valid_step_names) do
    prompt_parts = step["prompt"] || []

    prompt_parts
    |> Enum.filter(&(&1["type"] == "previous_response"))
    |> Enum.map(& &1["step"])
    |> Enum.filter(&(not MapSet.member?(valid_step_names, &1)))
  end

  @doc """
  Merge default values into workflow configuration.
  """
  @spec apply_defaults(config) :: config
  def apply_defaults(config) do
    workflow = config["workflow"]
    defaults = workflow["defaults"] || %{}

    updated_steps =
      Enum.map(workflow["steps"], fn step ->
        apply_step_defaults(step, defaults)
      end)

    put_in(config, ["workflow", "steps"], updated_steps)
  end

  defp apply_step_defaults(step, defaults) do
    # Apply defaults for common fields
    step
    |> Map.put_new("output_to_file", nil)
    |> apply_type_specific_defaults(defaults)
  end

  defp apply_type_specific_defaults(step, defaults) do
    case step["type"] do
      "claude" ->
        claude_defaults = defaults["claude_options"] || %{}
        current_options = step["claude_options"] || %{}
        merged_options = Map.merge(claude_defaults, current_options)
        Map.put(step, "claude_options", merged_options)

      "gemini" ->
        # Apply Gemini-specific defaults
        step
        |> Map.put_new("model", defaults["gemini_model"])
        |> Map.put_new("token_budget", defaults["gemini_token_budget"])

      _ ->
        step
    end
  end
end
