# Testing Strategy for Advanced Pipeline Features

**🎯 Goal**: Create comprehensive, working examples for ALL advanced features that test each capability in isolation and demonstrate real-world integration patterns.

## Overview

This document outlines the systematic approach to building robust tests and examples for the 5 critical advanced features, ensuring each component works independently and integrates seamlessly with the existing pipeline system.

## 🧪 Testing Methodology

### 1. Isolation Testing
Each feature must have dedicated tests that work independently:
- **Unit Tests**: Test individual functions and modules
- **Component Tests**: Test step types in isolation
- **Mock Tests**: Validate logic without API costs
- **Performance Tests**: Benchmark resource usage

### 2. Integration Testing
Features must work together seamlessly:
- **Combination Tests**: Multiple features in single workflows
- **Real-world Scenarios**: Practical use cases
- **Error Handling**: Failure modes and recovery
- **Performance**: Large-scale operations

### 3. Example-Driven Development
Every feature needs working examples:
- **Minimal Examples**: Simplest possible demonstration
- **Practical Examples**: Real-world use cases
- **Complex Examples**: Advanced integration patterns
- **Performance Examples**: Large-scale demonstrations

## 📋 Feature Testing Matrix

| Feature | Unit Tests | Component Tests | Integration Tests | Examples | Performance Tests |
|---------|------------|-----------------|-------------------|----------|-------------------|
| **Loop Constructs** | ✅ Engine logic | ✅ for_loop/while_loop steps | ✅ Nested loops + conditions | ✅ File processing | ✅ Large datasets |
| **Complex Conditions** | ✅ Expression parser | ✅ Condition evaluation | ✅ Conditions + loops | ✅ Smart routing | ✅ Expression complexity |
| **File Operations** | ✅ File utilities | ✅ file_ops step | ✅ File ops + transforms | ✅ Workspace management | ✅ Large file streaming |
| **Data Transformation** | ✅ Transform engine | ✅ data_transform step | ✅ Schema + transforms | ✅ ETL pipeline | ✅ Large dataset processing |
| **Codebase Intelligence** | ✅ Discovery engine | ✅ codebase_query step | ✅ Code analysis workflow | ✅ Project analysis | ✅ Large codebase scanning |
| **State Management** | ✅ Variable engine | ✅ set_variable step | ✅ State + loops | ✅ Multi-step workflows | ✅ Long-running pipelines |

## 🔄 1. Loop Constructs Testing Strategy

### Unit Tests (`test/pipeline/step/loop_test.exs`)

```elixir
defmodule Pipeline.Step.LoopTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  describe "for_loop execution" do
    test "iterates over simple array" do
      step = %{
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => [1, 2, 3],
        "steps" => [
          %{"name" => "process", "type" => "mock", "response" => "processed {{loop.item}}"}
        ]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.Loop.execute(step, context)
      
      assert result["results"] == ["processed 1", "processed 2", "processed 3"]
    end
    
    test "handles empty data source gracefully" do
      step = %{
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => [],
        "steps" => [%{"name" => "process", "type" => "mock"}]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.Loop.execute(step, context)
      
      assert result["results"] == []
      assert result["iterations"] == 0
    end
    
    test "respects max_iterations safety limit" do
      step = %{
        "type" => "while_loop",
        "condition" => "true",  # Would loop forever
        "max_iterations" => 3,
        "steps" => [%{"name" => "process", "type" => "mock"}]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.Loop.execute(step, context)
      
      assert result["iterations"] == 3
      assert result["terminated_by"] == "max_iterations"
    end
    
    test "supports nested loops with proper variable scoping" do
      step = %{
        "type" => "for_loop",
        "iterator" => "category",
        "data_source" => [
          %{"name" => "docs", "files" => ["a.md", "b.md"]},
          %{"name" => "code", "files" => ["x.ex", "y.ex"]}
        ],
        "steps" => [
          %{
            "name" => "process_files",
            "type" => "for_loop",
            "iterator" => "file",
            "data_source" => "{{loop.category.files}}",
            "steps" => [
              %{"name" => "process", "type" => "mock", 
                "response" => "{{loop.parent.category.name}}/{{loop.file}}"}
            ]
          }
        ]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.Loop.execute(step, context)
      
      expected = ["docs/a.md", "docs/b.md", "code/x.ex", "code/y.ex"]
      assert flatten_nested_results(result) == expected
    end
  end
  
  describe "parallel execution" do
    test "executes iterations in parallel" do
      step = %{
        "type" => "for_loop",
        "iterator" => "item",
        "data_source" => [1, 2, 3, 4, 5],
        "parallel" => true,
        "max_parallel" => 2,
        "steps" => [
          %{"name" => "slow_process", "type" => "mock", "delay" => 100}
        ]
      }
      
      context = mock_context()
      start_time = System.monotonic_time(:millisecond)
      {:ok, _result} = Pipeline.Step.Loop.execute(step, context)
      end_time = System.monotonic_time(:millisecond)
      
      # Should take ~300ms (3 batches × 100ms) instead of 500ms (5 × 100ms)
      assert (end_time - start_time) < 400
    end
  end
end
```

### Component Examples (`examples/loops/`)

#### Basic For Loop (`examples/loops/basic_for_loop.yaml`)
```yaml
workflow:
  name: "basic_for_loop_example"
  description: "Demonstrate basic for loop functionality"
  
  steps:
    - name: "setup_data"
      type: "set_variable"
      variables:
        files_to_process: 
          - "app.ex"
          - "config.exs" 
          - "test_helper.exs"
    
    - name: "process_files"
      type: "for_loop"
      iterator: "file"
      data_source: "{{state.files_to_process}}"
      steps:
        - name: "analyze_file"
          type: "claude"
          prompt: |
            Analyze the file: {{loop.file}}
            
            Provide a brief summary of what this file likely contains
            based on its name and extension.
          expected_output: "analysis"
```

#### While Loop with Condition (`examples/loops/while_loop_condition.yaml`)
```yaml
workflow:
  name: "while_loop_condition_example"
  description: "Demonstrate while loop with dynamic conditions"
  
  steps:
    - name: "initialize_counter"
      type: "set_variable"
      variables:
        attempt_count: 0
        success: false
        max_attempts: 3
    
    - name: "retry_until_success"
      type: "while_loop"
      condition: "state.success == false and state.attempt_count < state.max_attempts"
      max_iterations: 5
      steps:
        - name: "increment_attempt"
          type: "set_variable"
          variables:
            attempt_count: "{{state.attempt_count + 1}}"
        
        - name: "attempt_operation"
          type: "claude"
          prompt: |
            Attempt #{{state.attempt_count}}: Simulate a task that might fail.
            
            Return JSON with "success": true/false and "message": "explanation"
          expected_output: "json"
        
        - name: "update_success_status"
          type: "set_variable"
          condition: "previous_response.success == true"
          variables:
            success: true
```

#### Nested Loops (`examples/loops/nested_loops.yaml`)
```yaml
workflow:
  name: "nested_loops_example"
  description: "Demonstrate nested loop processing with real data"
  
  steps:
    - name: "setup_project_structure"
      type: "set_variable"
      variables:
        project_directories:
          - name: "lib"
            files: ["user.ex", "repo.ex", "auth.ex"]
          - name: "test"
            files: ["user_test.exs", "repo_test.exs"]
          - name: "config"
            files: ["config.exs", "dev.exs", "prod.exs"]
    
    - name: "analyze_project"
      type: "for_loop"
      iterator: "directory"
      data_source: "{{state.project_directories}}"
      steps:
        - name: "analyze_directory_files"
          type: "for_loop"
          iterator: "file"
          data_source: "{{loop.directory.files}}"
          steps:
            - name: "file_analysis"
              type: "claude"
              prompt: |
                Analyze file: {{loop.parent.directory.name}}/{{loop.file}}
                
                Directory context: {{loop.parent.directory.name}}
                File: {{loop.file}}
                
                Provide analysis considering the directory structure.
              expected_output: "analysis"
```

#### Parallel Processing (`examples/loops/parallel_processing.yaml`)
```yaml
workflow:
  name: "parallel_processing_example"
  description: "Demonstrate parallel loop execution for performance"
  
  steps:
    - name: "setup_large_dataset"
      type: "set_variable"
      variables:
        large_file_list: [
          "data_2023_01.csv", "data_2023_02.csv", "data_2023_03.csv",
          "data_2023_04.csv", "data_2023_05.csv", "data_2023_06.csv",
          "data_2023_07.csv", "data_2023_08.csv", "data_2023_09.csv"
        ]
    
    - name: "parallel_file_processing"
      type: "for_loop"
      iterator: "file"
      data_source: "{{state.large_file_list}}"
      parallel: true
      max_parallel: 3
      steps:
        - name: "process_large_file"
          type: "claude"
          prompt: |
            Process large data file: {{loop.file}}
            
            Simulate analysis of a large CSV file.
            Return summary statistics and key insights.
          expected_output: "processing_summary"
```

