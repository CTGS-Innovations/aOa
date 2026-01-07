# aOa - Work Board

> **Updated**: 2026-01-07 (Session 14 ACTIVE) | **Phase**: 5 - Go Live
> **Goal**: Public release with clean plugin + Docker distribution
> **Archive**: Phases 1-4 complete → `.context/archive/2026-01-06-phases-1-4-complete.md`
> **Current**: GL-007 revised → Plugin + Unified Docker approach

---

## Active Tasks

| # | Task | Status | Deps | Notes |
|---|------|--------|------|-------|
| GL-007 | Deployment Strategy | **REVISED** | - | Plugin + Unified Docker |
| GL-009 | Project Restructure | **NEXT** | GL-007 | plugin/, services/, cli/ |
| GL-010 | Unified Dockerfile | Queued | GL-009 | Single image, all services |
| GL-011 | Plugin Manifest | Queued | GL-009 | plugin.json, marketplace.json |
| GL-008 | Fresh System Test | Queued | GL-010, GL-011 | Test on clean machine |
| GL-003 | Token Calculator | Queued | GL-008 | HTML/JS, embed in README |
| GL-005 | Landing Page | Queued | GL-008 | One-pager with outcomes |
| GL-002 | Demo GIFs | Queued | GL-008 | Storyboards ready |
| P4-006 | 90% Accuracy | Ongoing | - | Background tuner learning

**Next Action**: GL-009 - Restructure project into clean layout

---

## GL-007: Deployment Strategy (REVISED)

**Previous Decision**: Docker Compose + install.sh (git clone approach)
**Problem**: Clobbers user's project, brings entire repo

**New Decision**: Plugin Marketplace + Unified Docker Image

### Distribution Model

```
┌─────────────────────────────────────────────────────────────┐
│                     User Installation                        │
├─────────────────────────────────────────────────────────────┤
│  1. /plugin marketplace add corey/aoa                       │
│  2. /plugin install aoa@aoa-marketplace                     │
│  3. /aoa:setup  (or: docker run aoa/aoa)                   │
└─────────────────────────────────────────────────────────────┘
```

### What Gets Distributed

| Component | Via | Contains |
|-----------|-----|----------|
| **Plugin** | Marketplace | hooks, skills, agents, commands |
| **Docker** | Docker Hub | all backend services, CLI |

### User Flow

```bash
# Claude Code plugin (hooks, skills, agents)
/plugin marketplace add corey/aoa
/plugin install aoa@aoa-marketplace

# Backend services (one command)
docker run -d -p 8080:8080 -v $(pwd):/codebase aoa/aoa

# Or via plugin command
/aoa:setup
```

### Trust Options

```bash
# Pre-built (convenience)
docker pull aoa/aoa

# Build yourself (trust)
git clone https://github.com/corey/aoa
docker build -t aoa .
```

---

## GL-009: Project Restructure

**Goal**: Clean separation of concerns

### Current (Messy)
```
├── .claude/          # Mixed with project
├── src/              # Services scattered
├── cli/
├── scripts/
└── (everything in root)
```

### Target (Clean)
```
aoa/
├── plugin/                      # Claude Code Plugin
│   ├── .claude-plugin/
│   │   ├── plugin.json
│   │   └── marketplace.json
│   ├── commands/
│   │   ├── setup.md
│   │   └── health.md
│   ├── agents/
│   ├── skills/
│   └── hooks/
│
├── services/                    # Backend (Docker)
│   ├── gateway/
│   ├── index/
│   ├── status/
│   └── ranking/
│
├── cli/                         # CLI tool
│   └── aoa
│
├── Dockerfile                   # Unified single image
├── docker-compose.yml           # Dev only
└── README.md
```

### Benefits
- Plugin is self-contained in `plugin/`
- Services grouped for Docker
- No confusion between hook types
- Marketplace points to `plugin/` subdirectory

---

## GL-010: Unified Dockerfile

**Goal**: Single Docker image with all services

```dockerfile
# All services in one image
# - Gateway
# - Index
# - Status
# - Redis (embedded)
# Process manager: supervisord or s6-overlay
```

**Distribution**:
- Docker Hub: `aoa/aoa:latest`
- GitHub Actions auto-publish on release

---

## GL-011: Plugin Manifest

**plugin.json**:
```json
{
  "name": "aoa",
  "description": "5 angles. 1 attack. Cut Claude Code costs by 2/3.",
  "version": "1.0.0",
  "author": { "name": "Corey" }
}
```

**marketplace.json**:
```json
{
  "name": "aoa-marketplace",
  "owner": { "name": "Corey" },
  "plugins": [{
    "name": "aoa",
    "source": ".",
    "description": "Angle of Attack - fast code search",
    "version": "1.0.0"
  }]
}
```

---

## Completed (This Phase)

| # | Task | Output | Date |
|---|------|--------|------|
| GL-001 | README Rewrite | Outcome-focused messaging | 2025-12-27 |
| GL-004 | Imagery | 3 Gemini images, neon cyan theme | 2025-12-27 |
| GL-006 | Messaging Unification | 5 angles branding | 2026-01-06 |
| - | Hook Rename | aoa-*.py naming convention | 2026-01-06 |
| - | Skill Rename | aoa.md (full reference) | 2026-01-06 |

---

## Key Results (All Phases)

| Metric | Value |
|--------|-------|
| Token Savings | 68% |
| Speed vs grep | 74x faster |
| Hit Rate | ~70% (target: 90%) |
| Benchmark Accuracy | 100% top-1 |

---

## Confidence Legend

| Signal | Meaning | Action |
|--------|---------|--------|
| 🟢 | Confident | Proceed freely |
| 🟡 | Uncertain | Try once, then research |
| 🔴 | Lost | STOP, use 131 agent |
