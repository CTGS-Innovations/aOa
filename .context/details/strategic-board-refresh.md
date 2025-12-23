# Strategic Board Refresh: Angle of Attack Edition

> **Date**: 2025-12-23
> **Agent**: GH (Growth Hacker)
> **Mission**: Refine roadmap to focus on what matters - stop the "read entire repo" pattern

---

## Executive Summary

The strategic insights reveal a clear path: **Claude's session logs are ground truth**. We don't need complex NLP or self-reported metrics. We have everything we need to build a predictive prefetch system that actually works.

**The Core Insight**:
```
Before: grep -> tree -> find -> read cycles (7+ tool calls, 8,500 tokens, 2+ seconds)
After:  Context query -> instant relevant snippets (1-2 calls, <1,200 tokens, <100ms)
```

**The Angle of Attack**:
1. Extract real session_id and tool_use_id from hooks (confirmed available)
2. Build transition matrix from Claude's own Read patterns
3. Prefetch top files WITH snippets before Claude asks
4. Measure with ground truth (did Claude actually read what we predicted?)

---

## Phase Restructure: What Changed

### Old vs New Phase Structure

| Old | New | Rationale |
|-----|-----|-----------|
| Phase 2: Predictive Prefetch | Phase 2: Prefetch + Correlation | Add prediction logging immediately |
| Phase 3: Multi-Query Fusion (NLP) | Phase 3: Transition Model | Claude logs replace NLP |
| Phase 4: Accuracy Tuning | Phase 4: Weight Optimization | Now has data to tune against |

### What We're Cutting

| Cut | Why | Replacement |
|-----|-----|-------------|
| NLP keyword extraction (P3-003 old) | Over-engineered | Pattern matching from intent-capture.py |
| Semantic matching | Not needed for 90% | Transition probabilities from logs |
| Gradient descent on weights | Premature | Simple Thompson Sampling |
| Complex feedback loops | Self-reported | Ground truth from session logs |

### What We're Adding

| Addition | Why | Impact |
|----------|-----|--------|
| `session_id` extraction | Links aOa to Claude exactly | Enables all correlation |
| `tool_use_id` capture | Precise tool-level linkage | Perfect hit/miss tracking |
| Transition matrix | "Read A -> usually Read B next" | Best prediction signal |
| Token cost tracking | Prove ROI in dollars | User adoption |
| Snippet prefetch | Not just files, exact lines | Dramatic token savings |

---

## Revised Phase Breakdown

### Phase 2: Prefetch + Correlation (Week 2) - CURRENT

**Goal**: Predictions with ground truth measurement from day one.

**Success Criteria**:
- [ ] Predictions logged with real session_id
- [ ] Hit rate measurable (even if low initially)
- [ ] `/predict` responds in <50ms p95
- [ ] Prefetch includes file snippets (first 10 lines)

| # | Task | Description | Status | Confidence |
|---|------|-------------|--------|------------|
| P2-001 | Confidence calculation | Score 0.0-1.0 per file | Ready | Green |
| P2-002 | Extract session linkage | Get `session_id`, `tool_use_id` from hooks | **NEW** | Green |
| P2-003 | Store predictions with ID | Redis keyed by session_id | **NEW** | Green |
| P2-004 | `/predict` endpoint | Returns files + confidence | Ready | Green |
| P2-005 | Snippet prefetch | First N lines of predicted files | Ready | Green |
| P2-006 | Hit/miss tracking | Compare predictions to actual reads | **NEW** | Green |
| P2-007 | UserPromptSubmit hook | Predict on prompt submission | Ready | Green |

**Key Change**: We're adding P2-002, P2-003, P2-006 from Phase 4 - start measuring immediately.

### Phase 3: Transition Model (Week 3) - SIMPLIFIED

**Goal**: Replace NLP with Claude's own behavior patterns.

