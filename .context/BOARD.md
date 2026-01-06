# aOa - Work Board

> **Updated**: 2026-01-06 (Session 13) | **Phase**: 5 - Go Live
> **Goal**: Public release with cohesive "Angle of Attack" branding
> **Archive**: Phases 1-4 complete → `.context/archive/2026-01-06-phases-1-4-complete.md`

---

## Active Tasks

| # | Task | Status | Deps | Notes |
|---|------|--------|------|-------|
| GL-006 | Messaging Unification | **Audit Done** | - | See master audit below |
| GL-003 | Token Calculator | Queued | GL-006 | HTML/JS, embed in README |
| GL-005 | Landing Page | Queued | GL-006 | One-pager with outcomes |
| GL-002 | Demo GIFs | Recording | GL-006 | Storyboards ready |
| P4-006 | 90% Accuracy | Ongoing | - | Background tuner learning |

**Next Action**: Implement GL-006 (messaging unification) per audit checklist

---

## GL-006: Messaging Unification

**Master Document**: `.context/details/2026-01-06-messaging-audit-master.md`

### The Five Angles

| Current | Angle | CLI Command |
|---------|-------|-------------|
| LOCAL SEARCH | **Symbol Angle** | `aoa search` |
| PATTERN SEARCH | **Signal Angle** | `aoa multi`, `aoa pattern` |
| INTENT TRACKING | **Intent Angle** | `aoa intent` |
| KNOWLEDGE REPOS | **Intel Angle** | `aoa repo` |
| Prediction/Memory | **Strike Angle** | `aoa context` |

**Tagline**: `5 angles. 1 attack.`

### Implementation Checklist

#### Phase 1: CLI Header (5 min)
- [ ] `cli/aoa:2` → `# aoa - 5 angles. 1 attack.`
- [ ] `cli/aoa:883` → `5 angles. 1 attack.`

#### Phase 2: CLI Section Headers (10 min)
- [ ] `cli/aoa:885` STATUS COMMANDS → `ATTACK STATUS`
- [ ] `cli/aoa:892` LOCAL SEARCH → `SYMBOL ANGLE`
- [ ] `cli/aoa:898` PATTERN SEARCH → `SIGNAL ANGLE`
- [ ] `cli/aoa:903` INTENT TRACKING → `INTENT ANGLE`
- [ ] `cli/aoa:915` KNOWLEDGE REPOS → `INTEL ANGLE`

#### Phase 3: Services Map (10 min)
- [ ] `cli/aoa:665` CORE CAPABILITIES → `THE FIVE ANGLES`
- [ ] `cli/aoa:668-677` Update capability names
- [ ] `cli/aoa:764` aOa Services → `aOa Angles`

#### Phase 4: Install Script (5 min)
- [ ] `install.sh:31` → `Deploying 5 angles...`
- [ ] `install.sh:161` → `Deploying angles...`
- [ ] `install.sh:~197` → `⚡ aOa Attack Ready!`

#### Phase 5: Status Line (2 min)
- [ ] `hooks/aoa-status.sh` `learning...` → `calibrating...`

#### Phase 6: README (10 min)
- [ ] Section headers: "The Five Angles", "Hit Rate", "Deploy"
- [ ] Update angle terminology in body

#### Phase 7: CLAUDE.md (5 min)
- [ ] Header → `5 Angles. 1 Attack.`
- [ ] Rule names updated

#### Phase 8: Verification
- [ ] `grep -r "Bold tools" .` → 0 results
- [ ] `aoa help` shows new headers
- [ ] `aoa services` shows angle terminology

---

## Completed (This Phase)

| # | Task | Output | Date |
|---|------|--------|------|
| GL-001 | README Rewrite | Outcome-focused messaging | 2025-12-27 |
| GL-004 | Imagery | 3 Gemini images, neon cyan theme | 2025-12-27 |
| GL-006 | Messaging Audit | 68 touchpoints inventoried | 2026-01-06 |

---

## Key Results (All Phases)

| Metric | Value |
|--------|-------|
| Token Savings | 68% |
| Speed vs grep | 74x faster |
| Hit Rate | ~70% (target: 90%) |
| Benchmark Accuracy | 100% top-1 |

---

## Files Reference

```
.context/details/2026-01-06-messaging-audit-master.md   # Full audit + line numbers
.context/archive/2026-01-06-phases-1-4-complete.md      # Historical phases
assets/generate-imagery.py                               # Gemini image generator
assets/generated/*.png                                   # Generated images
```

---

## Confidence Legend

| Signal | Meaning | Action |
|--------|---------|--------|
| 🟢 | Confident | Proceed freely |
| 🟡 | Uncertain | Try once, then research |
| 🔴 | Lost | STOP, use 131 agent |