### Performance Tests (`test/performance/loop_performance_test.exs`)

```elixir
defmodule Pipeline.Performance.LoopTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  @tag :performance
  test "for_loop handles large datasets efficiently" do
    large_dataset = 1..1000 |> Enum.to_list()
    
    step = %{
      "type" => "for_loop",
      "iterator" => "item",
      "data_source" => large_dataset,
      "steps" => [%{"name" => "process", "type" => "mock", "response" => "{{loop.item}}"}]
    }
    
    {time_microseconds, {:ok, result}} = :timer.tc(fn ->
      Pipeline.Step.Loop.execute(step, mock_context())
    end)
    
    # Should process 1000 items in under 1 second
    assert time_microseconds < 1_000_000
    assert length(result["results"]) == 1000
    
    # Memory usage should be reasonable
    memory_after = :erlang.memory(:total)
    assert memory_after < 100_000_000  # Less than 100MB
  end
  
  @tag :performance
  test "parallel loops scale efficiently" do
    dataset = 1..100 |> Enum.to_list()
    
    # Sequential execution
    sequential_step = %{
      "type" => "for_loop",
      "iterator" => "item",
      "data_source" => dataset,
      "parallel" => false,
      "steps" => [%{"name" => "process", "type" => "mock", "delay" => 10}]
    }
    
    {sequential_time, _} = :timer.tc(fn ->
      Pipeline.Step.Loop.execute(sequential_step, mock_context())
    end)
    
    # Parallel execution
    parallel_step = Map.put(sequential_step, "parallel", true)
                   |> Map.put("max_parallel", 10)
    
    {parallel_time, _} = :timer.tc(fn ->
      Pipeline.Step.Loop.execute(parallel_step, mock_context())
    end)
    
    # Parallel should be significantly faster
    speedup_ratio = sequential_time / parallel_time
    assert speedup_ratio > 3.0  # At least 3x speedup
  end
end
```

## 🧠 2. Complex Conditions Testing Strategy

### Unit Tests (`test/pipeline/condition/engine_test.exs`)

```elixir
defmodule Pipeline.Condition.EngineTest do
  use ExUnit.Case
  
  describe "boolean logic" do
    test "evaluates AND conditions correctly" do
      condition = %{
        "and" => [
          "step1.score > 5",
          "step2.status == 'passed'"
        ]
      }
      
      context = %{
        "step1" => %{"score" => 7},
        "step2" => %{"status" => "passed"}
      }
      
      assert Pipeline.Condition.Engine.evaluate(condition, context) == true
      
      # Test with failing condition
      failing_context = put_in(context, ["step2", "status"], "failed")
      assert Pipeline.Condition.Engine.evaluate(condition, failing_context) == false
    end
    
    test "evaluates OR conditions correctly" do
      condition = %{
        "or" => [
          "step1.score > 10",
          "step1.fallback == true"
        ]
      }
      
      context = %{"step1" => %{"score" => 3, "fallback" => true}}
      assert Pipeline.Condition.Engine.evaluate(condition, context) == true
    end
    
    test "evaluates NOT conditions correctly" do
      condition = %{"not" => "step1.has_errors == true"}
      
      context = %{"step1" => %{"has_errors" => false}}
      assert Pipeline.Condition.Engine.evaluate(condition, context) == true
    end
    
    test "evaluates nested boolean expressions" do
      condition = %{
        "and" => [
          %{
            "or" => [
              "step1.score > 8",
              "step1.confidence > 0.9"
            ]
          },
          %{"not" => "step2.has_errors == true"}
        ]
      }
      
      context = %{
        "step1" => %{"score" => 6, "confidence" => 0.95},
        "step2" => %{"has_errors" => false}
      }
      
      assert Pipeline.Condition.Engine.evaluate(condition, context) == true
    end
  end
  
  describe "comparison operators" do
    test "supports all comparison operators" do
      context = %{
        "step1" => %{
          "score" => 7.5,
          "status" => "passed",
          "tags" => ["important", "review"],
          "filename" => "user_controller.ex"
        }
      }
      
      # Numeric comparisons
      assert evaluate_condition("step1.score > 7", context) == true
      assert evaluate_condition("step1.score < 8", context) == true
      assert evaluate_condition("step1.score >= 7.5", context) == true
      assert evaluate_condition("step1.score <= 7.5", context) == true
      assert evaluate_condition("step1.score == 7.5", context) == true
      assert evaluate_condition("step1.score != 8", context) == true
      
      # String comparisons
      assert evaluate_condition("step1.status == 'passed'", context) == true
      assert evaluate_condition("step1.status != 'failed'", context) == true
      
      # Contains operator
      assert evaluate_condition("step1.tags contains 'important'", context) == true
      assert evaluate_condition("step1.tags contains 'urgent'", context) == false
      
      # Pattern matching
      assert evaluate_condition("step1.filename matches '.*\\.ex$'", context) == true
      assert evaluate_condition("step1.filename matches '.*\\.js$'", context) == false
    end
    
    test "supports mathematical expressions" do
      context = %{
        "step1" => %{"score" => 8, "weight" => 0.7, "threshold" => 5}
      }
      
      assert evaluate_condition("step1.score * step1.weight > step1.threshold", context) == true
      assert evaluate_condition("(step1.score + 2) / 2 > 4", context) == true
    end
    
    test "supports array functions" do
      context = %{
        "step1" => %{
          "issues" => [
            %{"severity" => "high", "count" => 3},
            %{"severity" => "medium", "count" => 5},
            %{"severity" => "low", "count" => 2}
          ]
        }
      }
      
      assert evaluate_condition("length(step1.issues) == 3", context) == true
      assert evaluate_condition("any(step1.issues, 'severity == \"high\"')", context) == true
      assert evaluate_condition("all(step1.issues, 'count > 0')", context) == true
      assert evaluate_condition("sum(step1.issues, 'count') == 10", context) == true
    end
  end
  
  defp evaluate_condition(expr, context) do
    Pipeline.Condition.Engine.evaluate(expr, context)
  end
end
```

### Component Examples (`examples/conditions/`)

#### Basic Conditions (`examples/conditions/basic_conditions.yaml`)
```yaml
workflow:
  name: "basic_conditions_example"
  description: "Demonstrate basic conditional execution"
  
  steps:
    - name: "analyze_code"
      type: "claude"
      prompt: |
        Analyze this code and return JSON with:
        - score (0-10)
        - status ("passed", "warning", "failed")
        - issues (array of issue objects)
      expected_output: "json"
    
    - name: "high_score_celebration"
      type: "claude"
      condition: "analyze_code.score >= 8"
      prompt: "Great job! The code scored {{analyze_code.score}}/10. Provide encouragement."
    
    - name: "improvement_suggestions"
      type: "claude"
      condition: "analyze_code.score < 6"
      prompt: |
        The code needs improvement (score: {{analyze_code.score}}/10).
        Provide specific suggestions based on the issues found.
    
    - name: "warning_review"
      type: "claude"
      condition: "analyze_code.status == 'warning'"
      prompt: "Review these warnings and decide if they need immediate attention."
```

#### Complex Boolean Logic (`examples/conditions/complex_boolean.yaml`)
```yaml
workflow:
  name: "complex_boolean_example"
  description: "Demonstrate complex boolean expressions"
  
  steps:
    - name: "comprehensive_analysis"
      type: "claude"
      prompt: |
        Perform comprehensive code analysis returning JSON with:
        - score: number (0-10)
        - confidence: number (0-1)
        - status: string
        - issues: array with severity levels
        - performance_score: number (0-10)
      expected_output: "json"
    
    - name: "deploy_ready_check"
      type: "claude"
      condition:
        and:
          - or:
            - "comprehensive_analysis.score > 8"
            - and:
              - "comprehensive_analysis.score > 6"
              - "comprehensive_analysis.confidence > 0.8"
          - not: "comprehensive_analysis.status == 'failed'"
          - "any(comprehensive_analysis.issues, 'severity == \"critical\"') == false"
      prompt: |
        Code passes deployment criteria:
        - Score: {{comprehensive_analysis.score}}/10
        - Confidence: {{comprehensive_analysis.confidence}}
        - No critical issues found
        
        Proceed with deployment preparation.
    
    - name: "performance_optimization_needed"
      type: "claude"
      condition:
        and:
          - "comprehensive_analysis.performance_score < 7"
          - "comprehensive_analysis.score > 6"
      prompt: |
        Code quality is acceptable but performance needs work.
        Performance score: {{comprehensive_analysis.performance_score}}/10
        
        Suggest performance optimizations.
```

