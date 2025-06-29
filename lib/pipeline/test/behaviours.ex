defmodule Pipeline.Test.AIProvider do
  @moduledoc """
  Behaviour for mocking AI providers (Gemini) in tests.
  """

  @doc """
  Generate a response from the AI provider.
  
  ## Parameters
    - prompt: The input prompt string
    - opts: Keyword list of options (model, token_budget, etc.)
  
  ## Returns
    - {:ok, response_map} on success
    - {:error, reason} on failure
  """
  @callback generate(prompt :: String.t(), opts :: keyword()) :: 
    {:ok, map()} | {:error, term()}
end

defmodule Pipeline.Test.ClaudeProvider do
  @moduledoc """
  Behaviour for mocking Claude SDK in tests.
  """

  @doc """
  Query Claude with a prompt and options.
  
  ## Parameters
    - prompt: The input prompt string
    - options: ClaudeCodeSDK.Options struct
  
  ## Returns
    An Enumerable that yields message structs
  """
  @callback query(prompt :: String.t(), options :: struct()) :: 
    Enumerable.t()
end

defmodule Pipeline.Test.FileSystem do
  @moduledoc """
  Behaviour for mocking file system operations in tests.
  """

  @doc "Read a file from the file system"
  @callback read(path :: String.t()) :: {:ok, binary()} | {:error, term()}
  
  @doc "Write content to a file"
  @callback write(path :: String.t(), content :: binary()) :: :ok | {:error, term()}
  
  @doc "Create directory path recursively"
  @callback mkdir_p(path :: String.t()) :: :ok | {:error, term()}
  
  @doc "Check if file exists"
  @callback exists?(path :: String.t()) :: boolean()
  
  @doc "List files in directory"
  @callback ls(path :: String.t()) :: {:ok, [String.t()]} | {:error, term()}
end

defmodule Pipeline.Test.Logger do
  @moduledoc """
  Behaviour for mocking Logger operations in tests.
  """

  @doc "Log an info message"
  @callback info(message :: String.t()) :: :ok
  
  @doc "Log a debug message"
  @callback debug(message :: String.t()) :: :ok
  
  @doc "Log an error message"
  @callback error(message :: String.t()) :: :ok
  
  @doc "Log a warning message"
  @callback warn(message :: String.t()) :: :ok
end