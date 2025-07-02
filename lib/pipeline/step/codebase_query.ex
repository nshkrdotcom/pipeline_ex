defmodule Pipeline.Step.CodebaseQuery do
  @moduledoc """
  Codebase query step executor for intelligent code analysis and querying.

  Enables sophisticated querying of project structure and code relationships:
  - File finding by patterns, types, and relationships
  - Code analysis queries (find functions, classes, imports)
  - Test relationship discovery
  - Dependency analysis
  - Change impact analysis

  ## Example YAML Usage

      - name: "find_related_files"
        type: "codebase_query"
        queries:
          main_modules:
            find_files:
              - type: "main"
              - pattern: "lib/**/*.ex"
              - exclude_tests: true
          test_files:
            find_files:
              - related_to: "{{previous_response:target_file}}"
              - type: "test"
          dependencies:
            find_dependencies:
              - for_file: "lib/user.ex"
              - include_transitive: false
  """

  require Logger
  alias Pipeline.Codebase.Context
  alias Pipeline.Codebase.QueryEngine

  @doc """
  Execute a codebase query step.
  """
  def execute(step, context) do
    Logger.info("🔍 Executing codebase_query step: #{step["name"]}")

    # Get or create codebase context
    codebase_context = get_codebase_context(step, context)

    # Execute queries
    case execute_queries(step["queries"], codebase_context, context) do
      {:ok, results} ->
        Logger.info("✅ Codebase queries completed successfully")
        {:ok, results}

      {:error, reason} ->
        Logger.error("❌ Codebase query failed: #{reason}")
        {:error, reason}
    end
  end

  # Private functions

  defp get_codebase_context(step, context) do
    workspace_dir =
      step["workspace_dir"] || Map.get(context, :workspace_dir) ||
        Map.get(context, "workspace_dir") || "."

    case Map.get(context, :codebase_context) do
      nil ->
        Logger.info("🔍 Discovering codebase context for: #{workspace_dir}")
        Context.discover(workspace_dir)

      existing_context ->
        existing_context
    end
  end

  defp execute_queries(queries, codebase_context, pipeline_context) when is_map(queries) do
    results =
      queries
      |> Enum.map(fn {query_name, query_config} ->
        Logger.info("🔍 Executing query: #{query_name}")

        case execute_single_query(query_config, codebase_context, pipeline_context) do
          {:ok, result} ->
            {query_name, result}

          {:error, reason} ->
            Logger.warning("⚠️ Query #{query_name} failed: #{reason}")
            {query_name, %{error: reason}}
        end
      end)
      |> Enum.into(%{})

    {:ok, results}
  end

  defp execute_queries(queries, _codebase_context, _pipeline_context) do
    {:error, "Queries must be a map, got: #{inspect(queries)}"}
  end

  defp execute_single_query(query_config, codebase_context, pipeline_context)
       when is_map(query_config) do
    # Handle different query types
    cond do
      Map.has_key?(query_config, "find_files") ->
        execute_find_files_query(query_config["find_files"], codebase_context, pipeline_context)

      Map.has_key?(query_config, "find_dependencies") ->
        execute_find_dependencies_query(
          query_config["find_dependencies"],
          codebase_context,
          pipeline_context
        )

      Map.has_key?(query_config, "find_functions") ->
        execute_find_functions_query(
          query_config["find_functions"],
          codebase_context,
          pipeline_context
        )

      Map.has_key?(query_config, "find_related") ->
        execute_find_related_query(
          query_config["find_related"],
          codebase_context,
          pipeline_context
        )

      Map.has_key?(query_config, "analyze_impact") ->
        execute_analyze_impact_query(
          query_config["analyze_impact"],
          codebase_context,
          pipeline_context
        )

      true ->
        {:error, "Unknown query type in config: #{inspect(query_config)}"}
    end
  end

  defp execute_single_query(query_config, _codebase_context, _pipeline_context) do
    {:error, "Query config must be a map, got: #{inspect(query_config)}"}
  end

  # Query type implementations

  defp execute_find_files_query(criteria, codebase_context, pipeline_context)
       when is_list(criteria) do
    resolved_criteria = resolve_criteria(criteria, pipeline_context)

    files = QueryEngine.find_files(codebase_context, resolved_criteria)

    {:ok,
     %{
       files: files,
       count: length(files),
       criteria: resolved_criteria
     }}
  end

  defp execute_find_files_query(criteria, _codebase_context, _pipeline_context) do
    {:error, "find_files criteria must be a list, got: #{inspect(criteria)}"}
  end

  defp execute_find_dependencies_query(config, codebase_context, pipeline_context)
       when is_list(config) do
    resolved_config = resolve_criteria(config, pipeline_context)

    dependencies = QueryEngine.find_dependencies(codebase_context, resolved_config)

    {:ok,
     %{
       dependencies: dependencies,
       config: resolved_config
     }}
  end

  defp execute_find_dependencies_query(config, _codebase_context, _pipeline_context) do
    {:error, "find_dependencies config must be a list, got: #{inspect(config)}"}
  end

  defp execute_find_functions_query(config, codebase_context, pipeline_context)
       when is_list(config) do
    resolved_config = resolve_criteria(config, pipeline_context)

    functions = QueryEngine.find_functions(codebase_context, resolved_config)

    {:ok,
     %{
       functions: functions,
       config: resolved_config
     }}
  end

  defp execute_find_functions_query(config, _codebase_context, _pipeline_context) do
    {:error, "find_functions config must be a list, got: #{inspect(config)}"}
  end

  defp execute_find_related_query(config, codebase_context, pipeline_context)
       when is_list(config) do
    resolved_config = resolve_criteria(config, pipeline_context)

    related = QueryEngine.find_related_files(codebase_context, resolved_config)

    {:ok,
     %{
       related_files: related,
       config: resolved_config
     }}
  end

  defp execute_find_related_query(config, _codebase_context, _pipeline_context) do
    {:error, "find_related config must be a list, got: #{inspect(config)}"}
  end

  defp execute_analyze_impact_query(config, codebase_context, pipeline_context)
       when is_list(config) do
    resolved_config = resolve_criteria(config, pipeline_context)

    impact = QueryEngine.analyze_impact(codebase_context, resolved_config)

    {:ok,
     %{
       impact_analysis: impact,
       config: resolved_config
     }}
  end

  defp execute_analyze_impact_query(config, _codebase_context, _pipeline_context) do
    {:error, "analyze_impact config must be a list, got: #{inspect(config)}"}
  end

  # Helper functions

  defp resolve_criteria(criteria, pipeline_context) when is_list(criteria) do
    criteria
    |> Enum.map(fn criterion ->
      case criterion do
        {key, value} when is_binary(key) ->
          {String.to_atom(key), resolve_template_value(value, pipeline_context)}

        {key, value} ->
          {key, resolve_template_value(value, pipeline_context)}

        %{} = map ->
          map
          |> Enum.map(fn {k, v} ->
            key = if is_binary(k), do: String.to_atom(k), else: k
            {key, resolve_template_value(v, pipeline_context)}
          end)
          |> Enum.into([])

        value ->
          resolve_template_value(value, pipeline_context)
      end
    end)
    |> List.flatten()
  end

  defp resolve_criteria(criteria, pipeline_context) do
    resolve_template_value(criteria, pipeline_context)
  end

  defp resolve_template_value(value, pipeline_context) when is_binary(value) do
    # Simple template resolution - can be enhanced
    case Regex.run(~r/\{\{([^}]+)\}\}/, value) do
      [_, template_key] ->
        resolve_template_key(template_key, pipeline_context)

      nil ->
        value
    end
  end

  defp resolve_template_value(value, _pipeline_context), do: value

  defp resolve_template_key("workspace_dir", context) do
    context.workspace_dir || "."
  end

  defp resolve_template_key("previous_response:" <> key, context) do
    case Map.get(context, :previous_response) do
      nil -> nil
      response when is_map(response) -> Map.get(response, key)
      _ -> nil
    end
  end

  defp resolve_template_key(key, context) do
    # Try to resolve from context variables
    Map.get(context, key) || Map.get(context, String.to_atom(key))
  end
end
