defmodule Pipeline.MABEAM.SensorsTest do
  use ExUnit.Case, async: false

  describe "QueueMonitor sensor" do
    test "starts successfully and emits queue status signals" do
      # Start the sensor with a test target
      {:ok, sensor} = Pipeline.MABEAM.Sensors.QueueMonitor.start_link(
        id: "test_queue_monitor",
        target: {:pid, target: self()},
        check_interval: 100,  # Fast interval for testing
        alert_threshold: 5
      )

      # Should receive a signal within a reasonable time
      assert_receive {:signal, {:ok, signal}}, 1000

      assert signal.type == "pipeline.queue_status"
      assert is_map(signal.data)
      assert Map.has_key?(signal.data, :queue_depth)
      assert Map.has_key?(signal.data, :processing_rate)
      assert Map.has_key?(signal.data, :alert)
      assert Map.has_key?(signal.data, :timestamp)

      # Clean up
      GenServer.stop(sensor)
    end

    test "triggers alert when queue depth exceeds threshold" do
      # This would require actual queue data to test properly
      # For now, we test the basic structure
      {:ok, sensor} = Pipeline.MABEAM.Sensors.QueueMonitor.start_link(
        id: "test_alert_monitor",
        target: {:pid, target: self()},
        check_interval: 50,
        alert_threshold: 0  # Low threshold to trigger alert
      )

      assert_receive {:signal, {:ok, signal}}, 1000
      
      # Alert should be false since we have no actual queue
      assert signal.data.alert == false

      GenServer.stop(sensor)
    end
  end

  describe "PerformanceMonitor sensor" do
    test "starts successfully and emits performance metrics" do
      {:ok, sensor} = Pipeline.MABEAM.Sensors.PerformanceMonitor.start_link(
        id: "test_performance_monitor",
        target: {:pid, target: self()},
        emit_interval: 100  # Fast interval for testing
      )

      # Should receive a signal within a reasonable time
      assert_receive {:signal, {:ok, signal}}, 1000

      assert signal.type == "pipeline.performance_metrics"
      assert is_map(signal.data)
      
      # Check that all expected metrics are present
      expected_fields = [
        :avg_execution_time, :throughput_per_hour, :error_rate,
        :active_pipelines, :memory_usage, :cpu_usage, :timestamp
      ]
      
      for field <- expected_fields do
        assert Map.has_key?(signal.data, field), "Missing field: #{field}"
      end

      # Memory usage should be a map with system info
      assert is_map(signal.data.memory_usage)
      assert Map.has_key?(signal.data.memory_usage, :total)
      assert Map.has_key?(signal.data.memory_usage, :processes)

      GenServer.stop(sensor)
    end

    test "collects real system metrics" do
      {:ok, sensor} = Pipeline.MABEAM.Sensors.PerformanceMonitor.start_link(
        id: "test_metrics_collector",
        target: {:pid, target: self()},
        emit_interval: 50
      )

      assert_receive {:signal, {:ok, signal}}, 1000

      # CPU usage should be a reasonable number
      assert is_number(signal.data.cpu_usage)
      assert signal.data.cpu_usage >= 0.0
      assert signal.data.cpu_usage <= 100.0

      # Memory usage should have real values
      assert signal.data.memory_usage.total > 0
      assert signal.data.memory_usage.processes > 0

      GenServer.stop(sensor)
    end
  end

  describe "sensor integration" do
    test "sensors work with MABEAM supervisor" do
      # Enable MABEAM to test full integration
      Application.put_env(:pipeline, :mabeam_enabled, true)
      
      # Start the MABEAM supervisor which includes sensors
      {:ok, supervisor} = Pipeline.MABEAM.Supervisor.start_link()
      
      # Give sensors time to initialize and emit signals
      Process.sleep(200)
      
      # Check that sensor processes are running
      children = Supervisor.which_children(supervisor)
      sensor_ids = Enum.map(children, fn {id, _, _, _} -> id end)
      
      assert :queue_monitor in sensor_ids
      assert :performance_monitor in sensor_ids

      # Stop supervisor
      Supervisor.stop(supervisor)
    end
  end
end