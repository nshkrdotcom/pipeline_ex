#!/bin/bash

# OTP and Elixir Code Audit Script
# Searches for potentially problematic patterns in lib/ and test/ directories

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories to search
SEARCH_DIRS="lib test"

# Output file for detailed report
REPORT_FILE="otp_audit_report_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}=== OTP and Elixir Code Audit ===${NC}"
echo "Searching in: $SEARCH_DIRS"
echo "Report will be saved to: $REPORT_FILE"
echo ""

# Initialize report
echo "OTP and Elixir Code Audit Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to search and report
search_pattern() {
    local pattern="$1"
    local description="$2"
    local severity="$3"  # HIGH, MEDIUM, LOW
    
    echo -e "\n${YELLOW}Checking for: ${description}${NC}"
    echo -e "\n## $description (Severity: $severity)" >> "$REPORT_FILE"
    
    local found=0
    
    # Use grep with proper options
    if grep -rn --include="*.ex" --include="*.exs" "$pattern" $SEARCH_DIRS 2>/dev/null | grep -v "otp_audit.sh"; then
        found=1
    fi >> "$REPORT_FILE"
    
    if [ $found -eq 0 ]; then
        echo -e "${GREEN}✓ None found${NC}"
        echo "None found" >> "$REPORT_FILE"
    else
        if [ "$severity" == "HIGH" ]; then
            echo -e "${RED}✗ Found instances (see report for details)${NC}"
        else
            echo -e "${YELLOW}⚠ Found instances (see report for details)${NC}"
        fi
    fi
}

# Function to search with word boundaries
search_word() {
    local word="$1"
    local description="$2"
    local severity="$3"
    search_pattern "\b${word}\b" "$description" "$severity"
}

echo -e "${BLUE}=== Searching for Banned/Dangerous Patterns ===${NC}"

# Banned patterns - should never be used
echo -e "\n${RED}[BANNED PATTERNS]${NC}"
search_word "spawn" "Direct spawn usage (use Task or GenServer instead)" "HIGH"
search_word "spawn_link" "Direct spawn_link usage (use Task or supervised process)" "HIGH"
search_word "spawn_monitor" "Direct spawn_monitor usage" "HIGH"
search_pattern ":timer\.sleep" "Timer.sleep usage (blocks scheduler)" "HIGH"
search_pattern "Process\.sleep" "Process.sleep usage (blocks scheduler)" "HIGH"
search_pattern "receive\s*do.*after\s*:infinity" "Receive with :infinity timeout" "HIGH"
search_pattern "GenServer\.call.*:infinity" "GenServer.call with :infinity timeout" "HIGH"
search_pattern "Task\.await.*:infinity" "Task.await with :infinity timeout" "HIGH"
search_pattern "Task\.await_many.*:infinity" "Task.await_many with :infinity timeout" "HIGH"

# Unsupervised processes
echo -e "\n${YELLOW}[UNSUPERVISED PROCESSES]${NC}"
search_pattern "GenServer\.start[^_]" "GenServer.start without link (orphaned process)" "HIGH"
search_pattern "Agent\.start[^_]" "Agent.start without link (orphaned process)" "HIGH"
search_pattern "Task\.start" "Task.start (unsupervised task)" "MEDIUM"
search_pattern "GenServer\.start_link.*name:" "GenServer with registered name (needs supervision)" "MEDIUM"
search_pattern "Agent\.start_link.*name:" "Agent with registered name (needs supervision)" "MEDIUM"

# Dangerous patterns
echo -e "\n${YELLOW}[DANGEROUS PATTERNS]${NC}"
search_word "Task\.async[^_]" "Task.async without supervisor" "MEDIUM"
search_pattern "Process\.register" "Manual process registration" "MEDIUM"
search_pattern "Process\.whereis.*\n.*GenServer\." "Race condition: whereis followed by GenServer call" "MEDIUM"
search_pattern "File\.rm.*\n.*File\.write" "File race condition: delete followed by write" "MEDIUM"
search_pattern ":ets\.new.*\[:named_table" "Named ETS table (potential collision)" "LOW"
search_pattern "Process\.exit.*:kill" "Process.exit with :kill (brutal termination)" "MEDIUM"
search_pattern "System\.halt" "System.halt (kills entire VM)" "HIGH"

