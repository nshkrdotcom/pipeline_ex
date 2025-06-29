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
  @spec get_app_config() :: %{
          optional(atom()) => any(),
          workspace_dir: String.t(),
          output_dir: String.t(),
          checkpoint_dir: String.t(),
          log_level: atom(),
          test_mode: String.t(),
          debug_enabled: boolean()
        }
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
  @spec get_provider_config(:claude | :gemini) :: %{
          api_key: String.t() | nil,
          base_url: String.t() | nil,
          model: String.t(),
          timeout: integer()
        }
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
         :ok <- validate_functions(config),
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
        {:error,
         "Configuration missing required 'workflow' section. Expected format: {\"workflow\": {...}}"}

      is_nil(workflow["name"]) ->
        {:error, "Workflow missing required 'name' field. Add: name: \"your_workflow_name\""}

      is_nil(workflow["steps"]) or not is_list(workflow["steps"]) ->
        {:error,
         "Workflow missing required 'steps' array. Expected format: steps: [{\"name\": \"step1\", \"type\": \"claude\", ...}]"}

      Enum.empty?(workflow["steps"]) ->
        {:error,
         "Workflow must contain at least one step. Add at least one step to the 'steps' array"}

      true ->
        :ok
    end
  end

  defp validate_functions(config) do
    workflow = config["workflow"]

    case workflow["gemini_functions"] do
      nil ->
        :ok

      functions when is_map(functions) ->
        Enum.reduce_while(functions, :ok, fn {function_name, function_def}, _acc ->
          case validate_function_definition(function_name, function_def) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)

      _ ->
        {:error, "gemini_functions must be a map of function definitions"}
    end
  end

  defp validate_function_definition(function_name, function_def) do
    cond do
      not is_map(function_def) ->
        {:error, "Function '#{function_name}' definition must be a map"}

      is_nil(function_def["description"]) ->
        {:error, "Function '#{function_name}' missing 'description' field"}

      is_nil(function_def["parameters"]) ->
        {:error, "Function '#{function_name}' missing 'parameters' field"}

      not is_map(function_def["parameters"]) ->
        {:error, "Function '#{function_name}' parameters must be a map"}

      true ->
        :ok
    end
  end

  defp validate_steps(config) do
    steps = config["workflow"]["steps"]

    # Check each step
    Enum.reduce_while(steps, :ok, fn step, _acc ->
      case validate_step(step, config) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_step(step, config) do
    cond do
      is_nil(step["name"]) ->
        {:error, "Step missing required 'name' field. Add: name: \"step_name\""}

      is_nil(step["type"]) ->
        {:error,
         "Step '#{step["name"]}' missing required 'type' field. Supported types: claude, gemini, parallel_claude, gemini_instructor"}

      step["type"] not in ["claude", "gemini", "parallel_claude", "gemini_instructor"] ->
        {:error,
         "Step '#{step["name"]}' has invalid type '#{step["type"]}'. Supported types: claude, gemini, parallel_claude, gemini_instructor"}

      is_nil(step["prompt"]) ->
        {:error,
         "Step '#{step["name"]}' missing required 'prompt' field. Add: prompt: [{\"type\": \"static\", \"content\": \"...\"}]"}

      not is_list(step["prompt"]) ->
        {:error,
         "Step '#{step["name"]}' prompt must be an array of prompt parts. Format: [{\"type\": \"static\", \"content\": \"...\"}]"}

      step["type"] == "parallel_claude" and is_nil(step["parallel_tasks"]) ->
        {:error,
         "Step '#{step["name"]}' of type 'parallel_claude' missing required 'parallel_tasks' field"}

      true ->
        with :ok <- validate_prompt_parts(step["prompt"], step["name"]),
             :ok <- validate_step_function_references(step, config) do
          :ok
        end
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
          {:error, "Step '#{step_name}' has previous_response prompt part missing 'step' field"}
        else
          :ok
        end

      nil ->
        {:error, "Step '#{step_name}' has prompt part without type"}

      _ ->
        {:error, "Step '#{step_name}' has prompt part with invalid type: #{type}"}
    end
  end

  defp validate_step_function_references(step, config) do
    case step["functions"] do
      nil ->
        :ok

      functions when is_list(functions) ->
        available_functions = get_available_functions(config)

        Enum.reduce_while(functions, :ok, fn function_name, _acc ->
          if function_name in available_functions do
            {:cont, :ok}
          else
            {:halt,
             {:error, "Step '#{step["name"]}' references undefined function: #{function_name}"}}
          end
        end)

      _ ->
        {:error, "Step '#{step["name"]}' functions must be a list"}
    end
  end

  defp get_available_functions(config) do
    case get_in(config, ["workflow", "gemini_functions"]) do
      nil -> []
      functions when is_map(functions) -> Map.keys(functions)
      _ -> []
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

        # Apply claude_output_format default if not specified
        output_format = defaults["claude_output_format"] || "json"
        merged_options = Map.merge(claude_defaults, current_options)
        merged_options = Map.put_new(merged_options, "output_format", output_format)

        Map.put(step, "claude_options", merged_options)

      "gemini" ->
        # Apply Gemini-specific defaults
        step
        |> Map.put_new("model", defaults["gemini_model"])
        |> Map.put_new("token_budget", defaults["gemini_token_budget"])

      "parallel_claude" ->
        # Apply defaults to parallel tasks
        tasks = step["parallel_tasks"] || []

        updated_tasks =
          Enum.map(tasks, fn task ->
            claude_defaults = defaults["claude_options"] || %{}
            current_options = task["claude_options"] || %{}
            output_format = defaults["claude_output_format"] || "json"
            merged_options = Map.merge(claude_defaults, current_options)
            merged_options = Map.put_new(merged_options, "output_format", output_format)
            Map.put(task, "claude_options", merged_options)
          end)

        Map.put(step, "parallel_tasks", updated_tasks)

      "gemini_instructor" ->
        # Apply Gemini-specific defaults with instructor settings
        step
        |> Map.put_new("model", defaults["gemini_model"])
        |> Map.put_new("token_budget", defaults["gemini_token_budget"])

      _ ->
        step
    end
  end
end
