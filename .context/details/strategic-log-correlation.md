# Unified Logging Architecture Analysis

> **Date**: 2025-12-23
> **Author**: GH (Growth Hacker Agent)
> **Status**: CONFIRMED - Ready for Implementation

---

## Problem Statement

Two separate log sources exist:
1. **Claude session logs**: `~/.claude/projects/[project]/[session].jsonl` - Complete tool call history
2. **aOa intent logs**: In-memory SQLite via POST to `/intent` - What hooks captured

**Goal**: Correlate "Claude read file X" with "aOa predicted file X 2 seconds earlier"

---

## Claude Session Log Schema (Complete Analysis)

### File Naming Patterns

| Pattern | Example | Purpose |
|---------|---------|---------|
| UUID | `7963e601-6a3c-4e7a-b76c-5408c1e58d61.jsonl` | Main session file |
| Agent | `agent-a7947fd.jsonl` | Sub-agent/task spawned from main session |

### Event Types

| Type | Purpose | Key Fields |
|------|---------|------------|
| `summary` | Session summary | `summary`, `leafUuid` |
| `file-history-snapshot` | File backup state | `messageId`, `snapshot`, `trackedFileBackups` |
| `user` | User message | Full message object (see below) |
| `assistant` | Claude response | Full message object (see below) |

### Message Schema (User & Assistant)

```json
{
  "parentUuid": "00b5ad02-b527-40ec-9f65-b26402938ab1",  // Chain to previous message
  "isSidechain": false,                                   // Is this a sub-agent?
  "userType": "external",                                 // User type
  "cwd": "/home/corey/aOa",                              // Working directory
  "sessionId": "7963e601-6a3c-4e7a-b76c-5408c1e58d61",   // SESSION LINKAGE KEY
  "version": "2.0.76",                                    // Claude CLI version
  "gitBranch": "main",                                    // Git context
  "agentId": "a7947fd",                                   // Sub-agent ID (if applicable)
  "slug": "virtual-moseying-crown",                       // Session slug
  "type": "user" | "assistant",                           // Message type
  "message": { ... },                                     // Content
  "uuid": "7df31e08-8d75-4f5f-b9f8-8789b5d0e8a9",        // UNIQUE MESSAGE ID
  "timestamp": "2025-12-23T05:29:41.639Z",               // ISO timestamp
  "requestId": "req_011CWP4v7nqJCQmAWcUSgK5W"            // API request ID
}
```

### Tool Use Schema (in `message.content[]`)

```json
{
  "type": "tool_use",
  "id": "toolu_01V3ES2VfE4TopHgdCU6t9wQ",  // TOOL INVOCATION ID
  "name": "Read",                           // Tool name
  "input": {
    "file_path": "/home/corey/aOa/.context/BOARD.md"
  }
}
```

### Tool Result Schema (in `message.content[]`)

```json
{
  "tool_use_id": "toolu_01V3ES2VfE4TopHgdCU6t9wQ",  // Links to tool_use
  "type": "tool_result",
  "content": "..."                                    // Result content
}
```

### Extended Tool Result Metadata

```json
{
  "toolUseResult": {
    "type": "text",
    "file": {
      "filePath": "/home/corey/aOa/.context/BOARD.md",
      "content": "...",
      "numLines": 162,
      "startLine": 1,
      "totalLines": 162
    }
  }
}
```

---

## Linkage Fields Analysis

### Primary Keys for Correlation

| Field | Source | Uniqueness | Use For |
|-------|--------|------------|---------|
| `sessionId` | Claude | Per-session | **PRIMARY LINK** - Connect aOa to Claude session |
| `uuid` | Claude | Per-message | Individual message tracking |
| `parentUuid` | Claude | Per-message | Message chain reconstruction |
| `timestamp` | Both | Milliseconds | Temporal correlation |
| `agentId` | Claude | Per-sub-agent | Sub-agent work isolation |
| `tool_use.id` | Claude | Per-tool-call | Link tool invocation to result |

### Session ID Availability

The `sessionId` is available in:
- Every Claude message (user and assistant)
- Agent files (they reference parent session)
- **PostToolUse hook stdin** (CONFIRMED)

