defmodule Pipeline.MABEAM.Agents.PipelineManager do
  use Jido.Agent,
    name: "pipeline_manager",
    description: "Manages pipeline execution with state tracking",
    actions: [
      Pipeline.MABEAM.Actions.ExecutePipelineYaml,
      Pipeline.MABEAM.Actions.GeneratePipeline,
      Pipeline.MABEAM.Actions.HealthCheck,
      # Add built-in Jido actions for state management
      Jido.Actions.Directives.RegisterAction
    ],
    schema: [
      execution_history: [type: {:list, :map}, default: [], doc: "History of pipeline executions"],
      current_execution: [type: :map, default: nil, doc: "Currently running pipeline"],
      total_executions: [type: :integer, default: 0, doc: "Total number of executions"],
      queue: [type: {:list, :map}, default: [], doc: "Pending pipeline executions"],
      stats: [type: :map, default: %{}, doc: "Execution statistics"]
    ]

  # Jido automatically handles:
  # - State validation using schema
  # - Action routing and execution
  # - Error handling and recovery
  # - Instruction processing
  # - OTP supervision integration
end