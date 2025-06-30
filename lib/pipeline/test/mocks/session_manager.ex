defmodule Pipeline.Test.Mocks.SessionManager do
  @moduledoc """
  Mock implementation of Session Manager for testing claude_session steps.
  """

  @doc """
  Create a new session with the given name and options.
  """
  def create_session(session_name, options \\ %{}) do
    session_id = "mock-session-#{session_name}-#{:rand.uniform(10000)}"

    session = %{
      "session_id" => session_id,
      "session_name" => session_name,
      "created_at" => DateTime.utc_now(),
      "persist" => Map.get(options, "persist", false),
      "continue_on_restart" => Map.get(options, "continue_on_restart", false),
      "checkpoint_frequency" => Map.get(options, "checkpoint_frequency", 5),
      "description" => Map.get(options, "description", "Mock session"),
      "status" => "active",
      "interaction_count" => 0,
      "last_interaction" => nil,
      "checkpoints" => []
    }

    # Store in process dictionary for this test session
    Process.put({:session, session_name}, session)
    {:ok, session}
  end

  @doc """
  Get an existing session by name.
  """
  def get_session(session_name) do
    case Process.get({:session, session_name}) do
      nil -> nil
      session -> session
    end
  end

  @doc """
  Continue an existing session with a new prompt.
  """
  def continue_session(session_id, prompt) do
    # Find session by ID
    session = find_session_by_id(session_id)

    case session do
      nil ->
        {:error, "Session not found: #{session_id}"}

      session ->
        # Update interaction count
        updated_session = %{
          session
          | "interaction_count" => session["interaction_count"] + 1,
            "last_interaction" => DateTime.utc_now()
        }

        # Store updated session
        Process.put({:session, session["session_name"]}, updated_session)

        {:ok,
         %{
           "session_id" => session_id,
           "response" => "Mock continuation response for: #{String.slice(prompt, 0, 50)}...",
           "interaction_count" => updated_session["interaction_count"],
           "continued" => true
         }}
    end
  end

  @doc """
  Checkpoint session data for persistence.
  """
  def checkpoint_session(session_id, data) do
    session = find_session_by_id(session_id)

    case session do
      nil ->
        {:error, "Session not found for checkpointing: #{session_id}"}

      session ->
        checkpoint = %{
          "checkpoint_id" => "checkpoint-#{:rand.uniform(1000)}",
          "timestamp" => DateTime.utc_now(),
          "data_size" => byte_size(inspect(data)),
          "data" => data
        }

        # Add checkpoint to session
        updated_checkpoints = [checkpoint | session["checkpoints"]]
        updated_session = %{session | "checkpoints" => updated_checkpoints}

        # Store updated session
        Process.put({:session, session["session_name"]}, updated_session)

        {:ok, checkpoint}
    end
  end

  @doc """
  List all active sessions.
  """
  def list_sessions do
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:session, _}, key) end)
    |> Enum.map(fn {_, session_name} ->
      session = Process.get({:session, session_name})

      %{
        "session_id" => session["session_id"],
        "session_name" => session["session_name"],
        "status" => session["status"],
        "created_at" => session["created_at"],
        "interaction_count" => session["interaction_count"]
      }
    end)
  end

  @doc """
  Close and cleanup a session.
  """
  def close_session(session_name) do
    case Process.get({:session, session_name}) do
      nil ->
        {:error, "Session not found: #{session_name}"}

      session ->
        # Mark as closed
        closed_session = %{session | "status" => "closed", "closed_at" => DateTime.utc_now()}
        Process.put({:session, session_name}, closed_session)
        {:ok, closed_session}
    end
  end

  @doc """
  Reset all mock sessions (for testing cleanup).
  """
  def reset_all_sessions do
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:session, _}, key) end)
    |> Enum.each(&Process.delete/1)

    :ok
  end

  # Private helper functions

  defp find_session_by_id(session_id) do
    Process.get_keys()
    |> Enum.filter(fn key -> match?({:session, _}, key) end)
    |> Enum.find_value(fn {_, session_name} ->
      session = Process.get({:session, session_name})
      if session["session_id"] == session_id, do: session, else: nil
    end)
  end
end
