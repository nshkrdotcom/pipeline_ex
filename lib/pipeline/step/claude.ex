defmodule Pipeline.Step.Claude do
  @moduledoc """
  Executes Claude (Muscle) steps for code execution and file manipulation.
  """

  alias Pipeline.{Debug, PromptBuilder}
  require Logger

  def execute(step, orch) do
    Logger.info("💪 Claude Muscle executing: #{step[:name] || step["name"] || "task"}")
    Logger.info("🔍 Debug: LLM call type: ASYNCHRONOUS (subprocess)")
    
    # Build prompt
    prompt = PromptBuilder.build(step[:prompt] || step["prompt"], orch.results)
    
    # Show prompt preview
    prompt_preview = if String.length(prompt) > 200, do: String.slice(prompt, 0, 200) <> "...", else: prompt
    Logger.info("📝 Prompt preview: #{prompt_preview}")
    
    Debug.log(orch.debug_log, "Claude prompt:\n#{prompt}\n")
    
    # Get Claude options
    raw_claude_opts = step[:claude_options] || step["claude_options"] || %{}
    claude_opts = build_claude_options(raw_claude_opts, orch)
    
    start_time = System.monotonic_time(:millisecond)
    Logger.info("🚀 Debug: Starting LLM call to Claude NOW at #{DateTime.utc_now()}")
    
    if claude_opts.cwd && claude_opts.cwd != orch.workspace_dir do
      Logger.info("📁 Working directory: #{claude_opts.cwd}")
    end
    
    # Execute Claude using the SDK
    result = execute_claude(prompt, claude_opts)
    
    elapsed = System.monotonic_time(:millisecond) - start_time
    Logger.info("📤 Raw Claude response (took #{elapsed / 1000}s):")
    
    response_preview = case result do
      %{text: text} when is_binary(text) ->
        if String.length(text) > 200, do: String.slice(text, 0, 200) <> "...", else: text
      map when is_map(map) ->
        encoded = Jason.encode!(map)
        String.slice(encoded, 0, 200) <> "..."
      _ ->
        inspected = inspect(result)
        String.slice(inspected, 0, 200) <> "..."
    end
    
    Logger.info("  #{response_preview}")
    Debug.log(orch.debug_log, "Claude response (took #{elapsed / 1000}s):\n#{inspect(result)}\n")
    
    # Save to file if specified
    output_file = step[:output_to_file] || step["output_to_file"]
    if output_file do
      save_output(orch.output_dir, output_file, result)
    end
    
    result
  end

  defp build_claude_options(claude_opts, orch) when is_map(claude_opts) do
    
    # Handle working directory first
    cwd = case claude_opts["cwd"] || claude_opts[:cwd] do
      nil -> orch.workspace_dir
      relative_path ->
        Path.join(orch.workspace_dir, relative_path)
        |> Path.expand()
    end
    
    # Ensure directory exists
    File.mkdir_p!(cwd)
    
    # Build options struct with all the config values
    # NOTE: We don't set output_format as it breaks message type detection in the SDK
    %ClaudeCodeSDK.Options{
      max_turns: claude_opts["max_turns"] || claude_opts[:max_turns],
      allowed_tools: claude_opts["allowed_tools"] || claude_opts[:allowed_tools],
      disallowed_tools: claude_opts["disallowed_tools"] || claude_opts[:disallowed_tools],
      verbose: claude_opts["verbose"] || claude_opts[:verbose],
      system_prompt: claude_opts["system_prompt"] || claude_opts[:system_prompt],
      append_system_prompt: claude_opts["append_system_prompt"] || claude_opts[:append_system_prompt],
      permission_mode: parse_permission_mode(claude_opts["permission_mode"] || claude_opts[:permission_mode]),
      cwd: cwd
    }
  end
  
  defp build_claude_options(nil, orch) do
    %ClaudeCodeSDK.Options{cwd: orch.workspace_dir}
  end
  
  
  defp parse_permission_mode(nil), do: nil
  defp parse_permission_mode("default"), do: :default
  defp parse_permission_mode("accept_edits"), do: :accept_edits
  defp parse_permission_mode("bypass_permissions"), do: :bypass_permissions
  defp parse_permission_mode("plan"), do: :plan
  defp parse_permission_mode(_), do: :default

  defp execute_claude(prompt, opts) do
    try do
      # Use the Claude SDK following the comprehensive manual patterns
      Logger.debug("Calling ClaudeCodeSDK.query with options: #{inspect(opts)}")
      stream = ClaudeCodeSDK.query(prompt, opts)
      
      # Process stream following the manual's message type patterns
      {assistant_responses, result_info} = 
        stream
        |> Enum.reduce({[], nil}, fn msg, {responses, result} ->
          Logger.debug("Processing message: type=#{msg.type}, subtype=#{inspect(msg.subtype)}")
          case msg do
            %ClaudeCodeSDK.Message{type: :assistant} = assistant_msg ->
              content = extract_assistant_content(assistant_msg)
              Logger.debug("Extracted assistant content: #{inspect(content)}")
              {[content | responses], result}
              
            %ClaudeCodeSDK.Message{type: :result} = result_msg ->
              extracted_result = extract_result_info(result_msg)
              Logger.debug("Extracted result info: #{inspect(extracted_result)}")
              {responses, extracted_result}
              
            _ ->
              Logger.debug("Skipping message type: #{msg.type}")
              {responses, result}
          end
        end)
        
      Logger.debug("Final assistant_responses: #{inspect(assistant_responses)}")
      Logger.debug("Final result_info: #{inspect(result_info)}")
      
      # Build response in our standard format
      %{
        text: Enum.reverse(assistant_responses) |> Enum.join("\n"),
        success: (result_info && result_info[:subtype] == :success),
        cost: (result_info && result_info[:data][:total_cost_usd]) || 0.0
      }
      
    rescue
      error ->
        Logger.error("❌ Claude SDK error: #{inspect(error)}")
        %{
          text: "Error executing Claude: #{inspect(error)}",
          success: false,
          error: inspect(error)
        }
    end
  end

  defp extract_assistant_content(%ClaudeCodeSDK.Message{data: %{message: message}}) do
    case message do
      %{"content" => content} when is_binary(content) -> 
        content
      %{"content" => content_list} when is_list(content_list) ->
        content_list
        |> Enum.map(fn
          %{"text" => text, "type" => "text"} -> text
          %{"text" => text} -> text  # fallback for older format
          %{"type" => "tool_use"} = tool -> "[Tool: #{tool["name"]}]"
          other -> inspect(other)
        end)
        |> Enum.join(" ")
      _ -> 
        inspect(message)
    end
  end

  defp extract_result_info(%ClaudeCodeSDK.Message{subtype: subtype, data: data}) do
    %{
      subtype: subtype,
      data: data
    }
  end

  defp save_output(output_dir, filename, data) do
    filepath = Path.join(output_dir, filename)
    File.mkdir_p!(Path.dirname(filepath))
    
    content = if is_binary(data) do
      data
    else
      Jason.encode!(data, pretty: true)
    end
    
    File.write!(filepath, content)
    Logger.info("📁 Saved output to: #{filepath}")
  end
end