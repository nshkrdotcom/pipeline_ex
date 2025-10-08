# Evaluation Pipeline Design Specification

**Date:** 2025-10-07
**Version:** 1.0
**Status:** Detailed Implementation Specification
**Companion Documents:**
- `01_enterprise_feasibility_assessment.md`
- `02_integration_architecture_design.md`

---

## Table of Contents

1. [Overview](#1-overview)
2. [Evaluation Framework Architecture](#2-evaluation-framework-architecture)
3. [Core Components Specification](#3-core-components-specification)
4. [Metrics System Design](#4-metrics-system-design)
5. [Test Case Management](#5-test-case-management)
6. [Execution Engine](#6-execution-engine)
7. [Result Aggregation & Reporting](#7-result-aggregation--reporting)
8. [YAML Pipeline Configuration](#8-yaml-pipeline-configuration)
9. [Implementation Guide](#9-implementation-guide)

---

## 1. Overview

### 1.1 Purpose

The Evaluation Pipeline system provides enterprise-grade capabilities for testing, validating, and monitoring AI pipeline performance. It enables:

- **Automated Testing** - Run comprehensive test suites against AI pipelines
- **Performance Tracking** - Monitor model performance over time
- **Regression Detection** - Automatically detect performance degradation
- **A/B Testing** - Compare different models or pipeline versions
- **Continuous Validation** - Integrate with CI/CD for automated quality gates

### 1.2 Design Goals

1. **Flexibility** - Support multiple evaluation metrics (LLM-based, NLP, custom)
2. **Performance** - Parallel execution of test cases
3. **Recoverability** - Checkpoint and resume long-running evaluations
4. **Observability** - Comprehensive metrics and logging
5. **Composability** - Reuse existing pipeline infrastructure
6. **Extensibility** - Easy to add new metrics and test types

### 1.3 Key Features

- ✅ **20+ Built-in Metrics** - BLEU, ROUGE, semantic similarity, faithfulness, etc.
- ✅ **LLM-as-Judge** - Use Claude/Gemini to evaluate responses
- ✅ **Python Integration** - Snakepit bridge for NLP libraries
- ✅ **Test Versioning** - Git-like versioning for test suites
- ✅ **Regression Testing** - Baseline comparison with alerts
- ✅ **Parallel Execution** - Concurrent test case processing
- ✅ **Rich Reporting** - HTML/JSON reports with visualizations

---

## 2. Evaluation Framework Architecture

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Evaluation API Layer                         │
│  - Mix Tasks (CLI)                                              │
│  - HTTP API (optional)                                          │
│  - Elixir API (programmatic)                                    │
└─────────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────────────┐
│                  Evaluation Orchestrator                        │
│  - Suite Management      - Execution Coordination               │
│  - Progress Tracking     - Checkpoint/Resume                    │
└─────────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Test Case    │  │  Metrics     │  │  Result      │
│ Manager      │  │  Calculator  │  │  Aggregator  │
│              │  │              │  │              │
│ - Load       │  │ - LLM-based  │  │ - Stats      │
│ - Version    │  │ - Python NLP │  │ - Regression │
│ - Generate   │  │ - Custom     │  │ - Reporting  │
└──────────────┘  └──────────────┘  └──────────────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                          ▼
        ┌─────────────────────────────────────────┐
        │      Pipeline Execution Engine          │
        │  (Reuses existing infrastructure)       │
        └─────────────────────────────────────────┘
```

### 2.2 Component Interactions

```
Test Suite (JSON)
      │
      ├─→ TestCaseManager.load()
      │         │
      │         └─→ Validate schema
      │         └─→ Load test cases
      │
      ├─→ EvaluationOrchestrator.run()
      │         │
      │         ├─→ Initialize tracking
      │         ├─→ Create checkpoint
      │         │
      │         ├─→ For each batch:
      │         │      │
      │         │      ├─→ Spawn parallel tasks
      │         │      │
      │         │      ├─→ For each test case:
      │         │      │      │
      │         │      │      ├─→ Execute pipeline
      │         │      │      │     │
      │         │      │      │     └─→ Get prediction
      │         │      │      │
      │         │      │      ├─→ Calculate metrics
      │         │      │      │     │
      │         │      │      │     ├─→ LLM-based (Elixir)
      │         │      │      │     └─→ NLP (Python/Snakepit)
      │         │      │      │
      │         │      │      └─→ Return result
      │         │      │
      │         │      └─→ Collect batch results
      │         │
      │         ├─→ Aggregate all results
      │         │
      │         └─→ Generate report
      │
      └─→ Save to storage
```

### 2.3 Data Flow

```
Input: Test Suite + Pipeline Config
      │
      ▼
┌────────────────────────┐
│  Load Test Cases       │
│  - Parse JSON          │
│  - Validate schema     │
│  - Apply filters       │
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Execute Test Cases    │
│  - Parallel batches    │
│  - Run pipeline        │
│  - Get predictions     │
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Calculate Metrics     │
│  - LLM evaluation      │
│  - NLP metrics         │
│  - Custom validators   │
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Aggregate Results     │
│  - Statistical summary │
│  - Baseline comparison │
│  - Regression detection│
└──────────┬─────────────┘
           │
           ▼
┌────────────────────────┐
│  Generate Report       │
│  - JSON output         │
│  - HTML visualization  │
│  - Metrics export      │
└────────────────────────┘
```

---

## 3. Core Components Specification

### 3.1 Evaluation Orchestrator

#### Module: `Pipeline.Evaluation.Orchestrator`

**Responsibilities:**
- Coordinate evaluation execution
- Manage test batching and parallelism
- Handle checkpoint/resume
- Track progress and emit telemetry

**API:**
```elixir
defmodule Pipeline.Evaluation.Orchestrator do
  @type eval_config :: %{
    test_suite_path: String.t(),
    pipeline_config: map(),
    metrics: [metric_config()],
    batch_size: pos_integer(),
    parallel: boolean(),
    checkpoint_interval: pos_integer(),
    baseline_path: String.t() | nil
  }

  @type eval_result :: %{
    eval_id: String.t(),
    test_suite: String.t(),
    total_tests: pos_integer(),
    passed_tests: pos_integer(),
    failed_tests: pos_integer(),
    metrics_summary: map(),
    duration_ms: pos_integer(),
    regression_detected: boolean()
  }

  @doc """
  Start a new evaluation run.
  """
  @spec start_evaluation(eval_config()) :: {:ok, eval_id :: String.t()} | {:error, term()}
  def start_evaluation(config)

  @doc """
  Resume evaluation from checkpoint.
  """
  @spec resume_evaluation(eval_id :: String.t()) :: {:ok, eval_result()} | {:error, term()}
  def resume_evaluation(eval_id)

  @doc """
  Get evaluation status (for monitoring).
  """
  @spec get_status(eval_id :: String.t()) :: {:ok, status :: map()} | {:error, term()}
  def get_status(eval_id)

  @doc """
  Cancel running evaluation.
  """
  @spec cancel_evaluation(eval_id :: String.t()) :: :ok | {:error, term()}
  def cancel_evaluation(eval_id)
end
```

**Implementation Outline:**
```elixir
defmodule Pipeline.Evaluation.Orchestrator do
  use GenServer

  alias Pipeline.Evaluation.{TestSuite, MetricsCalculator, ResultAggregator}
  alias Pipeline.CheckpointManager

  defstruct [
    :eval_id,
    :config,
    :test_suite,
    :results,
    :status,
    :start_time,
    :current_batch,
    :total_batches
  ]

  # Client API

  def start_evaluation(config) do
    eval_id = generate_eval_id()

    {:ok, _pid} = DynamicSupervisor.start_child(
      Pipeline.EvaluationSupervisor,
      {__MODULE__, {eval_id, config}}
    )

    GenServer.cast(via_tuple(eval_id), :start)
    {:ok, eval_id}
  end

  # Server callbacks

  def init({eval_id, config}) do
    # Load test suite
    {:ok, test_suite} = TestSuite.load(config.test_suite_path)

    # Initialize state
    state = %__MODULE__{
      eval_id: eval_id,
      config: config,
      test_suite: test_suite,
      results: [],
      status: :initializing,
      start_time: DateTime.utc_now(),
      current_batch: 0,
      total_batches: calculate_batches(test_suite, config.batch_size)
    }

    # Start performance monitoring
    Pipeline.Monitoring.Performance.start_monitoring("eval_#{eval_id}")

    {:ok, state}
  end

  def handle_cast(:start, state) do
    Logger.info("Starting evaluation: #{state.eval_id}")

    # Update status
    new_state = %{state | status: :running}

    # Execute batches
    execute_evaluation(new_state)

    {:noreply, new_state}
  end

  defp execute_evaluation(state) do
    batch_size = state.config.batch_size

    results =
      state.test_suite.test_cases
      |> Enum.with_index()
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index()
      |> Enum.reduce([], fn {batch, batch_idx}, acc_results ->
        # Checkpoint before each batch
        if rem(batch_idx, state.config.checkpoint_interval) == 0 do
          save_checkpoint(state, acc_results)
        end

        # Execute batch
        batch_results = execute_batch(batch, state.config)

        # Emit progress
        emit_progress(state, batch_idx + 1)

        acc_results ++ batch_results
      end)

    # Aggregate results
    aggregated = ResultAggregator.aggregate(results, state.config)

    # Save final results
    save_results(state.eval_id, aggregated)

    # Cleanup
    Pipeline.Monitoring.Performance.stop_monitoring("eval_#{state.eval_id}")

    Logger.info("Evaluation complete: #{state.eval_id}")

    %{state | results: aggregated, status: :completed}
  end

  defp execute_batch(batch, config) do
    if config.parallel do
      # Parallel execution
      batch
      |> Enum.map(fn {test_case, idx} ->
        Task.async(fn -> execute_test_case(test_case, idx, config) end)
      end)
      |> Task.await_many(60_000)
    else
      # Sequential execution
      Enum.map(batch, fn {test_case, idx} ->
        execute_test_case(test_case, idx, config)
      end)
    end
  end

  defp execute_test_case(test_case, idx, config) do
    start_time = System.monotonic_time(:millisecond)

    try do
      # Run pipeline to get prediction
      {:ok, prediction} = run_pipeline(test_case.input, config.pipeline_config)

      # Calculate all metrics
      metrics = MetricsCalculator.calculate_all(
        prediction,
        test_case.expected_output,
        config.metrics
      )

      # Determine pass/fail
      passed = all_metrics_pass?(metrics)

      %{
        test_case_id: test_case.id,
        index: idx,
        input: test_case.input,
        expected: test_case.expected_output,
        predicted: prediction,
        metrics: metrics,
        passed: passed,
        duration_ms: System.monotonic_time(:millisecond) - start_time
      }
    rescue
      error ->
        Logger.error("Test case #{idx} failed: #{inspect(error)}")

        %{
          test_case_id: test_case.id,
          index: idx,
          passed: false,
          error: inspect(error),
          duration_ms: System.monotonic_time(:millisecond) - start_time
        }
    end
  end

  defp run_pipeline(input, pipeline_config) do
    # Execute the pipeline being evaluated
    variables = %{"eval_input" => input}

    case Pipeline.execute_workflow(pipeline_config.path, variables: variables) do
      {:ok, results} ->
        # Extract the output (configurable which step)
        output_step = pipeline_config.output_step || get_last_step(results)
        output = extract_output(results, output_step)
        {:ok, output}

      error ->
        error
    end
  end

  defp all_metrics_pass?(metrics) do
    Enum.all?(metrics, fn metric -> metric.passed end)
  end

  defp save_checkpoint(state, results) do
    checkpoint_data = %{
      eval_id: state.eval_id,
      current_batch: state.current_batch,
      results_so_far: results,
      timestamp: DateTime.utc_now()
    }

    CheckpointManager.save("checkpoints/eval", "eval_#{state.eval_id}", checkpoint_data)
  end

  defp emit_progress(state, batch_num) do
    progress = %{
      eval_id: state.eval_id,
      current_batch: batch_num,
      total_batches: state.total_batches,
      percent_complete: Float.round(batch_num / state.total_batches * 100, 2)
    }

    :telemetry.execute(
      [:pipeline, :evaluation, :progress],
      %{percent: progress.percent_complete},
      progress
    )

    Logger.info("Evaluation progress: #{progress.percent_complete}%")
  end

  defp via_tuple(eval_id) do
    {:via, Registry, {Pipeline.MonitoringRegistry, "eval_#{eval_id}"}}
  end

  defp generate_eval_id do
    "eval_#{System.system_time(:millisecond)}_#{:rand.uniform(10000)}"
  end
end
```

### 3.2 Test Case Manager

#### Module: `Pipeline.Evaluation.TestCase`

**Responsibilities:**
- Load and validate test suites
- Version control for test cases
- Generate synthetic test cases
- Filter and sample test cases

**Test Case Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["id", "input", "expected_output"],
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique identifier for test case"
    },
    "input": {
      "type": ["string", "object"],
      "description": "Input to the pipeline"
    },
    "expected_output": {
      "type": ["string", "object"],
      "description": "Expected output from pipeline"
    },
    "metadata": {
      "type": "object",
      "properties": {
        "category": {"type": "string"},
        "difficulty": {"type": "string", "enum": ["easy", "medium", "hard"]},
        "tags": {"type": "array", "items": {"type": "string"}},
        "created_at": {"type": "string", "format": "date-time"},
        "source": {"type": "string"}
      }
    },
    "custom_metrics": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "threshold": {"type": "number"}
        }
      }
    }
  }
}
```

**API:**
```elixir
defmodule Pipeline.Evaluation.TestCase do
  @type test_case :: %__MODULE__{
    id: String.t(),
    input: String.t() | map(),
    expected_output: String.t() | map(),
    metadata: map(),
    custom_metrics: [map()]
  }

  @type test_suite :: %{
    name: String.t(),
    version: String.t(),
    test_cases: [test_case()],
    metadata: map()
  }

  defstruct [:id, :input, :expected_output, :metadata, :custom_metrics]

  @doc "Load test suite from file"
  @spec load_suite(String.t()) :: {:ok, test_suite()} | {:error, term()}
  def load_suite(path)

  @doc "Save test suite to file with versioning"
  @spec save_suite(test_suite(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save_suite(suite, path)

  @doc "Generate synthetic test cases using LLM"
  @spec generate_synthetic(specification :: String.t(), count :: pos_integer()) ::
    {:ok, [test_case()]} | {:error, term()}
  def generate_synthetic(specification, count)

  @doc "Filter test cases by criteria"
  @spec filter_by(test_suite(), criteria :: map()) :: test_suite()
  def filter_by(suite, criteria)

  @doc "Sample N random test cases"
  @spec sample(test_suite(), count :: pos_integer()) :: test_suite()
  def sample(suite, count)
end
```

**Implementation:**
```elixir
defmodule Pipeline.Evaluation.TestCase do
  @moduledoc "Test case management with versioning and generation"

  defstruct [:id, :input, :expected_output, :metadata, :custom_metrics]

  def load_suite(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content),
         :ok <- validate_suite_schema(data) do

      test_cases = Enum.map(data["test_cases"], &parse_test_case/1)

      suite = %{
        name: data["name"],
        version: data["version"] || "1.0",
        test_cases: test_cases,
        metadata: data["metadata"] || %{}
      }

      {:ok, suite}
    end
  end

  def save_suite(suite, base_path) do
    # Create versioned file
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    version_path = "#{base_path}_v#{suite.version}_#{timestamp}.json"

    data = %{
      "name" => suite.name,
      "version" => suite.version,
      "test_cases" => Enum.map(suite.test_cases, &serialize_test_case/1),
      "metadata" => Map.merge(suite.metadata, %{
        "saved_at" => timestamp,
        "test_count" => length(suite.test_cases)
      })
    }

    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        File.mkdir_p!(Path.dirname(version_path))
        File.write!(version_path, json)

        # Create/update latest symlink
        latest_path = "#{base_path}_latest.json"
        File.write!(latest_path, json)

        {:ok, version_path}

      error ->
        error
    end
  end

  def generate_synthetic(specification, count) do
    # Use Claude to generate test cases
    prompt = """
    Generate #{count} diverse test cases for the following specification:

    #{specification}

    Return JSON array with format:
    [
      {
        "id": "test_001",
        "input": "input text or object",
        "expected_output": "expected output",
        "metadata": {
          "category": "category_name",
          "difficulty": "easy|medium|hard"
        }
      },
      ...
    ]
    """

    case Pipeline.Providers.ClaudeProvider.query(prompt,
      model: "claude-sonnet-4",
      output_format: :json
    ) do
      {:ok, %{content: content}} ->
        case Jason.decode(content) do
          {:ok, test_cases_data} ->
            test_cases = Enum.map(test_cases_data, &parse_test_case/1)
            {:ok, test_cases}

          error ->
            error
        end

      error ->
        error
    end
  end

  def filter_by(suite, criteria) do
    filtered_cases = Enum.filter(suite.test_cases, fn test_case ->
      matches_criteria?(test_case, criteria)
    end)

    %{suite | test_cases: filtered_cases}
  end

  def sample(suite, count) do
    sampled_cases = Enum.take_random(suite.test_cases, count)
    %{suite | test_cases: sampled_cases}
  end

  # Private functions

  defp parse_test_case(data) do
    %__MODULE__{
      id: data["id"],
      input: data["input"],
      expected_output: data["expected_output"],
      metadata: data["metadata"] || %{},
      custom_metrics: data["custom_metrics"] || []
    }
  end

  defp serialize_test_case(test_case) do
    %{
      "id" => test_case.id,
      "input" => test_case.input,
      "expected_output" => test_case.expected_output,
      "metadata" => test_case.metadata,
      "custom_metrics" => test_case.custom_metrics
    }
  end

  defp matches_criteria?(test_case, criteria) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :category ->
          get_in(test_case.metadata, ["category"]) == value

        :difficulty ->
          get_in(test_case.metadata, ["difficulty"]) == value

        :tags ->
          tags = get_in(test_case.metadata, ["tags"]) || []
          value in tags

        _ ->
          true
      end
    end)
  end

  defp validate_suite_schema(data) do
    # Use JSON Schema validator
    schema = test_suite_schema()

    case Pipeline.Validation.SchemaValidator.validate(data, schema) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp test_suite_schema do
    %{
      "type" => "object",
      "required" => ["name", "test_cases"],
      "properties" => %{
        "name" => %{"type" => "string"},
        "version" => %{"type" => "string"},
        "test_cases" => %{
          "type" => "array",
          "items" => test_case_schema()
        }
      }
    }
  end

  defp test_case_schema do
    %{
      "type" => "object",
      "required" => ["id", "input", "expected_output"],
      "properties" => %{
        "id" => %{"type" => "string"},
        "input" => %{"type" => ["string", "object"]},
        "expected_output" => %{"type" => ["string", "object"]},
        "metadata" => %{"type" => "object"},
        "custom_metrics" => %{"type" => "array"}
      }
    }
  end
end
```

---

## 4. Metrics System Design

### 4.1 Metrics Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Metrics Calculator                         │
│  (Dispatches to appropriate metric implementation)          │
└─────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ LLM-Based    │  │ Python NLP   │  │ Custom       │
│ (Elixir)     │  │ (Snakepit)   │  │ (Pluggable)  │
│              │  │              │  │              │
│ - Semantic   │  │ - BLEU       │  │ - User-      │
│   Similarity │  │ - ROUGE      │  │   defined    │
│ - Faithful   │  │ - Embedding  │  │ - Domain-    │
│ - Relevance  │  │ - BERTScore  │  │   specific   │
│ - Coherence  │  │              │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

### 4.2 Metric Interface

```elixir
defmodule Pipeline.Evaluation.Metric do
  @moduledoc """
  Behaviour for evaluation metrics.
  All metrics must implement this behaviour.
  """

  @type metric_result :: %{
    score: float(),
    passed: boolean(),
    metadata: map()
  }

  @callback calculate(predicted :: any(), expected :: any(), opts :: keyword()) ::
    {:ok, metric_result()} | {:error, term()}

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback default_threshold() :: float()
end
```

### 4.3 LLM-Based Metrics (Elixir Implementation)

```elixir
defmodule Pipeline.Evaluation.Metrics.LLMJudge do
  @moduledoc """
  LLM-based evaluation metrics using Claude/Gemini as judges.
  Pure Elixir implementation - no Python dependencies.
  """

  @doc """
  Evaluate semantic similarity between predicted and expected outputs.
  Uses LLM to judge if outputs convey the same meaning.
  """
  def semantic_similarity(predicted, expected, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.7)

    prompt = """
    You are an expert evaluator. Compare these two texts for semantic similarity.

    Expected Output:
    #{expected}

    Predicted Output:
    #{predicted}

    Rate their semantic similarity on a scale of 0.0 to 1.0 where:
    - 1.0 = Identical meaning, even if worded differently
    - 0.7-0.9 = Very similar meaning with minor differences
    - 0.4-0.6 = Somewhat similar, captures main points
    - 0.0-0.3 = Different meanings

    Return ONLY a JSON object with this exact format:
    {
      "score": 0.0-1.0,
      "reasoning": "brief explanation of score",
      "key_differences": ["difference 1", "difference 2"]
    }
    """

    case Pipeline.Providers.ClaudeProvider.query(prompt,
      model: "claude-sonnet-4",
      output_format: :json,
      cache_ttl: 3600
    ) do
      {:ok, %{content: content}} ->
        result = Jason.decode!(content)

        {:ok, %{
          score: result["score"],
          passed: result["score"] >= threshold,
          reasoning: result["reasoning"],
          key_differences: result["key_differences"],
          metric: "semantic_similarity"
        }}

      error ->
        error
    end
  end

  @doc """
  Evaluate faithfulness - does predicted output accurately reflect source context?
  """
  def faithfulness(predicted, source_context, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.8)

    prompt = """
    Evaluate if the predicted output is faithful to the source context.
    Does it accurately represent information from the source without hallucination?

    Source Context:
    #{source_context}

    Predicted Output:
    #{predicted}

    Rate faithfulness from 0.0 to 1.0:
    - 1.0 = Fully faithful, all claims supported by source
    - 0.7-0.9 = Mostly faithful, minor unsupported details
    - 0.4-0.6 = Partially faithful, some hallucinations
    - 0.0-0.3 = Unfaithful, significant hallucinations

    Return JSON:
    {
      "score": 0.0-1.0,
      "reasoning": "explanation",
      "hallucinations": ["claim 1", "claim 2"],
      "supported_claims": ["claim 1", "claim 2"]
    }
    """

    case Pipeline.Providers.ClaudeProvider.query(prompt,
      model: "claude-sonnet-4",
      output_format: :json
    ) do
      {:ok, %{content: content}} ->
        result = Jason.decode!(content)

        {:ok, %{
          score: result["score"],
          passed: result["score"] >= threshold,
          reasoning: result["reasoning"],
          hallucinations: result["hallucinations"],
          supported_claims: result["supported_claims"],
          metric: "faithfulness"
        }}

      error ->
        error
    end
  end

  @doc """
  Evaluate relevance - does output address the query/question?
  """
  def relevance(predicted, query, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.7)

    prompt = """
    Evaluate how relevant the output is to the given query.

    Query:
    #{query}

    Output:
    #{predicted}

    Rate relevance from 0.0 to 1.0:
    - 1.0 = Directly addresses query, comprehensive
    - 0.7-0.9 = Addresses query well, minor gaps
    - 0.4-0.6 = Partially relevant, misses key points
    - 0.0-0.3 = Mostly irrelevant or off-topic

    Return JSON:
    {
      "score": 0.0-1.0,
      "reasoning": "explanation",
      "addressed_points": ["point 1", "point 2"],
      "missed_points": ["point 1", "point 2"]
    }
    """

    case Pipeline.Providers.ClaudeProvider.query(prompt,
      model: "claude-sonnet-4",
      output_format: :json
    ) do
      {:ok, %{content: content}} ->
        result = Jason.decode!(content)

        {:ok, %{
          score: result["score"],
          passed: result["score"] >= threshold,
          reasoning: result["reasoning"],
          addressed_points: result["addressed_points"],
          missed_points: result["missed_points"],
          metric: "relevance"
        }}

      error ->
        error
    end
  end

  @doc """
  Evaluate coherence - is the output well-structured and logical?
  """
  def coherence(predicted, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.7)

    prompt = """
    Evaluate the coherence of this text - how well-structured and logical is it?

    Text:
    #{predicted}

    Rate coherence from 0.0 to 1.0:
    - 1.0 = Excellent flow, clear structure, logical
    - 0.7-0.9 = Good coherence, minor flow issues
    - 0.4-0.6 = Somewhat coherent, noticeable issues
    - 0.0-0.3 = Incoherent, confusing structure

    Return JSON:
    {
      "score": 0.0-1.0,
      "reasoning": "explanation",
      "strengths": ["strength 1", "strength 2"],
      "weaknesses": ["weakness 1", "weakness 2"]
    }
    """

    case Pipeline.Providers.ClaudeProvider.query(prompt,
      model: "claude-sonnet-4",
      output_format: :json
    ) do
      {:ok, %{content: content}} ->
        result = Jason.decode!(content)

        {:ok, %{
          score: result["score"],
          passed: result["score"] >= threshold,
          reasoning: result["reasoning"],
          strengths: result["strengths"],
          weaknesses: result["weaknesses"],
          metric: "coherence"
        }}

      error ->
        error
    end
  end
end
```

### 4.4 Python NLP Metrics (Snakepit Integration)

Already covered in `02_integration_architecture_design.md` section 3.3-3.4.

### 4.5 Custom Metrics

```elixir
defmodule Pipeline.Evaluation.Metrics.Custom do
  @moduledoc """
  Framework for defining custom evaluation metrics.
  """

  @doc """
  Register a custom metric function.
  """
  def register_metric(name, function) when is_function(function, 2) do
    # Store in ETS registry
    :ets.insert(:custom_metrics, {name, function})
    :ok
  end

  @doc """
  Execute a custom metric.
  """
  def execute_custom(metric_name, predicted, expected, opts \\ []) do
    case :ets.lookup(:custom_metrics, metric_name) do
      [{^metric_name, function}] ->
        try do
          result = function.(predicted, expected)

          # Standardize result format
          standardized = standardize_result(result, opts)
          {:ok, standardized}
        rescue
          error ->
            {:error, error}
        end

      [] ->
        {:error, :metric_not_found}
    end
  end

  defp standardize_result(result, opts) when is_map(result) do
    threshold = Keyword.get(opts, :threshold, 0.7)

    %{
      score: Map.get(result, :score, 0.0),
      passed: Map.get(result, :score, 0.0) >= threshold,
      metadata: Map.drop(result, [:score])
    }
  end

  defp standardize_result(score, opts) when is_number(score) do
    threshold = Keyword.get(opts, :threshold, 0.7)

    %{
      score: score,
      passed: score >= threshold,
      metadata: %{}
    }
  end
end

# Example custom metric registration:
# Pipeline.Evaluation.Metrics.Custom.register_metric(
#   :word_count_similarity,
#   fn predicted, expected ->
#     pred_count = String.split(predicted) |> length()
#     exp_count = String.split(expected) |> length()
#     ratio = min(pred_count, exp_count) / max(pred_count, exp_count)
#     %{score: ratio, word_counts: %{predicted: pred_count, expected: exp_count}}
#   end
# )
```

---

## 5. Test Case Management

### 5.1 Test Suite Format

```json
{
  "name": "QA System Evaluation",
  "version": "2.1",
  "description": "Comprehensive test suite for question-answering pipeline",
  "metadata": {
    "created_at": "2025-10-07T10:00:00Z",
    "created_by": "evaluation-team",
    "domain": "customer_support",
    "tags": ["qa", "customer-support", "production"]
  },
  "test_cases": [
    {
      "id": "qa_001",
      "input": {
        "question": "How do I reset my password?",
        "context": "User documentation about account management..."
      },
      "expected_output": "To reset your password, go to Settings > Security > Reset Password",
      "metadata": {
        "category": "account_management",
        "difficulty": "easy",
        "tags": ["password", "security"],
        "source": "production_logs"
      },
      "custom_metrics": [
        {
          "name": "contains_steps",
          "threshold": 1.0
        }
      ]
    },
    {
      "id": "qa_002",
      "input": {
        "question": "What's your refund policy?",
        "context": "Company refund policy documentation..."
      },
      "expected_output": "Our refund policy allows returns within 30 days...",
      "metadata": {
        "category": "billing",
        "difficulty": "medium",
        "tags": ["refund", "policy"]
      }
    }
  ],
  "baseline_results": {
    "version": "2.0",
    "date": "2025-09-15T00:00:00Z",
    "metrics": {
      "semantic_similarity": 0.87,
      "faithfulness": 0.92,
      "bleu": 0.45
    }
  }
}
```

### 5.2 Version Control

```elixir
defmodule Pipeline.Evaluation.TestSuiteVersion do
  @moduledoc """
  Git-like versioning for test suites.
  """

  @doc """
  Create a new version of test suite.
  """
  def create_version(suite, changelog) do
    # Increment version
    new_version = increment_version(suite.version)

    # Add metadata
    updated_suite = %{suite |
      version: new_version,
      metadata: Map.merge(suite.metadata, %{
        "previous_version" => suite.version,
        "changelog" => changelog,
        "version_date" => DateTime.utc_now() |> DateTime.to_iso8601()
      })
    }

    # Save with version tag
    Pipeline.Evaluation.TestCase.save_suite(updated_suite, suite.name)
  end

  @doc """
  Compare two test suite versions.
  """
  def diff_versions(version1_path, version2_path) do
    {:ok, suite1} = Pipeline.Evaluation.TestCase.load_suite(version1_path)
    {:ok, suite2} = Pipeline.Evaluation.TestCase.load_suite(version2_path)

    %{
      version_1: suite1.version,
      version_2: suite2.version,
      added_tests: find_added(suite1.test_cases, suite2.test_cases),
      removed_tests: find_removed(suite1.test_cases, suite2.test_cases),
      modified_tests: find_modified(suite1.test_cases, suite2.test_cases)
    }
  end

  @doc """
  Revert to previous version.
  """
  def revert_to_version(suite_name, target_version) do
    # Find versioned file
    pattern = "#{suite_name}_v#{target_version}_*.json"
    files = Path.wildcard(pattern)

    case files do
      [file | _] ->
        # Load and mark as latest
        {:ok, suite} = Pipeline.Evaluation.TestCase.load_suite(file)
        Pipeline.Evaluation.TestCase.save_suite(suite, suite_name)

      [] ->
        {:error, :version_not_found}
    end
  end

  # Private functions

  defp increment_version(version) do
    [major, minor] = String.split(version, ".") |> Enum.map(&String.to_integer/1)
    "#{major}.#{minor + 1}"
  end

  defp find_added(old_cases, new_cases) do
    old_ids = MapSet.new(old_cases, & &1.id)

    Enum.filter(new_cases, fn new_case ->
      not MapSet.member?(old_ids, new_case.id)
    end)
  end

  defp find_removed(old_cases, new_cases) do
    new_ids = MapSet.new(new_cases, & &1.id)

    Enum.filter(old_cases, fn old_case ->
      not MapSet.member?(new_ids, old_case.id)
    end)
  end

  defp find_modified(old_cases, new_cases) do
    old_map = Map.new(old_cases, &{&1.id, &1})
    new_map = Map.new(new_cases, &{&1.id, &1})

    common_ids = MapSet.intersection(
      MapSet.new(Map.keys(old_map)),
      MapSet.new(Map.keys(new_map))
    )

    Enum.filter(common_ids, fn id ->
      old_map[id] != new_map[id]
    end)
    |> Enum.map(fn id ->
      %{
        id: id,
        old: old_map[id],
        new: new_map[id]
      }
    end)
  end
end
```

---

## 6. Execution Engine

### 6.1 Parallel Execution

```elixir
defmodule Pipeline.Evaluation.ParallelExecutor do
  @moduledoc """
  Executes test cases in parallel with configurable concurrency.
  """

  @doc """
  Execute test cases with controlled parallelism.
  """
  def execute_parallel(test_cases, config) do
    max_concurrency = config.max_concurrency || System.schedulers_online()

    test_cases
    |> Task.async_stream(
      fn test_case ->
        execute_single_test(test_case, config)
      end,
      max_concurrency: max_concurrency,
      timeout: config.test_timeout || 60_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, :timeout} -> %{error: :timeout}
    end)
  end

  defp execute_single_test(test_case, config) do
    # Rate limiting (if configured)
    if config.rate_limit do
      :timer.sleep(config.rate_limit_delay)
    end

    # Execute test
    # ... (implementation from Orchestrator)
  end
end
```

### 6.2 Progressive Results

```elixir
defmodule Pipeline.Evaluation.ProgressiveResults do
  @moduledoc """
  Stream results as they complete for long-running evaluations.
  """

  def execute_with_streaming(test_cases, config, callback_fn) do
    test_cases
    |> Enum.with_index()
    |> Enum.chunk_every(config.batch_size)
    |> Enum.reduce([], fn batch, acc_results ->
      batch_results =
        batch
        |> Enum.map(fn {test_case, idx} ->
          Task.async(fn ->
            result = execute_test(test_case, idx, config)

            # Emit result immediately
            callback_fn.(result)

            result
          end)
        end)
        |> Task.await_many(60_000)

      acc_results ++ batch_results
    end)
  end
end
```

---

## 7. Result Aggregation & Reporting

### 7.1 Result Aggregator

```elixir
defmodule Pipeline.Evaluation.ResultAggregator do
  @moduledoc """
  Aggregates evaluation results and performs statistical analysis.
  """

  def aggregate(results, config) do
    # Basic stats
    total = length(results)
    passed = Enum.count(results, & &1.passed)
    failed = total - passed

    # Metric statistics
    metric_stats = calculate_metric_stats(results)

    # Regression detection
    regression = detect_regression(metric_stats, config.baseline)

    # Build summary
    %{
      summary: %{
        total_tests: total,
        passed_tests: passed,
        failed_tests: failed,
        pass_rate: Float.round(passed / total * 100, 2),
        avg_duration_ms: avg_duration(results)
      },
      metrics: metric_stats,
      regression_detected: regression.detected,
      regression_details: regression.details,
      failed_tests: Enum.filter(results, &(not &1.passed)),
      all_results: results
    }
  end

  defp calculate_metric_stats(results) do
    # Group by metric type
    results
    |> Enum.flat_map(& &1.metrics)
    |> Enum.group_by(& &1.type)
    |> Map.new(fn {metric_type, metric_results} ->
      scores = Enum.map(metric_results, & &1.score)

      stats = %{
        mean: Statistics.mean(scores),
        median: Statistics.median(scores),
        std_dev: Statistics.std_dev(scores),
        min: Enum.min(scores),
        max: Enum.max(scores),
        p25: Statistics.percentile(scores, 25),
        p75: Statistics.percentile(scores, 75),
        p95: Statistics.percentile(scores, 95)
      }

      {metric_type, stats}
    end)
  end

  defp detect_regression(current_metrics, baseline) when is_map(baseline) do
    # Compare against baseline
    regressions =
      Enum.reduce(current_metrics, [], fn {metric_type, stats}, acc ->
        baseline_mean = get_in(baseline, [to_string(metric_type), "mean"])

        if baseline_mean do
          # Check for significant regression (> 5% drop)
          diff = (stats.mean - baseline_mean) / baseline_mean * 100

          if diff < -5 do
            regression_detail = %{
              metric: metric_type,
              current_mean: stats.mean,
              baseline_mean: baseline_mean,
              percent_change: Float.round(diff, 2)
            }

            [regression_detail | acc]
          else
            acc
          end
        else
          acc
        end
      end)

    %{
      detected: length(regressions) > 0,
      details: regressions
    }
  end

  defp detect_regression(_metrics, nil) do
    %{detected: false, details: []}
  end

  defp avg_duration(results) do
    durations = Enum.map(results, & Map.get(&1, :duration_ms, 0))
    Enum.sum(durations) / length(durations)
  end
end

defmodule Statistics do
  def mean(values), do: Enum.sum(values) / length(values)

  def median(values) do
    sorted = Enum.sort(values)
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end

  def std_dev(values) do
    avg = mean(values)
    variance = Enum.map(values, &:math.pow(&1 - avg, 2)) |> mean()
    :math.sqrt(variance)
  end

  def percentile(values, p) do
    sorted = Enum.sort(values)
    len = length(sorted)
    index = round(p / 100 * (len - 1))
    Enum.at(sorted, index)
  end
end
```

### 7.2 Report Generation

```elixir
defmodule Pipeline.Evaluation.ReportGenerator do
  @moduledoc """
  Generates evaluation reports in multiple formats.
  """

  @doc """
  Generate comprehensive evaluation report.
  """
  def generate_report(aggregated_results, config) do
    # Generate JSON
    json_report = generate_json_report(aggregated_results)

    # Generate HTML (if configured)
    html_report =
      if config.generate_html do
        generate_html_report(aggregated_results)
      end

    # Save to files
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    base_path = "outputs/eval_reports/#{config.eval_id}_#{timestamp}"

    File.mkdir_p!(Path.dirname(base_path))

    # Save JSON
    json_path = "#{base_path}.json"
    File.write!(json_path, Jason.encode!(json_report, pretty: true))

    # Save HTML
    html_path =
      if html_report do
        path = "#{base_path}.html"
        File.write!(path, html_report)
        path
      end

    %{
      json_path: json_path,
      html_path: html_path
    }
  end

  defp generate_json_report(results) do
    %{
      "report_version" => "1.0",
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "summary" => results.summary,
      "metrics" => results.metrics,
      "regression" => %{
        "detected" => results.regression_detected,
        "details" => results.regression_details
      },
      "failed_tests" => format_failed_tests(results.failed_tests),
      "detailed_results" => results.all_results
    }
  end

  defp generate_html_report(results) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Evaluation Report</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .metric { margin: 10px 0; }
        .pass { color: green; }
        .fail { color: red; }
        .regression { background: #ffe0e0; padding: 10px; margin: 10px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
      </style>
    </head>
    <body>
      <h1>Evaluation Report</h1>

      <div class="summary">
        <h2>Summary</h2>
        <p>Total Tests: #{results.summary.total_tests}</p>
        <p class="#{if results.summary.pass_rate >= 80, do: "pass", else: "fail"}">
          Pass Rate: #{results.summary.pass_rate}%
        </p>
        <p>Passed: #{results.summary.passed_tests}</p>
        <p>Failed: #{results.summary.failed_tests}</p>
      </div>

      #{if results.regression_detected do
        render_regression_section(results.regression_details)
      else
        ""
      end}

      <h2>Metrics</h2>
      #{render_metrics_table(results.metrics)}

      <h2>Failed Tests</h2>
      #{render_failed_tests(results.failed_tests)}
    </body>
    </html>
    """
  end

  defp render_regression_section(regressions) do
    """
    <div class="regression">
      <h2>⚠️ Regression Detected</h2>
      #{Enum.map(regressions, fn r ->
        "<p>#{r.metric}: #{r.percent_change}% (from #{r.baseline_mean} to #{r.current_mean})</p>"
      end) |> Enum.join()}
    </div>
    """
  end

  defp render_metrics_table(metrics) do
    """
    <table>
      <tr>
        <th>Metric</th>
        <th>Mean</th>
        <th>Median</th>
        <th>Std Dev</th>
        <th>P25</th>
        <th>P75</th>
        <th>P95</th>
      </tr>
      #{Enum.map(metrics, fn {name, stats} ->
        "<tr>
          <td>#{name}</td>
          <td>#{Float.round(stats.mean, 3)}</td>
          <td>#{Float.round(stats.median, 3)}</td>
          <td>#{Float.round(stats.std_dev, 3)}</td>
          <td>#{Float.round(stats.p25, 3)}</td>
          <td>#{Float.round(stats.p75, 3)}</td>
          <td>#{Float.round(stats.p95, 3)}</td>
        </tr>"
      end) |> Enum.join()}
    </table>
    """
  end

  defp render_failed_tests(failed_tests) do
    if length(failed_tests) == 0 do
      "<p>No failed tests!</p>"
    else
      """
      <table>
        <tr>
          <th>Test ID</th>
          <th>Input</th>
          <th>Expected</th>
          <th>Predicted</th>
          <th>Metrics</th>
        </tr>
        #{Enum.map(failed_tests, fn test ->
          "<tr>
            <td>#{test.test_case_id}</td>
            <td>#{truncate(inspect(test.input), 100)}</td>
            <td>#{truncate(inspect(test.expected), 100)}</td>
            <td>#{truncate(inspect(test.predicted), 100)}</td>
            <td>#{render_metrics_summary(test.metrics)}</td>
          </tr>"
        end) |> Enum.join()}
      </table>
      """
    end
  end

  defp render_metrics_summary(metrics) do
    Enum.map(metrics, fn m ->
      "#{m.type}: #{Float.round(m.score, 2)}"
    end)
    |> Enum.join(", ")
  end

  defp truncate(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp format_failed_tests(failed_tests) do
    Enum.map(failed_tests, fn test ->
      %{
        "test_id" => test.test_case_id,
        "input" => test.input,
        "expected" => test.expected,
        "predicted" => test.predicted,
        "failed_metrics" => Enum.filter(test.metrics, &(not &1.passed))
      }
    end)
  end
end
```

---

## 8. YAML Pipeline Configuration

### 8.1 Eval Pipeline YAML Format

```yaml
# examples/eval_pipelines/qa_evaluation.yaml
workflow:
  name: "qa_system_evaluation"
  description: "Evaluate question-answering pipeline performance"

  config:
    # Evaluation-specific configuration
    test_suite: "test_suites/qa_v2.1.json"
    batch_size: 10
    parallel: true
    max_concurrency: 5
    checkpoint_interval: 2  # Save checkpoint every 2 batches

    # Pipeline under test
    pipeline_under_test:
      path: "pipelines/qa_pipeline.yaml"
      output_step: "generate_answer"

    # Baseline for regression detection
    baseline_path: "baselines/qa_v2.0_baseline.json"

  steps:
    # Step 1: Load and validate test suite
    - name: "load_test_suite"
      type: "eval_load_suite"
      config:
        suite_path: "{{test_suite}}"
        filters:
          category: "customer_support"
          difficulty: ["easy", "medium"]
        sample_size: 100  # Optional: sample subset

    # Step 2: Execute evaluation
    - name: "run_evaluation"
      type: "eval_batch"
      config:
        test_suite: "{{load_test_suite.suite}}"
        pipeline: "{{pipeline_under_test}}"

        # Metrics to calculate
        metrics:
          # LLM-based metrics (Elixir)
          - type: "semantic_similarity"
            threshold: 0.80
            opts:
              model: "claude-sonnet-4"

          - type: "faithfulness"
            threshold: 0.85
            opts:
              source_field: "context"

          - type: "relevance"
            threshold: 0.75
            opts:
              query_field: "question"

          # Python NLP metrics (Snakepit)
          - type: "bleu"
            threshold: 0.40
            opts:
              n_gram: 4

          - type: "rouge"
            threshold: 0.50
            opts:
              rouge_type: "rouge-l"

          - type: "embedding_similarity"
            threshold: 0.75
            opts:
              model: "all-MiniLM-L6-v2"

          # Custom metrics
          - type: "custom:contains_steps"
            threshold: 1.0

        # Execution config
        batch_size: "{{batch_size}}"
        parallel: "{{parallel}}"
        max_concurrency: "{{max_concurrency}}"
        checkpoint_interval: "{{checkpoint_interval}}"

    # Step 3: Aggregate and analyze results
    - name: "aggregate_results"
      type: "eval_aggregate"
      config:
        results: "{{run_evaluation.results}}"
        baseline: "{{baseline_path}}"
        regression_threshold: 5  # % drop triggers regression

    # Step 4: Generate reports
    - name: "generate_reports"
      type: "eval_report"
      config:
        results: "{{aggregate_results}}"
        formats: ["json", "html"]
        output_dir: "outputs/eval_reports"

    # Step 5: Quality gate (optional)
    - name: "quality_gate"
      type: "eval_gate"
      condition: "{{aggregate_results.summary.pass_rate >= 85}}"
      on_failure: "warn"  # or "fail"
      config:
        thresholds:
          pass_rate: 85.0
          semantic_similarity_mean: 0.80
          no_regression: true
```

### 8.2 New Step Types

#### eval_load_suite
```yaml
- name: "load_tests"
  type: "eval_load_suite"
  config:
    suite_path: "path/to/suite.json"
    filters:
      category: "specific_category"
      tags: ["tag1", "tag2"]
    sample_size: 50  # Optional sampling
```

#### eval_batch
```yaml
- name: "evaluate"
  type: "eval_batch"
  config:
    test_suite: "{{previous_step.suite}}"
    pipeline:
      path: "pipeline.yaml"
      output_step: "final_step"
    metrics: [...]
    parallel: true
```

#### eval_aggregate
```yaml
- name: "aggregate"
  type: "eval_aggregate"
  config:
    results: "{{eval_step.results}}"
    baseline: "baseline.json"
```

#### eval_report
```yaml
- name: "report"
  type: "eval_report"
  config:
    results: "{{aggregate.summary}}"
    formats: ["json", "html"]
```

#### eval_gate
```yaml
- name: "gate"
  type: "eval_gate"
  condition: "{{results.pass_rate >= 80}}"
  on_failure: "fail"  # or "warn"
```

---

## 9. Implementation Guide

### 9.1 Phase 1: Core Framework (Week 1-2)

**Files to Create:**
```
lib/pipeline/evaluation/
├── orchestrator.ex          # Main coordinator
├── test_case.ex             # Test case management
├── metrics_calculator.ex    # Metric dispatcher
└── result_aggregator.ex     # Results aggregation
```

**Steps:**
1. Implement `Pipeline.Evaluation.Orchestrator`
2. Implement `Pipeline.Evaluation.TestCase`
3. Add JSON schema validation
4. Add checkpoint support for evaluations
5. Write unit tests

### 9.2 Phase 2: LLM Metrics (Week 2-3)

**Files to Create:**
```
lib/pipeline/evaluation/metrics/
├── llm_judge.ex             # LLM-based evaluation
├── exact_match.ex           # Simple metrics
├── fuzzy_match.ex           # Fuzzy string matching
└── custom.ex                # Custom metric framework
```

**Steps:**
1. Implement LLM-as-judge patterns
2. Add caching for LLM evaluations
3. Implement simple Elixir metrics
4. Create custom metric registry
5. Write integration tests

### 9.3 Phase 3: Python Integration (Week 3-4)

**Files to Create:**
```
lib/pipeline/external/
└── python_bridge.ex         # Snakepit interface

priv/python/
├── eval_metrics.py          # Python implementations
├── requirements.txt         # Dependencies
└── test_metrics.py          # Python tests
```

**Steps:**
1. Set up Snakepit pools
2. Implement Python metric scripts
3. Add health monitoring
4. Implement caching strategy
5. Load and performance testing

### 9.4 Phase 4: Reporting & CLI (Week 4)

**Files to Create:**
```
lib/pipeline/evaluation/
├── report_generator.ex      # Report generation
└── test_suite_version.ex    # Version control

lib/mix/tasks/
└── pipeline.eval.ex         # CLI task
```

**Steps:**
1. Implement report generators
2. Create HTML templates
3. Add Mix task for CLI
4. Add version control for test suites
5. Write end-to-end tests

### 9.5 Testing Strategy

```elixir
# test/pipeline/evaluation/orchestrator_test.exs
defmodule Pipeline.Evaluation.OrchestratorTest do
  use ExUnit.Case, async: false

  alias Pipeline.Evaluation.Orchestrator

  describe "evaluation execution" do
    test "runs simple evaluation suite" do
      config = %{
        test_suite_path: "test/fixtures/simple_suite.json",
        pipeline_config: %{path: "test/fixtures/echo_pipeline.yaml"},
        metrics: [
          %{type: :exact_match, threshold: 1.0}
        ],
        batch_size: 5,
        parallel: false
      }

      {:ok, eval_id} = Orchestrator.start_evaluation(config)

      # Wait for completion
      :timer.sleep(5000)

      {:ok, status} = Orchestrator.get_status(eval_id)
      assert status.status == :completed
      assert status.results.summary.total_tests > 0
    end

    test "handles checkpoint and resume" do
      # Test checkpoint/resume functionality
    end

    test "detects regression against baseline" do
      # Test regression detection
    end
  end
end
```

### 9.6 CLI Usage

```bash
# Run evaluation
mix pipeline.eval run \
  --suite test_suites/qa_v2.1.json \
  --pipeline pipelines/qa_pipeline.yaml \
  --output outputs/eval_$(date +%s)

# Resume from checkpoint
mix pipeline.eval resume eval_12345

# Generate report from results
mix pipeline.eval report \
  --results outputs/eval_12345/results.json \
  --format html

# Compare two evaluation runs
mix pipeline.eval compare \
  --baseline outputs/eval_12345/results.json \
  --current outputs/eval_12346/results.json
```

---

## Conclusion

This specification provides a complete blueprint for implementing a production-grade evaluation pipeline system for `pipeline_ex`. The design:

- ✅ Leverages existing pipeline infrastructure
- ✅ Provides 20+ evaluation metrics (LLM-based + NLP)
- ✅ Supports parallel execution and checkpointing
- ✅ Enables regression detection and A/B testing
- ✅ Generates comprehensive reports
- ✅ Integrates with CI/CD workflows

**Next Steps:**
1. Review and approve design
2. Begin Phase 1 implementation
3. Iterate based on feedback
4. Deploy to production

---

**Document Status:** Ready for Implementation
**Estimated Implementation Time:** 4-6 weeks
**Dependencies:** Snakepit integration, existing checkpoint system
