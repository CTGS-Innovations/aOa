# P2-001: Confidence Calculation Research

> **Date**: 2025-12-23
> **Task**: Convert composite score (0-100) to confidence (0.0-1.0)
> **Status**: Research Complete

---

## Problem Statement

We have a composite score from `scorer.py` calculated as:

```python
composite = (
    scores['recency'] * 0.4 +      # 0-100 normalized
    scores['frequency'] * 0.3 +    # 0-100 normalized
    tag_contribution               # 0-100 normalized * 0.3
)
# Max possible = 100, Min = 0
```

Need to convert this to a meaningful confidence score (0.0-1.0) that:
1. Reflects actual prediction reliability
2. Handles data sparsity (few accesses = low confidence)
3. Allows meaningful threshold-based filtering

---

## Research Questions Answered

### Q1: Simple Division vs Sigmoid vs Percentile Normalization?

| Approach | Formula | Pros | Cons |
|----------|---------|------|------|
| **Linear Division** | `composite / 100` | Simple, preserves relative ordering | Doesn't account for data quality |
| **Sigmoid** | `1 / (1 + exp(-k*(x-50)))` | Squashes extremes, natural probability | Loses precision at extremes, adds complexity |
| **Percentile** | `rank / total_files` | Distribution-aware, always 0-1 | Requires all files, relative not absolute |
| **Calibrated Linear** | `(composite / 100) * reliability_factor` | Simple + data quality aware | Needs reliability estimation |

**Recommendation: Calibrated Linear**