# Process dictionary abuse
echo -e "\n${YELLOW}[PROCESS DICTIONARY]${NC}"
search_pattern "Process\.get[^_]" "Process dictionary read (use GenServer state)" "LOW"
search_pattern "Process\.put" "Process dictionary write (use GenServer state)" "LOW"
search_pattern "Process\.delete" "Process dictionary delete" "LOW"

# Global state
echo -e "\n${YELLOW}[GLOBAL STATE]${NC}"
search_pattern ":persistent_term\." "Persistent term usage (be careful with updates)" "LOW"
search_pattern "Application\.put_env" "Runtime config modification" "MEDIUM"
search_pattern ":global\.register" "Global process registration" "MEDIUM"

# Resource leaks
echo -e "\n${YELLOW}[POTENTIAL RESOURCE LEAKS]${NC}"
search_pattern "File\.open[^!]" "File.open without ! (check if closed)" "LOW"
search_pattern ":dets\.open" "DETS table (check if closed)" "LOW"
search_pattern "Port\.open" "Port usage (check if closed)" "MEDIUM"

# Concurrency issues
echo -e "\n${YELLOW}[CONCURRENCY ISSUES]${NC}"
search_pattern "Enum\.map.*Task\.async" "Task.async inside Enum.map (use Task.async_stream)" "MEDIUM"
search_pattern "for.*Task\.async" "Task.async inside for comprehension" "MEDIUM"
search_pattern "rescue\s*_\s*->" "Catching all exceptions (hides errors)" "MEDIUM"
search_pattern "try.*rescue.*in\s*_" "Rescuing all error types" "MEDIUM"

# Bad supervision patterns
echo -e "\n${YELLOW}[SUPERVISION ISSUES]${NC}"
search_pattern "Supervisor\.start_link.*strategy:\s*:one_for_all" "one_for_all strategy (cascading restarts)" "LOW"
search_pattern "child_spec.*restart:\s*:permanent.*\n.*Task" "Permanent restart for Task (should be :temporary)" "MEDIUM"

# Performance issues
echo -e "\n${YELLOW}[PERFORMANCE CONCERNS]${NC}"
search_pattern "Enum\..*Enum\." "Nested Enum operations (use Stream or single pass)" "LOW"
search_pattern "\+\+ inside.*Enum\." "List concatenation in loop (use reverse/flatten)" "LOW"
search_pattern "length(" "Length calculation (O(n) for lists)" "LOW"

echo -e "\n${BLUE}=== Summary ===${NC}"

# Count issues by severity
HIGH_COUNT=$(grep -c "Severity: HIGH" "$REPORT_FILE" || true)
MEDIUM_COUNT=$(grep -c "Severity: MEDIUM" "$REPORT_FILE" || true)
LOW_COUNT=$(grep -c "Severity: LOW" "$REPORT_FILE" || true)

echo -e "${RED}High severity issues: $HIGH_COUNT${NC}"
echo -e "${YELLOW}Medium severity issues: $MEDIUM_COUNT${NC}"
echo -e "${GREEN}Low severity issues: $LOW_COUNT${NC}"

echo -e "\n${BLUE}Detailed report saved to: ${GREEN}$REPORT_FILE${NC}"

# Add summary to report
echo -e "\n\n## SUMMARY" >> "$REPORT_FILE"
echo "High severity issues: $HIGH_COUNT" >> "$REPORT_FILE"
echo "Medium severity issues: $MEDIUM_COUNT" >> "$REPORT_FILE"
echo "Low severity issues: $LOW_COUNT" >> "$REPORT_FILE"

# Exit with error if high severity issues found
if [ $HIGH_COUNT -gt 0 ]; then
    echo -e "\n${RED}⚠️  High severity issues found! Please review the report.${NC}"
    exit 1
else
    echo -e "\n${GREEN}✓ No high severity issues found.${NC}"
    exit 0
fi