defmodule Pipeline.Providers.ClaudeCode do
  @moduledoc """
  Claude Code SDK provider for live execution.

  This module provides the interface to the actual Claude Code SDK
  for production usage. In test mode, Pipeline.Test.Mocks.ClaudeProvider
  is used instead.
  """

  @doc """
  Execute a query with the Claude Code SDK.

  In the current implementation, this is a placeholder that would
  integrate with the actual Claude Code SDK in a production environment.
  """
  def query(_prompt, _options) do
    # This would integrate with the actual Claude Code SDK
    # For now, return an error indicating this is not implemented
    {:error, "Live Claude Code SDK integration not yet implemented. Use test mode."}
  end
end
