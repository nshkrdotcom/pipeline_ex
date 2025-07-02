# JULY_1_ARCH_DOCS_05: DSPy Integration & Optimization Layer

## Overview

The DSPy integration layer transforms ElexirionDSP from a static pipeline executor into a self-optimizing system. By treating pipeline prompts as parameters to be learned rather than fixed instructions, we enable continuous improvement of AI workflow performance.

## Core Philosophy

### From Static Prompts to Learned Programs

**Traditional Approach (Static):**
```yaml
# Fixed prompt that never improves
- name: analyze_code
  type: claude
  prompt: "Analyze this code for bugs and suggest improvements"
```

**DSPy Approach (Dynamic):**
```python
# Prompt that optimizes itself based on success metrics
class CodeAnalysisModule(dspy.Module):
    def __init__(self):
        self.analyze = dspy.ChainOfThought("code -> analysis")
    
    def forward(self, code):
        return self.analyze(code=code)

# DSPy finds the best prompt automatically
optimized = dspy.compile(CodeAnalysisModule(), metric=validate_analysis_quality)
```

### The Hybrid Execution Model

```
┌─────────────────────────────────────────────────────────────┐
│                   DSPy Optimizer (Python)                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                Learning Loop                        │    │
│  │  1. Generate candidate prompts                      │    │
│  │  2. Test via Elixir execution                       │    │
│  │  3. Measure success metrics                         │    │
│  │  4. Update prompt parameters                        │    │
│  │  5. Repeat until convergence                        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                    subprocess calls
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                Elixir Execution Runtime                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Production Pipeline                    │    │
│  │  • Robust error handling                           │    │
│  │  • OTP supervision                                 │    │
│  │  • Multi-provider support                          │    │
│  │  • Concurrent execution                            │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Architecture

### 1. Python-Elixir Bridge

```python
# bridge/elixir_pipeline.py
import subprocess
import json
import tempfile
from typing import Dict, Any, Optional