**CONFIRMED**: Claude's PostToolUse hook receives the following JSON via stdin:

```json
{
  "session_id": "abc123-uuid-here",           // REAL SESSION ID
  "transcript_path": "~/.claude/projects/.../session.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Read",
  "tool_input": { "file_path": "/path/to/file" },
  "tool_response": { "filePath": "/path/to/file", "success": true },
  "tool_use_id": "toolu_01ABC123..."          // EXACT CORRELATION KEY
}
```

**Critical Finding**: Both `session_id` AND `tool_use_id` are provided by Claude. This is the exact correlation key needed.

**Current Problem**: The intent-capture.py hook does NOT extract these fields. It generates its own via:
```python
SESSION_ID = os.environ.get("AOA_SESSION_ID", datetime.now().strftime("%Y%m%d"))
```

This is a date-based fallback, not the actual Claude session UUID.

---

## aOa Current Schema

### IntentRecord (in-memory)

```python
@dataclass
class IntentRecord:
    timestamp: int        # Unix timestamp (seconds)
    session_id: str       # Currently date-based, NOT Claude session
    tool: str             # Tool name (Read, Edit, etc.)
    files: List[str]      # Files accessed
    tags: List[str]       # Inferred intent tags
```

### POST /intent Payload

```json
{
  "session_id": "20251223",      // Date-based, NOT Claude session
  "tool": "Read",
  "files": ["/home/corey/aOa/file.py"],
  "tags": ["#python", "#reading"]
}
```

---

## Options Analysis

### Option A: aOa Writes to Same `.jsonl` Files

**Approach**: Append aOa events directly to Claude session files.

| Pros | Cons |
|------|------|
| Single source of truth | Requires file write access |
| No join at query time | May conflict with Claude's writes |
| Simple queries | Pollutes Claude's format |
| | Need to match Claude's schema exactly |
| | Risk of corruption |

**Risk Level**: HIGH - Claude owns those files, appending could break things.

### Option B: aOa Writes Parallel Files in Same Directory

**Approach**: Create `aoa-[sessionId].jsonl` alongside Claude's files.

| Pros | Cons |
|------|------|
| Clear separation | Still need sessionId from Claude |
| No conflict with Claude | Two files to query per session |
| Same directory = easy correlation | Requires write access to ~/.claude |
| | More complex deployment |

**Implementation**:
```
~/.claude/projects/-home-corey-aOa/
  7963e601-6a3c-4e7a-b76c-5408c1e58d61.jsonl     # Claude
  aoa-7963e601-6a3c-4e7a-b76c-5408c1e58d61.jsonl # aOa
```

**Risk Level**: MEDIUM - Need sessionId from hooks, write access concerns.

### Option C: Keep Separate, Join via sessionId + Timestamp

**Approach**: aOa keeps its own storage, join at query time using sessionId and timestamp.

| Pros | Cons |
|------|------|
| No filesystem coupling | Still need real sessionId from hooks |
| aOa controls own format | Join complexity at query time |
| Clean separation of concerns | Need to sync schemas for correlation |
| Can optimize for our queries | Two data sources to maintain |

**Implementation**:
```python
# At query time:
claude_events = read_jsonl(f"~/.claude/projects/.../session.jsonl")
aoa_events = query_sqlite(f"SELECT * FROM intents WHERE session_id = ?")
merged = correlate_by_timestamp(claude_events, aoa_events, window_ms=5000)
```

**Risk Level**: LOW - Clean separation, but need sessionId.

### Option D: Capture Full Context at Hook Time (RECOMMENDED)

**Approach**: Enhance hooks to capture Claude's sessionId from environment/stdin, store rich context.

| Pros | Cons |
|------|------|
| Get real sessionId at capture time | Requires hook enhancement |
| aOa logs are self-contained | Slight parsing overhead |
| No write to Claude's files | Need to discover sessionId source |
| Easy correlation | |
| Can add prediction metadata | |

**Implementation**:

1. **Discover sessionId source**: Claude hooks receive JSON via stdin - check if sessionId is included
2. **Enhanced IntentRecord**:
```python
@dataclass
class IntentRecord:
    timestamp: int
    timestamp_ms: int           # Millisecond precision
    session_id: str             # Real Claude sessionId
    tool: str
    tool_use_id: str            # Claude's toolu_xxx ID if available
    files: List[str]
    tags: List[str]
    prediction_made: bool       # Did we predict this file?
    prediction_confidence: float # If so, what confidence?
```

