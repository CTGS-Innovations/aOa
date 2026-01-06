# aOa - Session Beacon

> **Session**: 14 (ACTIVE) | **Date**: 2026-01-06
> **Phase**: 5 - Go Live (Public Release)

---

## Resume Here

**Task**: GL-008 Fresh Project Test

**Goal**: Test aOa deployment on a brand new project to validate install flow

**What We're Testing**:
1. `install.sh` runs cleanly on fresh machine/project
2. Docker services start correctly
3. CLI installs and works
4. Hooks get configured
5. Status line appears
6. CLAUDE.md template useful

---

## Session 14 Summary

**Completed**:
- GL-007 Deployment Strategy Research
  - Claude Code plugins = MCP servers only
  - MCP cannot configure hooks or status line
  - Decision: Docker Compose + Install Script (no MCP)

**In Progress**:
- GL-008 Fresh Project Test

**Blocked** (waiting on GL-008):
- GL-003 Token Calculator
- GL-005 Landing Page
- GL-002 Demo GIFs

**Ongoing**:
- P4-006 90% Accuracy (background tuner)

---

## GL-007 Decision Summary

| Option | Verdict | Reason |
|--------|---------|--------|
| MCP/Plugin | **Rejected** | Can't configure hooks, status line |
| Docker Compose | **Accepted** | Proven, handles all requirements |

**Deployment Flow**:
```bash
git clone https://github.com/you/aoa && cd aoa && ./install.sh
```

---

## Active Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| GL-008 | Fresh Project Test | **IN PROGRESS** | Testing deployment |
| GL-003 | Token Calculator | Queued | After GL-008 |
| GL-005 | Landing Page | Queued | After GL-008 |
| GL-002 | Demo GIFs | Queued | Storyboards ready |
| P4-006 | 90% Accuracy | Ongoing | Background tuner |

---

## Key Files

```
install.sh                                           # Main install script
.context/BOARD.md                                    # Master work board
cli/aoa                                              # CLI source
hooks/                                               # Hook scripts
```

---

## Test Commands

```bash
# In fresh project directory:
./install.sh                # Run full install
aoa health                  # Verify services
aoa search <term>           # Test symbol search
```
