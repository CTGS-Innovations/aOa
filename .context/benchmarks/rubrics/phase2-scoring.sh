#!/bin/bash
# phase2-prediction.sh - Phase 2 Predictive Prefetch Rubrics
#
# These tests verify that sequence prediction actually adds value.
# Two modes:
#   1. FEASIBILITY mode (default): Tests if patterns exist in session data
#   2. LIVE mode: Tests the actual /predict endpoint
#
# Usage:
#   ./phase2-prediction.sh              # Feasibility mode (test concept)
#   ./phase2-prediction.sh --live       # Live mode (test implementation)
#
# IMPORTANT: Run feasibility mode BEFORE implementing P2 to validate concept.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"

# Configuration
AOA_URL="${AOA_URL:-http://localhost:8080}"
REDIS_CLI="${REDIS_CLI:-docker exec aoa-redis-1 redis-cli}"
FIXTURES_DIR="$SCRIPT_DIR/../fixtures"
TEST_DB=15

# Mode: feasibility or live
MODE="${1:-feasibility}"
[[ "$MODE" == "--live" ]] && MODE="live"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================
# SETUP / TEARDOWN
# ============================================================

setup() {
    $REDIS_CLI -n $TEST_DB FLUSHDB > /dev/null 2>&1 || true
}

teardown() {
    $REDIS_CLI -n $TEST_DB FLUSHDB > /dev/null 2>&1 || true
}

# ============================================================
# HELPER: Simulate file access sequence
# ============================================================

# Record a file access to Redis (simulates what intent-capture does)
record_access() {
    local session_id="$1"
    local file_path="$2"
    local timestamp="${3:-$(date +%s)}"

    # Record to session sequence
    $REDIS_CLI -n $TEST_DB RPUSH "aoa:session:$session_id:sequence" "$file_path" > /dev/null

    # Record recency
    $REDIS_CLI -n $TEST_DB ZADD "aoa:recency" "$timestamp" "$file_path" > /dev/null

    # Record frequency
    $REDIS_CLI -n $TEST_DB ZINCRBY "aoa:frequency" 1 "$file_path" > /dev/null
}

# Build co-occurrence matrix from session sequences
build_cooccurrence() {
    local sessions
    sessions=$($REDIS_CLI -n $TEST_DB KEYS "aoa:session:*:sequence" 2>/dev/null)

    for session_key in $sessions; do
        local files
        files=$($REDIS_CLI -n $TEST_DB LRANGE "$session_key" 0 -1 2>/dev/null)

        local prev=""
        for file in $files; do
            if [[ -n "$prev" ]]; then
                # Record that $prev was followed by $file
                $REDIS_CLI -n $TEST_DB ZINCRBY "aoa:next:$prev" 1 "$file" > /dev/null
            fi
            prev="$file"
        done
    done
}

# Get prediction for next file after current file
predict_next() {
    local current_file="$1"
    local limit="${2:-5}"

    if [[ "$MODE" == "live" ]]; then
        # Use actual /predict endpoint
        curl -s "$AOA_URL/predict?file=$current_file&limit=$limit" 2>/dev/null | jq -r '.predictions[]?' 2>/dev/null
    else
        # Use Redis co-occurrence data
        $REDIS_CLI -n $TEST_DB ZREVRANGE "aoa:next:$current_file" 0 $((limit-1)) 2>/dev/null
    fi
}

# ============================================================
# RUBRIC 1: Sequence Pattern Detection
# Can we identify A->B patterns in access sequences?
# ============================================================
test_sequence_pattern_detection() {
    local test_name="Sequence Pattern Detection"
    echo -e "${BOLD}TEST: $test_name${NC}"
    echo "  Verifying we can detect A->B patterns in file accesses"

    setup

    # Simulate a clear pattern: routes.py -> handlers.py (3 times)
    local session_id="test-seq-$$"

    for i in 1 2 3; do
        record_access "$session_id" "/src/api/routes.py" "$(($(date +%s) + i*10))"
        record_access "$session_id" "/src/api/handlers.py" "$(($(date +%s) + i*10 + 1))"
    done

    # Build co-occurrence
    build_cooccurrence

    # Check if handlers.py is predicted after routes.py
    local predictions
    predictions=$(predict_next "/src/api/routes.py" 3)

    if echo "$predictions" | grep -q "handlers.py"; then
        echo -e "  ${GREEN}PASS${NC}: handlers.py predicted after routes.py"
        teardown
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: handlers.py NOT in predictions"
        echo "  Got: $predictions"
        teardown
        return 1
    fi
}

