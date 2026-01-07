#!/bin/bash
# =============================================================================
# aOa Status Line - Compact with Sparkline
# =============================================================================
#
# Format:
#   ⚡ aOa 🟢 100% │ ▂▄▆█▇███▇█ │ ctx:51k/200k (26%) │ Opus 4.5
#
# =============================================================================

set -uo pipefail

AOA_URL="${AOA_URL:-http://localhost:8080}"
HISTORY_FILE="${AOA_HISTORY_FILE:-$HOME/.aoa/hit_history}"

# ANSI colors
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
GRAY='\033[90m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Sparkline characters (8 levels)
BARS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

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
        echo "$((n / 1000))k"
    elif [ "$n" -ge 1000 ]; then
        local k=$((n / 1000))
        echo "${k}k"
    else
        echo "$n"
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

# === SPARKLINE FROM HISTORY ===
# History file format: one number per line (0-100 hit rate per batch)
# We'll generate sparkline from last 12 values

build_sparkline() {
    local history_data=""

    # Read history file if exists
    if [ -f "$HISTORY_FILE" ]; then
        history_data=$(tail -12 "$HISTORY_FILE" 2>/dev/null)
    fi

    # If no history, generate from current stats
    if [ -z "$history_data" ]; then
        # Bootstrap with current hit rate repeated
        local sparkline=""
        for i in {1..10}; do
            local bar_idx=$((HIT_PCT_INT * 7 / 100))
            [ "$bar_idx" -gt 7 ] && bar_idx=7
            [ "$bar_idx" -lt 0 ] && bar_idx=0

            # Color based on value
            if [ "$HIT_PCT_INT" -ge 80 ]; then
                sparkline+="${GREEN}${BARS[$bar_idx]}${RESET}"
            elif [ "$HIT_PCT_INT" -ge 50 ]; then
                sparkline+="${YELLOW}${BARS[$bar_idx]}${RESET}"
            else
                sparkline+="${GRAY}${BARS[$bar_idx]}${RESET}"
            fi
        done
        echo -e "$sparkline"
        return
    fi

    # Build sparkline from history
    local sparkline=""
    while IFS= read -r val; do
        [ -z "$val" ] && continue
        local v=${val%.*}  # Remove decimal
        v=${v:-0}

        # Map 0-100 to bar index 0-7
        local bar_idx=$((v * 7 / 100))
        [ "$bar_idx" -gt 7 ] && bar_idx=7
        [ "$bar_idx" -lt 0 ] && bar_idx=0

        # Color based on value
        if [ "$v" -ge 80 ]; then
            sparkline+="${GREEN}${BARS[$bar_idx]}${RESET}"
        elif [ "$v" -ge 50 ]; then
            sparkline+="${YELLOW}${BARS[$bar_idx]}${RESET}"
        else
            sparkline+="${GRAY}${BARS[$bar_idx]}${RESET}"
        fi
    done <<< "$history_data"

    echo -e "$sparkline"
}

SPARKLINE=$(build_sparkline)

# === RECORD HISTORY (for sparkline evolution) ===
# Only record if we have valid data and enough samples
if [ "$EVAL" -ge 3 ] 2>/dev/null; then
    mkdir -p "$(dirname "$HISTORY_FILE")" 2>/dev/null
    echo "$HIT_PCT_INT" >> "$HISTORY_FILE"
    # Keep only last 100 entries
    if [ -f "$HISTORY_FILE" ]; then
        tail -100 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi
fi

# === OUTPUT ===
SEP="${DIM}│${RESET}"

echo -e "${CYAN}${BOLD}⚡ aOa${RESET} ${ACC_DISPLAY} ${SEP} ${SPARKLINE} ${SEP} ctx:${CTX_COLOR}${TOTAL_FMT}/${CTX_SIZE_FMT}${RESET} ${DIM}(${PERCENT}%)${RESET} ${SEP} ${MODEL}"
