defmodule Pipeline.Providers.ClaudeProvider do
  @moduledoc """
  Live Claude provider using the existing Claude SDK integration.
  """

  require Logger

  @doc """
  Query Claude using the existing Claude SDK integration.
  """
  def query(prompt, options \\ %{}) do
    Logger.debug("💪 Querying Claude with prompt: #{String.slice(prompt, 0, 100)}...")
    
    # For now, delegate to the existing Claude step implementation
    # This maintains compatibility with the working Claude SDK integration
    
    try do
      # Build Claude options from the provider options
      claude_options = build_claude_options(options)
      
      # Use the existing Claude SDK via the step module
      # In a real implementation, this would call the Claude SDK directly
      # For now, execute_claude_sdk always returns {:ok, response}
      # In production, this would handle both success and error cases
      {:ok, response} = execute_claude_sdk(prompt, claude_options)
      Logger.debug("✅ Claude query successful")
      {:ok, response}
    rescue
      error ->
        Logger.error("💥 Claude query crashed: #{inspect(error)}")
        {:error, "Claude query crashed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions

  defp build_claude_options(options) do
    %{
      max_turns: options["max_turns"] || options[:max_turns] || 3,
      allowed_tools: options["allowed_tools"] || options[:allowed_tools] || [],
      disallowed_tools: options["disallowed_tools"] || options[:disallowed_tools] || [],
      system_prompt: options["system_prompt"] || options[:system_prompt],
      verbose: options["verbose"] || options[:verbose] || false,
      cwd: options["cwd"] || options[:cwd] || "./workspace"
    }
  end

  defp execute_claude_sdk(prompt, options) do
    # Use the actual Claude Code SDK for live API calls
    case Pipeline.TestMode.get_mode() do
      :mock ->
        # Return mock response in mock mode
        {:ok, %{
          text: "Mock Claude response for: #{String.slice(prompt, 0, 50)}...",
          success: true,
          cost: 0.001
        }}
        
      _live_or_mixed ->
        # Make real API call using ClaudeCodeSDK
        try do
          # Convert options to ClaudeCodeSDK Options struct
          sdk_options = %ClaudeCodeSDK.Options{
            verbose: options[:verbose] || false,
            cwd: options[:cwd] || "./workspace",
            system_prompt: options[:system_prompt],
            max_turns: options[:max_turns] || 3,
            allowed_tools: options[:allowed_tools],
            disallowed_tools: options[:disallowed_tools]
          }
          
          # Query using the SDK (returns a stream)
          stream = ClaudeCodeSDK.query(prompt, sdk_options)
          
          # Collect all messages from the stream
          messages = Enum.to_list(stream)
          
          # Debug: log the messages structure
          Logger.debug("ClaudeCodeSDK messages: #{inspect(messages, limit: :infinity)}")
          
          # Extract text content from messages
          try do
            text_content = extract_text_from_messages(messages)
            
            {:ok, %{
              text: text_content,
              success: true,
              cost: calculate_cost(messages)
            }}
          catch
            {:error, reason} ->
              Logger.error("ClaudeCodeSDK extraction error: #{reason}")
              {:error, reason}
          end
        rescue
          error ->
            Logger.error("ClaudeCodeSDK error: #{inspect(error)}")
            {:error, Exception.message(error)}
        end
    end
  end
  
  defp extract_text_from_messages(messages) do
    # Check for errors first
    error_msg = Enum.find(messages, fn msg -> 
      msg.type == :result and msg.subtype != :success 
    end)
    
    if error_msg do
      error_text = if Map.has_key?(error_msg.data, :error) do
        error_msg.data.error
      else
        inspect(error_msg.data)
      end
      throw({:error, "Claude SDK error: #{error_text}"})
    end

    # Extract assistant messages
    messages
    |> Enum.filter(fn msg -> msg.type == :assistant end)
    |> Enum.map(fn msg ->
      case msg.data.message do
        %{"content" => text} when is_binary(text) -> text
        %{"content" => [%{"text" => text}]} -> text
        other -> inspect(other)
      end
    end)
    |> Enum.join("\n")
  end
  
  defp calculate_cost(messages) do
    # Simple cost calculation based on message count
    # In reality, this would be based on token usage
    length(messages) * 0.0001
  end
end