defmodule Pipeline.EnhancedConfig do
  @moduledoc """
  Enhanced configuration management for Claude Code SDK integration.

  Extends the base Pipeline.Config with support for:
  - Enhanced Claude options schema
  - New step types (claude_smart, claude_session, etc.)
  - Workflow-level authentication and environment configuration
  - Advanced prompt template types
  """

  alias Pipeline.Config

  @enhanced_step_types [
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

  @valid_output_formats ["text", "json", "stream_json"]
  @valid_backoff_strategies ["linear", "exponential"]
  @valid_permission_modes ["default", "accept_edits", "bypass_permissions", "plan"]
  @valid_providers ["anthropic", "aws_bedrock", "google_vertex"]
  @valid_environment_modes ["development", "production", "test"]
  @valid_debug_levels ["basic", "detailed", "performance"]
  @valid_presets ["development", "production", "analysis", "chat"]
  @valid_extraction_formats ["text", "json", "structured", "summary", "markdown"]
  @valid_prompt_types [
    "static",
    "file",
    "previous_response",
    "session_context",
    "claude_continue"
  ]

  @doc """
  Load and validate an enhanced workflow configuration from map.
  This function replaces the base Config.load_workflow for enhanced features.
  """
  @spec load_from_map(map()) :: {:ok, map()} | {:error, String.t()}
  def load_from_map(config) do
    with :ok <- validate_enhanced_workflow(config),
         enhanced_config <- apply_enhanced_defaults(config) do
      {:ok, enhanced_config}
    end
  end

  @doc """
  Load and validate an enhanced workflow configuration from file.
  """
  @spec load_workflow(String.t()) :: {:ok, map()} | {:error, String.t()}
  def load_workflow(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, config} <- YamlElixir.read_from_string(content),
         {:ok, enhanced_config} <- load_from_map(config) do
      {:ok, enhanced_config}
    else
      {:error, :enoent} -> {:error, "Failed to read file: #{file_path}"}
      {:error, %YamlElixir.FileNotFoundError{}} -> {:error, "Failed to read file: #{file_path}"}
      {:error, %YamlElixir.ParsingError{}} -> {:error, "Failed to parse YAML: #{file_path}"}
      {:error, reason} when is_binary(reason) -> {:error, "Invalid workflow: #{reason}"}
      {:error, reason} -> {:error, "Failed to parse YAML: #{inspect(reason)}"}
    end
  end

  # Enhanced validation functions

  defp validate_enhanced_workflow(config) do
    with :ok <- validate_base_required_fields(config),
         :ok <- validate_base_functions(config),
         :ok <- validate_enhanced_workflow_config(config),
         :ok <- validate_enhanced_steps(config),
         :ok <- validate_base_step_dependencies(config) do
      :ok
    end
  end

  # Base validation functions - reimplemented to support enhanced step types

  defp validate_base_required_fields(config) do
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

  defp validate_base_functions(config) do
    case get_in(config, ["workflow", "gemini_functions"]) do
      nil -> :ok
      functions when is_map(functions) -> validate_all_function_definitions(functions)
      _ -> {:error, "gemini_functions must be a map of function definitions"}
    end
  end

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

  defp validate_base_step_dependencies(config) do
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

  defp validate_enhanced_workflow_config(config) do
    workflow = config["workflow"]

    with :ok <- validate_claude_auth_config(workflow),
         :ok <- validate_environment_config(workflow),
         :ok <- validate_enhanced_defaults(workflow) do
      :ok
    end
  end

  defp validate_claude_auth_config(workflow) do
    case workflow["claude_auth"] do
      nil ->
        :ok

      auth_config when is_map(auth_config) ->
        validate_claude_auth_fields(auth_config)

      _ ->
        {:error, "claude_auth must be a map"}
    end
  end

  defp validate_claude_auth_fields(auth_config) do
    with :ok <- validate_optional_boolean(auth_config, "auto_check", "claude_auth.auto_check"),
         :ok <-
           validate_optional_enum(
             auth_config,
             "provider",
             @valid_providers,
             "claude_auth.provider"
           ),
         :ok <-
           validate_optional_boolean(auth_config, "fallback_mock", "claude_auth.fallback_mock"),
         :ok <- validate_optional_boolean(auth_config, "diagnostics", "claude_auth.diagnostics") do
      :ok
    end
  end

  defp validate_environment_config(workflow) do
    case workflow["environment"] do
      nil ->
        :ok

      env_config when is_map(env_config) ->
        validate_environment_fields(env_config)

      _ ->
        {:error, "environment must be a map"}
    end
  end

  defp validate_environment_fields(env_config) do
    with :ok <-
           validate_optional_enum(
             env_config,
             "mode",
             @valid_environment_modes,
             "environment.mode"
           ),
         :ok <-
           validate_optional_enum(
             env_config,
             "debug_level",
             @valid_debug_levels,
             "environment.debug_level"
           ),
         :ok <- validate_cost_alerts_config(env_config) do
      :ok
    end
  end

  defp validate_cost_alerts_config(env_config) do
    case env_config["cost_alerts"] do
      nil ->
        :ok

      cost_alerts when is_map(cost_alerts) ->
        with :ok <-
               validate_optional_boolean(
                 cost_alerts,
                 "enabled",
                 "environment.cost_alerts.enabled"
               ),
             :ok <-
               validate_optional_number(
                 cost_alerts,
                 "threshold_usd",
                 "environment.cost_alerts.threshold_usd"
               ),
             :ok <-
               validate_optional_boolean(
                 cost_alerts,
                 "notify_on_exceed",
                 "environment.cost_alerts.notify_on_exceed"
               ) do
          :ok
        end

      _ ->
        {:error, "environment.cost_alerts must be a map"}
    end
  end

  defp validate_enhanced_defaults(workflow) do
    case workflow["defaults"] do
      nil ->
        :ok

      defaults when is_map(defaults) ->
        validate_enhanced_default_fields(defaults)

      _ ->
        {:error, "defaults must be a map"}
    end
  end

  defp validate_enhanced_default_fields(defaults) do
    with :ok <-
           validate_optional_enum(
             defaults,
             "claude_preset",
             @valid_presets,
             "defaults.claude_preset"
           ) do
      :ok
    end
  end

  defp validate_enhanced_steps(config) do
    steps = config["workflow"]["steps"]

    Enum.reduce_while(steps, :ok, fn step, _acc ->
      case validate_enhanced_step(step) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_enhanced_step(step) do
    with :ok <- validate_enhanced_step_type(step),
         :ok <- validate_enhanced_step_specific(step),
         :ok <- validate_enhanced_claude_options(step),
         :ok <- validate_enhanced_prompt(step) do
      :ok
    end
  end

  defp validate_enhanced_step_type(step) do
    if step["type"] in @enhanced_step_types do
      :ok
    else
      {:error,
       "Step '#{step["name"]}' has invalid type '#{step["type"]}'. Supported types: #{Enum.join(@enhanced_step_types, ", ")}"}
    end
  end

  defp validate_enhanced_step_specific(step) do
    case step["type"] do
      "claude_smart" -> validate_claude_smart_step(step)
      "claude_session" -> validate_claude_session_step(step)
      "claude_extract" -> validate_claude_extract_step(step)
      "claude_batch" -> validate_claude_batch_step(step)
      "claude_robust" -> validate_claude_robust_step(step)
      # Use base validation for existing types
      _ -> :ok
    end
  end

  defp validate_claude_smart_step(step) do
    with :ok <-
           validate_optional_enum(step, "preset", @valid_presets, "step '#{step["name"]}' preset"),
         :ok <-
           validate_optional_boolean(
             step,
             "environment_aware",
             "step '#{step["name"]}' environment_aware"
           ) do
      :ok
    end
  end

  defp validate_claude_session_step(step) do
    case step["session_config"] do
      nil ->
        {:error, "Step '#{step["name"]}' of type 'claude_session' requires session_config"}

      session_config when is_map(session_config) ->
        validate_session_config(session_config, step["name"])

      _ ->
        {:error, "Step '#{step["name"]}' session_config must be a map"}
    end
  end

  defp validate_session_config(session_config, step_name) do
    with :ok <-
           validate_optional_boolean(
             session_config,
             "persist",
             "step '#{step_name}' session_config.persist"
           ),
         :ok <-
           validate_optional_string(
             session_config,
             "session_name",
             "step '#{step_name}' session_config.session_name"
           ),
         :ok <-
           validate_optional_boolean(
             session_config,
             "continue_on_restart",
             "step '#{step_name}' session_config.continue_on_restart"
           ),
         :ok <-
           validate_optional_positive_integer(
             session_config,
             "checkpoint_frequency",
             "step '#{step_name}' session_config.checkpoint_frequency"
           ),
         :ok <-
           validate_optional_string(
             session_config,
             "description",
             "step '#{step_name}' session_config.description"
           ) do
      :ok
    end
  end

  defp validate_claude_extract_step(step) do
    case step["extraction_config"] do
      # extraction_config is optional
      nil ->
        :ok

      extraction_config when is_map(extraction_config) ->
        validate_extraction_config(extraction_config, step["name"])

      _ ->
        {:error, "Step '#{step["name"]}' extraction_config must be a map"}
    end
  end

  defp validate_extraction_config(extraction_config, step_name) do
    with :ok <-
           validate_optional_boolean(
             extraction_config,
             "use_content_extractor",
             "step '#{step_name}' extraction_config.use_content_extractor"
           ),
         :ok <-
           validate_optional_enum(
             extraction_config,
             "format",
             @valid_extraction_formats,
             "step '#{step_name}' extraction_config.format"
           ),
         :ok <-
           validate_optional_list(
             extraction_config,
             "post_processing",
             "step '#{step_name}' extraction_config.post_processing"
           ),
         :ok <-
           validate_optional_positive_integer(
             extraction_config,
             "max_summary_length",
             "step '#{step_name}' extraction_config.max_summary_length"
           ),
         :ok <-
           validate_optional_boolean(
             extraction_config,
             "include_metadata",
             "step '#{step_name}' extraction_config.include_metadata"
           ) do
      :ok
    end
  end

  defp validate_claude_batch_step(step) do
    with :ok <- validate_batch_config(step),
         :ok <- validate_batch_tasks(step) do
      :ok
    end
  end

  defp validate_batch_config(step) do
    case step["batch_config"] do
      # batch_config is optional
      nil ->
        :ok

      batch_config when is_map(batch_config) ->
        validate_batch_config_fields(batch_config, step["name"])

      _ ->
        {:error, "Step '#{step["name"]}' batch_config must be a map"}
    end
  end

  defp validate_batch_config_fields(batch_config, step_name) do
    with :ok <-
           validate_optional_positive_integer(
             batch_config,
             "max_parallel",
             "step '#{step_name}' batch_config.max_parallel"
           ),
         :ok <-
           validate_optional_positive_integer(
             batch_config,
             "timeout_per_task",
             "step '#{step_name}' batch_config.timeout_per_task"
           ),
         :ok <-
           validate_optional_boolean(
             batch_config,
             "consolidate_results",
             "step '#{step_name}' batch_config.consolidate_results"
           ) do
      :ok
    end
  end

  defp validate_batch_tasks(step) do
    case step["tasks"] do
      # tasks is optional
      nil ->
        :ok

      tasks when is_list(tasks) ->
        validate_batch_task_list(tasks, step["name"])

      _ ->
        {:error, "Step '#{step["name"]}' tasks must be a list"}
    end
  end

  defp validate_batch_task_list(tasks, step_name) do
    Enum.reduce_while(tasks, :ok, fn task, _acc ->
      case validate_batch_task(task, step_name) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_batch_task(task, step_name) do
    cond do
      not is_map(task) ->
        {:error, "Step '#{step_name}' batch task must be a map"}

      not Map.has_key?(task, "file") and not Map.has_key?(task, "prompt") ->
        {:error, "Step '#{step_name}' batch task must have either 'file' or 'prompt' field"}

      true ->
        :ok
    end
  end

  defp validate_claude_robust_step(step) do
    case step["retry_config"] do
      # retry_config is optional
      nil ->
        :ok

      retry_config when is_map(retry_config) ->
        validate_retry_config(retry_config, step["name"])

      _ ->
        {:error, "Step '#{step["name"]}' retry_config must be a map"}
    end
  end

  defp validate_retry_config(retry_config, step_name) do
    with :ok <-
           validate_optional_positive_integer(
             retry_config,
             "max_retries",
             "step '#{step_name}' retry_config.max_retries"
           ),
         :ok <-
           validate_optional_enum(
             retry_config,
             "backoff_strategy",
             @valid_backoff_strategies,
             "step '#{step_name}' retry_config.backoff_strategy"
           ),
         :ok <-
           validate_optional_list(
             retry_config,
             "retry_conditions",
             "step '#{step_name}' retry_config.retry_conditions"
           ),
         :ok <-
           validate_optional_string(
             retry_config,
             "fallback_action",
             "step '#{step_name}' retry_config.fallback_action"
           ) do
      :ok
    end
  end

  defp validate_enhanced_claude_options(step) do
    case step["claude_options"] do
      # claude_options is optional
      nil ->
        :ok

      options when is_map(options) ->
        validate_claude_options_fields(options, step["name"])

      _ ->
        {:error, "Step '#{step["name"]}' claude_options must be a map"}
    end
  end

  defp validate_claude_options_fields(options, step_name) do
    with :ok <- validate_core_claude_options(options, step_name),
         :ok <- validate_tool_management_options(options, step_name),
         :ok <- validate_system_prompt_options(options, step_name),
         :ok <- validate_session_management_options(options, step_name),
         :ok <- validate_performance_options(options, step_name),
         :ok <- validate_permission_options(options, step_name) do
      :ok
    end
  end

  defp validate_core_claude_options(options, step_name) do
    with :ok <-
           validate_optional_positive_integer(
             options,
             "max_turns",
             "step '#{step_name}' claude_options.max_turns"
           ),
         :ok <-
           validate_optional_enum(
             options,
             "output_format",
             @valid_output_formats,
             "step '#{step_name}' claude_options.output_format"
           ),
         :ok <-
           validate_optional_boolean(
             options,
             "verbose",
             "step '#{step_name}' claude_options.verbose"
           ) do
      :ok
    end
  end

  defp validate_tool_management_options(options, step_name) do
    with :ok <-
           validate_optional_list(
             options,
             "allowed_tools",
             "step '#{step_name}' claude_options.allowed_tools"
           ),
         :ok <-
           validate_optional_list(
             options,
             "disallowed_tools",
             "step '#{step_name}' claude_options.disallowed_tools"
           ) do
      :ok
    end
  end

  defp validate_system_prompt_options(options, step_name) do
    with :ok <-
           validate_optional_string(
             options,
             "system_prompt",
             "step '#{step_name}' claude_options.system_prompt"
           ),
         :ok <-
           validate_optional_string(
             options,
             "append_system_prompt",
             "step '#{step_name}' claude_options.append_system_prompt"
           ) do
      :ok
    end
  end

  defp validate_session_management_options(options, step_name) do
    with :ok <-
           validate_optional_string(
             options,
             "session_id",
             "step '#{step_name}' claude_options.session_id"
           ),
         :ok <-
           validate_optional_boolean(
             options,
             "resume_session",
             "step '#{step_name}' claude_options.resume_session"
           ) do
      :ok
    end
  end

  defp validate_performance_options(options, step_name) do
    with :ok <- validate_claude_retry_config(options, step_name),
         :ok <-
           validate_optional_positive_integer(
             options,
             "timeout_ms",
             "step '#{step_name}' claude_options.timeout_ms"
           ),
         :ok <-
           validate_optional_boolean(
             options,
             "debug_mode",
             "step '#{step_name}' claude_options.debug_mode"
           ),
         :ok <-
           validate_optional_boolean(
             options,
             "telemetry_enabled",
             "step '#{step_name}' claude_options.telemetry_enabled"
           ),
         :ok <-
           validate_optional_boolean(
             options,
             "cost_tracking",
             "step '#{step_name}' claude_options.cost_tracking"
           ) do
      :ok
    end
  end

  defp validate_claude_retry_config(options, step_name) do
    case options["retry_config"] do
      nil ->
        :ok

      retry_config when is_map(retry_config) ->
        validate_retry_config(retry_config, step_name <> " claude_options")

      _ ->
        {:error, "Step '#{step_name}' claude_options.retry_config must be a map"}
    end
  end

  defp validate_permission_options(options, step_name) do
    with :ok <-
           validate_optional_enum(
             options,
             "permission_mode",
             @valid_permission_modes,
             "step '#{step_name}' claude_options.permission_mode"
           ),
         :ok <-
           validate_optional_string(
             options,
             "permission_prompt_tool",
             "step '#{step_name}' claude_options.permission_prompt_tool"
           ),
         :ok <-
           validate_optional_string(
             options,
             "mcp_config",
             "step '#{step_name}' claude_options.mcp_config"
           ) do
      :ok
    end
  end

  defp validate_enhanced_prompt(step) do
    case {step["prompt"], step["type"]} do
      # Some step types don't require prompts
      {nil, "claude_batch"} ->
        :ok

      {nil, _} ->
        {:error, "Step '#{step["name"]}' missing required prompt field"}

      {prompt, _} when is_list(prompt) ->
        validate_enhanced_prompt_parts(prompt, step["name"])

      _ ->
        {:error, "Step '#{step["name"]}' prompt must be a list"}
    end
  end

  defp validate_enhanced_prompt_parts(prompt_parts, step_name) do
    Enum.reduce_while(prompt_parts, :ok, fn part, _acc ->
      case validate_enhanced_prompt_part(part, step_name) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_enhanced_prompt_part(part, step_name) do
    type = part["type"]

    case type do
      "static" ->
        validate_static_prompt_part(part, step_name)

      "file" ->
        validate_file_prompt_part(part, step_name)

      "previous_response" ->
        validate_enhanced_previous_response_part(part, step_name)

      "session_context" ->
        validate_session_context_part(part, step_name)

      "claude_continue" ->
        validate_claude_continue_part(part, step_name)

      nil ->
        {:error, "Step '#{step_name}' has prompt part without type"}

      _ ->
        {:error,
         "Step '#{step_name}' has prompt part with invalid type: #{type}. Valid types: #{Enum.join(@valid_prompt_types, ", ")}"}
    end
  end

  defp validate_static_prompt_part(part, step_name) do
    if is_nil(part["content"]) do
      {:error, "Step '#{step_name}' has static prompt part without content"}
    else
      :ok
    end
  end

  defp validate_file_prompt_part(part, step_name) do
    if is_nil(part["path"]) do
      {:error, "Step '#{step_name}' has file prompt part without path"}
    else
      :ok
    end
  end

  defp validate_enhanced_previous_response_part(part, step_name) do
    with :ok <-
           validate_required_string(part, "step", "Step '#{step_name}' previous_response part"),
         :ok <-
           validate_optional_string(
             part,
             "extract_with",
             "Step '#{step_name}' previous_response part extract_with"
           ),
         :ok <-
           validate_optional_boolean(
             part,
             "summary",
             "Step '#{step_name}' previous_response part summary"
           ),
         :ok <-
           validate_optional_positive_integer(
             part,
             "max_length",
             "Step '#{step_name}' previous_response part max_length"
           ) do
      # Validate extract_with value if present
      case part["extract_with"] do
        nil ->
          :ok

        "content_extractor" ->
          :ok

        invalid ->
          {:error,
           "Step '#{step_name}' previous_response part extract_with must be 'content_extractor', got: #{invalid}"}
      end
    end
  end

  defp validate_session_context_part(part, step_name) do
    with :ok <-
           validate_required_string(
             part,
             "session_id",
             "Step '#{step_name}' session_context part"
           ),
         :ok <-
           validate_optional_positive_integer(
             part,
             "include_last_n",
             "Step '#{step_name}' session_context part include_last_n"
           ) do
      :ok
    end
  end

  defp validate_claude_continue_part(part, step_name) do
    with :ok <-
           validate_required_string(
             part,
             "session_id",
             "Step '#{step_name}' claude_continue part"
           ),
         :ok <-
           validate_optional_string(
             part,
             "new_prompt",
             "Step '#{step_name}' claude_continue part new_prompt"
           ) do
      :ok
    end
  end

  # Enhanced defaults application

  defp apply_enhanced_defaults(config) do
    # First apply base defaults
    config_with_base_defaults = Config.apply_defaults(config)

    # Then apply enhanced defaults
    workflow = config_with_base_defaults["workflow"]
    enhanced_defaults = get_enhanced_defaults(workflow)

    updated_steps =
      Enum.map(workflow["steps"], fn step ->
        apply_enhanced_step_defaults(step, enhanced_defaults)
      end)

    put_in(config_with_base_defaults, ["workflow", "steps"], updated_steps)
  end

  defp get_enhanced_defaults(workflow) do
    base_defaults = workflow["defaults"] || %{}

    # Add enhanced default processing
    Map.merge(base_defaults, %{
      "claude_preset" => base_defaults["claude_preset"] || detect_environment_preset()
    })
  end

  defp detect_environment_preset do
    case Application.get_env(:pipeline, :environment, :development) do
      :development -> "development"
      :production -> "production"
      # Use development preset for tests
      :test -> "development"
      _ -> "development"
    end
  end

  defp apply_enhanced_step_defaults(step, defaults) do
    case step["type"] do
      "claude_smart" -> apply_claude_smart_defaults(step, defaults)
      "claude_session" -> apply_claude_session_defaults(step, defaults)
      "claude_extract" -> apply_claude_extract_defaults(step, defaults)
      "claude_batch" -> apply_claude_batch_defaults(step, defaults)
      "claude_robust" -> apply_claude_robust_defaults(step, defaults)
      # Use base defaults for other types
      _ -> step
    end
  end

  defp apply_claude_smart_defaults(step, defaults) do
    step
    |> Map.put_new("preset", defaults["claude_preset"])
    |> Map.put_new("environment_aware", true)
    |> apply_enhanced_claude_options_defaults(defaults)
  end

  defp apply_claude_session_defaults(step, defaults) do
    session_config = step["session_config"] || %{}

    enhanced_session_config =
      session_config
      |> Map.put_new("persist", true)
      |> Map.put_new("checkpoint_frequency", 5)

    step
    |> Map.put("session_config", enhanced_session_config)
    |> apply_enhanced_claude_options_defaults(defaults)
  end

  defp apply_claude_extract_defaults(step, defaults) do
    extraction_config = step["extraction_config"] || %{}

    enhanced_extraction_config =
      extraction_config
      |> Map.put_new("use_content_extractor", true)
      |> Map.put_new("format", "text")
      |> Map.put_new("include_metadata", false)

    step
    |> Map.put("extraction_config", enhanced_extraction_config)
    |> apply_enhanced_claude_options_defaults(defaults)
  end

  defp apply_claude_batch_defaults(step, defaults) do
    batch_config = step["batch_config"] || %{}

    enhanced_batch_config =
      batch_config
      |> Map.put_new("max_parallel", 3)
      |> Map.put_new("timeout_per_task", 60_000)
      |> Map.put_new("consolidate_results", true)

    step
    |> Map.put("batch_config", enhanced_batch_config)
    |> apply_enhanced_claude_options_defaults(defaults)
  end

  defp apply_claude_robust_defaults(step, defaults) do
    retry_config = step["retry_config"] || %{}

    enhanced_retry_config =
      retry_config
      |> Map.put_new("max_retries", 3)
      |> Map.put_new("backoff_strategy", "exponential")
      |> Map.put_new("retry_conditions", ["timeout", "api_error"])

    step
    |> Map.put("retry_config", enhanced_retry_config)
    |> apply_enhanced_claude_options_defaults(defaults)
  end

  defp apply_enhanced_claude_options_defaults(step, _defaults) do
    current_options = step["claude_options"] || %{}

    enhanced_options =
      current_options
      |> Map.put_new("verbose", false)
      |> Map.put_new("debug_mode", false)
      |> Map.put_new("telemetry_enabled", false)
      |> Map.put_new("cost_tracking", false)

    Map.put(step, "claude_options", enhanced_options)
  end

  # Validation helper functions

  defp validate_optional_boolean(map, key, field_name) do
    case Map.get(map, key) do
      nil -> :ok
      value when is_boolean(value) -> :ok
      _ -> {:error, "#{field_name} must be a boolean"}
    end
  end

  defp validate_optional_string(map, key, field_name) do
    case Map.get(map, key) do
      nil -> :ok
      value when is_binary(value) -> :ok
      _ -> {:error, "#{field_name} must be a string"}
    end
  end

  defp validate_required_string(map, key, field_name) do
    case Map.get(map, key) do
      nil -> {:error, "#{field_name} missing required '#{key}' field"}
      value when is_binary(value) -> :ok
      _ -> {:error, "#{field_name} #{key} must be a string"}
    end
  end

  defp validate_optional_number(map, key, field_name) do
    case Map.get(map, key) do
      nil -> :ok
      value when is_number(value) -> :ok
      _ -> {:error, "#{field_name} must be a number"}
    end
  end

  defp validate_optional_positive_integer(map, key, field_name) do
    case Map.get(map, key) do
      nil -> :ok
      value when is_integer(value) and value > 0 -> :ok
      value when is_integer(value) -> {:error, "#{field_name} must be positive, got: #{value}"}
      _ -> {:error, "#{field_name} must be a positive integer"}
    end
  end

  defp validate_optional_list(map, key, field_name) do
    case Map.get(map, key) do
      nil -> :ok
      value when is_list(value) -> :ok
      _ -> {:error, "#{field_name} must be a list"}
    end
  end

  defp validate_optional_enum(map, key, valid_values, field_name) do
    case Map.get(map, key) do
      nil ->
        :ok

      value ->
        if value in valid_values do
          :ok
        else
          {:error,
           "#{field_name} must be one of #{inspect(valid_values)}, got: #{inspect(value)}"}
        end
    end
  end
end
