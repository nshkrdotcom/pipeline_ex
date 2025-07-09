# DSPy Pipeline Composition Framework

## Overview

This document outlines the architecture for integrating DSPy's optimization capabilities into pipeline_ex through a comprehensive composition framework that maintains the existing YAML-based configuration while adding systematic optimization and evaluation.

## Core Architecture

### 1. **DSPy Signature System**

#### Signature Definition
```elixir
defmodule Pipeline.DSPy.Signature do
  @moduledoc """
  Represents a DSPy signature with Elixir-native configuration.
  
  Signatures define the input/output contract for optimizable steps.
  """
  
  defstruct [
    :name,
    :description,
    :input_fields,
    :output_fields,
    :instructions,
    :examples,
    :optimization_config
  ]
  
  def from_yaml_step(step_config) do
    %__MODULE__{
      name: step_config["name"],
      description: step_config["description"],
      input_fields: extract_input_fields(step_config),
      output_fields: extract_output_fields(step_config),
      instructions: step_config["instructions"],
      examples: step_config["examples"] || [],
      optimization_config: step_config["dspy_config"] || %{}
    }
  end
  
  def to_dspy_signature(signature) do
    # Convert to DSPy signature format
    # This will be implemented as a Python bridge
    %{
      name: signature.name,
      input_fields: format_input_fields(signature.input_fields),
      output_fields: format_output_fields(signature.output_fields),
      docstring: signature.instructions
    }
  end
end
```

#### Enhanced YAML Configuration
```yaml
# Enhanced pipeline with DSPy signatures
workflow:
  name: elixir_code_analyzer
  dspy_config:
    optimization_enabled: true
    evaluation_mode: "bootstrap_few_shot"
    training_size: 50
    validation_size: 20
    
  steps:
    - name: analyze_code_structure
      type: dspy_claude
      description: "Analyze Elixir code structure and identify patterns"
      
      # DSPy signature definition
      signature:
        input_fields:
          - name: source_code
            type: string
            description: "Elixir source code to analyze"
          - name: context
            type: string
            description: "Additional context about the code"
            
        output_fields:
          - name: analysis
            type: object
            description: "Structured analysis of the code"
            schema:
              type: object
              properties:
                complexity: {type: string, enum: [low, medium, high]}
                patterns: {type: array, items: {type: string}}
                recommendations: {type: array, items: {type: string}}
                
        instructions: |
          Analyze the provided Elixir code and identify:
          1. Code complexity level
          2. Design patterns used
          3. Improvement recommendations
          
      # DSPy optimization configuration
      dspy_config:
        optimization_target: "accuracy"
        few_shot_examples: 5
        bootstrap_iterations: 3
        
      # Training examples for optimization
      examples:
        - input:
            source_code: "defmodule Example do\n  def hello, do: :world\nend"
            context: "Simple module definition"
          output:
            analysis:
              complexity: "low"
              patterns: ["module_definition", "simple_function"]
              recommendations: ["Add documentation", "Consider pattern matching"]
```

### 2. **DSPy-Optimized Step Types**

#### Core Step Implementation
```elixir
defmodule Pipeline.Step.DSPyClaude do
  @moduledoc """
  DSPy-optimized Claude step with automatic prompt optimization.
  """
  
  def execute(step, context) do
    signature = Pipeline.DSPy.Signature.from_yaml_step(step)
    
    case should_optimize?(step, context) do
      true ->
        execute_with_optimization(signature, step, context)
      false ->
        execute_traditional(signature, step, context)
    end
  end
  
  defp execute_with_optimization(signature, step, context) do
    # Get optimized prompt from DSPy system
    optimized_prompt = Pipeline.DSPy.Optimizer.get_optimized_prompt(
      signature,
      step["dspy_config"],
      context
    )
    
    # Execute with optimized prompt
    result = Pipeline.Providers.ClaudeProvider.query(
      optimized_prompt,
      build_claude_options(step, context)
    )
    
    # Record performance for future optimization
    Pipeline.DSPy.Metrics.record_execution(signature.name, result, context)
    
    result
  end
  
  defp should_optimize?(step, context) do
    step["dspy_config"]["optimization_enabled"] == true and
    context[:dspy_mode] != :evaluation
  end
end
```

