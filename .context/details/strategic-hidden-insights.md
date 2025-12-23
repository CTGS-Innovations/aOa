# Session Data Mining: Hidden Value in Claude Code Logs

> **Date**: 2025-12-23
> **Purpose**: Extract hidden signals from Claude Code session logs that could enhance aOa
> **Location**: `~/.claude/projects/[project]/[session].jsonl`

---

## Part 1: Complete Field Inventory

### Session-Level Metadata

Every entry contains these session-level fields:

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| `sessionId` | UUID | `7963e601-6a3c-4e7a-b76c-5408c1e58d61` | Main session identifier |
| `agentId` | String | `ad88469` | Sub-agent identifier (for spawned agents) |
| `version` | Semver | `2.0.76` | Claude Code version |
| `cwd` | Path | `/home/corey/aOa` | Current working directory |
| `gitBranch` | String | `main` | Active git branch |
| `uuid` | UUID | Unique message ID | Links to parentUuid for threading |
| `parentUuid` | UUID/null | Parent message in thread | Enables conversation tree reconstruction |
| `timestamp` | ISO8601 | `2025-12-23T13:38:56.679Z` | Precise timing for every event |
| `type` | Enum | `user`, `assistant`, `summary`, `file-history-snapshot` | Message type discriminator |
| `isSidechain` | Boolean | `true` | Whether this is a sub-agent conversation |
| `userType` | String | `external` | User context type |
| `slug` | String | `virtual-moseying-crown` | Session slug (human-readable identifier) |

### Entry Types

1. **`type: "summary"`** - Session summary
   ```json
   {
     "type": "summary",
     "summary": "aOa Intent Capture & Hook Display System",
     "leafUuid": "235e8192-f077-43ee-9af6-85d6424c468a"
   }
   ```

2. **`type: "file-history-snapshot"`** - File version tracking
   ```json
   {
     "type": "file-history-snapshot",
     "messageId": "...",
     "isSnapshotUpdate": false,
     "snapshot": {
       "trackedFileBackups": {
         "docker-compose.yml": {
           "backupFileName": "f2063c422b1336c0@v2",
           "version": 2,
           "backupTime": "2025-12-22T21:37:45.422Z"
         }
       }
     }
   }
   ```

3. **`type: "user"`** - User messages
   ```json
   {
     "type": "user",
     "message": {
       "role": "user",
       "content": "Hey GH - Design Feature..."
     }
   }
   ```

4. **`type: "assistant"`** - Claude responses with rich metadata
   ```json
   {
     "type": "assistant",
     "requestId": "req_011CWPiDzTNJFUotqt1xDPTv",
     "message": { /* full API response */ }
   }
   ```

### Usage Object (Critical for Token Economics)

Every assistant message contains detailed token accounting:

```json
"usage": {
  "input_tokens": 3,
  "cache_creation_input_tokens": 9617,
  "cache_read_input_tokens": 0,
  "cache_creation": {
    "ephemeral_5m_input_tokens": 9617,
    "ephemeral_1h_input_tokens": 0
  },
  "output_tokens": 5,
  "service_tier": "standard"
}
```

| Field | Meaning | Value for aOa |
|-------|---------|---------------|
| `input_tokens` | Fresh tokens sent to API | **Cost driver** - minimize this |
| `cache_creation_input_tokens` | Tokens added to cache | Investment for future reads |
| `cache_read_input_tokens` | Tokens read from cache (10% cost) | **Savings** - maximize this |
| `ephemeral_5m_input_tokens` | 5-minute cache tokens | Short-term cache effectiveness |
| `ephemeral_1h_input_tokens` | 1-hour cache tokens | Long-term cache effectiveness |
| `output_tokens` | Tokens generated | Generation cost |
| `service_tier` | API tier | `standard` / `priority` |

### Tool Use Content Structure

```json
{
  "type": "tool_use",
  "id": "toolu_01Qa2W5UUGbxyP6mr3US6i6U",
  "name": "Read",
  "input": {"file_path": "/home/corey/aOa/.context/CURRENT.md"}
}
```

### Tool Result Structure (Rich File Metadata!)