#### Mathematical Expressions (`examples/conditions/mathematical_expressions.yaml`)
```yaml
workflow:
  name: "mathematical_expressions_example"
  description: "Demonstrate mathematical expressions in conditions"
  
  steps:
    - name: "metrics_collection"
      type: "claude"
      prompt: |
        Collect project metrics and return JSON:
        - lines_of_code: number
        - test_coverage: number (0-100)
        - complexity_score: number (1-10)
        - technical_debt_hours: number
      expected_output: "json"
    
    - name: "calculate_quality_index"
      type: "set_variable"
      variables:
        quality_index: "{{(metrics_collection.test_coverage * 0.4) + ((11 - metrics_collection.complexity_score) * 10 * 0.6)}}"
        debt_ratio: "{{metrics_collection.technical_debt_hours / (metrics_collection.lines_of_code / 1000)}}"
    
    - name: "excellent_quality"
      type: "claude"
      condition: "state.quality_index > 80 and state.debt_ratio < 5"
      prompt: |
        Excellent code quality detected!
        Quality Index: {{state.quality_index}}
        Debt Ratio: {{state.debt_ratio}}
        
        This project is in excellent shape.
    
    - name: "needs_refactoring"
      type: "claude"
      condition: "state.quality_index < 50 or state.debt_ratio > 15"
      prompt: |
        Code quality concerns identified:
        Quality Index: {{state.quality_index}} (target: >70)
        Debt Ratio: {{state.debt_ratio}} (target: <10)
        
        Recommend immediate refactoring priorities.
```

## 📁 3. File Operations Testing Strategy

### Unit Tests (`test/pipeline/step/file_ops_test.exs`)

```elixir
defmodule Pipeline.Step.FileOpsTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  setup do
    workspace = create_test_workspace()
    on_exit(fn -> cleanup_test_workspace(workspace) end)
    {:ok, workspace: workspace}
  end
  
  describe "copy operations" do
    test "copies file successfully", %{workspace: workspace} do
      source_path = Path.join(workspace, "source.txt")
      dest_path = Path.join(workspace, "dest.txt")
      File.write!(source_path, "test content")
      
      step = %{
        "type" => "file_ops",
        "operation" => "copy",
        "source" => "source.txt",
        "destination" => "dest.txt"
      }
      
      context = mock_context(workspace_dir: workspace)
      {:ok, result} = Pipeline.Step.FileOps.execute(step, context)
      
      assert File.exists?(dest_path)
      assert File.read!(dest_path) == "test content"
      assert result["operation"] == "copy"
      assert result["files_processed"] == 1
    end
    
    test "handles missing source file gracefully", %{workspace: workspace} do
      step = %{
        "type" => "file_ops",
        "operation" => "copy", 
        "source" => "nonexistent.txt",
        "destination" => "dest.txt"
      }
      
      context = mock_context(workspace_dir: workspace)
      {:error, reason} = Pipeline.Step.FileOps.execute(step, context)
      
      assert reason =~ "Source file not found"
    end
  end
  
  describe "validation operations" do
    test "validates file requirements", %{workspace: workspace} do
      File.write!(Path.join(workspace, "small.txt"), "small")
      File.write!(Path.join(workspace, "large.txt"), String.duplicate("x", 1000))
      File.mkdir!(Path.join(workspace, "testdir"))
      
      step = %{
        "type" => "file_ops",
        "operation" => "validate",
        "files" => [
          %{"path" => "small.txt", "must_exist" => true, "max_size" => 100},
          %{"path" => "large.txt", "must_exist" => true, "min_size" => 500},
          %{"path" => "testdir", "must_be_dir" => true}
        ]
      }
      
      context = mock_context(workspace_dir: workspace)
      {:ok, result} = Pipeline.Step.FileOps.execute(step, context)
      
      assert result["validation_passed"] == true
      assert length(result["validated_files"]) == 3
    end
  end
  
  describe "format conversion" do
    test "converts CSV to JSON", %{workspace: workspace} do
      csv_content = "name,age,city\nJohn,30,NYC\nJane,25,LA"
      csv_path = Path.join(workspace, "data.csv")
      json_path = Path.join(workspace, "data.json")
      File.write!(csv_path, csv_content)
      
      step = %{
        "type" => "file_ops",
        "operation" => "convert",
        "source" => "data.csv",
        "destination" => "data.json",
        "format" => "csv_to_json"
      }
      
      context = mock_context(workspace_dir: workspace)
      {:ok, result} = Pipeline.Step.FileOps.execute(step, context)
      
      assert File.exists?(json_path)
      json_data = File.read!(json_path) |> Jason.decode!()
      assert length(json_data) == 2
      assert hd(json_data)["name"] == "John"
    end
  end
end
```

### Component Examples (`examples/file_ops/`)

#### Basic File Operations (`examples/file_ops/basic_operations.yaml`)
```yaml
workflow:
  name: "basic_file_operations_example"
  description: "Demonstrate basic file operations"
  
  steps:
    - name: "create_test_files"
      type: "claude"
      tools: ["write"]
      prompt: |
        Create three test files:
        1. config.yaml with basic configuration
        2. data.csv with sample data
        3. README.md with project description
        
        Use realistic content for each file type.
    
    - name: "organize_files"
      type: "file_ops"
      operation: "copy"
      files:
        - source: "config.yaml"
          destination: "config/app.yaml"
        - source: "data.csv"
          destination: "data/sample.csv"
        - source: "README.md"
          destination: "docs/README.md"
    
    - name: "validate_structure"
      type: "file_ops"
      operation: "validate"
      files:
        - path: "config/"
          must_be_dir: true
        - path: "config/app.yaml"
          must_exist: true
          min_size: 50
        - path: "data/"
          must_be_dir: true
        - path: "data/sample.csv"
          must_exist: true
        - path: "docs/"
          must_be_dir: true
        - path: "docs/README.md"
          must_exist: true
          min_size: 100
```

#### File Format Conversions (`examples/file_ops/format_conversions.yaml`)
```yaml
workflow:
  name: "format_conversions_example"
  description: "Demonstrate file format conversions"
  
  steps:
    - name: "create_sample_data"
      type: "claude"
      tools: ["write"]
      prompt: |
        Create a CSV file named "users.csv" with the following structure:
        - Headers: id, name, email, age, department
        - Include 10 sample users with realistic data
        
        Also create a YAML configuration file "settings.yaml" with:
        - database settings
        - api configuration
        - feature flags
    
    - name: "convert_csv_to_json"
      type: "file_ops"
      operation: "convert"
      source: "users.csv"
      destination: "users.json"
      format: "csv_to_json"
    
    - name: "convert_yaml_to_json"
      type: "file_ops"
      operation: "convert"
      source: "settings.yaml"
      destination: "settings.json"
      format: "yaml_to_json"
    
    - name: "create_xml_version"
      type: "file_ops"
      operation: "convert"
      source: "users.json"
      destination: "users.xml"
      format: "json_to_xml"
      xml_root: "users"
      xml_item: "user"
    
    - name: "validate_conversions"
      type: "file_ops"
      operation: "validate"
      files:
        - path: "users.json"
          must_exist: true
          format: "json"
        - path: "settings.json"
          must_exist: true
          format: "json"
        - path: "users.xml"
          must_exist: true
          format: "xml"
```

#### Workspace Management (`examples/file_ops/workspace_management.yaml`)
```yaml
workflow:
  name: "workspace_management_example"
  description: "Demonstrate comprehensive workspace management"
  
  steps:
    - name: "setup_project_structure"
      type: "file_ops"
      operation: "create_directories"
      directories:
        - "src/components"
        - "src/utils"
        - "test/unit"
        - "test/integration"
        - "docs/api"
        - "config/environments"
        - "data/samples"
        - "output/reports"
    
    - name: "create_template_files"
      type: "claude"
      tools: ["write"]
      prompt: |
        Create template files for a typical project:
        1. src/components/Component.template - React component template
        2. src/utils/utility.template - Utility function template
        3. test/unit/test.template - Unit test template
        4. config/environments/env.template - Environment config template
        
        Make them realistic and useful templates.
    
    - name: "duplicate_templates"
      type: "for_loop"
      iterator: "component"
      data_source: ["Header", "Footer", "Navigation", "Sidebar"]
      steps:
        - name: "create_component"
          type: "file_ops"
          operation: "copy"
          source: "src/components/Component.template"
          destination: "src/components/{{loop.component}}.jsx"
          
        - name: "create_component_test"
          type: "file_ops"
          operation: "copy"
          source: "test/unit/test.template"
          destination: "test/unit/{{loop.component}}.test.js"
    
    - name: "cleanup_templates"
      type: "file_ops"
      operation: "delete"
      files:
        - "src/components/Component.template"
        - "src/utils/utility.template"
        - "test/unit/test.template"
        - "config/environments/env.template"
    
    - name: "generate_project_report"
      type: "file_ops"
      operation: "list"
      path: "."
      recursive: true
      include_stats: true
      output_file: "output/reports/project_structure.json"
```

