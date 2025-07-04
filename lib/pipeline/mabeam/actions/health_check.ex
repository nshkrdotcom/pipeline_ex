defmodule Pipeline.MABEAM.Actions.HealthCheck do
  @moduledoc """
  Jido Action that checks pipeline_ex system health.

  This action wraps the existing Pipeline.health_check/0 function
  to provide health status information for MABEAM monitoring.
  """

  use Jido.Action,
    name: "health_check",
    description: "Checks pipeline_ex system health",
    schema: [
      include_details: [type: :boolean, default: true, doc: "Include detailed health information"]
    ]

  @impl true
  def run(params, _context) do
    # Use existing health check
    case Pipeline.health_check() do
      :ok ->
        health_data = %{
          status: :healthy,
          timestamp: DateTime.utc_now(),
          pipeline_version: get_pipeline_version(),
          jido_integration: :active
        }

        health_data =
          if Map.get(params, :include_details, true) do
            Map.merge(health_data, %{
              config: Pipeline.get_config(),
              system_info: get_system_info()
            })
          else
            health_data
          end

        {:ok, health_data}

      {:error, issues} ->
        {:ok,
         %{
           status: :unhealthy,
           issues: issues,
           timestamp: DateTime.utc_now(),
           jido_integration: :active
         }}
    end
  end

  defp get_pipeline_version do
    case :application.get_key(:pipeline, :vsn) do
      {:ok, version} -> to_string(version)
      :undefined -> "unknown"
    end
  end

  defp get_system_info do
    %{
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      node: Node.self(),
      schedulers: System.schedulers_online()
    }
  end
end