3. **Query for correlation**:
```python
# Find predictions that preceded actual reads
SELECT
    p.file, p.confidence, p.timestamp as predicted_at,
    r.timestamp as read_at,
    (r.timestamp - p.timestamp) as delta_ms
FROM predictions p
JOIN intents r ON p.session_id = r.session_id AND p.file = r.files
WHERE r.tool = 'Read'
  AND r.timestamp > p.timestamp
  AND r.timestamp < p.timestamp + 60000  -- Within 60 seconds
```

**Risk Level**: LOW - Self-contained, clean, optimal.

---

## Recommendation: Option D (Enhanced Capture)

### Why Option D?

1. **Self-contained**: aOa doesn't depend on reading Claude's files
2. **Real-time**: Correlation happens at capture, not query
3. **Predictive**: We can store "did we predict this?" with each intent
4. **Metrics-ready**: Hit rate calculation is trivial
5. **No filesystem coupling**: Works across different environments

### Implementation Sketch

#### Step 1: Extract sessionId from Hook Input (CONFIRMED AVAILABLE)

Claude's PostToolUse hook provides via stdin:

| Field | Type | Use For |
|-------|------|---------|
| `session_id` | string | Primary session linkage |
| `tool_use_id` | string | Exact tool call correlation |
| `transcript_path` | string | Path to Claude's session log |
| `tool_name` | string | Tool type (Read, Edit, etc.) |
| `tool_input` | object | Tool parameters |
| `tool_response` | object | Tool result |

**Update intent-capture.py to extract these:**

```python
def main():
    raw = sys.stdin.read()
    data = json.loads(raw)

    # NEW: Extract Claude's correlation keys
    session_id = data.get('session_id', datetime.now().strftime("%Y%m%d"))
    tool_use_id = data.get('tool_use_id')
    transcript_path = data.get('transcript_path')

    tool = data.get('tool_name', data.get('tool', 'unknown'))
    # ... rest of processing
```

#### Step 2: Enhance IntentRecord

```python
@dataclass
class IntentRecord:
    timestamp: int              # Unix seconds
    timestamp_ms: int           # Unix milliseconds (for correlation)
    session_id: str             # Claude's UUID sessionId
    uuid: str                   # Our generated UUID for this record
    tool: str                   # Tool name
    tool_use_id: Optional[str]  # Claude's toolu_xxx if available
    files: List[str]            # Files accessed
    tags: List[str]             # Inferred tags
    # Prediction tracking
    predicted: bool             # Was this file predicted?
    prediction_id: Optional[str] # Which prediction matched?
    prediction_confidence: Optional[float]  # Confidence at prediction time
```

#### Step 3: Prediction-Intent Linkage

When a prediction is made:
```python
# Store prediction
prediction = {
    "id": uuid4(),
    "session_id": session_id,
    "timestamp_ms": time.time() * 1000,
    "files": ["file1.py", "file2.py"],
    "confidences": [0.85, 0.72],
    "expires_at": timestamp_ms + 60000  # 60s TTL
}
redis.set(f"prediction:{session_id}:latest", prediction)
```

When an intent is captured:
```python
# Check if this was predicted
prediction = redis.get(f"prediction:{session_id}:latest")
if prediction and any(f in prediction["files"] for f in files):
    record.predicted = True
    record.prediction_id = prediction["id"]
    record.prediction_confidence = prediction["confidences"][idx]
```

#### Step 4: Metrics Query

```python
def calculate_hit_rate(session_id: str, window_minutes: int = 60):
    """Calculate Hit@5 for a session."""
    predictions = get_predictions(session_id, since=window_minutes)
    actuals = get_intents(session_id, since=window_minutes, tool="Read")

    hits = 0
    for pred in predictions:
        top5 = pred["files"][:5]
        actual_files = [i.files for i in actuals if i.timestamp_ms > pred.timestamp_ms]
        if any(f in top5 for f in actual_files):
            hits += 1

    return hits / len(predictions) if predictions else 0
```