### 3. **Optimization Engine**

#### Core Optimizer
```elixir
defmodule Pipeline.DSPy.Optimizer do
  @moduledoc """
  Manages DSPy optimization for pipeline steps.
  """
  
  def optimize_pipeline(pipeline_config, training_data) do
    # Convert pipeline to DSPy program
    dspy_program = convert_to_dspy_program(pipeline_config)
    
    # Run optimization
    optimization_result = run_dspy_optimization(dspy_program, training_data)
    
    # Convert back to pipeline format
    optimized_pipeline = convert_from_dspy_program(optimization_result)
    
    # Validate improvements
    validate_optimization(pipeline_config, optimized_pipeline)
  end
  
  def get_optimized_prompt(signature, config, context) do
    case lookup_cached_optimization(signature.name, config) do
      {:ok, cached_prompt} ->
        cached_prompt
        
      :not_found ->
        # Generate new optimized prompt
        generate_optimized_prompt(signature, config, context)
    end
  end
  
  defp generate_optimized_prompt(signature, config, context) do
    # Bridge to Python DSPy system
    Pipeline.DSPy.PythonBridge.optimize_prompt(
      signature: signature,
      config: config,
      context: context
    )
  end
end
```

### 4. **Evaluation System**

#### Evaluation Framework
```elixir
defmodule Pipeline.DSPy.Evaluator do
  @moduledoc """
  Systematic evaluation of pipeline performance.
  """
  
  def evaluate_pipeline(pipeline_config, test_cases) do
    results = Enum.map(test_cases, fn test_case ->
      evaluate_single_case(pipeline_config, test_case)
    end)
    
    compile_evaluation_report(results)
  end
  
  def evaluate_single_case(pipeline_config, test_case) do
    # Execute pipeline with test input
    {:ok, result} = Pipeline.execute(pipeline_config, 
      inputs: test_case.input,
      evaluation_mode: true
    )
    
    # Evaluate result against expected output
    score = calculate_score(result, test_case.expected)
    
    %{
      input: test_case.input,
      expected: test_case.expected,
      actual: result,
      score: score,
      metrics: extract_metrics(result)
    }
  end
  
  def run_optimization_cycle(pipeline_config, training_data, validation_data) do
    # Initial evaluation
    baseline_score = evaluate_pipeline(pipeline_config, validation_data)
    
    # Optimize pipeline
    optimized_pipeline = Pipeline.DSPy.Optimizer.optimize_pipeline(
      pipeline_config,
      training_data
    )
    
    # Evaluate optimization
    optimized_score = evaluate_pipeline(optimized_pipeline, validation_data)
    
    # Compare results
    %{
      baseline: baseline_score,
      optimized: optimized_score,
      improvement: calculate_improvement(baseline_score, optimized_score),
      pipeline: optimized_pipeline
    }
  end
end
```

### 5. **Training Data Management**

#### Data Collection System
```elixir
defmodule Pipeline.DSPy.TrainingData do
  @moduledoc """
  Manages training examples for DSPy optimization.
  """
  
  def collect_from_executions(pipeline_name, limit \\ 100) do
    # Collect historical execution data
    Pipeline.DSPy.Metrics.get_execution_history(pipeline_name, limit)
    |> Enum.map(&format_as_training_example/1)
    |> filter_quality_examples()
  end
  
  def validate_training_data(training_examples) do
    Enum.map(training_examples, fn example ->
      %{
        valid: validate_example(example),
        issues: find_issues(example),
        quality_score: calculate_quality_score(example)
      }
    end)
  end
  
  def generate_few_shot_examples(signature, count \\ 5) do
    # Generate diverse examples for few-shot learning
    base_examples = lookup_examples(signature.name)
    
    case length(base_examples) do
      n when n >= count ->
        select_diverse_examples(base_examples, count)
        
      _ ->
        # Generate synthetic examples if needed
        generate_synthetic_examples(signature, count - length(base_examples))
        |> Enum.concat(base_examples)
    end
  end
end
```

