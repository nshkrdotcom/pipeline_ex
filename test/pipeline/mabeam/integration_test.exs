defmodule Pipeline.MABEAM.IntegrationTest do
  use ExUnit.Case
  use Pipeline.TestCase

  alias Pipeline.MABEAM.Actions.{ExecutePipelineYaml, HealthCheck, GeneratePipeline}

  describe "Jido Exec integration" do
    test "executes individual actions through Jido.Exec.run" do
      # Test HealthCheck action via Jido Exec
      assert {:ok, health_result} =
               Jido.Exec.run(
                 HealthCheck,
                 %{include_details: false},
                 %{},
                 timeout: 10_000
               )

      assert health_result.status in [:healthy, :unhealthy]
      assert health_result.jido_integration == :active
    end

    test "executes pipeline action with workflow timeout and context" do
      # Ensure mock mode for testing
      original_mode = System.get_env("TEST_MODE")
      System.put_env("TEST_MODE", "mock")

      try do
        context = %{
          user_id: "test_user",
          request_id: "test_request_123"
        }

        # This will fail because test file doesn't exist, but it demonstrates
        # that Jido Exec properly handles the action execution
        result =
          Jido.Exec.run(
            ExecutePipelineYaml,
            %{pipeline_file: "nonexistent.yaml"},
            context,
            timeout: 5_000,
            max_retries: 1
          )

        # Should return an error but in the proper Jido format
        assert {:error, _reason} = result
      after
        if original_mode do
          System.put_env("TEST_MODE", original_mode)
        else
          System.delete_env("TEST_MODE")
        end
      end
    end

    test "demonstrates workflow chaining potential" do
      # This test shows how multiple MABEAM actions could be chained
      # First check health, then potentially execute a pipeline

      # Step 1: Health check
      assert {:ok, health_result} =
               Jido.Exec.run(
                 HealthCheck,
                 %{include_details: true},
                 %{workflow_step: 1}
               )

      # Step 2: Based on health, we could execute a pipeline
      if health_result.status == :healthy do
        # In a real scenario, we'd execute a pipeline here
        # For testing, we just verify the action is available and working
        # Health check passed, demonstrating workflow chaining
        assert true
      end

      # This demonstrates the foundation for complex agent workflows
      assert health_result.jido_integration == :active
    end

    test "workflow error handling and compensation" do
      # Test that Jido properly handles action errors
      assert {:error, reason} =
               Jido.Exec.run(
                 ExecutePipelineYaml,
                 %{pipeline_file: "definitely_nonexistent_file.yaml"},
                 %{},
                 timeout: 3_000
               )

      # Jido should provide structured error information
      assert %Jido.Error{} = reason
      assert reason.type == :execution_error
      assert String.contains?(reason.message, "Pipeline execution failed")
    end

    test "async exec execution support" do
      # Test that actions work with Jido's async capabilities
      async_ref =
        Jido.Exec.run_async(
          HealthCheck,
          %{include_details: false},
          %{async_test: true}
        )

      # Should return a reference for async tracking
      assert is_reference(async_ref) or is_pid(async_ref) or is_map(async_ref)

      # Wait for completion
      assert {:ok, result} = Jido.Exec.await(async_ref, 5_000)
      assert result.status in [:healthy, :unhealthy]
    end
  end

  describe "MABEAM action registration and discovery" do
    test "actions are properly defined with Jido.Action behavior" do
      # Verify actions implement the required behavior
      assert ExecutePipelineYaml.__info__(:attributes)[:behaviour] == [Jido.Action]
      assert HealthCheck.__info__(:attributes)[:behaviour] == [Jido.Action]
      assert GeneratePipeline.__info__(:attributes)[:behaviour] == [Jido.Action]
    end

    test "actions have proper schemas defined" do
      # Each action should have a schema for parameter validation
      # Test by calling the schema function directly
      schema1 = ExecutePipelineYaml.schema()
      schema2 = HealthCheck.schema()
      schema3 = GeneratePipeline.schema()

      # Schemas should return lists of parameter definitions
      assert is_list(schema1)
      assert is_list(schema2)
      assert is_list(schema3)

      # Verify they contain expected parameters
      assert Keyword.has_key?(schema1, :pipeline_file)
      assert Keyword.has_key?(schema2, :include_details)
      assert Keyword.has_key?(schema3, :description)
    end
  end
end
