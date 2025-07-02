defmodule Pipeline.Codebase.ASTParser do
  @moduledoc """
  Unified AST parsing utilities for different programming languages.

  Provides a consistent interface for parsing and analyzing code across
  multiple languages, extracting functions, classes, imports, and other
  code constructs.

  ## ⚠️  IMPORTANT WARNING ⚠️ 

  This is a PROTOTYPE implementation using simplified regex-based parsing.

  For production use, this module should be replaced with proper language parsers:
  - JavaScript/TypeScript: Babylon, Acorn, or ESTree-based parsers
  - Python: Built-in `ast` module or `parso` library
  - Rust: `syn` crate or `rustc_parse`
  - Go: `go/parser` and `go/ast` from Go standard library
  - Elixir: Enhanced AST traversal using `Code.string_to_quoted/2`

  The current regex patterns are fragile and will fail on complex code patterns.
  """

  require Logger

  @type parse_result :: %{
          functions: [function_info()],
          classes: [class_info()],
          imports: [String.t()],
          exports: [String.t()],
          comments: [comment_info()],
          complexity: non_neg_integer()
        }

  @type function_info :: %{
          name: String.t(),
          type: String.t(),
          line: non_neg_integer(),
          end_line: non_neg_integer() | nil,
          parameters: [String.t()],
          visibility: String.t(),
          signature: String.t()
        }

  @type class_info :: %{
          name: String.t(),
          line: non_neg_integer(),
          end_line: non_neg_integer() | nil,
          methods: [function_info()],
          properties: [String.t()],
          inheritance: [String.t()]
        }

  @type comment_info :: %{
          line: non_neg_integer(),
          type: String.t(),
          content: String.t()
        }

  @doc """
  Parse a file and extract code information.

  Returns structured information about functions, classes, imports,
  and other code constructs based on the file's language.
  """
  @spec parse_file(String.t()) :: {:ok, parse_result()} | {:error, String.t()}
  def parse_file(file_path) do
    case detect_language(file_path) do
      :elixir -> parse_elixir_file(file_path)
      :javascript -> parse_javascript_file(file_path)
      :typescript -> parse_typescript_file(file_path)
      :python -> parse_python_file(file_path)
      :rust -> parse_rust_file(file_path)
      :go -> parse_go_file(file_path)
      :unknown -> {:error, "Unsupported file type: #{file_path}"}
    end
  end

  @doc """
  Find function definitions in a file.
  """
  @spec find_functions(String.t(), keyword()) :: {:ok, [function_info()]} | {:error, String.t()}
  def find_functions(file_path, opts \\ []) do
    case parse_file(file_path) do
      {:ok, result} ->
        functions = result.functions

        functions =
          case Keyword.get(opts, :name) do
            nil -> functions
            name -> Enum.filter(functions, &(&1.name == name))
          end

        functions =
          case Keyword.get(opts, :visibility) do
            nil -> functions
            visibility -> Enum.filter(functions, &(&1.visibility == visibility))
          end

        {:ok, functions}

      error ->
        error
    end
  end

  @doc """
  Find class definitions in a file.
  """
  @spec find_classes(String.t(), keyword()) :: {:ok, [class_info()]} | {:error, String.t()}
  def find_classes(file_path, opts \\ []) do
    case parse_file(file_path) do
      {:ok, result} ->
        classes = result.classes

        classes =
          case Keyword.get(opts, :name) do
            nil -> classes
            name -> Enum.filter(classes, &(&1.name == name))
          end

        {:ok, classes}

      error ->
        error
    end
  end

  @doc """
  Find import/require statements in a file.
  """
  @spec find_imports(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def find_imports(file_path) do
    case parse_file(file_path) do
      {:ok, result} -> {:ok, result.imports}
      error -> error
    end
  end

  @doc """
  Calculate cyclomatic complexity for a file.
  """
  @spec calculate_complexity(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def calculate_complexity(file_path) do
    case parse_file(file_path) do
      {:ok, result} -> {:ok, result.complexity}
      error -> error
    end
  end

  # Private functions

  defp detect_language(file_path) do
    case Path.extname(file_path) do
      ".ex" -> :elixir
      ".exs" -> :elixir
      ".js" -> :javascript
      ".jsx" -> :javascript
      ".ts" -> :typescript
      ".tsx" -> :typescript
      ".py" -> :python
      ".rs" -> :rust
      ".go" -> :go
      _ -> :unknown
    end
  end

  # Language-specific parsers

  defp parse_elixir_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Code.string_to_quoted(content, file: file_path) do
          {:ok, ast} ->
            {:ok,
             %{
               functions: extract_elixir_functions_from_content(content),
               classes: extract_elixir_modules(ast),
               imports: extract_elixir_imports_from_content(content),
               exports: extract_elixir_exports(ast),
               comments: extract_elixir_comments(content),
               complexity: calculate_elixir_complexity(ast)
             }}

          {:error, error} ->
            # Code.string_to_quoted/2 returns {:error, {line, message, token}}
            # Handle the standard error format from Elixir parser
            error_msg =
              case error do
                {line, msg, _token} ->
                  line_str = if is_integer(line), do: " at line #{line}", else: ""
                  msg_str = if is_list(msg), do: inspect(msg), else: to_string(msg)
                  "Parse error#{line_str}: #{msg_str}"
              end

            {:error, error_msg}
        end

      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  defp parse_javascript_file(file_path) do
    # WARNING: This is a simplified regex-based parser for demonstration only
    # For production use, replace with proper JavaScript parsers like:
    # - Babylon/Babel parser for ES6+ syntax
    # - Acorn for lightweight parsing
    # - ESTree-compliant parsers for full AST analysis
    case File.read(file_path) do
      {:ok, content} ->
        {:ok,
         %{
           functions: extract_javascript_functions(content),
           classes: extract_javascript_classes(content),
           imports: extract_javascript_imports(content),
           exports: extract_javascript_exports(content),
           comments: extract_javascript_comments(content),
           complexity: calculate_javascript_complexity(content)
         }}

      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  defp parse_typescript_file(file_path) do
    # TypeScript parsing (similar to JavaScript for now)
    parse_javascript_file(file_path)
  end

  defp parse_python_file(file_path) do
    # WARNING: This is a simplified regex-based parser for demonstration only
    # For production use, replace with proper Python AST parsers like:
    # - Python's built-in ast module
    # - parso for error-tolerant parsing
    # - libcst for concrete syntax trees
    case File.read(file_path) do
      {:ok, content} ->
        {:ok,
         %{
           functions: extract_python_functions(content),
           classes: extract_python_classes(content),
           imports: extract_python_imports(content),
           exports: extract_python_exports(content),
           comments: extract_python_comments(content),
           complexity: calculate_python_complexity(content)
         }}

      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  defp parse_rust_file(file_path) do
    # WARNING: This is a simplified regex-based parser for demonstration only
    # For production use, replace with proper Rust parsers like:
    # - syn crate for procedural macros
    # - rustc_parse for compiler-grade parsing
    # - tree-sitter-rust for syntax highlighting
    case File.read(file_path) do
      {:ok, content} ->
        {:ok,
         %{
           functions: extract_rust_functions(content),
           classes: extract_rust_structs(content),
           imports: extract_rust_imports(content),
           exports: extract_rust_exports(content),
           comments: extract_rust_comments(content),
           complexity: calculate_rust_complexity(content)
         }}

      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  defp parse_go_file(file_path) do
    # WARNING: This is a simplified regex-based parser for demonstration only
    # For production use, replace with proper Go parsers like:
    # - go/parser and go/ast packages from Go standard library
    # - tree-sitter-go for syntax highlighting
    # - gopls language server internals
    case File.read(file_path) do
      {:ok, content} ->
        {:ok,
         %{
           functions: extract_go_functions(content),
           classes: extract_go_structs(content),
           imports: extract_go_imports(content),
           exports: extract_go_exports(content),
           comments: extract_go_comments(content),
           complexity: calculate_go_complexity(content)
         }}

      {:error, reason} ->
        {:error, "File read error: #{reason}"}
    end
  end

  # Elixir AST extraction functions

  defp extract_elixir_functions_from_content(content) do
    # Simple regex-based function extraction for Elixir
    function_regex = ~r/def\s+([a-zA-Z_][a-zA-Z0-9_?!]*)\s*\(([^)]*)\)/

    Regex.scan(function_regex, content)
    |> Enum.map(fn [match, name, params] ->
      line = count_lines_to_match(content, match)

      param_list =
        if String.trim(params) == "",
          do: [],
          else: String.split(params, ",") |> Enum.map(&String.trim/1)

      %{
        name: name,
        type: "function",
        line: line,
        end_line: nil,
        parameters: param_list,
        visibility: if(String.starts_with?(name, "_"), do: "private", else: "public"),
        signature: "#{name}(#{params})"
      }
    end)
  end

  defp extract_elixir_modules(ast) do
    ast
    |> extract_module_defs()
    |> Enum.map(fn {name, line} ->
      %{
        name: to_string(name),
        line: line,
        end_line: nil,
        methods: [],
        properties: [],
        inheritance: []
      }
    end)
  end

  defp extract_elixir_imports_from_content(content) do
    # Simple regex-based import extraction for Elixir
    import_regex = ~r/(?:alias|import|use)\s+([A-Z][A-Za-z0-9_.]*)/

    Regex.scan(import_regex, content)
    |> Enum.map(fn [_, module] -> module end)
    |> Enum.uniq()
  end

  defp extract_elixir_exports(_ast) do
    # Elixir doesn't have explicit exports like JS
    []
  end

  defp extract_elixir_comments(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.match?(line, ~r/^\s*#/) end)
    |> Enum.map(fn {line, line_num} ->
      %{
        line: line_num,
        type: "line_comment",
        content: String.trim(line)
      }
    end)
  end

  defp calculate_elixir_complexity(ast) do
    # Simple complexity calculation based on control structures
    count_complexity_nodes(ast)
  end

  # JavaScript extraction functions (regex-based)

  defp extract_javascript_functions(content) do
    # Match function declarations and arrow functions
    function_regex =
      ~r/(?:function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(([^)]*)\)|([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(?:function\s*\(([^)]*)\)|\(([^)]*)\)\s*=>))/

    Regex.scan(function_regex, content, return: :index)
    |> Enum.with_index()
    |> Enum.map(fn {[{start, _length} | _], index} ->
      line = count_lines_to_position(content, start)

      # Extract function name and parameters (simplified)
      name = "function_#{index}"

      %{
        name: name,
        type: "function",
        line: line,
        end_line: nil,
        parameters: [],
        visibility: "public",
        signature: "#{name}()"
      }
    end)
  end

  defp extract_javascript_classes(content) do
    class_regex = ~r/class\s+([a-zA-Z_$][a-zA-Z0-9_$]*)/

    Regex.scan(class_regex, content)
    |> Enum.map(fn [match, name] ->
      line = count_lines_to_match(content, match)

      %{
        name: name,
        line: line,
        end_line: nil,
        methods: [],
        properties: [],
        inheritance: []
      }
    end)
  end

  defp extract_javascript_imports(content) do
    # NOTE: This regex-based approach is very brittle and incomplete
    # For production use, this should be replaced with a proper JavaScript parser like:
    # - Babylon/Babel parser
    # - Acorn
    # - ESTree-based parsers
    # This simplified version only handles basic import statements

    basic_import_regex = ~r/import\s+.*?from\s+['"](.*?)['"]/

    Regex.scan(basic_import_regex, content)
    |> Enum.map(fn [_, module] -> module end)
    |> Enum.uniq()
  end

  defp extract_javascript_exports(content) do
    export_regex =
      ~r/export\s+(?:default\s+)?(?:function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)|class\s+([a-zA-Z_$][a-zA-Z0-9_$]*)|(?:const|let|var)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)|(\{[^}]+\}))/

    Regex.scan(export_regex, content)
    |> Enum.map(fn
      [_, name, "", "", ""] -> name
      [_, "", name, "", ""] -> name
      [_, "", "", name, ""] -> name
      [_, "", "", "", exports] -> exports
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_javascript_comments(content) do
    # Match single-line and multi-line comments
    comment_regex = ~r/\/\/.*|\/\*[\s\S]*?\*\//

    Regex.scan(comment_regex, content, return: :index)
    |> Enum.map(fn [{start, length}] ->
      line = count_lines_to_position(content, start)
      comment_text = String.slice(content, start, length)

      type = if String.starts_with?(comment_text, "//"), do: "line_comment", else: "block_comment"

      %{
        line: line,
        type: type,
        content: String.trim(comment_text)
      }
    end)
  end

  defp calculate_javascript_complexity(content) do
    # Count control flow statements
    complexity_patterns = [
      ~r/\bif\b/,
      ~r/\belse\b/,
      ~r/\bfor\b/,
      ~r/\bwhile\b/,
      ~r/\bswitch\b/,
      ~r/\bcase\b/,
      ~r/\bcatch\b/,
      ~r/\btry\b/,
      # ternary operator
      ~r/\?\s*.*?\s*:/
    ]

    complexity_patterns
    |> Enum.map(&length(Regex.scan(&1, content)))
    |> Enum.sum()
    # Base complexity of 1
    |> max(1)
  end

  # Python extraction functions (regex-based)

  defp extract_python_functions(content) do
    function_regex = ~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)/

    Regex.scan(function_regex, content)
    |> Enum.map(fn [match, name, params] ->
      line = count_lines_to_match(content, match)
      param_list = String.split(params, ",") |> Enum.map(&String.trim/1)

      %{
        name: name,
        type: "function",
        line: line,
        end_line: nil,
        parameters: param_list,
        visibility: if(String.starts_with?(name, "_"), do: "private", else: "public"),
        signature: "#{name}(#{params})"
      }
    end)
  end

  defp extract_python_classes(content) do
    class_regex = ~r/class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:\(([^)]*)\))?:/

    Regex.scan(class_regex, content)
    |> Enum.map(fn result ->
      case result do
        [match, name] ->
          line = count_lines_to_match(content, match)

          %{
            name: name,
            line: line,
            end_line: nil,
            methods: [],
            properties: [],
            inheritance: []
          }

        [match, name, ""] ->
          line = count_lines_to_match(content, match)

          %{
            name: name,
            line: line,
            end_line: nil,
            methods: [],
            properties: [],
            inheritance: []
          }

        [match, name, inheritance] ->
          line = count_lines_to_match(content, match)
          inherited_classes = String.split(inheritance, ",") |> Enum.map(&String.trim/1)

          %{
            name: name,
            line: line,
            end_line: nil,
            methods: [],
            properties: [],
            inheritance: inherited_classes
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_python_imports(content) do
    import_regex =
      ~r/(?:import\s+([a-zA-Z_][a-zA-Z0-9_.]*)|from\s+([a-zA-Z_][a-zA-Z0-9_.]*)\s+import)/

    Regex.scan(import_regex, content)
    |> Enum.map(fn
      [_, module, ""] -> module
      [_, "", module] -> module
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_python_exports(_content) do
    # Python doesn't have explicit exports
    []
  end

  defp extract_python_comments(content) do
    # Match Python comments and docstrings
    comment_regex = ~r/#.*|"""[\s\S]*?"""|'''[\s\S]*?'''/

    Regex.scan(comment_regex, content, return: :index)
    |> Enum.map(fn [{start, length}] ->
      line = count_lines_to_position(content, start)
      comment_text = String.slice(content, start, length)

      type =
        cond do
          String.starts_with?(comment_text, "#") ->
            "line_comment"

          String.starts_with?(comment_text, "\"\"\"") or String.starts_with?(comment_text, "'''") ->
            "docstring"

          true ->
            "comment"
        end

      %{
        line: line,
        type: type,
        content: String.trim(comment_text)
      }
    end)
  end

  defp calculate_python_complexity(content) do
    # Count control flow statements
    complexity_patterns = [
      ~r/\bif\b/,
      ~r/\belif\b/,
      ~r/\belse\b/,
      ~r/\bfor\b/,
      ~r/\bwhile\b/,
      ~r/\btry\b/,
      ~r/\bexcept\b/,
      ~r/\bfinally\b/,
      ~r/\bwith\b/
    ]

    complexity_patterns
    |> Enum.map(&length(Regex.scan(&1, content)))
    |> Enum.sum()
    |> max(1)
  end

  # Rust extraction functions (simplified)

  defp extract_rust_functions(content) do
    function_regex = ~r/fn\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)/

    Regex.scan(function_regex, content)
    |> Enum.map(fn [match, name, params] ->
      line = count_lines_to_match(content, match)

      %{
        name: name,
        type: "function",
        line: line,
        end_line: nil,
        parameters: [params],
        visibility: "public",
        signature: "fn #{name}(#{params})"
      }
    end)
  end

  defp extract_rust_structs(content) do
    struct_regex = ~r/struct\s+([a-zA-Z_][a-zA-Z0-9_]*)/

    Regex.scan(struct_regex, content)
    |> Enum.map(fn [match, name] ->
      line = count_lines_to_match(content, match)

      %{
        name: name,
        line: line,
        end_line: nil,
        methods: [],
        properties: [],
        inheritance: []
      }
    end)
  end

  defp extract_rust_imports(content) do
    use_regex = ~r/use\s+([a-zA-Z_][a-zA-Z0-9_:]*)/

    Regex.scan(use_regex, content)
    |> Enum.map(fn [_, module] -> module end)
    |> Enum.uniq()
  end

  defp extract_rust_exports(_content), do: []

  defp extract_rust_comments(content) do
    comment_regex = ~r/\/\/.*|\/\*[\s\S]*?\*\//

    Regex.scan(comment_regex, content, return: :index)
    |> Enum.map(fn [{start, length}] ->
      line = count_lines_to_position(content, start)
      comment_text = String.slice(content, start, length)

      type = if String.starts_with?(comment_text, "//"), do: "line_comment", else: "block_comment"

      %{
        line: line,
        type: type,
        content: String.trim(comment_text)
      }
    end)
  end

  defp calculate_rust_complexity(content) do
    complexity_patterns = [
      ~r/\bif\b/,
      ~r/\belse\b/,
      ~r/\bfor\b/,
      ~r/\bwhile\b/,
      ~r/\bloop\b/,
      ~r/\bmatch\b/,
      # match arms
      ~r/\=>/
    ]

    complexity_patterns
    |> Enum.map(&length(Regex.scan(&1, content)))
    |> Enum.sum()
    |> max(1)
  end

  # Go extraction functions (simplified)

  defp extract_go_functions(content) do
    function_regex = ~r/func\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^)]*)\)/

    Regex.scan(function_regex, content)
    |> Enum.map(fn [match, name, params] ->
      line = count_lines_to_match(content, match)

      %{
        name: name,
        type: "function",
        line: line,
        end_line: nil,
        parameters: [params],
        visibility: if(String.match?(name, ~r/^[A-Z]/), do: "public", else: "private"),
        signature: "func #{name}(#{params})"
      }
    end)
  end

  defp extract_go_structs(content) do
    struct_regex = ~r/type\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+struct/

    Regex.scan(struct_regex, content)
    |> Enum.map(fn [match, name] ->
      line = count_lines_to_match(content, match)

      %{
        name: name,
        line: line,
        end_line: nil,
        methods: [],
        properties: [],
        inheritance: []
      }
    end)
  end

  defp extract_go_imports(content) do
    # Handle both single imports and block imports
    single_import_regex = ~r/import\s+"([^"]+)"/
    block_import_regex = ~r/import\s+\(([\s\S]*?)\)/

    # Extract single imports
    single_imports =
      Regex.scan(single_import_regex, content)
      |> Enum.map(fn [_, module] -> module end)

    # Extract block imports
    block_imports =
      Regex.scan(block_import_regex, content)
      |> Enum.flat_map(fn [_, block] ->
        # Extract individual imports from the block
        Regex.scan(~r/"([^"]+)"/, block)
        |> Enum.map(fn [_, module] -> module end)
      end)

    (single_imports ++ block_imports)
    |> Enum.uniq()
  end

  defp extract_go_exports(_content), do: []

  defp extract_go_comments(content) do
    comment_regex = ~r/\/\/.*|\/\*[\s\S]*?\*\//

    Regex.scan(comment_regex, content, return: :index)
    |> Enum.map(fn [{start, length}] ->
      line = count_lines_to_position(content, start)
      comment_text = String.slice(content, start, length)

      type = if String.starts_with?(comment_text, "//"), do: "line_comment", else: "block_comment"

      %{
        line: line,
        type: type,
        content: String.trim(comment_text)
      }
    end)
  end

  defp calculate_go_complexity(content) do
    complexity_patterns = [
      ~r/\bif\b/,
      ~r/\belse\b/,
      ~r/\bfor\b/,
      ~r/\bswitch\b/,
      ~r/\bcase\b/,
      ~r/\bselect\b/,
      # goroutines add complexity
      ~r/\bgo\b/
    ]

    complexity_patterns
    |> Enum.map(&length(Regex.scan(&1, content)))
    |> Enum.sum()
    |> max(1)
  end

  # Helper functions

  defp count_lines_to_position(content, position) do
    content
    |> String.slice(0, position)
    |> String.split("\n")
    |> length()
  end

  defp count_lines_to_match(content, match) do
    case :binary.match(content, match) do
      {position, _} -> count_lines_to_position(content, position)
      :nomatch -> 1
    end
  end

  # Elixir AST traversal helpers (simplified)
  # These are placeholder functions for future proper AST implementation

  defp extract_module_defs(_ast) do
    # TODO: Implement proper AST traversal for module definitions
    # This would involve walking the AST tree to find defmodule statements
    []
  end

  defp count_complexity_nodes(_ast) do
    # TODO: Implement proper complexity calculation by counting:
    # - if/unless statements
    # - case/cond statements  
    # - for/while loops
    # - function definitions
    1
  end
end