```json
{
  "type": "tool_result",
  "tool_use_id": "toolu_01PxbQdj8yZ4niArsBKKVgP8",
  "content": "...",
  "toolUseResult": {
    "type": "text",
    "file": {
      "filePath": "/home/corey/aOa/.context/BOARD.md",
      "content": "...",
      "numLines": 167,
      "startLine": 1,
      "totalLines": 167
    }
  }
}
```

### Web Search Result Structure

```json
{
  "toolUseResult": {
    "query": "Python TF-IDF text matching...",
    "results": [
      {"url": "...", "title": "..."}
    ],
    "durationSeconds": 24.696331520000008
  }
}
```

### Model Switching Detection

The `message.model` field tracks which model was used:
- `claude-haiku-4-5-20251001` - Fast/cheap
- `claude-opus-4-5-20251101` - Expensive/powerful

### Stop Reason Detection

```json
"stop_reason": "tool_use"  // Indicates more work coming
"stop_reason": null        // Mid-stream
"stop_reason": "end_turn"  // Complete response
```

---

## Part 2: Signals We Are NOT Using

### Currently Ignored High-Value Signals

| Signal | Available | Status | Potential Use |
|--------|-----------|--------|---------------|
| **Token cost per file** | Yes (calculated) | IGNORED | Predict expensive reads |
| **Cache hit ratio** | Yes (cache_read vs input) | IGNORED | Optimize prefetch timing |
| **Tool call duration** | Yes (timestamps) | IGNORED | Detect slow operations |
| **WebSearch duration** | Yes (`durationSeconds`) | IGNORED | Network latency patterns |
| **File line counts** | Yes (`numLines`, `totalLines`) | IGNORED | Predict token cost |
| **Re-read patterns** | Yes (same file multiple times) | IGNORED | Detect confusion |
| **Stop reasons** | Yes (`stop_reason`) | IGNORED | Predict multi-turn cost |
| **Model switching** | Yes (`message.model`) | IGNORED | Cost/quality tradeoffs |
| **Session duration** | Yes (timestamp deltas) | IGNORED | Fatigue detection |
| **Error patterns** | Yes (error content) | IGNORED | Learn from failures |
| **User interruptions** | Yes (`[Request interrupted by user]`) | IGNORED | Detect poor responses |
| **Git branch context** | Yes (`gitBranch`) | IGNORED | Branch-specific patterns |
| **Sub-agent spawning** | Yes (`isSidechain`, `agentId`) | IGNORED | Agent usage patterns |
| **Parent-child threading** | Yes (`parentUuid`) | IGNORED | Conversation reconstruction |
| **File backup versions** | Yes (`file-history-snapshot`) | IGNORED | Edit frequency patterns |
| **Request IDs** | Yes (`requestId`) | IGNORED | API correlation |
| **Cache type (5m vs 1h)** | Yes (`ephemeral_*`) | IGNORED | Cache tier optimization |

### Error Patterns Available

```
"[Request interrupted by user]" - User stopped the response
Tool errors show in content
File not found patterns
Permission errors
```

---

## Part 3: Innovative Use Cases for aOa

### Tier 1: Token Economics (P0 - Immediate Value)

#### 1. Token Cost Predictor
**Signal**: `numLines`, `totalLines`, historical token-per-line ratios
**Use**: Before reading a file, predict token cost
**Formula**: `predicted_tokens = numLines * avg_tokens_per_line[file_extension]`
**Action**: Warn user if file will consume >X% of context window

#### 2. Cache Efficiency Dashboard
**Signal**: `cache_read_input_tokens` vs `input_tokens` over time
**Use**: Show "cache hit rate" as a percentage
**Formula**: `cache_efficiency = cache_read / (cache_read + input) * 100`
**Action**: Display in status line: `cache:87%`

#### 3. Prefetch ROI Calculator
**Signal**: Files aOa predicted + cache hit rate on those files
**Use**: Prove aOa value in $ saved
**Formula**: `savings = predicted_cache_hits * tokens * (1 - 0.1) * $0.00X`
**Action**: Show "aOa saved $X.XX this session"

#### 4. Context Window Pressure Indicator
**Signal**: `input_tokens` + `cache_creation_input_tokens` trends
**Use**: Predict context exhaustion before it happens
**Action**: Warn at 70%, 85%, 95% of context limit

### Tier 2: Behavioral Intelligence (P1 - Near-Term Value)

