# aOa Enrich - Batch Semantic Enrichment

> **Purpose**: Enrich code outlines with AI-generated semantic tags
> **Trigger**: `aoa enrich` or "enrich the codebase with aOa"

---

## Overview

This skill batch-processes files that need semantic enrichment. It:
1. Queries `/outline/pending` for files needing enrichment
2. Batches files into groups of 15
3. Spawns Haiku tasks to generate semantic tags
4. Marks files enriched via `/outline/enriched`

**Idempotent**: Re-running picks up where you left off.

---

## Execution Steps

### Step 1: Check Pending Files

```bash
curl -s localhost:8080/outline/pending
```

Parse the response to get:
- `pending_count`: Number of files needing enrichment
- `pending`: Array of file objects with `file`, `language`, `reason`

If `pending_count` is 0, report "All files are up to date" and exit.

### Step 2: Batch and Process

Group pending files into batches of 15. For each batch:

1. **Get outlines** for each file in the batch:
   ```bash
   curl -s "localhost:8080/outline?file=<filepath>"
   ```

2. **Spawn a Haiku task** to analyze the batch and generate tags:

   ```
   Task(
     subagent_type="general-purpose",
     model="haiku",
     prompt="Analyze these code outlines and generate 2-5 semantic tags per file..."
   )
   ```

3. **Mark files enriched** after processing:
   ```bash
   curl -s -X POST localhost:8080/outline/enriched \
     -H "Content-Type: application/json" \
     -d '{"file": "<filepath>"}'
   ```

### Step 3: Report Progress

After each batch, report:
- Files processed in this batch
- Total progress (e.g., "15/45 files enriched")
- Any errors encountered

---

## Haiku Prompt Template

When spawning Haiku tasks for tag generation, use this prompt:

```
You are analyzing code structure to generate semantic tags.

For each file below, examine the symbols (functions, classes, methods) and generate 2-5 semantic tags that describe:
- What the code DOES (e.g., "authentication", "file-parsing", "api-routing")
- The DOMAIN it belongs to (e.g., "database", "ui", "networking")
- Key PATTERNS used (e.g., "singleton", "factory", "middleware")

Output format - one line per file:
<filepath>: tag1, tag2, tag3

FILES TO ANALYZE:

[Insert outline data here]
```

---

## Error Handling

- **API unreachable**: Report "aOa services not running. Run `aoa health` to check."
- **File outline fails**: Skip file, continue with batch, report at end
- **Haiku task fails**: Retry once, then skip batch and continue

---

## Example Session

```
User: aoa enrich

Claude: Checking pending enrichment...

Found 45 files needing enrichment.
Processing in 3 batches of 15.

**Batch 1/3** (15 files)
- services/index/indexer.py: indexing, search, file-watching
- services/gateway/gateway.py: api-routing, proxy, health-check
...
Marked 15 files as enriched.

**Batch 2/3** (15 files)
...

**Batch 3/3** (15 files)
...

Enrichment complete: 45 files processed.
```

---

## Quick Commands

| Command | Description |
|---------|-------------|
| `aoa enrich` | Run full enrichment |
| `aoa outline --pending` | Check pending count |
| `aoa health` | Verify services running |
