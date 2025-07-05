defmodule Mix.Tasks.Pipeline.Benchmark do
  @moduledoc """
  Run performance benchmarks comparing sync vs async streaming.

  ## Usage

      mix pipeline.benchmark [options]

  ## Options

    * `--iterations` - Number of iterations per test (default: 5)
    * `--warmup` - Number of warmup iterations (default: 2)
    * `--sizes` - Test sizes to run: small,medium,large (default: all)
    * `--output` - Output directory for reports (default: benchmarks)
    * `--mode` - Run only specific mode: sync, async, or both (default: both)

  ## Examples

      # Run full benchmark suite
      mix pipeline.benchmark

      # Quick benchmark with fewer iterations
      mix pipeline.benchmark --iterations 3 --warmup 1

      # Test only small and medium sizes
      mix pipeline.benchmark --sizes small,medium

      # Benchmark only async mode
      mix pipeline.benchmark --mode async
  """

  use Mix.Task
  require Logger
  alias Pipeline.Performance.BenchmarkRunner

  @shortdoc "Run streaming performance benchmarks"

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    # Parse arguments
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          iterations: :integer,
          warmup: :integer,
          sizes: :string,
          output: :string,
          mode: :string
        ]
      )

    # Configure options
    benchmark_opts = build_options(opts)

    Logger.info("""
    Starting Pipeline Performance Benchmark
    ======================================
    Iterations: #{benchmark_opts.iterations}
    Warmup: #{benchmark_opts.warmup}
    Sizes: #{inspect(benchmark_opts.test_sizes)}
    Mode: #{benchmark_opts.mode || "both"}
    Output: #{benchmark_opts.output_dir}
    """)

    # Run benchmarks
    case run_benchmarks(benchmark_opts) do
      {:ok, report_path} ->
        Logger.info("\n✅ Benchmark completed successfully!")
        Logger.info("📊 Report saved to: #{report_path}")
        Logger.info("\nKey findings:")
        display_key_findings(report_path)

      {:error, reason} ->
        Logger.error("❌ Benchmark failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp build_options(opts) do
    %{
      iterations: opts[:iterations] || 5,
      warmup: opts[:warmup] || 2,
      test_sizes: parse_sizes(opts[:sizes]),
      output_dir: opts[:output] || "benchmarks",
      mode: parse_mode(opts[:mode])
    }
  end

  defp parse_sizes(nil), do: [:small, :medium, :large]

  defp parse_sizes(sizes_str) do
    sizes_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp parse_mode(nil), do: nil
  defp parse_mode("sync"), do: :sync
  defp parse_mode("async"), do: :async
  defp parse_mode("both"), do: nil

  defp parse_mode(other) do
    Logger.warning("Unknown mode: #{other}, using both")
    nil
  end

  defp run_benchmarks(opts) do
    # Filter test configurations based on mode
    opts =
      if opts.mode do
        Map.put(opts, :filter_mode, opts.mode)
      else
        opts
      end

    case BenchmarkRunner.run_suite(Map.to_list(opts)) do
      {:ok, _runner} ->
        # Find the report path
        report_files =
          File.ls!(opts.output_dir)
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.sort()
          |> List.last()

        if report_files do
          {:ok, Path.join(opts.output_dir, report_files)}
        else
          {:error, "Report generation failed"}
        end
    end
  end

  defp display_key_findings(report_path) do
    # Read the JSON report for structured data
    json_path = String.replace(report_path, ".md", ".json")

    case File.read(json_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            comparison = data["comparison"]

            IO.puts("")
            IO.puts("📈 Performance Improvements:")

            IO.puts(
              "   • Time to First Token: #{comparison["comparison"]["ttft_improvement"] || "N/A"}%"
            )

            IO.puts(
              "   • Memory efficiency: #{comparison["comparison"]["memory_efficiency"]["reduction_percent"]}%"
            )

            IO.puts("\n⚡ Average Response Times:")
            IO.puts("   • Sync mode: #{comparison["sync"]["avg_duration_ms"]}ms")
            IO.puts("   • Async mode: #{comparison["async"]["avg_duration_ms"]}ms")

            if comparison["async"]["avg_ttft_ms"] do
              IO.puts("   • Async TTFT: #{comparison["async"]["avg_ttft_ms"]}ms")
            end

          {:error, _} ->
            Logger.warning("Could not parse benchmark results")
        end

      {:error, _} ->
        Logger.warning("Could not read benchmark results")
    end
  end
end
