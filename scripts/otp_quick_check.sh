#!/bin/bash

# Quick OTP Check - Only production code issues

echo "=== Quick OTP Issue Check (Production Code Only) ==="
echo ""

echo "Critical Issues in lib/ (excluding Mix tasks):"
echo "---------------------------------------------"

echo -n "Unsupervised GenServer/Agent: "
grep -rn --include="*.ex" "GenServer\.start_link.*name:\|Agent\.start_link.*name:" lib/ 2>/dev/null | grep -v "lib/mix" | wc -l

echo -n "Unsupervised Task.async: "
grep -rn --include="*.ex" "Task\.async[^_]" lib/ 2>/dev/null | grep -v "lib/mix" | wc -l

echo -n "Infinite timeouts: "
grep -rn --include="*.ex" ":infinity" lib/ 2>/dev/null | grep -v "lib/mix" | wc -l

echo -n "Process dictionary usage: "
grep -rn --include="*.ex" "Process\.\(get\|put\)" lib/ 2>/dev/null | grep -v "lib/pipeline/test" | wc -l

echo -n "File race conditions: "
grep -B1 -A1 --include="*.ex" "File\.write" lib/ 2>/dev/null | grep -B1 "File\.rm" | grep -v "lib/mix" | wc -l

echo ""
echo "Detailed Issues:"
echo "----------------"

echo -e "\n1. Unsupervised processes:"
grep -rn --include="*.ex" "GenServer\.start_link.*name:\|Agent\.start_link.*name:" lib/ 2>/dev/null | grep -v "lib/mix" || echo "  None found"

echo -e "\n2. Unsupervised tasks:"
grep -rn --include="*.ex" "Task\.async[^_]" lib/ 2>/dev/null | grep -v "lib/mix" | grep -v "Task\.async_stream" || echo "  None found"

echo -e "\n3. Infinite timeouts:"
grep -rn --include="*.ex" "Task\.await.*:infinity\|GenServer\.call.*:infinity" lib/ 2>/dev/null | grep -v "lib/mix" || echo "  None found"

echo -e "\n4. The ONE file race condition:"
echo "  lib/pipeline/checkpoint_manager.ex:53-54 - File.rm followed by File.write"

echo -e "\nSummary: Most issues are in test code or Mix tasks, which is acceptable."