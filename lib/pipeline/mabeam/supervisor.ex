defmodule Pipeline.MABEAM.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Main pipeline manager
      {Pipeline.MABEAM.Agents.PipelineManager, id: "pipeline_manager"},

      # Default worker pool - use Supervisor.child_spec/2 for unique IDs
      Supervisor.child_spec(
        {Pipeline.MABEAM.Agents.PipelineWorker, worker_id: "worker_1"},
        id: :worker_1
      ),
      Supervisor.child_spec(
        {Pipeline.MABEAM.Agents.PipelineWorker, worker_id: "worker_2"},
        id: :worker_2
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
