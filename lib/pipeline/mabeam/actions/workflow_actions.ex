defmodule Pipeline.MABEAM.Actions.ExecutePipelineAsync do
  use Jido.Action,
    name: "execute_pipeline_async",
    description: "Executes pipeline asynchronously with full Jido Workflow features",
    schema: [
      pipeline_file: [type: :string, required: true, doc: "Path to YAML pipeline file"],
      workspace_dir: [type: :string, default: "./workspace", doc: "Workspace directory"],
      output_dir: [type: :string, default: "./outputs", doc: "Output directory"],
      debug: [type: :boolean, default: false, doc: "Enable debug mode"],
      timeout: [type: :pos_integer, default: 300_000, doc: "Execution timeout in milliseconds"],
      max_retries: [type: :integer, default: 3, doc: "Maximum retry attempts"],
      telemetry_level: [
        type: :atom,
        default: :full,
        doc: "Telemetry level (:full, :minimal, :silent)"
      ]
    ]

  @impl true
  def run(params, context) do
    # Use Jido Exec for advanced execution
    try do
      async_ref =
        Jido.Exec.run_async(
          Pipeline.MABEAM.Actions.ExecutePipelineYaml,
          %{
            pipeline_file: params.pipeline_file,
            workspace_dir: params.workspace_dir,
            output_dir: params.output_dir,
            debug: params.debug
          },
          context,
          timeout: params.timeout,
          max_retries: params.max_retries
        )

      {:ok,
       %{
         async_ref: async_ref,
         status: :started,
         pipeline_file: params.pipeline_file,
         started_at: DateTime.utc_now()
       }}
    rescue
      error ->
        {:error, "Failed to start async pipeline execution: #{inspect(error)}"}
    end
  end
end

defmodule Pipeline.MABEAM.Actions.AwaitPipelineResult do
  use Jido.Action,
    name: "await_pipeline_result",
    description: "Awaits result from async pipeline execution",
    schema: [
      async_ref: [type: :any, required: true, doc: "Async reference from ExecutePipelineAsync"],
      timeout: [type: :pos_integer, default: 300_000, doc: "Await timeout in milliseconds"]
    ]

  @impl true
  def run(params, _context) do
    case Jido.Exec.await(params.async_ref, params.timeout) do
      {:ok, result} ->
        {:ok,
         %{
           status: :completed,
           result: result,
           completed_at: DateTime.utc_now()
         }}

      {:error, %Jido.Error{type: :timeout} = error} ->
        {:error, "Pipeline execution timed out: #{error.message}"}

      {:error, %Jido.Error{} = error} ->
        {:error, "Pipeline execution failed: #{error.message}"}
    end
  end
end

defmodule Pipeline.MABEAM.Actions.CancelPipelineExecution do
  use Jido.Action,
    name: "cancel_pipeline_execution",
    description: "Cancels an async pipeline execution",
    schema: [
      async_ref: [type: :any, required: true, doc: "Async reference from ExecutePipelineAsync"]
    ]

  @impl true
  def run(params, _context) do
    case Jido.Exec.cancel(params.async_ref) do
      :ok ->
        {:ok,
         %{
           status: :cancelled,
           cancelled_at: DateTime.utc_now()
         }}

      {:error, %Jido.Error{type: :not_found} = error} ->
        {:error, "Pipeline execution not found or already completed: #{error.message}"}

      {:error, %Jido.Error{} = error} ->
        {:error, "Failed to cancel pipeline execution: #{error.message}"}
    end
  end
end

defmodule Pipeline.MABEAM.Actions.GetPipelineStatus do
  use Jido.Action,
    name: "get_pipeline_status",
    description: "Gets the status of an async pipeline execution",
    schema: [
      async_ref: [type: :any, required: true, doc: "Async reference from ExecutePipelineAsync"]
    ]

  @impl true
  def run(params, _context) do
    # Jido.Exec doesn't have a status function, so we'll check if the process is alive
    case params.async_ref do
      %{pid: pid} when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok,
           %{
             status: :running,
             checked_at: DateTime.utc_now()
           }}
        else
          {:ok,
           %{
             status: :completed_or_failed,
             checked_at: DateTime.utc_now()
           }}
        end

      _ ->
        {:error, "Invalid async reference"}
    end
  end
end

defmodule Pipeline.MABEAM.Actions.BatchExecutePipelines do
  use Jido.Action,
    name: "batch_execute_pipelines",
    description: "Executes multiple pipelines concurrently with async workflows",
    schema: [
      pipeline_files: [
        type: {:list, :string},
        required: true,
        doc: "List of pipeline files to execute"
      ],
      workspace_dir: [type: :string, default: "./workspace", doc: "Workspace directory"],
      output_dir: [type: :string, default: "./outputs", doc: "Output directory"],
      debug: [type: :boolean, default: false, doc: "Enable debug mode"],
      timeout: [type: :pos_integer, default: 300_000, doc: "Per-pipeline timeout"],
      max_retries: [type: :integer, default: 3, doc: "Maximum retry attempts per pipeline"],
      concurrent_limit: [type: :pos_integer, default: 5, doc: "Maximum concurrent executions"]
    ]

  @impl true
  def run(params, context) do
    # Start all pipelines asynchronously
    try do
      async_refs =
        params.pipeline_files
        # Limit concurrency
        |> Enum.take(params.concurrent_limit)
        |> Enum.map(fn pipeline_file ->
          async_ref =
            Jido.Exec.run_async(
              Pipeline.MABEAM.Actions.ExecutePipelineYaml,
              %{
                pipeline_file: pipeline_file,
                workspace_dir: params.workspace_dir,
                output_dir: params.output_dir,
                debug: params.debug
              },
              context,
              timeout: params.timeout,
              max_retries: params.max_retries
            )

          {pipeline_file, async_ref}
        end)

      {:ok,
       %{
         batch_id: generate_batch_id(),
         pipeline_refs: async_refs,
         total_pipelines: length(params.pipeline_files),
         started_at: DateTime.utc_now()
       }}
    rescue
      error ->
        {:error, "Failed to start batch pipeline execution: #{inspect(error)}"}
    end
  end

  defp generate_batch_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end

defmodule Pipeline.MABEAM.Actions.AwaitBatchResults do
  use Jido.Action,
    name: "await_batch_results",
    description: "Awaits results from batch pipeline execution",
    schema: [
      pipeline_refs: [
        type: {:list, :any},
        required: true,
        doc: "List of {pipeline_file, async_ref} tuples"
      ],
      timeout: [type: :pos_integer, default: 600_000, doc: "Total await timeout"]
    ]

  @impl true
  def run(params, _context) do
    results =
      params.pipeline_refs
      |> Enum.map(fn {pipeline_file, async_ref} ->
        case Jido.Exec.await(async_ref, params.timeout) do
          {:ok, result} ->
            {pipeline_file, :success, result}

          {:error, reason} ->
            {pipeline_file, :error, reason}
        end
      end)

    successful = Enum.count(results, fn {_, status, _} -> status == :success end)
    failed = length(results) - successful

    {:ok,
     %{
       results: results,
       summary: %{
         total: length(results),
         successful: successful,
         failed: failed,
         success_rate: successful / length(results)
       },
       completed_at: DateTime.utc_now()
     }}
  end
end
