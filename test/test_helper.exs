ExUnit.start()

# Configure ExUnit for compact output
ExUnit.configure(formatters: [ExUnit.CLIFormatter], format: :dot, exclude: [:integration])

# Configure Logger for single-line output
Logger.configure(format: "$time [$level] $message\n")

# Load support files in dependency order
Code.require_file("support/test_case.exs", __DIR__)
Code.require_file("support/pipeline_test_case.exs", __DIR__)
Code.require_file("support/enhanced_mocks.ex", __DIR__)
Code.require_file("support/enhanced_factory.ex", __DIR__)
Code.require_file("support/enhanced_test_case.ex", __DIR__)