class ElixirPipelineExecutor:
    """Bridge between DSPy and Elixir pipeline execution"""
    
    def __init__(self, elixir_project_path: str):
        self.project_path = elixir_project_path
        self.temp_dir = tempfile.mkdtemp()
    
    def execute_pipeline(self, 
                        pipeline_config: Dict[str, Any], 
                        input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Execute an Elixir pipeline and return results"""
        
        # 1. Write temporary pipeline config
        config_path = self._write_temp_config(pipeline_config)
        
        # 2. Write input data
        input_path = self._write_temp_input(input_data)
        
        # 3. Execute via mix command
        result = subprocess.run([
            'mix', 'pipeline.execute', 
            '--config', config_path,
            '--input', input_path,
            '--format', 'json'
        ], 
        cwd=self.project_path,
        capture_output=True, 
        text=True,
        timeout=300  # 5 minute timeout
        )
        
        if result.returncode != 0:
            raise Exception(f"Pipeline execution failed: {result.stderr}")
        
        # 4. Parse and return results
        return json.loads(result.stdout)
    
    def _write_temp_config(self, config: Dict[str, Any]) -> str:
        """Write pipeline config to temporary YAML file"""
        import yaml
        
        config_path = f"{self.temp_dir}/pipeline_{id(config)}.yaml"
        with open(config_path, 'w') as f:
            yaml.dump(config, f)
        return config_path
    
    def _write_temp_input(self, input_data: Dict[str, Any]) -> str:
        """Write input data to temporary JSON file"""
        input_path = f"{self.temp_dir}/input_{id(input_data)}.json"
        with open(input_path, 'w') as f:
            json.dump(input_data, f)
        return input_path
```

### 2. DSPy Module Wrappers

```python
# modules/elixir_modules.py
import dspy
from typing import Dict, Any
from .bridge.elixir_pipeline import ElixirPipelineExecutor

class ElixirPipelineModule(dspy.Module):
    """DSPy module that wraps Elixir pipeline execution"""
    
    def __init__(self, 
                 pipeline_template: Dict[str, Any],
                 elixir_path: str = "/path/to/pipeline_ex"):
        super().__init__()
        self.pipeline_template = pipeline_template
        self.executor = ElixirPipelineExecutor(elixir_path)
        
        # Extract optimizable prompt from template
        self.prompt_step = self._find_prompt_step(pipeline_template)
        
        # Create DSPy predictor for the prompt
        signature = self._build_signature(self.prompt_step)
        self.predictor = dspy.Predict(signature)
    
    def forward(self, **kwargs):
        """Execute the pipeline with DSPy-optimized prompts"""
        
        # 1. Generate optimized prompt using DSPy
        optimized_prompt = self.predictor(**kwargs).prediction
        
        # 2. Update pipeline config with optimized prompt
        updated_config = self._update_pipeline_prompt(
            self.pipeline_template, 
            optimized_prompt
        )
        
        # 3. Execute via Elixir
        result = self.executor.execute_pipeline(updated_config, kwargs)
        
        # 4. Return structured result
        return dspy.Prediction(
            pipeline_result=result,
            optimized_prompt=optimized_prompt
        )
    
    def _find_prompt_step(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Find the step containing the prompt to optimize"""
        steps = config.get('workflow', {}).get('steps', [])
        
        for step in steps:
            if step.get('type') in ['claude', 'gemini', 'claude_smart']:
                return step
        
        raise ValueError("No optimizable prompt step found in pipeline")
    
    def _build_signature(self, step: Dict[str, Any]) -> str:
        """Build DSPy signature from pipeline step"""
        # Extract input/output structure from step configuration
        # This would be customized based on your pipeline conventions
        return "input_data -> pipeline_output"
    
    def _update_pipeline_prompt(self, 
                               config: Dict[str, Any], 
                               new_prompt: str) -> Dict[str, Any]:
        """Update pipeline config with new prompt"""
        import copy
        updated_config = copy.deepcopy(config)
        
        # Find and update the prompt step
        steps = updated_config['workflow']['steps']
        for step in steps:
            if step.get('type') in ['claude', 'gemini', 'claude_smart']:
                if isinstance(step['prompt'], list):
                    # Update static content
                    for prompt_item in step['prompt']:
                        if prompt_item.get('type') == 'static':
                            prompt_item['content'] = new_prompt
                else:
                    step['prompt'] = new_prompt
                break
        
        return updated_config

class CodeAnalysisModule(ElixirPipelineModule):
    """Specialized module for code analysis optimization"""
    
    def __init__(self, elixir_path: str = "/path/to/pipeline_ex"):
        pipeline_template = {
            'workflow': {
                'name': 'optimizable_code_analysis',
                'steps': [{
                    'name': 'analyze_code',
                    'type': 'claude_smart',
                    'preset': 'analysis',
                    'prompt': [{
                        'type': 'static',
                        'content': 'PLACEHOLDER_FOR_OPTIMIZATION'
                    }]
                }]
            }
        }
        super().__init__(pipeline_template, elixir_path)

class RefactoringModule(ElixirPipelineModule):
    """Specialized module for refactoring optimization"""
    
    def __init__(self, elixir_path: str = "/path/to/pipeline_ex"):
        pipeline_template = {
            'workflow': {
                'name': 'optimizable_refactoring',
                'steps': [
                    {
                        'name': 'analyze_for_refactoring',
                        'type': 'claude_smart',
                        'preset': 'analysis',
                        'prompt': [{
                            'type': 'static',
                            'content': 'ANALYSIS_PLACEHOLDER'
                        }]
                    },
                    {
                        'name': 'generate_refactoring_plan',
                        'type': 'claude_smart', 
                        'preset': 'development',
                        'prompt': [{
                            'type': 'static',
                            'content': 'REFACTORING_PLACEHOLDER'
                        }, {
                            'type': 'previous_response',
                            'name': 'analyze_for_refactoring'
                        }]
                    }
                ]
            }
        }
        super().__init__(pipeline_template, elixir_path)
```

### 3. Training Data Management

```python
# training/data_manager.py
import json
import yaml
from pathlib import Path
from typing import List, Dict, Any, Tuple

class TrainingDataManager:
    """Manages training examples for DSPy optimization"""
    
    def __init__(self, data_dir: str):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(exist_ok=True)
    
    def create_example(self, 
                      input_data: Dict[str, Any],
                      expected_output: Dict[str, Any],
                      metadata: Dict[str, Any] = None) -> str:
        """Create a new training example"""
        
        example_id = self._generate_example_id()
        example_data = {
            'id': example_id,
            'input': input_data,
            'expected_output': expected_output,
            'metadata': metadata or {},
            'created_at': datetime.utcnow().isoformat()
        }
        
        example_path = self.data_dir / f"{example_id}.json"
        with open(example_path, 'w') as f:
            json.dump(example_data, f, indent=2)
        
        return example_id
    
    def load_examples(self) -> List[dspy.Example]:
        """Load all training examples as DSPy examples"""
        examples = []
        
        for example_file in self.data_dir.glob("*.json"):
            with open(example_file) as f:
                data = json.load(f)
            
            example = dspy.Example(
                **data['input'],
                expected_output=data['expected_output']
            ).with_inputs(*data['input'].keys())
            
            examples.append(example)
        
        return examples
    
    def create_from_successful_execution(self, 
                                       pipeline_config: Dict[str, Any],
                                       input_data: Dict[str, Any],
                                       execution_result: Dict[str, Any],
                                       quality_score: float):
        """Create training example from successful pipeline execution"""
        
        if quality_score >= 8.0:  # Only save high-quality examples
            self.create_example(
                input_data=input_data,
                expected_output=execution_result,
                metadata={
                    'pipeline_config': pipeline_config,
                    'quality_score': quality_score,
                    'source': 'successful_execution'
                }
            )
    
    def _generate_example_id(self) -> str:
        import uuid
        return str(uuid.uuid4())[:8]

# Example: Create training data from manual examples
def bootstrap_training_data():
    manager = TrainingDataManager("training_data/code_analysis")
    
    # Example 1: OTP analysis
    manager.create_example(
        input_data={
            "code": """
            defmodule MyAgent do
              use Agent
              
              def start_link do
                Agent.start_link(fn -> %{} end)
              end
              
              def get_state(agent) do
                Agent.get(agent, & &1)
              end
            end
            """,
            "analysis_type": "otp_patterns"
        },
        expected_output={
            "findings": [
                "Agent started without supervision",
                "No error handling for Agent.start_link",
                "State is not persistent across crashes"
            ],
            "recommendations": [
                "Add Agent to supervision tree",
                "Implement proper error handling",
                "Consider using GenServer for stateful processes"
            ],
            "severity": "medium"
        }
    )
```

### 4. Metrics and Evaluation

```python
# metrics/evaluators.py
import dspy
from typing import Dict, Any, List

class CodeAnalysisEvaluator:
    """Evaluates the quality of code analysis outputs"""
    
    def __init__(self):
        # Use another LLM as a judge
        self.judge = dspy.Predict(
            "analysis_output, expected_output -> quality_score_and_reasoning"
        )
    
    def evaluate(self, example: dspy.Example, prediction: dspy.Prediction) -> bool:
        """Evaluate if the analysis meets quality standards"""
        
        analysis_output = prediction.pipeline_result
        expected_output = example.expected_output
        
        # Get LLM evaluation
        evaluation = self.judge(
            analysis_output=json.dumps(analysis_output),
            expected_output=json.dumps(expected_output)
        )
        
        try:
            result = json.loads(evaluation.quality_score_and_reasoning)
            score = float(result.get('score', 0))
            reasoning = result.get('reasoning', '')
            
            print(f"Analysis Quality Score: {score}/10")
            print(f"Reasoning: {reasoning}")
            
            return score >= 7.0  # Threshold for "good enough"
            
        except (json.JSONDecodeError, ValueError, KeyError):
            print(f"Failed to parse evaluation: {evaluation.quality_score_and_reasoning}")
            return False

class RefactoringEvaluator:
    """Evaluates the quality of refactoring suggestions"""
    
    def __init__(self):
        self.judge = dspy.Predict(
            "original_code, refactoring_plan, analysis_context -> feasibility_and_quality"
        )
    
    def evaluate(self, example: dspy.Example, prediction: dspy.Prediction) -> bool:
        """Evaluate refactoring plan quality"""
        
        refactor_result = prediction.pipeline_result
        
        evaluation = self.judge(
            original_code=example.input_code,
            refactoring_plan=json.dumps(refactor_result),
            analysis_context=json.dumps(example.analysis_context)
        )
        
        try:
            result = json.loads(evaluation.feasibility_and_quality)
            
            feasibility_score = float(result.get('feasibility', 0))
            quality_score = float(result.get('quality', 0))
            
            # Both scores must be high
            return feasibility_score >= 7.0 and quality_score >= 7.0
            
        except (json.JSONDecodeError, ValueError, KeyError):
            return False

def create_composite_metric(evaluators: List[Any]) -> callable:
    """Create a metric that combines multiple evaluators"""
    
    def composite_metric(example: dspy.Example, prediction: dspy.Prediction) -> bool:
        scores = []
        
        for evaluator in evaluators:
            try:
                score = evaluator.evaluate(example, prediction)
                scores.append(score)
            except Exception as e:
                print(f"Evaluator failed: {e}")
                scores.append(False)
        
        # All evaluators must pass
        return all(scores)
    
    return composite_metric
```

### 5. Optimization Scripts

```python
# optimize_pipelines.py
import dspy
from modules.elixir_modules import CodeAnalysisModule, RefactoringModule
from training.data_manager import TrainingDataManager
from metrics.evaluators import CodeAnalysisEvaluator, RefactoringEvaluator

def optimize_code_analysis_pipeline():
    """Optimize the code analysis pipeline prompts"""
    
    print("🔄 Starting Code Analysis Pipeline Optimization...")
    
    # 1. Load training data
    data_manager = TrainingDataManager("training_data/code_analysis")
    training_examples = data_manager.load_examples()
    
    print(f"📊 Loaded {len(training_examples)} training examples")
    
    # 2. Configure LLM (using Claude for main execution)
    claude = dspy.Anthropic(model="claude-3-sonnet-20240229")
    dspy.settings.configure(lm=claude)
    
    # 3. Create module and evaluator
    analysis_module = CodeAnalysisModule()
    evaluator = CodeAnalysisEvaluator()
    
    # 4. Set up optimizer
    optimizer = dspy.teleprompt.BootstrapFewShot(
        metric=evaluator.evaluate,
        max_bootstrapped_demos=3,
        max_labeled_demos=5
    )
    
    # 5. Run optimization
    print("🎯 Running optimization...")
    optimized_module = optimizer.compile(
        student=analysis_module,
        trainset=training_examples[:10],  # Use subset for faster iteration
        valset=training_examples[10:15] if len(training_examples) > 10 else None
    )
    
    # 6. Save optimized prompts
    save_optimized_module(optimized_module, "optimized_code_analysis")
    
    print("✅ Code Analysis Pipeline Optimization Complete!")
    return optimized_module

def optimize_refactoring_pipeline():
    """Optimize the refactoring pipeline prompts"""
    
    print("🔄 Starting Refactoring Pipeline Optimization...")
    
    # Similar process for refactoring
    data_manager = TrainingDataManager("training_data/refactoring")
    training_examples = data_manager.load_examples()
    
    refactoring_module = RefactoringModule()
    evaluator = RefactoringEvaluator()
    
    optimizer = dspy.teleprompt.BootstrapFewShot(
        metric=evaluator.evaluate,
        max_bootstrapped_demos=2,
        max_labeled_demos=3
    )
    
    optimized_module = optimizer.compile(
        student=refactoring_module,
        trainset=training_examples[:8],
        valset=training_examples[8:12] if len(training_examples) > 8 else None
    )
    
    save_optimized_module(optimized_module, "optimized_refactoring")
    
    print("✅ Refactoring Pipeline Optimization Complete!")
    return optimized_module

def save_optimized_module(module, name: str):
    """Save optimized module prompts back to Elixir configs"""
    
    # Extract the optimized prompts
    optimized_prompts = extract_prompts_from_module(module)
    
    # Update Elixir YAML files with optimized prompts
    update_elixir_configs(name, optimized_prompts)
    
    # Save DSPy module for future use
    module.save(f"optimized_modules/{name}.dspy")

def extract_prompts_from_module(module) -> Dict[str, str]:
    """Extract optimized prompts from DSPy module"""
    
    prompts = {}
    
    # Access the predictor's optimized prompt
    if hasattr(module, 'predictor'):
        prompts['main_prompt'] = module.predictor.signature
        
        # Get few-shot examples if available
        if hasattr(module.predictor, 'demos'):
            prompts['examples'] = module.predictor.demos
    
    return prompts

def update_elixir_configs(module_name: str, optimized_prompts: Dict[str, str]):
    """Update Elixir YAML configurations with optimized prompts"""
    
    import yaml
    
    config_path = f"../pipelines/optimized/{module_name}.yaml"
    
    # Load existing config or create new one
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        config = {'workflow': {'name': module_name, 'steps': []}}
    
    # Update prompts in config
    for step in config['workflow']['steps']:
        if step.get('type') in ['claude', 'gemini', 'claude_smart']:
            step['prompt'] = [{
                'type': 'static',
                'content': optimized_prompts.get('main_prompt', step['prompt'])
            }]
    
    # Save updated config
    with open(config_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False)
    
    print(f"💾 Saved optimized config to {config_path}")

if __name__ == "__main__":
    # Run optimization for all modules
    optimize_code_analysis_pipeline()
    optimize_refactoring_pipeline()
    
    print("🚀 All pipeline optimizations complete!")
```

### 6. Continuous Learning System

```python
# continuous_learning.py
import schedule
import time
from datetime import datetime, timedelta

class ContinuousLearningSystem:
    """Continuously improves pipelines based on usage data"""
    
    def __init__(self, elixir_project_path: str):
        self.elixir_path = elixir_project_path
        self.last_optimization = datetime.now()
        
    def setup_learning_schedule(self):
        """Set up scheduled optimization runs"""
        
        # Daily light optimization
        schedule.every().day.at("02:00").do(self.daily_optimization)
        
        # Weekly full re-optimization
        schedule.every().week.do(self.weekly_full_optimization)
        
        # Real-time learning from feedback
        schedule.every(10).minutes.do(self.process_recent_feedback)
    
    def daily_optimization(self):
        """Light optimization based on recent usage"""
        print(f"🌅 Running daily optimization at {datetime.now()}")
        
        # Collect usage metrics from last 24 hours
        usage_data = self.collect_recent_usage_data(hours=24)
        
        if self.should_optimize(usage_data):
            # Run quick optimization on pipelines with poor performance
            self.optimize_underperforming_pipelines(usage_data)
    
    def weekly_full_optimization(self):
        """Full re-optimization of all pipelines"""
        print(f"📅 Running weekly full optimization at {datetime.now()}")
        
        # Collect week's worth of data
        usage_data = self.collect_recent_usage_data(hours=168)  # 7 days
        
        # Re-optimize all modules
        optimize_code_analysis_pipeline()
        optimize_refactoring_pipeline()
        
        # Update performance baselines
        self.update_performance_baselines(usage_data)
    
    def collect_recent_usage_data(self, hours: int) -> Dict[str, Any]:
        """Collect pipeline usage and performance data"""
        
        # Query Elixir system for metrics
        # This would interface with your telemetry system
        
        import subprocess
        result = subprocess.run([
            'mix', 'telemetry.export',
            '--format', 'json',
            '--since', f"{hours}h"
        ], 
        cwd=self.elixir_path,
        capture_output=True,
        text=True
        )
        
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return {}
    
    def should_optimize(self, usage_data: Dict[str, Any]) -> bool:
        """Determine if optimization is needed"""
        
        # Check performance degradation
        current_success_rate = usage_data.get('success_rate', 1.0)
        baseline_success_rate = 0.95
        
        if current_success_rate < baseline_success_rate:
            return True
        
        # Check if enough new data is available
        new_examples_count = usage_data.get('new_examples', 0)
        if new_examples_count > 10:
            return True
        
        return False
    
    def run_forever(self):
        """Run the continuous learning system"""
        print("🔄 Starting continuous learning system...")
        
        while True:
            schedule.run_pending()
            time.sleep(60)  # Check every minute

if __name__ == "__main__":
    learning_system = ContinuousLearningSystem("/path/to/pipeline_ex")
    learning_system.setup_learning_schedule()
    learning_system.run_forever()
```

## Integration with Elixir

### 1. Enhanced Mix Tasks

```elixir
# lib/mix/tasks/dspy.ex
defmodule Mix.Tasks.Dspy.Optimize do
  use Mix.Task
  
  @shortdoc "Optimize pipeline prompts using DSPy"
  
  def run(args) do
    {opts, args, _} = OptionParser.parse(args,
      switches: [
        pipeline: :string,
        module: :string,
        training_data: :string
      ]
    )
    
    python_script = Path.join([__DIR__, "../../../scripts/optimize_pipeline.py"])
    
    cmd_args = [
      "python3", python_script,
      "--elixir-path", File.cwd!(),
      "--pipeline", Keyword.get(opts, :pipeline, "all"),
      "--training-data", Keyword.get(opts, :training_data, "training_data/")
    ]
    
    case System.cmd("python3", tl(cmd_args)) do
      {output, 0} ->
        IO.puts("✅ Optimization completed successfully")
        IO.puts(output)
        
      {error, exit_code} ->
        IO.puts("❌ Optimization failed with exit code #{exit_code}")
        IO.puts(error)
        System.halt(1)
    end
  end
end
```

### 2. Telemetry Integration

```elixir
defmodule Pipeline.DSPyTelemetry do
  @moduledoc """
  Collects telemetry data for DSPy optimization
  """
  
  def setup() do
    :telemetry.attach_many(
      "dspy-data-collection",
      [
        [:pipeline, :execution, :stop],
        [:pipeline, :step, :stop]
      ],
      &handle_telemetry_event/4,
      %{}
    )
  end
  
  def handle_telemetry_event([:pipeline, :execution, :stop], measurements, metadata, _config) do
    # Record execution results for DSPy training
    execution_data = %{
      pipeline_id: metadata.pipeline_id,
      success: measurements.success,
      duration_ms: measurements.duration,
      quality_score: calculate_quality_score(metadata.result),
      input_data: metadata.input,
      output_data: metadata.result,
      timestamp: DateTime.utc_now()
    }
    
    # Store for DSPy training data collection
    Pipeline.DSPyDataStore.record_execution(execution_data)
  end
  
  defp calculate_quality_score(result) do
    # Implement heuristics to score result quality
    # This can be enhanced with user feedback
    case result do
      %{status: :success, findings: findings} when length(findings) > 0 -> 8.5
      %{status: :success} -> 7.0
      %{status: :partial} -> 5.0
      _ -> 2.0
    end
  end
end
```

The DSPy integration transforms ElexirionDSP from a static system into a continuously learning platform. By treating prompts as learnable parameters rather than fixed instructions, we enable the system to improve its performance automatically based on real-world usage patterns and feedback.