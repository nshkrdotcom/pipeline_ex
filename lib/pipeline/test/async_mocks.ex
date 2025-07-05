defmodule Pipeline.Test.AsyncMocks do
  @moduledoc """
  Mock support for testing async streaming functionality.

  This module provides utilities for creating mock async streams with configurable
  behaviors, timing patterns, and error injection capabilities. It integrates with
  the existing mock system to enable comprehensive testing of async streaming features.

  ## Features

  - Configurable streaming patterns (fast, slow, chunked)
  - Deterministic timing simulation
  - Error injection at specific points
  - Integration with existing mock providers
  - Support for various message types

  ## Example

      # Create a simple mock stream
      stream = AsyncMocks.create_stream("test content")

      # Create a slow stream with delays
      slow_stream = AsyncMocks.create_stream("test", pattern: :slow)

      # Create a stream that errors after 3 messages
      error_stream = AsyncMocks.create_stream("test",
        error_after: 3,
        error_type: :network_error
      )
  """

  alias Pipeline.Streaming.AsyncResponse

  @type streaming_pattern :: :fast | :slow | :chunked | :realistic
  @type error_type :: :network_error | :timeout | :invalid_message | :stream_interrupted

  @type mock_options :: %{
          pattern: streaming_pattern(),
          delay_ms: non_neg_integer(),
          chunk_size: pos_integer(),
          error_after: pos_integer() | nil,
          error_type: error_type() | nil,
          include_metadata: boolean(),
          total_tokens: non_neg_integer()
        }

  @doc """
  Creates a mock async stream with configurable behavior.

  ## Options

  - `:pattern` - Streaming pattern to use (default: `:fast`)
    - `:fast` - No delays between messages
    - `:slow` - 50ms delay between messages
    - `:chunked` - Groups messages in chunks with delays
    - `:realistic` - Variable delays simulating real network behavior

  - `:delay_ms` - Override default delay for pattern (milliseconds)
  - `:chunk_size` - Number of messages per chunk for `:chunked` pattern
  - `:error_after` - Inject error after N messages
  - `:error_type` - Type of error to inject
  - `:include_metadata` - Include additional metadata in messages
  - `:total_tokens` - Total token count to simulate
  """
  @spec create_stream(String.t(), keyword()) :: Enumerable.t()
  def create_stream(content, opts \\ []) do
    options = build_options(opts)
    messages = generate_messages(content, options)

    case options.pattern do
      :fast -> create_fast_stream(messages, options)
      :slow -> create_slow_stream(messages, options)
      :chunked -> create_chunked_stream(messages, options)
      :realistic -> create_realistic_stream(messages, options)
    end
  end

  @doc """
  Creates a mock AsyncResponse with streaming behavior.

  This wraps a mock stream in an AsyncResponse for use in pipeline tests.
  """
  @spec create_async_response(String.t(), String.t(), keyword()) :: AsyncResponse.t()
  def create_async_response(content, step_name, opts \\ []) do
    stream = create_stream(content, opts)

    AsyncResponse.new(stream, step_name,
      handler: opts[:handler],
      buffer_size: opts[:buffer_size] || 10,
      metadata: %{
        mock: true,
        pattern: opts[:pattern] || :fast,
        created_at: DateTime.utc_now()
      }
    )
  end

  @doc """
  Creates a predefined mock stream for common test scenarios.

  ## Scenarios

  - `:simple` - Basic successful stream
  - `:code_generation` - Mock code generation response
  - `:analysis` - Mock analysis response with multiple sections
  - `:error` - Stream that errors partway through
  - `:timeout` - Stream that times out
  - `:empty` - Stream with no content
  """
  @type scenario :: :simple | :code_generation | :analysis | :error | :timeout | :empty

  @spec create_scenario_stream(scenario(), keyword()) :: Enumerable.t()
  def create_scenario_stream(scenario, opts \\ []) do
    content = scenario_content(scenario)
    scenario_opts = scenario_options(scenario)

    create_stream(content, Keyword.merge(scenario_opts, opts))
  end

  @doc """
  Injects an error into an existing stream at a specific point.

  This is useful for testing error handling in stream processors.
  """
  @spec inject_error(Enumerable.t(), pos_integer(), error_type()) :: Enumerable.t()
  def inject_error(stream, after_count, error_type) do
    Stream.transform(
      stream,
      fn -> 0 end,
      fn
        message, count when count == after_count - 1 ->
          # Inject the error after this message
          error = create_error(error_type)
          {[message, error], count + 1}

        message, count ->
          {[message], count + 1}
      end,
      fn _count -> :ok end
    )
  end

  @doc """
  Sets up mock provider responses for async streaming.

  This configures the mock Claude provider to return async responses.
  """
  @spec setup_async_mock(String.t() | Regex.t(), keyword()) :: :ok
  def setup_async_mock(pattern, opts \\ []) do
    alias Pipeline.Test.Mocks.ClaudeProvider

    # Store both sync and async responses
    content = opts[:content] || "Mock async response"

    # For sync requests
    sync_response = %{
      "text" => content,
      "success" => true,
      "cost" => 0.001
    }

    # Set sync response
    ClaudeProvider.set_response_pattern(pattern, sync_response)

    # Also set async response pattern with a special prefix
    async_pattern = "__async__" <> pattern

    async_response_fn = fn _prompt ->
      create_async_response(content, "mock_step", opts)
    end

    ClaudeProvider.set_response_pattern(async_pattern, async_response_fn)

    :ok
  end

  @doc """
  Clears all async mock configurations.
  """
  @spec reset_async_mocks() :: :ok
  def reset_async_mocks() do
    Pipeline.Test.Mocks.ClaudeProvider.reset()
  end

  # Private functions

  defp build_options(opts) do
    defaults = %{
      pattern: :fast,
      delay_ms: nil,
      chunk_size: 3,
      error_after: nil,
      error_type: nil,
      include_metadata: false,
      total_tokens: 100
    }

    Map.merge(defaults, Map.new(opts))
  end

  defp generate_messages(content, options) do
    # Split content into words for realistic streaming
    words = String.split(content, ~r/\s+/)
    total_words = length(words)

    # Generate text messages
    text_messages =
      words
      |> Enum.with_index()
      |> Enum.map(fn {word, index} ->
        message = %{
          type: :text,
          data: %{content: word <> " "}
        }

        # Add token count to some messages
        if rem(index, 3) == 0 do
          tokens = div(options.total_tokens, total_words)
          put_in(message, [:data, :tokens], tokens)
        else
          message
        end
      end)

    # Add metadata messages if requested
    messages =
      if options.include_metadata do
        metadata_message = %{
          type: :system,
          data: %{
            info: "Stream started",
            timestamp: DateTime.utc_now()
          }
        }

        [metadata_message | text_messages]
      else
        text_messages
      end

    # Add result message at the end
    result_message = %{
      type: :result,
      data: %{
        session_id: "mock_session_#{:rand.uniform(10000)}",
        total_tokens: options.total_tokens,
        content: content
      }
    }

    messages ++ [result_message]
  end

  defp create_fast_stream(messages, options) do
    if options.error_after do
      inject_error(Stream.map(messages, & &1), options.error_after, options.error_type)
    else
      Stream.map(messages, & &1)
    end
  end

  defp create_slow_stream(messages, options) do
    delay = options.delay_ms || 50

    stream =
      Stream.map(messages, fn message ->
        Process.sleep(delay)
        message
      end)

    if options.error_after do
      inject_error(stream, options.error_after, options.error_type)
    else
      stream
    end
  end

  defp create_chunked_stream(messages, options) do
    delay = options.delay_ms || 100

    stream =
      messages
      |> Stream.chunk_every(options.chunk_size)
      |> Stream.flat_map(fn chunk ->
        Process.sleep(delay)
        chunk
      end)

    if options.error_after do
      inject_error(stream, options.error_after, options.error_type)
    else
      stream
    end
  end

  defp create_realistic_stream(messages, options) do
    base_delay = options.delay_ms || 30

    stream =
      Stream.map(messages, fn message ->
        # Variable delay: 50% to 150% of base delay
        delay = round(base_delay * (0.5 + :rand.uniform()))
        Process.sleep(delay)
        message
      end)

    if options.error_after do
      inject_error(stream, options.error_after, options.error_type)
    else
      stream
    end
  end

  defp create_error(:network_error) do
    %{
      type: :error,
      data: %{
        error: "Network connection lost",
        code: "ENETDOWN"
      }
    }
  end

  defp create_error(:timeout) do
    %{
      type: :error,
      data: %{
        error: "Stream timeout",
        code: "ETIMEDOUT"
      }
    }
  end

  defp create_error(:invalid_message) do
    %{
      type: :error,
      data: %{
        error: "Invalid message format",
        code: "EINVAL"
      }
    }
  end

  defp create_error(:stream_interrupted) do
    %{
      type: :error,
      data: %{
        error: "Stream interrupted by user",
        code: "EINTR"
      }
    }
  end

  defp scenario_content(:simple) do
    "This is a simple test response with basic content."
  end

  defp scenario_content(:code_generation) do
    """
    Here's the implementation:

    ```elixir
    def hello_world do
      IO.puts("Hello, World!")
    end
    ```

    This function prints a greeting to the console.
    """
  end

  defp scenario_content(:analysis) do
    """
    ## Analysis Results

    ### Performance Metrics
    - Response time: 120ms
    - Memory usage: 45MB
    - CPU utilization: 23%

    ### Recommendations
    1. Optimize database queries
    2. Implement caching layer
    3. Reduce memory allocations
    """
  end

  defp scenario_content(:error) do
    "Starting analysis... Processing data..."
  end

  defp scenario_content(:timeout) do
    "Initiating long-running operation..."
  end

  defp scenario_content(:empty) do
    # Single space to ensure at least one message
    " "
  end

  defp scenario_options(:simple), do: [pattern: :fast]
  defp scenario_options(:code_generation), do: [pattern: :realistic, include_metadata: true]
  defp scenario_options(:analysis), do: [pattern: :chunked, chunk_size: 5]
  defp scenario_options(:error), do: [pattern: :slow, error_after: 3, error_type: :network_error]
  defp scenario_options(:timeout), do: [pattern: :slow, error_after: 2, error_type: :timeout]
  defp scenario_options(:empty), do: [pattern: :fast]
end
