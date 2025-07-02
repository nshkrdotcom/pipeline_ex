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
    with {:ok, content} <- File.read(file_path),
         {:ok, config} <- YamlElixir.read_from_string(content),
         :ok <- validate_workflow(config) do
      {:ok, config}
    else
      {:error, :enoent} -> {:error, "Failed to read file: #{file_path}"}
      {:error, %YamlElixir.FileNotFoundError{}} -> {:error, "Failed to read file: #{file_path}"}
      {:error, %YamlElixir.ParsingError{}} -> {:error, "Failed to parse YAML: #{file_path}"}
      {:error, reason} when is_binary(reason) -> {:error, "Invalid workflow: #{reason}"}
      {:error, reason} -> {:error, "Failed to parse YAML: #{inspect(reason)}"}
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
      model: System.get_env("CLAUDE_MODEL") || "claude-4-sonnet",
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
    case get_gemini_functions(config) do
      nil -> :ok
      functions when is_map(functions) -> validate_all_function_definitions(functions)
      _ -> {:error, "gemini_functions must be a map of function definitions"}
    end
  end

  defp get_gemini_functions(config), do: config["workflow"]["gemini_functions"]

  defp validate_all_function_definitions(functions) do
    Enum.reduce_while(functions, :ok, fn {function_name, function_def}, _acc ->
      case validate_function_definition(function_name, function_def) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
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
    with :ok <- validate_step_required_fields(step),
         :ok <- validate_step_type(step),
         :ok <- validate_step_type_specific(step),
         :ok <- validate_step_prompt(step),
         :ok <- validate_step_function_references(step, config) do
      :ok
    end
  end

  defp validate_step_required_fields(step) do
    cond do
      is_nil(step["name"]) ->
        {:error, "Step missing required 'name' field. Add: name: \"step_name\""}

      is_nil(step["type"]) ->
        {:error,
         "Step '#{step["name"]}' missing required 'type' field. Supported types: set_variable, claude, gemini, parallel_claude, gemini_instructor, claude_smart, claude_session, claude_extract, claude_batch, claude_robust"}

      true ->
        :ok
    end
  end

  defp validate_step_type(step) do
    supported_types = [
      "set_variable",
      "claude",
      "gemini",
      "parallel_claude",
      "gemini_instructor",
      "claude_smart",
      "claude_session",
      "claude_extract",
      "claude_batch",
      "claude_robust"
    ]

    if step["type"] in supported_types do
      :ok
    else
      {:error,
       "Step '#{step["name"]}' has invalid type '#{step["type"]}'. Supported types: #{Enum.join(supported_types, ", ")}"}
    end
  end

  defp validate_step_type_specific(step) do
    if step["type"] == "parallel_claude" and is_nil(step["parallel_tasks"]) do
      {:error,
       "Step '#{step["name"]}' of type 'parallel_claude' missing required 'parallel_tasks' field"}
    else
      :ok
    end
  end

  defp validate_step_prompt(step) do
    cond do
      step["type"] == "parallel_claude" ->
        :ok

      # claude_batch can use either prompt or tasks
      step["type"] == "claude_batch" ->
        if is_nil(step["prompt"]) and is_nil(step["tasks"]) do
          {:error,
           "Step '#{step["name"]}' of type 'claude_batch' must have either 'prompt' or 'tasks' field"}
        else
          :ok
        end

      # set_variable doesn't require a prompt
      step["type"] == "set_variable" ->
        :ok

      is_nil(step["prompt"]) ->
        {:error,
         "Step '#{step["name"]}' missing required 'prompt' field. Add: prompt: [{\"type\": \"static\", \"content\": \"...\"}]"}

      not is_list(step["prompt"]) ->
        {:error,
         "Step '#{step["name"]}' prompt must be an array of prompt parts. Format: [{\"type\": \"static\", \"content\": \"...\"}]"}

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

        Enum.reduce_while(
          functions,
          :ok,
          &validate_function_reference(step, available_functions, &1, &2)
        )

      _ ->
        {:error, "Step '#{step["name"]}' functions must be a list"}
    end
  end

  defp validate_function_reference(step, available_functions, function_name, _acc) do
    if function_name in available_functions do
      {:cont, :ok}
    else
      {:halt, {:error, "Step '#{step["name"]}' references undefined function: #{function_name}"}}
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
        apply_claude_defaults(step, defaults)

      "gemini" ->
        apply_gemini_defaults(step, defaults)

      "parallel_claude" ->
        apply_parallel_claude_defaults(step, defaults)

      "gemini_instructor" ->
        apply_gemini_defaults(step, defaults)

      # Enhanced step types use claude defaults as base
      type
      when type in [
             "claude_smart",
             "claude_session",
             "claude_extract",
             "claude_batch",
             "claude_robust"
           ] ->
        apply_claude_defaults(step, defaults)

      _ ->
        step
    end
  end

  defp apply_claude_defaults(step, defaults) do
    merged_options = merge_claude_options(step["claude_options"], defaults)
    Map.put(step, "claude_options", merged_options)
  end

  defp apply_gemini_defaults(step, defaults) do
    step
    |> Map.put_new("model", defaults["gemini_model"])
    |> Map.put_new("token_budget", defaults["gemini_token_budget"])
  end

  defp apply_parallel_claude_defaults(step, defaults) do
    tasks = step["parallel_tasks"] || []
    updated_tasks = Enum.map(tasks, &apply_claude_task_defaults(&1, defaults))
    Map.put(step, "parallel_tasks", updated_tasks)
  end

  defp apply_claude_task_defaults(task, defaults) do
    merged_options = merge_claude_options(task["claude_options"], defaults)
    Map.put(task, "claude_options", merged_options)
  end

  defp merge_claude_options(current_options, defaults) do
    claude_defaults = defaults["claude_options"] || %{}
    current_options = current_options || %{}
    output_format = defaults["claude_output_format"] || "json"

    claude_defaults
    |> Map.merge(current_options)
    |> Map.put_new("output_format", output_format)
  end
end