**Success Criteria**:
- [ ] Transition matrix built from session logs
- [ ] "Read A -> likely need B" predictions work
- [ ] `/context` endpoint returns ranked files + snippets
- [ ] Hit@5 > 70% on historical sessions

| # | Task | Description | Status | Confidence |
|---|------|-------------|--------|------------|
| P3-001 | Session log parser | Parse `~/.claude/projects/` logs | Ready | Green |
| P3-002 | Transition matrix | P(file_B \| file_A was read) | Ready | Green |
| P3-003 | Pattern-based keywords | Reuse INTENT_PATTERNS from hooks | **SIMPLIFIED** | Green |
| P3-004 | `/context` endpoint | Natural language -> ranked files | Ready | Green |
| P3-005 | Background sync | Update transitions every 5 min | Ready | Yellow |

**Key Change**: P3-003 was "NLP semantic matching" (RED). Now it's "reuse existing patterns" (GREEN).

### Phase 4: Weight Optimization (Week 4) - DATA-DRIVEN

**Goal**: Tune weights using actual hit/miss data from Phase 2-3.

**Success Criteria**:
- [ ] Hit@5 >= 90% on training data
- [ ] Hit@5 >= 85% on new sessions
- [ ] Weight changes improve metrics measurably
- [ ] ROI visible in token savings

| # | Task | Description | Status | Confidence |
|---|------|-------------|--------|------------|
| P4-001 | Rolling hit rate | Calculate Hit@5 over 24h window | Ready | Green |
| P4-002 | Thompson Sampling | 8 discrete weight combinations | Ready | Green |
| P4-003 | `/metrics` endpoint | Show accuracy + token savings | Ready | Green |
| P4-004 | Token cost tracking | Prove $ savings from predictions | **NEW** | Green |
| P4-005 | Auto-tune loop | Adjust weights based on hit rate | Ready | Yellow |

**Key Change**: Now we have data to tune against. No more optimizing blind.

---

## Prefetch Flow Design

### Sequence Diagram: UserPromptSubmit -> Context Injection

```
User types prompt
       |
       v
+------------------+
| UserPromptSubmit |  (Claude Code hook)
| Hook fires       |
+------------------+
       |
       | stdin: { prompt, session_id }
       v
+------------------+
| intent-prefetch  |  (aOa hook script)
| .py              |
+------------------+
       |
       | 1. Extract keywords (pattern match)
       | 2. GET /predict?keywords=X,Y&session_id=Z
       v
+------------------+
| /predict         |  (aOa indexer API)
| endpoint         |
+------------------+
       |
       | 3. Query Redis for:
       |    - Tag affinity scores
       |    - Transition probabilities
       |    - Recency/frequency scores
       |
       | 4. Composite score + confidence
       v
+------------------+
| scorer.py        |  (ranking module)
+------------------+
       |
       | 5. Read first N lines of top 5 files
       | 6. Store prediction with prediction_id
       v
+------------------+
| Response:        |
| {                |
|   predictions: [ |
|     {file, conf, |
|      snippet}    |
|   ],             |
|   prediction_id  |
| }                |
+------------------+
       |
       | stdout: JSON additionalContext
       v
+------------------+
| Claude receives  |  (injected into prompt)
| context          |
+------------------+
       |
       | Claude decides what to read
       v
+------------------+
| PostToolUse      |  (Claude Code hook)
| Hook fires       |
+------------------+
       |
       | stdin: { tool_name: "Read", file_path, session_id, tool_use_id }
       v
+------------------+
| intent-capture   |  (aOa hook script)
| .py              |
+------------------+
       |
       | 7. Check: was this file predicted?
       | 8. Record hit or miss
       | 9. Update transition matrix
       v
+------------------+
| Redis            |
| - hits:session_id|
| - transitions:*  |
+------------------+
```

### Timing Budget (<100ms total)

