defmodule Pipeline.Validation.SchemaValidatorTest do
  use ExUnit.Case, async: true

  alias Pipeline.Validation.SchemaValidator

  describe "validate/2" do
    test "validates basic string type" do
      schema = %{"type" => "string"}
      assert {:ok, "hello"} = SchemaValidator.validate("hello", schema)
    end

    test "rejects non-string for string type" do
      schema = %{"type" => "string"}
      assert {:error, [%{message: message}]} = SchemaValidator.validate(123, schema)
      assert message =~ "Expected string"
    end

    test "validates basic number type" do
      schema = %{"type" => "number"}
      assert {:ok, 42} = SchemaValidator.validate(42, schema)
      assert {:ok, 3.14} = SchemaValidator.validate(3.14, schema)
    end

    test "validates basic integer type" do
      schema = %{"type" => "integer"}
      assert {:ok, 42} = SchemaValidator.validate(42, schema)
    end

    test "rejects float for integer type" do
      schema = %{"type" => "integer"}
      assert {:error, [%{message: message}]} = SchemaValidator.validate(3.14, schema)
      assert message =~ "Expected integer"
    end

    test "validates basic boolean type" do
      schema = %{"type" => "boolean"}
      assert {:ok, true} = SchemaValidator.validate(true, schema)
      assert {:ok, false} = SchemaValidator.validate(false, schema)
    end

    test "validates basic array type" do
      schema = %{"type" => "array"}
      assert {:ok, [1, 2, 3]} = SchemaValidator.validate([1, 2, 3], schema)
    end

    test "validates basic object type" do
      schema = %{"type" => "object"}
      assert {:ok, %{"key" => "value"}} = SchemaValidator.validate(%{"key" => "value"}, schema)
    end

    test "validates null type" do
      schema = %{"type" => "null"}
      assert {:ok, nil} = SchemaValidator.validate(nil, schema)
    end
  end

  describe "object validation" do
    test "validates required properties" do
      schema = %{
        "type" => "object",
        "required" => ["name", "age"],
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }

      valid_data = %{"name" => "John", "age" => 30}
      assert {:ok, ^valid_data} = SchemaValidator.validate(valid_data, schema)
    end

    test "rejects missing required properties" do
      schema = %{
        "type" => "object",
        "required" => ["name", "age"],
        "properties" => %{
          "name" => %{"type" => "string"},
          "age" => %{"type" => "integer"}
        }
      }

      invalid_data = %{"name" => "John"}
      assert {:error, [%{message: message}]} = SchemaValidator.validate(invalid_data, schema)
      assert message =~ "Required property 'age' is missing"
    end

    test "validates nested object properties" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "user" => %{
            "type" => "object",
            "required" => ["name"],
            "properties" => %{
              "name" => %{"type" => "string"},
              "email" => %{"type" => "string"}
            }
          }
        }
      }

      valid_data = %{"user" => %{"name" => "John", "email" => "john@example.com"}}
      assert {:ok, ^valid_data} = SchemaValidator.validate(valid_data, schema)
    end

    test "rejects additional properties when additionalProperties is false" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"}
        },
        "additionalProperties" => false
      }

      invalid_data = %{"name" => "John", "age" => 30}
      assert {:error, [%{message: message}]} = SchemaValidator.validate(invalid_data, schema)
      assert message =~ "Additional property 'age' is not allowed"
    end

    test "validates additional properties with schema" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"}
        },
        "additionalProperties" => %{"type" => "integer"}
      }

      valid_data = %{"name" => "John", "age" => 30, "score" => 95}
      assert {:ok, ^valid_data} = SchemaValidator.validate(valid_data, schema)

      invalid_data = %{"name" => "John", "age" => "thirty"}
      assert {:error, [%{message: message}]} = SchemaValidator.validate(invalid_data, schema)
      assert message =~ "Expected integer"
    end
  end

  describe "array validation" do
    test "validates array items with schema" do
      schema = %{
        "type" => "array",
        "items" => %{"type" => "string"}
      }

      valid_data = ["hello", "world"]
      assert {:ok, ^valid_data} = SchemaValidator.validate(valid_data, schema)
    end

    test "rejects invalid array items" do
      schema = %{
        "type" => "array",
        "items" => %{"type" => "string"}
      }

      invalid_data = ["hello", 123]

      assert {:error, [%{message: message, path: path}]} =
               SchemaValidator.validate(invalid_data, schema)

      assert message =~ "Expected string"
      assert path == "[1]"
    end

    test "validates array length constraints" do
      schema = %{
        "type" => "array",
        "minItems" => 2,
        "maxItems" => 4
      }

      assert {:ok, [1, 2]} = SchemaValidator.validate([1, 2], schema)
      assert {:ok, [1, 2, 3, 4]} = SchemaValidator.validate([1, 2, 3, 4], schema)

      assert {:error, [%{message: message}]} = SchemaValidator.validate([1], schema)
      assert message =~ "Array must have at least 2 items"

      assert {:error, [%{message: message}]} = SchemaValidator.validate([1, 2, 3, 4, 5], schema)
      assert message =~ "Array must have at most 4 items"
    end
  end

  describe "string validation" do
    test "validates string length constraints" do
      schema = %{
        "type" => "string",
        "minLength" => 3,
        "maxLength" => 10
      }

      assert {:ok, "hello"} = SchemaValidator.validate("hello", schema)

      assert {:error, [%{message: message}]} = SchemaValidator.validate("hi", schema)
      assert message =~ "String must be at least 3 characters long"

      assert {:error, [%{message: message}]} =
               SchemaValidator.validate("this is too long", schema)

      assert message =~ "String must be at most 10 characters long"
    end

    test "validates string pattern" do
      schema = %{
        "type" => "string",
        "pattern" => "^[a-zA-Z]+$"
      }

      assert {:ok, "hello"} = SchemaValidator.validate("hello", schema)

      assert {:error, [%{message: message}]} = SchemaValidator.validate("hello123", schema)
      assert message =~ "String does not match pattern"
    end

    test "validates enum values" do
      schema = %{
        "type" => "string",
        "enum" => ["red", "green", "blue"]
      }

      assert {:ok, "red"} = SchemaValidator.validate("red", schema)

      assert {:error, [%{message: message}]} = SchemaValidator.validate("yellow", schema)
      assert message =~ "Value must be one of"
    end
  end

  describe "numeric validation" do
    test "validates number constraints" do
      schema = %{
        "type" => "number",
        "minimum" => 0,
        "maximum" => 100
      }

      assert {:ok, 50} = SchemaValidator.validate(50, schema)
      assert {:ok, 0} = SchemaValidator.validate(0, schema)
      assert {:ok, 100} = SchemaValidator.validate(100, schema)

      assert {:error, [%{message: message}]} = SchemaValidator.validate(-1, schema)
      assert message =~ "Value must be >= 0"

      assert {:error, [%{message: message}]} = SchemaValidator.validate(101, schema)
      assert message =~ "Value must be <= 100"
    end

    test "validates exclusive bounds" do
      schema = %{
        "type" => "number",
        "exclusiveMinimum" => 0,
        "exclusiveMaximum" => 100
      }

      assert {:ok, 50} = SchemaValidator.validate(50, schema)

      assert {:error, [%{message: message}]} = SchemaValidator.validate(0, schema)
      assert message =~ "Value must be > 0"

      assert {:error, [%{message: message}]} = SchemaValidator.validate(100, schema)
      assert message =~ "Value must be < 100"
    end
  end

  describe "validate_step_output/3" do
    test "validates step output with detailed reporting" do
      schema = %{
        "type" => "object",
        "required" => ["analysis", "score"],
        "properties" => %{
          "analysis" => %{"type" => "string", "minLength" => 10},
          "score" => %{"type" => "number", "minimum" => 0, "maximum" => 10}
        }
      }

      valid_data = %{"analysis" => "This is a detailed analysis", "score" => 8.5}

      assert {:ok, ^valid_data} =
               SchemaValidator.validate_step_output("test_step", valid_data, schema)
    end

    test "reports validation failures with step context" do
      schema = %{
        "type" => "object",
        "required" => ["analysis"],
        "properties" => %{
          "analysis" => %{"type" => "string"}
        }
      }

      invalid_data = %{"score" => 8}

      assert {:error, error_message, errors} =
               SchemaValidator.validate_step_output("test_step", invalid_data, schema)

      assert error_message =~ "Schema validation failed for step 'test_step'"
      assert error_message =~ "Required property 'analysis' is missing"
      assert is_list(errors)
      assert length(errors) == 1
    end
  end

  describe "valid_schema?/1" do
    test "validates basic schema structure" do
      assert SchemaValidator.valid_schema?(%{"type" => "string"})
      assert SchemaValidator.valid_schema?(%{"type" => "object"})
      refute SchemaValidator.valid_schema?(%{"type" => "invalid"})
      refute SchemaValidator.valid_schema?(%{})
      refute SchemaValidator.valid_schema?("not a map")
    end
  end

  describe "supported_types/0" do
    test "returns list of supported types" do
      types = SchemaValidator.supported_types()
      assert "string" in types
      assert "number" in types
      assert "integer" in types
      assert "boolean" in types
      assert "object" in types
      assert "array" in types
      assert "null" in types
    end
  end

  describe "complex validation scenarios" do
    test "validates analysis result schema" do
      schema = %{
        "type" => "object",
        "required" => ["analysis", "recommendations", "score"],
        "properties" => %{
          "analysis" => %{
            "type" => "string",
            "minLength" => 50
          },
          "score" => %{
            "type" => "number",
            "minimum" => 0,
            "maximum" => 10
          },
          "recommendations" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "required" => ["priority", "action"],
              "properties" => %{
                "priority" => %{
                  "type" => "string",
                  "enum" => ["high", "medium", "low"]
                },
                "action" => %{
                  "type" => "string",
                  "minLength" => 5
                }
              }
            }
          }
        }
      }

      valid_data = %{
        "analysis" =>
          "This is a comprehensive analysis of the code that covers multiple aspects and provides detailed insights into the structure and quality.",
        "score" => 7.5,
        "recommendations" => [
          %{
            "priority" => "high",
            "action" => "Refactor the main function to improve readability"
          },
          %{
            "priority" => "medium",
            "action" => "Add unit tests for edge cases"
          }
        ]
      }

      assert {:ok, ^valid_data} = SchemaValidator.validate(valid_data, schema)
    end

    test "provides detailed error paths for nested validation failures" do
      schema = %{
        "type" => "object",
        "required" => ["user"],
        "properties" => %{
          "user" => %{
            "type" => "object",
            "required" => ["profile"],
            "properties" => %{
              "profile" => %{
                "type" => "object",
                "required" => ["name"],
                "properties" => %{
                  "name" => %{"type" => "string", "minLength" => 2}
                }
              }
            }
          }
        }
      }

      invalid_data = %{
        "user" => %{
          "profile" => %{
            "name" => "A"
          }
        }
      }

      assert {:error, [%{path: path, message: message}]} =
               SchemaValidator.validate(invalid_data, schema)

      assert path == "user.profile.name"
      assert message =~ "String must be at least 2 characters long"
    end

    test "handles multiple validation errors" do
      schema = %{
        "type" => "object",
        "required" => ["name", "age", "email"],
        "properties" => %{
          "name" => %{"type" => "string", "minLength" => 2},
          "age" => %{"type" => "integer", "minimum" => 0, "maximum" => 150},
          "email" => %{"type" => "string", "pattern" => "^[^@]+@[^@]+$"}
        }
      }

      invalid_data = %{
        "name" => "A",
        "age" => 200,
        "email" => "invalid-email"
      }

      assert {:error, errors} = SchemaValidator.validate(invalid_data, schema)
      assert length(errors) == 3

      error_messages = Enum.map(errors, & &1.message)
      assert Enum.any?(error_messages, &(&1 =~ "String must be at least 2 characters long"))
      assert Enum.any?(error_messages, &(&1 =~ "Value must be <= 150"))
      assert Enum.any?(error_messages, &(&1 =~ "String does not match pattern"))
    end
  end
end