# ============================================================
# RUBRIC 2: Co-Access Correlation
# Files accessed in same session should correlate
# ============================================================
test_cooccurrence_correlation() {
    local test_name="Co-Access Correlation"
    echo -e "${BOLD}TEST: $test_name${NC}"
    echo "  Files accessed together should become correlated"

    setup

    # Session 1: A -> B -> C
    record_access "session1" "/src/models.py"
    record_access "session1" "/src/db.py"
    record_access "session1" "/src/queries.py"

    # Session 2: A -> B -> C (same pattern)
    record_access "session2" "/src/models.py"
    record_access "session2" "/src/db.py"
    record_access "session2" "/src/queries.py"

    # Session 3: X -> Y -> Z (different pattern)
    record_access "session3" "/tests/test_api.py"
    record_access "session3" "/tests/fixtures.py"

    build_cooccurrence

    # After accessing models.py, db.py should rank higher than test_api.py
    local predictions
    predictions=$(predict_next "/src/models.py" 5)

    local db_rank=-1
    local test_rank=-1
    local rank=0

    while IFS= read -r file; do
        ((rank++))
        [[ "$file" == "/src/db.py" ]] && db_rank=$rank
        [[ "$file" == "/tests/test_api.py" ]] && test_rank=$rank
    done <<< "$predictions"

    if [[ $db_rank -gt 0 ]] && { [[ $test_rank -eq -1 ]] || [[ $db_rank -lt $test_rank ]]; }; then
        echo -e "  ${GREEN}PASS${NC}: Correlated file db.py ranks higher"
        teardown
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Correlation not detected"
        echo "  db.py rank: $db_rank, test_api.py rank: $test_rank"
        teardown
        return 1
    fi
}

