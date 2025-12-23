# aOa Context Intelligence - Work Board

> **Updated**: 2025-12-23 | **Phase**: 2 - Predictive Prefetch
> **Goal**: Transform aOa from search tool to predictive prefetch (90% accuracy)
> **Strategic Review**: See `.context/details/strategic-board-refresh.md`

---

## Confidence Legend

| Indicator | Meaning | Action |
|-----------|---------|--------|
| 🟢 | Confident - clear path, similar to existing code | Proceed freely |
| 🟡 | Uncertain - some unknowns, may need quick research | Try first, then research |
| 🔴 | Lost - significant unknowns, needs research first | Research before starting |

| Research | Agent | When to Use |
|----------|-------|-------------|
| 131 | 1-3-1 Pattern | Problem decomposition, understanding behavior |
| GH | Growth Hacker | Architecture decisions, best practices |
| - | None | Straightforward implementation |

---

## Quick Wins (P0 - Start Here)

Strategic insights identified high-impact, low-effort wins to prove the concept:

| # | Win | Effort | Impact | Reference |
|---|-----|--------|--------|-----------|
| QW-1 | Extract session_id from hooks | 30 min | Enables all correlation | strategic-log-correlation.md |
| QW-2 | Log predictions to Redis | 1 hr | Hit rate becomes measurable | strategic-board-refresh.md |
| QW-3 | Compare predictions to actual reads | 2 hr | Proves accuracy | strategic-session-reward.md |
| QW-4 | Show hit rate in `aoa health` | 1 hr | User sees value immediately | strategic-board-refresh.md |

**Total**: 4.5 hours to prove predictive prefetch works.

---

## Active

| # | Task | Expected Output | Solution Pattern | Status | C | R |
|---|------|-----------------|------------------|--------|---|---|
| P2-001 | Implement confidence calculation | Score 0.0-1.0 per file | Calibrated linear + evidence weighting | Ready | 🟢 | ✓ |

---

## Phase 1 - Redis Scoring Engine ✅ COMPLETE

**Success Criteria**: Files ranked by recency + frequency + tag affinity. `/rank` endpoint returns top 10.
**Result**: 6/6 rubrics pass, average latency 21ms

| # | Task | Expected Output | Solution Pattern | Status |
|---|------|-----------------|------------------|--------|
| P1-001 | Create ranking package | `/src/ranking/__init__.py`, `redis_client.py` | New directory, class wrapping redis-py | ✅ |
| P1-002 | Implement score operations | `zadd()`, `zincrby()`, `zrange()` wrappers | RedisClient class with sorted set methods | ✅ |
| P1-003 | Add recency scoring | Files scored by last-access time | Normalized exponential decay (1hr half-life) | ✅ |
| P1-004 | Add frequency scoring | Files scored by access count | `ZINCRBY frequency:files 1 <file>` | ✅ |
| P1-005 | Add tag affinity scoring | Files scored per tag | `ZADD tag:<tag> <score> <file>` | ✅ |
| P1-006 | Modify intent-capture.py | Write scores on every intent capture | POST to /rank/record on each file | ✅ |
| P1-007 | Implement composite scoring | Combined score from all signals | Weighted sum with normalization | ✅ |
| P1-008 | Add decay mechanism | Old scores fade over time | Exponential decay in scorer.py | ✅ |
| P1-009 | Add /rank endpoint | `GET /rank?tag=<tag>&limit=10` returns ranked files | New route in indexer.py | ✅ |
| P1-010 | Integration test | End-to-end: intent -> score -> rank | Benchmark rubrics (6/6 pass) | ✅ |

---

## Phase 2 - Predictive Prefetch (Week 2)

**Success Criteria**: PreHook outputs predicted files + snippets. Hit rate measurable from day one.
**Research**: See details/p2-001-confidence-research.md, p2-003-prehook-research.md, p2-005-userpromptsubmit-research.md
**Strategic**: See details/strategic-log-correlation.md, strategic-hidden-insights.md