### 6. **Python Bridge for DSPy**

#### Bridge Implementation
```elixir
defmodule Pipeline.DSPy.PythonBridge do
  @moduledoc """
  Bridge to Python DSPy system for optimization.
  """
  
  use GenServer
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def optimize_prompt(signature: signature, config: config, context: context) do
    GenServer.call(__MODULE__, {:optimize_prompt, signature, config, context})
  end
  
  def evaluate_program(program, test_cases) do
    GenServer.call(__MODULE__, {:evaluate_program, program, test_cases})
  end
  
  # GenServer implementation
  def init(_) do
    # Initialize Python environment
    python_port = Port.open(
      {:spawn, "python3 -u #{dspy_bridge_script()}"},
      [:binary, :exit_status, line: 1024]
    )
    
    {:ok, %{python_port: python_port}}
  end
  
  def handle_call({:optimize_prompt, signature, config, context}, _from, state) do
    # Send optimization request to Python
    request = %{
      action: "optimize_prompt",
      signature: signature,
      config: config,
      context: context
    }
    
    Port.command(state.python_port, Jason.encode!(request) <> "\n")
    
    # Wait for response
    receive do
      {^python_port, {:data, response}} ->
        {:ok, result} = Jason.decode(response)
        {:reply, result, state}
    after
      30_000 ->
        {:reply, {:error, :timeout}, state}
    end
  end
  
  defp dspy_bridge_script do
    Path.join([__DIR__, "../../../priv/dspy_bridge.py"])
  end
end
```

#### Python DSPy Bridge Script
```python
#!/usr/bin/env python3
# priv/dspy_bridge.py

import sys
import json
import dspy
from typing import Dict, List, Any

class ElixirDSPyBridge:
    def __init__(self):
        # Initialize DSPy with appropriate LM
        self.lm = dspy.OpenAI(model="gpt-4")
        dspy.settings.configure(lm=self.lm)
        
    def optimize_prompt(self, signature_data: Dict, config: Dict, context: Dict) -> Dict:
        """Optimize a prompt using DSPy"""
        
        # Create DSPy signature from Elixir data
        signature_class = self.create_signature_class(signature_data)
        
        # Create DSPy program
        program = dspy.Predict(signature_class)
        
        # Load training examples
        training_examples = self.load_training_examples(config, context)
        
        # Run optimization
        optimizer = self.create_optimizer(config)
        optimized_program = optimizer.compile(program, trainset=training_examples)
        
        # Extract optimized prompt
        optimized_prompt = self.extract_optimized_prompt(optimized_program)
        
        return {
            "success": True,
            "optimized_prompt": optimized_prompt,
            "metrics": self.get_optimization_metrics(optimized_program)
        }
    
    def create_signature_class(self, signature_data: Dict):
        """Create DSPy signature class from Elixir data"""
        
        class_name = signature_data["name"]
        input_fields = signature_data["input_fields"]
        output_fields = signature_data["output_fields"]
        
        # Dynamically create signature class
        class_dict = {}
        
        for field in input_fields:
            class_dict[field["name"]] = dspy.InputField(desc=field["description"])
            
        for field in output_fields:
            class_dict[field["name"]] = dspy.OutputField(desc=field["description"])
            
        return type(class_name, (dspy.Signature,), class_dict)
    
    def run_evaluation(self, program_data: Dict, test_cases: List[Dict]) -> Dict:
        """Run evaluation on test cases"""
        
        # Implementation for evaluation
        pass

def main():
    bridge = ElixirDSPyBridge()
    
    for line in sys.stdin:
        try:
            request = json.loads(line.strip())
            action = request["action"]
            
            if action == "optimize_prompt":
                result = bridge.optimize_prompt(
                    request["signature"],
                    request["config"],
                    request["context"]
                )
            elif action == "evaluate_program":
                result = bridge.run_evaluation(
                    request["program"],
                    request["test_cases"]
                )
            else:
                result = {"success": False, "error": f"Unknown action: {action}"}
                
            print(json.dumps(result))
            sys.stdout.flush()
            
        except Exception as e:
            error_result = {"success": False, "error": str(e)}
            print(json.dumps(error_result))
            sys.stdout.flush()

if __name__ == "__main__":
    main()
```

