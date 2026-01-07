#!/bin/bash
# =============================================================================
# aOa Status Line - Progressive Display
# =============================================================================
#
# Progression:
#   Learning:    ⚡ aOa ⚪ 5/30 │ 4.2ms • 12 results │ ctx:... │ Model
#   Predicting:  ⚡ aOa 🟢 120 │ 3.5ms • 6 results │ ctx:... │ Model
#   With savings: ⚡ aOa 🟢 250 │ ↓12k ⚡30s saved │ ctx:... │ Model
#
# =============================================================================

set -uo pipefail

AOA_URL="${AOA_URL:-http://localhost:8080}"
STATUS_FILE="${AOA_STATUS_FILE:-$HOME/.aoa/status.json}"
MIN_INTENTS=30

# ANSI colors
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
GRAY='\033[90m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# === READ INPUT FROM CLAUDE CODE ===
input=$(cat)

# === PARSE CONTEXT WINDOW ===
CURRENT_USAGE=$(echo "$input" | jq '.context_window.current_usage' 2>/dev/null)
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
CWD=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null)

# Format CWD (show last 2 path components)
if [ -n "$CWD" ]; then
    CWD_SHORT=$(echo "$CWD" | rev | cut -d'/' -f1-2 | rev)
else
    CWD_SHORT=""
fi

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

# Format tokens (e.g., 51k, 1.2M)
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

# === GET INTENT COUNT ===
INTENTS=0
if [ -f "$STATUS_FILE" ]; then
    INTENTS=$(jq -r '.intents // 0' "$STATUS_FILE" 2>/dev/null)
fi
INTENTS=${INTENTS:-0}

# === GET AOA METRICS (with timing) ===
START_TIME=$(date +%s%N)
METRICS=$(curl -s --max-time 0.3 "${AOA_URL}/metrics" 2>/dev/null)
END_TIME=$(date +%s%N)

# Calculate response time in ms
if [ -n "$METRICS" ]; then
    RESPONSE_MS=$(( (END_TIME - START_TIME) / 1000000 ))
else
    RESPONSE_MS=0
fi

if [ -z "$METRICS" ]; then
    # aOa not running - minimal output
    echo -e "${CYAN}${BOLD}⚡ aOa${RESET} ${DIM}offline${RESET} ${DIM}│${RESET} ctx:${CTX_COLOR}${TOTAL_FMT}/${CTX_SIZE_FMT}${RESET} ${DIM}(${PERCENT}%)${RESET} ${DIM}│${RESET} ${MODEL}"
    exit 0
fi

# Parse metrics
HIT_PCT=$(echo "$METRICS" | jq -r '.rolling.hit_at_5_pct // 0')
HIT_PCT_INT=$(printf "%.0f" "$HIT_PCT")
TOKENS_SAVED=$(echo "$METRICS" | jq -r '.savings.tokens // 0')
TIME_SAVED_SEC=$(echo "$METRICS" | jq -r '.savings.time_sec // 0')
TIME_SAVED_SEC_INT=$(printf "%.0f" "$TIME_SAVED_SEC")
ROLLING_HITS=$(echo "$METRICS" | jq -r '.rolling.hits // 0')
EVALUATED=$(echo "$METRICS" | jq -r '.rolling.evaluated // 0')

# === BUILD DISPLAY ===
SEP="${DIM}│${RESET}"

# Traffic light + intents
if [ "$INTENTS" -lt "$MIN_INTENTS" ]; then
    # Learning phase: gray light, X/30
    LIGHT="${GRAY}⚪${RESET}"
    INTENT_DISPLAY="${INTENTS}/${MIN_INTENTS}"
elif [ "$HIT_PCT_INT" -ge 80 ] 2>/dev/null; then
    # Good predictions: green light
    LIGHT="${GREEN}🟢${RESET}"
    INTENT_DISPLAY="${INTENTS}"
else
    # Predicting but room to improve: yellow light
    LIGHT="${YELLOW}🟡${RESET}"
    INTENT_DISPLAY="${INTENTS}"
fi

# Format intents for display (1.2k for large numbers)
if [ "$INTENTS" -ge 1000 ]; then
    INTENT_FMT=$(format_tokens $INTENTS)
    if [ "$INTENTS" -lt "$MIN_INTENTS" ]; then
        INTENT_DISPLAY="${INTENT_FMT}/${MIN_INTENTS}"
    else
        INTENT_DISPLAY="${INTENT_FMT}"
    fi
fi

# Middle section: savings OR speed+results
if [ "$TOKENS_SAVED" -gt 0 ] 2>/dev/null; then
    # Have savings - show them
    TOKENS_SAVED_FMT=$(format_tokens $TOKENS_SAVED)
    TIME_SAVED_FMT=$(format_time $TIME_SAVED_SEC_INT)
    MIDDLE="${GREEN}↓${TOKENS_SAVED_FMT}${RESET} ${GREEN}⚡${TIME_SAVED_FMT}${RESET} saved"
else
    # No savings yet - show speed and results
    RESULTS=${ROLLING_HITS:-0}
    [ "$RESULTS" -eq 0 ] && RESULTS=${EVALUATED:-0}
    MIDDLE="${GREEN}${RESPONSE_MS}ms${RESET} ${DIM}•${RESET} ${RESULTS} results"
fi

# === OUTPUT ===
# Include CWD if available
if [ -n "$CWD_SHORT" ]; then
    echo -e "${CYAN}${BOLD}⚡ aOa${RESET} ${LIGHT} ${INTENT_DISPLAY} ${SEP} ${MIDDLE} ${SEP} ctx:${CTX_COLOR}${TOTAL_FMT}/${CTX_SIZE_FMT}${RESET} ${DIM}(${PERCENT}%)${RESET} ${SEP} ${MODEL} ${DIM}│${RESET} ${CYAN}${CWD_SHORT}${RESET}"
else
    echo -e "${CYAN}${BOLD}⚡ aOa${RESET} ${LIGHT} ${INTENT_DISPLAY} ${SEP} ${MIDDLE} ${SEP} ctx:${CTX_COLOR}${TOTAL_FMT}/${CTX_SIZE_FMT}${RESET} ${DIM}(${PERCENT}%)${RESET} ${SEP} ${MODEL}"
fi