| # | Task | Expected Output | Solution Pattern | Deps | Status | C | R |
|---|------|-----------------|------------------|------|--------|---|---|
| P2-001 | Implement confidence calculation | Score 0.0-1.0 per file | Calibrated linear + evidence weighting | P1-007 | Active | 🟢 | ✓ |
| P2-002 | Extract session linkage | Get session_id, tool_use_id from hooks | Parse stdin JSON in intent-capture.py | - | Queued | 🟢 | ✓ |
| P2-003 | Store predictions with session | Redis keyed by session_id | prediction:{session_id}:{ts} | P2-002 | Queued | 🟢 | ✓ |
| P2-004 | Create /predict endpoint | `GET /predict?tags=X,Y` returns files+confidence | New route using scorer | P2-001 | Queued | 🟢 | - |
| P2-005 | Implement snippet prefetch | First N lines of predicted files | Read + truncate in /predict | P2-004 | Queued | 🟢 | - |
| P2-006 | Hit/miss tracking | Record prediction hits in PostToolUse | Compare prediction to actual Read | P2-003 | Queued | 🟢 | ✓ |
| P2-007 | UserPromptSubmit hook | Predict on prompt submission | JSON additionalContext format | P2-004 | Queued | 🟢 | ✓ |

---

## Phase 3 - Transition Model (Week 3)

**Success Criteria**: Predictions use Claude's learned behavior patterns. Hit@5 > 70%.
**Research**: See details/p3-architecture-research.md, p3-003-semantic-research.md
**Strategic**: See details/strategic-session-reward.md (ground truth approach)

| # | Task | Expected Output | Solution Pattern | Deps | Status | C | R |
|---|------|-----------------|------------------|------|--------|---|---|
| P3-001 | Session log parser | Parse ~/.claude/projects/ JSONL | Extract Read events with timestamps | P2-006 | Queued | 🟢 | ✓ |
| P3-002 | Transition matrix builder | P(file_B \| file_A read) probabilities | Count transitions in Redis | P3-001 | Queued | 🟢 | ✓ |
| P3-003 | Pattern-based keyword extraction | Extract keywords from intent | Reuse INTENT_PATTERNS from hooks | - | Queued | 🟢 | ✓ |
| P3-004 | Create /context endpoint | `POST /context` returns files+snippets | Keywords + transitions + tags | P3-002 | Queued | 🟢 | ✓ |
| P3-005 | Add `aoa context` CLI | `aoa context "fix auth bug"` | CLI wrapper for /context | P3-004 | Queued | 🟢 | - |
| P3-006 | Caching layer | Cache common intents | Redis normalized keyword keys, 1hr TTL | P3-004 | Queued | 🟢 | ✓ |

---

## Phase 4 - Weight Optimization (Week 4)

**Success Criteria**: 90% Hit@5 via data-driven weight tuning. Token savings visible.
**Research**: See details/p4-accuracy-research.md, p4-metrics-research.md
**Strategic**: See details/strategic-hidden-insights.md (token economics)
**Ground Truth**: Uses Claude session logs (~/.claude/projects/) for reward signal

| # | Task | Expected Output | Solution Pattern | Deps | Status | C | R |
|---|------|-----------------|------------------|------|--------|---|---|
| P4-001 | Rolling hit rate calculation | Hit@5 over 24h window | Redis sorted sets, real-time correlation | P2-006 | Queued | 🟢 | ✓ |
| P4-002 | Thompson Sampling tuner | 8 weight configurations | Beta distributions per arm | P4-001 | Queued | 🟢 | ✓ |
| P4-003 | `/metrics` endpoint | Show accuracy + savings | Rolling metrics from Redis | P4-001 | Queued | 🟢 | ✓ |
| P4-004 | Token cost tracking | Prove $ savings from predictions | Extract from session logs | P3-001 | Queued | 🟢 | ✓ |
| P4-005 | `aoa metrics` CLI | View accuracy in terminal | Sparklines + ASCII viz | P4-003 | Queued | 🟢 | ✓ |
| P4-006 | Achieve 90% accuracy | Hit@5 >= 90% | Progressive tuning: 70% -> 80% -> 90% | P4-002 | Queued | 🟢 | ✓ |

