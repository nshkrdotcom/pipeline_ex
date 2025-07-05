defmodule Pipeline.SessionManager do
  @moduledoc """
  Session management for persistent Claude conversations.

  Provides session creation, retrieval, checkpointing, and lifecycle management
  for claude_session step types. Sessions can persist across pipeline runs
  and maintain conversation context.
  """

  require Logger
  alias Pipeline.TestMode

  @doc """
  Create a new session with the given name and options.

  ## Options
  - `persist`: Whether to persist the session across restarts (default: false)
  - `max_turns`: Maximum turns allowed in the session (default: configured in config.exs)
  - `checkpoint_interval`: How often to checkpoint (default: 5 interactions)
  """
  def create_session(session_name, options \\ %{}) do
    case TestMode.get_mode() do
      :mock ->
        create_mock_session(session_name, options)

      _live_mode ->
        create_live_session(session_name, options)
    end
  end

  @doc """
  Get an existing session by session_id.
  Returns nil if session not found.
  """
  def get_session(session_id) do
    case TestMode.get_mode() do
      :mock ->
        get_mock_session(session_id)

      _live_mode ->
        get_live_session(session_id)
    end
  end

  @doc """
  Continue an existing session with a new prompt.
  Returns {:ok, response} or {:error, reason}.
  """
  def continue_session(session_id, prompt) do
    case TestMode.get_mode() do
      :mock ->
        continue_mock_session(session_id, prompt)

      _live_mode ->
        continue_live_session(session_id, prompt)
    end
  end

  @doc """
  Checkpoint session data for persistence.
  """
  def checkpoint_session(session_id, data) do
    case TestMode.get_mode() do
      :mock ->
        checkpoint_mock_session(session_id, data)

      _live_mode ->
        checkpoint_live_session(session_id, data)
    end
  end

  @doc """
  List all available sessions.
  """
  def list_sessions do
    case TestMode.get_mode() do
      :mock ->
        list_mock_sessions()

      _live_mode ->
        list_live_sessions()
    end
  end

  # Mock implementations (delegate to test mocks)

  defp create_mock_session(session_name, options) do
    session_id = "mock-session-#{session_name}-#{:rand.uniform(10000)}"

    %{
      "session_id" => session_id,
      "session_name" => session_name,
      "created_at" => DateTime.utc_now(),
      "persist" => Map.get(options, "persist", false),
      "status" => "active",
      "max_turns" =>
        Map.get(options, "max_turns", Application.get_env(:pipeline, :max_turns_session, 50)),
      "checkpoint_interval" => Map.get(options, "checkpoint_interval", 5),
      "interactions" => []
    }
  end

  defp get_mock_session(session_id) do
    case String.contains?(session_id, "mock-session") do
      true ->
        %{
          "session_id" => session_id,
          "session_name" => extract_session_name_from_id(session_id),
          "created_at" => DateTime.utc_now(),
          "status" => "active",
          "interactions" => [],
          "checkpoint_count" => :rand.uniform(5)
        }

      false ->
        nil
    end
  end

  defp continue_mock_session(session_id, prompt) do
    case get_mock_session(session_id) do
      nil ->
        {:error, "Session not found"}

      _session ->
        {:ok,
         %{
           "session_id" => session_id,
           "response" => "Mock continuation response for: #{String.slice(prompt, 0, 50)}...",
           "interaction_count" => :rand.uniform(10),
           "status" => "success"
         }}
    end
  end

  defp checkpoint_mock_session(session_id, data) do
    {:ok,
     %{
       "session_id" => session_id,
       "checkpoint_id" => "checkpoint-#{:rand.uniform(1000)}",
       "timestamp" => DateTime.utc_now(),
       "data_size" => byte_size(inspect(data)),
       "status" => "checkpointed"
     }}
  end

  defp list_mock_sessions do
    [
      %{
        "session_id" => "mock-session-1",
        "session_name" => "test_session_1",
        "status" => "active",
        "created_at" => DateTime.utc_now()
      },
      %{
        "session_id" => "mock-session-2",
        "session_name" => "test_session_2",
        "status" => "archived",
        "created_at" => DateTime.utc_now()
      }
    ]
  end

  # Live implementations

  defp create_live_session(session_name, options) do
    session_id = generate_session_id(session_name)

    session_data = %{
      "session_id" => session_id,
      "session_name" => session_name,
      "created_at" => DateTime.utc_now(),
      "persist" => Map.get(options, "persist", false),
      "status" => "active",
      "max_turns" =>
        Map.get(options, "max_turns", Application.get_env(:pipeline, :max_turns_session, 50)),
      "checkpoint_interval" => Map.get(options, "checkpoint_interval", 5),
      "interactions" => [],
      "total_cost" => 0.0,
      "turn_count" => 0
    }

    # Store session in memory (in production, this would be persistent storage)
    store_session(session_id, session_data)

    Logger.debug("📋 Created live session: #{session_id}")
    session_data
  end

  defp get_live_session(session_id) do
    case retrieve_session(session_id) do
      nil ->
        Logger.debug("❌ Session not found: #{session_id}")
        nil

      session_data ->
        Logger.debug("✅ Retrieved session: #{session_id}")
        session_data
    end
  end

  defp continue_live_session(session_id, prompt) do
    case get_live_session(session_id) do
      nil ->
        {:error, "Session not found: #{session_id}"}

      session ->
        turn_count = session["turn_count"] + 1
        max_turns = session["max_turns"]

        if turn_count > max_turns do
          {:error, "Session exceeded maximum turns (#{max_turns})"}
        else
          # Update session with new interaction
          new_interaction = %{
            "turn" => turn_count,
            "prompt" => prompt,
            "timestamp" => DateTime.utc_now()
          }

          updated_session =
            session
            |> Map.put("turn_count", turn_count)
            |> Map.update("interactions", [new_interaction], &[new_interaction | &1])

          store_session(session_id, updated_session)

          {:ok,
           %{
             "session_id" => session_id,
             "turn_count" => turn_count,
             "max_turns" => max_turns,
             "status" => "continued"
           }}
        end
    end
  end

  defp checkpoint_live_session(session_id, data) do
    timestamp = DateTime.utc_now()
    checkpoint_id = "checkpoint-#{System.system_time(:millisecond)}"

    case get_live_session(session_id) do
      nil ->
        {:error, "Session not found for checkpointing: #{session_id}"}

      session ->
        checkpoint_data = %{
          "checkpoint_id" => checkpoint_id,
          "session_id" => session_id,
          "timestamp" => timestamp,
          "data" => data,
          "session_state" => session
        }

        # Store checkpoint (in production, this would be persistent)
        store_checkpoint(checkpoint_id, checkpoint_data)

        Logger.debug("💾 Checkpointed session: #{session_id} -> #{checkpoint_id}")

        {:ok,
         %{
           "session_id" => session_id,
           "checkpoint_id" => checkpoint_id,
           "timestamp" => timestamp,
           "data_size" => byte_size(inspect(data)),
           "status" => "checkpointed"
         }}
    end
  end

  defp list_live_sessions do
    # In production, this would query persistent storage
    get_all_sessions()
    |> Enum.map(fn {session_id, session_data} ->
      %{
        "session_id" => session_id,
        "session_name" => session_data["session_name"],
        "status" => session_data["status"],
        "created_at" => session_data["created_at"],
        "turn_count" => session_data["turn_count"]
      }
    end)
  end

  # Storage helpers (in-memory for now, would be database/file in production)

  defp generate_session_id(session_name) do
    timestamp = System.system_time(:millisecond)
    "session-#{session_name}-#{timestamp}"
  end

  defp store_session(session_id, session_data) do
    # Store in process dictionary for simplicity (would be ETS/database in production)
    sessions = Process.get(:pipeline_sessions, %{})
    Process.put(:pipeline_sessions, Map.put(sessions, session_id, session_data))
  end

  defp retrieve_session(session_id) do
    sessions = Process.get(:pipeline_sessions, %{})
    Map.get(sessions, session_id)
  end

  defp get_all_sessions do
    Process.get(:pipeline_sessions, %{})
  end

  defp store_checkpoint(checkpoint_id, checkpoint_data) do
    # Store checkpoint in process dictionary (would be persistent storage in production)
    checkpoints = Process.get(:pipeline_checkpoints, %{})
    Process.put(:pipeline_checkpoints, Map.put(checkpoints, checkpoint_id, checkpoint_data))
  end

  defp extract_session_name_from_id(session_id) do
    # Extract session name from mock session ID format: "mock-session-{name}-{number}"
    case String.split(session_id, "-") do
      ["mock", "session" | name_parts] ->
        name_parts
        # Remove the random number at the end
        |> Enum.drop(-1)
        |> Enum.join("-")

      _ ->
        "unknown"
    end
  end
end