# ============================================================
# RUBRIC 3: Prediction Hit Rate
# Replay sessions and measure prediction accuracy
# ============================================================
test_prediction_hit_rate() {
    local test_name="Prediction Hit Rate"
    echo -e "${BOLD}TEST: $test_name${NC}"
    echo "  Measuring prediction accuracy on synthetic sessions"

    setup

    # Train on repeated patterns
    for i in 1 2 3 4 5; do
        local sid="train-$i"
        record_access "$sid" "/src/api/routes.py"
        record_access "$sid" "/src/api/handlers.py"
        record_access "$sid" "/src/api/schemas.py"
    done

    for i in 1 2 3; do
        local sid="train-db-$i"
        record_access "$sid" "/src/db/models.py"
        record_access "$sid" "/src/db/queries.py"
    done

    build_cooccurrence

    # Test: replay a new session and count hits
    local test_sequence=("/src/api/routes.py" "/src/api/handlers.py" "/src/api/schemas.py")
    local hits=0
    local attempts=0

    for ((i=0; i<${#test_sequence[@]}-1; i++)); do
        local current="${test_sequence[$i]}"
        local next="${test_sequence[$((i+1))]}"

        local predictions
        predictions=$(predict_next "$current" 5)
        ((attempts++))

        if echo "$predictions" | grep -q "$(basename "$next")"; then
            ((hits++))
        fi
    done

    local hit_rate=0
    if [[ $attempts -gt 0 ]]; then
        hit_rate=$(echo "scale=2; $hits * 100 / $attempts" | bc)
    fi

    echo "  Hit rate: $hit_rate% ($hits/$attempts)"

    # Target: >30% hit rate
    if (( $(echo "$hit_rate >= 30" | bc -l) )); then
        echo -e "  ${GREEN}PASS${NC}: Hit rate >= 30%"
        teardown
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Hit rate < 30% target"
        teardown
        return 1
    fi
}

# ============================================================
# RUBRIC 4: Cold Start Graceful Degradation
# Unknown files should not crash, should fall back gracefully
# ============================================================
test_cold_start() {
    local test_name="Cold Start Graceful Degradation"
    echo -e "${BOLD}TEST: $test_name${NC}"
    echo "  Unknown files should return empty, not error"

    setup

    # Query for a file we've never seen
    local predictions
    predictions=$(predict_next "/completely/unknown/file.py" 5 2>&1) || true

    # Should not error, should return empty or graceful response
    if [[ -z "$predictions" ]] || [[ "$predictions" == "null" ]]; then
        echo -e "  ${GREEN}PASS${NC}: Empty predictions for unknown file"
        teardown
        return 0
    elif echo "$predictions" | grep -qi "error"; then
        echo -e "  ${RED}FAIL${NC}: Got error instead of empty result"
        teardown
        return 1
    else
        echo -e "  ${GREEN}PASS${NC}: Graceful response for unknown file"
        teardown
        return 0
    fi
}

# ============================================================
# RUBRIC 5: Prediction Latency
# Predictions should be fast (<50ms)
# ============================================================
test_prediction_latency() {
    local test_name="Prediction Latency"
    echo -e "${BOLD}TEST: $test_name${NC}"
    echo "  Predictions should complete in <50ms"

    setup

    # Build some data
    for i in $(seq 1 100); do
        record_access "perf-$i" "/src/file$i.py"
        record_access "perf-$i" "/src/file$((i+1)).py"
    done
    build_cooccurrence

    # Measure prediction time
    local total_ms=0
    local runs=10

    for _ in $(seq 1 $runs); do
        local start end elapsed_ms
        start=$(date +%s%N)
        predict_next "/src/file50.py" 10 > /dev/null 2>&1
        end=$(date +%s%N)
        elapsed_ms=$(( (end - start) / 1000000 ))
        total_ms=$((total_ms + elapsed_ms))
    done

    local avg_ms=$((total_ms / runs))
    echo "  Average latency: ${avg_ms}ms"

    if [[ $avg_ms -lt 50 ]]; then
        echo -e "  ${GREEN}PASS${NC}: Latency < 50ms"
        teardown
        return 0
    else
        echo -e "  ${RED}FAIL${NC}: Latency >= 50ms"
        teardown
        return 1
    fi
}

# ============================================================
# RUBRIC 6: Real Session Replay (using fixtures)
# Test against synthetic-sessions.jsonl
# ============================================================
test_real_session_replay() {
    local test_name="Real Session Replay"
    echo -e "${BOLD}TEST: $test_name${NC}"
    echo "  Replaying synthetic sessions to measure real-world accuracy"

    local fixtures_file="$FIXTURES_DIR/synthetic-sessions.jsonl"

    if [[ ! -f "$fixtures_file" ]]; then
        echo -e "  ${YELLOW}SKIP${NC}: No fixtures file found"
        return 0
    fi

    setup

    # Phase 1: Train on first half of each session
    local total_sessions=0
    local trained_sequences=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        ((total_sessions++))

        local session_name
        session_name=$(echo "$line" | jq -r '.session')

        # Extract file sequence from events
        local files
        files=$(echo "$line" | jq -r '.events[].files[]?' 2>/dev/null | head -5)

        local prev=""
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            record_access "fixture-$session_name" "$file"
            ((trained_sequences++))
            prev="$file"
        done <<< "$files"

    done < "$fixtures_file"

    echo "  Trained on $total_sessions sessions ($trained_sequences accesses)"

    build_cooccurrence

    # Phase 2: Test predictions
    local hits=0
    local attempts=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local files
        files=$(echo "$line" | jq -r '.events[].files[]?' 2>/dev/null)

        local prev=""
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue

            if [[ -n "$prev" ]]; then
                ((attempts++))
                local predictions
                predictions=$(predict_next "$prev" 10)

                if echo "$predictions" | grep -qF "$file"; then
                    ((hits++))
                fi
            fi
            prev="$file"
        done <<< "$files"

    done < "$fixtures_file"

    local hit_rate=0
    if [[ $attempts -gt 0 ]]; then
        hit_rate=$(echo "scale=1; $hits * 100 / $attempts" | bc)
    fi

    echo "  Real session hit rate: $hit_rate% ($hits/$attempts)"

    # Target for real sessions: >20% (lower than synthetic)
    if (( $(echo "$hit_rate >= 20" | bc -l) )); then
        echo -e "  ${GREEN}PASS${NC}: Real session hit rate >= 20%"
        teardown
        return 0
    else
        echo -e "  ${YELLOW}MARGINAL${NC}: Hit rate < 20% - patterns may be weak"
        teardown
        return 1
    fi
}

# ============================================================
# MAIN
# ============================================================
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        aOa Phase 2 Benchmark: Predictive Prefetch            ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    if [[ "$MODE" == "live" ]]; then
    echo "║  Mode: LIVE (testing /predict endpoint)                      ║"
    else
    echo "║  Mode: FEASIBILITY (testing concept with Redis simulation)   ║"
    fi
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Check Redis is available
    if ! $REDIS_CLI PING > /dev/null 2>&1; then
        echo -e "${RED}Redis not available${NC}"
        echo "Start with: docker-compose up -d redis"
        exit 1
    fi
    echo -e "  Redis: ${GREEN}OK${NC}"

    if [[ "$MODE" == "live" ]]; then
        if ! curl -s --max-time 2 "$AOA_URL/health" > /dev/null 2>&1; then
            echo -e "  aOa API: ${RED}NOT AVAILABLE${NC}"
            exit 1
        fi
        echo -e "  aOa API: ${GREEN}OK${NC}"
    fi
    echo ""

    local tests=(
        "test_sequence_pattern_detection"
        "test_cooccurrence_correlation"
        "test_prediction_hit_rate"
        "test_cold_start"
        "test_prediction_latency"
        "test_real_session_replay"
    )

    local passed=0
    local failed=0
    local results=()

    for test in "${tests[@]}"; do
        echo ""
        if $test; then
            passed=$((passed + 1))
            results+=("${GREEN}✓${NC} $test")
        else
            failed=$((failed + 1))
            results+=("${RED}✗${NC} $test")
        fi
    done

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                         RESULTS                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    for result in "${results[@]}"; do
        echo -e "  $result"
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  Total: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Save results
    local results_dir="$SCRIPT_DIR/../results"
    local today
    today=$(date +%Y-%m-%d)
    local results_file="$results_dir/${today}-phase2-${MODE}.json"

    mkdir -p "$results_dir"

    cat > "$results_file" << EOF
{
    "phase": 2,
    "mode": "$MODE",
    "date": "$today",
    "timestamp": "$(date -Iseconds)",
    "rubrics": {
        "passed": $passed,
        "failed": $failed,
        "total": ${#tests[@]}
    },
    "interpretation": {
        "feasibility_passed": $([ "$MODE" == "feasibility" ] && [ $passed -ge 4 ] && echo "true" || echo "false"),
        "ready_for_implementation": $([ $passed -ge 5 ] && echo "true" || echo "false")
    }
}
EOF

    echo "Results saved to: $results_file"
    echo ""

    if [[ "$MODE" == "feasibility" ]]; then
        if [[ $passed -ge 4 ]]; then
            echo -e "${GREEN}Feasibility VALIDATED${NC} - Prediction patterns exist in data"
            echo "Recommendation: Proceed with P2 implementation"
        else
            echo -e "${YELLOW}Feasibility UNCERTAIN${NC} - Weak patterns detected"
            echo "Recommendation: Investigate data quality before implementing P2"
        fi
    fi

    echo ""

    [[ $failed -gt 0 ]] && exit 1
    exit 0
}

main "$@"