#### 5. Confusion Detector
**Signal**: Same file read 3+ times in short window without edits
**Pattern**: Read A -> Read B -> Read A -> Read A (3 reads of A)
**Use**: Claude is confused or file is complex
**Action**: Surface file as "needs documentation" or offer help

#### 6. Error Pattern Learning
**Signal**: Tool calls that result in error content
**Use**: Learn which patterns fail (e.g., "permission denied on /etc/*")
**Action**: Pre-warn on likely failures, suggest alternatives

#### 7. User Interruption Analysis
**Signal**: `[Request interrupted by user]` patterns
**Use**: Which responses get cut off?
**Insight**: Long responses? Wrong direction? Missing context?
**Action**: Tune response length, ask clarifying questions earlier

#### 8. Model Switching Intelligence
**Signal**: When users switch from Haiku to Opus (or vice versa)
**Pattern**: Haiku fails -> switch to Opus
**Use**: Predict when task needs more powerful model
**Action**: Suggest model switch before user does

### Tier 3: Session Intelligence (P1 - Medium-Term Value)

#### 9. Session Fatigue Detection
**Signal**: Response quality degradation over session length
**Metrics**:
  - Error rate increasing
  - Re-reads increasing
  - User interruptions increasing
**Use**: Suggest session break or context refresh
**Action**: "Consider starting a fresh session for better results"

#### 10. Branch-Specific Patterns
**Signal**: `gitBranch` + file access patterns
**Use**: Different branches have different hot files
**Action**: Pre-weight predictions based on active branch

#### 11. Agent Spawn Effectiveness
**Signal**: `isSidechain` + outcome quality
**Use**: Which agent types (131, GH, Beacon) produce best results?
**Action**: Recommend appropriate agent for task type

### Tier 4: Predictive Features (P2 - Future Value)

#### 12. Next-File Prediction from Conversation
**Signal**: User message content + subsequent Read calls
**ML Model**: Train on (prompt_embedding -> file_accessed)
**Use**: Before any tool call, predict likely files
**Action**: Pre-fetch with very high confidence

#### 13. Token Budget Optimization
**Signal**: Historical cost per task type
**Use**: Predict total session cost before starting
**Action**: "This type of task typically uses ~50k tokens ($X.XX)"

#### 14. Multi-Session Learning
**Signal**: Patterns across sessions on same project
**Use**: Learn project-specific patterns over time
**Action**: First session is learning, subsequent sessions are optimized

#### 15. Edit Frequency Prediction
**Signal**: `file-history-snapshot` backup patterns
**Use**: Files edited frequently are "hot" for writes
**Action**: Suggest pre-reading frequently-edited files

---

## Part 4: Implementation Priorities

### P0: Ship This Week (Immediate ROI)

| Feature | Effort | Value | Dependency |
|---------|--------|-------|------------|
| Token cost per file tracking | 2h | High | P1-done |
| Cache efficiency % in status | 2h | High | Redis working |
| Prefetch hit tracking | 3h | High | P2-003 predictions |
| Simple cost savings display | 2h | Medium | Token tracking |

### P1: Next Sprint (Near-Term Value)

| Feature | Effort | Value | Dependency |
|---------|--------|-------|------------|
| Confusion detector (re-reads) | 4h | Medium | P1 intents |
| User interruption logging | 2h | Medium | Intent capture |
| Error pattern collection | 3h | Medium | Intent capture |
| Context pressure warning | 3h | High | Token tracking |

### P2: Future (Longer-Term Value)

| Feature | Effort | Value | Dependency |
|---------|--------|-------|------------|
| Model switching intelligence | 8h | Medium | Multi-session data |
| Session fatigue detection | 8h | Medium | Quality metrics |
| Branch-specific patterns | 6h | Medium | Git integration |
| Prompt-to-file ML model | 20h | High | Significant data |

---

## Part 5: Competitive Advantages

### What We Can Do That Others Cannot

| Capability | Why Unique | Competitive Moat |
|------------|------------|------------------|
| **Real token economics** | We see actual API responses | No other tool has this data |
| **Cache optimization** | We know cache hit rates | Invisible to users normally |
| **Prefetch verification** | We predict + verify | Provable ROI |
| **Cross-session learning** | We persist history | Builds over time |
| **Branch-aware predictions** | We see git context | Project-specific intelligence |
| **Error learning** | We see failures | Avoid repeated mistakes |