| Step | Target | Method |
|------|--------|--------|
| Hook startup | 10ms | Python already warm |
| Keyword extraction | 5ms | Regex patterns, no NLP |
| /predict request | 20ms | Local HTTP |
| Redis queries | 15ms | Sorted set ZRANGE |
| Snippet read | 30ms | Read first 500 bytes x 5 files |
| Response format | 5ms | JSON serialize |
| **Total** | **85ms** | Under 100ms budget |

### Response Format

```json
{
  "additionalContext": [
    {
      "type": "predicted_context",
      "title": "Likely relevant files",
      "content": "Based on your prompt, you'll likely need:\n\n## scorer.py (92% confidence)\n```python\nclass Scorer:\n    def get_ranked_files(self, tags, limit=10):\n        ...\n```\n\n## redis_client.py (85% confidence)\n```python\nclass RedisClient:\n    def zadd(self, key, score, member):\n        ...\n```"
    }
  ]
}
```

---

## Context Agent First Pattern

### The Vision

Claude should query aOa before reaching for Grep/Glob/Read.

**Before (current)**:
```
User: "Fix the auth bug"
Claude: Grep("auth") -> 15 results -> Read(file1) -> Read(file2) -> ...
        7 tool calls, 8,500 tokens, 2.6s
```

**After (with context agent)**:
```
User: "Fix the auth bug"
Claude: [Receives prefetched context with auth files + snippets]
        Maybe 1-2 targeted reads, 1,200 tokens, 100ms
```

### Implementation Path

1. **Phase 2**: UserPromptSubmit injects "likely files" as additionalContext
2. **Phase 3**: `/context` endpoint for Claude to explicitly query ("aoa context fix auth")
3. **Phase 4**: Claude learns to trust aOa predictions (CLAUDE.md instructions)

### CLAUDE.md Update for Phase 3

```markdown
## Context Agent First

Before using Grep/Glob, ask aOa:

```bash
# For specific code:
aoa context "fix auth bug"
# Returns: ranked files + snippets + confidence

# For navigation:
aoa search "auth login session"
# Returns: file:line matches
```

**Why?** aOa knows your patterns. It predicts what you'll need based on:
- Your recent file accesses
- What files are usually read together
- Keyword-to-file learned mappings

**Trust threshold**: If aOa returns files with >80% confidence, read those first.
```

---

## Quick Wins (P0 - Prove the Concept)

### The Smallest Increment That Proves Value

**Goal**: Show that predictions work before building the full system.

| Win | Effort | Proves | Do When |
|-----|--------|--------|---------|
| Extract `session_id` from hooks | 30 min | Linkage works | Now |
| Log predictions to Redis | 1 hr | Can track | Phase 2 start |
| Compare to actual reads | 2 hr | Hit rate measurable | Phase 2 day 1 |
| Show hit rate in `aoa health` | 1 hr | User sees value | Phase 2 day 2 |

### Win #1: Session ID Extraction (Do Now)

```python
# intent-capture.py - CURRENT
SESSION_ID = os.environ.get("AOA_SESSION_ID", datetime.now().strftime("%Y%m%d"))

# intent-capture.py - NEW
def get_session_id(data: dict) -> str:
    """Extract real session_id from Claude hook input."""
    return data.get('session_id', datetime.now().strftime("%Y%m%d"))

# Usage:
data = json.loads(sys.stdin.read())
session_id = get_session_id(data)
tool_use_id = data.get('tool_use_id')  # For exact correlation
```

This takes 30 minutes and enables everything else.

### Win #2: Prediction Logging (Phase 2 Day 1)

```python
# scorer.py
def log_prediction(self, session_id: str, predictions: list[dict]) -> str:
    """Log prediction for hit rate calculation."""
    prediction_id = f"{session_id}:{int(time.time() * 1000)}"
    self.redis.hset(f"prediction:{prediction_id}", mapping={
        'files': json.dumps([p['file'] for p in predictions]),
        'timestamp_ms': int(time.time() * 1000),
        'confidences': json.dumps([p['confidence'] for p in predictions])
    })
    self.redis.expire(f"prediction:{prediction_id}", 3600)  # 1hr TTL
    return prediction_id
```

