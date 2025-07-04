defmodule Pipeline.MABEAM.Actions.HealthCheckTest do
  use ExUnit.Case

  alias Pipeline.MABEAM.Actions.HealthCheck

  describe "HealthCheck action" do
    test "returns health status successfully" do
      params = %{include_details: true}

      assert {:ok, result} = HealthCheck.run(params, %{})

      # Should always return a result (either healthy or unhealthy)
      assert result.status in [:healthy, :unhealthy]
      assert %DateTime{} = result.timestamp
      assert result.jido_integration == :active

      # When include_details is true, should have additional info
      assert Map.has_key?(result, :config)
      assert Map.has_key?(result, :system_info)

      # System info should have expected fields
      assert is_binary(result.system_info.elixir_version)
      assert is_binary(result.system_info.otp_version)
      assert is_atom(result.system_info.node)
      assert is_integer(result.system_info.schedulers)
    end

    test "excludes details when include_details is false" do
      params = %{include_details: false}

      assert {:ok, result} = HealthCheck.run(params, %{})

      assert result.status in [:healthy, :unhealthy]
      assert %DateTime{} = result.timestamp
      assert result.jido_integration == :active

      # Should not include detailed information
      refute Map.has_key?(result, :config)
      refute Map.has_key?(result, :system_info)
    end

    test "uses default include_details when not specified" do
      # Default should be true
      assert {:ok, result} = HealthCheck.run(%{}, %{})

      # Should include details by default
      assert Map.has_key?(result, :config)
      assert Map.has_key?(result, :system_info)
    end

    test "handles unhealthy status gracefully" do
      # Even if health check returns issues, the action should succeed
      # and return the issues in a structured format
      assert {:ok, result} = HealthCheck.run(%{}, %{})

      if result.status == :unhealthy do
        assert is_list(result.issues)
        assert length(result.issues) > 0
      end
    end
  end
end