## 🔄 4. Data Transformation Testing Strategy

### Unit Tests (`test/pipeline/step/data_transform_test.exs`)

```elixir
defmodule Pipeline.Step.DataTransformTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  describe "filter operations" do
    test "filters array elements by condition" do
      data = [
        %{"name" => "Alice", "score" => 85, "department" => "engineering"},
        %{"name" => "Bob", "score" => 72, "department" => "marketing"},
        %{"name" => "Carol", "score" => 91, "department" => "engineering"}
      ]
      
      step = %{
        "type" => "data_transform",
        "input_data" => data,
        "operations" => [
          %{"operation" => "filter", "condition" => "score > 80"}
        ]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.DataTransform.execute(step, context)
      
      assert length(result["transformed_data"]) == 2
      assert Enum.all?(result["transformed_data"], fn item -> item["score"] > 80 end)
    end
    
    test "filters with complex conditions" do
      data = [
        %{"name" => "Alice", "score" => 85, "department" => "engineering", "active" => true},
        %{"name" => "Bob", "score" => 92, "department" => "marketing", "active" => false},
        %{"name" => "Carol", "score" => 78, "department" => "engineering", "active" => true}
      ]
      
      step = %{
        "type" => "data_transform",
        "input_data" => data,
        "operations" => [
          %{
            "operation" => "filter",
            "condition" => "department == 'engineering' and active == true"
          }
        ]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.DataTransform.execute(step, context)
      
      assert length(result["transformed_data"]) == 2
      assert Enum.all?(result["transformed_data"], fn item -> 
        item["department"] == "engineering" and item["active"] == true
      end)
    end
  end
  
  describe "aggregation operations" do
    test "calculates aggregations correctly" do
      data = [
        %{"department" => "engineering", "salary" => 90000, "years" => 3},
        %{"department" => "engineering", "salary" => 95000, "years" => 5},
        %{"department" => "marketing", "salary" => 75000, "years" => 2},
        %{"department" => "marketing", "salary" => 80000, "years" => 4}
      ]
      
      step = %{
        "type" => "data_transform",
        "input_data" => data,
        "operations" => [
          %{"operation" => "group_by", "field" => "department"},
          %{"operation" => "aggregate", "function" => "average", "field" => "salary"}
        ]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.DataTransform.execute(step, context)
      
      engineering_avg = result["transformed_data"]["engineering"]["salary_average"]
      marketing_avg = result["transformed_data"]["marketing"]["salary_average"]
      
      assert engineering_avg == 92500.0
      assert marketing_avg == 77500.0
    end
  end
  
  describe "join operations" do
    test "joins data on specified keys" do
      users = [
        %{"id" => 1, "name" => "Alice"},
        %{"id" => 2, "name" => "Bob"}
      ]
      
      scores = [
        %{"user_id" => 1, "score" => 85},
        %{"user_id" => 2, "score" => 92}
      ]
      
      step = %{
        "type" => "data_transform",
        "input_data" => users,
        "operations" => [
          %{
            "operation" => "join",
            "right_data" => scores,
            "left_key" => "id",
            "right_key" => "user_id",
            "join_type" => "inner"
          }
        ]
      }
      
      context = mock_context()
      {:ok, result} = Pipeline.Step.DataTransform.execute(step, context)
      
      assert length(result["transformed_data"]) == 2
      
      alice_record = Enum.find(result["transformed_data"], fn r -> r["name"] == "Alice" end)
      assert alice_record["score"] == 85
    end
  end
end
```

### Component Examples (`examples/data_transform/`)

#### Basic Transformations (`examples/data_transform/basic_transformations.yaml`)
```yaml
workflow:
  name: "basic_transformations_example"
  description: "Demonstrate basic data transformation operations"
  
  steps:
    - name: "create_sample_data"
      type: "set_variable"
      variables:
        employee_data:
          - id: 1
            name: "Alice Johnson"
            department: "Engineering"
            salary: 90000
            years_experience: 5
            performance_rating: 4.2
            active: true
          - id: 2
            name: "Bob Smith"
            department: "Marketing"
            salary: 75000
            years_experience: 3
            performance_rating: 3.8
            active: true
          - id: 3
            name: "Carol Williams"
            department: "Engineering"
            salary: 95000
            years_experience: 7
            performance_rating: 4.5
            active: false
          - id: 4
            name: "David Brown"
            department: "Sales"
            salary: 80000
            years_experience: 4
            performance_rating: 4.0
            active: true
    
    - name: "filter_active_employees"
      type: "data_transform"
      input_source: "state.employee_data"
      operations:
        - operation: "filter"
          condition: "active == true"
      output_field: "active_employees"
    
    - name: "filter_high_performers"
      type: "data_transform"
      input_source: "active_employees"
      operations:
        - operation: "filter"
          condition: "performance_rating >= 4.0"
      output_field: "high_performers"
    
    - name: "calculate_department_stats"
      type: "data_transform"
      input_source: "active_employees"
      operations:
        - operation: "group_by"
          field: "department"
        - operation: "aggregate"
          functions:
            - field: "salary"
              function: "average"
            - field: "salary"
              function: "sum"
            - field: "performance_rating"
              function: "average"
            - field: "id"
              function: "count"
      output_field: "department_statistics"
    
    - name: "create_summary_report"
      type: "data_transform"
      input_source: "department_statistics"
      operations:
        - operation: "transform"
          expression: |
            {
              "department": department,
              "employee_count": id_count,
              "average_salary": salary_average,
              "total_payroll": salary_sum,
              "average_performance": performance_rating_average,
              "budget_per_employee": salary_sum / id_count
            }
      output_field: "summary_report"
```

#### Complex Data Processing (`examples/data_transform/complex_processing.yaml`)
```yaml
workflow:
  name: "complex_data_processing_example"
  description: "Demonstrate complex data processing pipeline"
  
  steps:
    - name: "load_sales_data"
      type: "set_variable"
      variables:
        sales_transactions:
          - transaction_id: "T001"
            customer_id: "C001"
            product_id: "P001"
            quantity: 2
            unit_price: 50.00
            transaction_date: "2024-01-15"
            region: "North"
          - transaction_id: "T002"
            customer_id: "C002"
            product_id: "P002"
            quantity: 1
            unit_price: 150.00
            transaction_date: "2024-01-16"
            region: "South"
          - transaction_id: "T003"
            customer_id: "C001"
            product_id: "P001"
            quantity: 3
            unit_price: 50.00
            transaction_date: "2024-01-17"
            region: "North"
    
    - name: "load_customer_data"
      type: "set_variable"
      variables:
        customers:
          - customer_id: "C001"
            name: "Acme Corp"
            tier: "Premium"
            discount_rate: 0.1
          - customer_id: "C002"
            name: "Beta LLC"
            tier: "Standard"
            discount_rate: 0.05
    
    - name: "calculate_transaction_totals"
      type: "data_transform"
      input_source: "state.sales_transactions"
      operations:
        - operation: "transform"
          expression: |
            {
              ...item,
              "total_amount": quantity * unit_price,
              "month": transaction_date.substring(0, 7)
            }
      output_field: "enriched_transactions"
    
    - name: "join_customer_information"
      type: "data_transform"
      input_source: "enriched_transactions"
      operations:
        - operation: "join"
          right_source: "state.customers"
          left_key: "customer_id"
          right_key: "customer_id"
          join_type: "left"
      output_field: "transactions_with_customers"
    
    - name: "apply_discounts"
      type: "data_transform"
      input_source: "transactions_with_customers"
      operations:
        - operation: "transform"
          expression: |
            {
              ...item,
              "discounted_amount": total_amount * (1 - discount_rate),
              "discount_applied": total_amount * discount_rate
            }
      output_field: "final_transactions"
    
    - name: "generate_regional_summary"
      type: "data_transform"
      input_source: "final_transactions"
      operations:
        - operation: "group_by"
          field: "region"
        - operation: "aggregate"
          functions:
            - field: "discounted_amount"
              function: "sum"
            - field: "discount_applied"
              function: "sum"
            - field: "transaction_id"
              function: "count"
            - field: "discounted_amount"
              function: "average"
      output_field: "regional_summary"
    
    - name: "generate_customer_summary"
      type: "data_transform"
      input_source: "final_transactions"
      operations:
        - operation: "group_by"
          field: "customer_id"
        - operation: "aggregate"
          functions:
            - field: "discounted_amount"
              function: "sum"
            - field: "transaction_id"
              function: "count"
        - operation: "sort"
          field: "discounted_amount_sum"
          order: "desc"
      output_field: "customer_summary"
```

