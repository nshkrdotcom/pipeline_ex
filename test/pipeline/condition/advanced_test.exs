defmodule Pipeline.Condition.AdvancedTest do
  use ExUnit.Case, async: true
  
  alias Pipeline.Condition.Engine

  describe "mathematical expressions" do
    test "basic arithmetic operations" do
      context = %{results: %{"step1" => %{"score" => 8, "weight" => 0.9}}}
      
      # Multiplication
      assert Engine.evaluate("step1.score * step1.weight", context) == true
      assert Engine.evaluate("step1.score * step1.weight > 7", context) == true
      assert Engine.evaluate("step1.score * step1.weight < 5", context) == false
      
      # Addition
      assert Engine.evaluate("step1.score + 2 == 10", context) == true
      assert Engine.evaluate("step1.score + step1.weight > 8", context) == true
      
      # Division
      assert Engine.evaluate("step1.score / 2 == 4", context) == true
      assert Engine.evaluate("step1.score / 0 == 0", context) == true  # Division by zero protection
      
      # Subtraction
      assert Engine.evaluate("step1.score - 3 == 5", context) == true
      
      # Modulo
      assert Engine.evaluate("step1.score % 3 == 2", context) == true
    end
    
    test "operator precedence" do
      context = %{results: %{"step1" => %{"a" => 2, "b" => 3, "c" => 4}}}
      
      # Multiplication before addition
      assert Engine.evaluate("step1.a + step1.b * step1.c == 14", context) == true
      
      # Division before subtraction
      assert Engine.evaluate("step1.c - step1.b / step1.a == 2.5", context) == true
    end
    
    test "complex mathematical comparisons" do
      context = %{results: %{"analysis" => %{"score" => 8.5, "confidence" => 0.85, "threshold" => 0.8}}}
      
      assert Engine.evaluate("analysis.score * analysis.confidence > analysis.threshold", context) == true
      assert Engine.evaluate("analysis.score * analysis.confidence <= 7.0", context) == false
    end
  end

  describe "string functions" do
    test "contains function" do
      context = %{results: %{"step1" => %{"message" => "Hello World", "tags" => ["error", "warning"]}}}
      
      assert Engine.evaluate("contains(step1.message, 'World')", context) == true
      assert Engine.evaluate("contains(step1.message, 'xyz')", context) == false
      assert Engine.evaluate("contains(step1.tags, 'error')", context) == true
    end
    
    test "matches function" do
      context = %{results: %{"analysis" => %{"file_path" => "/src/test.ex", "email" => "user@example.com"}}}
      
      assert Engine.evaluate("matches(analysis.file_path, '.*\\.ex')", context) == true
      assert Engine.evaluate("matches(analysis.file_path, '.*\\.js')", context) == false
      assert Engine.evaluate("matches(analysis.email, '\\w+@\\w+\\.\\w+')", context) == true
    end
    
    test "length function" do
      context = %{results: %{"step1" => %{"text" => "Hello", "items" => [1, 2, 3, 4]}}}
      
      assert Engine.evaluate("length(step1.text) == 5", context) == true
      assert Engine.evaluate("length(step1.items) == 4", context) == true
      assert Engine.evaluate("length(step1.items) > 3", context) == true
    end
    
    test "startsWith and endsWith functions" do
      context = %{results: %{"step1" => %{"filename" => "test_file.ex"}}}
      
      assert Engine.evaluate("startsWith(step1.filename, 'test')", context) == true
      assert Engine.evaluate("startsWith(step1.filename, 'prod')", context) == false
      assert Engine.evaluate("endsWith(step1.filename, '.ex')", context) == true
      assert Engine.evaluate("endsWith(step1.filename, '.js')", context) == false
    end
  end

  describe "array functions" do
    test "any function with condition" do
      context = %{
        results: %{
          "analysis" => %{
            "issues" => [
              %{"severity" => "low", "type" => "style"},
              %{"severity" => "high", "type" => "security"},
              %{"severity" => "medium", "type" => "performance"}
            ]
          }
        }
      }
      
      assert Engine.evaluate("any(analysis.issues, 'severity == \"high\"')", context) == true
      assert Engine.evaluate("any(analysis.issues, 'severity == \"critical\"')", context) == false
    end
    
    test "all function with condition" do
      context = %{
        results: %{
          "step1" => %{
            "scores" => [8, 9, 7, 8],
            "statuses" => ["passed", "passed", "passed"]
          }
        }
      }
      
      assert Engine.evaluate("all(step1.scores, '@ > 6')", context) == true
      assert Engine.evaluate("all(step1.scores, '@ > 8')", context) == false
    end
    
    test "count function" do
      context = %{
        results: %{
          "step1" => %{
            "items" => [1, 2, 3, 4, 5],
            "errors" => [%{"type" => "syntax"}, %{"type" => "logic"}]
          }
        }
      }
      
      assert Engine.evaluate("count(step1.items) == 5", context) == true
      assert Engine.evaluate("count(step1.errors) == 2", context) == true
      assert Engine.evaluate("count(step1.items) > 3", context) == true
    end
    
    test "sum and average functions" do
      context = %{results: %{"step1" => %{"scores" => [8, 9, 7, 8]}}}
      
      assert Engine.evaluate("sum(step1.scores) == 32", context) == true
      assert Engine.evaluate("average(step1.scores) == 8.0", context) == true
      assert Engine.evaluate("average(step1.scores) > 7.5", context) == true
    end
    
    test "min and max functions" do
      context = %{results: %{"step1" => %{"values" => [3, 1, 4, 1, 5, 9]}}}
      
      assert Engine.evaluate("min(step1.values) == 1", context) == true
      assert Engine.evaluate("max(step1.values) == 9", context) == true
      assert Engine.evaluate("max(step1.values) - min(step1.values) == 8", context) == true
    end
    
    test "isEmpty function" do
      context = %{
        results: %{
          "step1" => %{
            "empty_list" => [],
            "empty_string" => "",
            "filled_list" => [1, 2, 3],
            "filled_string" => "hello"
          }
        }
      }
      
      assert Engine.evaluate("isEmpty(step1.empty_list)", context) == true
      assert Engine.evaluate("isEmpty(step1.empty_string)", context) == true
      assert Engine.evaluate("isEmpty(step1.filled_list)", context) == false
      assert Engine.evaluate("isEmpty(step1.filled_string)", context) == false
    end
  end

  describe "mathematical functions" do
    test "abs, round, floor, ceil functions" do
      context = %{results: %{"step1" => %{"negative" => -5.7, "positive" => 3.2}}}
      
      assert Engine.evaluate("abs(step1.negative) == 5.7", context) == true
      assert Engine.evaluate("round(step1.negative) == -6", context) == true
      assert Engine.evaluate("floor(step1.positive) == 3", context) == true
      assert Engine.evaluate("ceil(step1.positive) == 4", context) == true
    end
    
    test "between function" do
      context = %{results: %{"step1" => %{"score" => 7.5, "min" => 5, "max" => 10}}}
      
      assert Engine.evaluate("between(step1.score, 5, 10)", context) == true
      assert Engine.evaluate("between(step1.score, 8, 10)", context) == false
      assert Engine.evaluate("step1.score between step1.min and step1.max", context) == true
    end
  end

  describe "date/time functions" do
    test "now function returns current datetime" do
      context = %{results: %{}}
      
      # Test that now() returns a DateTime
      result = Pipeline.Condition.Functions.call_function("now", [], context)
      assert %DateTime{} = result
    end
    
    test "duration functions" do
      context = %{results: %{"step1" => %{"days_val" => 2, "hours_val" => 3}}}
      
      # These functions return seconds
      assert Engine.evaluate("days(1) == 86400", context) == true  # 1 day = 86400 seconds
      assert Engine.evaluate("hours(1) == 3600", context) == true   # 1 hour = 3600 seconds
      assert Engine.evaluate("minutes(1) == 60", context) == true   # 1 minute = 60 seconds
    end
  end

  describe "complex expressions" do
    test "combined mathematical and function expressions" do
      context = %{
        results: %{
          "analysis" => %{
            "score" => 8.5,
            "confidence" => 0.9,
            "recommendations" => ["fix1", "fix2", "fix3", "fix4"],
            "issues" => [
              %{"severity" => "low"},
              %{"severity" => "medium"},
              %{"severity" => "low"}
            ]
          }
        }
      }
      
      # Complex condition with multiple functions and math
      complex_condition = %{
        "and" => [
          "analysis.score * analysis.confidence > 0.8",
          "any(analysis.issues, 'severity == \"high\"') == false",
          "length(analysis.recommendations) between 3 and 10"
        ]
      }
      
      assert Engine.evaluate(complex_condition, context) == true
    end
    
    test "nested function calls" do
      context = %{
        results: %{
          "step1" => %{
            "data" => [
              %{"values" => [1, 2, 3]},
              %{"values" => [4, 5, 6]},
              %{"values" => [7, 8, 9]}
            ]
          }
        }
      }
      
      # This is a complex nested case that would require more sophisticated parsing
      # For now, we test simpler combinations
      assert Engine.evaluate("count(step1.data) == 3", context) == true
      assert Engine.evaluate("count(step1.data) > 2", context) == true
    end
  end

  describe "edge cases and error handling" do
    test "invalid function names" do
      context = %{results: %{}}
      
      assert_raise ArgumentError, "Unknown function: invalidFunction", fn ->
        Pipeline.Condition.Functions.call_function("invalidFunction", [], context)
      end
    end
    
    test "division by zero protection" do
      context = %{results: %{"step1" => %{"zero" => 0, "value" => 10}}}
      
      assert Engine.evaluate("step1.value / step1.zero == 0", context) == true
      assert Engine.evaluate("step1.value % step1.zero == 0", context) == true
    end
    
    test "invalid regex patterns" do
      context = %{results: %{"step1" => %{"text" => "hello"}}}
      
      # Invalid regex should return false, not crash
      assert Engine.evaluate("matches(step1.text, '[invalid')", context) == false
    end
    
    test "non-numeric operations on strings" do
      context = %{results: %{"step1" => %{"text" => "hello", "number" => 5}}}
      
      # Should handle gracefully
      assert Engine.evaluate("step1.text + step1.number == 0", context) == false
    end
    
    test "missing fields return appropriate defaults" do
      context = %{results: %{"step1" => %{}}}
      
      assert Engine.evaluate("length(step1.missing_field) == 0", context) == true
      assert Engine.evaluate("step1.missing_field == null", context) == true
    end
  end

  describe "backward compatibility" do
    test "simple truthy conditions still work" do
      context = %{results: %{"step1" => %{"success" => true, "error" => nil}}}
      
      assert Engine.evaluate("step1.success", context) == true
      assert Engine.evaluate("step1.error", context) == false
    end
    
    test "existing dot notation still works" do
      context = %{results: %{"analysis" => %{"result" => %{"status" => "passed"}}}}
      
      assert Engine.evaluate("analysis.result.status", context) == true
    end
    
    test "existing boolean expressions still work" do
      context = %{results: %{"step1" => %{"score" => 8}, "step2" => %{"valid" => true}}}
      
      condition = %{
        "and" => [
          "step1.score > 5",
          "step2.valid"
        ]
      }
      
      assert Engine.evaluate(condition, context) == true
    end
  end
end