defmodule Pipeline.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    base_children = [
      # Registry for monitoring processes
      {Registry, keys: :unique, name: Pipeline.MonitoringRegistry}
    ]

    children = if Application.get_env(:pipeline, :mabeam_enabled, false) do
      base_children ++ [Pipeline.MABEAM.Supervisor]
    else
      base_children
    end

    opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
