defmodule Pipeline.Codebase.Analyzers.ElixirAnalyzer do
  @moduledoc """
  Specialized analyzer for Elixir projects.
  
  Provides deep analysis of Elixir codebases including:
  - Module and function discovery
  - Dependency analysis
  - Test file relationships
  - Documentation extraction
  """

  @doc """
  Analyze an Elixir file and extract module information.
  """
  @spec analyze_file(String.t()) :: {:ok, map()} | {:error, String.t()}
  def analyze_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Code.string_to_quoted(content, file: file_path) do
          {:ok, ast} ->
            {:ok, extract_module_info(ast, file_path)}
          
          {:error, {_line, error, _token}} ->
            {:error, "Parse error: #{error}"}
        end
      
      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  @doc """
  Find module dependencies within the project.
  """
  @spec find_module_dependencies(String.t(), String.t()) :: [String.t()]
  def find_module_dependencies(file_path, project_root) do
    case analyze_file(file_path) do
      {:ok, info} ->
        info[:imports] ++ info[:aliases] ++ info[:uses]
        |> Enum.filter(&is_project_module?(&1, project_root))
      
      {:error, _} ->
        []
    end
  end

  @doc """
  Find the corresponding test file for a source file.
  """
  @spec find_test_file(String.t(), String.t()) :: String.t() | nil
  def find_test_file(source_file, project_root) do
    # Convert lib/my_app/user.ex -> test/my_app/user_test.exs
    relative_path = Path.relative_to(source_file, project_root)
    
    case String.replace_prefix(relative_path, "lib/", "") do
      ^relative_path ->
        nil  # Not in lib/ directory
      
      lib_relative ->
        base_name = Path.basename(lib_relative, ".ex")
        dir_path = Path.dirname(lib_relative)
        
        test_file = Path.join([project_root, "test", dir_path, "#{base_name}_test.exs"])
        
        if File.exists?(test_file), do: test_file, else: nil
    end
  end

  @doc """
  Extract documentation from module.
  """
  @spec extract_documentation(String.t()) :: map()
  def extract_documentation(file_path) do
    case analyze_file(file_path) do
      {:ok, info} ->
        %{
          module_doc: info[:module_doc],
          function_docs: info[:function_docs] || %{}
        }
      
      {:error, _} ->
        %{module_doc: nil, function_docs: %{}}
    end
  end

  # Private functions

  defp extract_module_info(ast, file_path) do
    info = %{
      file_path: file_path,
      modules: [],
      functions: [],
      imports: [],
      aliases: [],
      uses: [],
      module_doc: nil,
      function_docs: %{}
    }
    
    traverse_ast(ast, info)
  end

  defp traverse_ast(ast, info) do
    case ast do
      {:defmodule, _meta, [module_name, [do: body]]} ->
        module_info = %{
          name: module_name_to_string(module_name),
          functions: extract_functions(body),
          doc: extract_module_doc(body)
        }
        
        updated_info = %{info | 
          modules: [module_info | info.modules],
          module_doc: module_info.doc
        }
        
        traverse_module_body(body, updated_info)
      
      list when is_list(list) ->
        Enum.reduce(list, info, &traverse_ast/2)
      
      tuple when is_tuple(tuple) ->
        tuple
        |> Tuple.to_list()
        |> Enum.reduce(info, &traverse_ast/2)
      
      _ ->
        info
    end
  end

  defp traverse_module_body(body, info) do
    case body do
      {:__block__, _meta, statements} ->
        Enum.reduce(statements, info, &process_statement/2)
      
      statement ->
        process_statement(statement, info)
    end
  end

  defp process_statement(statement, info) do
    case statement do
      {:import, _meta, [module]} ->
        %{info | imports: [module_name_to_string(module) | info.imports]}
      
      {:alias, _meta, [module]} ->
        %{info | aliases: [module_name_to_string(module) | info.aliases]}
      
      {:alias, _meta, [module, [as: _alias_name]]} ->
        %{info | aliases: [module_name_to_string(module) | info.aliases]}
      
      {:use, _meta, [module]} ->
        %{info | uses: [module_name_to_string(module) | info.uses]}
      
      {:def, _meta, [{function_name, _fun_meta, args} | _]} ->
        function_info = %{
          name: function_name,
          arity: length(args || []),
          type: :public
        }
        %{info | functions: [function_info | info.functions]}
      
      {:defp, _meta, [{function_name, _fun_meta, args} | _]} ->
        function_info = %{
          name: function_name,
          arity: length(args || []),
          type: :private
        }
        %{info | functions: [function_info | info.functions]}
      
      _ ->
        info
    end
  end

  defp extract_functions(body) do
    case body do
      {:__block__, _meta, statements} ->
        Enum.flat_map(statements, &extract_function_from_statement/1)
      
      statement ->
        extract_function_from_statement(statement)
    end
  end

  defp extract_function_from_statement(statement) do
    case statement do
      {:def, _meta, [{function_name, _fun_meta, args} | _]} ->
        [%{
          name: function_name,
          arity: length(args || []),
          type: :public
        }]
      
      {:defp, _meta, [{function_name, _fun_meta, args} | _]} ->
        [%{
          name: function_name,
          arity: length(args || []),
          type: :private
        }]
      
      _ ->
        []
    end
  end

  defp extract_module_doc(body) do
    case body do
      {:__block__, _meta, statements} ->
        Enum.find_value(statements, &extract_moduledoc/1)
      
      statement ->
        extract_moduledoc(statement)
    end
  end

  defp extract_moduledoc({:@, _meta, [{:moduledoc, _doc_meta, [doc]}]}) when is_binary(doc) do
    doc
  end

  defp extract_moduledoc(_), do: nil

  defp module_name_to_string(module) when is_atom(module) do
    Atom.to_string(module)
  end

  defp module_name_to_string({:__aliases__, _meta, aliases}) do
    aliases
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join(".")
  end

  defp module_name_to_string(module) do
    inspect(module)
  end

  defp is_project_module?(module_name, _project_root) when is_binary(module_name) do
    # Check if this looks like a project module (starts with capitalized name)
    # This is a heuristic - in practice you'd want more sophisticated detection
    case String.split(module_name, ".") do
      [first | _] ->
        String.match?(first, ~r/^[A-Z][a-zA-Z]*$/) and
        not String.starts_with?(module_name, "Elixir.") and
        not String.starts_with?(module_name, "Enum") and
        not String.starts_with?(module_name, "GenServer")
      
      _ ->
        false
    end
  end

  defp is_project_module?(_, _), do: false
end