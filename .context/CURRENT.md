# aOa Context Intelligence - Beacon

> **Session**: 04 | **Date**: 2025-12-23
> **Phase**: 2 - Predictive Prefetch + Correlation
> **Strategic Review Complete**: All P2-P4 researched, all tasks green

---

## Now

Strategic research complete. Six deep-dive documents cover every phase. Key insight: Claude's session logs are ground truth - no complex NLP needed. Start with Quick Wins to prove concept in 4.5 hours.

## Quick Wins (Do First)

| # | Win | Effort | Impact |
|---|-----|--------|--------|
| QW-1 | Extract session_id from hooks | 30 min | Enables all correlation |
| QW-2 | Log predictions to Redis | 1 hr | Hit rate becomes measurable |
| QW-3 | Compare predictions to actual reads | 2 hr | Proves accuracy |
| QW-4 | Show hit rate in `aoa health` | 1 hr | User sees value immediately |

**Total**: 4.5 hours to prove predictive prefetch works.

## Active

| # | Task | Solution Pattern | C | R |
|---|------|------------------|---|---|
| QW-1 | Extract session_id from hooks | Parse stdin JSON in intent-capture.py | Green | Done |

## Blocked

- None

## Next (After Quick Wins)

1. **P2-001**: Confidence calculation (0.0-1.0 per file)
2. **P2-004**: `/predict` endpoint (files + confidence)
3. **P2-005**: Snippet prefetch (first N lines)
4. **P2-007**: UserPromptSubmit hook integration

## Key Files

```
src/hooks/intent-capture.py  # Add session_id extraction (QW-1)
src/ranking/scorer.py        # Prediction logging (QW-2, QW-3)
src/index/indexer.py         # /rank exists, needs /predict
gateway.py                   # Health endpoint (QW-4)
```

## Strategic Documents (All Complete)

| Document | Focus |
|----------|-------|
| strategic-board-refresh.md | Enhanced roadmap - session logs eliminate 60% complexity |
| strategic-session-reward.md | Claude logs provide complete reward signal |
| strategic-log-correlation.md | session_id + tool_use_id enable perfect correlation |
| strategic-hidden-insights.md | Token economics prove ROI, 15 use cases found |
| strategic-overall-review.md | System assessment, cold start challenges |
| p2-001-confidence-research.md | Calibrated linear + evidence weighting |

## Test Commands

```bash
# Health check
aoa health

# Record file access (builds scores)
curl -X POST "localhost:8080/rank/record" \
  -H "Content-Type: application/json" \
  -d '{"file": "src/index/indexer.py", "tags": ["python", "api"]}'

# Get ranked files
curl "localhost:8080/rank?limit=10"

# Run benchmarks
cd /home/corey/aOa/.context/benchmarks && python -m pytest -v
```

## Resume Command

```bash
# Read strategic insights first
cat /home/corey/aOa/.context/details/strategic-board-refresh.md

# Then start QW-1: Extract session_id from intent-capture.py
# See: strategic-log-correlation.md for session_id format
```

## Phase Summary

| Phase | Status | Next Step |
|-------|--------|-----------|
| 1 - Redis Scoring | Complete | 6/6 rubrics pass |
| 2 - Prefetch + Correlation | Active | Quick Wins first |
| 3 - Transition Model | Queued | After Phase 2 |
| 4 - Weight Optimization | Queued | After Phase 3 |
