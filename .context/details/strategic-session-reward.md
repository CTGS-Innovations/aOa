# Claude Session Logs as Reward Signal

**Date**: 2025-12-23
**Status**: Discovery Complete - Ready for Implementation
**Impact**: Dramatically simplifies Phase 3-4 by providing ground truth

---

## Discovery

Claude Code stores complete session logs at:
```
~/.claude/projects/[project-slug]/[session-id].jsonl
```

Where:
- `project-slug` = cwd path with `/` replaced by `-` (e.g., `-home-corey-aOa`)
- `session-id` = UUID or `agent-[hash]` for sub-agents

---

## File Types

### 1. Main Session Files (`[uuid].jsonl`)
Contains metadata and file history snapshots:
```json
{"type":"summary","summary":"aOa setup, hooks integration, port fix","leafUuid":"4bb..."}
{"type":"file-history-snapshot","messageId":"...","snapshot":{
  "trackedFileBackups":{
    "docker-compose.yml":{"backupFileName":"f2063...@v1","version":1,"backupTime":"..."},
    "install.sh":{"backupFileName":"d94c5...@v1","version":1,"backupTime":"..."}
  }
}}
```

**Extractable**: List of all files modified during session with timestamps.

### 2. Agent Files (`agent-[hash].jsonl`)
Contains complete conversation with tool calls:
```json
{"type":"user","message":{"role":"user","content":"..."}}
{"type":"assistant","message":{
  "content":[
    {"type":"tool_use","id":"toolu_...","name":"Read","input":{"file_path":"/path/to/file.py"}}
  ],
  "usage":{"input_tokens":3,"output_tokens":1}
}}
{"type":"user","message":{"role":"user","content":[
  {"tool_use_id":"toolu_...","type":"tool_result","content":"file contents..."}
]}}
```

**Extractable**: Every tool call with parameters.

---

## Schema: Tool Use Events

### Read Tool
```json
{
  "type": "tool_use",
  "id": "toolu_01QRJggwyC3mCNkgTExktNrK",
  "name": "Read",
  "input": {
    "file_path": "/home/corey/aOa/.context/BOARD.md",
    "offset": 1,      // optional
    "limit": 100      // optional
  }
}
```

### Write Tool
```json
{
  "type": "tool_use",
  "id": "toolu_01PFi6woX95asSCBhjVh9dvY",
  "name": "Write",
  "input": {
    "file_path": "/home/corey/aOa/.context/BOARD.md",
    "content": "..."
  }
}
```

### Edit Tool
```json
{
  "type": "tool_use",
  "name": "Edit",
  "input": {
    "file_path": "/path/to/file.py",
    "old_string": "original text",
    "new_string": "replacement text"
  }
}
```

### Glob Tool
```json
{
  "type": "tool_use",
  "name": "Glob",
  "input": {
    "pattern": "**/*.py",
    "path": "/home/corey/aOa"
  }
}
```

### Grep Tool
```json
{
  "type": "tool_use",
  "name": "Grep",
  "input": {
    "pattern": "function_name",
    "path": "/home/corey/aOa",
    "glob": "*.py"
  }
}
```

---

## Extractable Data

| Data Point | Source | Use for Scoring |
|------------|--------|-----------------|
| Files read | `tool_use.name="Read"` | Ground truth for predictions |
| Files written | `tool_use.name="Write"` | High-value files |
| Files edited | `tool_use.name="Edit"` | High-value files |
| Search patterns | `Grep/Glob` patterns | Intent signals |
| Read order | Timestamp sequence | Transition probabilities |
| Session context | `sessionId` | Group related reads |
| Git branch | `gitBranch` field | Context clustering |
| Token usage | `usage.input_tokens` | File importance proxy |

---

## Reward Signal Design

### Current Plan (Complex)
```
Phase 3: NLP keyword extraction -> semantic matching
Phase 4: Store predictions, wait 5 min, compare to intents, gradient descent
```

### New Plan (Simple - Ground Truth)
```
1. Parse Claude session logs (exists, free, complete)
2. Extract file access patterns (Read, Write, Edit)
3. Build transition matrix: P(file_B | file_A was read)
4. Reward = prediction matched actual Claude Read
5. No NLP, no semantic matching, no self-reported metrics
```

---

## Implementation: Session Log Parser