### 7. **Integration with Existing Pipeline System**

#### Enhanced Executor
```elixir
defmodule Pipeline.DSPy.EnhancedExecutor do
  @moduledoc """
  Enhanced executor with DSPy integration.
  """
  
  def execute(workflow, opts \\ []) do
    # Check if DSPy optimization is enabled
    case should_use_dspy?(workflow, opts) do
      true ->
        execute_with_dspy(workflow, opts)
      false ->
        Pipeline.Executor.execute(workflow, opts)
    end
  end
  
  defp execute_with_dspy(workflow, opts) do
    # Initialize DSPy context
    dspy_context = initialize_dspy_context(workflow, opts)
    
    # Execute with DSPy enhancements
    enhanced_opts = Keyword.put(opts, :dspy_context, dspy_context)
    
    # Use enhanced step execution
    execute_steps_with_dspy(workflow["workflow"]["steps"], enhanced_opts)
  end
  
  defp should_use_dspy?(workflow, opts) do
    # Check if DSPy is enabled in configuration
    workflow["workflow"]["dspy_config"]["optimization_enabled"] == true or
    Keyword.get(opts, :force_dspy, false)
  end
end
```

## Configuration Examples

### Basic DSPy-Enabled Pipeline
```yaml
workflow:
  name: code_documentation_generator
  description: "Generate documentation for Elixir code"
  
  dspy_config:
    optimization_enabled: true
    evaluation_metric: "documentation_quality"
    training_examples_path: "training_data/docs_examples.json"
    
  steps:
    - name: analyze_code
      type: dspy_claude
      signature:
        input_fields:
          - name: source_code
            type: string
            description: "Elixir source code"
        output_fields:
          - name: documentation
            type: string
            description: "Generated documentation"
            
      dspy_config:
        few_shot_examples: 3
        optimization_target: "clarity"
```

### Advanced Multi-Step DSPy Pipeline
```yaml
workflow:
  name: comprehensive_code_analysis
  
  dspy_config:
    optimization_enabled: true
    global_training_data: "training_data/code_analysis.json"
    
  steps:
    - name: extract_functions
      type: dspy_claude
      signature:
        input_fields:
          - name: source_code
            type: string
        output_fields:
          - name: functions
            type: array
            description: "List of function definitions"
            
    - name: analyze_complexity
      type: dspy_gemini
      signature:
        input_fields:
          - name: functions
            type: array
            template: "{{steps.extract_functions.functions}}"
        output_fields:
          - name: complexity_analysis
            type: object
            
    - name: generate_recommendations
      type: dspy_claude
      signature:
        input_fields:
          - name: complexity_analysis
            type: object
            template: "{{steps.analyze_complexity.complexity_analysis}}"
        output_fields:
          - name: recommendations
            type: array
```

## Benefits of This Architecture

### 1. **Seamless Integration**
- Maintains existing YAML configuration
- Backward compatible with current pipelines
- Progressive enhancement path

### 2. **Systematic Optimization**
- Automatic prompt optimization
- Evidence-based improvements
- Continuous learning from usage

### 3. **Robust Evaluation**
- Systematic testing framework
- Performance metrics tracking
- Quality assurance

### 4. **Flexible Configuration**
- Step-level optimization control
- Multiple optimization strategies
- Custom evaluation metrics

This framework provides a comprehensive foundation for integrating DSPy's optimization capabilities into pipeline_ex while maintaining the system's existing strengths and usability.