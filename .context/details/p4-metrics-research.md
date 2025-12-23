# P4-002/P4-005 Research: Hit Rate Metrics & Dashboard

> **Date**: 2025-12-23
> **Agent**: 131
> **Status**: Research Complete
> **Confidence**: YELLOW -> GREEN

---

## Problem

Two related prediction accuracy problems:
1. **P4-002**: How to calculate hit rate by comparing predictions to actual file usage
2. **P4-005**: How to display accuracy metrics (CLI vs API vs both)

---

## Recommendation: Hybrid Redis + Dual CLI/API Dashboard

Use Redis sorted sets for real-time metrics, expose via both `/metrics` API and `aoa metrics` CLI.

---

## P4-002: Hit Rate Calculation

### Storage Schema (Redis)

```
aoa:predictions:<session_id>   # ZSET: {file_path: timestamp}
aoa:actuals:<session_id>       # ZSET: {file_path: timestamp}
aoa:metrics:hit_rate:rolling   # ZSET: {bucket_ts: hit_rate}
```

### Core Metrics Class

```python
# src/ranking/metrics.py
import time
from typing import Dict, List, Set
from .redis_client import RedisClient

class PredictionMetrics:
    """Track prediction accuracy using Redis sorted sets."""

    PREFIX_PREDICTIONS = "aoa:predictions"
    PREFIX_ACTUALS = "aoa:actuals"
    SESSION_WINDOW = 300       # 5 minutes
    RETENTION_SECONDS = 86400  # 24 hours

    def __init__(self, redis_client=None):
        self.redis = redis_client or RedisClient()

    def record_prediction(self, session_id: str, files: List[str],
                          confidence: Dict[str, float] = None) -> int:
        """Record predicted files for a session."""
        ts = time.time()
        key = f"{self.PREFIX_PREDICTIONS}:{session_id}"

        for f in files:
            score = confidence.get(f, ts) if confidence else ts
            self.redis.zadd(key, score, f)

        self.redis.expire(key, self.RETENTION_SECONDS)
        return len(files)

    def record_actual(self, session_id: str, file_path: str) -> None:
        """Record an actual file access."""
        key = f"{self.PREFIX_ACTUALS}:{session_id}"
        self.redis.zadd(key, time.time(), file_path)
        self.redis.expire(key, self.RETENTION_SECONDS)

    def calculate_hit_rate(self, session_id: str) -> Dict:
        """Calculate hit rate for a session."""
        pred_key = f"{self.PREFIX_PREDICTIONS}:{session_id}"
        actual_key = f"{self.PREFIX_ACTUALS}:{session_id}"

        predicted = set(self.redis.zrange(pred_key, 0, -1))
        actual = set(self.redis.zrange(actual_key, 0, -1))

        hits = predicted & actual
        precision = len(hits) / len(predicted) if predicted else 0.0
        recall = len(hits) / len(actual) if actual else 0.0

        return {
            'predicted': list(predicted),
            'actual': list(actual),
            'hits': list(hits),
            'precision': round(precision, 4),
            'recall': round(recall, 4),
        }

    def get_rolling_metrics(self, window_seconds: int = 3600) -> Dict:
        """Get aggregated metrics over rolling window."""
        now = time.time()
        cutoff = now - window_seconds

        pred_keys = self.redis.keys(f"{self.PREFIX_PREDICTIONS}:*")

        total_predicted = 0
        total_hits = 0
        sessions = 0

        for pred_key in pred_keys:
            session_id = pred_key.split(":")[-1]
            actual_key = f"{self.PREFIX_ACTUALS}:{session_id}"

            predicted = set(self.redis.client.zrangebyscore(pred_key, cutoff, now))
            actual = set(self.redis.client.zrangebyscore(actual_key, cutoff, now))

            if predicted:
                sessions += 1
                total_predicted += len(predicted)
                total_hits += len(predicted & actual)

        return {
            'sessions': sessions,
            'total_predicted': total_predicted,
            'total_hits': total_hits,
            'precision': round(total_hits / total_predicted, 4) if total_predicted else 0.0,
        }
```

---

## P4-005: Dashboard Metrics

### API Endpoint

```python
# Add to indexer.py
@app.route('/metrics')
def get_metrics():
    """Get prediction accuracy metrics."""
    window = int(request.args.get('window', 24))  # hours

    metrics = PredictionMetrics()
    rolling = metrics.get_rolling_metrics(window * 3600)

    return jsonify({
        'current': rolling,
        'target': {'precision_goal': 0.90, 'on_target': rolling['precision'] >= 0.90},
        'timestamp': time.time(),
    })
```

### CLI Command with Sparklines

```python
# aoa metrics command
from sparklines import sparklines

def format_cli_output(metrics: Dict) -> str:
    precision = metrics['current']['precision']

    # Color based on performance
    if precision >= 0.90:
        status = "\033[92m[OK]\033[0m"  # Green
    elif precision >= 0.70:
        status = "\033[93m[--]\033[0m"  # Yellow
    else:
        status = "\033[91m[!!]\033[0m"  # Red

    return f"""
aOa Prediction Metrics
{'=' * 50}

Current (Last Hour)
  Precision:   {precision:.1%} {status}
  Predictions: {metrics['current']['total_predicted']}
  Hits:        {metrics['current']['total_hits']}
  Sessions:    {metrics['current']['sessions']}

Goal: 90% Precision
  Status: {'ON TARGET' if precision >= 0.90 else f'{0.90 - precision:.1%} below target'}
"""
```

### CLI Output Example

```
aOa Prediction Metrics
==================================================

Current (Last Hour)
  Precision:   85.2% [--]
  Predictions: 47
  Hits:        40
  Sessions:    12

Goal: 90% Precision
  Status: 4.8% below target
```

---

## Integration Points

1. **`/predict` endpoint**: Call `metrics.record_prediction()` before returning
2. **`intent-capture.py`**: Call `metrics.record_actual()` on every Read event
3. **New `/metrics` endpoint**: Expose dashboard summary
4. **New `aoa metrics` command**: CLI visualization

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/ranking/metrics.py` | NEW - Core metrics tracking |
| `src/ranking/dashboard.py` | NEW - Dashboard formatting |
| `src/index/indexer.py` | MODIFY - Add `/metrics` endpoint |
| `src/hooks/intent-capture.py` | MODIFY - Call record_actual |
| `src/gateway.py` | MODIFY - Add `aoa metrics` command |

---

## Sources

- [Precision and Recall at K - Evidently AI](https://www.evidentlyai.com/ranking-metrics/precision-recall-at-k)
- [Rolling Rate Limiter with Redis - ClassDojo](https://engineering.classdojo.com/blog/2015/02/06/rolling-rate-limiter/)
- [Sparklines Python Library](https://github.com/deeplook/sparklines)