### How This Makes aOa Smarter Over Time

```
Week 1: Learn file access patterns (reactive)
Week 2: Predict with basic signals (proactive)
Week 4: Tune weights from hit rate (adaptive)
Week 8: Cross-session patterns (intelligent)
Week 12: Prompt-to-file prediction (prescient)
```

### Data Advantage

We accumulate:
1. **Token costs per file** - Build a token prediction model
2. **Cache patterns** - Optimize prefetch timing
3. **Error patterns** - Avoid repeated failures
4. **Conversation patterns** - Predict from prompts

This compounds over time. The more aOa is used, the smarter it gets.

---

## Part 6: Schema Reference

### Full Entry Types

```typescript
type SessionEntry =
  | SummaryEntry
  | FileHistorySnapshot
  | UserMessage
  | AssistantMessage;

interface SummaryEntry {
  type: "summary";
  summary: string;
  leafUuid: string;
}

interface FileHistorySnapshot {
  type: "file-history-snapshot";
  messageId: string;
  isSnapshotUpdate: boolean;
  snapshot: {
    messageId: string;
    timestamp: string;
    trackedFileBackups: Record<string, FileBackup>;
  };
}

interface FileBackup {
  backupFileName: string | null;
  version: number;
  backupTime: string;
}

interface UserMessage {
  type: "user";
  uuid: string;
  parentUuid: string | null;
  timestamp: string;
  sessionId: string;
  agentId?: string;
  version: string;
  cwd: string;
  gitBranch: string;
  isSidechain: boolean;
  userType: string;
  slug?: string;
  message: {
    role: "user";
    content: string | ToolResult[];
  };
  toolUseResult?: ToolUseResult;
}

interface AssistantMessage {
  type: "assistant";
  uuid: string;
  parentUuid: string;
  timestamp: string;
  sessionId: string;
  agentId?: string;
  version: string;
  cwd: string;
  gitBranch: string;
  isSidechain: boolean;
  userType: string;
  slug?: string;
  requestId: string;
  message: {
    model: string;
    id: string;
    type: "message";
    role: "assistant";
    content: (TextContent | ToolUseContent)[];
    stop_reason: "tool_use" | "end_turn" | null;
    stop_sequence: string | null;
    usage: UsageStats;
  };
}

interface UsageStats {
  input_tokens: number;
  cache_creation_input_tokens: number;
  cache_read_input_tokens: number;
  cache_creation: {
    ephemeral_5m_input_tokens: number;
    ephemeral_1h_input_tokens: number;
  };
  output_tokens: number;
  service_tier: "standard" | "priority";
}

interface ToolUseContent {
  type: "tool_use";
  id: string;
  name: string;
  input: Record<string, unknown>;
}

interface ToolUseResult {
  type: "text";
  file?: {
    filePath: string;
    content: string;
    numLines: number;
    startLine: number;
    totalLines: number;
  };
  query?: string;  // For WebSearch
  results?: unknown[];
  durationSeconds?: number;
}
```

---

## Appendix: Sample Extraction Queries

### Get all file reads with token costs
```python
# Pseudocode
for entry in session:
    if entry.type == "assistant" and has_tool_use(entry):
        tool = get_tool_use(entry)
        if tool.name == "Read":
            file_path = tool.input.file_path
            tokens = entry.message.usage.input_tokens
            log(file_path, tokens)
```

### Calculate cache efficiency
```python
cache_reads = sum(e.message.usage.cache_read_input_tokens for e in session)
fresh_reads = sum(e.message.usage.input_tokens for e in session)
efficiency = cache_reads / (cache_reads + fresh_reads) * 100
```

### Detect re-read patterns (confusion)
```python
from collections import Counter
file_reads = [get_file_path(e) for e in session if is_read(e)]
read_counts = Counter(file_reads)
confused_files = [f for f, count in read_counts.items() if count >= 3]
```

---

## Next Steps

1. **Immediate**: Add token tracking to intent-capture.py
2. **This week**: Implement cache efficiency calculation
3. **Next sprint**: Build confusion detector
4. **Phase 3**: Add to status line display
5. **Phase 4**: ML on prompt-to-file correlation

This data is gold. We're sitting on signals no one else has access to.
