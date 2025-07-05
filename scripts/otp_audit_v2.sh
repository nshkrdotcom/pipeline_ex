#!/bin/bash

# OTP and Elixir Code Audit Script v2
# Enhanced version with configuration support and better filtering

set -euo pipefail

# Default configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/otp_audit_config.sh"

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directories to search (can be overridden by config)
SEARCH_DIRS="${SEARCH_DIRS:-lib}"
if [ "${CHECK_TEST_FILES:-true}" == "true" ]; then
    SEARCH_DIRS="$SEARCH_DIRS test"
fi

# Output file for detailed report
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="otp_audit_report_${TIMESTAMP}.txt"
SUMMARY_FILE="otp_audit_summary_${TIMESTAMP}.txt"

echo -e "${BLUE}=== OTP and Elixir Code Audit v2 ===${NC}"
echo "Configuration: ${CONFIG_FILE}"
echo "Searching in: $SEARCH_DIRS"
echo "Reports: $REPORT_FILE, $SUMMARY_FILE"
echo ""

# Initialize reports
cat > "$REPORT_FILE" << EOF
OTP and Elixir Code Audit Report
Generated: $(date)
Configuration: ${CONFIG_FILE}
Search Directories: $SEARCH_DIRS
========================================

EOF

# Initialize summary
cat > "$SUMMARY_FILE" << EOF
OTP Audit Summary
Generated: $(date)
========================================

Issues by Category:
EOF

# Counters
declare -A issue_counts
declare -A category_counts

# Function to check if line should be ignored
should_ignore() {
    local line="$1"
    
    if [ -z "${IGNORE_PATTERNS+x}" ]; then
        return 1
    fi
    
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        if echo "$line" | grep -qE "$pattern"; then
            return 0
        fi
    done
    
    return 1
}

# Enhanced search function
search_pattern() {
    local pattern="$1"
    local description="$2"
    local severity="$3"
    local category="${4:-General}"
    
    echo -e "\n${YELLOW}Checking: ${description}${NC}"
    echo -e "\n## $description" >> "$REPORT_FILE"
    echo "Severity: $severity | Category: $category" >> "$REPORT_FILE"
    echo "Pattern: $pattern" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    
    local found=0
    local count=0
    local temp_file=$(mktemp)
    
    # Search for pattern
    grep -rn --include="*.ex" --include="*.exs" "$pattern" $SEARCH_DIRS 2>/dev/null > "$temp_file" || true
    
    # Process results
    while IFS= read -r line; do
        if ! should_ignore "$line"; then
            echo "$line" >> "$REPORT_FILE"
            ((count++))
            found=1
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ $found -eq 0 ]; then
        echo -e "${GREEN}✓ None found${NC}"
        echo "None found" >> "$REPORT_FILE"
    else
        # Update counters
        issue_counts["${severity}"]=$((${issue_counts["${severity}"]:-0} + count))
        category_counts["${category}"]=$((${category_counts["${category}"]:-0} + count))
        
        if [ "$severity" == "HIGH" ]; then
            echo -e "${RED}✗ Found $count instances${NC}"
        elif [ "$severity" == "MEDIUM" ]; then
            echo -e "${YELLOW}⚠ Found $count instances${NC}"
        else
            echo -e "${CYAN}ℹ Found $count instances${NC}"
        fi
    fi
    
    echo "" >> "$REPORT_FILE"
}

# Function to search with word boundaries
search_word() {
    local word="$1"
    local description="$2"
    local severity="$3"
    local category="${4:-General}"
    search_pattern "\b${word}\b" "$description" "$severity" "$category"
}

echo -e "${BLUE}=== Running Audit Checks ===${NC}"

# Critical Issues - Should rarely if ever be used
echo -e "\n${RED}[CRITICAL PATTERNS]${NC}"
search_word "spawn" "Direct spawn (use Task/GenServer)" "HIGH" "Concurrency"
search_word "spawn_link" "Direct spawn_link" "HIGH" "Concurrency"
search_pattern ":timer\.sleep" "Timer.sleep (blocks scheduler)" "HIGH" "Performance"
search_pattern "Process\.sleep" "Process.sleep (blocks scheduler)" "HIGH" "Performance"
search_pattern "receive.*after\s*:infinity" "Infinite receive timeout" "HIGH" "Reliability"
search_pattern "GenServer\.call.*:infinity" "Infinite GenServer timeout" "HIGH" "Reliability"
search_pattern "Task\.await.*:infinity" "Infinite Task.await" "HIGH" "Reliability"

# Process Management Issues
echo -e "\n${YELLOW}[PROCESS MANAGEMENT]${NC}"
search_pattern "GenServer\.start[^_]" "GenServer.start (no link)" "HIGH" "Process Management"
search_pattern "Agent\.start[^_]" "Agent.start (no link)" "HIGH" "Process Management"
search_pattern "Task\.start[^_]" "Task.start (unsupervised)" "MEDIUM" "Process Management"
search_pattern "GenServer\.start_link.*name:\s*[^,\n]*[^}]" "Named GenServer" "MEDIUM" "Process Management"
search_pattern "Agent\.start_link.*name:" "Named Agent" "MEDIUM" "Process Management"
search_word "Task\.async" "Unsupervised Task.async" "MEDIUM" "Process Management"

