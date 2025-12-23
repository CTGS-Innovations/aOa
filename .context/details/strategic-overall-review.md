# aOa Strategic Review: Predictive Prefetch System

> **Date**: 2025-12-23
> **Agent**: GH (Growth Hacker)
> **Scope**: Full architecture and roadmap assessment

---

## Executive Summary

aOa's predictive prefetch system is well-architected for its scope. The 4-phase approach is sound, but Phase 3 (semantic matching) carries the highest risk and should be simplified. The biggest gap is the **feedback loop** - without measuring what predictions were actually useful, the 90% accuracy target is aspirational rather than actionable.

**Key findings:**
1. Phase order is correct, but Phase 3 scope should be reduced
2. Missing: explicit prediction/usage correlation tracking
3. 90% accuracy is achievable with simpler signals than semantic NLP
4. Quick wins exist in Phase 2 that would significantly improve UX

---

## Phase Strategy Assessment

### Current Plan

| Phase | Focus | Status | GH Assessment |
|-------|-------|--------|---------------|
| 1 | Redis Scoring Engine | Complete | KEEP - solid foundation |
| 2 | Predictive Prefetch | Ready | KEEP - correct next step |
| 3 | Multi-Query Fusion | Queued | MODIFY - reduce scope |
| 4 | Accuracy Tuning | Queued | REORDER - move earlier |

### Recommended Changes

#### Phase 3: Reduce Scope (HIGH PRIORITY)

**Current plan**: Semantic matching, NLP keyword extraction, `/context` endpoint

**Problem**: P3-003 (semantic matching) is marked RED for good reason. NLP-based intent matching is:
- Complex to implement correctly
- Hard to debug when it fails
- Likely to add latency
- Unnecessary for 90% accuracy

**Recommendation**: Replace semantic matching with **pattern-based intent inference**:
- Use existing tag patterns from `intent-capture.py` (already working)
- Extract keywords from user prompt using simple regex (like P2-005 already does)
- Match against existing tag affinity scores (already in Redis)

This turns a RED task into a GREEN task with minimal loss of functionality.

#### Phase 4: Start Feedback Loop Earlier

**Current plan**: Add feedback loop after everything else is built

