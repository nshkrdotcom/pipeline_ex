defmodule Pipeline.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Registry for monitoring processes
      {Registry, keys: :unique, name: Pipeline.MonitoringRegistry}
    ]

    opts = [strategy: :one_for_one, name: Pipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end
end