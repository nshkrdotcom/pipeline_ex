defmodule Pipeline.OptionBuilderTest do
  use Pipeline.Test.EnhancedTestCase
  alias Pipeline.OptionBuilder

  describe "environment-aware preset selection" do
    test "for_environment/0 selects development preset by default" do
      Application.put_env(:pipeline, :environment, :development)

      options = OptionBuilder.for_environment()

      assert options["max_turns"] == 20
      assert options["verbose"] == true
      assert options["output_format"] == "stream_json"
      assert "Write" in options["allowed_tools"]
      assert options["debug_mode"] == true
    end

    test "for_environment/0 selects production preset when configured" do
      Application.put_env(:pipeline, :environment, :production)

      options = OptionBuilder.for_environment()

      assert options["max_turns"] == 10
      assert options["verbose"] == false
      assert options["output_format"] == "json"
      assert options["allowed_tools"] == ["Read"]
      assert options["debug_mode"] == false
    end

    test "for_environment/0 selects test preset in test environment" do
      Application.put_env(:pipeline, :environment, :test)

      options = OptionBuilder.for_environment()

      assert options["max_turns"] == 3
      assert options["verbose"] == true
      assert options["output_format"] == "json"
      assert options["allowed_tools"] == ["Read"]
      assert options["cost_tracking"] == false
    end
  end

  describe "development preset" do
    test "build_development_options/0 returns permissive settings" do
      options = OptionBuilder.build_development_options()

      assert options["max_turns"] == 20
      assert options["verbose"] == true
      assert options["debug_mode"] == true
      assert options["telemetry_enabled"] == true
      assert options["cost_tracking"] == true

      expected_tools = ["Write", "Edit", "Read", "Bash", "Search", "Glob", "Grep"]
      assert options["allowed_tools"] == expected_tools

      assert options["retry_config"]["max_retries"] == 3
      assert options["retry_config"]["backoff_strategy"] == "exponential"
      assert options["timeout_ms"] == 300_000

      assert String.contains?(options["system_prompt"], "development assistant")
    end
  end

  describe "production preset" do
    test "build_production_options/0 returns restricted settings" do
      options = OptionBuilder.build_production_options()

      assert options["max_turns"] == 10
      assert options["verbose"] == false
      assert options["debug_mode"] == false
      assert options["telemetry_enabled"] == true
      assert options["cost_tracking"] == true

      assert options["allowed_tools"] == ["Read"]

      assert options["retry_config"]["max_retries"] == 2
      assert options["retry_config"]["backoff_strategy"] == "linear"
      assert options["timeout_ms"] == 120_000

      assert String.contains?(options["system_prompt"], "production assistant")
    end
  end

  describe "analysis preset" do
    test "build_analysis_options/0 returns read-only tools" do
      options = OptionBuilder.build_analysis_options()

      assert options["max_turns"] == 5
      assert options["verbose"] == true
      assert options["debug_mode"] == false
      assert options["telemetry_enabled"] == true

      expected_tools = ["Read", "Glob", "Grep"]
      assert options["allowed_tools"] == expected_tools

      assert options["retry_config"]["max_retries"] == 2
      assert options["timeout_ms"] == 180_000

      assert String.contains?(options["system_prompt"], "code analysis expert")
    end
  end

  describe "chat preset" do
    test "build_chat_options/0 returns minimal settings" do
      options = OptionBuilder.build_chat_options()

      assert options["max_turns"] == 15
      assert options["verbose"] == false
      assert options["debug_mode"] == false
      assert options["telemetry_enabled"] == false
      assert options["cost_tracking"] == true

      assert options["allowed_tools"] == []
      assert options["output_format"] == "text"

      assert options["retry_config"]["max_retries"] == 1
      assert options["timeout_ms"] == 60_000

      assert String.contains?(options["system_prompt"], "helpful assistant")
    end
  end

  describe "test preset" do
    test "build_test_options/0 returns mock-friendly settings" do
      options = OptionBuilder.build_test_options()

      assert options["max_turns"] == 3
      assert options["verbose"] == true
      assert options["debug_mode"] == true
      assert options["telemetry_enabled"] == false
      assert options["cost_tracking"] == false

      assert options["allowed_tools"] == ["Read"]
      assert options["output_format"] == "json"

      assert options["retry_config"]["max_retries"] == 1
      assert options["retry_config"]["retry_on"] == []
      assert options["timeout_ms"] == 30_000

      assert String.contains?(options["system_prompt"], "test assistant")
    end
  end

  describe "preset merging" do
    test "merge/2 with atom preset name combines preset with overrides" do
      overrides = %{
        "max_turns" => 25,
        "custom_field" => "custom_value"
      }

      result = OptionBuilder.merge(:development, overrides)

      # Override values should take precedence
      assert result["max_turns"] == 25
      assert result["custom_field"] == "custom_value"

      # Non-overridden values should remain from preset
      assert result["verbose"] == true
      assert result["debug_mode"] == true
      assert "Write" in result["allowed_tools"]
    end

    test "merge/2 with string preset name works correctly" do
      overrides = %{"max_turns" => 7}

      result = OptionBuilder.merge("production", overrides)

      assert result["max_turns"] == 7
      # From production preset
      assert result["verbose"] == false
      # From production preset
      assert result["allowed_tools"] == ["Read"]
    end

    test "merge/2 performs deep merge for nested maps" do
      overrides = %{
        "retry_config" => %{
          "max_retries" => 5
        }
      }

      result = OptionBuilder.merge(:development, overrides)

      # Should merge nested maps
      assert result["retry_config"]["max_retries"] == 5
      # From preset
      assert result["retry_config"]["backoff_strategy"] == "exponential"
      # From preset
      assert result["retry_config"]["retry_on"] == ["timeout", "api_error"]
    end
  end

  describe "preset optimizations" do
    test "apply_preset_optimizations/2 adds development-specific enhancements" do
      base_options = %{"max_turns" => 10}

      result = OptionBuilder.apply_preset_optimizations(:development, base_options)

      assert String.contains?(result["append_system_prompt"], "detailed logging")
      assert "Write" in result["allowed_tools"]
      assert "Bash" in result["allowed_tools"]
    end

    test "apply_preset_optimizations/2 restricts production tools" do
      base_options = %{"allowed_tools" => ["Write", "Edit", "Bash"]}

      result = OptionBuilder.apply_preset_optimizations(:production, base_options)

      assert result["allowed_tools"] == ["Read"]
      assert String.contains?(result["append_system_prompt"], "safety")
    end

    test "apply_preset_optimizations/2 configures analysis tools" do
      base_options = %{"max_turns" => 5}

      result = OptionBuilder.apply_preset_optimizations(:analysis, base_options)

      assert result["allowed_tools"] == ["Read", "Glob", "Grep"]
      assert String.contains?(result["append_system_prompt"], "thorough analysis")
    end

    test "apply_preset_optimizations/2 minimizes chat tools" do
      base_options = %{"allowed_tools" => ["Write", "Read"]}

      result = OptionBuilder.apply_preset_optimizations(:chat, base_options)

      assert result["allowed_tools"] == []
      assert String.contains?(result["append_system_prompt"], "concise responses")
    end
  end

  describe "preset configuration metadata" do
    test "get_preset_config/1 returns complete configuration info" do
      config = OptionBuilder.get_preset_config(:development)

      assert config.name == "Development"
      assert is_binary(config.description)
      assert is_list(config.optimized_for)
      assert "rapid development" in config.optimized_for
      assert is_map(config.options)
      assert config.options["max_turns"] == 20
    end

    test "get_preset_config/1 works with string names" do
      config = OptionBuilder.get_preset_config("production")

      assert config.name == "Production"
      assert "safety" in config.optimized_for
      assert config.options["max_turns"] == 10
    end

    test "get_preset_config/1 defaults to development for invalid names" do
      config = OptionBuilder.get_preset_config(:invalid)

      assert config.name == "Development"
    end
  end

  describe "preset listing and validation" do
    test "list_presets/0 returns all available presets" do
      presets = OptionBuilder.list_presets()

      assert length(presets) == 5

      preset_names = Enum.map(presets, & &1.name)
      assert :development in preset_names
      assert :production in preset_names
      assert :analysis in preset_names
      assert :chat in preset_names
      assert :test in preset_names

      # Check that each preset has required fields
      Enum.each(presets, fn preset ->
        assert is_binary(preset.description)
        assert is_list(preset.optimized_for)
        assert length(preset.optimized_for) > 0
      end)
    end

    test "valid_preset?/1 validates preset names correctly" do
      assert OptionBuilder.valid_preset?(:development) == true
      assert OptionBuilder.valid_preset?("production") == true
      assert OptionBuilder.valid_preset?(:analysis) == true
      assert OptionBuilder.valid_preset?("chat") == true
      assert OptionBuilder.valid_preset?(:test) == true

      assert OptionBuilder.valid_preset?(:invalid) == false
      assert OptionBuilder.valid_preset?("invalid") == false
      assert OptionBuilder.valid_preset?(nil) == false
    end
  end

  describe "edge cases and error handling" do
    test "merge/2 handles empty overrides" do
      result = OptionBuilder.merge(:development, %{})
      development_preset = OptionBuilder.build_development_options()

      assert result == development_preset
    end

    test "merge/2 handles nil overrides gracefully" do
      result = OptionBuilder.merge(:development, nil)
      development_preset = OptionBuilder.build_development_options()

      # Should handle nil by treating it as empty map
      assert result["max_turns"] == development_preset["max_turns"]
    end

    test "apply_preset_optimizations/2 handles unknown preset gracefully" do
      base_options = %{"max_turns" => 10}

      result = OptionBuilder.apply_preset_optimizations(:unknown, base_options)

      # Should return original options unchanged
      assert result == base_options
    end
  end
end
