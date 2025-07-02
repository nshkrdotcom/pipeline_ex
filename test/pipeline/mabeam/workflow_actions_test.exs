defmodule Pipeline.MABEAM.WorkflowActionsTest do
  use ExUnit.Case, async: false

  describe "ExecutePipelineAsync action" do
    test "starts async execution successfully" do
      params = %{
        pipeline_file: "test/fixtures/simple_test.yaml",
        timeout: 30_000,
        max_retries: 1,
        telemetry_level: :minimal
      }

      {:ok, result} = Pipeline.MABEAM.Actions.ExecutePipelineAsync.run(params, %{})

      assert Map.has_key?(result, :async_ref)
      assert result.status == :started
      assert result.pipeline_file == params.pipeline_file
      assert %DateTime{} = result.started_at
    end

    test "validates required parameters" do
      # Missing pipeline_file should fail validation
      params = %{timeout: 30_000}

      assert {:error, _reason} = 
        Pipeline.MABEAM.Actions.ExecutePipelineAsync.run(params, %{})
    end
  end

  describe "AwaitPipelineResult action" do
    test "awaits async pipeline completion" do
      # First start an async execution
      start_params = %{
        pipeline_file: "test/fixtures/simple_test.yaml",
        timeout: 10_000
      }

      {:ok, start_result} = Pipeline.MABEAM.Actions.ExecutePipelineAsync.run(start_params, %{})

      # Now await the result
      await_params = %{
        async_ref: start_result.async_ref,
        timeout: 15_000
      }

      {:ok, await_result} = Pipeline.MABEAM.Actions.AwaitPipelineResult.run(await_params, %{})

      assert await_result.status == :completed
      assert Map.has_key?(await_result, :result)
      assert %DateTime{} = await_result.completed_at
    end

    test "handles timeout correctly" do
      # Create a mock async_ref that will timeout
      fake_async_ref = make_ref()

      await_params = %{
        async_ref: fake_async_ref,
        timeout: 100  # Very short timeout
      }

      {:error, reason} = Pipeline.MABEAM.Actions.AwaitPipelineResult.run(await_params, %{})
      assert reason =~ "timed out"
    end
  end

  describe "CancelPipelineExecution action" do
    test "cancels running pipeline" do
      # Start an async execution
      start_params = %{
        pipeline_file: "test/fixtures/simple_test.yaml",
        timeout: 30_000
      }

      {:ok, start_result} = Pipeline.MABEAM.Actions.ExecutePipelineAsync.run(start_params, %{})

      # Cancel it
      cancel_params = %{async_ref: start_result.async_ref}

      {:ok, cancel_result} = Pipeline.MABEAM.Actions.CancelPipelineExecution.run(cancel_params, %{})

      assert cancel_result.status == :cancelled
      assert %DateTime{} = cancel_result.cancelled_at
    end

    test "handles cancellation of non-existent execution" do
      fake_async_ref = make_ref()
      cancel_params = %{async_ref: fake_async_ref}

      {:error, reason} = Pipeline.MABEAM.Actions.CancelPipelineExecution.run(cancel_params, %{})
      assert reason =~ "not found"
    end
  end

  describe "GetPipelineStatus action" do
    test "gets status of running pipeline" do
      # Start an async execution
      start_params = %{
        pipeline_file: "test/fixtures/simple_test.yaml",
        timeout: 30_000
      }

      {:ok, start_result} = Pipeline.MABEAM.Actions.ExecutePipelineAsync.run(start_params, %{})

      # Get status
      status_params = %{async_ref: start_result.async_ref}

      {:ok, status_result} = Pipeline.MABEAM.Actions.GetPipelineStatus.run(status_params, %{})

      assert Map.has_key?(status_result, :status)
      assert %DateTime{} = status_result.checked_at
    end
  end

  describe "BatchExecutePipelines action" do
    test "starts multiple pipelines concurrently" do
      params = %{
        pipeline_files: [
          "test/fixtures/simple_test.yaml",
          "test/fixtures/simple_test.yaml"  # Use same file twice for testing
        ],
        timeout: 30_000,
        concurrent_limit: 2
      }

      {:ok, result} = Pipeline.MABEAM.Actions.BatchExecutePipelines.run(params, %{})

      assert Map.has_key?(result, :batch_id)
      assert is_binary(result.batch_id)
      assert length(result.pipeline_refs) == 2
      assert result.total_pipelines == 2
      assert %DateTime{} = result.started_at

      # Each pipeline_ref should be a {pipeline_file, async_ref} tuple
      Enum.each(result.pipeline_refs, fn {pipeline_file, async_ref} ->
        assert is_binary(pipeline_file)
        assert is_reference(async_ref)
      end)
    end

    test "respects concurrent limit" do
      params = %{
        pipeline_files: [
          "test/fixtures/simple_test.yaml",
          "test/fixtures/simple_test.yaml",
          "test/fixtures/simple_test.yaml",
          "test/fixtures/simple_test.yaml",
          "test/fixtures/simple_test.yaml"
        ],
        concurrent_limit: 3  # Limit to 3 concurrent executions
      }

      {:ok, result} = Pipeline.MABEAM.Actions.BatchExecutePipelines.run(params, %{})

      # Should only start 3 pipelines despite 5 being requested
      assert length(result.pipeline_refs) == 3
      assert result.total_pipelines == 5
    end
  end

  describe "AwaitBatchResults action" do
    test "awaits all pipelines in batch" do
      # Start a batch
      batch_params = %{
        pipeline_files: [
          "test/fixtures/simple_test.yaml",
          "test/fixtures/simple_test.yaml"
        ],
        timeout: 15_000
      }

      {:ok, batch_result} = Pipeline.MABEAM.Actions.BatchExecutePipelines.run(batch_params, %{})

      # Await batch results
      await_params = %{
        pipeline_refs: batch_result.pipeline_refs,
        timeout: 30_000
      }

      {:ok, await_result} = Pipeline.MABEAM.Actions.AwaitBatchResults.run(await_params, %{})

      assert length(await_result.results) == 2
      assert Map.has_key?(await_result, :summary)
      assert await_result.summary.total == 2
      assert %DateTime{} = await_result.completed_at

      # Each result should be a {pipeline_file, status, result} tuple
      Enum.each(await_result.results, fn {pipeline_file, status, _result} ->
        assert is_binary(pipeline_file)
        assert status in [:success, :error]
      end)
    end
  end

  describe "workflow integration" do
    test "actions work with Jido.Workflow.run" do
      # Test that our actions integrate properly with Jido's workflow system
      params = %{
        pipeline_file: "test/fixtures/simple_test.yaml",
        timeout: 10_000
      }

      {:ok, result} = Jido.Exec.run(
        Pipeline.MABEAM.Actions.ExecutePipelineAsync,
        params,
        %{user_id: "test_user"},
        timeout: 15_000
      )

      assert result.status == :started
      assert Map.has_key?(result, :async_ref)
    end

    test "actions handle workflow timeouts" do
      params = %{
        pipeline_file: "test/fixtures/simple_test.yaml",
        timeout: 30_000  # Action timeout
      }

      # Very short workflow timeout should cause failure
      {:error, error} = Jido.Exec.run(
        Pipeline.MABEAM.Actions.ExecutePipelineAsync,
        params,
        %{},
        timeout: 1  # 1ms timeout
      )

      assert error.type == :timeout
    end
  end
end