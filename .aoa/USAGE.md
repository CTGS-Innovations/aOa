# aOa - Fast Code Intelligence

> **Core Principle:** aOa finds exact locations so you read only what you need.
> Instead of 3,700 tokens for a whole file, read 200 tokens for the relevant function.

---

## Quick Reference

| I want to... | Command | Scope | Speed |
|--------------|---------|-------|-------|
| Find a symbol | `aoa search handleAuth` | Full index | <1ms |
| Find files with ANY term | `aoa search "auth token"` | Full index | <5ms |
| Find files with ALL terms | `aoa multi auth,token,session` | Full index | ~3ms |
| Search with regex | `aoa pattern '{"match": "TODO"}'` | Working set | ~3ms |
| See file structure | `aoa outline src/auth.js` | Single file | ~5ms |
| Find by semantic tag | `aoa search "#authentication"` | Tagged files | <1ms |

**Scope definitions:**
- **Full index**: All indexed files in project (hundreds/thousands)
- **Working set**: Local/recently accessed files (~30-50)
- **Tagged files**: Files processed by `aoa-outline` agent

---

## When You Need to Find Code Fast

**Goal:** Locate where something is implemented

**Use:** `aoa search <term>` or spawn `aoa-scout` agent

```bash
aoa search "handleAuth"           # Single term
aoa search "auth session token"   # Multi-term ranked (OR search)
```

**Result:** Exact file:line in <5ms (not slow grep scanning)

---

## When You Need to Understand Architecture

**Goal:** Explore patterns, understand how components connect

**Use:** Spawn `aoa-explore` agent

**Result:** Thorough analysis using indexed symbols, understands relationships

---

## When You Need File Structure

**Goal:** See functions/classes without reading the whole file

**Use:** `aoa outline <file>`

```bash
aoa outline src/auth/handler.py
```

**Result:** Symbol map with line ranges - read only what matters

---

## When You Want Semantic Search