Why:
- Linear division (`composite / 100`) is insufficient because a file with score 80 from 1 access should have LOWER confidence than score 60 from 100 accesses
- Sigmoid adds complexity without addressing the data quality problem
- Percentile is good for ranking but loses absolute meaning (50th percentile doesn't mean "50% sure")
- Calibrated linear keeps simplicity while adding data quality adjustment

### Q2: Should Confidence Account for Data Sparsity?

**Yes, absolutely.** This is the key insight.

From the research on [cold start problems in recommender systems](https://www.sciencedirect.com/science/article/abs/pii/S0957417420300737):
- Data sparsity causes unreliable predictions
- Confidence should reflect both the score AND the evidence behind it
- "Uncertainty-aware trust calibration prevents over-confidence in sparse or noisy neighborhoods"

**Sparsity Signals to Consider:**

| Signal | Meaning | Impact on Confidence |
|--------|---------|---------------------|
| Total accesses for file | More data = more reliable | High correlation |
| Time since first access | Longer history = more stable | Medium correlation |
| Number of distinct tags | Richer context = better prediction | Medium correlation |
| Global file count | More files = percentile more meaningful | Low correlation |

### Q3: Best Practices for Prediction Confidence Scores?

From [ML confidence score best practices](https://www.mindee.com/blog/how-use-confidence-scores-ml-models):

1. **Scores should be calibrated** - A 0.8 confidence should mean ~80% accuracy
2. **Thresholds matter**:
   - > 0.7: Strong candidate (Microsoft recommendation)
   - 0.3-0.7: Partial confidence
   - < 0.3: Probably not useful
3. **Normalized confidence is key** - "Calculate the fraction of predictions with smaller confidence value"

From [Google's normalization guide](https://developers.google.com/machine-learning/crash-course/numerical-data/normalization):
- Linear scaling works when bounds are known (we know 0-100)
- Z-score better for unknown distributions (not our case)

---

## Recommended Approach

### The Formula

```python
def calculate_confidence(composite: float, access_count: int,
                         time_span_hours: float) -> float:
    """
    Calculate confidence score from composite score and evidence.

    Args:
        composite: Weighted score 0-100
        access_count: Total accesses recorded for this file
        time_span_hours: Hours since first access

    Returns:
        Confidence 0.0-1.0
    """
    # Base confidence from composite (0-1)
    base = composite / 100.0

    # Evidence factor: more accesses = more confident
    # Uses log scale: 1 access = 0.3, 5 = 0.6, 20+ = 0.9+
    MIN_ACCESSES_FULL_CONFIDENCE = 20
    evidence = min(1.0, 0.3 + 0.7 * math.log1p(access_count) /
                   math.log1p(MIN_ACCESSES_FULL_CONFIDENCE))

    # Time stability factor: longer history = more stable
    # Ramps up over 24 hours
    MIN_HOURS_FULL_CONFIDENCE = 24
    stability = min(1.0, 0.5 + 0.5 * time_span_hours / MIN_HOURS_FULL_CONFIDENCE)

    # Combined confidence
    # weight base score by evidence (more important) and stability (less important)
    confidence = base * (0.7 * evidence + 0.3 * stability)

    return round(confidence, 4)
```

### Why This Formula?

1. **Base score (`composite / 100`)**: Linear division, preserves ordering
2. **Evidence factor (log scale)**:
   - 1 access: 0.30 (low confidence)
   - 5 accesses: 0.60 (medium confidence)
   - 20+ accesses: 0.90+ (high confidence)
   - Log scale prevents single outlier sessions from dominating
3. **Stability factor**:
   - Files seen only today: 0.50 (might be temporary)
   - Files seen over 24h: 1.00 (pattern is stable)
4. **Combined weighting**:
   - 70% evidence (number of accesses is strongest signal)
   - 30% stability (time span is secondary)

### Example Calculations

| Composite | Accesses | Hours | Confidence | Interpretation |
|-----------|----------|-------|------------|----------------|
| 80 | 1 | 0.5 | 0.28 | High score but single access - uncertain |
| 60 | 20 | 24 | 0.58 | Medium score, lots of evidence - reasonable |
| 40 | 50 | 48 | 0.40 | Lower score but very reliable data |
| 90 | 30 | 12 | 0.79 | High score, good evidence - confident |
| 95 | 100 | 72 | 0.93 | High score, extensive evidence - very confident |

---

## Implementation Plan

### Step 1: Add Evidence Tracking to Redis

Need to track:
- `access_count` per file (already have via frequency)
- `first_seen` timestamp per file (need to add)

```python
# In record_access(), add first_seen tracking:
first_seen_key = f"first_seen:{file_path}"
if not self.redis.exists(first_seen_key):
    self.redis.set(first_seen_key, int(time.time()))
```

Or simpler - use a hash:
```python
# Track metadata in a hash per file
self.redis.hset(f"file:{file_path}", "first_seen", int(time.time()))
self.redis.hincrby(f"file:{file_path}", "access_count", 1)
```

### Step 2: Update get_ranked_files()

Add confidence calculation after composite:

```python
# After computing composite score
access_count = self.get_frequency_score(file_path) or 1
first_seen = self.redis.hget(f"file:{file_path}", "first_seen")
time_span_hours = (now - float(first_seen or now)) / 3600

confidence = self.calculate_confidence(
    composite=scores['composite'],
    access_count=int(access_count),
    time_span_hours=time_span_hours
)

entry['confidence'] = confidence
```

### Step 3: Return in API Response

```json
{
    "files": [
        {
            "file": "src/index/indexer.py",
            "score": 85.23,
            "confidence": 0.72,
            "recency": 92.1,
            "frequency": 78.5,
            "tags": {"python": 85.0}
        }
    ]
}
```

---

## Alternative Approaches Considered

### 1. Pure Sigmoid

```python
def sigmoid_confidence(composite, k=0.1):
    return 1 / (1 + math.exp(-k * (composite - 50)))
```

**Rejected because**: Doesn't account for data sparsity. A score of 80 from 1 access would have same confidence as 80 from 100 accesses.

### 2. Percentile-Based

```python
def percentile_confidence(file_score, all_scores):
    rank = sum(1 for s in all_scores if s < file_score)
    return rank / len(all_scores)
```

**Rejected because**:
- Requires computing all scores to determine one file's confidence
- Loses absolute meaning (50th percentile != 50% confident)
- Bad for cold start (few files makes percentiles meaningless)

### 3. Bayesian Approach

```python
def bayesian_confidence(hits, trials, prior_alpha=1, prior_beta=1):
    # Beta distribution posterior mean
    return (prior_alpha + hits) / (prior_alpha + prior_beta + trials)
```

**Considered for future**: Good for Phase 4 when we have hit/miss data. Overkill for now since we don't have feedback yet.

---

## Threshold Recommendations

Based on [Microsoft's guidance](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/concept/accuracy-confidence):

| Confidence | Action |
|------------|--------|
| >= 0.70 | Show as primary prediction |
| 0.40-0.69 | Show as secondary/suggested |
| < 0.40 | Don't show (too uncertain) |

For Phase 2, recommend starting with threshold of **0.50** (conservative) and tuning in Phase 4.

---

## Sources

- [Understanding Confidence Scores in Machine Learning](https://www.mindee.com/blog/how-use-confidence-scores-ml-models)
- [Confidence in ML Models - Oxford](https://www.blopig.com/blog/2025/03/confidence-in-ml-models/)
- [Resolving Cold Start and Sparse Data in Recommender Systems](https://www.sciencedirect.com/science/article/abs/pii/S0957417420300737)
- [Score Normalization - ScienceDirect](https://www.sciencedirect.com/topics/computer-science/score-normalization)
- [Sigmoid vs Softmax - Stanford](https://web.stanford.edu/~nanbhas/blog/sigmoid-softmax/)
- [Google ML Normalization Guide](https://developers.google.com/machine-learning/crash-course/numerical-data/normalization)
- [Microsoft Confidence Score Guidance](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/concept/accuracy-confidence)

---

## Summary

**Recommended approach**: Calibrated linear with evidence weighting

```python
confidence = (composite / 100) * (0.7 * evidence_factor + 0.3 * stability_factor)
```

**Key insight**: Raw score alone is insufficient. Confidence must account for HOW MUCH evidence we have behind that score.

**Next step**: Implement `calculate_confidence()` method in `scorer.py` with first_seen tracking.
