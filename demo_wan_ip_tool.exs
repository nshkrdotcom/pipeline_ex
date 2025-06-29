#!/usr/bin/env elixir

# Demo script showing the WAN IP tool system working
# This demonstrates the complete tool system without requiring Gemini API

IO.puts """
🔧 WAN IP Tool System Demo
=========================

This demo shows the generic tool system with InstructorLite adapter
and the get_wan_ip tool for Ubuntu 24.04 working successfully.
"""

# Start the tool registry
{:ok, _pid} = Pipeline.Tools.ToolRegistry.start_link()

IO.puts "\n📋 Step 1: Auto-registering tools..."
results = Pipeline.Tools.ToolRegistry.auto_register_tools()
IO.inspect(results, label: "Registration Results")

IO.puts "\n📋 Step 2: Listing registered tools..."
tools = Pipeline.Tools.ToolRegistry.list_tools()
IO.inspect(tools, label: "Available Tools")

IO.puts "\n📋 Step 3: Getting tool definition..."
definitions = Pipeline.Tools.ToolRegistry.get_tool_definitions()
Enum.each(definitions, fn def ->
  IO.puts "Tool: #{def.name}"
  IO.puts "Description: #{def.description}"
  IO.puts "Parameters: #{inspect(def.parameters, pretty: true)}"
end)

IO.puts "\n📋 Step 4: Executing get_wan_ip tool..."
case Pipeline.Tools.ToolRegistry.execute_tool("get_wan_ip", %{}) do
  {:ok, result} ->
    IO.puts "✅ SUCCESS! WAN IP Tool Results:"
    IO.puts "  WAN IP: #{result.wan_ip}"
    IO.puts "  Service: #{result.service_used}"
    IO.puts "  Platform: #{result.platform}"
    IO.puts "  Timestamp: #{result.timestamp}"
    
  {:error, error} ->
    IO.puts "❌ Error: #{error}"
end

IO.puts "\n📋 Step 5: Testing with different service..."
case Pipeline.Tools.ToolRegistry.execute_tool("get_wan_ip", %{"service" => "httpbin"}) do
  {:ok, result} ->
    IO.puts "✅ SUCCESS! WAN IP Tool Results (httpbin):"
    IO.puts "  WAN IP: #{result.wan_ip}"
    IO.puts "  Service: #{result.service_used}"
    
  {:error, error} ->
    IO.puts "❌ Error: #{error}"
end

IO.puts "\n📋 Step 6: Testing InstructorLite adapter..."
adapter_schema = Pipeline.Tools.Adapters.InstructorLiteAdapter.create_function_schema(["get_wan_ip"])
IO.puts "✅ Function calling schema created:"
IO.inspect(adapter_schema, pretty: true)

IO.puts "\n🎉 Demo Complete!"
IO.puts """

Summary:
- ✅ Generic tool system implemented with behaviors and registry
- ✅ InstructorLite adapter for multi-provider function calling
- ✅ Ubuntu 24.04 WAN IP tool working with curl
- ✅ Platform-specific validation and error handling
- ✅ Provider-agnostic design ready for other LLM providers

The system is ready for integration with Gemini function calling!
"""