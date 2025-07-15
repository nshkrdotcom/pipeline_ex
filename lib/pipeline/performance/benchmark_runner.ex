defmodule Pipeline.Performance.BenchmarkRunner do
  @moduledoc """
  Automated benchmark runner for comparing sync vs async streaming performance.

  Provides utilities to run standardized benchmarks and generate reports.
  """

  require Logger
  alias Pipeline.{Executor}
  alias Pipeline.Monitoring.{Performance}
  alias Pipeline.Streaming.PerformanceAnalyzer

  @default_options %{
    iterations: 5,
    warmup: 2,
    output_dir: "benchmarks",
    test_sizes: [:small, :medium, :large]
  }

  defstruct [
    :options,
    :results,
    :analyzer,
    :start_time,
    :end_time
  ]

  @type benchmark_result :: %{
          test_name: String.t(),
          mode: :sync | :async,
          size: atom(),
          iteration: non_neg_integer(),
          duration_ms: non_neg_integer(),
          ttft_ms: non_neg_integer() | nil,
          throughput: float() | nil,
          memory_peak: non_neg_integer(),
          metrics: map()
        }

  @type t :: %__MODULE__{
          options: map(),
          results: list(benchmark_result()),
          analyzer: PerformanceAnalyzer.t(),
          start_time: DateTime.t(),
          end_time: DateTime.t() | nil
        }

  @doc """
  Run a complete benchmark suite comparing sync and async modes.
  """
  @spec run_suite(keyword()) :: {:ok, t()}
  def run_suite(opts \\ []) do
    options = Map.merge(@default_options, Map.new(opts))

    # Ensure output directory exists
    File.mkdir_p!(options.output_dir)

    runner = %__MODULE__{
      options: options,
      results: [],
      analyzer: PerformanceAnalyzer.new(),
      start_time: DateTime.utc_now()
    }

    Logger.info("Starting benchmark suite with #{options.iterations} iterations...")

    # Run warmup
    runner =
      if options.warmup > 0 do
        Logger.info("Running #{options.warmup} warmup iterations...")
        run_warmup(runner)
      else
        runner
      end

    # Run actual benchmarks
    runner =
      options.test_sizes
      |> Enum.reduce(runner, fn size, acc ->
        acc
        |> run_size_benchmarks(size)
      end)

    runner = %{runner | end_time: DateTime.utc_now()}

    # Generate report
    report_path = generate_report(runner)
    Logger.info("Benchmark complete. Report saved to: #{report_path}")

    {:ok, runner}
  end

  @doc """
  Run a specific benchmark test.
  """
  @spec run_single_benchmark(map(), :sync | :async) ::
          {:ok, benchmark_result()} | {:error, term()}
  def run_single_benchmark(workflow, mode) do
    # Ensure the workflow has async settings configured correctly
    workflow = configure_workflow_for_mode(workflow, mode)

    # Start performance monitoring
    pipeline_name = get_in(workflow, ["workflow", "name"])

    case Performance.start_monitoring(pipeline_name) do
      {:ok, _monitor_pid} ->
        # Track start time and memory
        start_time = System.monotonic_time(:millisecond)
        start_memory = :erlang.memory(:total)

        # Execute workflow
        case Executor.execute(workflow) do
          {:ok, results} ->
            end_time = System.monotonic_time(:millisecond)
            end_memory = :erlang.memory(:total)

            # Get performance metrics
            perf_metrics =
              case Performance.stop_monitoring(pipeline_name) do
                {:ok, metrics} -> metrics
                _ -> %{}
              end

            # Extract streaming-specific metrics if async
            streaming_metrics =
              if mode == :async do
                extract_streaming_metrics(results)
              else
                %{}
              end

            {:ok,
             %{
               mode: mode,
               duration_ms: end_time - start_time,
               ttft_ms: streaming_metrics[:ttft_ms],
               throughput: streaming_metrics[:throughput],
               memory_peak: max(end_memory, start_memory),
               memory_delta: end_memory - start_memory,
               metrics: Map.merge(perf_metrics, streaming_metrics)
             }}

          {:error, reason} ->
            _ = Performance.stop_monitoring(pipeline_name)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, {:monitoring_failed, reason}}
    end
  end

  @doc """
  Compare results between sync and async modes.
  """
  @spec compare_results(list(benchmark_result())) :: map()
  def compare_results(results) do
    sync_results = Enum.filter(results, &(&1.mode == :sync))
    async_results = Enum.filter(results, &(&1.mode == :async))

    %{
      sync: calculate_summary(sync_results),
      async: calculate_summary(async_results),
      comparison: %{
        ttft_improvement: calculate_ttft_improvement(sync_results, async_results),
        memory_efficiency: calculate_memory_efficiency(sync_results, async_results),
        throughput_comparison: compare_throughput(sync_results, async_results)
      }
    }
  end

  # Private functions

  defp run_warmup(runner) do
    warmup_workflow = create_test_workflow("warmup", "Simple warmup test", :small)

    Enum.reduce(1..runner.options.warmup, runner, fn i, acc ->
      Logger.debug("Warmup iteration #{i}")

      # Run both sync and async to warm up the system
      _ = run_single_benchmark(warmup_workflow, :sync)
      _ = run_single_benchmark(warmup_workflow, :async)

      # Don't save warmup results
      acc
    end)
  end

  defp run_size_benchmarks(runner, size) do
    Logger.info("Running benchmarks for size: #{size}")

    test_config = get_test_config(size)
    workflow = create_test_workflow("bench_#{size}", test_config.prompt, size)

    # Run iterations for both modes
    results =
      Enum.flat_map([:sync, :async], fn mode ->
        Enum.map(1..runner.options.iterations, fn iteration ->
          Logger.debug("Running #{mode} iteration #{iteration} for #{size}")

          case run_single_benchmark(workflow, mode) do
            {:ok, result} ->
              Map.merge(result, %{
                test_name: "bench_#{size}",
                size: size,
                iteration: iteration
              })

            {:error, reason} ->
              Logger.error("Benchmark failed: #{inspect(reason)}")
              nil
          end
        end)
      end)
      |> Enum.reject(&is_nil/1)

    # Update analyzer with async results
    async_results = Enum.filter(results, &(&1.mode == :async))

    updated_analyzer =
      Enum.reduce(async_results, runner.analyzer, fn result, analyzer ->
        if result.metrics[:stream_id] do
          analyzer
          |> PerformanceAnalyzer.start_stream(result.metrics.stream_id, :benchmark)
          |> PerformanceAnalyzer.complete_stream(result.metrics.stream_id)
        else
          analyzer
        end
      end)

    %{runner | results: runner.results ++ results, analyzer: updated_analyzer}
  end

  defp configure_workflow_for_mode(workflow, :sync) do
    put_in(
      workflow,
      ["workflow", "steps", Access.all(), "claude_options", "async_streaming"],
      false
    )
  end

  defp configure_workflow_for_mode(workflow, :async) do
    workflow
    |> put_in(["workflow", "steps", Access.all(), "claude_options", "async_streaming"], true)
    |> put_in(["workflow", "steps", Access.all(), "claude_options", "stream_handler"], "simple")
    |> put_in(["workflow", "steps", Access.all(), "claude_options", "stream_handler_opts"], %{
      "show_timestamps" => false,
      "track_metrics" => true
    })
  end

  defp get_test_config(:small) do
    %{
      prompt: "Generate a list of 5 items",
      expected_tokens: 50,
      expected_duration: 1000
    }
  end

  defp get_test_config(:medium) do
    %{
      prompt: "Generate a detailed list of 25 items with descriptions",
      expected_tokens: 500,
      expected_duration: 3000
    }
  end

  defp get_test_config(:large) do
    %{
      prompt:
        "Generate a comprehensive report with 50 sections, each containing analysis and recommendations",
      expected_tokens: 2000,
      expected_duration: 8000
    }
  end

  defp create_test_workflow(name, prompt, _size) do
    %{
      "workflow" => %{
        "name" => name,
        "steps" => [
          %{
            "name" => "benchmark_step",
            "type" => "claude",
            "claude_options" => %{
              "max_turns" => 1,
              "system_prompt" => "You are a benchmark assistant. Respond concisely."
            },
            "prompt" => [
              %{"type" => "static", "content" => prompt}
            ]
          }
        ]
      }
    }
  end

  defp extract_streaming_metrics(results) do
    # Look for async response metrics in results
    step_result = results["benchmark_step"] || %{}

    %{
      ttft_ms: step_result["time_to_first_token_ms"],
      throughput: step_result["tokens_per_second"],
      message_count: step_result["message_count"],
      stream_id: step_result["stream_id"]
    }
  end

  defp calculate_summary([]) do
    %{
      avg_duration_ms: 0,
      avg_ttft_ms: nil,
      avg_throughput: nil,
      avg_memory_mb: 0,
      p95_duration_ms: 0,
      p99_duration_ms: 0
    }
  end

  defp calculate_summary(results) do
    durations = Enum.map(results, & &1.duration_ms) |> Enum.sort()
    ttfts = results |> Enum.map(& &1.ttft_ms) |> Enum.reject(&is_nil/1)
    throughputs = results |> Enum.map(& &1.throughput) |> Enum.reject(&is_nil/1)
    memories = Enum.map(results, & &1.memory_peak)

    %{
      avg_duration_ms: average(durations),
      avg_ttft_ms: if(Enum.empty?(ttfts), do: nil, else: average(ttfts)),
      avg_throughput: if(Enum.empty?(throughputs), do: nil, else: average(throughputs)),
      avg_memory_mb: average(memories) / (1024 * 1024),
      p95_duration_ms: percentile(durations, 0.95),
      p99_duration_ms: percentile(durations, 0.99),
      sample_count: length(results)
    }
  end

  defp calculate_ttft_improvement(sync_results, async_results) do
    sync_avg = average(Enum.map(sync_results, & &1.duration_ms))
    async_ttfts = async_results |> Enum.map(& &1.ttft_ms) |> Enum.reject(&is_nil/1)

    if Enum.empty?(async_ttfts) do
      nil
    else
      async_avg_ttft = average(async_ttfts)
      improvement = (sync_avg - async_avg_ttft) / sync_avg * 100
      Float.round(improvement, 2)
    end
  end

  defp calculate_memory_efficiency(sync_results, async_results) do
    sync_avg_memory = average(Enum.map(sync_results, & &1.memory_peak))
    async_avg_memory = average(Enum.map(async_results, & &1.memory_peak))

    %{
      sync_avg_mb: sync_avg_memory / (1024 * 1024),
      async_avg_mb: async_avg_memory / (1024 * 1024),
      reduction_percent:
        Float.round((sync_avg_memory - async_avg_memory) / sync_avg_memory * 100, 2)
    }
  end

  defp compare_throughput(sync_results, async_results) do
    sync_throughputs = sync_results |> Enum.map(& &1.throughput) |> Enum.reject(&is_nil/1)
    async_throughputs = async_results |> Enum.map(& &1.throughput) |> Enum.reject(&is_nil/1)

    %{
      sync_avg: if(Enum.empty?(sync_throughputs), do: nil, else: average(sync_throughputs)),
      async_avg: if(Enum.empty?(async_throughputs), do: nil, else: average(async_throughputs))
    }
  end

  defp average([]), do: 0
  defp average(list), do: Enum.sum(list) / length(list)

  defp percentile([], _), do: 0

  defp percentile(sorted_list, p) do
    index = round(p * (length(sorted_list) - 1))
    Enum.at(sorted_list, index)
  end

  defp generate_report(runner) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    report_filename = "benchmark_report_#{timestamp}.md"
    report_path = Path.join(runner.options.output_dir, report_filename)

    comparison = compare_results(runner.results)
    analyzer_report = PerformanceAnalyzer.get_report(runner.analyzer)

    report_content = """
    # Pipeline Streaming Performance Benchmark Report

    Generated: #{DateTime.utc_now() |> DateTime.to_string()}
    Duration: #{DateTime.diff(runner.end_time, runner.start_time, :second)} seconds

    ## Configuration
    - Iterations: #{runner.options.iterations}
    - Warmup: #{runner.options.warmup}
    - Test sizes: #{inspect(runner.options.test_sizes)}

    ## Summary Results

    ### Synchronous Mode
    - Average duration: #{comparison.sync.avg_duration_ms}ms
    - P95 duration: #{comparison.sync.p95_duration_ms}ms
    - P99 duration: #{comparison.sync.p99_duration_ms}ms
    - Average memory: #{Float.round(comparison.sync.avg_memory_mb, 2)}MB

    ### Asynchronous Streaming Mode
    - Average duration: #{comparison.async.avg_duration_ms}ms
    - Average TTFT: #{comparison.async.avg_ttft_ms || "N/A"}ms
    - Average throughput: #{comparison.async.avg_throughput || "N/A"} tokens/sec
    - P95 duration: #{comparison.async.p95_duration_ms}ms
    - P99 duration: #{comparison.async.p99_duration_ms}ms
    - Average memory: #{Float.round(comparison.async.avg_memory_mb, 2)}MB

    ## Performance Improvements
    - TTFT improvement: #{comparison.comparison.ttft_improvement || "N/A"}%
    - Memory reduction: #{comparison.comparison.memory_efficiency.reduction_percent}%

    ## Detailed Results by Size

    #{generate_size_breakdown(runner.results)}

    ## Streaming Performance Analysis
    - Total streams analyzed: #{analyzer_report.total_streams}
    - Performance issues found: #{analyzer_report.issues_found}

    ### Recommendations
    #{Enum.map(analyzer_report.recommendations, fn rec -> "- #{rec}" end) |> Enum.join("\n")}

    ## Raw Data

    Full results available in: #{report_path}.json
    """

    # Write report
    File.write!(report_path, report_content)

    # Also save raw data as JSON
    json_path = String.replace(report_path, ".md", ".json")

    json_data = %{
      config: runner.options,
      results: runner.results,
      comparison: comparison,
      analyzer_report: analyzer_report
    }

    File.write!(json_path, Jason.encode!(json_data, pretty: true))

    report_path
  end

  defp generate_size_breakdown(results) do
    results
    |> Enum.group_by(& &1.size)
    |> Enum.map(fn {size, size_results} ->
      sync = Enum.filter(size_results, &(&1.mode == :sync))
      async = Enum.filter(size_results, &(&1.mode == :async))

      """
      ### #{String.capitalize(to_string(size))} Size
      - Sync avg: #{average(Enum.map(sync, & &1.duration_ms))}ms
      - Async avg: #{average(Enum.map(async, & &1.duration_ms))}ms
      - Async TTFT: #{format_ttft_average(async)}ms
      """
    end)
    |> Enum.join("\n")
  end

  defp format_ttft_average(async_results) do
    ttft_values =
      async_results
      |> Enum.map(& &1.ttft_ms)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(ttft_values) do
      "N/A"
    else
      average(ttft_values)
    end
  end
end
