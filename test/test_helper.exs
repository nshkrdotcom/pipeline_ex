ExUnit.start()

# Configure ExUnit for compact output
ExUnit.configure(formatters: [ExUnit.CLIFormatter], format: :dot)

# Configure Logger for single-line output
Logger.configure(format: "$time [$level] $message\n")

# Load support files
Code.require_file("support/test_case.exs", __DIR__)
Code.require_file("support/pipeline_test_case.exs", __DIR__)
