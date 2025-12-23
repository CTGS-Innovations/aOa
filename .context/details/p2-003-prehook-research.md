# P2-003 Research: PreHook stdout Parsing

> **Date**: 2025-12-23 | **Agent**: 131 | **Status**: Complete

## Problem

How does Claude Code parse PreHook stdout? What format should intent-prefetch.py output for Claude to understand predicted files?

## Three Solutions Evaluated

### Solution 1: Plain Text stdout
- Just `print()` your context
- Output visible in transcript as "hook output"
- Simplest but least discrete

### Solution 2: JSON additionalContext (RECOMMENDED)
- Return structured JSON with `hookSpecificOutput.additionalContext`
- Discrete injection (no "hook output" label)
- Official documented API

### Solution 3: system-reminder XML
- Wrap in `<system-reminder>` tags
- Matches Claude Code's internal format
- Undocumented, may break

## Recommendation: Solution 2

```python
#!/usr/bin/env python3
"""UserPromptSubmit hook - JSON additionalContext injection"""
import sys
import json
import requests

def get_predictions():
    try:
        resp = requests.get("http://localhost:8080/predict?limit=5", timeout=1)
        return resp.json().get('files', [])
    except:
        return []

def main():
    try:
        data = json.load(sys.stdin)
    except:
        data = {}

    predictions = get_predictions()

    if predictions:
        # Build context string
        context_lines = ["## Predicted Relevant Files", ""]
        for f in predictions:
            context_lines.append(f"- `{f['path']}` (confidence: {f['confidence']:.0%})")
        context_lines.append("")
        context_lines.append("Consider reading these files if relevant to the task.")

        context = "\n".join(context_lines)

        # Output structured JSON
        output = {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": context
            }
        }
        print(json.dumps(output))

    sys.exit(0)

if __name__ == "__main__":
    main()
```

## Key Implementation Notes

1. **Exit code matters**: Always exit 0. Exit code 2 ignores stdout.
2. **Timeout**: Default 60s, but aim for <100ms UX
3. **Current intent-prefetch.py is wrong**: It's PreToolUse but should be UserPromptSubmit
4. **Hook types**:
   - PreToolUse: Fires before each tool call
   - UserPromptSubmit: Fires once per user message (better for initial context)

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Blog - How to Configure Hooks](https://claude.com/blog/how-to-configure-hooks)
- [Claude Code Hooks Mastery (GitHub)](https://github.com/disler/claude-code-hooks-mastery)

## Confidence After Research

**GREEN** - Format is clear, ready for implementation.
