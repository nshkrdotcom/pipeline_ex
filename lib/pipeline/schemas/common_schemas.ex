defmodule Pipeline.Schemas.CommonSchemas do
  @moduledoc """
  Common JSON Schema definitions for pipeline step outputs.

  Provides reusable schema definitions for common data structures
  used across different pipeline steps.
  """

  @doc """
  Schema for basic analysis results.
  """
  def analysis_result_schema do
    %{
      "type" => "object",
      "required" => ["analysis", "score"],
      "properties" => %{
        "analysis" => %{
          "type" => "string",
          "minLength" => 10,
          "description" => "Detailed analysis text"
        },
        "score" => %{
          "type" => "number",
          "minimum" => 0,
          "maximum" => 10,
          "description" => "Analysis score from 0-10"
        },
        "summary" => %{
          "type" => "string",
          "maxLength" => 500,
          "description" => "Brief summary of the analysis"
        },
        "recommendations" => %{
          "type" => "array",
          "items" => recommendation_schema(),
          "description" => "List of actionable recommendations"
        },
        "confidence" => %{
          "type" => "number",
          "minimum" => 0.0,
          "maximum" => 1.0,
          "description" => "Confidence level in the analysis"
        }
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Schema for code analysis results.
  """
  def code_analysis_schema do
    %{
      "type" => "object",
      "required" => ["files_analyzed", "issues", "metrics"],
      "properties" => %{
        "files_analyzed" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Number of files analyzed"
        },
        "issues" => %{
          "type" => "array",
          "items" => code_issue_schema(),
          "description" => "List of code issues found"
        },
        "metrics" => %{
          "type" => "object",
          "properties" => %{
            "complexity" => %{"type" => "number", "minimum" => 0},
            "maintainability" => %{"type" => "number", "minimum" => 0, "maximum" => 100},
            "test_coverage" => %{"type" => "number", "minimum" => 0, "maximum" => 100}
          },
          "additionalProperties" => true
        },
        "overall_quality" => %{
          "type" => "string",
          "enum" => ["excellent", "good", "fair", "poor"],
          "description" => "Overall code quality assessment"
        }
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Schema for test results.
  """
  def test_results_schema do
    %{
      "type" => "object",
      "required" => ["total_tests", "passed", "failed", "status"],
      "properties" => %{
        "total_tests" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Total number of tests run"
        },
        "passed" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Number of tests that passed"
        },
        "failed" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Number of tests that failed"
        },
        "skipped" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Number of tests that were skipped"
        },
        "status" => %{
          "type" => "string",
          "enum" => ["passed", "failed", "partial"],
          "description" => "Overall test run status"
        },
        "duration" => %{
          "type" => "number",
          "minimum" => 0,
          "description" => "Test execution duration in seconds"
        },
        "failures" => %{
          "type" => "array",
          "items" => test_failure_schema(),
          "description" => "Details of failed tests"
        }
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Schema for API response data.
  """
  def api_response_schema do
    %{
      "type" => "object",
      "required" => ["status_code", "success"],
      "properties" => %{
        "status_code" => %{
          "type" => "integer",
          "minimum" => 100,
          "maximum" => 599,
          "description" => "HTTP status code"
        },
        "success" => %{
          "type" => "boolean",
          "description" => "Whether the API call was successful"
        },
        "data" => %{
          "description" => "Response data - can be any type"
        },
        "error" => %{
          "type" => "string",
          "description" => "Error message if request failed"
        },
        "headers" => %{
          "type" => "object",
          "description" => "HTTP response headers"
        },
        "duration" => %{
          "type" => "number",
          "minimum" => 0,
          "description" => "Request duration in milliseconds"
        }
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Schema for file operation results.
  """
  def file_operation_schema do
    %{
      "type" => "object",
      "required" => ["operation", "success", "files_processed"],
      "properties" => %{
        "operation" => %{
          "type" => "string",
          "enum" => ["read", "write", "copy", "move", "delete", "create"],
          "description" => "Type of file operation performed"
        },
        "success" => %{
          "type" => "boolean",
          "description" => "Whether the operation succeeded"
        },
        "files_processed" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Number of files processed"
        },
        "files" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "path" => %{"type" => "string"},
              "size" => %{"type" => "integer", "minimum" => 0},
              "status" => %{"type" => "string", "enum" => ["success", "error", "skipped"]}
            }
          },
          "description" => "Details of processed files"
        },
        "errors" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "List of error messages"
        }
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Schema for documentation generation results.
  """
  def documentation_schema do
    %{
      "type" => "object",
      "required" => ["sections", "total_pages"],
      "properties" => %{
        "sections" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string"},
              "content" => %{"type" => "string"},
              "word_count" => %{"type" => "integer", "minimum" => 0}
            }
          },
          "description" => "Generated documentation sections"
        },
        "total_pages" => %{
          "type" => "integer",
          "minimum" => 0,
          "description" => "Total number of pages generated"
        },
        "format" => %{
          "type" => "string",
          "enum" => ["markdown", "html", "pdf", "docx"],
          "description" => "Output format of the documentation"
        },
        "metadata" => %{
          "type" => "object",
          "properties" => %{
            "title" => %{"type" => "string"},
            "author" => %{"type" => "string"},
            "version" => %{"type" => "string"},
            "created_at" => %{"type" => "string", "format" => "date-time"}
          }
        }
      },
      "additionalProperties" => false
    }
  end

  # Private helper schemas

  defp recommendation_schema do
    %{
      "type" => "object",
      "required" => ["priority", "action"],
      "properties" => %{
        "priority" => %{
          "type" => "string",
          "enum" => ["high", "medium", "low"],
          "description" => "Priority level of the recommendation"
        },
        "action" => %{
          "type" => "string",
          "minLength" => 5,
          "description" => "Recommended action to take"
        },
        "rationale" => %{
          "type" => "string",
          "description" => "Explanation of why this action is recommended"
        },
        "effort" => %{
          "type" => "string",
          "enum" => ["low", "medium", "high"],
          "description" => "Estimated effort required"
        }
      },
      "additionalProperties" => false
    }
  end

  defp code_issue_schema do
    %{
      "type" => "object",
      "required" => ["file", "line", "severity", "message"],
      "properties" => %{
        "file" => %{
          "type" => "string",
          "description" => "File where the issue was found"
        },
        "line" => %{
          "type" => "integer",
          "minimum" => 1,
          "description" => "Line number of the issue"
        },
        "column" => %{
          "type" => "integer",
          "minimum" => 1,
          "description" => "Column number of the issue"
        },
        "severity" => %{
          "type" => "string",
          "enum" => ["error", "warning", "info"],
          "description" => "Severity level of the issue"
        },
        "message" => %{
          "type" => "string",
          "minLength" => 5,
          "description" => "Description of the issue"
        },
        "rule" => %{
          "type" => "string",
          "description" => "Rule or check that flagged this issue"
        }
      },
      "additionalProperties" => false
    }
  end

  defp test_failure_schema do
    %{
      "type" => "object",
      "required" => ["test_name", "error_message"],
      "properties" => %{
        "test_name" => %{
          "type" => "string",
          "description" => "Name of the failed test"
        },
        "error_message" => %{
          "type" => "string",
          "description" => "Error message from the test failure"
        },
        "file" => %{
          "type" => "string",
          "description" => "Test file containing the failed test"
        },
        "line" => %{
          "type" => "integer",
          "minimum" => 1,
          "description" => "Line number where the test failed"
        },
        "duration" => %{
          "type" => "number",
          "minimum" => 0,
          "description" => "Duration of the failed test in seconds"
        }
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Get all available schema definitions as a map.
  """
  def all_schemas do
    %{
      "analysis_result" => analysis_result_schema(),
      "code_analysis" => code_analysis_schema(),
      "test_results" => test_results_schema(),
      "api_response" => api_response_schema(),
      "file_operation" => file_operation_schema(),
      "documentation" => documentation_schema()
    }
  end

  @doc """
  Get a schema by name.
  """
  def get_schema(name) do
    Map.get(all_schemas(), name)
  end

  @doc """
  List all available schema names.
  """
  def schema_names do
    Map.keys(all_schemas())
  end
end
