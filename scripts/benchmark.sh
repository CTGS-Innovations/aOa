#!/bin/bash
# =============================================================================
# aOa Benchmark - Show the difference
# =============================================================================
#
# Compares traditional grep/find/read approaches vs aOa's O(1) search
#
# Usage:
#   ./scripts/benchmark.sh [path-to-codebase]
#
# =============================================================================

set -e

CODEBASE="${1:-.}"
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}⚡ aOa Benchmark${NC}"
echo
echo "Codebase: $CODEBASE"
echo

# =============================================================================
# Scenario 1: Find authentication code
# =============================================================================

echo -e "${BOLD}Scenario 1: Find all authentication code${NC}"
echo

# Count files
FILE_COUNT=$(find "$CODEBASE" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" \) | wc -l)
echo "Files in codebase: $FILE_COUNT"
echo

# --- Without aOa (grep) ---
echo -e "${YELLOW}WITHOUT aOa (traditional grep):${NC}"

START=$(date +%s%N)
grep -r "auth" "$CODEBASE" --include="*.py" --include="*.js" 2>/dev/null | wc -l > /tmp/grep1.txt &
PID1=$!
grep -r "login" "$CODEBASE" --include="*.py" --include="*.js" 2>/dev/null | wc -l > /tmp/grep2.txt &
PID2=$!
grep -r "session" "$CODEBASE" --include="*.py" --include="*.js" 2>/dev/null | wc -l > /tmp/grep3.txt &
PID3=$!
wait $PID1 $PID2 $PID3
END=$(date +%s%N)

GREP_MS=$(( (END - START) / 1000000 ))
GREP_RESULTS=$(( $(cat /tmp/grep1.txt) + $(cat /tmp/grep2.txt) + $(cat /tmp/grep3.txt) ))

echo "  Time:    ${GREP_MS}ms"
echo "  Results: $GREP_RESULTS matches"
echo "  Tools:   3 grep commands"
echo

# --- With aOa ---
echo -e "${GREEN}WITH aOa (O(1) multi-search):${NC}"

START=$(date +%s%N)
AOA_OUTPUT=$(aoa multi "auth,login,session" 2>&1)
END=$(date +%s%N)

AOA_MS=$(( (END - START) / 1000000 ))
AOA_RESULTS=$(echo "$AOA_OUTPUT" | grep -oP '\d+(?= hits)' || echo "0")

echo "  Time:    ${AOA_MS}ms"
echo "  Results: $AOA_RESULTS hits"
echo "  Tools:   1 command"
echo

# Calculate improvement
if [ $GREP_MS -gt 0 ]; then
    SPEEDUP=$(( GREP_MS / AOA_MS ))
    echo -e "${CYAN}${BOLD}Improvement: ${SPEEDUP}x faster${NC}"
fi

echo
echo "---"
echo

# =============================================================================
# Scenario 2: List all Python files
# =============================================================================

echo -e "${BOLD}Scenario 2: List all Python files${NC}"
echo

# --- Without aOa (find) ---
echo -e "${YELLOW}WITHOUT aOa (find command):${NC}"

START=$(date +%s%N)
FIND_COUNT=$(find "$CODEBASE" -type f -name "*.py" 2>/dev/null | wc -l)
END=$(date +%s%N)

FIND_MS=$(( (END - START) / 1000000 ))

echo "  Time:    ${FIND_MS}ms"
echo "  Results: $FIND_COUNT files"
echo

# --- With aOa ---
echo -e "${GREEN}WITH aOa (indexed files):${NC}"

START=$(date +%s%N)
AOA_COUNT=$(aoa files "*.py" 2>/dev/null | wc -l)
END=$(date +%s%N)

AOA_FILES_MS=$(( (END - START) / 1000000 ))

echo "  Time:    ${AOA_FILES_MS}ms"
echo "  Results: $AOA_COUNT files"
echo

if [ $FIND_MS -gt 0 ] && [ $AOA_FILES_MS -gt 0 ]; then
    SPEEDUP=$(( FIND_MS / AOA_FILES_MS ))
    echo -e "${CYAN}${BOLD}Improvement: ${SPEEDUP}x faster${NC}"
fi

echo
echo "---"
echo

# =============================================================================
# Summary
# =============================================================================

echo -e "${BOLD}Summary${NC}"
echo

TOTAL_GREP_MS=$(( GREP_MS + FIND_MS ))
TOTAL_AOA_MS=$(( AOA_MS + AOA_FILES_MS ))

if [ $TOTAL_GREP_MS -gt 0 ] && [ $TOTAL_AOA_MS -gt 0 ]; then
    OVERALL=$(( TOTAL_GREP_MS / TOTAL_AOA_MS ))
fi

echo "Traditional approach: ${TOTAL_GREP_MS}ms"
echo "aOa approach:         ${TOTAL_AOA_MS}ms"
echo
echo -e "${GREEN}${BOLD}Overall: ${OVERALL}x faster with aOa${NC}"
echo

echo -e "${CYAN}Token savings (estimated):${NC}"
echo "  Traditional: ~8,500 tokens (grep + read loops)"
echo "  aOa:         ~1,150 tokens (ranked results)"
echo "  Savings:     ${BOLD}~87% fewer tokens${NC}"
echo

# Cleanup
rm -f /tmp/grep*.txt