---

## Next Steps

1. **Verify sessionId availability**: Debug hook input to find Claude's sessionId
2. **Enhance IntentRecord**: Add millisecond timestamp, prediction tracking fields
3. **Implement prediction storage**: Redis with TTL for active predictions
4. **Add correlation logic**: Link predictions to actual reads at capture time
5. **Build metrics endpoint**: `/metrics/hit_rate?session=X&window=60`

---

## Key Files to Modify

| File | Change |
|------|--------|
| `/home/corey/aOa/src/hooks/intent-capture.py` | Extract sessionId, add prediction lookup |
| `/home/corey/aOa/src/index/indexer.py` | Enhanced IntentRecord schema |
| `/home/corey/aOa/src/hooks/intent-prefetch.py` | Store predictions with IDs |
| `/home/corey/aOa/src/ranking/scorer.py` | Add prediction ID generation |

---

## Summary

| Option | Risk | Complexity | Coupling | Recommended |
|--------|------|------------|----------|-------------|
| A: Same file | HIGH | Low | Tight | No |
| B: Parallel files | MEDIUM | Medium | Medium | No |
| C: Join at query | LOW | High | Loose | Maybe |
| **D: Enhanced capture** | **LOW** | **Medium** | **None** | **Yes** |

**Option D** gives us self-contained, metrics-ready logging with no filesystem coupling to Claude's internals. The main prerequisite is discovering how to get the real `sessionId` from Claude's hook interface.

---

## CONFIRMED: Complete Linkage Strategy

### The Golden Path

```
Claude Tool Call                      aOa Capture
================                      ===========

1. Claude decides to Read file
   |
   v
2. PostToolUse hook fires ---------> 3. intent-capture.py receives:
   (stdin JSON)                          - session_id (Claude's UUID)
                                         - tool_use_id (toolu_xxx)
                                         - tool_name, tool_input

                                      4. aOa records IntentRecord with:
                                         - session_id (real UUID)
                                         - tool_use_id (exact correlation)
                                         - files, tags (derived)

                                      5. Check prediction cache:
                                         - Was this file predicted?
                                         - At what confidence?
                                         - Mark as hit/miss
```

### Correlation Queries

**Query 1**: "Was this file predicted before it was read?"
```python
SELECT
    i.session_id,
    i.tool_use_id,
    i.files[0] as file_read,
    p.files as files_predicted,
    p.confidence,
    (i.timestamp_ms - p.timestamp_ms) as prediction_lead_ms
FROM intents i
LEFT JOIN predictions p ON
    i.session_id = p.session_id AND
    i.files[0] IN p.files AND
    p.timestamp_ms < i.timestamp_ms AND
    p.timestamp_ms > i.timestamp_ms - 60000  -- 60s window
WHERE i.tool = 'Read'
```

**Query 2**: "Calculate Hit@5 for session"
```python
def hit_at_5(session_id):
    predictions = get_predictions(session_id)
    reads = get_reads(session_id)

    hits = 0
    for pred in predictions:
        top5 = pred.files[:5]
        # Find reads within 60s after this prediction
        future_reads = [r for r in reads
                        if r.timestamp_ms > pred.timestamp_ms
                        and r.timestamp_ms < pred.timestamp_ms + 60000]
        if any(r.file in top5 for r in future_reads):
            hits += 1

    return hits / len(predictions) if predictions else 0.0
```

---

## Implementation Checklist

| Step | File | Change | Priority |
|------|------|--------|----------|
| 1 | `intent-capture.py` | Extract `session_id`, `tool_use_id` from stdin JSON | P0 |
| 2 | `indexer.py` | Add `tool_use_id` to IntentRecord dataclass | P0 |
| 3 | `/intent` endpoint | Accept `tool_use_id` in POST body | P0 |
| 4 | Redis | Store predictions keyed by `session_id` | P1 |
| 5 | `intent-capture.py` | Check prediction cache on capture | P1 |
| 6 | `/metrics/hit_rate` | New endpoint for accuracy metrics | P2 |

---

## Sources

- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [GitHub Issue #6403 - PostToolUse Testing](https://github.com/anthropics/claude-code/issues/6403)
