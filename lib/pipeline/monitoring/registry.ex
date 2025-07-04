defmodule Pipeline.Monitoring.Registry do
  @moduledoc """
  Registry for pipeline monitoring processes.
  """

  def child_spec(_args) do
    Registry.child_spec(
      keys: :unique,
      name: Pipeline.MonitoringRegistry
    )
  end
end