## 🗂️ 5. Codebase Intelligence Testing Strategy

### Unit Tests (`test/pipeline/codebase/context_test.exs`)

```elixir
defmodule Pipeline.Codebase.ContextTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  setup do
    test_project = create_test_project()
    on_exit(fn -> cleanup_test_project(test_project) end)
    {:ok, project_path: test_project}
  end
  
  describe "project discovery" do
    test "detects Elixir project correctly", %{project_path: path} do
      create_elixir_project_structure(path)
      
      context = Pipeline.Codebase.Context.discover(path)
      
      assert context.project_type == :elixir
      assert context.root_path == path
      assert Map.has_key?(context.structure, :main_files)
      assert Map.has_key?(context.structure, :test_files)
      assert length(context.dependencies) > 0
    end
    
    test "analyzes file structure correctly", %{project_path: path} do
      files = [
        "lib/my_app.ex",
        "lib/my_app/user.ex", 
        "lib/my_app/repo.ex",
        "test/my_app_test.exs",
        "test/my_app/user_test.exs",
        "mix.exs",
        "README.md"
      ]
      
      Enum.each(files, fn file ->
        full_path = Path.join(path, file)
        File.mkdir_p!(Path.dirname(full_path))
        File.write!(full_path, "# #{file}")
      end)
      
      context = Pipeline.Codebase.Context.discover(path)
      
      assert length(context.structure.main_files) == 3
      assert length(context.structure.test_files) == 2
      assert Enum.any?(context.structure.config_files, &String.contains?(&1, "mix.exs"))
    end
    
    test "parses dependencies correctly", %{project_path: path} do
      mix_exs_content = """
      defmodule MyApp.MixProject do
        use Mix.Project
        
        def project do
          [
            app: :my_app,
            version: "0.1.0",
            deps: deps()
          ]
        end
        
        defp deps do
          [
            {:phoenix, "~> 1.7.0"},
            {:ecto, "~> 3.9"},
            {:jason, "~> 1.4"}
          ]
        end
      end
      """
      
      File.write!(Path.join(path, "mix.exs"), mix_exs_content)
      
      context = Pipeline.Codebase.Context.discover(path)
      
      dep_names = Enum.map(context.dependencies, & &1.name)
      assert "phoenix" in dep_names
      assert "ecto" in dep_names
      assert "jason" in dep_names
    end
  end
  
  describe "git integration" do
    test "extracts git information", %{project_path: path} do
      setup_git_repo(path)
      
      context = Pipeline.Codebase.Context.discover(path)
      
      assert context.git_info.is_repo == true
      assert context.git_info.branch != nil
      assert context.git_info.commit != nil
    end
  end
  
  defp create_elixir_project_structure(path) do
    File.write!(Path.join(path, "mix.exs"), basic_mix_exs())
    File.mkdir_p!(Path.join(path, "lib"))
    File.mkdir_p!(Path.join(path, "test"))
  end
  
  defp setup_git_repo(path) do
    System.cmd("git", ["init"], cd: path)
    System.cmd("git", ["config", "user.name", "Test User"], cd: path)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: path)
    File.write!(Path.join(path, "README.md"), "# Test Project")
    System.cmd("git", ["add", "."], cd: path)
    System.cmd("git", ["commit", "-m", "Initial commit"], cd: path)
  end
end
```

### Component Examples (`examples/codebase_intelligence/`)

#### Project Discovery (`examples/codebase_intelligence/project_discovery.yaml`)
```yaml
workflow:
  name: "project_discovery_example"
  description: "Demonstrate automatic project discovery and analysis"
  
  steps:
    - name: "discover_project_type"
      type: "codebase_query"
      codebase_context: true
      queries:
        project_info:
          get_project_type: true
          get_structure: true
          get_dependencies: true
          get_git_info: true
    
    - name: "analyze_project_structure"
      type: "claude"
      codebase_context: true
      prompt: |
        Analyze this {{codebase.project_type}} project:
        
        Project Structure:
        - Main files: {{codebase.structure.main_files}}
        - Test files: {{codebase.structure.test_files}}
        - Config files: {{codebase.structure.config_files}}
        
        Dependencies:
        {{#each codebase.dependencies}}
        - {{name}}: {{version}}
        {{/each}}
        
        Git Information:
        - Branch: {{codebase.git_info.branch}}
        - Last commit: {{codebase.git_info.last_commit}}
        - Status: {{codebase.git_info.status}}
        
        Provide an overview of this project including:
        1. Project type and purpose assessment
        2. Architecture analysis
        3. Dependency health check
        4. Recommendations for improvement
      expected_output: "project_analysis"
    
    - name: "identify_entry_points"
      type: "codebase_query"
      queries:
        entry_points:
          find_files:
            - type: "entry_point"
            - patterns: ["**/application.ex", "**/router.ex", "**/*_web.ex", "**/main.*"]
        
        important_modules:
          find_files:
            - type: "module"
            - exclude_tests: true
            - min_size: 500
            - sort_by: "size"
            - limit: 10
    
    - name: "analyze_entry_points"
      type: "claude"
      prompt: |
        Analyze the key entry points and important modules:
        
        Entry Points Found:
        {{previous_response.entry_points}}
        
        Important Modules:
        {{previous_response.important_modules}}
        
        For each entry point and important module:
        1. Describe its likely purpose
        2. Identify dependencies and relationships
        3. Assess complexity and maintainability
        4. Suggest any improvements
      expected_output: "entry_point_analysis"
```

#### Code Relationship Analysis (`examples/codebase_intelligence/relationship_analysis.yaml`)
```yaml
workflow:
  name: "code_relationship_analysis_example"
  description: "Demonstrate code relationship and dependency analysis"
  
  steps:
    - name: "find_core_modules"
      type: "codebase_query"
      queries:
        core_modules:
          find_files:
            - type: "source"
            - patterns: ["lib/**/*.ex"]
            - exclude_tests: true
            - min_size: 200
    
    - name: "analyze_module_relationships"
      type: "for_loop"
      iterator: "module"
      data_source: "previous_response.core_modules"
      max_iterations: 5  # Limit for example
      steps:
        - name: "find_dependencies"
          type: "codebase_query"
          queries:
            dependencies:
              find_dependencies:
                - for_file: "{{loop.module.path}}"
                - include_internal: true
                - include_external: false
            
            dependents:
              find_dependents:
                - of_file: "{{loop.module.path}}"
                - include_tests: true
        
        - name: "analyze_module_impact"
          type: "claude"
          prompt: |
            Analyze module: {{loop.module.path}}
            
            This module depends on:
            {{previous_response.dependencies}}
            
            This module is used by:
            {{previous_response.dependents}}
            
            Module size: {{loop.module.size}} bytes
            Last modified: {{loop.module.modified}}
            
            Assess:
            1. Module responsibility and cohesion
            2. Coupling level (high/medium/low)
            3. Impact level if this module changes
            4. Refactoring recommendations
          expected_output: "module_analysis"
    
    - name: "find_test_coverage_gaps"
      type: "codebase_query"
      queries:
        source_files:
          find_files:
            - type: "source"
            - exclude_tests: true
        
        test_files:
          find_files:
            - type: "test"
    
    - name: "identify_untested_modules"
      type: "data_transform"
      input_source: "previous_response.source_files"
      operations:
        - operation: "filter"
          condition: "!has_corresponding_test(path, test_files)"
      output_field: "untested_modules"
    
    - name: "generate_testing_recommendations"
      type: "claude"
      condition: "length(untested_modules) > 0"
      prompt: |
        Found modules without corresponding tests:
        {{untested_modules}}
        
        For each untested module:
        1. Assess testing priority (high/medium/low)
        2. Suggest test scenarios to cover
        3. Identify dependencies that need mocking
        4. Provide test structure recommendations
      expected_output: "testing_recommendations"
```

