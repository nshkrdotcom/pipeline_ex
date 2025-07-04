defmodule Pipeline.Safety.ResourceMonitorTest do
  use ExUnit.Case, async: true
  alias Pipeline.Safety.ResourceMonitor

  describe "check_limits/2" do
    test "passes when within memory limits" do
      usage = %{
        # 100MB
        memory_bytes: 100_000_000,
        start_time: DateTime.utc_now(),
        elapsed_ms: 5000
      }

      limits = %{
        memory_limit_mb: 1024,
        timeout_seconds: 300
      }

      assert :ok = ResourceMonitor.check_limits(usage, limits)
    end

    test "fails when memory limit exceeded" do
      usage = %{
        # ~1.9GB
        memory_bytes: 2_000_000_000,
        start_time: DateTime.utc_now(),
        elapsed_ms: 5000
      }

      limits = %{
        # 1GB
        memory_limit_mb: 1024,
        timeout_seconds: 300
      }

      assert {:error, message} = ResourceMonitor.check_limits(usage, limits)
      assert message =~ "Memory limit exceeded"
      assert message =~ "1907.3 MB > 1024 MB"
    end

    test "passes when within timeout limits" do
      usage = %{
        memory_bytes: 100_000_000,
        start_time: DateTime.utc_now(),
        # 30 seconds
        elapsed_ms: 30_000
      }

      limits = %{
        memory_limit_mb: 1024,
        timeout_seconds: 60
      }

      assert :ok = ResourceMonitor.check_limits(usage, limits)
    end

    test "fails when timeout exceeded" do
      usage = %{
        memory_bytes: 100_000_000,
        start_time: DateTime.utc_now(),
        # 400 seconds
        elapsed_ms: 400_000
      }

      limits = %{
        memory_limit_mb: 1024,
        # 5 minutes
        timeout_seconds: 300
      }

      assert {:error, message} = ResourceMonitor.check_limits(usage, limits)
      assert message =~ "Execution timeout exceeded"
      assert message =~ "400.0s > 300s"
    end

    test "uses default limits when not provided" do
      usage = %{
        memory_bytes: 100_000_000,
        start_time: DateTime.utc_now(),
        elapsed_ms: 5000
      }

      assert :ok = ResourceMonitor.check_limits(usage)
    end
  end

  describe "collect_usage/1" do
    test "collects current usage with provided start time" do
      start_time = DateTime.add(DateTime.utc_now(), -5, :second)
      usage = ResourceMonitor.collect_usage(start_time)

      assert is_integer(usage.memory_bytes)
      assert usage.memory_bytes > 0
      assert usage.start_time == start_time
      # At least 4 seconds elapsed
      assert usage.elapsed_ms >= 4000
      # At most 6 seconds elapsed
      assert usage.elapsed_ms <= 6000
    end

    test "collects current usage with current time as default" do
      usage = ResourceMonitor.collect_usage()

      assert is_integer(usage.memory_bytes)
      assert usage.memory_bytes > 0
      # Should be very small
      assert usage.elapsed_ms < 100
    end
  end

  describe "monitor_execution/2" do
    test "passes when execution is within limits" do
      start_time = DateTime.add(DateTime.utc_now(), -5, :second)

      limits = %{
        memory_limit_mb: 1024,
        timeout_seconds: 300
      }

      assert :ok = ResourceMonitor.monitor_execution(start_time, limits)
    end

    test "fails when memory limit would be exceeded" do
      start_time = DateTime.add(DateTime.utc_now(), -5, :second)

      # Set very low memory limit to trigger failure
      limits = %{
        # 1MB - should be exceeded
        memory_limit_mb: 1,
        timeout_seconds: 300
      }

      assert {:error, message} = ResourceMonitor.monitor_execution(start_time, limits)
      assert message =~ "Memory limit exceeded"
    end
  end

  describe "create_workspace/2" do
    test "creates workspace directory successfully" do
      base_path = System.tmp_dir!()
      test_workspace = Path.join(base_path, "test_workspace_#{:rand.uniform(1000)}")

      # Ensure the directory doesn't exist
      File.rm_rf!(test_workspace)

      assert {:ok, workspace_path} = ResourceMonitor.create_workspace(test_workspace, "test_step")

      # Verify directory was created
      assert File.exists?(workspace_path)
      assert File.dir?(workspace_path)

      # Verify it's a subdirectory of the base path
      assert String.starts_with?(workspace_path, test_workspace)

      # Clean up
      File.rm_rf!(test_workspace)
    end

    test "returns error when directory creation fails" do
      # Try to create workspace in a non-existent parent directory
      invalid_path = "/non_existent_root/test_workspace"

      assert {:error, message} = ResourceMonitor.create_workspace(invalid_path, "test_step")
      assert message =~ "Failed to create workspace directory"
    end
  end

  describe "cleanup_workspace/1" do
    test "cleans up existing workspace directory" do
      base_path = System.tmp_dir!()
      test_workspace = Path.join(base_path, "test_cleanup_#{:rand.uniform(1000)}")

      # Create the directory and some content
      File.mkdir_p!(test_workspace)
      test_file = Path.join(test_workspace, "test_file.txt")
      File.write!(test_file, "test content")

      # Verify it exists
      assert File.exists?(test_workspace)
      assert File.exists?(test_file)

      # Clean up
      assert :ok = ResourceMonitor.cleanup_workspace(test_workspace)

      # Verify it's gone
      assert not File.exists?(test_workspace)
      assert not File.exists?(test_file)
    end

    test "succeeds when workspace doesn't exist" do
      non_existent_path = "/tmp/non_existent_workspace_#{:rand.uniform(1000)}"

      assert :ok = ResourceMonitor.cleanup_workspace(non_existent_path)
    end
  end

  describe "cleanup_context/1" do
    test "cleans up context data structures" do
      context = %{
        results: %{"step1" => "result1", "step2" => "result2"},
        execution_log: ["log1", "log2", "log3"],
        large_data: %{huge: "data"},
        cached_results: %{cache: "data"},
        other_field: "preserved"
      }

      cleaned = ResourceMonitor.cleanup_context(context)

      assert cleaned.results == %{}
      assert cleaned.execution_log == []
      assert not Map.has_key?(cleaned, :large_data)
      assert not Map.has_key?(cleaned, :cached_results)
      assert cleaned.other_field == "preserved"
    end

    test "recursively cleans parent contexts" do
      parent_context = %{
        results: %{"parent_step" => "parent_result"},
        execution_log: ["parent_log"],
        parent_context: nil
      }

      context = %{
        results: %{"child_step" => "child_result"},
        execution_log: ["child_log"],
        parent_context: parent_context
      }

      cleaned = ResourceMonitor.cleanup_context(context)

      assert cleaned.results == %{}
      assert cleaned.execution_log == []
      assert cleaned.parent_context.results == %{}
      assert cleaned.parent_context.execution_log == []
    end

    test "handles context without parent" do
      context = %{
        results: %{"step1" => "result1"},
        execution_log: ["log1"],
        parent_context: nil
      }

      cleaned = ResourceMonitor.cleanup_context(context)

      assert cleaned.results == %{}
      assert cleaned.execution_log == []
      assert cleaned.parent_context == nil
    end

    test "cleans workspace directory if present" do
      base_path = System.tmp_dir!()
      test_workspace = Path.join(base_path, "context_cleanup_#{:rand.uniform(1000)}")

      # Create workspace
      File.mkdir_p!(test_workspace)
      test_file = Path.join(test_workspace, "test_file.txt")
      File.write!(test_file, "test content")

      context = %{
        workspace_dir: test_workspace,
        results: %{"step1" => "result1"}
      }

      # Verify workspace exists
      assert File.exists?(test_workspace)
      assert File.exists?(test_file)

      # Clean up context
      cleaned = ResourceMonitor.cleanup_context(context)

      # Verify workspace is cleaned
      assert not File.exists?(test_workspace)
      assert not File.exists?(test_file)
      assert cleaned.results == %{}
    end
  end

  describe "log_resource_usage/2" do
    test "logs resource usage without errors" do
      usage = %{
        # 100MB
        memory_bytes: 100_000_000,
        start_time: DateTime.utc_now(),
        elapsed_ms: 5000
      }

      # These tests mainly verify the function doesn't crash
      assert :ok = ResourceMonitor.log_resource_usage(usage, :debug)
      assert :ok = ResourceMonitor.log_resource_usage(usage, :info)
      assert :ok = ResourceMonitor.log_resource_usage(usage, :warning)
      assert :ok = ResourceMonitor.log_resource_usage(usage, :error)
      assert :ok = ResourceMonitor.log_resource_usage(usage, :invalid_level)
    end

    test "uses debug level by default" do
      usage = %{
        memory_bytes: 50_000_000,
        start_time: DateTime.utc_now(),
        elapsed_ms: 2500
      }

      assert :ok = ResourceMonitor.log_resource_usage(usage)
    end
  end

  describe "check_memory_pressure/2" do
    test "logs at appropriate levels based on memory usage" do
      start_time = DateTime.utc_now()

      # Low usage (under 50%)
      low_usage = %{
        # 100MB
        memory_bytes: 100_000_000,
        start_time: start_time,
        elapsed_ms: 1000
      }

      # 1GB limit
      limits = %{memory_limit_mb: 1024}
      assert :ok = ResourceMonitor.check_memory_pressure(low_usage, limits)

      # Medium usage (50-75%)
      medium_usage = %{
        # 600MB
        memory_bytes: 600_000_000,
        start_time: start_time,
        elapsed_ms: 1000
      }

      assert :ok = ResourceMonitor.check_memory_pressure(medium_usage, limits)

      # High usage (75-90%)
      high_usage = %{
        # 800MB
        memory_bytes: 800_000_000,
        start_time: start_time,
        elapsed_ms: 1000
      }

      assert :ok = ResourceMonitor.check_memory_pressure(high_usage, limits)

      # Critical usage (over 90%)
      critical_usage = %{
        # 950MB
        memory_bytes: 950_000_000,
        start_time: start_time,
        elapsed_ms: 1000
      }

      assert :ok = ResourceMonitor.check_memory_pressure(critical_usage, limits)
    end

    test "uses default limits when not provided" do
      usage = %{
        memory_bytes: 100_000_000,
        start_time: DateTime.utc_now(),
        elapsed_ms: 1000
      }

      assert :ok = ResourceMonitor.check_memory_pressure(usage)
    end
  end
end

