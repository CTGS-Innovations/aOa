# Phase 4 Accuracy Tuning Research

> **Date**: 2025-12-23
> **Tasks**: P4-003 (Weight Tuning), P4-006 (90% Accuracy)
> **Status**: Research Complete
> **Confidence**: Yellow -> Green (after research)

---

## Executive Summary

After researching weight tuning algorithms and accuracy metrics, here are the key findings:

| Question | Answer |
|----------|--------|
| Best tuning algorithm? | **Thompson Sampling** (simple, no hyperparameters, proven effective) |
| Is 90% realistic? | **Yes, but measured as Hit@K** (not precision) |
| What metric? | **Hit@5** or **Recall@K** - "was the file in top 5 predictions?" |
| Online or batch? | **Online** - adapt continuously to user patterns |
| Gradient descent? | **Overkill** - only 3 weights, not differentiable objective |

---

## P4-003: Weight Tuning Strategy

### The Problem

Current weights are fixed:
```python
DEFAULT_WEIGHTS = {
    'recency': 0.4,
    'frequency': 0.3,
    'tag': 0.3,
}
```

We need to tune these based on actual prediction success/failure.

### Algorithm Comparison

| Algorithm | Pros | Cons | Complexity | Recommendation |
|-----------|------|------|------------|----------------|
| **Gradient Descent** | Fast convergence, well-understood | Requires differentiable objective, can overshoot | Medium | Not suitable - objective not differentiable |
| **Bayesian Optimization** | Sample-efficient, handles expensive evaluations | Complex to implement, overkill for 3 params | High | Overkill for our use case |
| **Coordinate Descent** | Simple, one param at a time | Can get stuck in local optima | Low | Good fallback option |
| **Hill Climbing** | No gradients needed, intuitive | Local optima, requires step size tuning | Low | Viable but needs hyperparameters |
| **Thompson Sampling** | No hyperparameters, balances exploration/exploitation, proven for bandits | Requires prior distribution | Low | **Recommended** |
| **Grid Search** | Exhaustive, guaranteed global | Slow, doesn't adapt | Very Low | Only for initial calibration |

### Why Thompson Sampling?

