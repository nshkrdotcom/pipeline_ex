defmodule Pipeline.Context.Nested do
  @moduledoc """
  Context management for nested pipeline execution.

  Handles context creation, variable mapping, and output extraction
  for nested pipeline execution with support for context inheritance.
  """

  require Logger
  alias Pipeline.State.VariableEngine

  @doc """
  Create a nested context from parent context based on configuration.

  ## Parameters
  - `parent_context`: The parent pipeline's execution context
  - `step_config`: The nested pipeline step configuration

  ## Returns
  - `{:ok, nested_context}` on success
  - `{:error, reason}` on failure
  """
  def create_nested_context(parent_context, step_config) do
    require Logger

    Logger.debug(
      "Creating nested context. Parent context keys: #{inspect(Map.keys(parent_context))}"
    )

    Logger.debug("Parent context results: #{inspect(Map.get(parent_context, :results, %{}))}")
    Logger.debug("Step config inputs: #{inspect(step_config["inputs"])}")

    base_context = create_base_context(parent_context, step_config)

    with {:ok, context_with_inputs} <-
           apply_input_mappings(base_context, step_config, parent_context) do
      Logger.debug("Resolved inputs: #{inspect(context_with_inputs.inputs)}")
      enhanced_context = set_nested_metadata(context_with_inputs, parent_context, step_config)
      {:ok, enhanced_context}
    end
  end

  @doc """
  Extract outputs from nested pipeline results based on configuration.

  ## Parameters
  - `results`: The nested pipeline execution results
  - `output_config`: Output extraction configuration

  ## Returns
  - `{:ok, extracted_outputs}` on success
  - `{:error, reason}` on failure
  """
  def extract_outputs(results, output_config)
      when is_list(output_config) and length(output_config) > 0 do
    extracted =
      output_config
      |> Enum.map(&extract_single_output(results, &1))
      |> Enum.reduce_while({:ok, %{}}, fn
        {:ok, {key, value}}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, key, value)}}
        {:error, reason}, _acc -> {:halt, {:error, reason}}
      end)

    extracted
  end

  def extract_outputs(results, nil), do: {:ok, results}
  def extract_outputs(results, []), do: {:ok, results}

  @doc """
  Resolve templates in a string using the provided context.
  This is made public so it can be used by other modules.
  """
  def resolve_template(text, context) do
    resolve_template_private(text, context)
  end

  # Create base context with inheritance rules
  defp create_base_context(parent_context, step_config) do
    config = step_config["config"] || %{}
    inherit_context = Map.get(config, "inherit_context", false)

    if inherit_context do
      inherit_base_context(parent_context)
    else
      create_isolated_context(parent_context)
    end
  end

  # Create context that inherits from parent
  defp inherit_base_context(parent) do
    %{
      # Inherit read-only data
      global_vars: Map.get(parent, :global_vars, %{}),
      functions: Map.get(parent, :functions, %{}),
      providers: Map.get(parent, :providers, %{}),

      # Create new mutable data
      results: %{},
      step_index: 0,
      execution_log: [],
      # Will be populated by input mapping
      inputs: %{},
      variable_state: VariableEngine.new_state(),

      # Track nesting
      parent_context: parent,
      nesting_depth: Map.get(parent, :nesting_depth, 0) + 1
    }
  end

  # Create isolated context
  defp create_isolated_context(parent) do
    %{
      # Fresh execution state
      results: %{},
      step_index: 0,
      execution_log: [],

      # Basic inheritance (minimal)
      global_vars: %{},
      functions: Map.get(parent, :functions, %{}),
      providers: Map.get(parent, :providers, %{}),
      inputs: %{},
      variable_state: VariableEngine.new_state(),

      # Track nesting
      parent_context: parent,
      nesting_depth: Map.get(parent, :nesting_depth, 0) + 1
    }
  end

  # Apply input mappings from parent context
  defp apply_input_mappings(base_context, step_config, parent_context) do
    explicit_inputs = step_config["inputs"] || %{}
    config = step_config["config"] || %{}
    inherit_context = Map.get(config, "inherit_context", false)

    # If inheriting context and no explicit inputs, inherit parent inputs
    final_inputs =
      if inherit_context && map_size(explicit_inputs) == 0 do
        Map.get(parent_context, :inputs, %{})
      else
        {:ok, resolved_inputs} = resolve_input_mappings(explicit_inputs, parent_context)
        resolved_inputs
      end

    enhanced_context = Map.put(base_context, :inputs, final_inputs)
    {:ok, enhanced_context}
  end

  # Resolve input mappings using variable interpolation
  defp resolve_input_mappings(inputs, parent_context) when is_map(inputs) do
    resolved_inputs =
      inputs
      |> Enum.map(fn {key, value} ->
        {key, resolve_input_value(value, parent_context)}
      end)
      |> Map.new()

    {:ok, resolved_inputs}
  end

  # Resolve a single input value
  defp resolve_input_value(value, parent_context) when is_binary(value) do
    # Simple template resolution for nested pipeline inputs
    resolve_template_private(value, parent_context)
  end

  defp resolve_input_value(value, _parent_context), do: value

  # Simple template resolution
  defp resolve_template_private(text, context) do
    # Check if the entire string is a single template
    case Regex.run(~r/^\{\{([^}]+)\}\}$/, String.trim(text)) do
      [_, expression] ->
        # Single template, return the actual value (preserve type)
        expression
        |> String.trim()
        |> resolve_expression(context)
        |> unwrap_template_result()

      nil ->
        # Multiple templates or mixed content, do string replacement
        Regex.replace(~r/\{\{([^}]+)\}\}/, text, fn _, expression ->
          expression
          |> String.trim()
          |> resolve_expression(context)
          |> to_string()
        end)
    end
  end

  # Unwrap template result, returning original type or string fallback
  defp unwrap_template_result(result) when is_binary(result) do
    # If it's still a template string, return as-is
    if String.starts_with?(result, "{{") && String.ends_with?(result, "}}") do
      result
    else
      result
    end
  end

  defp unwrap_template_result(result), do: result

  # Resolve individual expressions
  defp resolve_expression(expression, context) do
    case expression do
      # Handle steps.stepname.result patterns
      "steps." <> path ->
        resolve_step_path(path, context) || "{{steps.#{path}}}"

      # Handle global_vars patterns  
      "global_vars." <> var_name ->
        get_in(context, [:global_vars, var_name]) || "{{global_vars.#{var_name}}}"

      # Handle workflow patterns
      "workflow." <> path ->
        resolve_workflow_path(path, context) || "{{workflow.#{path}}}"

      # Unknown pattern, return as-is
      _ ->
        "{{#{expression}}}"
    end
  end

  # Resolve step result paths like "prepare.result.data"
  defp resolve_step_path(path, context) do
    path_parts = String.split(path, ".")

    case path_parts do
      [step_name, "result" | rest] ->
        # Handle steps.stepname.result.field pattern
        step_result = get_in(context, [:results, step_name])

        if step_result && length(rest) > 0 do
          get_nested_value_simple(step_result, rest)
        else
          step_result
        end

      [step_name] ->
        # Handle steps.stepname pattern
        get_in(context, [:results, step_name])

      [] ->
        nil

      _ ->
        # Other patterns, try to resolve directly
        get_nested_value_simple(Map.get(context, :results, %{}), path_parts)
    end
  end

  # Resolve workflow paths
  defp resolve_workflow_path(path, context) do
    workflow_data = Map.get(context, :config, %{})
    path_parts = String.split(path, ".")
    get_nested_value_simple(workflow_data, path_parts)
  end

  # Get nested value from a structure
  defp get_nested_value_simple(data, []), do: data

  defp get_nested_value_simple(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      value -> get_nested_value_simple(value, rest)
    end
  end

  defp get_nested_value_simple(_data, _path), do: nil

  # Set nested metadata
  defp set_nested_metadata(context, parent_context, step_config) do
    context
    |> Map.put(:pipeline_source, get_pipeline_source(step_config))
    |> Map.put(:step_name, step_config["name"])
    |> Map.put(:parent_step_index, Map.get(parent_context, :step_index, 0))
  end

  # Extract a single output based on configuration
  defp extract_single_output(results, output_config) when is_binary(output_config) do
    # Simple extraction - get step result by name
    case Map.get(results, output_config) do
      nil -> {:error, "Output '#{output_config}' not found in results"}
      value -> {:ok, {output_config, value}}
    end
  end

  defp extract_single_output(results, output_config) when is_map(output_config) do
    # Complex extraction with path and alias
    path = output_config["path"]
    alias_name = output_config["as"] || path

    case extract_nested_path(results, path) do
      {:ok, value} -> {:ok, {alias_name, value}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Extract value from nested path (e.g., "step.result.field")
  defp extract_nested_path(results, path) when is_binary(path) do
    path_parts = String.split(path, ".")

    case get_nested_value(results, path_parts) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "Path '#{path}' not found in results"}
    end
  end

  # Get value from nested structure
  defp get_nested_value(data, []), do: {:ok, data}

  defp get_nested_value(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> :error
      value -> get_nested_value(value, rest)
    end
  end

  defp get_nested_value(_data, _path), do: :error

  # Helper to identify pipeline source for debugging
  defp get_pipeline_source(step_config) do
    cond do
      step_config["pipeline_file"] -> {:file, step_config["pipeline_file"]}
      step_config["pipeline"] -> :inline
      step_config["pipeline_ref"] -> {:ref, step_config["pipeline_ref"]}
      true -> :unknown
    end
  end
end
