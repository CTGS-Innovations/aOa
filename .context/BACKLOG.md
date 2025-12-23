# aOa Context Intelligence - Backlog

> **Updated**: 2025-12-23

Items parked for future consideration. Not scheduled, but captured with enough context to pick up later.

---

## Future Enhancements

| # | Item | Context | Why Parked |
|---|------|---------|------------|
| B-001 | Embeddings-based semantic search | Use sentence transformers for intent matching | Adds complexity, start with keyword matching |
| B-002 | Cross-repo learning | Learn patterns from multiple indexed repos | Need single-repo working first |
| B-003 | Editor integration | VSCode extension showing predictions | CLI-first approach |
| B-004 | Prediction explanation | Why was this file predicted? | Nice-to-have after core works |
| B-005 | File relationship graph | Build graph of which files accessed together | Could improve predictions, evaluate later |
| B-006 | Time-of-day patterns | Learn that auth work happens mornings | May be noise, evaluate after baseline |

---

## Technical Debt

| # | Item | Context | Priority |
|---|------|---------|----------|
| D-001 | intent-prefetch.py outputs nothing | Currently commented out, needs implementation | Fixed in P2-003 |
| D-002 | No tests for scoring | Need unit tests for redis_client | Add during P1 |
| D-003 | Hardcoded Redis connection | Should use config | Low |

---

## Questions to Resolve

| # | Question | Context | Status |
|---|----------|---------|--------|
| Q-001 | What weights for recency vs frequency vs tags? | GH suggested 0.4/0.3/0.3 | Start with these, tune in P4 |
| Q-002 | How many predictions to show? | Too many is noise, too few misses | Start with 5, make configurable |
| Q-003 | Decay half-life for scores? | How fast should old scores fade? | Try 24 hours, tune based on usage |
