defmodule Pipeline.Tools.Implementations.GetWanIp.Ubuntu2404 do
  @moduledoc """
  Tool to get the WAN (external) IP address using Ubuntu 24.04 CLI tools.
  
  This implementation uses curl to query external services for the public IP.
  """

  @behaviour Pipeline.Tools.Tool

  require Logger

  @impl Pipeline.Tools.Tool
  def get_definition() do
    %{
      name: "get_wan_ip",
      description: "Get the current WAN (external/public) IP address of the system",
      parameters: %{
        type: "object",
        properties: %{
          service: %{
            type: "string",
            enum: ["ipify", "httpbin", "checkip"],
            description: "Which service to use for IP lookup (default: ipify)",
            default: "ipify"
          },
          timeout: %{
            type: "integer",
            description: "Timeout in seconds (default: 10)",
            default: 10,
            minimum: 1,
            maximum: 30
          }
        },
        required: []
      }
    }
  end

  @impl Pipeline.Tools.Tool
  def execute(args) do
    service = Map.get(args, "service", "ipify")
    timeout = Map.get(args, "timeout", 10)
    
    Logger.info("🌐 Getting WAN IP using service: #{service}")
    
    case get_wan_ip_with_service(service, timeout) do
      {:ok, ip} ->
        result = %{
          wan_ip: String.trim(ip),
          service_used: service,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          platform: "ubuntu-24.04"
        }
        
        Logger.info("✅ WAN IP retrieved: #{result.wan_ip}")
        {:ok, result}
        
      {:error, reason} ->
        Logger.error("❌ Failed to get WAN IP: #{reason}")
        {:error, "Failed to retrieve WAN IP: #{reason}"}
    end
  end

  @impl Pipeline.Tools.Tool
  def supported_platforms() do
    ["ubuntu-24.04", "ubuntu-22.04", "debian", "linux"]
  end

  @impl Pipeline.Tools.Tool
  def validate_environment() do
    # Check if curl is available
    case System.cmd("which", ["curl"], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok
        
      {_output, _} ->
        {:error, "curl is not installed or not in PATH"}
    end
  end

  # Private functions

  defp get_wan_ip_with_service(service, timeout) do
    case service do
      "ipify" ->
        execute_curl("https://api.ipify.org", timeout)
        
      "httpbin" ->
        execute_curl("https://httpbin.org/ip", timeout)
        |> parse_httpbin_response()
        
      "checkip" ->
        execute_curl("https://checkip.amazonaws.com", timeout)
        
      _ ->
        {:error, "Unknown service: #{service}"}
    end
  end

  defp execute_curl(url, timeout) do
    try do
      case System.cmd("curl", [
        "--silent",
        "--show-error", 
        "--max-time", to_string(timeout),
        "--user-agent", "Pipeline-Tools/1.0",
        url
      ], stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, output}
          
        {error_output, exit_code} ->
          {:error, "curl failed (exit #{exit_code}): #{error_output}"}
      end
    rescue
      error ->
        {:error, "curl execution failed: #{inspect(error)}"}
    end
  end

  defp parse_httpbin_response({:ok, json_response}) do
    try do
      case Jason.decode(json_response) do
        {:ok, %{"origin" => ip}} ->
          {:ok, ip}
          
        {:error, _} ->
          {:error, "Failed to parse JSON response from httpbin"}
      end
    rescue
      _ ->
        {:error, "Invalid JSON response from httpbin"}
    end
  end

  defp parse_httpbin_response({:error, reason}), do: {:error, reason}
end