From research on [Multi-Armed Bandits](https://en.wikipedia.org/wiki/Multi-armed_bandit) and [Thompson Sampling](https://en.wikipedia.org/wiki/Thompson_sampling):

1. **No hyperparameters** - Unlike epsilon-greedy or hill climbing, no step sizes to tune
2. **Natural exploration/exploitation** - Automatically balances trying new weights vs using known good ones
3. **Adapts online** - Updates after each prediction feedback
4. **Proven effective** - "Thompson sampling greatly outperforms other methods"
5. **Simple to implement** - Just maintain Beta distributions for each weight

From [Stanford's Thompson Sampling Tutorial](https://web.stanford.edu/~bvr/pubs/TS_Tutorial.pdf):
> "Thompson Sampling is a natural Bayesian algorithm... efficient to implement and exhibits several desirable properties such as small regret."

### Implementation Approach: Discretized Thompson Sampling

Since we have 3 continuous weights (recency, frequency, tag), we discretize:

```python
"""
Discretized Thompson Sampling for Weight Tuning

Instead of treating each weight as continuous, we define discrete "arms":
- Each arm is a weight configuration
- We learn which configuration works best via Thompson Sampling
"""

import random
from typing import Dict, List, Tuple

class WeightTuner:
    """
    Thompson Sampling weight optimizer.

    Maintains Beta distributions for each weight configuration,
    updating based on hit/miss feedback.
    """

    # Define weight configurations to try (arms)
    ARMS = [
        {'recency': 0.5, 'frequency': 0.3, 'tag': 0.2},  # Recency-heavy
        {'recency': 0.4, 'frequency': 0.4, 'tag': 0.2},  # Balanced RF
        {'recency': 0.4, 'frequency': 0.3, 'tag': 0.3},  # Current default
        {'recency': 0.3, 'frequency': 0.4, 'tag': 0.3},  # Frequency-heavy
        {'recency': 0.3, 'frequency': 0.3, 'tag': 0.4},  # Tag-heavy
        {'recency': 0.2, 'frequency': 0.4, 'tag': 0.4},  # Low recency
        {'recency': 0.5, 'frequency': 0.2, 'tag': 0.3},  # High recency, low freq
        {'recency': 0.33, 'frequency': 0.33, 'tag': 0.34},  # Equal weights
    ]

    def __init__(self, redis_client=None):
        """
        Initialize with Beta(1,1) priors (uniform) for each arm.

        Beta distribution represents probability of success.
        alpha = successes + 1
        beta = failures + 1
        """
        self.redis = redis_client
        # Store as Redis hash: arm_idx -> (alpha, beta)
        self.prior_alpha = 1
        self.prior_beta = 1

    def _get_arm_stats(self, arm_idx: int) -> Tuple[int, int]:
        """Get (alpha, beta) for an arm from Redis."""
        if self.redis:
            key = f"tuner:arm:{arm_idx}"
            alpha = int(self.redis.hget(key, "alpha") or self.prior_alpha)
            beta = int(self.redis.hget(key, "beta") or self.prior_beta)
            return (alpha, beta)
        return (self.prior_alpha, self.prior_beta)

    def _update_arm_stats(self, arm_idx: int, hit: bool):
        """Update arm stats after feedback."""
        if self.redis:
            key = f"tuner:arm:{arm_idx}"
            if hit:
                self.redis.hincrby(key, "alpha", 1)
            else:
                self.redis.hincrby(key, "beta", 1)

    def select_weights(self) -> Dict[str, float]:
        """
        Select weights using Thompson Sampling.

        1. Sample from each arm's Beta distribution
        2. Select arm with highest sample
        3. Return that arm's weights
        """
        best_arm = 0
        best_sample = -1

        for idx, arm in enumerate(self.ARMS):
            alpha, beta = self._get_arm_stats(idx)
            # Sample from Beta(alpha, beta)
            sample = random.betavariate(alpha, beta)
            if sample > best_sample:
                best_sample = sample
                best_arm = idx

        # Store selected arm for feedback
        self._current_arm = best_arm
        return self.ARMS[best_arm].copy()

    def record_feedback(self, hit: bool, arm_idx: int = None):
        """
        Record hit/miss feedback for the selected arm.

        Args:
            hit: True if prediction was used, False otherwise
            arm_idx: Arm index (defaults to last selected)
        """
        arm = arm_idx if arm_idx is not None else getattr(self, '_current_arm', 0)
        self._update_arm_stats(arm, hit)

    def get_best_weights(self) -> Dict[str, float]:
        """
        Get the arm with highest expected success rate.
        (For when you want exploitation only, no exploration)
        """
        best_arm = 0
        best_mean = 0

        for idx, arm in enumerate(self.ARMS):
            alpha, beta = self._get_arm_stats(idx)
            mean = alpha / (alpha + beta)
            if mean > best_mean:
                best_mean = mean
                best_arm = idx

        return self.ARMS[best_arm].copy()

    def get_stats(self) -> List[Dict]:
        """Get statistics for all arms."""
        stats = []
        for idx, arm in enumerate(self.ARMS):
            alpha, beta = self._get_arm_stats(idx)
            stats.append({
                'arm': idx,
                'weights': arm,
                'alpha': alpha,
                'beta': beta,
                'mean': alpha / (alpha + beta),
                'samples': alpha + beta - 2,  # Subtract priors
            })
        return sorted(stats, key=lambda x: x['mean'], reverse=True)
```

### Training Data Collection

To tune weights, we need hit/miss data:

```python
"""
Prediction Logging for Training Data Collection

Flow:
1. User submits prompt (UserPromptSubmit hook fires)
2. We predict top 5 files with current weights
3. Store prediction with timestamp
4. User reads files (intent-capture logs reads)
5. Background job compares predictions to actual reads
6. Record hit/miss feedback to tuner
"""

import time
from typing import List, Dict

class PredictionLogger:
    """Log predictions for later evaluation."""

    # How long to wait before evaluating a prediction (seconds)
    EVAL_DELAY = 300  # 5 minutes

    def __init__(self, redis_client):
        self.redis = redis_client

    def log_prediction(self, prediction_id: str, files: List[str],
                       weights: Dict[str, float], arm_idx: int):
        """
        Log a prediction for later evaluation.

        Args:
            prediction_id: Unique ID (e.g., timestamp + hash)
            files: List of predicted files
            weights: Weight configuration used
            arm_idx: Thompson Sampling arm index
        """
        key = f"prediction:{prediction_id}"
        self.redis.hset(key, mapping={
            "timestamp": int(time.time()),
            "files": ",".join(files),
            "weights": str(weights),
            "arm_idx": arm_idx,
            "evaluated": 0,
        })
        # Add to pending evaluation set
        self.redis.zadd("predictions:pending",
                       {prediction_id: time.time() + self.EVAL_DELAY})

    def evaluate_pending(self, actual_reads: List[str]) -> List[Dict]:
        """
        Evaluate predictions that are ready.

        Args:
            actual_reads: Files that were actually read since prediction

        Returns:
            List of evaluation results
        """
        now = time.time()
        results = []

        # Get predictions ready for evaluation
        pending = self.redis.zrangebyscore("predictions:pending", 0, now)

        for pred_id in pending:
            key = f"prediction:{pred_id}"
            pred_data = self.redis.hgetall(key)

            if pred_data and not int(pred_data.get("evaluated", 0)):
                predicted = pred_data["files"].split(",")

                # Calculate hit rate: how many predictions were used?
                hits = sum(1 for f in predicted if f in actual_reads)
                hit_rate = hits / len(predicted) if predicted else 0

                # Was it a hit? (at least one prediction used)
                hit = hits > 0

                results.append({
                    "prediction_id": pred_id,
                    "predicted": predicted,
                    "hits": hits,
                    "hit_rate": hit_rate,
                    "arm_idx": int(pred_data["arm_idx"]),
                    "hit": hit,
                })

                # Mark as evaluated
                self.redis.hset(key, "evaluated", 1)
                self.redis.hset(key, "hit", 1 if hit else 0)
                self.redis.zrem("predictions:pending", pred_id)

        return results
```

### Online vs Batch Learning Decision

| Approach | Description | Pros | Cons |
|----------|-------------|------|------|
| **Online** | Update after each prediction feedback | Adapts immediately, no batch jobs | Noisy updates, potential oscillation |
| **Batch** | Collect N samples, then update | Stable updates, less noise | Slow to adapt, requires scheduled jobs |
| **Mini-batch** | Update every 10-20 samples | Balance of both | More complex implementation |

**Recommendation: Online with dampening**

From research on [Online vs Batch Learning](https://medium.com/data-scientists-diary/online-vs-batch-learning-in-machine-learning-385d21511ec3):
> "Online learning can be a bit more unpredictable... but it's actually a feature for scenarios where rapid adaptation is more important than perfect accuracy."

For aOa, rapid adaptation to user patterns is more important than perfect stability. Thompson Sampling naturally handles this by maintaining full distributions rather than point estimates.

---

## P4-006: Achieving 90% Accuracy

### Defining "90% Accuracy"

The term "accuracy" is ambiguous. We must choose a specific metric:

| Metric | Formula | What It Measures | 90% Means |
|--------|---------|------------------|-----------|
| **Precision@K** | (relevant in top K) / K | Quality of predictions | 9/10 predictions are used |
| **Recall@K** | (relevant in top K) / (total relevant) | Coverage of needs | 90% of needed files predicted |
| **Hit@K** | 1 if any prediction used, else 0 | Any useful prediction | 90% of sessions have a hit |
| **NDCG@K** | Position-weighted relevance | Order quality | Complex interpretation |
| **F1@K** | Harmonic mean of P@K and R@K | Balance | Balanced quality |

From [Recall and Precision at K for Recommender Systems](https://medium.com/@m_n_malaeb/recall-and-precision-at-k-for-recommender-systems-618483226c54):
> "Precision@k is a fraction of top k recommended items that are relevant to the user."

From [Evaluating Recommendation Systems](https://www.shaped.ai/blog/evaluating-recommendation-systems-part-1):
> "Recall@k (also known as HitRatio@k) is a fraction of top k recommended items that are in a set of items relevant to the user."

### Recommended Metric: Hit@5

For aOa's use case, **Hit@5** (also called Recall@5 or HitRatio@5) makes the most sense:

**Definition**: "Was at least one of the top 5 predicted files actually read by the user?"

**Why Hit@5?**
1. **Binary outcome** - Easy to understand and track
2. **User perspective** - If any prediction helps, it's valuable
3. **Realistic K** - Users typically see 3-5 suggestions
4. **Measurable** - Clear success/failure signal for tuning

**90% Hit@5 = 90% of prediction batches include at least one file the user reads**

### Is 90% Realistic?

Research on prefetch prediction accuracy:

From [Measuring Predictive Prefetching](https://www.usenix.org/legacy/event/usenix01/full_papers/kroeger/kroeger_html/node10.html):
> "Across four diverse traces... accuracy measures ranged from 0.78-0.88 (78-88%)."

From research on [cache prefetching](https://en.wikipedia.org/wiki/Cache_prefetching):
> "The better prefetch methods... have very high efficiencies, hiding approximately 90 percent of the miss delay."

From [recommendation system benchmarks](https://www.sciencedirect.com/science/article/abs/pii/S0045790621003311):
> "CUPCF system achieved maximum values of Accuracy (0.91402)... on the MovieLens dataset."

**Verdict: 90% is achievable but aggressive**

| Data Quality | Realistic Target |
|--------------|------------------|
| Cold start (< 50 intents) | 60-70% |
| Warm (50-200 intents) | 70-80% |
| Established (200+ intents) | 80-90% |
| Heavily used (1000+ intents) | 85-95% |

### Baseline Comparison

We need baselines to know if we're improving:

| Baseline | Description | Expected Hit@5 |
|----------|-------------|----------------|
| **Random** | Random 5 files from indexed set | ~5% (depends on corpus size) |
| **MRU** | Most Recently Used 5 files | ~40-60% (strong baseline) |
| **MFU** | Most Frequently Used 5 files | ~30-50% |
| **Current formula** | recency*0.4 + freq*0.3 + tag*0.3 | ~50-70% (estimate) |
| **Tuned formula** | Optimal weights via Thompson | 70-90% (target) |

### Evaluation Methodology

```python
"""
Accuracy Evaluation System

Computes Hit@K, Precision@K, and Recall@K from prediction logs.
"""

from typing import List, Dict
from collections import defaultdict

class AccuracyEvaluator:
    """Evaluate prediction accuracy across multiple metrics."""

    def __init__(self, redis_client):
        self.redis = redis_client

    def evaluate_batch(self, predictions: List[Dict], actuals: List[str]) -> Dict:
        """
        Evaluate a batch of predictions against actual reads.

        Args:
            predictions: List of {files: [...], confidence: ...}
            actuals: List of files that were actually read

        Returns:
            Dict with hit@k, precision@k, recall@k for various k
        """
        actual_set = set(actuals)
        results = {}

        for k in [1, 3, 5, 10]:
            # Get top K predictions
            top_k = [p['files'][:k] for p in predictions]

            hits = 0
            precision_sum = 0
            recall_sum = 0

            for pred_files in top_k:
                pred_set = set(pred_files)
                intersection = pred_set & actual_set

                # Hit@K: 1 if any intersection
                if intersection:
                    hits += 1

                # Precision@K: relevant / k
                precision_sum += len(intersection) / k if k > 0 else 0

                # Recall@K: relevant / total_relevant
                recall_sum += len(intersection) / len(actual_set) if actual_set else 0

            n = len(predictions)
            results[f'hit@{k}'] = hits / n if n > 0 else 0
            results[f'precision@{k}'] = precision_sum / n if n > 0 else 0
            results[f'recall@{k}'] = recall_sum / n if n > 0 else 0

        return results

    def get_rolling_accuracy(self, window_hours: int = 24) -> Dict:
        """
        Get accuracy over a rolling time window.

        Returns:
            Dict with metrics and trend
        """
        import time

        now = time.time()
        window_start = now - (window_hours * 3600)

        # Get evaluated predictions in window
        # (Implementation would query Redis for predictions with timestamps in range)

        # Return summary
        return {
            'window_hours': window_hours,
            'predictions': 0,  # Count from Redis
            'hit_at_5': 0.0,   # Computed from logs
            'trend': 'stable',  # 'improving', 'declining', 'stable'
        }
```

### Fallback Strategies if 90% Not Achievable

If we plateau below 90%, these strategies can help:

| Strategy | Description | Implementation Complexity |
|----------|-------------|--------------------------|
| **Expand K** | Predict more files (top 7 instead of top 5) | Low |
| **Contextual features** | Add time of day, day of week | Medium |
| **Session memory** | Remember files from same "task" | Medium |
| **Semantic signals** | Use file content similarity | High |
| **User segmentation** | Different weights per usage pattern | High |
| **Lower threshold** | Accept 80-85% as "good enough" | None |

**Pragmatic approach**: Start with Hit@5 target of 80%, iterate to 85%, then push for 90%.

---

## Implementation Plan

### Phase 4 Task Breakdown

| Step | Task | Deps | Effort |
|------|------|------|--------|
| 4.1 | Add prediction logging to `/predict` endpoint | P2-002 | 2h |
| 4.2 | Create evaluation background job | 4.1 | 2h |
| 4.3 | Implement WeightTuner with Thompson Sampling | - | 3h |
| 4.4 | Connect tuner to scorer | 4.3 | 1h |
| 4.5 | Add `/metrics` endpoint for accuracy stats | 4.2 | 2h |
| 4.6 | Run baseline evaluation | 4.5 | 1h |
| 4.7 | Tune until target hit rate achieved | 4.6 | Ongoing |

### Data Requirements

To begin tuning, we need:

| Requirement | Minimum | Target |
|-------------|---------|--------|
| Total intents logged | 100 | 500+ |
| Prediction/read pairs | 50 | 200+ |
| Distinct files in corpus | 20 | 100+ |
| Sessions (prompt submissions) | 20 | 100+ |

### Metrics Dashboard

Endpoints to add:

```python
# GET /metrics - Overall accuracy stats
{
    "total_predictions": 150,
    "evaluated_predictions": 120,
    "hit_at_5": 0.72,
    "precision_at_5": 0.34,
    "recall_at_5": 0.68,
    "current_weights": {"recency": 0.4, "frequency": 0.3, "tag": 0.3},
    "best_arm": {"weights": {...}, "hit_rate": 0.78},
    "trend": "improving",
    "target_hit_rate": 0.90,
    "gap_to_target": 0.18
}

# GET /metrics/history?days=7 - Accuracy over time
{
    "daily": [
        {"date": "2025-12-23", "hit_at_5": 0.65, "predictions": 20},
        {"date": "2025-12-24", "hit_at_5": 0.72, "predictions": 35},
        ...
    ]
}

# GET /metrics/arms - Thompson Sampling arm statistics
{
    "arms": [
        {"idx": 0, "weights": {...}, "mean": 0.78, "samples": 45},
        {"idx": 1, "weights": {...}, "mean": 0.65, "samples": 32},
        ...
    ]
}
```

---

## Confidence Assessment

### Before Research: Red

- P4-003: "Gradient descent or simpler heuristic?" - Didn't know
- P4-006: "Is 90% realistic?" - No frame of reference

### After Research: Green

| Question | Confidence | Rationale |
|----------|------------|-----------|
| Algorithm choice | Green | Thompson Sampling is proven, simple, fits use case |
| Metric definition | Green | Hit@5 is standard, measurable, appropriate |
| 90% target | Yellow->Green | Achievable with enough data, clear path |
| Implementation | Green | Code sketches complete, patterns clear |

### Remaining Unknowns

1. **Actual hit rate** - Need to collect baseline data first
2. **Convergence time** - How many samples until weights stabilize?
3. **Arm count** - 8 arms might be too few or too many

---

## Sources

### Weight Tuning
- [Thompson Sampling - Wikipedia](https://en.wikipedia.org/wiki/Thompson_sampling)
- [A Tutorial on Thompson Sampling - Stanford](https://web.stanford.edu/~bvr/pubs/TS_Tutorial.pdf)
- [Multi-Armed Bandit - Wikipedia](https://en.wikipedia.org/wiki/Multi-armed_bandit)
- [2024 AAAI: Noninformative Priors for Thompson Sampling](https://ojs.aaai.org/index.php/AAAI/article/view/29240)
- [Online vs Batch Learning](https://medium.com/data-scientists-diary/online-vs-batch-learning-in-machine-learning-385d21511ec3)
- [Bayesian Optimization Overview - Distill](https://distill.pub/2020/bayesian-optimization/)
- [Hill Climbing vs Gradient Descent](https://webeduclick.com/difference-between-hill-climbing-and-gradient-descent-search/)

### Accuracy Metrics
- [Recall and Precision at K for Recommender Systems](https://medium.com/@m_n_malaeb/recall-and-precision-at-k-for-recommender-systems-618483226c54)
- [Recommender Systems Metrics - Neptune.ai](https://neptune.ai/blog/recommender-systems-metrics)
- [Evaluating Recommendation Systems - Shaped.ai](https://www.shaped.ai/blog/evaluating-recommendation-systems-part-1)
- [Precision and Recall at K - Evidently AI](https://www.evidentlyai.com/ranking-metrics/precision-recall-at-k)
- [Comprehensive Survey of Evaluation Techniques](https://arxiv.org/html/2312.16015v2)

### Prefetch Benchmarks
- [Measuring Predictive Prefetching - USENIX](https://www.usenix.org/legacy/event/usenix01/full_papers/kroeger/kroeger_html/node10.html)
- [Cache Prefetching - Wikipedia](https://en.wikipedia.org/wiki/Cache_prefetching)
- [Cold Start in Recommender Systems - ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0957417420300737)

---

## Summary

### P4-003: Weight Tuning

**Algorithm**: Thompson Sampling with discretized weight configurations (8 arms)

**Why**: Simple, no hyperparameters, proven for online learning, naturally balances exploration/exploitation

**Training data**: Log predictions, compare to actual reads after 5-minute delay

**Update strategy**: Online (update after each feedback)

### P4-006: 90% Accuracy

**Metric**: Hit@5 - "at least 1 of top 5 predictions was actually used"

**Target progression**:
1. Baseline (current formula): Measure first
2. Phase 1 target: 70% Hit@5
3. Phase 2 target: 80% Hit@5
4. Stretch goal: 90% Hit@5

**Evaluation**: Rolling 24-hour accuracy with trend detection

**Fallbacks**: Expand K, add features, accept 85% as success

---

## Next Steps

1. Complete Phase 2 first (prediction infrastructure)
2. Implement prediction logging (P4-001)
3. Collect 100+ prediction/read pairs
4. Measure baseline accuracy
5. Deploy Thompson Sampling tuner
6. Monitor and iterate
