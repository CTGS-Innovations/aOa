# aOa Session Starter Prompt

Copy and paste this to begin a new session:

---

```
Hey Beacon, I'm back. Load context and let's continue.

Mode: Execute with precision. Use the traffic light system (🟢🟡🔴) before each task. Track progress with TodoWrite. When stuck, use 131 for research.

Style:
- Build benchmarks FIRST (fail before, pass after)
- Small incremental changes, test after each
- Update context files as we go
- Capture learnings before session ends

Current goal: Phase 2 - Predictive Prefetch (see BOARD.md)

Go.
```

---

## What This Activates

| Element | Purpose |
|---------|---------|
| "Hey Beacon" | Spawns Beacon agent to load CURRENT.md + BOARD.md |
| Traffic lights | Forces confidence assessment before action |
| TodoWrite | Visible progress tracking |
| 131 | Research agent for unknowns |
| "Benchmarks FIRST" | Data-driven development |
| "Update context" | Knowledge preservation |

## Expected Response

Beacon returns:
- Current phase status
- Active task with confidence level
- Blockers (if any)
- Suggested first action

Then you say "Go" or redirect.

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

Quick task: [specific change]. 🟢 confidence. No research needed. Just do it.
```
