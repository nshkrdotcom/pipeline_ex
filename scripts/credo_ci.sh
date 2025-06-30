#!/bin/bash

# Run Credo for CI - excludes refactoring opportunities 
# This allows refactoring suggestions locally but doesn't fail CI

set -e

echo "🔍 Running Credo (excluding refactoring opportunities)..."

# Capture credo output
credo_output=$(mix credo --strict 2>&1)
credo_exit_code=$?

# Print the output but filter out refactoring opportunities for analysis
echo "$credo_output" | grep -v -A 1000 "Refactoring opportunities" | grep -v -E "^\[F\]" || true

# Check if there were any Software Design or Code Readability issues
if echo "$credo_output" | grep -q -E "(Software Design|Code Readability)"; then
    # Check if these sections have actual issues (not just headers)
    design_issues=$(echo "$credo_output" | sed -n '/Software Design/,/Code Readability\|Refactoring opportunities\|Please report/p' | grep -c "^\[D\]" || true)
    readability_issues=$(echo "$credo_output" | sed -n '/Code Readability/,/Refactoring opportunities\|Please report/p' | grep -c "^\[R\]" || true)
    
    if [ "$design_issues" -gt 0 ] || [ "$readability_issues" -gt 0 ]; then
        echo "❌ Found $design_issues design issues and $readability_issues readability issues"
        exit 1
    fi
fi

echo "✅ No critical Credo issues found (refactoring opportunities are shown locally only)"
exit 0
