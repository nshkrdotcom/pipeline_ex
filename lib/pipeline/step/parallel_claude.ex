defmodule Pipeline.Step.ParallelClaude do
  @moduledoc """
  Executes multiple Claude tasks in parallel.
  """

  alias Pipeline.Step.Claude
  require Logger

  def execute(step, context) do
    tasks = step["parallel_tasks"] || []

    Logger.info("💪💪 Running #{length(tasks)} Claude tasks in parallel")
    Logger.info("🔍 Debug: LLM call type: ASYNCHRONOUS PARALLEL (multiple subprocesses)")

    Logger.info(
      "🚀 Debug: Starting #{length(tasks)} parallel LLM calls to Claude NOW at #{DateTime.utc_now()}"
    )

    # Create async tasks for each parallel task
    async_tasks =
      Enum.map(tasks, fn task ->
        Task.async(fn ->
          # Create a step-like structure for each task
          claude_step = %{
            "name" => task["id"],
            "type" => "claude",
            "claude_options" => task["claude_options"],
            "prompt" => task["prompt"],
            "output_to_file" => task["output_to_file"]
          }

          # Execute the task
          result = Claude.execute(claude_step, context)
          {task["id"], result}
        end)
      end)

    # Wait for all tasks to complete
    results =
      Task.await_many(async_tasks, :infinity)
      |> Map.new()

    # Combine results
    combined_text =
      tasks
      |> Enum.map(fn task ->
        "\n===[#{task["id"]}]===\n" <> inspect(results[task["id"]])
      end)
      |> Enum.join("\n")

    combined_result = %{
      combined_results: combined_text,
      individual_results: results
    }

    # Save combined results if specified
    if step["output_to_file"] do
      save_output(context.output_dir, step["output_to_file"], combined_result)
    end

    {:ok, combined_result}
  end

  defp save_output(output_dir, filename, data) do
    filepath = Path.join(output_dir, filename)
    File.mkdir_p!(Path.dirname(filepath))

    content =
      if is_binary(data) do
        data
      else
        Jason.encode!(data, pretty: true)
      end

    File.write!(filepath, content)
    Logger.info("📁 Saved output to: #{filepath}")
  end
end
