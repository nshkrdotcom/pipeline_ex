defmodule Pipeline do
  @moduledoc """
  Pipeline Orchestration System for combining Gemini (Brain) and Claude (Muscle).
  """

  alias Pipeline.Orchestrator

  @doc """
  Run a pipeline from a configuration file.
  """
  def run(config_path) do
    with {:ok, orchestrator} <- Orchestrator.new(config_path) do
      Orchestrator.run(orchestrator)
    end
  end
end
