# aOa Messaging Audit - Master Reference

> **Date**: 2026-01-06 (Session 13)
> **Purpose**: Complete inventory of all user-facing messaging for "Angle of Attack" theme alignment
> **Status**: ACTIVE - This is the authoritative audit document
> **Supersedes**: `messaging-full-audit.md`, `messaging-unification-draft.md`

---

## Executive Summary

The "Angle of Attack" theme is strong at the top (README, brand) but fragments at the mid-level (CLI help, install script). This audit inventories every touchpoint and proposes alignment.

| Category | Items | Aligned | Partial | Misaligned |
|----------|-------|---------|---------|------------|
| README.md | 14 | 10 | 3 | 1 |
| CLI Help | 23 | 12 | 8 | 3 |
| Install Script | 7 | 3 | 2 | 2 |
| Status Line | 5 | 4 | 1 | 0 |
| CLAUDE.md | 11 | 7 | 3 | 1 |
| Docker/Services | 8 | 8 | 0 | 0 |
| **Total** | **68** | **44** | **17** | **7** |

---

## The Core Concept

### Two-Layer Model

```
┌─────────────────────────────────────────────────┐
│                  THE ATTACK                      │
│   Sophisticated ranking + orchestration          │
│   Combines all angles → High hit rate            │
└──────────────────────┬──────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │ Symbol  │   │ Signal  │   │  Intel  │  ...
   │  Angle  │   │  Angle  │   │  Angle  │
   └─────────┘   └─────────┘   └─────────┘
        │              │              │
   O(1) lookup   Multi-term    External docs
```

**Layer 1 - The Angles**: 5 individual approach methods
**Layer 2 - The Attack**: Orchestration that combines angles for accuracy

### The Five Angles

| Angle | What It Does | CLI Command |
|-------|--------------|-------------|
| **Symbol Angle** | O(1) index lookup | `aoa search` |
| **Intent Angle** | Tracks what user is doing | `aoa intent` |
| **Intel Angle** | External knowledge repos | `aoa repo` |
| **Signal Angle** | Multi-term ranking | `aoa multi` |
| **Strike Angle** | Predictive prefetch | `aoa context` |

### Canonical Tagline

```
5 angles. 1 attack. High hit rate.
```

---

## Vocabulary Guide

### Terms to USE (Attack-Aligned)

| Term | Meaning | Example Usage |
|------|---------|---------------|
| **angle** | One approach method | "Symbol angle uses O(1) lookup" |
| **attack** | Combined orchestration | "The attack combines all angles" |
| **intent** | What user is doing (tracked) | "105 intents captured" |
| **hit** | Accurate prediction | "Predicted file was a hit" |
| **hit rate** | Accuracy percentage | "Hit rate: 100%" |
| **target** | File/symbol being found | "Target acquired" |
| **calibrating** | Learning state | "calibrating..." |
| **deploy** | Installation | "Deploying 5 angles..." |

### Terms to AVOID

| Term | Why | Use Instead |
|------|-----|-------------|
| "bold tools" | Vague marketing | "5 angles. 1 attack." |
| "smart" | Overused | "precise", "fast" |
| "attack group" | Outdated | "angle" |
| "knowledge repo" | Generic | "intel source" |
| "learning" | Passive | "calibrating" |
| "vector" | Military jargon | "angle" |

---

## Detailed Inventory

### 1. README.md

| Line | Element | Current | Proposed | Status |
|------|---------|---------|----------|--------|
| 1 | Title | `# aOa - Angle O(1)f Attack` | Keep | ✅ Aligned |
| 5 | Tagline | `Same cost for 100 files or 100,000.` | Keep | ✅ Aligned |
| 43 | Section | "How It Works" | "The Five Angles" | 🟡 Change |
| 47 | Intro | "Five attack groups with 15+ methods" | "5 angles converging to 1 attack" | 🟡 Change |
| 47-54 | Groups | Search, Intent, Knowledge, Ranking, Prediction | Symbol, Intent, Intel, Signal, Strike Angles | 🟡 Change |
| 61 | Section | "The Numbers" | "Hit Rate" | 🟡 Change |
| 66 | Metric | "Accuracy: ~70%" | "Hit rate: ~70%" | 🟡 Change |
| 70 | Section | "Quick Start" | "Deploy" | 🟡 Change |
| 89 | Status | `⚡ aOa 🟢 100%` | Keep | ✅ Aligned |
| 100 | Explain | "O = Big O notation. O(1) constant time." | Keep | ✅ Aligned |
| 101 | Explain | "Angle = The right approach." | "Angle = 5 approach methods" | 🟡 Change |
| 102 | Explain | "Attack = 5 groups, 15+ methods, converging..." | "Attack = The orchestration that combines angles" | 🟡 Change |
| 106 | Trust | "Runs locally... Open source" | Keep | ✅ Aligned |
| 115 | Closing | "The flat line wins." | Keep | ✅ Aligned |

