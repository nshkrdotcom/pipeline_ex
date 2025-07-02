defmodule Pipeline.MABEAM.Agents.PipelineWorker do
  use Jido.Agent,
    name: "pipeline_worker",
    description: "Executes individual pipelines with specialization",
    actions: [
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      Pipeline.MABEAM.Actions.HealthCheck
    ],
    schema: [
      worker_id: [type: :string, required: true, doc: "Unique worker identifier"],
      specialization: [type: :atom, default: :general, doc: "Worker specialization type"],
      status: [type: :atom, default: :idle, doc: "Current worker status"],
      current_pipeline: [type: :map, default: nil, doc: "Currently executing pipeline"],
      execution_count: [type: :integer, default: 0, doc: "Number of completed executions"],
      last_execution: [type: :map, default: nil, doc: "Last execution details"]
    ]
end