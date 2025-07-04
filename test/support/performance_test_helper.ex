defmodule Pipeline.Test.PerformanceTestHelper do
  @moduledoc """
  Test helper for performance-related tests.

  Provides utilities for:
  - Safe monitoring process management
  - Test file fixtures
  - Memory usage mocking
  - Process cleanup
  """

  alias Pipeline.Monitoring.Performance

  @doc """
  Start monitoring for a test with automatic cleanup.
  """
  def start_test_monitoring(test_name, opts \\ []) do
    # Ensure any existing monitoring is stopped first
    stop_test_monitoring(test_name)

    # Start with test-specific configuration
    test_opts =
      Keyword.merge(
        [
          # Lower threshold for testing
          memory_threshold: 50_000_000,
          # Shorter timeout for testing
          execution_threshold: 10
        ],
        opts
      )

    case Performance.start_monitoring(test_name, test_opts) do
      {:ok, pid} ->
        # Register for cleanup
        ExUnit.Callbacks.on_exit(fn ->
          stop_test_monitoring(test_name)
        end)

        {:ok, pid}

      error ->
        error
    end
  end

  @doc """
  Stop monitoring for a test safely.
  """
  def stop_test_monitoring(test_name) do
    try do
      case Performance.stop_monitoring(test_name) do
        {:ok, metrics} -> {:ok, metrics}
        {:error, :not_found} -> :ok
        error -> error
      end
    rescue
      _ -> :ok
    end
  end

  @doc """
  Create a test workspace directory.
  """
  def create_test_workspace(test_name) do
    workspace_dir = Path.join(["test", "tmp", "performance", test_name])
    File.rm_rf!(workspace_dir)
    File.mkdir_p!(workspace_dir)

    # Register for cleanup
    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!(workspace_dir)
    end)

    workspace_dir
  end

  @doc """
  Create a test file with specified content.
  """
  def create_test_file(workspace_dir, filename, content_or_size) do
    file_path = Path.join(workspace_dir, filename)

    case content_or_size do
      content when is_binary(content) ->
        File.write!(file_path, content)

      size when is_integer(size) ->
        # Create file of specified size in KB
        content = String.duplicate("test line #{:rand.uniform(1000)}\n", size * 40)
        File.write!(file_path, content)
    end

    file_path
  end

  @doc """
  Generate test data of specified size.
  """
  def generate_test_data(size, type \\ :list) do
    case type do
      :list ->
        1..size
        |> Enum.map(fn i ->
          %{
            "id" => i,
            "name" => "item_#{i}",
            "priority" => rem(i, 3) + 1,
            "active" => rem(i, 2) == 0,
            "data" => "test_data_#{i}"
          }
        end)

      :binary ->
        String.duplicate("test data line #{:rand.uniform(1000)}\n", size)

      :map ->
        1..size
        |> Enum.reduce(%{}, fn i, acc ->
          Map.put(acc, "key_#{i}", "value_#{i}")
        end)
    end
  end

  @doc """
  Wait for a condition to be true with timeout.
  """
  def wait_for(condition_fn, timeout \\ 5000, interval \\ 100) do
    end_time = System.monotonic_time(:millisecond) + timeout
    wait_for_condition(condition_fn, end_time, interval)
  end

  defp wait_for_condition(condition_fn, end_time, interval) do
    if condition_fn.() do
      :ok
    else
      current_time = System.monotonic_time(:millisecond)

      if current_time > end_time do
        {:error, :timeout}
      else
        Process.sleep(interval)
        wait_for_condition(condition_fn, end_time, interval)
      end
    end
  end

  @doc """
  Mock system memory for testing.
  """
  def mock_system_memory(memory_bytes) do
    # Override the memory function for testing
    # This would require updating the Performance module to be testable
    :ok
  end

  @doc """
  Assert that performance metrics meet expectations.
  """
  def assert_performance_metrics(metrics, expectations) do
    Enum.each(expectations, fn {key, expected} ->
      actual = Map.get(metrics, key)

      case expected do
        {:less_than, value} ->
          assert actual < value, "Expected #{key} (#{actual}) to be less than #{value}"

        {:greater_than, value} ->
          assert actual > value, "Expected #{key} (#{actual}) to be greater than #{value}"

        {:equals, value} ->
          assert actual == value, "Expected #{key} (#{actual}) to equal #{value}"

        value ->
          assert actual == value, "Expected #{key} (#{actual}) to equal #{value}"
      end
    end)
  end

  @doc """
  Clean up all test processes and files.
  """
  def cleanup_all_test_resources do
    # Stop all monitoring processes
    Registry.select(Pipeline.MonitoringRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$2"]}])
    |> Enum.each(fn pid ->
      if Process.alive?(pid) do
        Process.exit(pid, :kill)
      end
    end)

    # Clean up test files
    File.rm_rf!("test/tmp/performance")

    :ok
  end
end