### 2. CLI Help (`cli/aoa help`)

#### Header

| Element | Current | Proposed | Status |
|---------|---------|----------|--------|
| Title | `AOA` | Keep | ✅ Aligned |
| Subtitle | `Bold tools for Claude Code` | `5 angles. 1 attack.` | 🔴 Change |

#### Command Group Headers

| Current | Proposed | Status |
|---------|----------|--------|
| `STATUS COMMANDS` | `ATTACK STATUS` | 🟡 Change |
| `LOCAL SEARCH` | `SYMBOL ANGLE` | 🟡 Change |
| `PATTERN SEARCH` | `SIGNAL ANGLE` | 🟡 Change |
| `INTENT TRACKING` | `INTENT ANGLE` | 🟡 Change |
| `URL WHITELIST` | Keep | ✅ Aligned |
| `KNOWLEDGE REPOS` | `INTEL ANGLE` | 🟡 Change |
| `SYSTEM` | Keep | ✅ Aligned |

#### Command Descriptions

| Command | Current | Proposed | Status |
|---------|---------|----------|--------|
| `status` | "Show status line (context, cost, usage)" | "Show attack status (hit rate, intents)" | 🟡 Change |
| `search <term>` | "Find symbol/term in local codebase" | "O(1) symbol lookup" | 🟡 Change |
| `multi <t1,t2>` | "Multi-term search" | "Multi-angle search" | 🟡 Change |
| `changes` | "Recent file changes" | Keep | ✅ Aligned |
| `files` | "List indexed files" | Keep | ✅ Aligned |
| `pattern` | "Multi-pattern regex search" | Keep | ✅ Aligned |
| `intent recent` | "Recent intent records" | Keep | ✅ Aligned |
| `intent tags` | "All tags with file counts" | Keep | ✅ Aligned |
| `repo list` | "List knowledge repos" | "List intel sources" | 🟡 Change |
| `repo add` | "Clone and index a git repo" | "Add intel source" | 🟡 Change |
| `repo remove` | "Remove a knowledge repo" | "Remove intel source" | 🟡 Change |
| `health` | "Check all services" | "Check all angles" | 🟡 Change |

#### Philosophy Section

| Current | Proposed |
|---------|----------|
| "Local search is the default (your code)" | "Symbol angle is default (your code)" |
| "Knowledge repos are isolated reference material" | "Intel angle is isolated reference material" |
| "No mixing - repo code never pollutes local results" | "No mixing - intel never pollutes symbol results" |

### 3. Install Script (`install.sh`)

| Line | Current | Proposed | Status |
|------|---------|----------|--------|
| 30 | `⚡ aOa - Angle O(1)f Attack` | Keep | ✅ Aligned |
| 31 | `Installation Starting...` | `Deploying 5 angles...` | 🔴 Change |
| 158 | `Building Docker services...` | `Building attack surface...` | 🟡 Optional |
| 161 | `Starting services...` | `Deploying angles...` | 🟡 Change |
| 165 | `Waiting for services to be healthy...` | `Waiting for angles to align...` | 🟡 Optional |
| 197 | `⚡ aOa Installation Complete!` | `⚡ aOa Attack Ready!` | 🔴 Change |
| 202 | `aoa search <term>  Search your code` | `aoa search <term>  Symbol angle` | 🟡 Change |
| 203 | `aoa health  Check services` | `aoa health  Check angles` | 🟡 Change |

### 4. Status Line (`aoa-status.sh`)

| Element | Current | Proposed | Status |
|---------|---------|----------|--------|
| Brand | `⚡ aOa` | Keep | ✅ Aligned |
| Accuracy | `🟢 100%` | Keep (hit rate) | ✅ Aligned |
| Count | `136 intents` | Keep | ✅ Aligned |
| Tags | `editing python auth` | Keep | ✅ Aligned |
| Learning state | `learning...` | `calibrating...` | 🟡 Change |

### 5. CLAUDE.md

| Line | Element | Current | Proposed | Status |
|------|---------|---------|----------|--------|
| 1 | Title | `# aOa - AI Agent Instructions` | `# aOa - 5 Angles. 1 Attack.` | 🟡 Change |
| 3 | Critical | `CRITICAL: ...ALWAYS use aoa search` | Keep | ✅ Aligned |
| 58 | Rule #1 | "Search with aOa First" | "Symbol Angle First" | 🟡 Change |
| 78 | Rule #2 | "aOa Returns File:Line" | Keep | ✅ Aligned |
| 93 | Rule #3 | "One Search Replaces Many Greps" | "One Angle Replaces Many Tools" | 🟡 Change |
| 111 | Command | "Finding ANY code/symbol" | "Symbol angle lookup" | 🟡 Optional |
| 144 | Section | `## Intent Tracking` | Keep | ✅ Aligned |
| 146 | Status | "61 intents" | Keep | ✅ Aligned |

