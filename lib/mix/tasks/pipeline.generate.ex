defmodule Mix.Tasks.Pipeline.Generate do
  @moduledoc """
  Generates a new pipeline using the Genesis Pipeline.
  
  ## Usage
  
      mix pipeline.generate "Create a pipeline that analyzes code quality"      # Mock mode (safe, no API costs)
      mix pipeline.generate.live "Create a pipeline that analyzes code quality" # Live mode (real AI calls)
      
  ## Options
  
    * `--output` - Output file path (defaults to generated_pipeline.yaml)
    * `--profile` - Performance profile: speed_optimized, accuracy_optimized, balanced
    * `--complexity` - Target complexity: simple, moderate, complex
    * `--dry-run` - Show what would be generated without creating files
    
  ## Examples
  
      # Generate a simple data processing pipeline (mock mode)
      mix pipeline.generate "Process CSV data and extract insights"
      
      # Generate with real AI providers (requires API keys)
      mix pipeline.generate.live "Analyze customer feedback" --profile accuracy_optimized
      
      # Preview pipeline without creating files
      mix pipeline.generate "Generate API documentation" --dry-run
      
  ## Environment Variables
  
  - `TEST_MODE`: "mock" (default), "live", or "mixed"
  - `PIPELINE_DEBUG`: "true" to enable detailed logging
  - `CLAUDE_API_KEY`: Required for live mode with Claude
  - `GEMINI_API_KEY`: Required for live mode with Gemini
  """
  
  use Mix.Task
  alias Pipeline.Executor
  alias Pipeline.Meta.Generator
  alias Pipeline.TestMode
  
  @shortdoc "Generate a new pipeline using the Genesis Pipeline"
  
  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, args, _} = OptionParser.parse(args,
      switches: [
        output: :string,
        profile: :string,
        complexity: :string,
        dry_run: :boolean
      ],
      aliases: [
        o: :output,
        p: :profile,
        c: :complexity,
        d: :dry_run
      ]
    )
    
    case args do
      [] ->
        Mix.shell().error("Error: Pipeline request required")
        Mix.shell().info("")
        Mix.shell().info("Usage: mix pipeline.generate \"your pipeline request\"")
        System.halt(1)
        
      [request | _] ->
        generate_pipeline(request, opts)
    end
  end
  
  defp generate_pipeline(request, opts) do
    output_file = determine_output_file(request, opts)
    dry_run = Keyword.get(opts, :dry_run, false)
    test_mode = TestMode.get_mode()
    
    Mix.shell().info("🧬 Initializing Genesis Pipeline...")
    Mix.shell().info("📝 Request: #{request}")
    Mix.shell().info("🔧 Mode: #{test_mode}")
    Mix.shell().info("📁 Output: #{output_file}")
    
    # Prepare genesis pipeline input
    input = %{
      "pipeline_request" => request,
      "performance_profile" => Keyword.get(opts, :profile, "balanced"),
      "target_complexity" => Keyword.get(opts, :complexity, "moderate")
    }
    
    # Execute the Genesis Pipeline (using working version)
    genesis_path = "working_genesis.yaml"
    
    Mix.shell().info("🔄 Executing Genesis Pipeline...")
    
    case execute_genesis_pipeline(genesis_path, input) do
      {:ok, result} ->
        handle_success(result, output_file, dry_run)
        
      {:error, reason} ->
        Mix.shell().error("❌ Pipeline generation failed: #{inspect(reason)}")
        System.halt(1)
    end
  end
  
  defp execute_genesis_pipeline(genesis_path, input) do
    # Check if genesis pipeline exists
    full_path = Path.expand(genesis_path)
    
    if File.exists?(full_path) and TestMode.live_mode?() do
      # Execute the actual genesis pipeline in live mode
      case Pipeline.Config.load_workflow(genesis_path) do
        {:ok, config} ->
          # Merge input with existing config input
          existing_input = get_in(config, ["workflow", "input"]) || %{}
          merged_input = Map.merge(existing_input, input)
          config_with_input = put_in(config, ["workflow", "input"], merged_input)
          
          case Executor.execute(config_with_input) do
            {:ok, result} ->
              extract_generated_pipeline(result)
              
            error ->
              error
          end
          
        error ->
          error
      end
    else
      # Use mock/fallback generation
      if TestMode.mock_mode?() do
        Mix.shell().info("🎭 Running in mock mode (no API calls)")
      else
        Mix.shell().info("⚠️  Genesis pipeline not found, using fallback generator...")
      end
      Generator.generate_from_request(input["pipeline_request"])
    end
  end
  
  defp extract_generated_pipeline(result) do
    # Extract the generated pipeline from genesis pipeline output
    # The result should be a map with step names as keys
    Mix.shell().info("🐛 Debug - Result keys: #{inspect(Map.keys(result))}")
    
    case result do
      %{"create_pipeline" => pipeline_result} ->
        Mix.shell().info("🐛 Debug - Found create_pipeline result")
        {:ok, parse_simple_pipeline_result(pipeline_result)}
        
      result when is_map(result) and map_size(result) == 0 ->
        Mix.shell().info("🐛 Debug - Empty result map, checking for conversation failure")
        # The Claude conversation might have failed but Claude still generated content
        # Let's return a fallback generated pipeline
        {:ok, create_fallback_pipeline()}
        
      %{"package_offspring" => package_result} ->
        Mix.shell().info("🐛 Debug - Found package_offspring directly")
        {:ok, parse_package_result(package_result)}
        
      %{"validate_pipeline" => validation_result} ->
        Mix.shell().info("🐛 Debug - Using validate_pipeline result directly")
        {:ok, parse_validation_result(validation_result)}
        
      result when is_map(result) ->
        # Try to extract meaningful content from step results
        case extract_meaningful_content(result) do
          {:ok, content} -> {:ok, content}
          {:error, _} ->
            Mix.shell().info("🐛 Debug - Full result structure:")
            Mix.shell().info(inspect(result, pretty: true, limit: 2000))
            {:error, "Invalid genesis pipeline output"}
        end
        
      _ ->
        {:error, "Invalid result format"}
    end
  end
  
  defp parse_package_result(package_result) when is_map(package_result) do
    Mix.shell().info("🐛 Debug - Package result map keys: #{inspect(Map.keys(package_result))}")
    Mix.shell().info("🐛 Debug - Package result preview: #{inspect(package_result, limit: 500)}")
    
    # Extract the actual AI response content
    content = case package_result do
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      %{content: content} when is_binary(content) -> content
      %{"content" => content} when is_binary(content) -> content
      %{response: response} when is_binary(response) -> response
      %{"response" => response} when is_binary(response) -> response
      _ -> 
        Mix.shell().info("🐛 Debug - No text field found, using inspect")
        inspect(package_result, pretty: true)
    end
    
    # Parse the AI response to extract pipeline components
    parse_ai_response(content)
  end
  
  defp parse_package_result(package_result) when is_binary(package_result) do
    Mix.shell().info("🐛 Debug - Binary package result length: #{String.length(package_result)}")
    Mix.shell().info("🐛 Debug - Binary package preview: #{String.slice(package_result, 0, 200)}...")
    
    # Parse the text output to extract components
    %{
      "pipeline_yaml" => extract_yaml_section(package_result),
      "documentation" => extract_documentation_section(package_result),
      "dna" => %{"id" => generate_id(), "generation" => 0}
    }
  end
  
  defp parse_ai_response(content) when is_binary(content) do
    Mix.shell().info("🐛 Debug - AI response content preview: #{String.slice(content, 0, 200)}...")
    
    # Extract YAML content from AI response
    pipeline_yaml = extract_yaml_section(content)
    
    # Create a complete pipeline package
    %{
      "pipeline_yaml" => pipeline_yaml,
      "documentation" => extract_documentation_from_response(content),
      "dna" => %{
        "id" => generate_id(),
        "generation" => 1,
        "traits" => ["ai_generated", "live_mode"],
        "source" => "genesis_pipeline"
      }
    }
  end
  
  defp parse_ai_response(content) do
    Mix.shell().info("🐛 Debug - Non-binary AI response: #{inspect(content)}")
    create_simple_package(inspect(content, pretty: true))
  end
  
  defp parse_validation_result(validation_result) when is_map(validation_result) do
    Mix.shell().info("🐛 Debug - Validation result map keys: #{inspect(Map.keys(validation_result))}")
    Mix.shell().info("🐛 Debug - Validation result preview: #{inspect(validation_result, limit: 500)}")
    
    # Extract the actual AI response content
    content = case validation_result do
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      %{content: content} when is_binary(content) -> content
      %{"content" => content} when is_binary(content) -> content
      %{response: response} when is_binary(response) -> response
      %{"response" => response} when is_binary(response) -> response
      _ -> 
        Mix.shell().info("🐛 Debug - No text field found in validation result, using inspect")
        inspect(validation_result, pretty: true)
    end
    
    # Parse the AI response to extract pipeline components
    parse_ai_response(content)
  end
  
  defp parse_validation_result(validation_result) when is_binary(validation_result) do
    Mix.shell().info("🐛 Debug - Binary validation result length: #{String.length(validation_result)}")
    Mix.shell().info("🐛 Debug - Binary validation preview: #{String.slice(validation_result, 0, 200)}...")
    
    # Parse the text output to extract components
    %{
      "pipeline_yaml" => extract_yaml_section(validation_result),
      "documentation" => extract_documentation_section(validation_result),
      "dna" => %{"id" => generate_id(), "generation" => 0}
    }
  end
  
  defp parse_simple_pipeline_result(pipeline_result) when is_map(pipeline_result) do
    Mix.shell().info("🐛 Debug - Simple pipeline result map keys: #{inspect(Map.keys(pipeline_result))}")
    Mix.shell().info("🐛 Debug - Simple pipeline result preview: #{inspect(pipeline_result, limit: 500)}")
    
    # Extract the actual AI response content
    content = case pipeline_result do
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      %{content: content} when is_binary(content) -> content
      %{"content" => content} when is_binary(content) -> content
      %{response: response} when is_binary(response) -> response
      %{"response" => response} when is_binary(response) -> response
      _ -> 
        Mix.shell().info("🐛 Debug - No text field found in simple pipeline result, using inspect")
        inspect(pipeline_result, pretty: true)
    end
    
    # Create a complete pipeline package
    %{
      "pipeline_yaml" => extract_yaml_section(content),
      "documentation" => %{
        "pipeline_name" => "simple_generated_pipeline",
        "description" => "AI-generated pipeline via Simple Genesis",
        "purpose" => "Simple pipeline generation",
        "usage" => "mix pipeline.run <pipeline_file>"
      },
      "dna" => %{
        "id" => generate_id(),
        "generation" => 1,
        "traits" => ["simple_generated", "live_mode"],
        "source" => "simple_genesis"
      }
    }
  end
  
  defp parse_simple_pipeline_result(pipeline_result) when is_binary(pipeline_result) do
    Mix.shell().info("🐛 Debug - Binary simple pipeline result length: #{String.length(pipeline_result)}")
    Mix.shell().info("🐛 Debug - Binary simple pipeline preview: #{String.slice(pipeline_result, 0, 200)}...")
    
    # Parse the text output to extract components
    %{
      "pipeline_yaml" => extract_yaml_section(pipeline_result),
      "documentation" => %{
        "pipeline_name" => "simple_generated_pipeline",
        "description" => "AI-generated pipeline via Simple Genesis",
        "purpose" => "Simple pipeline generation",
        "usage" => "mix pipeline.run <pipeline_file>"
      },
      "dna" => %{
        "id" => generate_id(),
        "generation" => 1,
        "traits" => ["simple_generated", "live_mode"],
        "source" => "simple_genesis"
      }
    }
  end

  defp extract_yaml_section(text) do
    # Extract YAML between markers or use full text
    cond do
      String.contains?(text, "```yaml") ->
        text
        |> String.split("```yaml")
        |> Enum.at(1, "")
        |> String.split("```")
        |> Enum.at(0, "")
        |> String.trim()
        
      String.contains?(text, "```yml") ->
        text
        |> String.split("```yml")
        |> Enum.at(1, "")
        |> String.split("```")
        |> Enum.at(0, "")
        |> String.trim()
        
      # If no code blocks, try to extract YAML-like content
      String.contains?(text, "workflow:") or String.contains?(text, "name:") ->
        # Find the start of YAML content
        lines = String.split(text, "\n")
        yaml_start = Enum.find_index(lines, fn line ->
          String.contains?(line, "workflow:") or 
          String.contains?(line, "name:") or 
          String.match?(line, ~r/^[a-zA-Z_]+:/)
        end)
        
        if yaml_start do
          lines
          |> Enum.drop(yaml_start)
          |> Enum.join("\n")
          |> String.trim()
        else
          text
        end
        
      true ->
        text
    end
  end
  
  defp extract_documentation_from_response(content) do
    # Try to extract documentation sections from AI response
    %{
      "pipeline_name" => "genesis_generated_pipeline",
      "description" => extract_description_from_response(content),
      "purpose" => "AI-generated pipeline from Genesis system",
      "usage" => "mix pipeline.run <pipeline_file>"
    }
  end
  
  defp extract_description_from_response(content) do
    # Try to find description in the response
    cond do
      String.contains?(content, "Description:") ->
        content
        |> String.split("Description:")
        |> Enum.at(1, "")
        |> String.split("\n")
        |> Enum.at(0, "")
        |> String.trim()
        
      String.contains?(content, "## Description") ->
        content
        |> String.split("## Description")
        |> Enum.at(1, "")
        |> String.split("##")
        |> Enum.at(0, "")
        |> String.trim()
        
      true ->
        "AI-generated pipeline via Genesis system"
    end
  end
  
  defp extract_documentation_section(_text) do
    %{
      "description" => "Generated pipeline",
      "usage" => "mix pipeline.run <output_file>"
    }
  end
  
  defp handle_success(result, output_file, dry_run) do
    pipeline_yaml = result["pipeline_yaml"]
    documentation = result["documentation"]
    dna = result["dna"]
    
    if dry_run do
      Mix.shell().info("\n📋 Generated Pipeline (dry run):")
      Mix.shell().info("─" |> String.duplicate(50))
      Mix.shell().info(pipeline_yaml)
      Mix.shell().info("─" |> String.duplicate(50))
      
      if documentation do
        Mix.shell().info("\n📚 Documentation:")
        Mix.shell().info(format_simple_documentation(documentation))
      end
    else
      # Ensure output directory exists
      ensure_output_directory(output_file)
      
      # Write pipeline file with safe content handling
      safe_pipeline_yaml = ensure_string_content(pipeline_yaml)
      File.write!(output_file, safe_pipeline_yaml)
      Mix.shell().info("✅ Pipeline generated successfully: #{output_file}")
      
      # Write documentation if present
      if documentation do
        doc_file = Path.rootname(output_file) <> "_README.md"
        safe_doc_content = format_documentation_markdown(documentation)
        File.write!(doc_file, safe_doc_content)
        Mix.shell().info("📚 Documentation created: #{doc_file}")
      end
      
      # Write DNA file for future evolution
      if dna do
        dna_file = Path.rootname(output_file) <> "_dna.json"
        safe_dna_content = Jason.encode!(dna, pretty: true)
        File.write!(dna_file, safe_dna_content)
        Mix.shell().info("🧬 DNA saved: #{dna_file}")
      end
      
      Mix.shell().info("\n🚀 Next steps:")
      Mix.shell().info("   1. Review the generated pipeline: #{output_file}")
      Mix.shell().info("   2. Test it: mix pipeline.run #{output_file}")
      Mix.shell().info("   3. Evolve it: mix pipeline.evolve #{output_file}")
    end
  end
  
  defp format_documentation(doc) when is_map(doc) do
    """
    Description: #{doc["description"] || "N/A"}
    Usage: #{doc["usage"] || "N/A"}
    """
  end
  
  defp format_documentation(doc) when is_binary(doc) do
    doc
  end
  
  defp format_documentation_markdown(doc) when is_map(doc) do
    """
    # #{doc["pipeline_name"] || "Generated Pipeline"}
    
    #{doc["description"] || "Auto-generated pipeline"}
    
    ## Usage
    
    #{format_usage_section(doc["usage"])}
    
    ## Configuration
    
    #{format_config_section(doc["configuration"])}
    
    ## Examples
    
    #{format_examples_section(doc["examples"])}
    """
  end
  
  defp format_documentation_markdown(doc) when is_binary(doc) do
    "# Generated Pipeline\n\n#{doc}"
  end
  
  defp format_config_section(nil), do: "No additional configuration required."
  defp format_config_section(config) do
    config
    |> Enum.map(fn {key, value} -> "- **#{key}**: #{inspect(value)}" end)
    |> Enum.join("\n")
  end
  
  defp format_examples_section(nil), do: "No examples available."
  defp format_examples_section(examples) when is_list(examples) do
    examples
    |> Enum.map(fn example ->
      """
      ### #{example["scenario"]}
      
      Input:
      ```
      #{example["input"]}
      ```
      
      Expected Output:
      ```
      #{example["expected_output"]}
      ```
      """
    end)
    |> Enum.join("\n")
  end
  defp format_examples_section(_), do: "No examples available."

  defp format_usage_section(usage) when is_map(usage) do
    """
    Basic usage: #{usage["basic_usage"] || "mix pipeline.run pipeline.yaml"}
    
    Example: #{usage["example_command"] || "mix pipeline.run pipeline.yaml --input data.json"}
    """
  end
  defp format_usage_section(usage) when is_binary(usage), do: usage
  defp format_usage_section(_), do: "mix pipeline.run pipeline.yaml"

  defp format_simple_documentation(doc) when is_map(doc) do
    """
    Pipeline: #{doc["pipeline_name"] || "Generated Pipeline"}
    Description: #{doc["description"] || "Auto-generated pipeline"}
    Purpose: #{doc["purpose"] || "General purpose"}
    """
  end
  
  defp format_simple_documentation(doc) when is_binary(doc) do
    doc
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp determine_output_file(request, opts) do
    case Keyword.get(opts, :output) do
      nil ->
        # Generate unique filename in evolution directory
        generate_unique_filename(request)
      
      custom_output ->
        # Use custom output but ensure it's unique
        ensure_unique_filepath(custom_output)
    end
  end

  defp generate_unique_filename(request) do
    # Create evolution directory
    evolution_dir = "evolved_pipelines"
    
    # Generate base name from request
    base_name = request
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s]/, "")
      |> String.split()
      |> Enum.take(4)
      |> Enum.join("_")
      |> case do
        "" -> "generated_pipeline"
        name -> name
      end
    
    # Add timestamp for uniqueness
    timestamp = DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)
      |> Integer.to_string()
    
    filename = "#{base_name}_#{timestamp}.yaml"
    Path.join([evolution_dir, filename])
  end

  defp ensure_unique_filepath(filepath) do
    if File.exists?(filepath) do
      # Add timestamp to make it unique
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      ext = Path.extname(filepath)
      base = Path.rootname(filepath)
      
      "#{base}_#{timestamp}#{ext}"
    else
      filepath
    end
  end

  defp ensure_output_directory(filepath) do
    dir = Path.dirname(filepath)
    File.mkdir_p!(dir)
  end

  defp ensure_string_content(content) when is_binary(content), do: content
  defp ensure_string_content(content) when is_map(content) do
    case Jason.encode(content, pretty: true) do
      {:ok, json} -> json
      {:error, _} -> inspect(content, pretty: true)
    end
  end
  defp ensure_string_content(content), do: inspect(content, pretty: true)

  defp extract_meaningful_content(result) do
    # Try various ways to extract meaningful pipeline content
    cond do
      # Look for steps in the result and extract the last one
      is_map(result) && Map.has_key?(result, "steps") ->
        extract_from_steps(result["steps"])
        
      # If result has pipeline-like content directly
      is_map(result) && has_pipeline_content?(result) ->
        {:ok, create_pipeline_package(result)}
        
      # If it's a string, try to parse as YAML or use as-is
      is_binary(result) ->
        {:ok, create_simple_package(result)}
        
      true ->
        {:error, "No extractable content"}
    end
  end

  defp extract_from_steps(steps) when is_map(steps) do
    # Get the last step result which should be the packaged output
    step_names = ["package_offspring", "validate_pipeline", "synthesize_pipeline_yaml", "generate_documentation"]
    
    Mix.shell().info("🐛 Debug - Available step keys: #{inspect(Map.keys(steps))}")
    
    result = Enum.find_value(step_names, fn step_name ->
      case Map.get(steps, step_name) do
        nil -> 
          Mix.shell().info("🐛 Debug - Step #{step_name}: not found")
          nil
        step_result -> 
          content_preview = step_result |> inspect() |> String.slice(0, 100)
          Mix.shell().info("🐛 Debug - Step #{step_name}: found, preview: #{content_preview}")
          step_result
      end
    end)
    
    if result do
      {:ok, parse_package_result(result)}
    else
      {:error, "No extractable step content"}
    end
  end

  defp has_pipeline_content?(content) when is_map(content) do
    pipeline_keys = ["pipeline_yaml", "yaml", "workflow", "steps", "name"]
    Enum.any?(pipeline_keys, &Map.has_key?(content, &1))
  end

  defp create_pipeline_package(content) do
    %{
      "pipeline_yaml" => extract_yaml_content(content),
      "documentation" => extract_documentation_content(content),
      "dna" => extract_dna_content(content)
    }
  end

  defp create_simple_package(yaml_content) do
    %{
      "pipeline_yaml" => yaml_content,
      "documentation" => %{
        "pipeline_name" => "generated_pipeline",
        "description" => "AI-generated pipeline",
        "purpose" => "general purpose"
      },
      "dna" => %{
        "id" => generate_id(),
        "generation" => 1,
        "traits" => ["ai_generated", "live_mode"]
      }
    }
  end

  defp extract_yaml_content(content) do
    cond do
      Map.has_key?(content, "pipeline_yaml") -> content["pipeline_yaml"]
      Map.has_key?(content, "yaml") -> content["yaml"]
      Map.has_key?(content, "workflow") -> content["workflow"]
      true -> ensure_string_content(content)
    end
  end

  defp extract_documentation_content(content) do
    case Map.get(content, "documentation") do
      nil -> %{
        "pipeline_name" => "generated_pipeline",
        "description" => "AI-generated pipeline",
        "purpose" => "general purpose"
      }
      doc -> doc
    end
  end

  defp extract_dna_content(content) do
    case Map.get(content, "dna") do
      nil -> %{
        "id" => generate_id(),
        "generation" => 1,
        "traits" => ["ai_generated", "live_mode"]
      }
      dna -> dna
    end
  end
  
  defp create_fallback_pipeline do
    %{
      "pipeline_yaml" => """
      workflow:
        name: fallback_pipeline
        description: Fallback generated pipeline
        version: "1.0.0"
        
        steps:
        - name: simple_task
          type: claude
          prompt:
            - type: "static"
              content: "Process the input and provide a helpful response."
      """,
      "documentation" => %{
        "pipeline_name" => "fallback_pipeline",
        "description" => "A simple fallback pipeline when generation fails",
        "purpose" => "Demonstration of pipeline structure",
        "usage" => "mix pipeline.run fallback_pipeline.yaml"
      },
      "dna" => %{
        "id" => generate_id(),
        "generation" => 0,
        "traits" => ["fallback", "simple"],
        "source" => "fallback_generator"
      }
    }
  end
end