**Goal:** Search by concept (#auth, #routing) not just text matches

**Use:** Spawn `aoa-outline` agent (runs in background)

**Result:** AI-tagged symbols searchable by purpose and domain

---

## Available Agents

| Agent | Model | Use When |
|-------|-------|----------|
| `aoa-scout` | haiku | Quick searches: "where is X?" |
| `aoa-explore` | sonnet | Deep dives: "how does auth work?" |
| `aoa-outline` | haiku | Background tagging for semantic search |

---

## How Search Works

**Three search modes:**

### 1. Symbol Lookup (O(1) - instant, full index)

**Single term** - exact symbol match:
```bash
aoa search handleAuth              # finds "handleAuth" symbol
```

**Multi-term (space-separated)** - OR search, ranked by relevance:
```bash
aoa search "auth session token"    # finds symbols matching ANY term, ranked
```
**Note:** This is NOT phrase search. `"auth session"` won't find the exact phrase - it finds files containing "auth" OR "session", ranked by match quality.

### 2. Multi-Term Intersection (full index)

**Comma-separated** - AND search, files must contain ALL terms:
```bash
aoa multi auth,session,token       # files must contain all three terms
```
Use this when you need intersection, not union.

### 3. Pattern Search (regex - working set only)

Pattern search scans **local/recent files only** (~30-50 files), not the full index.
Use this for regex matching within your current working context.

```bash
aoa pattern '{"match": "TODO|FIXME"}'            # regex in working set
aoa pattern '{"func": "async\\s+function"}'      # function patterns
```

**Scope limitation:** For full-codebase pattern search, use:
```bash
aoa search TODO                    # symbol lookup (full index, O(1))
# OR
grep -r "pattern" .                # traditional grep (slower but complete)
```

---

## Tokenization Rules

`aoa search` tokenizes on word boundaries. Understanding this prevents "0 hits" surprises:

| Pattern | Tokens | How to Search |
|---------|--------|---------------|
| `tree_sitter` | `tree_sitter` | `aoa search tree_sitter` |
| `tree-sitter` | `tree`, `sitter` | `aoa search tree` or `aoa multi tree,sitter` |
| `treeSitter` | `treeSitter` | `aoa search treeSitter` |
| `app.post` | `app`, `post` | `aoa pattern '{"match": "app\\.post"}'` |
| `module.exports` | `module`, `exports` | `aoa search exports` or `aoa multi module,exports` |

**Tip:** When searching for hyphenated or dot-notation terms, use `aoa multi` with comma separation:
```bash
aoa multi voice,app               # finds "voice-app", "voice_app", etc.
```

---

## Common Mistakes

### Expecting phrase/proximity search
```bash
# What users try:
aoa search "error handling"        # expects exact phrase

# What actually happens:
# Finds symbols matching "error" OR "handling", ranked by relevance

# What to use instead:
aoa multi error,handling           # files containing BOTH terms
aoa pattern '{"match": "error.*handling"}'  # regex (working set only)
```

### Using pattern for full codebase search
```bash
# What users try:
aoa pattern '{"match": "module\\.exports"}'  # expects all 700+ files

# What actually happens:
# Only scans ~30-50 local/recent files

# What to use instead:
aoa search exports                 # symbol lookup (full index)
aoa multi module,exports           # intersection search
```

### Searching for dot-notation patterns
```bash
# What users try:
aoa search app.post                # fails - dot breaks tokenization

# What to use instead:
aoa pattern '{"match": "app\\.post"}'  # regex (escape the dot)
aoa search post                    # then filter results manually
```

---

## Rules

1. **Always use `aoa search`** - Never Grep or Glob
2. **Always use `aoa outline`** - Never raw curl to API
3. **Read specific lines** - Use file:line from search results, don't read whole files
4. **Use underscores in search** - Hyphens and dots split tokens
5. **Use `aoa multi` for AND** - Space-separated is OR, comma-separated is AND

---

## The Value

| Without aOa | With aOa |
|-------------|----------|
| Grep scans entire codebase | Indexed O(1) lookup |
| Read whole files (3,700 tokens) | Read exact lines (200 tokens) |
| Slow pattern matching | <5ms symbol search |
| Text matches only | Semantic tags (#auth, #routing) |

---

## Troubleshooting

### "0 hits" for a term I know exists

1. **Check tokenization:** Hyphens and dots break tokens
   - `app.post` → search for `post` or use `aoa pattern`
   - `my-component` → search for `component` or use `aoa multi my,component`
2. **Try `aoa multi`** with individual words
3. **Use `aoa pattern`** for exact string matching (working set only)

### Pattern search returns fewer results than expected

Pattern search only scans working set (~30-50 files). For full codebase:
- Use `aoa search` for symbol lookup
- Use traditional `grep -r` for exhaustive pattern matching

### Predictions showing low confidence (30-40%)

This is normal during cold start. Accuracy improves as:
- More intents are recorded (aim for 1000+)
- Semantic tags are added via `aoa-outline` agent
- Usage patterns establish file relationships

### Semantic search (#tags) not working

Run the `aoa-outline` agent to generate semantic tags:
```bash
# In Claude Code, spawn aoa-outline agent
# Or manually: aoa outline --store <file>
```

### File count looks wrong (API pagination)

The `/files` endpoint defaults to `limit=50`. For full count:
```bash
curl -s "localhost:8080/files?project=<id>&limit=1000" | jq '.results | length'
```

---

## Auto-Tag Requests (AUTOMATIC)

When you see `## aOa Auto-Tag Request` in hook output, you MUST:

1. Spawn a Haiku task with the prompt provided
2. Store the resulting tags via the curl command shown

Example:
```
Task(model="haiku", prompt="Generate 3-5 semantic hashtags...")
```

Then store:
```bash
curl -s -X POST localhost:8080/intent -H "Content-Type: application/json" -d '{"session_id": "...", "tags": ["#routing", "#auth"]}'
```

This builds semantic context automatically as you work. **Don't skip this.**