### Core Extractor
```python
import json
from pathlib import Path
from collections import defaultdict
from datetime import datetime

class SessionLogParser:
    def __init__(self, project_path: str):
        self.project_slug = project_path.replace('/', '-')
        self.base_path = Path.home() / '.claude' / 'projects' / self.project_slug

    def parse_session(self, session_file: Path) -> list[dict]:
        """Extract tool use events from session file."""
        events = []
        with open(session_file) as f:
            for line in f:
                entry = json.loads(line)
                if entry.get('type') == 'assistant':
                    content = entry.get('message', {}).get('content', [])
                    for item in content:
                        if item.get('type') == 'tool_use':
                            events.append({
                                'tool': item['name'],
                                'input': item['input'],
                                'timestamp': entry['timestamp'],
                                'session_id': entry.get('sessionId'),
                                'agent_id': entry.get('agentId')
                            })
        return events

    def extract_file_reads(self, events: list[dict]) -> list[str]:
        """Get ordered list of files read."""
        return [
            e['input']['file_path']
            for e in events
            if e['tool'] == 'Read'
        ]

    def extract_file_writes(self, events: list[dict]) -> list[str]:
        """Get list of files written/edited."""
        return [
            e['input']['file_path']
            for e in events
            if e['tool'] in ('Write', 'Edit')
        ]

    def build_transition_matrix(self) -> dict[str, dict[str, int]]:
        """Build file transition counts across all sessions."""
        transitions = defaultdict(lambda: defaultdict(int))

        for session_file in self.base_path.glob('agent-*.jsonl'):
            events = self.parse_session(session_file)
            files = self.extract_file_reads(events)

            for i in range(len(files) - 1):
                from_file = files[i]
                to_file = files[i + 1]
                transitions[from_file][to_file] += 1

        return dict(transitions)
```

### Redis Integration
```python
def sync_to_redis(transitions: dict, redis_client):
    """Store transition counts in Redis for real-time scoring."""
    for from_file, to_files in transitions.items():
        key = f"transitions:{from_file}"
        for to_file, count in to_files.items():
            redis_client.zadd(key, {to_file: count})
```

### Prediction Scoring
```python
def score_prediction(predicted: list[str], actual: list[str]) -> dict:
    """Calculate Hit@K metrics."""
    actual_set = set(actual)

    return {
        'hit_at_1': 1 if predicted[0] in actual_set else 0,
        'hit_at_3': 1 if any(p in actual_set for p in predicted[:3]) else 0,
        'hit_at_5': 1 if any(p in actual_set for p in predicted[:5]) else 0,
        'precision_at_5': len(set(predicted[:5]) & actual_set) / 5,
        'recall_at_5': len(set(predicted[:5]) & actual_set) / len(actual_set) if actual_set else 0
    }
```

---

## Simplified Phase 3-4 Roadmap

### Phase 3: File Transition Model (replaces semantic matching)
| Task | Description | Confidence |
|------|-------------|------------|
| P3-001 | Session log parser | Green - straightforward JSON parsing |
| P3-002 | Transition matrix builder | Green - counts in Redis sorted sets |
| P3-003 | `/context` uses transitions | Green - ZRANGE on transition keys |
| P3-004 | Background sync daemon | Yellow - needs scheduling approach |

### Phase 4: Ground Truth Feedback (replaces gradient descent)
| Task | Description | Confidence |
|------|-------------|------------|
| P4-001 | Compare predictions to actual reads | Green - set intersection |
| P4-002 | Hit@5 metric calculation | Green - simple math |
| P4-003 | Weight adjustment via hit rate | Yellow - Thompson Sampling still good |
| P4-004 | Dashboard showing metrics | Green - `/metrics` endpoint |

---

## Key Insight

**Before**: We were going to build complex feedback loops with:
- Self-reported predictions stored in Redis
- 5-minute delay for evaluation
- Gradient descent on weights
- NLP for semantic matching

**After**: Claude already logs everything we need:
- Ground truth file access (Read events)
- Exact timestamps and order
- Session context (what files are accessed together)
- No self-reporting, no delays, no NLP

---

## Data Access Pattern

```
1. Scheduled job (every 5 min or on session end)
   -> Parse new session logs
   -> Update transition matrix in Redis
   -> Calculate rolling accuracy metrics

2. On prediction request
   -> Current files (from intent) -> Redis transition lookup
   -> Rank by transition probability
   -> Return top K predictions

3. On evaluation
   -> Compare last N predictions to last N actual reads
   -> Update Hit@5 rolling average
   -> Adjust weights if below threshold
```

---

## File Locations Summary

| Data | Location | Format |
|------|----------|--------|
| Session logs | `~/.claude/projects/-home-corey-aOa/agent-*.jsonl` | JSONL |
| File history | `~/.claude/projects/-home-corey-aOa/[uuid].jsonl` | JSONL with snapshots |
| Transition cache | Redis `transitions:{file}` | Sorted set |
| Accuracy metrics | Redis `metrics:hit_at_5` | Time series |

---

## Next Steps

1. **Immediate**: Build `SessionLogParser` class in `/src/ranking/session_parser.py`
2. **Today**: Add background sync to populate transitions
3. **Phase 3**: Update `/context` to use transition probabilities
4. **Phase 4**: Dashboard showing prediction accuracy vs ground truth

This discovery reduces Phase 3-4 complexity by ~60% while improving accuracy (ground truth > self-reported).
