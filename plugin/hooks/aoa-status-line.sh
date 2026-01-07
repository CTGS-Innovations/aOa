#!/bin/bash
# =============================================================================
# aOa Status Line - Savings Display
# =============================================================================
#
# Format:
#   ⚡ aOa 🟢 100% │ ↓45k ⚡2.3s saved │ ctx:51k/200k (26%) │ Opus 4.5
#
# =============================================================================

set -uo pipefail

AOA_URL="${AOA_URL:-http://localhost:8080}"

# ANSI colors
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# === READ INPUT FROM CLAUDE CODE ===
input=$(cat)

# === PARSE CONTEXT WINDOW ===
CURRENT_USAGE=$(echo "$input" | jq '.context_window.current_usage' 2>/dev/null)
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)

# Get tokens
if [ "$CURRENT_USAGE" != "null" ] && [ -n "$CURRENT_USAGE" ]; then
    INPUT_TOKENS=$(echo "$CURRENT_USAGE" | jq -r '.input_tokens // 0')
    CACHE_CREATION=$(echo "$CURRENT_USAGE" | jq -r '.cache_creation_input_tokens // 0')
    CACHE_READ=$(echo "$CURRENT_USAGE" | jq -r '.cache_read_input_tokens // 0')
    TOTAL_TOKENS=$((INPUT_TOKENS + CACHE_CREATION + CACHE_READ))
else
    TOTAL_TOKENS=0
fi

# Ensure numeric
CONTEXT_SIZE=${CONTEXT_SIZE:-200000}
[ "$CONTEXT_SIZE" -eq 0 ] 2>/dev/null && CONTEXT_SIZE=200000
TOTAL_TOKENS=${TOTAL_TOKENS:-0}

# Calculate percentage
if [ "$CONTEXT_SIZE" -gt 0 ]; then
    PERCENT=$((TOTAL_TOKENS * 100 / CONTEXT_SIZE))
else
    PERCENT=0
fi

# Format tokens (e.g., 51k, 200k)
format_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then
        local m=$((n / 1000000))
        local k=$(( (n % 1000000) / 100000 ))
        if [ "$k" -gt 0 ]; then
            echo "${m}.${k}M"
        else
            echo "${m}M"
        fi
    elif [ "$n" -ge 1000 ]; then
        local k=$((n / 1000))
        echo "${k}k"
    else
        echo "$n"
    fi
}

# Format time (seconds to human readable)
format_time() {
    local sec=$1
    if [ "$sec" -ge 3600 ]; then
        local h=$((sec / 3600))
        local m=$(( (sec % 3600) / 60 ))
        echo "${h}h${m}m"
    elif [ "$sec" -ge 60 ]; then
        local m=$((sec / 60))
        local s=$((sec % 60))
        echo "${m}m${s}s"
    else
        echo "${sec}s"
    fi
}

TOTAL_FMT=$(format_tokens $TOTAL_TOKENS)
CTX_SIZE_FMT=$(format_tokens $CONTEXT_SIZE)

# Context color
if [ "$PERCENT" -lt 50 ]; then CTX_COLOR=$GREEN
elif [ "$PERCENT" -lt 75 ]; then CTX_COLOR=$YELLOW
else CTX_COLOR=$RED
fi

# === GET AOA METRICS ===
METRICS=$(curl -s --max-time 0.3 "${AOA_URL}/metrics" 2>/dev/null)

if [ -z "$METRICS" ]; then
    # aOa not running - minimal output
    echo -e "${CYAN}${BOLD}⚡ aOa${RESET} ${DIM}│ offline │${RESET} ctx:${CTX_COLOR}${TOTAL_FMT}/${CTX_SIZE_FMT}${RESET} ${DIM}(${PERCENT}%)${RESET} ${DIM}│${RESET} ${MODEL}"
    exit 0
fi

# Parse metrics
EVAL=$(echo "$METRICS" | jq -r '.rolling.evaluated // 0')
HIT_PCT=$(echo "$METRICS" | jq -r '.rolling.hit_at_5_pct // 0')
HIT_PCT_INT=$(printf "%.0f" "$HIT_PCT")

# Parse savings
TOKENS_SAVED=$(echo "$METRICS" | jq -r '.savings.tokens // 0')
TIME_SAVED_SEC=$(echo "$METRICS" | jq -r '.savings.time_sec // 0')
TIME_SAVED_SEC_INT=$(printf "%.0f" "$TIME_SAVED_SEC")

# === ACCURACY DISPLAY ===
if [ "$EVAL" -lt 3 ] 2>/dev/null; then
    ACC_DISPLAY="${DIM}calibrating${RESET}"
elif [ "$HIT_PCT_INT" -ge 80 ] 2>/dev/null; then
    ACC_DISPLAY="${GREEN}🟢 ${BOLD}${HIT_PCT_INT}%${RESET}"
elif [ "$HIT_PCT_INT" -ge 50 ] 2>/dev/null; then
    ACC_DISPLAY="${YELLOW}🟡 ${BOLD}${HIT_PCT_INT}%${RESET}"
else
    ACC_DISPLAY="${RED}🔴 ${BOLD}${HIT_PCT_INT}%${RESET}"
fi

# === SAVINGS DISPLAY ===
TOKENS_SAVED_FMT=$(format_tokens $TOKENS_SAVED)
TIME_SAVED_FMT=$(format_time $TIME_SAVED_SEC_INT)

if [ "$TOKENS_SAVED" -gt 0 ] 2>/dev/null; then
    SAVINGS_DISPLAY="${GREEN}↓${TOKENS_SAVED_FMT}${RESET} ${GREEN}⚡${TIME_SAVED_FMT}${RESET}"
else
    SAVINGS_DISPLAY="${DIM}tracking...${RESET}"
fi

# === OUTPUT ===
SEP="${DIM}│${RESET}"

echo -e "${CYAN}${BOLD}⚡ aOa${RESET} ${ACC_DISPLAY} ${SEP} ${SAVINGS_DISPLAY} ${SEP} ctx:${CTX_COLOR}${TOTAL_FMT}/${CTX_SIZE_FMT}${RESET} ${DIM}(${PERCENT}%)${RESET} ${SEP} ${MODEL}"