#### Intelligent Code Search (`examples/codebase_intelligence/intelligent_search.yaml`)
```yaml
workflow:
  name: "intelligent_code_search_example"
  description: "Demonstrate intelligent code search and analysis"
  
  steps:
    - name: "search_for_patterns"
      type: "codebase_query"
      queries:
        database_operations:
          find_code:
            - patterns: ["Repo\\.", "Ecto\\.Query", "from\\(", "select\\("]
            - file_types: [".ex"]
        
        api_endpoints:
          find_code:
            - patterns: ["def.*\\(conn", "get\\s+\"/", "post\\s+\"/", "Router\\."]
            - file_types: [".ex"]
        
        error_handling:
          find_code:
            - patterns: [":error", "catch", "rescue", "raise"]
            - file_types: [".ex"]
        
        configuration_usage:
          find_code:
            - patterns: ["Application\\.get_env", "config\\(", "System\\.get_env"]
            - file_types: [".ex"]
    
    - name: "analyze_database_usage"
      type: "claude"
      condition: "length(previous_response.database_operations) > 0"
      prompt: |
        Found database operations in these locations:
        {{previous_response.database_operations}}
        
        Analyze the database usage patterns:
        1. Identify query complexity and performance concerns
        2. Check for N+1 query problems
        3. Verify proper error handling
        4. Suggest optimizations
      expected_output: "database_analysis"
    
    - name: "analyze_api_design"
      type: "claude"
      condition: "length(previous_response.api_endpoints) > 0"
      prompt: |
        Found API endpoints in these locations:
        {{previous_response.api_endpoints}}
        
        Analyze the API design:
        1. REST compliance and consistency
        2. Input validation and sanitization
        3. Authentication and authorization patterns
        4. Response format consistency
        5. Error handling and status codes
      expected_output: "api_analysis"
    
    - name: "analyze_error_handling"
      type: "claude"
      condition: "length(previous_response.error_handling) > 0"
      prompt: |
        Found error handling patterns in these locations:
        {{previous_response.error_handling}}
        
        Analyze error handling consistency:
        1. Error propagation patterns
        2. Logging and monitoring integration
        3. User-friendly error messages
        4. Recovery mechanisms
        5. Recommendations for improvement
      expected_output: "error_handling_analysis"
    
    - name: "find_security_concerns"
      type: "codebase_query"
      queries:
        potential_security_issues:
          find_code:
            - patterns: [
                "String\\.to_atom", 
                "Code\\.eval", 
                "System\\.cmd",
                "File\\.read!",
                "raw\\s*:",
                "unsafe"
              ]
            - file_types: [".ex"]
    
    - name: "security_assessment"
      type: "claude"
      condition: "length(previous_response.potential_security_issues) > 0"
      prompt: |
        Found potential security concerns:
        {{previous_response.potential_security_issues}}
        
        Assess each finding:
        1. Severity level (critical/high/medium/low)
        2. Actual risk vs false positive
        3. Recommended fixes or mitigations
        4. Best practices to prevent similar issues
      expected_output: "security_assessment"
```

## 💾 6. State Management Testing Strategy

### Unit Tests (`test/pipeline/state/variable_engine_test.exs`)

```elixir
defmodule Pipeline.State.VariableEngineTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  describe "variable assignment" do
    test "sets simple variables correctly" do
      variables = %{
        "counter" => 0,
        "name" => "test_pipeline",
        "active" => true
      }
      
      context = mock_context()
      updated_context = Pipeline.State.VariableEngine.set_variables(variables, context)
      
      assert updated_context.state["counter"] == 0
      assert updated_context.state["name"] == "test_pipeline"
      assert updated_context.state["active"] == true
    end
    
    test "supports variable interpolation" do
      initial_context = mock_context()
      |> put_in([:state, "base_count"], 5)
      |> put_in([:state, "multiplier"], 3)
      
      variables = %{
        "total" => "{{state.base_count * state.multiplier}}",
        "message" => "Total is {{state.total}}"
      }
      
      updated_context = Pipeline.State.VariableEngine.set_variables(variables, initial_context)
      
      assert updated_context.state["total"] == 15
      assert updated_context.state["message"] == "Total is 15"
    end
    
    test "handles complex data structures" do
      variables = %{
        "users" => [
          %{"name" => "Alice", "age" => 30},
          %{"name" => "Bob", "age" => 25}
        ],
        "config" => %{
          "database" => %{
            "host" => "localhost",
            "port" => 5432
          }
        }
      }
      
      context = mock_context()
      updated_context = Pipeline.State.VariableEngine.set_variables(variables, context)
      
      assert length(updated_context.state["users"]) == 2
      assert updated_context.state["config"]["database"]["host"] == "localhost"
    end
  end
  
  describe "variable scoping" do
    test "supports loop variable scoping" do
      context = mock_context()
      |> put_in([:state, "global_var"], "global")
      |> put_in([:loop_vars, "item"], "loop_item")
      |> put_in([:loop_vars, "parent", "category"], "parent_category")
      
      # Should resolve loop variables correctly
      assert Pipeline.State.VariableEngine.resolve_variable("state.global_var", context) == "global"
      assert Pipeline.State.VariableEngine.resolve_variable("loop.item", context) == "loop_item"
      assert Pipeline.State.VariableEngine.resolve_variable("loop.parent.category", context) == "parent_category"
    end
    
    test "handles variable precedence correctly" do
      context = mock_context()
      |> put_in([:state, "name"], "global_name")
      |> put_in([:loop_vars, "name"], "loop_name")
      
      # Loop variables should take precedence
      assert Pipeline.State.VariableEngine.resolve_variable("name", context) == "loop_name"
      
      # But explicit state access should work
      assert Pipeline.State.VariableEngine.resolve_variable("state.name", context) == "global_name"
    end
  end
  
  describe "checkpoint integration" do
    test "persists state to checkpoint" do
      context = mock_context()
      |> put_in([:state], %{"counter" => 5, "processed_files" => ["file1.ex", "file2.ex"]})
      
      checkpoint_data = Pipeline.State.VariableEngine.prepare_checkpoint(context)
      
      assert checkpoint_data["state"]["counter"] == 5
      assert length(checkpoint_data["state"]["processed_files"]) == 2
    end
    
    test "restores state from checkpoint" do
      checkpoint_data = %{
        "state" => %{"counter" => 10, "last_step" => "processing"},
        "metadata" => %{"timestamp" => "2024-01-01T12:00:00Z"}
      }
      
      context = Pipeline.State.VariableEngine.restore_from_checkpoint(checkpoint_data, mock_context())
      
      assert context.state["counter"] == 10
      assert context.state["last_step"] == "processing"
    end
  end
end
```

### Component Examples (`examples/state_management/`)

#### Basic State Management (`examples/state_management/basic_state.yaml`)
```yaml
workflow:
  name: "basic_state_management_example"
  description: "Demonstrate basic state management with variables"
  
  steps:
    - name: "initialize_processing_state"
      type: "set_variable"
      variables:
        total_files: 0
        processed_files: []
        errors_encountered: []
        start_time: "{{now()}}"
        processing_status: "initialized"
    
    - name: "setup_file_list"
      type: "set_variable"
      variables:
        files_to_process:
          - "user.ex"
          - "auth.ex"
          - "repo.ex"
          - "config.exs"
          - "router.ex"
        total_files: "{{length(state.files_to_process)}}"
    
    - name: "process_files_with_state_tracking"
      type: "for_loop"
      iterator: "file"
      data_source: "{{state.files_to_process}}"
      steps:
        - name: "update_processing_status"
          type: "set_variable"
          variables:
            processing_status: "processing"
            current_file: "{{loop.file}}"
        
        - name: "simulate_file_processing"
          type: "claude"
          prompt: |
            Process file: {{state.current_file}}
            Progress: {{length(state.processed_files) + 1}} of {{state.total_files}}
            
            Simulate processing this file and return:
            - success: true/false
            - message: processing result
            - issues_found: number of issues
          expected_output: "json"
        
        - name: "update_file_processing_state" 
          type: "set_variable"
          variables:
            processed_files: "{{state.processed_files + [state.current_file]}}"
            errors_encountered: >
              {{previous_response.success ? 
                state.errors_encountered : 
                state.errors_encountered + [state.current_file]}}
    
    - name: "finalize_processing_state"
      type: "set_variable"
      variables:
        processing_status: "completed"
        end_time: "{{now()}}"
        success_rate: "{{(state.total_files - length(state.errors_encountered)) / state.total_files * 100}}"
        processing_duration: "{{state.end_time - state.start_time}}"
    
    - name: "generate_processing_report"
      type: "claude"
      prompt: |
        Generate a processing report:
        
        Processing Summary:
        - Status: {{state.processing_status}}
        - Total files: {{state.total_files}}
        - Successfully processed: {{length(state.processed_files)}}
        - Errors encountered: {{length(state.errors_encountered)}}
        - Success rate: {{state.success_rate}}%
        - Duration: {{state.processing_duration}}
        
        Files processed:
        {{#each state.processed_files}}
        - {{this}}
        {{/each}}
        
        {{#if state.errors_encountered}}
        Files with errors:
        {{#each state.errors_encountered}}
        - {{this}}
        {{/each}}
        {{/if}}
        
        Provide analysis and recommendations.
      expected_output: "processing_report"
```

