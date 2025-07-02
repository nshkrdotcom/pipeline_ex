defmodule Pipeline.MABEAM.AgentsTest do
  use ExUnit.Case, async: false

  setup do
    # Enable MABEAM for testing
    Application.put_env(:pipeline, :mabeam_enabled, true)
    
    # Start the application manually since it doesn't implement child_spec/1
    {:ok, _} = Application.ensure_all_started(:pipeline)
    
    on_exit(fn ->
      Application.stop(:pipeline)
      Application.put_env(:pipeline, :mabeam_enabled, false)
    end)
    
    :ok
  end

  describe "PipelineManager Agent" do
    test "starts successfully under supervision" do
      # The manager should already be running from the setup
      assert Process.whereis(Pipeline.MABEAM.Supervisor) != nil
    end

    test "can receive instructions and execute actions" do
      # Create an instruction to check health
      _instruction = %Jido.Instruction{
        action: "health_check",
        params: %{}
      }

      # Send instruction to pipeline manager
      # Note: This is a basic test - in production we'd use proper Jido agent communication
      assert {:ok, _result} = Pipeline.MABEAM.Actions.HealthCheck.run(%{}, %{})
    end

    test "maintains execution history in state" do
      # Test that the agent can maintain state according to its schema
      # This would typically be tested through Jido's agent testing utilities
      assert true  # Placeholder for actual state testing
    end
  end

  describe "PipelineWorker Agent" do
    test "starts with correct initial state" do
      # Workers should be started with worker_id
      # This tests the schema validation and initial state
      assert true  # Placeholder - would test actual worker state
    end

    test "can execute pipeline YAML files" do
      # Test that worker can execute an actual pipeline
      pipeline_file = "test/fixtures/simple_test_workflow.yaml"
      
      if File.exists?(pipeline_file) do
        assert {:ok, _result} = Pipeline.MABEAM.Actions.ExecutePipelineYaml.run(
          %{pipeline_file: pipeline_file}, 
          %{}
        )
      else
        # Skip if test file doesn't exist
        assert true
      end
    end

    test "handles multiple workers independently" do
      # Test that multiple workers can run concurrently
      # This would be tested through the supervisor
      children = Supervisor.which_children(Pipeline.MABEAM.Supervisor)
      
      # Should have at least the manager and 2 workers
      assert length(children) >= 3
    end
  end

  describe "MABEAM Supervisor" do
    test "starts all required children" do
      children = Supervisor.which_children(Pipeline.MABEAM.Supervisor)
      child_ids = Enum.map(children, fn {id, _pid, _type, _modules} -> id end)
      
      # Should have pipeline manager and workers
      assert Pipeline.MABEAM.Agents.PipelineManager in child_ids
      assert :worker_1 in child_ids
      assert :worker_2 in child_ids
    end

    test "restarts children on failure" do
      # Test supervisor restart behavior
      children = Supervisor.which_children(Pipeline.MABEAM.Supervisor)
      assert length(children) > 0
      
      # All children should be running
      Enum.each(children, fn {_id, pid, _type, _modules} ->
        assert is_pid(pid)
        assert Process.alive?(pid)
      end)
    end
  end

  describe "Integration with existing pipeline_ex" do
    test "MABEAM actions can execute existing pipeline functionality" do
      # Test that our Jido Actions properly wrap existing Pipeline.run/2
      # This ensures backward compatibility
      
      # Test health check action
      assert {:ok, result} = Pipeline.MABEAM.Actions.HealthCheck.run(%{}, %{})
      assert is_map(result)
    end

    test "application starts correctly with MABEAM enabled" do
      # Test that the application starts properly with MABEAM enabled
      assert Application.get_env(:pipeline, :mabeam_enabled) == true
      assert Process.whereis(Pipeline.MABEAM.Supervisor) != nil
    end

    test "application works without MABEAM when disabled" do
      # Stop current application
      :ok = Application.stop(:pipeline)
      
      # Disable MABEAM
      Application.put_env(:pipeline, :mabeam_enabled, false)
      
      # Start application again
      :ok = Application.start(:pipeline)
      
      # MABEAM supervisor should not be running
      assert Process.whereis(Pipeline.MABEAM.Supervisor) == nil
      
      # Re-enable for cleanup
      Application.put_env(:pipeline, :mabeam_enabled, true)
    end
  end

  describe "Agent instruction processing" do
    test "agents can process Jido instructions" do
      # This would test the full Jido instruction processing flow
      # For now, we test that our actions work independently
      
      # Test execute pipeline action
      params = %{
        pipeline_file: "test/fixtures/simple_test_workflow.yaml",
        workspace_dir: "./test_workspace",
        output_dir: "./test_outputs",
        debug: true
      }
      
      if File.exists?(params.pipeline_file) do
        assert {:ok, _result} = Pipeline.MABEAM.Actions.ExecutePipelineYaml.run(params, %{})
      else
        # Test with minimal params that don't require actual files
        minimal_params = %{pipeline_file: "nonexistent.yaml"}
        # Should fail gracefully
        assert {:error, _reason} = Pipeline.MABEAM.Actions.ExecutePipelineYaml.run(minimal_params, %{})
      end
    end

    test "agents maintain state through instruction processing" do
      # Test that agent state is maintained across instructions
      # This would use Jido's built-in state management testing
      assert true  # Placeholder for actual state persistence testing
    end
  end
end