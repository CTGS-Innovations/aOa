# aOa Session Starter Prompt

Copy and paste this to begin a new session:

---

```
Hey Beacon, I'm back. Load context and let's continue.

Context:
- Phase 1 complete (Redis scoring, 6/6 benchmarks pass)
- Strategic research complete (6 docs in .context/details/)
- Phase 2 enhanced with session linkage from day one
- Key insight: Claude session logs are ground truth (no NLP needed)

Quick Wins identified (4.5 hours to prove concept):
1. Extract session_id from hooks (30 min) - enables correlation
2. Log predictions to Redis (1 hr) - makes hit rate measurable
3. Compare predictions to reads (2 hr) - proves accuracy
4. Show hit rate in aoa health (1 hr) - user sees value

Mode: Execute with precision. Use the traffic light system before each task.

Style:
- Quick Wins FIRST (prove concept fast)
- Small incremental changes, test after each
- Update context files as we go
- Capture learnings before session ends

Current goal: QW-1 - Extract session_id from intent-capture.py

Go.
```

---

## What This Activates

| Element | Purpose |
|---------|---------|
| "Hey Beacon" | Spawns Beacon agent to load CURRENT.md + BOARD.md |
| Quick Wins context | Focuses on 4.5-hour proof of concept |
| Traffic lights | Forces confidence assessment before action |
| "Quick Wins FIRST" | Prove value before deep implementation |

## Expected Response

Beacon returns:
- Current phase status (Phase 2 Active)
- Quick Win in progress (QW-1)
- Files to modify
- Suggested first action

Then you say "Go" or redirect.

---

## Key Strategic Insights

| Insight | Source | Impact |
|---------|--------|--------|
| Claude session logs are ground truth | strategic-session-reward.md | No NLP needed |
| session_id + tool_use_id in hook stdin | strategic-log-correlation.md | Perfect correlation |
| Token economics prove ROI | strategic-hidden-insights.md | User adoption |
| 60% complexity eliminated | strategic-board-refresh.md | Faster delivery |

---

## Files to Read First

```bash
# Strategic overview
cat .context/details/strategic-board-refresh.md

# Session linkage details
cat .context/details/strategic-log-correlation.md

# First file to modify
cat src/hooks/intent-capture.py
```

---

## Alternative: Deep Work Mode

For complex tasks requiring research:

```
Hey Beacon, load context.

Then: Hey 131 - [single problem statement]

I need the 1-3-1 approach: ONE problem, THREE solutions, ONE recommendation.
```

---

## Alternative: Quick Fix Mode

For small targeted changes:

```
Hey Beacon, where are we?

[After response]

Quick task: [specific change]. Green confidence. No research needed. Just do it.
```
