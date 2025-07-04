defmodule Pipeline.Step.ClaudeExtract do
  @moduledoc """
  Claude Extract step executor - handles claude_extract step type with content extraction and processing.

  Claude Extract steps provide advanced content extraction capabilities:
  - Extract structured data from Claude responses
  - Apply post-processing operations (code blocks, recommendations, etc.)
  - Format content in various output formats (text, json, structured, summary, markdown)
  - Include extraction metadata and statistics
  """

  require Logger
  alias Pipeline.{OptionBuilder, PromptBuilder, TestMode}

  # Note: These are defined here for reference but validation happens in EnhancedConfig
  # @valid_formats ["text", "json", "structured", "summary", "markdown"]
  # @valid_post_processing ["extract_code_blocks", "extract_recommendations", ...]

  @doc """
  Execute a claude_extract step with content extraction.
  """
  def execute(step, context) do
    Logger.info("🎯 Executing Claude Extract step: #{step["name"]}")

    try do
      with {:ok, enhanced_options} <- build_enhanced_options(step, context),
           prompt <- PromptBuilder.build(step["prompt"], context.results),
           {:ok, provider} <- get_provider(context),
           {:ok, raw_response} <- execute_with_provider(provider, prompt, enhanced_options),
           {:ok, extracted_content} <- extract_content(raw_response, step) do
        Logger.info("✅ Claude Extract step completed successfully")
        {:ok, extracted_content}
      else
        {:error, reason} ->
          Logger.error("❌ Claude Extract step failed: #{reason}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("💥 Claude Extract step crashed: #{inspect(error)}")
        {:error, "Claude Extract step crashed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions

  defp build_enhanced_options(step, context) do
    # Start with basic enhanced Claude options
    base_options = step["claude_options"] || %{}

    # Apply OptionBuilder for consistency with other step types
    preset = get_preset_for_extract(step, context)
    enhanced_options = OptionBuilder.merge(preset, base_options)

    # Add extraction-specific options
    extraction_config = step["extraction_config"] || %{}

    extraction_options = %{
      "extraction_config" => extraction_config,
      # Preserve preset for mock provider
      "preset" => preset
    }

    final_options = Map.merge(enhanced_options, extraction_options)

    Logger.debug(
      "🎯 Claude Extract options built with format: #{extraction_config["format"] || "default"}"
    )

    {:ok, final_options}
  rescue
    error ->
      Logger.error("💥 Failed to build extraction options: #{inspect(error)}")
      {:error, "Failed to build extraction options: #{Exception.message(error)}"}
  end

  defp get_preset_for_extract(step, context) do
    # Use analysis preset as default for extraction (good for detailed analysis)
    step["preset"] ||
      get_in(context.config, ["workflow", "defaults", "claude_preset"]) ||
      "analysis"
  end

  defp get_provider(context) do
    provider_module = determine_provider_module(context)
    {:ok, provider_module}
  end

  defp determine_provider_module(_context) do
    # Check if we're in test mode
    test_mode = Application.get_env(:pipeline, :test_mode, :live)

    case test_mode do
      :mock ->
        Pipeline.Test.Mocks.ClaudeProvider

      _ ->
        # Use enhanced provider for live mode
        Pipeline.Providers.EnhancedClaudeProvider
    end
  end

  defp execute_with_provider(provider, prompt, options) do
    Logger.debug("🚀 Executing Claude Extract with provider #{inspect(provider)}")

    Logger.debug(
      "📋 Extraction format: #{get_in(options, ["extraction_config", "format"]) || "default"}"
    )

    case provider.query(prompt, options) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_content(raw_response, step) do
    extraction_config = step["extraction_config"] || %{}

    try do
      # Start with the raw response
      content = get_response_text(raw_response)

      # Apply content extraction if enabled
      extracted_content =
        if extraction_config["use_content_extractor"] do
          apply_content_extractor(content, extraction_config)
        else
          content
        end

      # Apply format-specific processing
      format = extraction_config["format"] || "text"
      formatted_content = apply_format_processing(extracted_content, format, extraction_config)

      # Apply post-processing operations
      post_processed_content = apply_post_processing(formatted_content, extraction_config)

      # Build final response with metadata
      final_response =
        build_extraction_response(
          post_processed_content,
          raw_response,
          extraction_config,
          step
        )

      {:ok, final_response}
    rescue
      error ->
        Logger.error("💥 Content extraction failed: #{inspect(error)}")
        {:error, "Content extraction failed: #{Exception.message(error)}"}
    end
  end

  defp get_response_text(response) do
    cond do
      is_binary(response) -> response
      is_map(response) && Map.has_key?(response, "text") -> response["text"]
      is_map(response) && Map.has_key?(response, "content") -> response["content"]
      true -> inspect(response)
    end
  end

  defp apply_content_extractor(content, extraction_config) do
    # In mock mode, simulate content extraction
    case TestMode.get_mode() do
      :mock ->
        simulate_content_extraction(content, extraction_config)

      _ ->
        # In live mode, would use real content extractor (not implemented yet)
        # Pipeline.ContentExtractor.extract_text(content)
        # Return content as-is for now
        content
    end
  end

  defp simulate_content_extraction(content, extraction_config) do
    format = extraction_config["format"] || "text"

    case format do
      "json" ->
        Jason.encode!(%{
          "extracted_content" => content,
          "extraction_metadata" => %{
            "format" => "json",
            "extracted_at" => DateTime.utc_now(),
            "content_length" => String.length(content)
          }
        })

      "structured" ->
        """
        ## Extracted Content

        ### Summary
        #{String.slice(content, 0, 200)}...

        ### Key Points
        - Content successfully extracted
        - Format: structured
        - Length: #{String.length(content)} characters

        ### Full Content
        #{content}
        """

      "summary" ->
        "Summary: #{String.slice(content, 0, 100)}..."

      "markdown" ->
        """
        # Extracted Content

        **Extraction Date**: #{DateTime.utc_now()}
        **Format**: Markdown
        **Content Length**: #{String.length(content)} characters

        ## Content

        #{content}
        """

      _ ->
        content
    end
  end

  defp apply_format_processing(content, format, extraction_config) do
    case format do
      "json" ->
        # Ensure content is valid JSON
        if valid_json?(content) do
          content
        else
          Jason.encode!(%{"content" => content, "format" => "json"})
        end

      "structured" ->
        # Apply structured formatting if not already done
        if String.contains?(content, "##") do
          content
        else
          """
          ## Extracted Content

          #{content}
          """
        end

      "summary" ->
        # Apply summary length limits
        max_length = extraction_config["max_summary_length"] || 500

        if String.length(content) <= max_length do
          content
        else
          String.slice(content, 0, max_length - 3) <> "..."
        end

      "markdown" ->
        # Ensure markdown formatting
        if String.contains?(content, "#") do
          content
        else
          """
          # Extracted Content

          #{content}
          """
        end

      _ ->
        content
    end
  end

  defp apply_post_processing(content, extraction_config) do
    post_processing = extraction_config["post_processing"] || []

    Enum.reduce(post_processing, content, fn operation, acc ->
      apply_post_processing_operation(acc, operation)
    end)
  end

  defp apply_post_processing_operation(content, operation) do
    case operation do
      "extract_code_blocks" ->
        extract_code_blocks(content)

      "extract_recommendations" ->
        extract_recommendations(content)

      "extract_links" ->
        extract_links(content)

      "extract_key_points" ->
        extract_key_points(content)

      "format_markdown" ->
        format_as_markdown(content)

      "generate_summary" ->
        generate_summary(content)

      _ ->
        Logger.warning("⚠️ Unknown post-processing operation: #{operation}")
        content
    end
  end

  defp extract_code_blocks(content) do
    # Simple regex to find code blocks
    code_blocks =
      Regex.scan(~r/```[\s\S]*?```/, content)
      |> Enum.map(fn [block] -> block end)

    if Enum.empty?(code_blocks) do
      content
    else
      code_section = """

      ## Code Blocks Extracted
      #{Enum.join(code_blocks, "\n\n")}
      """

      content <> code_section
    end
  end

  defp extract_recommendations(content) do
    # Look for recommendation patterns
    recommendations =
      content
      |> String.split("\n")
      |> Enum.filter(&(String.contains?(&1, "recommend") || String.contains?(&1, "suggest")))

    if Enum.empty?(recommendations) do
      content
    else
      rec_section = """

      ## Recommendations Extracted
      #{Enum.join(recommendations, "\n")}
      """

      content <> rec_section
    end
  end

  defp extract_links(content) do
    # Simple URL extraction
    links =
      Regex.scan(~r/https?:\/\/[^\s]+/, content)
      |> Enum.map(fn [link] -> "- #{link}" end)

    if Enum.empty?(links) do
      content
    else
      link_section = """

      ## Links Extracted
      #{Enum.join(links, "\n")}
      """

      content <> link_section
    end
  end

  defp extract_key_points(content) do
    # Look for bullet points or numbered lists
    key_points =
      content
      |> String.split("\n")
      |> Enum.filter(
        &(String.starts_with?(&1, "- ") || String.starts_with?(&1, "* ") ||
            Regex.match?(~r/^\d+\./, &1))
      )

    if Enum.empty?(key_points) do
      content
    else
      points_section = """

      ## Key Points Extracted
      #{Enum.join(key_points, "\n")}
      """

      content <> points_section
    end
  end

  defp format_as_markdown(content) do
    # Ensure proper markdown formatting
    if String.contains?(content, "#") do
      content
    else
      """
      # Content

      #{content}
      """
    end
  end

  defp generate_summary(content) do
    # Generate a simple summary
    summary =
      content
      |> String.split(". ")
      |> Enum.take(3)
      |> Enum.join(". ")
      |> String.slice(0, 200)

    summary_section = """

    ## Generated Summary
    #{summary}...
    """

    content <> summary_section
  end

  defp build_extraction_response(processed_content, raw_response, extraction_config, step) do
    base_response = %{
      "text" => processed_content,
      "success" => true,
      "extraction_applied" => true
    }

    # Add metadata if requested
    base_response =
      if extraction_config["include_metadata"] do
        metadata = %{
          "extraction_metadata" => %{
            "format" => extraction_config["format"] || "text",
            "use_content_extractor" => extraction_config["use_content_extractor"] || false,
            "post_processing_applied" => extraction_config["post_processing"] || [],
            "extraction_timestamp" => DateTime.utc_now(),
            "original_length" => get_content_length(raw_response),
            "processed_length" => String.length(processed_content),
            "step_name" => step["name"]
          }
        }

        Map.merge(base_response, metadata)
      else
        base_response
      end

    # Preserve original response fields
    case raw_response do
      %{} = response_map ->
        Map.merge(response_map, base_response)

      _ ->
        base_response
    end
  end

  defp get_content_length(response) do
    content = get_response_text(response)
    String.length(content)
  end

  defp valid_json?(content) do
    case Jason.decode(content) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end
end
