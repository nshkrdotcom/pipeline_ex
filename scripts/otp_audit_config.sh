#!/bin/bash

# OTP Audit Configuration
# This file can be sourced to override default patterns

# Patterns to ignore (regex)
# These patterns will be excluded from results
IGNORE_PATTERNS=(
    # Ignore System.halt in Mix tasks (legitimate use)
    "lib/mix/tasks/.*System\.halt"
    
    # Ignore timer.sleep in tests
    "test/.*:timer\.sleep"
    
    # Ignore Process.sleep in tests
    "test/.*Process\.sleep"
    
    # Ignore Process.exit(:kill) in tests
    "test/.*Process\.exit.*:kill"
    
    # Ignore Process dictionary in test mocks
    "test/.*Process\.get"
    "test/.*Process\.put"
    "lib/pipeline/test/.*Process\."
)

# Additional patterns to check (add your own)
CUSTOM_PATTERNS=(
    # Add custom patterns here
    # Format: "pattern|description|severity"
    "IO\.inspect.*prod|IO.inspect in production code|MEDIUM"
    "TODO|TODO comments|LOW"
    "FIXME|FIXME comments|MEDIUM"
    "XXX|XXX comments|HIGH"
)

# Files/directories to exclude from search
EXCLUDE_DIRS=(
    "_build"
    "deps"
    ".git"
    "node_modules"
    "priv/static"
)

# Severity levels that should cause exit failure
FAIL_ON_SEVERITY=("HIGH")

# Whether to check test files
CHECK_TEST_FILES=true

# Output format (text, json, csv)
OUTPUT_FORMAT="text"

# Maximum line length to display in report
MAX_LINE_LENGTH=120