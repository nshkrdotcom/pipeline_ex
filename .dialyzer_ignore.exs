[
  {"lib/mix/tasks/showcase.ex", :guard_fail},
  {"lib/pipeline/providers/gemini_provider.ex", :guard_fail},
  {"lib/pipeline/providers/gemini_provider.ex", :pattern_match_cov},
  {"lib/pipeline/result_manager.ex", :pattern_match_cov},
  {"lib/pipeline.ex", :contract_supertype},
  {"lib/pipeline/codebase/analyzers/elixir_analyzer.ex", :contract_supertype},
  {"lib/pipeline/codebase/discovery.ex", :contract_supertype},
  # Safety module dialyzer issues with default parameters and function overloading
  {"lib/pipeline/safety/recursion_guard.ex", :no_return},
  {"lib/pipeline/safety/recursion_guard.ex", :call},
  {"lib/pipeline/safety/resource_monitor.ex", :no_return},
  {"lib/pipeline/safety/resource_monitor.ex", :call},
  {"lib/pipeline/safety/resource_monitor.ex", :unmatched_return},
  {"lib/pipeline/safety/resource_monitor.ex", :extra_range},
  {"lib/pipeline/safety/safety_manager.ex", :no_return},
  {"lib/pipeline/safety/safety_manager.ex", :call},
  {"lib/pipeline/safety/safety_manager.ex", :invalid_contract},
  {"lib/pipeline/safety/safety_manager.ex", :unmatched_return},
  {"lib/pipeline/step/nested_pipeline.ex", :pattern_match_cov}
]
