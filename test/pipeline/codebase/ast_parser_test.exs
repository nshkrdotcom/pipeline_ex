defmodule Pipeline.Codebase.ASTParserTest do
  use ExUnit.Case, async: true

  alias Pipeline.Codebase.ASTParser

  @test_workspace_dir "/tmp/test_ast_parser"

  setup do
    # Create test workspace
    File.mkdir_p!(@test_workspace_dir)

    # Create test files
    create_test_files()

    on_exit(fn ->
      File.rm_rf!(@test_workspace_dir)
    end)

    :ok
  end

  describe "parse_file/1" do
    test "parses Elixir file successfully" do
      file_path = Path.join(@test_workspace_dir, "user.ex")

      assert {:ok, result} = ASTParser.parse_file(file_path)

      assert Map.has_key?(result, :functions)
      assert Map.has_key?(result, :classes)
      assert Map.has_key?(result, :imports)
      assert Map.has_key?(result, :exports)
      assert Map.has_key?(result, :comments)
      assert Map.has_key?(result, :complexity)

      assert is_list(result.functions)
      assert is_list(result.classes)
      assert is_list(result.imports)
      assert is_integer(result.complexity)
    end

    test "parses JavaScript file successfully" do
      file_path = Path.join(@test_workspace_dir, "user.js")

      assert {:ok, result} = ASTParser.parse_file(file_path)

      assert Map.has_key?(result, :functions)
      assert Map.has_key?(result, :classes)
      assert Map.has_key?(result, :imports)
      assert Map.has_key?(result, :exports)
      assert Map.has_key?(result, :comments)
      assert Map.has_key?(result, :complexity)

      assert is_list(result.functions)
      assert is_list(result.classes)
      assert is_list(result.imports)
      assert is_integer(result.complexity)
    end

    test "parses Python file successfully" do
      file_path = Path.join(@test_workspace_dir, "user.py")

      assert {:ok, result} = ASTParser.parse_file(file_path)

      assert Map.has_key?(result, :functions)
      assert Map.has_key?(result, :classes)
      assert Map.has_key?(result, :imports)
      assert Map.has_key?(result, :comments)
      assert Map.has_key?(result, :complexity)

      assert is_list(result.functions)
      assert is_list(result.classes)
      assert is_list(result.imports)
      assert is_integer(result.complexity)
    end

    test "parses Rust file successfully" do
      file_path = Path.join(@test_workspace_dir, "user.rs")

      assert {:ok, result} = ASTParser.parse_file(file_path)

      assert Map.has_key?(result, :functions)
      assert Map.has_key?(result, :classes)
      assert Map.has_key?(result, :imports)
      assert Map.has_key?(result, :comments)
      assert Map.has_key?(result, :complexity)

      assert is_list(result.functions)
      assert is_list(result.classes)
      assert is_list(result.imports)
      assert is_integer(result.complexity)
    end

    test "parses Go file successfully" do
      file_path = Path.join(@test_workspace_dir, "user.go")

      assert {:ok, result} = ASTParser.parse_file(file_path)

      assert Map.has_key?(result, :functions)
      assert Map.has_key?(result, :classes)
      assert Map.has_key?(result, :imports)
      assert Map.has_key?(result, :comments)
      assert Map.has_key?(result, :complexity)

      assert is_list(result.functions)
      assert is_list(result.classes)
      assert is_list(result.imports)
      assert is_integer(result.complexity)
    end

    test "returns error for unsupported file type" do
      file_path = Path.join(@test_workspace_dir, "data.txt")
      File.write!(file_path, "Some text content")

      assert {:error, reason} = ASTParser.parse_file(file_path)
      assert String.contains?(reason, "Unsupported file type")
    end

    test "returns error for non-existent file" do
      file_path = Path.join(@test_workspace_dir, "non_existent.ex")

      assert {:error, reason} = ASTParser.parse_file(file_path)
      assert String.contains?(reason, "File read error")
    end
  end

  describe "find_functions/2" do
    test "finds all functions in Elixir file" do
      file_path = Path.join(@test_workspace_dir, "user.ex")

      assert {:ok, functions} = ASTParser.find_functions(file_path)

      assert is_list(functions)
      assert length(functions) > 0
      assert Enum.all?(functions, &is_map/1)
      assert Enum.all?(functions, &Map.has_key?(&1, :name))
      assert Enum.all?(functions, &Map.has_key?(&1, :type))
      assert Enum.all?(functions, &Map.has_key?(&1, :line))
    end

    test "finds functions by name" do
      file_path = Path.join(@test_workspace_dir, "user.ex")

      assert {:ok, functions} = ASTParser.find_functions(file_path, name: "create_user")

      assert is_list(functions)
      assert Enum.all?(functions, &(&1.name == "create_user"))
    end

    test "finds functions by visibility" do
      file_path = Path.join(@test_workspace_dir, "user.ex")

      assert {:ok, functions} = ASTParser.find_functions(file_path, visibility: "public")

      assert is_list(functions)
      assert Enum.all?(functions, &(&1.visibility == "public"))
    end

    test "finds JavaScript functions" do
      file_path = Path.join(@test_workspace_dir, "user.js")

      assert {:ok, functions} = ASTParser.find_functions(file_path)

      assert is_list(functions)
      assert length(functions) > 0
      assert Enum.all?(functions, &(&1.type == "function"))
    end

    test "finds Python functions" do
      file_path = Path.join(@test_workspace_dir, "user.py")

      assert {:ok, functions} = ASTParser.find_functions(file_path)

      assert is_list(functions)
      assert length(functions) > 0
      assert Enum.all?(functions, &(&1.type == "function"))
    end
  end

  describe "find_classes/2" do
    test "finds classes in Python file" do
      file_path = Path.join(@test_workspace_dir, "user.py")

      assert {:ok, classes} = ASTParser.find_classes(file_path)

      assert is_list(classes)
      assert length(classes) > 0
      assert Enum.all?(classes, &is_map/1)
      assert Enum.all?(classes, &Map.has_key?(&1, :name))
      assert Enum.all?(classes, &Map.has_key?(&1, :line))
    end

    test "finds classes by name" do
      file_path = Path.join(@test_workspace_dir, "user.py")

      assert {:ok, classes} = ASTParser.find_classes(file_path, name: "User")

      assert is_list(classes)
      assert Enum.all?(classes, &(&1.name == "User"))
    end

    test "finds JavaScript classes" do
      file_path = Path.join(@test_workspace_dir, "user.js")

      assert {:ok, classes} = ASTParser.find_classes(file_path)

      assert is_list(classes)
      assert length(classes) > 0
    end
  end

  describe "find_imports/1" do
    test "finds Elixir imports" do
      file_path = Path.join(@test_workspace_dir, "user.ex")

      assert {:ok, imports} = ASTParser.find_imports(file_path)

      assert is_list(imports)
      # Should find alias statements
    end

    test "finds JavaScript imports" do
      file_path = Path.join(@test_workspace_dir, "user.js")

      assert {:ok, imports} = ASTParser.find_imports(file_path)

      assert is_list(imports)
      assert length(imports) > 0
    end

    test "finds Python imports" do
      file_path = Path.join(@test_workspace_dir, "user.py")

      assert {:ok, imports} = ASTParser.find_imports(file_path)

      assert is_list(imports)
      assert length(imports) > 0
    end

    test "finds Rust imports" do
      file_path = Path.join(@test_workspace_dir, "user.rs")

      assert {:ok, imports} = ASTParser.find_imports(file_path)

      assert is_list(imports)
      assert length(imports) > 0
    end

    test "finds Go imports" do
      file_path = Path.join(@test_workspace_dir, "user.go")

      assert {:ok, imports} = ASTParser.find_imports(file_path)

      assert is_list(imports)
      assert length(imports) > 0
    end
  end

  describe "calculate_complexity/1" do
    test "calculates complexity for Elixir file" do
      file_path = Path.join(@test_workspace_dir, "user.ex")

      assert {:ok, complexity} = ASTParser.calculate_complexity(file_path)

      assert is_integer(complexity)
      assert complexity >= 1
    end

    test "calculates complexity for JavaScript file" do
      file_path = Path.join(@test_workspace_dir, "user.js")

      assert {:ok, complexity} = ASTParser.calculate_complexity(file_path)

      assert is_integer(complexity)
      assert complexity >= 1
    end

    test "calculates complexity for Python file" do
      file_path = Path.join(@test_workspace_dir, "user.py")

      assert {:ok, complexity} = ASTParser.calculate_complexity(file_path)

      assert is_integer(complexity)
      assert complexity >= 1
    end

    test "higher complexity for files with more control structures" do
      simple_file = Path.join(@test_workspace_dir, "simple.py")
      complex_file = Path.join(@test_workspace_dir, "complex.py")

      # Simple file
      File.write!(simple_file, """
      def simple_function():
          return "hello"
      """)

      # Complex file with control structures
      File.write!(complex_file, """
      def complex_function(x):
          if x > 0:
              for i in range(x):
                  if i % 2 == 0:
                      continue
                  else:
                      try:
                          result = process(i)
                      except Exception:
                          pass
              return result
          else:
              return None
      """)

      assert {:ok, simple_complexity} = ASTParser.calculate_complexity(simple_file)
      assert {:ok, complex_complexity} = ASTParser.calculate_complexity(complex_file)

      assert complex_complexity > simple_complexity
    end
  end

  describe "language detection" do
    test "detects Elixir files correctly" do
      ex_file = Path.join(@test_workspace_dir, "test.ex")
      exs_file = Path.join(@test_workspace_dir, "test.exs")

      File.write!(ex_file, "defmodule Test, do: nil")
      File.write!(exs_file, "defmodule Test, do: nil")

      assert {:ok, _} = ASTParser.parse_file(ex_file)
      assert {:ok, _} = ASTParser.parse_file(exs_file)
    end

    test "detects JavaScript/TypeScript files correctly" do
      js_file = Path.join(@test_workspace_dir, "test.js")
      ts_file = Path.join(@test_workspace_dir, "test.ts")
      jsx_file = Path.join(@test_workspace_dir, "test.jsx")
      tsx_file = Path.join(@test_workspace_dir, "test.tsx")

      File.write!(js_file, "function test() {}")
      File.write!(ts_file, "function test(): void {}")
      File.write!(jsx_file, "function test() { return <div/>; }")
      File.write!(tsx_file, "function test(): JSX.Element { return <div/>; }")

      assert {:ok, _} = ASTParser.parse_file(js_file)
      assert {:ok, _} = ASTParser.parse_file(ts_file)
      assert {:ok, _} = ASTParser.parse_file(jsx_file)
      assert {:ok, _} = ASTParser.parse_file(tsx_file)
    end
  end

  describe "error handling" do
    test "handles malformed Elixir file" do
      malformed_file = Path.join(@test_workspace_dir, "malformed.ex")
      File.write!(malformed_file, "defmodule Test do\n  # Missing end")

      assert {:error, reason} = ASTParser.parse_file(malformed_file)
      assert String.contains?(reason, "Parse error")
    end

    test "handles empty files gracefully" do
      empty_file = Path.join(@test_workspace_dir, "empty.ex")
      File.write!(empty_file, "")

      # Should not crash, might return empty results
      result = ASTParser.parse_file(empty_file)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # Helper functions

  defp create_test_files do
    # Create Elixir file
    elixir_content = """
    defmodule TestProject.User do
      @moduledoc "User management module"

      alias TestProject.Account
      import TestProject.Utils

      # This is a comment
      def create_user(params) do
        if valid_user?(params) do
          {:ok, params}
        else
          {:error, "Invalid user"}
        end
      end

      def update_user(id, params) when is_integer(id) do
        case validate_user(params) do
          {:ok, validated} -> {:ok, validated}
          error -> error
        end
      end

      defp validate_user(params) do
        {:ok, params}
      end

      defp valid_user?(_params), do: true
    end
    """

    File.write!(Path.join(@test_workspace_dir, "user.ex"), elixir_content)

    # Create JavaScript file
    js_content = """
    // User management functions
    import { validate } from './utils.js';

    /* Multi-line comment
       for documentation */
    function createUser(params) {
      if (params.name) {
        return { id: 1, ...params };
      } else {
        throw new Error('Invalid user');
      }
    }

    const updateUser = (id, params) => {
      for (let key in params) {
        if (params.hasOwnProperty(key)) {
          // Update logic
        }
      }
      return { id, ...params };
    };

    class UserManager {
      constructor() {
        this.users = [];
      }

      addUser(user) {
        try {
          this.users.push(user);
        } catch (error) {
          console.error(error);
        }
      }
    }

    export { createUser, updateUser, UserManager };
    """

    File.write!(Path.join(@test_workspace_dir, "user.js"), js_content)

    # Create Python file
    python_file = Path.join(@test_workspace_dir, "user.py")

    File.write!(python_file, """
    \"\"\"User management module\"\"\"
    import os
    from datetime import datetime

    class User:
        \"\"\"User class for managing user data\"\"\"
        
        def __init__(self, name, email):
            self.name = name
            self.email = email

        def create_user(self, params):
            \"\"\"Create a new user\"\"\"
            if params.get('name'):
                return {'id': 1, **params}
            else:
                raise ValueError('Invalid user')

        def update_user(self, user_id, params):
            \"\"\"Update user information\"\"\"
            for key, value in params.items():
                if hasattr(self, key):
                    setattr(self, key, value)
            return self

    def validate_user(params):
        # Validation logic
        if 'email' in params:
            return params['email'].count('@') == 1
        return False

    def process_users(users):
        \"\"\"Process a list of users\"\"\"
        results = []
        for user in users:
            try:
                if validate_user(user):
                    results.append(user)
                elif user.get('force', False):
                    results.append(user)
                else:
                    continue
            except Exception as e:
                print(f"Error processing user: {e}")
                pass
        return results
    """)

    # Create Rust file
    rust_content = """
    // User management module
    use std::collections::HashMap;

    /* Multi-line comment
       for documentation */
    struct User {
        id: u32,
        name: String,
        email: String,
    }

    impl User {
        fn new(name: String, email: String) -> Self {
            User {
                id: 1,
                name,
                email,
            }
        }
    }

    fn create_user(params: HashMap<String, String>) -> Result<User, String> {
        if let Some(name) = params.get("name") {
            if let Some(email) = params.get("email") {
                Ok(User::new(name.clone(), email.clone()))
            } else {
                Err("Email required".to_string())
            }
        } else {
            Err("Name required".to_string())
        }
    }

    fn validate_user(user: &User) -> bool {
        match user.email.contains('@') {
            true => !user.name.is_empty(),
            false => false,
        }
    }
    """

    File.write!(Path.join(@test_workspace_dir, "user.rs"), rust_content)

    # Create Go file
    go_content = """
    // User management package
    package main

    import (
        "fmt"
        "strings"
    )

    /* Multi-line comment
       for documentation */
    type User struct {
        ID    int    `json:"id"`
        Name  string `json:"name"`
        Email string `json:"email"`
    }

    func CreateUser(name, email string) (*User, error) {
        if name == "" {
            return nil, fmt.Errorf("name is required")
        }
        
        if !strings.Contains(email, "@") {
            return nil, fmt.Errorf("invalid email")
        }

        return &User{
            ID:    1,
            Name:  name,
            Email: email,
        }, nil
    }

    func (u *User) UpdateUser(params map[string]string) {
        for key, value := range params {
            switch key {
            case "name":
                u.Name = value
            case "email":
                u.Email = value
            }
        }
    }

    func validateUser(user *User) bool {
        return user.Name != "" && strings.Contains(user.Email, "@")
    }
    """

    File.write!(Path.join(@test_workspace_dir, "user.go"), go_content)
  end
end
