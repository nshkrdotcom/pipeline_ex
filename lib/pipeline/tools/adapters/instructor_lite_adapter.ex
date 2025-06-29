defmodule Pipeline.Tools.Adapters.InstructorLiteAdapter do
  @moduledoc """
  Adapter for using Pipeline tools with InstructorLite.

  Converts tool definitions to InstructorLite-compatible schemas
  and handles function call execution.
  """

  alias Pipeline.Tools.ToolRegistry
  require Logger

  @doc """
  Create function calling schema for InstructorLite from registered tools.
  """
  def create_function_schema(tool_names \\ nil) do
    available_tools =
      if tool_names do
        # Filter to only requested tools
        Enum.filter(ToolRegistry.get_tool_definitions(), fn def ->
          def.name in tool_names
        end)
      else
        # Use all registered tools
        ToolRegistry.get_tool_definitions()
      end

    if length(available_tools) == 0 do
      Logger.warning("⚠️ No tools available for function calling")
      create_basic_response_schema()
    else
      create_tool_calling_schema(available_tools)
    end
  end

  @doc """
  Execute function calls from InstructorLite response.
  """
  def execute_function_calls(response) do
    case extract_function_calls(response) do
      [] ->
        # No function calls, return response as-is
        {:ok, response}

      function_calls ->
        # Execute each function call
        results =
          Enum.map(function_calls, fn call ->
            execute_single_function_call(call)
          end)

        # Combine results with original response
        enhanced_response =
          response
          |> Map.put("function_calls_executed", length(function_calls))
          |> Map.put("function_results", results)

        {:ok, enhanced_response}
    end
  end

  @doc """
  Create an Ecto schema for function calling responses.
  """
  def create_function_response_schema() do
    quote do
      defmodule Pipeline.Schemas.FunctionCallResponse do
        use Ecto.Schema
        use InstructorLite.Instruction

        @derive Jason.Encoder
        @primary_key false
        embedded_schema do
          field(:reasoning, :string)
          field(:function_name, :string)
          field(:function_args, :map)
          field(:expected_result, :string)
        end
      end
    end
  end

  # Private functions

  defp create_basic_response_schema() do
    %{
      type: "object",
      properties: %{
        text: %{type: "string", description: "The response text"},
        reasoning: %{type: "string", description: "Your reasoning process"}
      },
      required: ["text"]
    }
  end

  defp create_tool_calling_schema(tools) do
    # Create function call options based on available tools
    function_options =
      Enum.reduce(tools, %{}, fn tool, acc ->
        Map.put(acc, tool.name, %{
          type: "object",
          properties: %{
            function_name: %{
              type: "string",
              enum: [tool.name],
              description: "The name of the function to call"
            },
            args: tool.parameters,
            reasoning: %{
              type: "string",
              description: "Why you chose this function and these arguments"
            }
          },
          required: ["function_name", "args", "reasoning"]
        })
      end)

    %{
      type: "object",
      properties: %{
        reasoning: %{
          type: "string",
          description: "Your analysis of the user's request and why you need to call a function"
        },
        function_call: %{
          type: "object",
          properties: function_options,
          description: "The function to call with its arguments"
        },
        expected_outcome: %{
          type: "string",
          description: "What you expect this function call to accomplish"
        }
      },
      required: ["reasoning", "function_call"]
    }
  end

  defp extract_function_calls(response) when is_map(response) do
    case Map.get(response, "function_call") do
      nil ->
        []

      function_call when is_map(function_call) ->
        # Extract function calls from the nested structure
        Enum.flat_map(function_call, fn {_key, call_data} ->
          case call_data do
            %{"function_name" => name, "args" => args} ->
              [%{name: name, args: args, reasoning: Map.get(call_data, "reasoning")}]

            _ ->
              []
          end
        end)
    end
  end

  defp extract_function_calls(_), do: []

  defp execute_single_function_call(%{name: name, args: args} = call) do
    case ToolRegistry.execute_tool(name, args) do
      {:ok, result} ->
        %{
          function: name,
          args: args,
          reasoning: Map.get(call, :reasoning),
          status: "success",
          result: result,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }

      {:error, error} ->
        %{
          function: name,
          args: args,
          reasoning: Map.get(call, :reasoning),
          status: "error",
          error: inspect(error),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
    end
  end
end
