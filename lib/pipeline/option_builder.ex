defmodule Pipeline.OptionBuilder do
  @moduledoc """
  Pipeline wrapper for ClaudeCodeSDK.OptionBuilder with additional pipeline-specific functionality.

  Provides preset configurations optimized for different environments and use cases:
  - Development: Permissive settings, verbose logging, full tool access
  - Production: Restricted settings, minimal tools, safe defaults
  - Analysis: Read-only tools, optimized for code analysis
  - Chat: Simple conversation settings, basic tools
  - Test: Optimized for testing with mock-friendly settings
  """

  @type preset_name :: :development | :production | :analysis | :chat | :test
  @type claude_options :: %{
          String.t() => String.t() | boolean() | integer() | [String.t()] | map()
        }

  @doc """
  Build options based on the current environment.
  Auto-detects the environment and applies appropriate presets.
  """
  @spec for_environment() :: claude_options()
  def for_environment do
    case Application.get_env(:pipeline, :environment, detect_mix_environment()) do
      :development -> build_development_options()
      :production -> build_production_options()
      :test -> build_test_options()
      _ -> build_development_options()
    end
  end

  @doc """
  Build development preset options.
  Optimized for development work with permissive settings and verbose output.
  """
  @spec build_development_options() :: claude_options()
  def build_development_options do
    %{
      "max_turns" => 20,
      "verbose" => true,
      "output_format" => "stream_json",
      "allowed_tools" => ["Write", "Edit", "Read", "Bash", "Search", "Glob", "Grep"],
      "debug_mode" => true,
      "telemetry_enabled" => true,
      "cost_tracking" => true,
      "retry_config" => %{
        "max_retries" => 3,
        "backoff_strategy" => "exponential",
        "retry_on" => ["timeout", "api_error"]
      },
      # 5 minutes
      "timeout_ms" => 300_000,
      "system_prompt" =>
        "You are a helpful development assistant. Focus on writing clean, maintainable code."
    }
  end

  @doc """
  Build production preset options.
  Optimized for production use with restricted settings and minimal tools.
  """
  @spec build_production_options() :: claude_options()
  def build_production_options do
    %{
      "max_turns" => 10,
      "verbose" => false,
      "output_format" => "json",
      "allowed_tools" => ["Read"],
      "debug_mode" => false,
      "telemetry_enabled" => true,
      "cost_tracking" => true,
      "retry_config" => %{
        "max_retries" => 2,
        "backoff_strategy" => "linear",
        "retry_on" => ["timeout"]
      },
      # 2 minutes
      "timeout_ms" => 120_000,
      "system_prompt" => "You are a production assistant. Prioritize safety and reliability."
    }
  end

  @doc """
  Build analysis preset options.
  Optimized for code analysis with read-only tools and detailed reporting.
  """
  @spec build_analysis_options() :: claude_options()
  def build_analysis_options do
    %{
      "max_turns" => 5,
      "verbose" => true,
      "output_format" => "json",
      "allowed_tools" => ["Read", "Glob", "Grep"],
      "debug_mode" => false,
      "telemetry_enabled" => true,
      "cost_tracking" => true,
      "retry_config" => %{
        "max_retries" => 2,
        "backoff_strategy" => "exponential",
        "retry_on" => ["timeout", "api_error"]
      },
      # 3 minutes
      "timeout_ms" => 180_000,
      "system_prompt" =>
        "You are a code analysis expert. Provide detailed, structured analysis with specific recommendations."
    }
  end

  @doc """
  Build chat preset options.
  Optimized for simple conversations with minimal tools.
  """
  @spec build_chat_options() :: claude_options()
  def build_chat_options do
    %{
      "max_turns" => 15,
      "verbose" => false,
      "output_format" => "text",
      "allowed_tools" => [],
      "debug_mode" => false,
      "telemetry_enabled" => false,
      "cost_tracking" => true,
      "retry_config" => %{
        "max_retries" => 1,
        "backoff_strategy" => "linear",
        "retry_on" => ["timeout"]
      },
      # 1 minute
      "timeout_ms" => 60_000,
      "system_prompt" => "You are a helpful assistant. Provide clear, concise responses."
    }
  end

  @doc """
  Build test preset options.
  Optimized for testing with mock-friendly settings.
  """
  @spec build_test_options() :: claude_options()
  def build_test_options do
    %{
      "max_turns" => 3,
      "verbose" => true,
      "output_format" => "json",
      "allowed_tools" => ["Read"],
      "debug_mode" => true,
      "telemetry_enabled" => false,
      "cost_tracking" => false,
      "retry_config" => %{
        "max_retries" => 1,
        "backoff_strategy" => "linear",
        "retry_on" => []
      },
      # 30 seconds
      "timeout_ms" => 30_000,
      "system_prompt" => "You are a test assistant. Provide predictable, structured responses."
    }
  end

  @doc """
  Merge a preset with custom options.
  Custom options override preset values.
  """
  @spec merge(preset_name() | String.t(), map() | nil) :: claude_options()
  def merge(preset_name, overrides) when is_atom(preset_name) do
    base_options =
      case preset_name do
        :development -> build_development_options()
        :production -> build_production_options()
        :analysis -> build_analysis_options()
        :chat -> build_chat_options()
        :test -> build_test_options()
        _ -> build_development_options()
      end

    safe_overrides = overrides || %{}
    deep_merge(base_options, safe_overrides)
  end

  def merge(preset_name, overrides) when is_binary(preset_name) do
    preset_atom = String.to_atom(preset_name)
    merge(preset_atom, overrides)
  end

  @doc """
  Apply preset-specific optimizations to a configuration.
  """
  @spec apply_preset_optimizations(preset_name() | String.t(), claude_options()) ::
          claude_options()
  def apply_preset_optimizations(preset_name, options) when is_binary(preset_name) do
    apply_preset_optimizations(String.to_atom(preset_name), options)
  end

  def apply_preset_optimizations(preset_name, options) when is_atom(preset_name) do
    case preset_name do
      :development ->
        apply_development_optimizations(options)

      :production ->
        apply_production_optimizations(options)

      :analysis ->
        apply_analysis_optimizations(options)

      :chat ->
        apply_chat_optimizations(options)

      :test ->
        apply_test_optimizations(options)

      _ ->
        options
    end
  end

  @doc """
  Get preset configuration for a specific use case.
  """
  @spec get_preset_config(preset_name() | String.t()) :: %{
          name: String.t(),
          description: String.t(),
          optimized_for: [String.t()],
          options: claude_options()
        }
  def get_preset_config(preset_name) when is_binary(preset_name) do
    get_preset_config(String.to_atom(preset_name))
  end

  def get_preset_config(preset_name) when is_atom(preset_name) do
    case preset_name do
      :development ->
        %{
          name: "Development",
          description: "Permissive settings for development work with full tool access",
          optimized_for: ["rapid development", "debugging", "experimentation"],
          options: build_development_options()
        }

      :production ->
        %{
          name: "Production",
          description: "Restricted settings for production use with minimal tools",
          optimized_for: ["safety", "reliability", "minimal resource usage"],
          options: build_production_options()
        }

      :analysis ->
        %{
          name: "Analysis",
          description: "Read-only tools optimized for code analysis and review",
          optimized_for: ["code review", "security analysis", "quality assessment"],
          options: build_analysis_options()
        }

      :chat ->
        %{
          name: "Chat",
          description: "Simple conversation settings with minimal tools",
          optimized_for: ["Q&A", "documentation", "simple assistance"],
          options: build_chat_options()
        }

      :test ->
        %{
          name: "Test",
          description: "Mock-friendly settings for testing and CI/CD",
          optimized_for: ["unit testing", "integration testing", "CI/CD pipelines"],
          options: build_test_options()
        }

      _ ->
        get_preset_config(:development)
    end
  end

  @doc """
  List all available presets with their descriptions.
  """
  @spec list_presets() :: [%{name: atom(), description: String.t(), optimized_for: [String.t()]}]
  def list_presets do
    [:development, :production, :analysis, :chat, :test]
    |> Enum.map(fn preset ->
      config = get_preset_config(preset)

      %{
        name: preset,
        description: config.description,
        optimized_for: config.optimized_for
      }
    end)
  end

  @doc """
  Validate that a preset name is valid.
  """
  @spec valid_preset?(String.t() | atom()) :: boolean()
  def valid_preset?(preset_name) when is_binary(preset_name) do
    valid_preset?(String.to_atom(preset_name))
  end

  def valid_preset?(preset_name) when is_atom(preset_name) do
    preset_name in [:development, :production, :analysis, :chat, :test]
  end

  # Private helper functions

  defp detect_mix_environment do
    case Mix.env() do
      :dev -> :development
      :prod -> :production
      :test -> :test
      _ -> :development
    end
  end

  defp apply_development_optimizations(options) do
    options
    |> Map.put_new(
      "append_system_prompt",
      "Use detailed logging and provide comprehensive explanations."
    )
    |> ensure_development_tools()
  end

  defp apply_production_optimizations(options) do
    options
    |> Map.put_new(
      "append_system_prompt",
      "Prioritize safety, security, and minimal resource usage."
    )
    |> restrict_production_tools()
  end

  defp apply_analysis_optimizations(options) do
    options
    |> Map.put_new(
      "append_system_prompt",
      "Focus on thorough analysis and provide structured, actionable recommendations."
    )
    |> ensure_analysis_tools()
  end

  defp apply_chat_optimizations(options) do
    options
    |> Map.put_new(
      "append_system_prompt",
      "Provide helpful, concise responses suitable for conversation."
    )
    |> minimize_chat_tools()
  end

  defp apply_test_optimizations(options) do
    options
    |> Map.put_new(
      "append_system_prompt",
      "Provide predictable, deterministic responses suitable for testing."
    )
    |> ensure_test_tools()
  end

  defp ensure_development_tools(options) do
    current_tools = Map.get(options, "allowed_tools", [])
    development_tools = ["Write", "Edit", "Read", "Bash", "Search", "Glob", "Grep"]

    updated_tools = (current_tools ++ development_tools) |> Enum.uniq()
    Map.put(options, "allowed_tools", updated_tools)
  end

  defp restrict_production_tools(options) do
    Map.put(options, "allowed_tools", ["Read"])
  end

  defp ensure_analysis_tools(options) do
    Map.put(options, "allowed_tools", ["Read", "Glob", "Grep"])
  end

  defp minimize_chat_tools(options) do
    Map.put(options, "allowed_tools", [])
  end

  defp ensure_test_tools(options) do
    Map.put(options, "allowed_tools", ["Read"])
  end

  # Deep merge function for nested maps
  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      deep_merge(v1, v2)
    end)
  end

  defp deep_merge(_left, right), do: right
end
