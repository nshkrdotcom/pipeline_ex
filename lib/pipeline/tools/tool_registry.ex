defmodule Pipeline.Tools.ToolRegistry do
  @moduledoc """
  Registry for managing and executing pipeline tools.
  
  Provides a central place to register, discover, and execute tools
  that can be called by LLM adapters.
  """

  require Logger

  @doc """
  Register a tool module in the registry.
  """
  def register_tool(tool_module) when is_atom(tool_module) do
    try do
      definition = tool_module.get_definition()
      
      # Validate the tool can run in current environment
      case validate_tool(tool_module) do
        :ok ->
          Agent.update(:tool_registry, fn registry ->
            Map.put(registry, definition.name, tool_module)
          end)
          
          Logger.info("🔧 Registered tool: #{definition.name}")
          :ok
          
        {:error, reason} ->
          Logger.warning("⚠️ Tool #{definition.name} failed validation: #{reason}")
          {:error, reason}
      end
    rescue
      UndefinedFunctionError ->
        {:error, "Tool module #{tool_module} does not implement get_definition/0"}
    end
  end

  @doc """
  Get all registered tool definitions for LLM adapters.
  """
  def get_tool_definitions() do
    Agent.get(:tool_registry, fn registry ->
      Enum.map(registry, fn {_name, tool_module} ->
        tool_module.get_definition()
      end)
    end)
  end

  @doc """
  Execute a tool by name with the given arguments.
  """
  def execute_tool(tool_name, args) when is_binary(tool_name) and is_map(args) do
    case Agent.get(:tool_registry, fn registry -> Map.get(registry, tool_name) end) do
      nil ->
        Logger.error("❌ Tool not found: #{tool_name}")
        {:error, "Tool '#{tool_name}' not found"}
        
      tool_module ->
        Logger.info("🔧 Executing tool: #{tool_name} with args: #{inspect(args)}")
        
        try do
          case tool_module.execute(args) do
            {:ok, result} ->
              Logger.info("✅ Tool #{tool_name} completed successfully")
              {:ok, result}
              
            {:error, reason} ->
              Logger.error("❌ Tool #{tool_name} failed: #{inspect(reason)}")
              {:error, reason}
          end
        rescue
          error ->
            Logger.error("❌ Tool #{tool_name} crashed: #{inspect(error)}")
            {:error, "Tool execution failed: #{inspect(error)}"}
        end
    end
  end

  @doc """
  Get a specific tool module by name.
  """
  def get_tool(tool_name) when is_binary(tool_name) do
    Agent.get(:tool_registry, fn registry -> Map.get(registry, tool_name) end)
  end

  @doc """
  List all registered tool names.
  """
  def list_tools() do
    Agent.get(:tool_registry, fn registry -> Map.keys(registry) end)
  end

  @doc """
  Start the tool registry.
  """
  def start_link() do
    Agent.start_link(fn -> %{} end, name: :tool_registry)
  end

  @doc """
  Auto-discover and register tools from a given module path.
  """
  def auto_register_tools(base_module \\ Pipeline.Tools.Implementations) do
    # Get all modules in the implementations directory
    modules = discover_tool_modules(base_module)
    
    results = Enum.map(modules, fn module ->
      case register_tool(module) do
        :ok -> {:ok, module}
        error -> {:error, {module, error}}
      end
    end)
    
    successful = Enum.count(results, &match?({:ok, _}, &1))
    total = length(results)
    
    Logger.info("🔧 Auto-registered #{successful}/#{total} tools")
    
    results
  end

  defp validate_tool(tool_module) do
    if function_exported?(tool_module, :validate_environment, 0) do
      tool_module.validate_environment()
    else
      :ok
    end
  end

  defp discover_tool_modules(_base_module) do
    # This is a simplified discovery - in a real implementation,
    # you might scan the file system or use a more sophisticated approach
    [
      Pipeline.Tools.Implementations.GetWanIp.Ubuntu2404
    ]
  end
end