# State Management
echo -e "\n${YELLOW}[STATE MANAGEMENT]${NC}"
search_pattern "Process\.get[^_]" "Process dictionary read" "LOW" "State Management"
search_pattern "Process\.put" "Process dictionary write" "LOW" "State Management"
search_pattern ":ets\.new.*\[:named_table" "Named ETS table" "LOW" "State Management"
search_pattern "Application\.put_env" "Runtime config change" "MEDIUM" "State Management"

# Error Handling
echo -e "\n${YELLOW}[ERROR HANDLING]${NC}"
search_pattern "rescue\s*_\s*->" "Catch-all rescue" "MEDIUM" "Error Handling"
search_pattern "catch\s*_.*->" "Catch-all catch" "MEDIUM" "Error Handling"
search_pattern "Process\.exit.*:kill" "Process.exit(:kill)" "MEDIUM" "Error Handling"
search_pattern "System\.halt" "System.halt" "HIGH" "Error Handling"

# File System Operations
echo -e "\n${YELLOW}[FILE OPERATIONS]${NC}"
search_pattern "File\.rm.*\n.*File\.write" "File delete-write race" "MEDIUM" "File System"
search_pattern "File\.exists\?.*\n.*File\." "File exists check race" "LOW" "File System"

# Performance Concerns
echo -e "\n${CYAN}[PERFORMANCE]${NC}"
search_pattern "Enum\..*Enum\." "Nested Enum operations" "LOW" "Performance"
search_pattern "length(" "O(n) length calculation" "LOW" "Performance"
search_pattern "\+\+.*Enum\." "List concatenation in loop" "LOW" "Performance"

# Code Quality
echo -e "\n${CYAN}[CODE QUALITY]${NC}"
search_pattern "TODO" "TODO comments" "LOW" "Code Quality"
search_pattern "FIXME" "FIXME comments" "MEDIUM" "Code Quality"
search_pattern "IO\.inspect[^(]*prod" "IO.inspect in production" "MEDIUM" "Code Quality"

# Custom patterns from config
if [ ! -z "${CUSTOM_PATTERNS+x}" ]; then
    echo -e "\n${CYAN}[CUSTOM CHECKS]${NC}"
    for pattern_def in "${CUSTOM_PATTERNS[@]}"; do
        IFS='|' read -r pattern desc severity <<< "$pattern_def"
        search_pattern "$pattern" "$desc" "$severity" "Custom"
    done
fi

# Generate Summary
echo -e "\n${BLUE}=== Generating Summary ===${NC}"

{
    echo -e "\nIssue Counts by Severity:"
    echo "-------------------------"
    for severity in HIGH MEDIUM LOW; do
        count=${issue_counts[$severity]:-0}
        echo "$severity: $count"
    done
    
    echo -e "\nIssue Counts by Category:"
    echo "-------------------------"
    for category in "${!category_counts[@]}"; do
        echo "$category: ${category_counts[$category]}"
    done
    
    echo -e "\nRecommendations:"
    echo "-------------------------"
    
    if [ ${issue_counts[HIGH]:-0} -gt 0 ]; then
        echo "- Address HIGH severity issues immediately"
        echo "- Consider adding supervision for unsupervised processes"
        echo "- Replace infinite timeouts with configurable values"
    fi
    
    if [ ${issue_counts[MEDIUM]:-0} -gt 0 ]; then
        echo "- Review MEDIUM severity issues for production code"
        echo "- Consider refactoring Process dictionary usage"
        echo "- Improve error handling specificity"
    fi
    
    echo -e "\nNext Steps:"
    echo "1. Review detailed report: $REPORT_FILE"
    echo "2. Update ignore patterns in: $CONFIG_FILE"
    echo "3. Run audit regularly in CI/CD pipeline"
    
} >> "$SUMMARY_FILE"

# Display summary
cat "$SUMMARY_FILE"

echo -e "\n${BLUE}Reports saved:${NC}"
echo -e "  Detailed: ${GREEN}$REPORT_FILE${NC}"
echo -e "  Summary:  ${GREEN}$SUMMARY_FILE${NC}"

# Exit status based on configuration
exit_code=0
for severity in "${FAIL_ON_SEVERITY[@]}"; do
    if [ ${issue_counts[$severity]:-0} -gt 0 ]; then
        echo -e "\n${RED}⚠️  Found $severity severity issues!${NC}"
        exit_code=1
    fi
done

if [ $exit_code -eq 0 ]; then
    echo -e "\n${GREEN}✓ No blocking issues found${NC}"
fi

exit $exit_code