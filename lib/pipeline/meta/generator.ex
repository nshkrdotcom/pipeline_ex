defmodule Pipeline.Meta.Generator do
  @moduledoc """
  Pipeline generator that transforms DNA into executable pipeline configurations.
  This is the core engine that brings pipeline organisms to life.
  """

  alias Pipeline.Meta.DNA
  require Logger

  @doc """
  Generates a pipeline YAML configuration from DNA
  """
  def generate_from_dna(%DNA{} = dna) do
    %{
      "name" => dna.name,
      "description" => generate_description(dna),
      "version" => "#{dna.generation}.0.0",
      "metadata" => build_metadata(dna),
      "steps" => generate_steps(dna)
    }
    |> to_yaml()
  end

  @doc """
  Generates a pipeline from a request using the Genesis Pipeline
  """
  def generate_from_request(request) do
    # This would execute the genesis pipeline with the request
    # For now, we'll simulate the pipeline execution
    {:ok, simulate_genesis_pipeline(request)}
  end

  defp generate_description(dna) do
    traits = Enum.join(dna.dominant_traits, ", ")
    "Generated pipeline with traits: #{traits}. Generation: #{dna.generation}"
  end

  defp build_metadata(dna) do
    %{
      "dna_id" => dna.id,
      "generation" => dna.generation,
      "lineage" => dna.lineage,
      "performance_profile" => dna.optimization_chromosome.performance_profile,
      "complexity" => calculate_complexity(dna)
    }
  end

  defp generate_steps(dna) do
    dna.structural_chromosome.step_sequences
    |> Enum.map(&transform_step(&1, dna))
    |> add_error_handling(dna.behavioral_chromosome)
    |> optimize_steps(dna.optimization_chromosome)
  end

  defp transform_step(step_spec, dna) do
    base_step = %{
      "name" => step_spec["step_name"],
      "type" => step_spec["step_type"],
      "prompt" => generate_prompt(step_spec, dna)
    }

    # Add provider-specific configuration
    case step_spec["step_type"] do
      "claude" <> _ -> add_claude_config(base_step, dna)
      "gemini" <> _ -> add_gemini_config(base_step, dna)
      _ -> base_step
    end
  end

  defp generate_prompt(step_spec, dna) do
    # Find matching prompt pattern
    pattern = find_prompt_pattern(step_spec["purpose"], dna.structural_chromosome.prompt_patterns)

    if pattern do
      apply_prompt_pattern(pattern, step_spec)
    else
      generate_default_prompt(step_spec)
    end
  end

  defp find_prompt_pattern(purpose, patterns) do
    Enum.find(patterns, fn pattern ->
      String.contains?(purpose, pattern["pattern_type"])
    end)
  end

  defp apply_prompt_pattern(pattern, step_spec) do
    pattern["template"]
    |> String.replace("{{purpose}}", step_spec["purpose"])
    |> String.replace("{{step_name}}", step_spec["step_name"])
  end

  defp generate_default_prompt(step_spec) do
    """
    #{step_spec["purpose"]}

    Process the input and provide a detailed response.
    """
  end

  defp add_claude_config(step, dna) do
    config = %{
      "model" => select_claude_model(dna),
      "max_tokens" => calculate_max_tokens(dna),
      "temperature" => calculate_temperature(dna)
    }

    Map.put(step, "config", config)
  end

  defp add_gemini_config(step, dna) do
    config = %{
      "model" => select_gemini_model(dna),
      "generation_config" => %{
        "temperature" => calculate_temperature(dna),
        "max_output_tokens" => calculate_max_tokens(dna)
      }
    }

    Map.put(step, "config", config)
  end

  defp select_claude_model(dna) do
    case dna.optimization_chromosome.performance_profile do
      "speed_optimized" -> "claude-opus-4-20250514"
      "accuracy_optimized" -> "claude-opus-4-20250514"
      _ -> "claude-opus-4-20250514"
    end
  end

  defp select_gemini_model(dna) do
    case dna.optimization_chromosome.performance_profile do
      "speed_optimized" -> "gemini-2.5-flash"
      "accuracy_optimized" -> "gemini-2.5-pro"
      _ -> "gemini-2.5-flash-lite-preview-06-17"
    end
  end

  defp calculate_max_tokens(dna) do
    base_tokens = 2048

    # Adjust based on token conservation
    conservation_factor = dna.optimization_chromosome.token_conservation

    round(base_tokens * (2.0 - conservation_factor))
  end

  defp calculate_temperature(dna) do
    # Higher innovation index = higher temperature
    base_temp = 0.7
    innovation_adjustment = dna.innovation_index * 0.3

    min(base_temp + innovation_adjustment, 1.0)
  end

  defp add_error_handling(steps, behavioral_chromosome) do
    case behavioral_chromosome.error_handling_strategy do
      "retry_robust" ->
        Enum.map(steps, &add_retry_config/1)

      "graceful_degradation" ->
        Enum.map(steps, &add_fallback_config/1)

      _ ->
        steps
    end
  end

  defp add_retry_config(step) do
    Map.put(step, "retry", %{
      "max_attempts" => 3,
      "backoff" => "exponential"
    })
  end

  defp add_fallback_config(step) do
    Map.put(step, "on_error", %{
      "action" => "continue",
      "default_value" => %{"error" => "Step failed gracefully"}
    })
  end

  defp optimize_steps(steps, optimization_chromosome) do
    steps
    |> maybe_add_caching(optimization_chromosome)
    |> maybe_parallelize(optimization_chromosome)
  end

  defp maybe_add_caching(steps, optimization_chromosome) do
    if optimization_chromosome.caching_aggressiveness > 0.5 do
      Enum.map(steps, fn step ->
        Map.put(step, "cache", %{
          "enabled" => true,
          "ttl_seconds" => 3600
        })
      end)
    else
      steps
    end
  end

  defp maybe_parallelize(steps, optimization_chromosome) do
    if "parallel_execution" in optimization_chromosome.preferences do
      # Group independent steps for parallel execution
      # This is a simplified version - real implementation would analyze dependencies
      steps
    else
      steps
    end
  end

  defp calculate_complexity(dna) do
    step_count = length(dna.structural_chromosome.step_sequences)

    cond do
      step_count <= 3 -> "simple"
      step_count <= 7 -> "moderate"
      true -> "complex"
    end
  end

  defp to_yaml(pipeline_map) do
    # In a real implementation, we'd use a YAML library
    # For now, we'll create a simple YAML-like string
    """
    name: #{pipeline_map["name"]}
    description: #{pipeline_map["description"]}
    version: #{pipeline_map["version"]}

    metadata:
      dna_id: #{pipeline_map["metadata"]["dna_id"]}
      generation: #{pipeline_map["metadata"]["generation"]}
      performance_profile: #{pipeline_map["metadata"]["performance_profile"]}
      complexity: #{pipeline_map["metadata"]["complexity"]}

    steps:
    #{format_steps(pipeline_map["steps"])}
    """
  end

  defp format_steps(steps) do
    steps
    |> Enum.map(&format_step/1)
    |> Enum.join("\n")
  end

  defp format_step(step) do
    """
      - name: #{step["name"]}
        type: #{step["type"]}
        prompt: |
          #{step["prompt"]}
    """
  end

  # Mock/fallback function to simulate genesis pipeline execution
  defp simulate_genesis_pipeline(request) do
    # Analyze the request to determine pipeline type
    pipeline_type = infer_pipeline_type(request)

    %{
      "pipeline_yaml" => generate_mock_pipeline(request, pipeline_type),
      "documentation" => generate_mock_documentation(request, pipeline_type),
      "dna" => %{
        "id" => "mock-" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)),
        "traits" => infer_traits(request),
        "generation" => 0,
        "performance_profile" => "balanced"
      }
    }
  end

  defp infer_pipeline_type(request) do
    request_lower = String.downcase(request)

    cond do
      String.contains?(request_lower, ["analyze", "analysis", "examine"]) -> :analysis
      String.contains?(request_lower, ["generate", "create", "build"]) -> :generation
      String.contains?(request_lower, ["process", "transform", "convert"]) -> :processing
      String.contains?(request_lower, ["extract", "parse", "read"]) -> :extraction
      String.contains?(request_lower, ["summarize", "summary", "brief"]) -> :summarization
      true -> :general
    end
  end

  defp generate_mock_pipeline(request, pipeline_type) do
    steps =
      case pipeline_type do
        :analysis -> mock_analysis_steps(request)
        :generation -> mock_generation_steps(request)
        :processing -> mock_processing_steps(request)
        :extraction -> mock_extraction_steps(request)
        :summarization -> mock_summarization_steps(request)
        :general -> mock_general_steps(request)
      end

    """
    name: #{generate_pipeline_name(request)}
    description: "Mock-generated pipeline for: #{request}"
    version: "1.0.0"

    metadata:
      generated_by: genesis_pipeline_mock
      request: "#{request}"
      pipeline_type: #{pipeline_type}
      complexity: moderate

    steps:
    #{steps}
    """
  end

  defp mock_analysis_steps(request) do
    """
      - name: data_collection
        type: claude_smart
        prompt: |
          Collect and organize data for analysis:
          {{input_data}}
          
          Focus on gathering relevant information for: #{request}
          
      - name: perform_analysis
        type: claude_robust
        prompt: |
          Analyze the collected data:
          {{steps.data_collection.result}}
          
          Provide comprehensive analysis including:
          1. Key findings
          2. Patterns and trends
          3. Insights and implications
          
      - name: generate_report
        type: claude_extract
        prompt: |
          Generate analysis report:
          {{steps.perform_analysis.result}}
        schema:
          report:
            summary: string
            findings: array
            recommendations: array
            confidence_score: number
    """
  end

  defp mock_generation_steps(request) do
    """
      - name: understand_requirements
        type: claude_smart
        prompt: |
          Understand the generation requirements:
          {{requirements}}
          
          For request: #{request}
          
      - name: generate_content
        type: claude_robust
        prompt: |
          Generate content based on requirements:
          {{steps.understand_requirements.result}}
          
          Ensure the generated content is:
          1. Relevant and accurate
          2. Well-structured
          3. Complete and comprehensive
          
      - name: review_and_refine
        type: claude_smart
        prompt: |
          Review and refine the generated content:
          {{steps.generate_content.result}}
          
          Make improvements for quality and clarity.
    """
  end

  defp mock_processing_steps(request) do
    """
      - name: input_validation
        type: claude_smart
        prompt: |
          Validate and prepare input for processing:
          {{input}}
          
          For processing task: #{request}
          
      - name: data_processing
        type: claude_batch
        prompts:
          - "Process data chunk 1: {{chunk_1}}"
          - "Process data chunk 2: {{chunk_2}}"
          - "Process data chunk 3: {{chunk_3}}"
          
      - name: output_formatting
        type: claude_extract
        prompt: |
          Format processed results:
          {{steps.data_processing.results}}
        schema:
          processed_data:
            results: array
            metadata: object
            summary: string
    """
  end

  defp mock_extraction_steps(request) do
    """
      - name: source_analysis
        type: claude_smart
        prompt: |
          Analyze source material for extraction:
          {{source_data}}
          
          For extraction task: #{request}
          
      - name: extract_information
        type: claude_extract
        prompt: |
          Extract relevant information:
          {{steps.source_analysis.result}}
        schema:
          extracted_data:
            entities: array
            relationships: array
            metadata: object
            
      - name: validate_extraction
        type: claude_robust
        prompt: |
          Validate and clean extracted information:
          {{steps.extract_information.result}}
          
          Ensure accuracy and completeness.
    """
  end

  defp mock_summarization_steps(request) do
    """
      - name: content_analysis
        type: claude_smart
        prompt: |
          Analyze content for summarization:
          {{content}}
          
          For task: #{request}
          
      - name: generate_summary
        type: claude_robust
        prompt: |
          Generate comprehensive summary:
          {{steps.content_analysis.result}}
          
          Create summary that captures:
          1. Main points
          2. Key details
          3. Important conclusions
          
      - name: refine_summary
        type: claude_smart
        prompt: |
          Refine and optimize summary:
          {{steps.generate_summary.result}}
          
          Ensure clarity and conciseness.
    """
  end

  defp mock_general_steps(request) do
    """
      - name: understand_task
        type: claude_smart
        prompt: |
          Understand the task requirements:
          {{input}}
          
          Task: #{request}
          
      - name: execute_task
        type: claude_robust
        prompt: |
          Execute the requested task:
          {{steps.understand_task.result}}
          
          Provide comprehensive and accurate results.
          
      - name: validate_results
        type: claude_smart
        prompt: |
          Validate and finalize results:
          {{steps.execute_task.result}}
          
          Ensure quality and completeness.
    """
  end

  defp generate_pipeline_name(request) do
    request
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.split()
    |> Enum.take(3)
    |> Enum.join("_")
    |> then(fn name -> if name == "", do: "generated_pipeline", else: name end)
  end

  defp generate_mock_documentation(request, pipeline_type) do
    %{
      "pipeline_name" => generate_pipeline_name(request),
      "description" => "Mock-generated pipeline for: #{request}",
      "purpose" => "#{pipeline_type} pipeline",
      "usage" => %{
        "basic_usage" => "mix pipeline.run #{generate_pipeline_name(request)}.yaml",
        "example_command" =>
          "mix pipeline.run #{generate_pipeline_name(request)}.yaml --input data.json",
        "required_inputs" => ["input data relevant to: #{request}"],
        "expected_outputs" => ["processed results", "analysis report", "generated content"]
      },
      "performance" => %{
        "estimated_execution_time" => "2-5 minutes",
        "token_usage_estimate" => "500-2000 tokens",
        "cost_estimate" => "$0.01-0.05"
      }
    }
  end

  defp infer_traits(request) do
    traits = ["mock_generated"]
    request_lower = String.downcase(request)

    traits =
      if String.contains?(request_lower, ["fast", "quick", "speed"]) do
        ["speed_optimized" | traits]
      else
        traits
      end

    traits =
      if String.contains?(request_lower, ["accurate", "precise", "detailed"]) do
        ["accuracy_optimized" | traits]
      else
        traits
      end

    traits =
      if String.contains?(request_lower, ["complex", "comprehensive", "advanced"]) do
        ["complex_processing" | traits]
      else
        traits
      end

    traits
  end
end