#### Advanced State with Checkpoints (`examples/state_management/checkpoint_state.yaml`)
```yaml
workflow:
  name: "checkpoint_state_example"
  description: "Demonstrate state management with checkpoint recovery"
  
  steps:
    - name: "initialize_long_running_process"
      type: "set_variable"
      variables:
        batch_size: 3
        current_batch: 0
        total_processed: 0
        failed_items: []
        checkpoint_frequency: 2  # Checkpoint every 2 batches
        
    - name: "setup_large_dataset"
      type: "set_variable"
      variables:
        items_to_process: [
          "item_001", "item_002", "item_003", "item_004", "item_005",
          "item_006", "item_007", "item_008", "item_009", "item_010",
          "item_011", "item_012", "item_013", "item_014", "item_015"
        ]
        total_items: "{{length(state.items_to_process)}}"
        total_batches: "{{ceil(state.total_items / state.batch_size)}}"
    
    - name: "process_in_batches"
      type: "while_loop"
      condition: "state.current_batch < state.total_batches"
      max_iterations: 10
      steps:
        - name: "calculate_batch_bounds"
          type: "set_variable"
          variables:
            batch_start: "{{state.current_batch * state.batch_size}}"
            batch_end: "{{min((state.current_batch + 1) * state.batch_size, state.total_items)}}"
        
        - name: "extract_current_batch"
          type: "data_transform"
          input_source: "state.items_to_process"
          operations:
            - operation: "slice"
              start: "{{state.batch_start}}"
              end: "{{state.batch_end}}"
          output_field: "current_batch_items"
        
        - name: "process_batch_items"
          type: "for_loop"
          iterator: "item"
          data_source: "{{previous_response.current_batch_items}}"
          steps:
            - name: "process_single_item"
              type: "claude"
              prompt: |
                Process item: {{loop.item}}
                Batch: {{state.current_batch + 1}} of {{state.total_batches}}
                Item {{loop.index + 1}} of {{length(current_batch_items)}}
                
                Simulate complex processing and return:
                - success: true/false
                - processing_time: seconds
                - result: processing result
              expected_output: "json"
            
            - name: "update_processing_counters"
              type: "set_variable"
              variables:
                total_processed: "{{state.total_processed + 1}}"
                failed_items: >
                  {{previous_response.success ? 
                    state.failed_items : 
                    state.failed_items + [loop.item]}}
        
        - name: "increment_batch_counter"
          type: "set_variable"
          variables:
            current_batch: "{{state.current_batch + 1}}"
        
        - name: "checkpoint_if_needed"
          type: "checkpoint"
          condition: "state.current_batch % state.checkpoint_frequency == 0"
          state:
            progress_checkpoint: true
            batch_completed: "{{state.current_batch}}"
            items_processed: "{{state.total_processed}}"
            failures: "{{state.failed_items}}"
            checkpoint_time: "{{now()}}"
    
    - name: "final_processing_summary"
      type: "set_variable"
      variables:
        processing_complete: true
        final_success_rate: "{{(state.total_processed - length(state.failed_items)) / state.total_processed * 100}}"
        completion_time: "{{now()}}"
    
    - name: "save_final_checkpoint"
      type: "checkpoint"
      state:
        final_state: true
        total_items: "{{state.total_items}}"
        processed_items: "{{state.total_processed}}"
        failed_items: "{{state.failed_items}}"
        success_rate: "{{state.final_success_rate}}"
        completion_time: "{{state.completion_time}}"
```

## 🚀 Integration Testing Strategy

### Complete Integration Examples (`examples/integration/`)

#### Multi-Feature Workflow (`examples/integration/complete_workflow.yaml`)
```yaml
workflow:
  name: "complete_integration_example"
  description: "Demonstrate all advanced features working together"
  
  steps:
    # 1. Initialize state and discover codebase
    - name: "initialize_analysis_state"
      type: "set_variable"
      variables:
        analysis_start_time: "{{now()}}"
        total_files_analyzed: 0
        high_priority_issues: []
        recommendations: []
        analysis_phase: "initialization"
    
    - name: "discover_project_context"
      type: "codebase_query"
      codebase_context: true
      queries:
        project_overview:
          get_project_type: true
          get_structure: true
          get_dependencies: true
        
        source_files:
          find_files:
            - type: "source"
            - exclude_tests: true
            - min_size: 100
    
    - name: "validate_project_structure"
      type: "file_ops"
      operation: "validate"
      files:
        - path: "lib/"
          must_be_dir: true
        - path: "test/"
          must_be_dir: true
        - path: "mix.exs"
          must_exist: true
          min_size: 200
    
    # 2. Conditional processing based on project size
    - name: "determine_analysis_approach"
      type: "set_variable"
      condition: "length(previous_response.source_files) > 10"
      variables:
        analysis_approach: "comprehensive"
        batch_size: 5
        parallel_processing: true
    
    - name: "determine_analysis_approach_small"
      type: "set_variable"
      condition: "length(discover_project_context.source_files) <= 10"
      variables:
        analysis_approach: "simple"
        batch_size: 3
        parallel_processing: false
    
    # 3. File processing loop with state management
    - name: "analyze_source_files"
      type: "for_loop"
      iterator: "file"
      data_source: "{{discover_project_context.source_files}}"
      parallel: "{{state.parallel_processing}}"
      max_parallel: "{{state.parallel_processing ? 3 : 1}}"
      steps:
        - name: "update_analysis_phase"
          type: "set_variable"
          variables:
            analysis_phase: "analyzing_files"
            current_file: "{{loop.file.path}}"
        
        - name: "analyze_single_file"
          type: "claude"
          output_schema:
            type: "object"
            required: ["file_path", "issues", "complexity_score", "recommendations"]
            properties:
              file_path: {type: "string"}
              issues:
                type: "array"
                items:
                  type: "object"
                  properties:
                    severity: {type: "string", enum: ["low", "medium", "high", "critical"]}
                    type: {type: "string"}
                    message: {type: "string"}
                    line: {type: "number"}
              complexity_score: {type: "number", minimum: 1, maximum: 10}
              recommendations:
                type: "array"
                items: {type: "string"}
          prompt: |
            Analyze this {{codebase.project_type}} file: {{loop.file.path}}
            
            File content:
            {{file:{{loop.file.path}}}}
            
            Project context: {{codebase.project_type}} project with {{length(codebase.dependencies)}} dependencies
            
            Provide comprehensive analysis including:
            1. Code quality issues (return as structured array)
            2. Complexity assessment (1-10 scale)
            3. Specific improvement recommendations
            4. Security concerns if any
            
            Focus on {{state.analysis_approach}} analysis approach.
        
        - name: "update_analysis_state"
          type: "set_variable"
          variables:
            total_files_analyzed: "{{state.total_files_analyzed + 1}}"
            high_priority_issues: >
              {{state.high_priority_issues + 
                filter(previous_response.issues, 'severity in [\"high\", \"critical\"]')}}
            recommendations: "{{state.recommendations + previous_response.recommendations}}"
    
    # 4. Data transformation and aggregation
    - name: "aggregate_analysis_results"
      type: "data_transform"
      input_source: "state.high_priority_issues"
      operations:
        - operation: "group_by"
          field: "severity"
        - operation: "aggregate"
          functions:
            - field: "severity"
              function: "count"
        - operation: "sort"
          field: "count"
          order: "desc"
      output_field: "issue_summary"
    
    - name: "filter_critical_issues"
      type: "data_transform"
      input_source: "state.high_priority_issues"
      operations:
        - operation: "filter"
          condition: "severity == 'critical'"
        - operation: "sort"
          field: "file_path"
      output_field: "critical_issues"
    
    # 5. Conditional remediation based on findings
    - name: "create_remediation_plan"
      type: "claude"
      condition:
        or:
          - "length(critical_issues) > 0"
          - "length(state.high_priority_issues) > 5"
      prompt: |
        Critical issues requiring immediate attention:
        {{critical_issues}}
        
        Total high-priority issues: {{length(state.high_priority_issues)}}
        Issue breakdown: {{issue_summary}}
        
        Create a prioritized remediation plan:
        1. Immediate actions for critical issues
        2. Short-term fixes for high-priority issues
        3. Long-term improvements
        4. Prevention strategies
      expected_output: "remediation_plan"
    
    # 6. Generate comprehensive reports
    - name: "export_analysis_data"
      type: "file_ops"
      operation: "convert"
      source_data: 
        analysis_summary:
          project_type: "{{codebase.project_type}}"
          files_analyzed: "{{state.total_files_analyzed}}"
          total_issues: "{{length(state.high_priority_issues)}}"
          critical_issues: "{{length(critical_issues)}}"
          issue_breakdown: "{{issue_summary}}"
          recommendations_count: "{{length(state.recommendations)}}"
          analysis_duration: "{{now() - state.analysis_start_time}}"
      destination: "analysis_report.json"
      format: "object_to_json"
    
    - name: "create_detailed_report"
      type: "claude"
      condition: "state.total_files_analyzed > 0"
      prompt: |
        Generate a comprehensive analysis report:
        
        ## Project Analysis Summary
        - Project Type: {{codebase.project_type}}
        - Files Analyzed: {{state.total_files_analyzed}}
        - Analysis Duration: {{now() - state.analysis_start_time}}
        - Analysis Approach: {{state.analysis_approach}}
        
        ## Findings Overview
        - Total Issues: {{length(state.high_priority_issues)}}
        - Critical Issues: {{length(critical_issues)}}
        - Issue Distribution: {{issue_summary}}
        
        ## Key Recommendations
        {{#each state.recommendations}}
        - {{this}}
        {{/each}}
        
        {{#if remediation_plan}}
        ## Remediation Plan
        {{remediation_plan}}
        {{/if}}
        
        ## Project Health Assessment
        Based on the analysis results, provide:
        1. Overall project health score (1-10)
        2. Main areas of concern
        3. Strengths of the codebase
        4. Next steps for improvement
      expected_output: "final_report"
    
    # 7. Final state checkpoint
    - name: "finalize_analysis"
      type: "checkpoint"
      state:
        analysis_complete: true
        completion_time: "{{now()}}"
        total_duration: "{{now() - state.analysis_start_time}}"
        files_processed: "{{state.total_files_analyzed}}"
        issues_found: "{{length(state.high_priority_issues)}}"
        success: true
```