### 6. Docker/Services (docker-compose.yml)

| Element | Current | Status |
|---------|---------|--------|
| Gateway comment | "Gateway - Single entry point" | ✅ Aligned |
| Index comment | "Index - Codebase search and intent tracking" | ✅ Aligned |
| Status comment | "Status - Session metrics" | ✅ Aligned |
| Redis comment | "Redis - Hot-path storage" | ✅ Aligned |
| Proxy comment | "Proxy - Controlled internet access" | ✅ Aligned |
| Network comment | "Internal - NO internet access" | ✅ Aligned |
| Service names | `gateway`, `index`, `status`, `redis`, `proxy` | ✅ Aligned (internal) |

### 7. Source Code Docstrings

| File | Current | Status |
|------|---------|--------|
| `gateway.py` | "aOa Gateway - Single ingress point" | ✅ Aligned |
| `indexer.py` | "Codebase Indexer - Multi-Index Architecture" | ✅ Aligned |
| `status_service.py` | "aOa Status Service" | ✅ Aligned |

---

## What Does NOT Change

| Element | Reason |
|---------|--------|
| CLI command names (`aoa search`, `aoa intent`) | User muscle memory |
| API endpoint paths (`/symbol`, `/intent`) | Would break integrations |
| Docker service names | Internal architecture |
| Traffic light colors (🟢 🟡 🔴) | Universal understanding |
| Config paths (`.aoa/`) | Breaking change not worth it |
| "intents" in status line | Concrete metric, not abstract |
| "hit rate" terminology | Already attack-themed |

---

## Verified Line Numbers (Exact Locations)

### cli/aoa (Main CLI Script)

| Line | Current | Proposed | Category |
|------|---------|----------|----------|
| 2 | `# aoa - Bold tools for Claude Code` | `# aoa - 5 angles. 1 attack.` | Comment |
| 883 | `Bold tools for Claude Code` | `5 angles. 1 attack.` | Help header |
| 885 | `STATUS COMMANDS` | `ATTACK STATUS` | Section header |
| 892 | `LOCAL SEARCH (your project - default)` | `SYMBOL ANGLE (your project - default)` | Section header |
| 898 | `PATTERN SEARCH (agent-driven regex)` | `SIGNAL ANGLE (agent-driven regex)` | Section header |
| 903 | `INTENT TRACKING (semantic layer)` | `INTENT ANGLE (semantic layer)` | Section header |
| 915 | `KNOWLEDGE REPOS (isolated reference code)` | `INTEL ANGLE (isolated reference code)` | Section header |
| 633 | `aOa Service Map` | Keep (or `aOa Attack Map`) | Services banner |
| 665 | `CORE CAPABILITIES` | `THE FIVE ANGLES` | Services section |
| 668 | `⚡ SEARCH` | `⚡ SYMBOL ANGLE` | Capability |
| 671 | `🎯 INTENT` | `🎯 INTENT ANGLE` | Capability |
| 674 | `🧠 MEMORY` | `🧠 STRIKE ANGLE` | Capability |
| 677 | `📊 METRICS` | `📊 ATTACK STATUS` | Capability |
| 764 | `aOa Services` | `aOa Angles` | Health header |

### install.sh

| Line | Current | Proposed |
|------|---------|----------|
| 31 | `Installation Starting...` | `Deploying 5 angles...` |
| 158 | `Building Docker services...` | `Building attack surface...` |
| 161 | `Starting services...` | `Deploying angles...` |
| ~197 | `Installation Complete!` | `⚡ aOa Attack Ready!` |

### hooks/aoa-status.sh

| Line | Current | Proposed |
|------|---------|----------|
| ~71,80 | `learning...` | `calibrating...` |

---

## Implementation Checklist

### Phase 1: CLI Help Header & Subtitle (5 min)

- [ ] `cli/aoa:2` - Comment: → `# aoa - 5 angles. 1 attack.`
- [ ] `cli/aoa:883` - Help subtitle: → `5 angles. 1 attack.`

### Phase 2: CLI Section Headers (10 min)

- [ ] `cli/aoa:885` - STATUS COMMANDS → `ATTACK STATUS`
- [ ] `cli/aoa:892` - LOCAL SEARCH → `SYMBOL ANGLE`
- [ ] `cli/aoa:898` - PATTERN SEARCH → `SIGNAL ANGLE`
- [ ] `cli/aoa:903` - INTENT TRACKING → `INTENT ANGLE`
- [ ] `cli/aoa:915` - KNOWLEDGE REPOS → `INTEL ANGLE`

### Phase 3: CLI Services Map (10 min)