### Win #3: Hit Rate Calculation (Phase 2 Day 1)

```python
# scorer.py
def calculate_hit_rate(self, session_id: str, window_minutes: int = 60) -> dict:
    """Calculate Hit@5 from predictions vs actual reads."""
    # Get all predictions in window
    predictions = self._get_recent_predictions(session_id, window_minutes)

    # Get all reads in window (from intent records)
    reads = self._get_recent_reads(session_id, window_minutes)

    hits = 0
    for pred in predictions:
        top5 = pred['files'][:5]
        # Find reads that happened after this prediction
        future_reads = [r for r in reads if r['timestamp_ms'] > pred['timestamp_ms']]
        if any(r['file'] in top5 for r in future_reads):
            hits += 1

    return {
        'hit_at_5': hits / len(predictions) if predictions else 0.0,
        'predictions_made': len(predictions),
        'reads_observed': len(reads)
    }
```

### Win #4: Health Display

```
$ aoa health

aOa Health Check
================
Index:      Running (1,247 symbols)
Redis:      Running (scoring active)
Intents:    142 captured today
Predictions: 23 made, 18 hits (78% Hit@5)  <-- NEW
```

---

## Success Metrics That Matter

### Primary Metrics (Phase 2-4)

| Metric | Target | How to Measure | Why It Matters |
|--------|--------|----------------|----------------|
| **Hit@5** | >90% | predicted file in top 5 was read | Core accuracy |
| **Latency p95** | <100ms | /predict response time | User experience |
| **Token Savings** | >50% | tokens with vs without prefetch | ROI proof |
| **Tool Calls Reduced** | >70% | grep+read cycles avoided | Efficiency |

### Secondary Metrics (Nice to Have)

| Metric | Target | Notes |
|--------|--------|-------|
| Precision@5 | >40% | How many of top 5 were actually used |
| Cold Start Hit@5 | >60% | First session in new codebase |
| Cache Hit Rate | >80% | Are prefetched files in Claude's cache? |

### Anti-Metrics (Don't Optimize For)

| Anti-Metric | Why Avoid |
|-------------|-----------|
| Total predictions made | More isn't better |
| Confidence average | Can be gamed |
| Session count | Vanity metric |

---

## Strategic Insights Applied

### From strategic-session-reward.md

**Insight**: Claude session logs are ground truth for predictions.

**Application**:
- Phase 3 uses transition matrix from actual Read patterns
- No self-reported metrics - we verify against real tool calls
- Session log parser becomes core infrastructure

### From strategic-log-correlation.md

**Insight**: `session_id` and `tool_use_id` are available in hook stdin.

**Application**:
- P2-002 extracts these fields (30 min task)
- Enables perfect prediction-to-read correlation
- No fuzzy timestamp matching needed

### From strategic-hidden-insights.md

**Insight**: Token economics are hidden gold.

**Application**:
- P4-004 tracks token cost per prediction
- Can show "aOa saved $X.XX this session"
- Proves ROI for adoption

### From strategic-overall-review.md

**Insight**: Cold start is the biggest challenge.

**Application**:
- Fall back to file mtime when no Redis data
- Pre-seed common patterns (README, config, entry points)
- First session is learning mode

---

## What To Cut From Current Plan

### Remove

| Item | Why Cut |
|------|---------|
| NLP semantic matching | Over-engineered; patterns work fine |
| Complex gradient descent | Thompson Sampling is sufficient |
| 5-minute evaluation delay | Real-time correlation is better |
| Self-reported predictions | Ground truth from logs |

### Simplify

| Item | Before | After |
|------|--------|-------|
| Keyword extraction | spaCy/NLP pipeline | Regex patterns (existing) |
| Weight tuning | ML optimization | 8-arm Thompson Sampling |
| Session tracking | Date-based fallback | Real Claude session_id |
| Prediction evaluation | Delayed batch | Real-time on Read capture |