---

## Phases Overview

| Phase | Focus | Status | Blocked By | Success Metric |
|-------|-------|--------|------------|----------------|
| 1 | Redis Scoring Engine | ✅ Complete | - | /rank returns ranked files (6/6 rubrics) |
| 2 | Prefetch + Correlation | Ready | - | Predictions + hit rate measurable |
| 3 | Transition Model | Queued | Phase 2 | Hit@5 > 70% from learned patterns |
| 4 | Weight Optimization | Queued | Phase 3 | 90% Hit@5 + token savings visible |

---

## Completed

| # | Task | Output | Completed |
|---|------|--------|-----------|
| P1 | Phase 1 - Redis Scoring Engine | 6/6 rubrics pass, 21ms avg latency | 2025-12-23 |
| R1 | Strategic research - P2/P3/P4 | All phases researched, all tasks green | 2025-12-23 |
| R2 | Strategic overall review | System assessment, gaps identified | 2025-12-23 |
| R3 | Strategic session reward | Claude logs as ground truth | 2025-12-23 |
| R4 | Strategic log correlation | session_id/tool_use_id linkage | 2025-12-23 |
| R5 | Strategic hidden insights | Token economics, 15 use cases | 2025-12-23 |
| R6 | Strategic board refresh | Enhanced roadmap with insights | 2025-12-23 |

---

## Architecture Notes

```
Current:
  intent-capture.py -> POST /intent -> indexer.py -> SQLite

Phase 1 adds:
  intent-capture.py -> POST /intent -> indexer.py -> SQLite
                                                  -> Redis (scores)

Phase 2 adds:
  UserPromptSubmit hook -> Extract session_id, keywords
                        -> GET /predict -> scorer.py -> Redis (tags, recency, frequency)
                        -> Read snippets (first N lines)
                        <- JSON additionalContext to Claude

  PostToolUse hook -> intent-capture.py (with session_id, tool_use_id)
                   -> Check: was file predicted? -> Record hit/miss

Phase 3 adds:
  Session log parser -> ~/.claude/projects/ -> Extract Read patterns
                     -> Build transition matrix (Read A -> usually Read B)
                     -> Store in Redis transitions:{file}

  aoa context "..." -> POST /context -> transitions + tags + keywords
                    <- files + snippets + confidence

Phase 4 adds:
  Rolling metrics -> Compare predictions to actual reads (ground truth)
               -> Thompson Sampling weight tuning
               -> /metrics endpoint shows Hit@5, token savings
```

## Key Dependencies

- Redis: Already running in docker-compose
- redis-py: Need to verify installed
- Lua scripting: For atomic decay operations

---

## Strategic Insights Summary

### Key Research Documents

| Document | Focus | Key Finding |
|----------|-------|-------------|
| strategic-board-refresh.md | Enhanced roadmap | Session logs eliminate 60% of complexity |
| strategic-overall-review.md | System assessment | Cold start is biggest challenge, quick wins identified |
| strategic-session-reward.md | Ground truth approach | Claude logs provide complete reward signal |
| strategic-log-correlation.md | Linkage strategy | session_id + tool_use_id enable perfect correlation |
| strategic-hidden-insights.md | Data mining | Token economics prove ROI, 15 use cases found |

### Confidence Assessment

**🟢 All tasks green** - Complete research coverage across P2-P4

**Phase 2**: Confidence + session linkage + prediction logging
- Researched: p2-001, p2-003, p2-005
- Strategic: log-correlation, hidden-insights

**Phase 3**: Transition model (not NLP)
- Researched: p3-architecture, p3-003-semantic
- Strategic: session-reward (ground truth)

**Phase 4**: Thompson Sampling + token economics
- Researched: p4-accuracy, p4-metrics
- Strategic: hidden-insights (ROI proof)