- [ ] `cli/aoa:665` - CORE CAPABILITIES → `THE FIVE ANGLES`
- [ ] `cli/aoa:668` - ⚡ SEARCH → `⚡ SYMBOL ANGLE`
- [ ] `cli/aoa:671` - 🎯 INTENT → `🎯 INTENT ANGLE`
- [ ] `cli/aoa:674` - 🧠 MEMORY → `🧠 STRIKE ANGLE`
- [ ] `cli/aoa:677` - 📊 METRICS → `📊 ATTACK STATUS`
- [ ] `cli/aoa:764` - aOa Services → `aOa Angles`

### Phase 4: Install Script (5 min)

- [ ] `install.sh:31` → `Deploying 5 angles...`
- [ ] `install.sh:158` → `Building attack surface...`
- [ ] `install.sh:161` → `Deploying angles...`
- [ ] `install.sh:~197` → `⚡ aOa Attack Ready!`

### Phase 5: Status Line (2 min)

- [ ] `hooks/aoa-status.sh` - `learning...` → `calibrating...`

### Phase 6: README.md (10 min)

- [ ] Section headers: "The Five Angles", "Hit Rate", "Deploy"
- [ ] Attack groups table → Angle names
- [ ] "Why aOa" definitions updated

### Phase 7: CLAUDE.md (5 min)

- [ ] Header: `5 Angles. 1 Attack.`
- [ ] Rule #1: "Symbol Angle First"
- [ ] Rule #3: "One Angle Replaces Many Tools"

### Phase 8: Verification

- [ ] `grep -r "Bold tools" .` → 0 results
- [ ] `grep -r "LOCAL SEARCH" cli/` → 0 results
- [ ] `grep -r "KNOWLEDGE REPOS" cli/` → 0 results
- [ ] `grep -rn "attack group" .` → 0 results
- [ ] Status line shows "intents" (intentional keep)
- [ ] Run `aoa help` - verify new headers
- [ ] Run `aoa services` - verify angle terminology
- [ ] Run `aoa health` - verify output

---

## Visual Diff Preview

### CLI Help (Before)

```
                              AOA
                       Bold tools for Claude Code

STATUS COMMANDS
  status                 Show status line (context, cost, usage)

LOCAL SEARCH (your project - default)
  search <term>          Find symbol/term in local codebase

PATTERN SEARCH (agent-driven regex)
  pattern '<json>'       Multi-pattern regex search

INTENT TRACKING (semantic layer)
  intent recent          Recent intent records

KNOWLEDGE REPOS (isolated reference code)
  repo list              List knowledge repos
```

### CLI Help (After)

```
                              AOA
                       5 angles. 1 attack.

ATTACK STATUS
  status                 Show attack status (hit rate, intents)

SYMBOL ANGLE (your project - default)
  search <term>          O(1) symbol lookup

SIGNAL ANGLE (agent-driven regex)
  pattern '<json>'       Multi-pattern regex search

INTENT ANGLE (semantic layer)
  intent recent          Recent intent records

INTEL ANGLE (isolated reference code)
  repo list              List intel sources
```

### Services Map (Before)

```
╔══════════════════════════════════════════════════════════════════════╗
║                         aOa Service Map                              ║
╠══════════════════════════════════════════════════════════════════════╣
║  CORE CAPABILITIES                                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║  ⚡ SEARCH         O(1) symbol lookup across codebase                ║
║  🎯 INTENT         Track tool calls, extract behavior patterns       ║
║  🧠 MEMORY         Dynamic working context for LLMs                  ║
║  📊 METRICS        Prediction accuracy, token savings                ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Services Map (After)

```
╔══════════════════════════════════════════════════════════════════════╗
║                         aOa Attack Map                               ║
╠══════════════════════════════════════════════════════════════════════╣
║  THE FIVE ANGLES                                                     ║
╠══════════════════════════════════════════════════════════════════════╣
║  ⚡ SYMBOL ANGLE   O(1) symbol lookup across codebase                ║
║  🎯 INTENT ANGLE   Track tool calls, extract behavior patterns       ║
║  🧠 STRIKE ANGLE   Predictive prefetch, dynamic context              ║
║  📊 ATTACK STATUS  Hit rate, prediction accuracy, token savings      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Health Output (Before → After)

```
# Before
aOa Services
  Index service: ✓ Running
  Status service: ✓ Running

# After
aOa Angles
  Symbol Angle (index): ✓ Running
  Status Angle: ✓ Running
```

---

## Prior Work (Archived)

These documents are superseded by this master reference:

- `.context/details/messaging-full-audit.md` - Original audit checklist
- `.context/details/messaging-unification-draft.md` - Concept exploration

---

## Approval

| Role | Status | Date |
|------|--------|------|
| Technical Review | Pending | - |
| User Approval | Pending | - |
| Implementation | Not Started | - |

---

*Generated 2026-01-06 | aOa Session 13*
