defmodule Pipeline.Condition.EngineTest do
  use ExUnit.Case, async: true
  alias Pipeline.Condition.Engine

  # Test context setup
  defp test_context do
    %{
      results: %{
        "analysis" => %{
          "score" => 8.5,
          "status" => "passed",
          "warnings" => [
            %{"type" => "minor", "message" => "unused variable"},
            %{"type" => "info", "message" => "formatting issue"}
          ],
          "errors" => [],
          "metadata" => %{
            "complexity" => 3,
            "coverage" => 85.7
          }
        },
        "validation" => %{
          "success" => true,
          "message" => "All tests passed"
        },
        "empty_step" => %{},
        "false_step" => false,
        "nil_step" => nil,
        "string_step" => "hello world",
        "number_step" => 42,
        "list_step" => [1, 2, 3, 4, 5]
      }
    }
  end

  describe "simple conditions (backward compatibility)" do
    test "evaluates step existence" do
      context = test_context()
      
      assert Engine.evaluate("analysis", context) == true
      assert Engine.evaluate("validation", context) == true
      assert Engine.evaluate("nonexistent", context) == false
    end

    test "evaluates field access" do
      context = test_context()
      
      assert Engine.evaluate("analysis.score", context) == true
      assert Engine.evaluate("analysis.status", context) == true
      assert Engine.evaluate("analysis.errors", context) == false  # empty list
      assert Engine.evaluate("analysis.nonexistent", context) == false
    end

    test "evaluates nested field access" do
      context = test_context()
      
      assert Engine.evaluate("analysis.metadata.complexity", context) == true
      assert Engine.evaluate("analysis.metadata.coverage", context) == true
      assert Engine.evaluate("analysis.metadata.nonexistent", context) == false
    end

    test "evaluates falsy values" do
      context = test_context()
      
      assert Engine.evaluate("false_step", context) == false
      assert Engine.evaluate("nil_step", context) == false
      assert Engine.evaluate("empty_step", context) == false
      assert Engine.evaluate("analysis.errors", context) == false  # empty list
    end
  end

  describe "comparison operators" do
    test "evaluates numeric comparisons" do
      context = test_context()
      
      assert Engine.evaluate("analysis.score > 7", context) == true
      assert Engine.evaluate("analysis.score > 10", context) == false
      assert Engine.evaluate("analysis.score < 10", context) == true
      assert Engine.evaluate("analysis.score < 7", context) == false
      assert Engine.evaluate("analysis.score >= 8.5", context) == true
      assert Engine.evaluate("analysis.score <= 8.5", context) == true
      assert Engine.evaluate("analysis.metadata.complexity > 2", context) == true
      assert Engine.evaluate("analysis.metadata.coverage < 90", context) == true
    end

    test "evaluates equality comparisons" do
      context = test_context()
      
      assert Engine.evaluate("analysis.status == 'passed'", context) == true
      assert Engine.evaluate("analysis.status == 'failed'", context) == false
      assert Engine.evaluate("analysis.status != 'failed'", context) == true
      assert Engine.evaluate("analysis.score == 8.5", context) == true
      assert Engine.evaluate("number_step == 42", context) == true
    end

    test "evaluates string comparisons" do
      context = test_context()
      
      assert Engine.evaluate("string_step > 'hello'", context) == true
      assert Engine.evaluate("string_step < 'world'", context) == true
      assert Engine.evaluate("analysis.status > 'p'", context) == true  # "passed" > "p" is true
      assert Engine.evaluate("analysis.status < 'z'", context) == true
    end

    test "evaluates contains operator" do
      context = test_context()
      
      assert Engine.evaluate("string_step contains 'hello'", context) == true
      assert Engine.evaluate("string_step contains 'goodbye'", context) == false
      assert Engine.evaluate("list_step contains 3", context) == true
      assert Engine.evaluate("list_step contains 10", context) == false
    end

    test "evaluates matches operator" do
      context = test_context()
      
      assert Engine.evaluate("string_step matches '^hello'", context) == true
      assert Engine.evaluate("string_step matches 'world$'", context) == true
      assert Engine.evaluate("string_step matches '^goodbye'", context) == false
      assert Engine.evaluate("analysis.status matches '^pass'", context) == true
    end

    test "evaluates length property" do
      context = test_context()
      
      assert Engine.evaluate("analysis.warnings.length > 1", context) == true
      assert Engine.evaluate("analysis.warnings.length < 5", context) == true
      assert Engine.evaluate("analysis.errors.length == 0", context) == true
      assert Engine.evaluate("string_step.length > 5", context) == true
      assert Engine.evaluate("list_step.length == 5", context) == true
    end
  end

  describe "boolean operators" do
    test "evaluates AND conditions" do
      context = test_context()
      
      condition = %{
        "and" => [
          "analysis.score > 7",
          "analysis.status == 'passed'"
        ]
      }
      assert Engine.evaluate(condition, context) == true

      condition = %{
        "and" => [
          "analysis.score > 10",
          "analysis.status == 'passed'"
        ]
      }
      assert Engine.evaluate(condition, context) == false
    end

    test "evaluates OR conditions" do
      context = test_context()
      
      condition = %{
        "or" => [
          "analysis.score > 10",
          "analysis.status == 'passed'"
        ]
      }
      assert Engine.evaluate(condition, context) == true

      condition = %{
        "or" => [
          "analysis.score > 10",
          "analysis.status == 'failed'"
        ]
      }
      assert Engine.evaluate(condition, context) == false
    end

    test "evaluates NOT conditions" do
      context = test_context()
      
      condition = %{"not" => "analysis.errors.length > 0"}
      assert Engine.evaluate(condition, context) == true

      condition = %{"not" => "analysis.score > 7"}
      assert Engine.evaluate(condition, context) == false
    end

    test "evaluates nested boolean conditions" do
      context = test_context()
      
      condition = %{
        "and" => [
          "analysis.score > 7",
          %{
            "or" => [
              "analysis.status == 'passed'",
              "analysis.warnings.length < 3"
            ]
          },
          %{"not" => "analysis.errors.length > 0"}
        ]
      }
      assert Engine.evaluate(condition, context) == true

      condition = %{
        "and" => [
          "analysis.score > 10",  # This will fail
          %{
            "or" => [
              "analysis.status == 'passed'",
              "analysis.warnings.length < 3"
            ]
          }
        ]
      }
      assert Engine.evaluate(condition, context) == false
    end
  end

  describe "list conditions" do
    test "evaluates list as implicit AND" do
      context = test_context()
      
      conditions = [
        "analysis.score > 7",
        "analysis.status == 'passed'",
        "analysis.errors.length == 0"
      ]
      assert Engine.evaluate(conditions, context) == true

      conditions = [
        "analysis.score > 10",  # This will fail
        "analysis.status == 'passed'"
      ]
      assert Engine.evaluate(conditions, context) == false
    end
  end

  describe "edge cases" do
    test "handles nil condition" do
      context = test_context()
      assert Engine.evaluate(nil, context) == true
    end

    test "handles empty maps and lists" do
      context = test_context()
      assert Engine.evaluate("empty_step", context) == false
      assert Engine.evaluate("analysis.errors", context) == false
    end

    test "handles nonexistent fields gracefully" do
      context = test_context()
      assert Engine.evaluate("nonexistent.field > 5", context) == false
      assert Engine.evaluate("analysis.nonexistent == 'test'", context) == false
    end

    test "handles type mismatches gracefully" do
      context = test_context()
      # Comparing string to number should return false
      assert Engine.evaluate("string_step > 5", context) == false
      assert Engine.evaluate("number_step contains 'test'", context) == false
    end

    test "handles invalid regex patterns" do
      context = test_context()
      assert Engine.evaluate("string_step matches '[invalid'", context) == false
    end

    test "handles various literal types" do
      context = test_context()
      
      # String literals
      assert Engine.evaluate("analysis.status == \"passed\"", context) == true
      assert Engine.evaluate("analysis.status == 'passed'", context) == true
      
      # Number literals
      assert Engine.evaluate("number_step == 42", context) == true
      assert Engine.evaluate("analysis.score == 8.5", context) == true
      
      # Boolean literals
      assert Engine.evaluate("validation.success == true", context) == true
      assert Engine.evaluate("false_step == false", context) == true
      
      # Null literal
      assert Engine.evaluate("nil_step == null", context) == true
    end
  end

  describe "complex real-world scenarios" do
    test "evaluates code quality gate condition" do
      context = test_context()
      
      # Quality gate: Score > 7 AND (no errors OR warnings < 3) AND coverage > 80
      condition = %{
        "and" => [
          "analysis.score > 7",
          %{
            "or" => [
              "analysis.errors.length == 0",
              "analysis.warnings.length < 3"
            ]
          },
          "analysis.metadata.coverage > 80"
        ]
      }
      assert Engine.evaluate(condition, context) == true
    end

    test "evaluates deployment condition" do
      context = test_context()
      
      # Deploy if: validation passed AND no errors AND (high score OR low complexity)
      condition = %{
        "and" => [
          "validation.success == true",
          "analysis.errors.length == 0",
          %{
            "or" => [
              "analysis.score > 8",
              "analysis.metadata.complexity < 5"
            ]
          }
        ]
      }
      assert Engine.evaluate(condition, context) == true
    end

    test "evaluates notification condition" do
      context = test_context()
      
      # Notify if: has warnings AND (low score OR high complexity)
      condition = %{
        "and" => [
          "analysis.warnings.length > 0",
          %{
            "or" => [
              "analysis.score < 8",
              "analysis.metadata.complexity > 5"
            ]
          }
        ]
      }
      assert Engine.evaluate(condition, context) == false  # Score is 8.5, complexity is 3
    end
  end
end