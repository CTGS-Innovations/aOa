# aOa - Work Board

> **Updated**: 2026-01-06 (Session 14 ACTIVE) | **Phase**: 5 - Go Live
> **Goal**: Public release with cohesive "Angle of Attack" branding
> **Archive**: Phases 1-4 complete → `.context/archive/2026-01-06-phases-1-4-complete.md`
> **Current**: GL-007 decided → testing deployment on fresh project

---

## Active Tasks

| # | Task | Status | Deps | Notes |
|---|------|--------|------|-------|
| GL-007 | Deployment Strategy | **DECIDED** | - | Docker Compose + Install Script |
| GL-008 | Fresh Project Test | **IN PROGRESS** | GL-007 | Test deployment on new project |
| GL-003 | Token Calculator | Queued | GL-008 | HTML/JS, embed in README |
| GL-005 | Landing Page | Queued | GL-008 | One-pager with outcomes |
| GL-002 | Demo GIFs | Queued | GL-008 | Storyboards ready |
| P4-006 | 90% Accuracy | Ongoing | - | Background tuner learning

**Next Action**: GL-008 - Test deployment on fresh project

### GL-007: Deployment Strategy (DECIDED)

**Decision**: Docker Compose + Install Script (No MCP/Plugin)

**Rationale** (Session 14 research):
- Claude Code "plugins" = MCP servers only
- MCP servers CANNOT: configure hooks, set status line, install Docker services
- Our value requires hooks (UserPromptSubmit) and status line - not possible via MCP
- Restart required either way (MCP add or install.sh)
- No advantage to MCP bootstrap approach

**Deployment Options**:
```bash
# Option A: Clone and run (primary)
git clone https://github.com/you/aoa && cd aoa && ./install.sh

# Option B: One-liner (future, if npm published)
npx @aoa/setup
```

**Install Script Must Handle**:
1. Docker Compose services (indexer, API)
2. CLI to ~/bin
3. Hook configuration (UserPromptSubmit)
4. Status line setup
5. CLAUDE.md template

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

#### Phase 1: CLI Header (5 min) ✅
- [x] `cli/aoa:2` → `# aoa - 5 angles. 1 attack.`
- [x] `cli/aoa:883` → `5 angles. 1 attack.`

#### Phase 2: CLI Section Headers (10 min) ✅
- [x] `cli/aoa:885` STATUS COMMANDS → `ATTACK STATUS`
- [x] `cli/aoa:892` LOCAL SEARCH → `SYMBOL ANGLE`
- [x] `cli/aoa:898` PATTERN SEARCH → `SIGNAL ANGLE`
- [x] `cli/aoa:903` INTENT TRACKING → `INTENT ANGLE`
- [x] `cli/aoa:915` KNOWLEDGE REPOS → `INTEL ANGLE`

#### Phase 3: Services Map (10 min) ✅
- [x] `cli/aoa:665` CORE CAPABILITIES → `THE FIVE ANGLES`
- [x] `cli/aoa:668-677` Update capability names
- [x] `cli/aoa:764` aOa Services → `aOa Angles`

#### Phase 4: Install Script (5 min) ✅
- [x] `install.sh:31` → `Deploying 5 angles...`
- [x] `install.sh:161` → `Deploying angles...`
- [x] `install.sh:~197` → `⚡ aOa Attack Ready!`

#### Phase 5: Status Line (2 min) ✅
- [x] `hooks/aoa-status.sh` `learning...` → `calibrating...`
- [x] `intent-summary.py` `learning...` → `calibrating...`

#### Phase 6: README (10 min) ✅
- [x] Section headers: "The Five Angles", "Hit Rate", "Deploy"
- [x] Update angle terminology in body

#### Phase 7: CLAUDE.md (5 min) ✅
- [x] Header → `5 Angles. 1 Attack.`
- [x] Rule names updated

#### Phase 8: Verification ✅
- [x] `grep -r "Bold tools" .` → 0 results
- [x] `aoa help` shows new headers
- [x] `aoa services` shows angle terminology

---

## Completed (This Phase)

| # | Task | Output | Date |
|---|------|--------|------|
| GL-001 | README Rewrite | Outcome-focused messaging | 2025-12-27 |
| GL-004 | Imagery | 3 Gemini images, neon cyan theme | 2025-12-27 |
| GL-006 | Messaging Unification | 5 angles branding across all touchpoints | 2026-01-06 |
| - | CLI Gateway Routing | CLI routes through 8080, status container rebuilt | 2026-01-06 |
| - | ~/bin/aoa Updated | Latest CLI installed to user path | 2026-01-06 |

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
