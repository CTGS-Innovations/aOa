# aOa - Session Beacon

> **Session**: 14 (ACTIVE) | **Date**: 2026-01-07
> **Phase**: 5 - Go Live (Public Release)

---

## Resume Here

**Task**: GL-009 Project Restructure

**Goal**: Clean separation → plugin/, services/, cli/

**Decision Made**: Plugin Marketplace + Unified Docker (not git clone)

---

## Session 14 Summary

**Completed**:
- GL-007 Deployment Strategy Research (REVISED)
  - Discovered Claude Code has formal plugin system
  - Plugin = marketplace distribution (no git clone needed)
  - MCP not needed for hooks (plugin handles it)
  - Single Docker image simplifies backend
- Hook rename (aoa-*.py convention)
- Skill rename (aoa.md)

**New Plan**:
```
User Installation:
1. /plugin marketplace add corey/aoa
2. /plugin install aoa@aoa-marketplace
3. docker run aoa/aoa (or /aoa:setup)
```

**Next Tasks**:
- GL-009: Restructure project
- GL-010: Unified Dockerfile
- GL-011: Plugin manifest
- GL-008: Test on fresh system

---

## GL-007 Evolution

| Stage | Approach | Problem |
|-------|----------|---------|
| Initial | Docker Compose + install.sh | Clobbers project |
| MCP idea | MCP server bootstrap | Can't configure hooks |
| **Final** | Plugin + Docker Hub | Clean, no clobber |

---

## Target Structure

```
aoa/
├── plugin/           # Claude Code Plugin (marketplace)
│   ├── .claude-plugin/
│   ├── commands/
│   ├── agents/
│   ├── skills/
│   └── hooks/
├── services/         # Backend (Docker image)
│   ├── gateway/
│   ├── index/
│   ├── status/
│   └── ranking/
├── cli/              # CLI tool
├── Dockerfile        # Unified image
└── README.md
```

---

## Test System Ready

Fresh machine available for testing:
- Option A: Develop here, test there
- Option B: Migrate source of truth to new system

**Recommendation**: Develop here (keep history), test on fresh system

---

## Active Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| GL-009 | Project Restructure | **NEXT** | plugin/, services/, cli/ |
| GL-010 | Unified Dockerfile | Queued | Single image |
| GL-011 | Plugin Manifest | Queued | plugin.json |
| GL-008 | Fresh System Test | Queued | Test installation |

---

## Key Files

```
.context/BOARD.md                    # Updated with new plan
plugin/                              # To be created
services/                            # To be created (from src/)
Dockerfile                           # To be created (unified)
```
