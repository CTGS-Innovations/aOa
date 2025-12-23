# aOa Context Intelligence - Beacon

> **Session**: 01 | **Date**: 2025-12-23
> **Phase**: 1 - Redis Scoring Engine

---

## Now

Starting Phase 1: Implement Redis scoring infrastructure in `/src/ranking/`.

## Active

| # | Task | Solution Pattern | C | R |
|---|------|------------------|---|---|
| P1-001 | Create ranking package structure | New `/src/ranking/` with `redis_client.py`, `scorer.py` | 🟢 | - |

## Blocked

- None

## Next

1. Create `redis_client.py` with sorted set operations
2. Modify `intent-capture.py` to write scores on each intent
3. Add decay mechanism via Lua script
4. Add `/rank` endpoint to indexer

## Key Files

```
src/hooks/intent-capture.py   # Writes intents, needs to write scores
src/hooks/intent-prefetch.py  # PreHook, currently outputs nothing
src/index/indexer.py          # Main API, needs /rank endpoint
docker-compose.yml            # Redis already running
```

## Resume Command

```bash
aoa health  # Verify services running
# Then: Create /home/corey/aOa/src/ranking/redis_client.py
```
