# P2-005 Research: UserPromptSubmit Hook

> **Date**: 2025-12-23 | **Agent**: 131 | **Status**: Complete

## Problem

How does UserPromptSubmit hook work in Claude Code? How to trigger predictions on prompt submission?

## Key Findings

### 1. Configuration Already Exists

aOa already has UserPromptSubmit hooked in `.claude/settings.local.json`:
```json
"UserPromptSubmit": [{
  "hooks": [{
    "type": "command",
    "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/intent-summary.py\"",
    "timeout": 2
  }]
}]
```

### 2. Input Payload Schema

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/home/corey/aOa",
  "permission_mode": "default",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "The user's actual prompt text"
}
```

### 3. Output Format for Context Injection

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Your predicted context here"
  }
}
```

### 4. Environment Variables Available

- `CLAUDE_PROJECT_DIR` - project root
- `AOA_URL` - already defined in existing hooks

## Recommended Implementation

```python
#!/usr/bin/env python3
"""UserPromptSubmit hook - Predictive prefetch"""
import sys
import json
import os
import re
from urllib.request import urlopen

AOA_URL = os.environ.get("AOA_URL", "http://localhost:8080")

def extract_keywords(prompt: str) -> list:
    """Extract likely file/symbol keywords from prompt."""
    stopwords = {'the', 'and', 'for', 'that', 'this', 'with', 'from', 'have', 'what', 'how'}
    words = re.findall(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', prompt.lower())
    return [w for w in words if w not in stopwords and len(w) > 2][:10]

def main():
    data = json.load(sys.stdin)
    prompt = data.get("prompt", "")

    keywords = extract_keywords(prompt)
    if not keywords:
        sys.exit(0)

    try:
        url = f"{AOA_URL}/predict?tags={','.join(keywords)}&limit=5"
        response = urlopen(url, timeout=1.5)
        predictions = json.loads(response.read())
    except:
        sys.exit(0)

    files = predictions.get("files", [])
    if not files:
        sys.exit(0)

    context_parts = ["## aOa Predicted Files"]
    for f in files:
        context_parts.append(f"- `{f['path']}` ({f['confidence']:.0%})")

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": "\n".join(context_parts)
        }
    }
    print(json.dumps(output))
    sys.exit(0)

if __name__ == "__main__":
    main()
```

## Implementation Notes

1. **Known bug**: Use absolute paths with `$CLAUDE_PROJECT_DIR`
2. **Timeout**: 2 seconds configured, aim for <100ms
3. **Dependency**: Needs P2-002 `/predict` endpoint first
4. **Combine with P2-003**: Both tasks consume same endpoint

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Hooks Mastery (GitHub)](https://github.com/disler/claude-code-hooks-mastery)
- [UserPromptSubmit Bug Issue #8810](https://github.com/anthropics/claude-code/issues/8810)

## Confidence After Research

**GREEN** - Infrastructure exists, format documented, ready for implementation.