### Defer

| Item | Why Defer | When Revisit |
|------|-----------|--------------|
| ML prompt-to-file model | Need more data | After 1000+ predictions |
| Cross-project learning | Scope creep | v2.0 |
| Branch-specific patterns | Nice to have | v1.5 |
| Model switching intelligence | Complex | v2.0 |

---

## Updated BOARD.md Structure

### Recommended Changes

1. **Merge P4-001 into Phase 2** - Start tracking predictions immediately
2. **Simplify P3-003** - Pattern matching, not NLP
3. **Add session linkage tasks** - P2-002, P2-003
4. **Add token economics** - P4-004

### New Task Dependencies

```
P2-002 (session linkage) <- P2-003 (prediction storage) <- P2-006 (hit tracking)
                                                        <- P3-002 (transitions)

P2-005 (snippets) <- P3-004 (/context endpoint)

P2-006 (hit tracking) <- P4-001 (rolling hit rate) <- P4-002 (Thompson Sampling)
```

---

## Implementation Priority Order

### This Week

1. **P2-002**: Extract `session_id` and `tool_use_id` from hook stdin
2. **P2-003**: Store predictions in Redis with session key
3. **P2-001**: Confidence calculation (already researched)
4. **P2-004**: `/predict` endpoint

### Next Week

5. **P2-005**: Snippet prefetch (first N lines)
6. **P2-006**: Hit/miss tracking on Read capture
7. **P2-007**: UserPromptSubmit hook integration

### Week 3

8. **P3-001**: Session log parser
9. **P3-002**: Transition matrix builder
10. **P3-004**: `/context` endpoint

### Week 4

11. **P4-001**: Rolling hit rate calculation
12. **P4-002**: Thompson Sampling weight tuning
13. **P4-003**: `/metrics` endpoint
14. **P4-004**: Token savings tracking

---

## Risk Mitigation

### Risk: Session ID Not Available

**Mitigation**: Fall back to timestamp correlation within 5s window.

```python
def get_session_id(data: dict) -> str:
    # Primary: Claude's session_id
    if 'session_id' in data:
        return data['session_id']
    # Fallback: date-based (current behavior)
    return datetime.now().strftime("%Y%m%d")
```

### Risk: Predictions Too Slow

**Mitigation**: Strict timeout, return empty on slow.

```python
@app.route('/predict')
def predict():
    try:
        with timeout(50):  # 50ms hard limit
            return jsonify(scorer.get_predictions(...))
    except TimeoutError:
        return jsonify({'predictions': [], 'reason': 'timeout'})
```

### Risk: Cold Start Accuracy

**Mitigation**: Pre-seed common patterns.

```python
COLD_START_FILES = [
    'README.md',
    'package.json',
    'setup.py',
    'Makefile',
    'docker-compose.yml',
    '.context/BOARD.md',
    '.context/CURRENT.md'
]

def get_predictions_with_fallback(keywords, session_id):
    predictions = scorer.get_predictions(keywords, session_id)
    if not predictions:
        return [{'file': f, 'confidence': 0.3} for f in COLD_START_FILES if exists(f)]
    return predictions
```

---

## Summary

**The angle of attack is clear**:

1. **Extract session linkage** - Use Claude's own session_id and tool_use_id
2. **Build transition matrix** - "Read A -> usually need B" from Claude's logs
3. **Prefetch with snippets** - Not just files, exact code chunks
4. **Measure with ground truth** - Did Claude actually read what we predicted?

**What we're NOT doing**:
- Complex NLP (patterns work fine)
- Self-reported metrics (ground truth from logs)
- Premature ML (simple weighting first)
- Boiling the ocean (surgical, incremental)

**The result**:
- Tool calls reduced by 70%+
- Token savings of 50%+
- Latency <100ms
- 90% Hit@5 accuracy

This is achievable with the strategic insights we've gathered. The hard research is done. Now we execute.
