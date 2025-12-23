# GH Analysis - Context Intelligence Implementation Plan

> **Date**: 2025-12-23
> **Source**: GH agent exhaustive analysis

## Summary

Transform aOa from a simple search tool into a predictive prefetch system that achieves 90% accuracy in predicting which files the user will need.

## Current State (Pre-Implementation)

- aOa services running: index, status, redis, proxy
- Intent capture working: 75 intents captured
- PreHook exists but outputs nothing (commented out)
- Redis connected but no scores being written

## 4-Phase Plan

### Phase 1: Redis Scoring Engine (Week 1)

**Goal**: Build the scoring infrastructure.

**Tasks**:
1. Create `/home/corey/aOa/src/ranking/` package
2. Implement `redis_client.py` with sorted set operations
3. Modify `intent-capture.py` to write Redis scores:
   - Recency: timestamp of last access
   - Frequency: count of accesses
   - Tag affinity: per-tag scores
4. Add composite scoring with `ZUNIONSTORE`
5. Add decay mechanism (Lua script for atomic operations)
6. Add `/rank` endpoint to indexer

**Success Criteria**: `/rank` endpoint returns top 10 files for a given context.

### Phase 2: Predictive Prefetch (Week 2)

**Goal**: Make predictions based on scores.

**Tasks**:
1. Implement confidence calculation (normalize to 0.0-1.0)
2. Create `/predict` endpoint
3. Update PreHook (`intent-prefetch.py`) to output predictions
4. Implement context peek (snippet extraction for predicted files)
5. Add `UserPromptSubmit` prediction trigger

**Success Criteria**: PreHook outputs predicted files before each interaction.

### Phase 3: Multi-Query Fusion (Week 3)

**Goal**: Natural language intent to file predictions.

**Tasks**:
1. Create `/context` endpoint (intent description -> ranked files + snippets)
2. Add `aoa context "<description>"` CLI command
3. Implement semantic intent matching (keyword -> tag mapping)
4. Bundle results with confidence scores

**Success Criteria**: `aoa context "fix the auth bug"` returns relevant files.

### Phase 4: Accuracy Tuning (Week 4)

**Goal**: Achieve 90% prediction accuracy.

**Tasks**:
1. Implement prediction logging (what was predicted vs what was used)
2. Calculate hit rate metrics
3. Implement weight tuning algorithm
4. Add `aoa feedback` command for manual feedback
5. Iterate until 90% accuracy achieved

**Success Criteria**: 90% of top-5 predictions are actually used.

## Scoring Formula

```
composite_score = (recency_weight * recency_score) +
                  (frequency_weight * frequency_score) +
                  (tag_weight * tag_affinity_score)
```

Initial weights (to be tuned in Phase 4):
- Recency: 0.4
- Frequency: 0.3
- Tags: 0.3

## Decay Mechanism

Scores decay over time to prevent stale files from dominating.

```lua
-- Lua script for atomic decay
local scores = redis.call('ZRANGE', KEYS[1], 0, -1, 'WITHSCORES')
for i = 1, #scores, 2 do
    local member = scores[i]
    local score = tonumber(scores[i+1])
    local decayed = score * ARGV[1]  -- decay factor, e.g., 0.95
    redis.call('ZADD', KEYS[1], decayed, member)
end
```

## Files to Modify

| File | Changes |
|------|---------|
| `src/ranking/redis_client.py` | NEW - Redis wrapper |
| `src/ranking/scorer.py` | NEW - Composite scoring |
| `src/hooks/intent-capture.py` | Add score writing |
| `src/hooks/intent-prefetch.py` | Implement prediction output |
| `src/index/indexer.py` | Add /rank, /predict, /context endpoints |
| `cli/aoa` | Add `aoa context` command |

## Redis Keys Structure

```
recency:files          # ZSET: file -> timestamp
frequency:files        # ZSET: file -> count
tag:<tagname>          # ZSET: file -> affinity score
composite:files        # ZSET: file -> weighted composite
predictions:<session>  # LIST: prediction log for accuracy tracking
```
