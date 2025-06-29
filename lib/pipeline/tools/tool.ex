defmodule Pipeline.Tools.Tool do
  @moduledoc """
  Base behavior for pipeline tools that can be called by LLMs.
  
  Tools define functions that can be executed by AI models during conversations.
  Each tool should implement this behavior to provide consistent interface.
  """

  @doc """
  Returns the tool definition including name, description, and parameters schema.
  This is used by LLM adapters to register the tool with the AI service.
  """
  @callback get_definition() :: %{
    name: String.t(),
    description: String.t(), 
    parameters: map()
  }

  @doc """
  Executes the tool with the given arguments.
  Returns {:ok, result} on success or {:error, reason} on failure.
  """
  @callback execute(args :: map()) :: {:ok, any()} | {:error, any()}

  @doc """
  Returns the platforms/configurations this tool supports.
  Used for tool discovery and validation.
  """
  @callback supported_platforms() :: [String.t()]

  @doc """
  Validates that the tool can run in the current environment.
  Returns :ok if valid, {:error, reason} if not.
  """
  @callback validate_environment() :: :ok | {:error, String.t()}

  @optional_callbacks [supported_platforms: 0, validate_environment: 0]
end