## 📊 Performance Testing Strategy

### Load Testing (`test/performance/`)

```elixir
# test/performance/advanced_features_performance_test.exs
defmodule Pipeline.Performance.AdvancedFeaturesTest do
  use ExUnit.Case
  use Pipeline.TestCase
  
  @tag :performance
  @tag timeout: 300_000  # 5 minutes
  test "handles large loop iterations efficiently" do
    large_dataset = 1..1000 |> Enum.to_list()
    
    workflow = %{
      "workflow" => %{
        "name" => "performance_test",
        "steps" => [
          %{
            "name" => "large_loop",
            "type" => "for_loop",
            "iterator" => "item",
            "data_source" => large_dataset,
            "parallel" => True,
            "max_parallel" => 5,
            "steps" => [
              %{
                "name" => "process_item",
                "type" => "mock",
                "response" => "processed {{loop.item}}"
              }
            ]
          }
        ]
      }
    }
    
    {time_microseconds, {:ok, _result}} = :timer.tc(fn ->
      Pipeline.execute(workflow, test_mode: :mock)
    end)
    
    # Should process 1000 items in under 30 seconds
    assert time_microseconds < 30_000_000
    
    # Memory usage should remain reasonable
    memory_usage = :erlang.memory(:total)
    assert memory_usage < 200_000_000  # Less than 200MB
  end
  
  @tag :performance  
  test "complex condition evaluation performance" do
    complex_conditions = [
      %{
        "and" => [
          "step1.score > 5",
          %{
            "or" => [
              "step2.status == 'passed'",
              "step2.fallback == true"
            ]
          },
          %{"not" => "step3.has_errors == true"}
        ]
      }
    ]
    
    context = mock_context_with_data()
    
    # Test 10,000 condition evaluations
    {time_microseconds, _results} = :timer.tc(fn ->
      1..10_000
      |> Enum.map(fn _i ->
        Pipeline.Condition.Engine.evaluate(hd(complex_conditions), context)
      end)
    end)
    
    # Should evaluate 10,000 complex conditions in under 1 second
    assert time_microseconds < 1_000_000
  end
  
  @tag :performance
  test "file operations with large datasets" do
    workspace = create_test_workspace()
    
    # Create 100 files
    large_files = 1..100
    |> Enum.map(fn i ->
      file_path = Path.join(workspace, "file_#{i}.txt")
      File.write!(file_path, String.duplicate("test content ", 1000))
      "file_#{i}.txt"
    end)
    
    workflow = %{
      "workflow" => %{
        "name" => "file_performance_test",
        "steps" => [
          %{
            "name" => "copy_all_files",
            "type" => "for_loop",
            "iterator" => "file",
            "data_source" => large_files,
            "parallel" => true,
            "max_parallel" => 10,
            "steps" => [
              %{
                "name" => "copy_file",
                "type" => "file_ops",
                "operation" => "copy",
                "source" => "{{loop.file}}",
                "destination" => "backup/{{loop.file}}"
              }
            ]
          }
        ]
      }
    }
    
    {time_microseconds, {:ok, _result}} = :timer.tc(fn ->
      Pipeline.execute(workflow, workspace_dir: workspace, test_mode: :mock)
    end)
    
    # Should copy 100 files in under 10 seconds
    assert time_microseconds < 10_000_000
    
    cleanup_test_workspace(workspace)
  end
end
```

## 📋 Testing Checklist

### Feature Completion Matrix

| Feature | Unit Tests | Component Tests | Integration Tests | Examples | Performance Tests | Documentation |
|---------|:----------:|:---------------:|:-----------------:|:--------:|:-----------------:|:-------------:|
| **For Loops** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **While Loops** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Nested Loops** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Parallel Loops** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Boolean AND/OR** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Comparison Ops** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Math Expressions** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Array Functions** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **File Copy/Move** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **File Validation** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Format Conversion** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Schema Validation** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Data Filtering** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Data Aggregation** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Data Joins** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Project Discovery** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Code Queries** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Dependency Analysis** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Variable Assignment** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Variable Interpolation** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **State Checkpoints** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Automated Testing Commands

```bash
# Run all advanced feature tests
mix test test/pipeline/step/loop_test.exs
mix test test/pipeline/condition/engine_test.exs
mix test test/pipeline/step/file_ops_test.exs
mix test test/pipeline/step/data_transform_test.exs
mix test test/pipeline/codebase/context_test.exs
mix test test/pipeline/state/variable_engine_test.exs

# Run integration tests
mix test test/integration/advanced_features_test.exs

# Run performance tests
mix test test/performance/ --include performance

# Run all examples in mock mode
mix pipeline.run examples/loops/basic_for_loop.yaml
mix pipeline.run examples/conditions/basic_conditions.yaml
mix pipeline.run examples/file_ops/basic_operations.yaml
mix pipeline.run examples/data_transform/basic_transformations.yaml
mix pipeline.run examples/codebase_intelligence/project_discovery.yaml
mix pipeline.run examples/state_management/basic_state.yaml
mix pipeline.run examples/integration/complete_workflow.yaml

# Run examples in live mode (requires API keys)
mix pipeline.run.live examples/integration/complete_workflow.yaml
```

## 🎯 Success Criteria

### Functional Requirements
- [ ] All 20+ individual features work correctly in isolation
- [ ] All features integrate seamlessly in complex workflows
- [ ] Performance targets met for large datasets (>1000 items)
- [ ] Memory usage remains under 500MB for any workflow
- [ ] Error handling works gracefully for all failure modes

### Quality Requirements
- [ ] Unit test coverage >95% for all new modules
- [ ] Integration tests cover all feature combinations
- [ ] Performance tests validate scalability
- [ ] All examples run successfully in both mock and live modes
- [ ] Documentation is complete and accurate

### User Experience Requirements
- [ ] YAML syntax remains intuitive and readable
- [ ] Error messages are clear and actionable
- [ ] Mock mode supports all new features for development
- [ ] Live mode works reliably with real AI providers
- [ ] Migration path from basic to advanced features is smooth

---

This comprehensive testing strategy ensures that every advanced feature is thoroughly validated, documented, and production-ready. Each test builds confidence that the pipeline system can handle real-world complexity while maintaining reliability and performance.