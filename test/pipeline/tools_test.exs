defmodule Pipeline.ToolsTest do
  @moduledoc """
  Test the Gemini Tools function calling implementation.
  """
  
  use Pipeline.TestCase
  
  alias Gemini.Tools
  alias Gemini.Types.{Content, Part}
  
  describe "Gemini.Tools" do
    test "function/3 creates proper tool definition" do
      tool = Tools.function(
        "get_weather",
        "Get current weather for a location", 
        %{
          type: "object",
          properties: %{
            location: %{
              type: "string",
              description: "City and state"
            }
          },
          required: ["location"]
        }
      )
      
      assert tool["function_declarations"] |> length() == 1
      
      func_def = List.first(tool["function_declarations"])
      assert func_def["name"] == "get_weather"
      assert func_def["description"] == "Get current weather for a location"
      assert func_def["parameters"]["type"] == "object"
    end
    
    test "functions/1 creates multiple tool definitions" do
      functions = [
        %{name: "get_weather", description: "Get weather", parameters: %{type: "object"}},
        %{name: "send_email", description: "Send email", parameters: %{type: "object"}}
      ]
      
      tools = Tools.functions(functions)
      
      assert tools["function_declarations"] |> length() == 2
      names = Enum.map(tools["function_declarations"], &(&1["name"]))
      assert "get_weather" in names
      assert "send_email" in names
    end
    
    test "config/2 creates proper tool config" do
      # Test AUTO mode
      auto_config = Tools.config(:auto)
      assert auto_config["function_calling_config"]["mode"] == "AUTO"
      
      # Test ANY mode
      any_config = Tools.config(:any)
      assert any_config["function_calling_config"]["mode"] == "ANY"
      
      # Test ANY mode with allowed functions
      restricted_config = Tools.config(:any, ["get_weather"])
      assert restricted_config["function_calling_config"]["mode"] == "ANY"
      assert restricted_config["function_calling_config"]["allowed_function_names"] == ["get_weather"]
      
      # Test NONE mode
      none_config = Tools.config(:none)
      assert none_config["function_calling_config"]["mode"] == "NONE"
    end
    
    test "param/3 creates proper parameter schemas" do
      # String parameter
      string_param = Tools.param(:string, "A string value")
      assert string_param["type"] == "string"
      assert string_param["description"] == "A string value"
      
      # Enum parameter
      enum_param = Tools.param(:enum, "Choose one", ["option1", "option2"])
      assert enum_param["type"] == "string"
      assert enum_param["enum"] == ["option1", "option2"]
      
      # Integer parameter
      int_param = Tools.param(:integer, "A number")
      assert int_param["type"] == "integer"
      
      # Object parameter
      obj_param = Tools.param(:object, "An object", %{"field1" => %{"type" => "string"}})
      assert obj_param["type"] == "object"
      assert obj_param["properties"]["field1"]["type"] == "string"
    end
    
    test "execute_functions/2 executes function registry" do
      function_calls = [
        %{name: "test_func", args: %{"input" => "hello"}}
      ]
      
      function_registry = %{
        "test_func" => fn args ->
          {:ok, %{"output" => "processed: #{args["input"]}"}}
        end
      }
      
      {:ok, response_parts} = Tools.execute_functions(function_calls, function_registry)
      
      assert length(response_parts) == 1
      part = List.first(response_parts)
      
      assert Part.has_function_response?(part)
      assert Part.get_function_name(part) == "test_func"
      
      response_data = Part.get_function_response(part)
      assert response_data["output"] == "processed: hello"
    end
    
    test "execute_functions/2 handles function errors" do
      function_calls = [
        %{name: "failing_func", args: %{}}
      ]
      
      function_registry = %{
        "failing_func" => fn _args ->
          {:error, "Something went wrong"}
        end
      }
      
      {:ok, response_parts} = Tools.execute_functions(function_calls, function_registry)
      
      assert length(response_parts) == 1
      part = List.first(response_parts)
      
      assert Part.has_function_response?(part)
      response_data = Part.get_function_response(part)
      assert response_data["error"] == "Something went wrong"
    end
    
    test "execute_functions/2 handles missing functions" do
      function_calls = [
        %{name: "missing_func", args: %{}}
      ]
      
      function_registry = %{}
      
      {:ok, response_parts} = Tools.execute_functions(function_calls, function_registry)
      
      assert length(response_parts) == 1
      part = List.first(response_parts)
      
      assert Part.has_function_response?(part)
      response_data = Part.get_function_response(part)
      assert response_data["error"] == "Function not implemented"
    end
  end
  
  describe "Part function calling extensions" do
    test "function_call/2 creates function call part" do
      part = Part.function_call("test_func", %{"arg1" => "value1"})
      
      assert Part.has_function_call?(part)
      assert Part.get_function_name(part) == "test_func"
      assert Part.get_function_args(part) == %{"arg1" => "value1"}
    end
    
    test "function_response/2 creates function response part" do
      part = Part.function_response("test_func", %{"result" => "success"})
      
      assert Part.has_function_response?(part)
      assert Part.get_function_name(part) == "test_func"
      assert Part.get_function_response(part) == %{"result" => "success"}
    end
    
    test "helper functions work correctly" do
      # Test with no function call
      text_part = Part.text("Hello world")
      refute Part.has_function_call?(text_part)
      refute Part.has_function_response?(text_part)
      assert Part.get_function_name(text_part) == nil
      
      # Test with function call
      call_part = Part.function_call("my_func", %{"key" => "value"})
      assert Part.has_function_call?(call_part)
      refute Part.has_function_response?(call_part)
      assert Part.get_function_name(call_part) == "my_func"
      assert Part.get_function_args(call_part) == %{"key" => "value"}
      
      # Test with function response
      response_part = Part.function_response("my_func", "result_data")
      refute Part.has_function_call?(response_part)
      assert Part.has_function_response?(response_part)
      assert Part.get_function_name(response_part) == "my_func"
      assert Part.get_function_response(response_part) == "result_data"
    end
  end
end