**Problem**: Without knowing which predictions are actually used, you're optimizing blind. The research shows:
> "Utilization matters: which pieces of context actually get used? If your system pulls seven different data sources but the AI only references two, you're wasting tokens."
> -- [Qodo Contextual Retrieval](https://www.qodo.ai/blog/contextual-retrieval/)

**Recommendation**: Move P4-001 (prediction logging) into Phase 2:
- Log every prediction made
- Log which files Claude actually reads (already captured by `intent-capture.py`)
- Correlation is trivial: prediction -> did a Read happen for that file?

This gives you data to tune against before you have all features built.

### Proposed Phase Order

| Phase | Focus | Key Change |
|-------|-------|------------|
| 2 | Predictive Prefetch + Logging | Add P4-001 here |
| 2.5 | Accuracy Baseline | Measure hit rate before Phase 3 |
| 3 | Pattern-Based Context | Remove NLP, use existing tag system |
| 4 | Weight Tuning | Now has data to tune against |

---

## Gap Analysis

### Missing Components

| Gap | Impact | Effort | Priority |
|-----|--------|--------|----------|
| **Prediction-to-usage correlation** | Can't measure accuracy | Low | CRITICAL |
| **Session boundary tracking** | Predictions leak across sessions | Low | HIGH |
| **Negative signal tracking** | Only tracks what's used, not what's ignored | Medium | MEDIUM |
| **Cross-file dependency boost** | If A is predicted, related files B/C not boosted | Medium | LOW |

#### 1. Prediction-to-Usage Correlation (CRITICAL)

**Problem**: You predict files via `/predict`, Claude reads files, but you never link them.

**Solution**: Add a prediction ID system:
```python
# When predicting:
prediction_id = f"{session_id}:{timestamp}"
predictions = scorer.get_ranked_files(...)
store_prediction(prediction_id, predictions)  # Redis with 1hr TTL

# When intent-capture sees a Read:
recent_predictions = get_recent_predictions(session_id)
if read_file in recent_predictions:
    record_hit(prediction_id, read_file)
else:
    record_miss(prediction_id, read_file)
```

This is the foundation for all accuracy measurement.

#### 2. Session Boundary Tracking (HIGH)

**Problem**: Predictions from one prompt might influence scoring for another.

**Current state**: `SESSION_ID` defaults to date (`YYYYMMDD`), so all prompts in a day share a session.

**Solution**:
- Use Claude Code's actual session ID (available in hook input as `session_id`)
- Track prediction timestamps to decay stale predictions
- Clear prediction cache on session end

#### 3. Negative Signal Tracking (MEDIUM)

**Problem**: A file that's predicted but not used is a signal, but you only increment scores.

**Current behavior**: Only positive signals (file was accessed) are recorded.

**Solution**: Implement soft penalties:
```python
# After a prediction is made but file not used within N minutes:
def decay_unused_prediction(file_path, tags):
    for tag in tags:
        scorer.redis.zincrby(f"tag:{tag}", -0.1, file_path)
```

This prevents files from staying "sticky" when they're no longer relevant.

#### 4. Cross-File Dependency Boost (LOW)

**Problem**: If `scorer.py` is predicted, related files (`redis_client.py`, `indexer.py`) aren't boosted.

**Current state**: Dependency graph exists in `CodebaseIndex` but isn't used for prediction.

**Solution for Phase 3+**:
```python
# After getting base predictions:
for file in predictions:
    deps = index.deps_incoming.get(file, [])
    for dep in deps[:3]:  # Limit to top 3
        boost_score(dep, 0.5 * file_score)
```

---

## Risk Assessment

### Risks to 90% Accuracy

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Cold start** | HIGH | HIGH | Fallback to recency-only for new sessions |
| **Session context drift** | MEDIUM | HIGH | Bound predictions to prompt, not session |
| **Over-reliance on frequency** | MEDIUM | MEDIUM | Cap frequency contribution at 30% |
| **Stale predictions** | MEDIUM | MEDIUM | TTL on prediction cache (5 min) |
| **Edge case: new file creation** | LOW | LOW | Detect Write tool, auto-add to predictions |

### Cold Start is the Biggest Challenge

From research:
> "65% of developers using AI say the assistant 'misses relevant context.' Among those who feel AI degrades quality, 44% blame missing context."
> -- [Qodo State of AI Code Quality](https://www.qodo.ai/reports/state-of-ai-code-quality/)

**Why this matters for aOa**: First few prompts in a new codebase have no scoring data.

**Mitigation strategy**:
1. **Immediate**: Fall back to file recency (mtime) when no Redis data exists
2. **Short-term**: Pre-seed common patterns (README, main entry points, config files)
3. **Medium-term**: Use file structure analysis (entry points, recently modified)

---

## Competitive Comparison

### How Cursor Does It

From [Cursor Codebase Indexing Docs](https://cursor.com/docs/context/codebase-indexing):

| Aspect | Cursor | aOa | Delta |
|--------|--------|-----|-------|
| **Indexing** | Semantic chunking + embeddings | Token-based inverted index | Cursor uses LLM embeddings |
| **Storage** | Turbopuffer (vector DB) | Redis (sorted sets) | Different but both work |
| **Query** | Nearest-neighbor semantic search | Weighted recency/frequency/tag | aOa is simpler, faster |
| **Context injection** | Auto-retrieves into prompt | Hook-based additionalContext | Similar outcome |
| **Caching** | Merkle tree delta sync | None yet | Gap to close |

**Key insight from Cursor**: They use tree-sitter for intelligent chunking at logical boundaries (functions, classes). aOa could benefit from language-aware chunking in Phase 3.

### How GitHub Copilot Does It

From [GitHub Copilot Context](https://github.com/orgs/community/discussions/51323):

| Aspect | Copilot | aOa | Delta |
|--------|---------|-----|-------|
| **Context** | Open tabs + current file | All tool interactions | aOa has more signal |
| **Prediction** | Next-token probability | Access pattern scoring | Both valid |
| **Learning** | Global model | Per-project scoring | aOa is project-specific |
| **Feedback** | Thumbs up/down | None yet | Gap to close |

**Key insight from Copilot**: They found that "neighboring files" (open tabs) are the strongest signal. aOa's recency scoring approximates this.

### aOa's Unique Advantages

1. **Tool-level granularity**: You know exactly what Claude reads, edits, searches
2. **Tag affinity**: Can predict by work category (#testing, #api, etc.)
3. **Real-time scoring**: Updates as Claude works, not just at index time
4. **Lightweight**: No external embedding API needed

---

## Quick Wins

### High Impact, Low Effort

| # | Win | Effort | Impact | When |
|---|-----|--------|--------|------|
| 1 | Add prediction logging to P2-001 | 2 hrs | HIGH | Phase 2 |
| 2 | Use Claude's session_id instead of date | 30 min | MEDIUM | Phase 2 |
| 3 | Add file snippet preview (first 5 lines) | 1 hr | MEDIUM | Phase 2 |
| 4 | Pre-seed README/config patterns | 1 hr | MEDIUM | Phase 2 |
| 5 | Add `/metrics` endpoint for debugging | 2 hrs | HIGH | Phase 2 |

### Win #1: Prediction Logging (Do This First)

Add to `scorer.py`:
```python
def log_prediction(self, session_id: str, predictions: list, source: str = "predict"):
    """Log prediction for later accuracy analysis."""
    key = f"aoa:prediction:{session_id}:{int(time.time())}"
    self.redis.client.hset(key, mapping={
        'files': json.dumps([p['file'] for p in predictions]),
        'source': source,
        'timestamp': int(time.time())
    })
    self.redis.client.expire(key, 3600)  # 1 hour TTL
```

This takes 2 hours and unlocks all accuracy measurement.

### Win #3: File Snippet Preview

The research shows that context preview helps:
> "The LLM now has the necessary context from your codebase to provide a more informed and relevant response."
> -- [Cursor Docs](https://docs.cursor.com/context/codebase-indexing)

Add to `/predict` response:
```python
# After getting predictions:
for p in predictions:
    try:
        with open(p['file']) as f:
            p['preview'] = f.read(500)  # First 500 chars
    except:
        p['preview'] = None
```

### Win #5: Metrics Endpoint

Add `/metrics` for debugging and tuning:
```python
@app.route('/metrics')
def metrics():
    return jsonify({
        'predictions_made': redis.zcard('aoa:prediction:*'),
        'predictions_hit': redis.zcard('aoa:hits:*'),
        'hit_rate': calculate_hit_rate(),
        'top_predicted_files': scorer.get_top_files_by_frequency(10),
        'weights': scorer.get_weights(),
        'last_updated': scorer.get_stats()
    })
```

---

## Architectural Anti-Patterns to Avoid

### 1. Over-Engineering Semantic Matching (P3-003)

**Anti-pattern**: Building NLP pipeline for keyword extraction

**Why it's wrong**: You already have working tag patterns in `intent-capture.py`. The 15 pattern regexes cover most cases.

**Do this instead**: Use the same patterns for prediction:
```python
# Reuse INTENT_PATTERNS from intent-capture.py
def extract_tags_from_prompt(prompt: str) -> list:
    tags = []
    for pattern, pattern_tags in INTENT_PATTERNS:
        if re.search(pattern, prompt, re.IGNORECASE):
            tags.extend(pattern_tags)
    return tags
```

### 2. Premature Weight Optimization (P4-003)

**Anti-pattern**: Gradient descent on weights before you have hit/miss data

**Why it's wrong**: Without baseline metrics, you're optimizing noise.

**Do this instead**:
1. Ship with default weights (0.4/0.3/0.3)
2. Collect 1000+ predictions with hit/miss data
3. Then run simple grid search over weight combinations

### 3. Blocking on Predictions

**Anti-pattern**: Making Claude wait for `/predict` before responding

**Why it's wrong**: Adds latency, degrades UX

**Do this instead**: Keep predictions async:
- UserPromptSubmit hook has 2s timeout
- If prediction takes >100ms, return empty
- Prefetch in background for next prompt

### 4. Global Scoring Without Session Isolation

**Anti-pattern**: Predictions from session A affect scores for session B

**Why it's wrong**: Work context varies between sessions

**Current state**: This is happening now (date-based session ID)

**Fix**: Proper session isolation with Claude's session_id

---

## Recommendations Summary

### Must Do (Phase 2)

1. **Add prediction logging** - Foundation for all accuracy work
2. **Use proper session_id** - Stop cross-session contamination
3. **Add `/metrics` endpoint** - Visibility into prediction quality

### Should Do (Phase 2-3)

4. **Simplify P3-003** - Use pattern matching, not NLP
5. **Add prediction TTL** - 5 min expiry on prediction cache
6. **Add file preview** - First N lines in prediction response

### Could Do (Phase 4+)

7. **Implement negative signals** - Decay unused predictions
8. **Add dependency boosting** - Related files get score bump
9. **Cross-project learning** - Share patterns across projects

### Defer

10. **Semantic embeddings** - Not needed for 90% accuracy
11. **ML weight optimization** - Simple grid search is sufficient
12. **Real-time streaming** - Current hook model is good enough

---

## Validation Checklist

Before declaring Phase 2 complete, verify:

- [ ] Predictions are logged with session ID
- [ ] Hit rate is measurable (even if low initially)
- [ ] `/predict` responds in <50ms p95
- [ ] Confidence scores correlate with actual hits
- [ ] Cold start has sensible fallback

Before declaring Phase 4 complete, verify:

- [ ] Hit rate >= 90% on training data
- [ ] Hit rate >= 85% on new sessions (generalization)
- [ ] Weight changes improve metrics (not just noise)
- [ ] User can see prediction quality via `/metrics`

---

## Sources

- [Cursor Codebase Indexing Docs](https://cursor.com/docs/context/codebase-indexing)
- [How Cursor Indexes Codebases Fast](https://read.engineerscodex.com/p/how-cursor-indexes-codebases-fast)
- [GitHub Copilot Context Management](https://github.com/orgs/community/discussions/51323)
- [Sourcegraph: Lessons from Building AI Coding Assistants](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation)
- [Qodo: Contextual Retrieval](https://www.qodo.ai/blog/contextual-retrieval/)
- [Qodo: State of AI Code Quality](https://www.qodo.ai/reports/state-of-ai-code-quality/)
- [orq.ai: RAG Evaluation Best Practices](https://orq.ai/blog/rag-evaluation)
- [Kubiya: Context Engineering Best Practices](https://www.kubiya.ai/blog/context-engineering-best-practices)
- [Nature: Discovering RL Algorithms](https://www.nature.com/articles/s41586-025-09761-x)
- [MDPI: Multi-Task Dynamic Weight Optimization](https://www.mdpi.com/2076-3417/15/5/2473)

---

## Appendix: Confidence Calculation Review

The proposed confidence formula in `p2-001-confidence-research.md` is solid:

```python
confidence = (composite / 100) * (0.7 * evidence + 0.3 * stability)
```

**Validation**: This aligns with Microsoft's guidance:
> "Scores should be calibrated - A 0.8 confidence should mean ~80% accuracy"

**Recommendation**: Ship this formula, then calibrate in Phase 4 once you have hit/miss data to validate against.

The evidence factor (log scale of access count) is particularly important - it prevents over-confidence on sparse data, which is the #1 cold start issue.
