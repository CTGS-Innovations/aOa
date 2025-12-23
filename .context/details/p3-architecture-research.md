# Phase 3 Architecture Research: Multi-Query Fusion

> **Date**: 2025-12-23
> **Agent**: GH (Growth Hacker)
> **Status**: Research Complete

---

## Problem Statement

Phase 3 adds natural language intent understanding to aOa:

```
User: aoa context "fix auth bug"
       |
       v
POST /context { "intent": "fix auth bug" }
       |
       v
[Keyword Extraction] -> [Tag Mapping] -> [File Ranking] -> [Snippet Extraction]
       |
       v
Response: { files: [...], snippets: [...], confidence: 0.85 }
```

Two tasks researched:
- **P3-001**: `/context` endpoint design
- **P3-005**: Caching layer for common intents

---

## P3-001: /context Endpoint Design

### Research Questions Answered

#### Q1: What response schema works best for code context retrieval?

Drawing from [GitHub's Code Search API](https://docs.github.com/en/rest/search/search), [Azure Cognitive Search](https://learn.microsoft.com/en-us/answers/questions/1687650/how-we-can-use-the-@search-score-and-@search-reran), and [Perplexity Search API](https://www.datacamp.com/tutorial/perplexity-search-api-tutorial):

**Best practices identified:**
1. Return ranked results with confidence/relevance scores
2. Include text fragments (snippets) with match positions
3. Provide metadata for each result (file type, last modified)
4. Include aggregate confidence for the overall response
5. Return processing time for debugging

#### Q2: How to combine /predict + snippet extraction?

The flow should be:

```
1. Parse intent -> extract keywords
2. Keywords -> map to tags (via tag_to_files index)
3. Tags -> call scorer.get_ranked_files(tags=tags)
4. For top N files -> extract relevant snippets
5. Bundle with confidence scores
```

### Recommended Request Schema

```json
POST /context
Content-Type: application/json

{
    "intent": "fix the auth bug in login",
    "limit": 5,
    "snippet_lines": 10,
    "threshold": 0.3
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `intent` | string | yes | - | Natural language description |
| `limit` | int | no | 5 | Max files to return |
| `snippet_lines` | int | no | 10 | Lines of context per snippet |
| `threshold` | float | no | 0.3 | Min confidence to include |

### Recommended Response Schema

```json
{
    "intent": "fix the auth bug in login",
    "keywords": ["auth", "bug", "login"],
    "tags_matched": ["authentication", "login", "python"],
    "files": [
        {
            "path": "src/auth/login.py",
            "confidence": 0.85,
            "score": {
                "composite": 78.5,
                "recency": 92.1,
                "frequency": 65.0,
                "tag_affinity": 88.3
            },
            "snippet": {
                "start_line": 45,
                "end_line": 55,
                "content": "def handle_login(username, password):\n    ...",
                "highlights": [
                    {"term": "login", "line": 45, "col": 11}
                ]
            },
            "metadata": {
                "language": "python",
                "last_modified": 1703289600,
                "size": 2048
            }
        }
    ],
    "aggregate": {
        "total_matches": 12,
        "returned": 5,
        "avg_confidence": 0.72,
        "cached": false
    },
    "ms": 45.2
}
```

### Implementation Approach

```python
@app.route('/context', methods=['POST'])
def context_search():
    """
    Natural language intent -> ranked files + snippets.

    Combines:
    - Keyword extraction from intent
    - Tag mapping via intent_index
    - File ranking via scorer
    - Snippet extraction via /file endpoint logic
    """
    start = time.time()
    data = request.json or {}

    intent = data.get('intent', '')
    limit = int(data.get('limit', 5))
    snippet_lines = int(data.get('snippet_lines', 10))
    threshold = float(data.get('threshold', 0.3))

    if not intent:
        return jsonify({'error': 'intent required'}), 400

    # Step 1: Extract keywords (simple approach first)
    keywords = extract_keywords(intent)

    # Step 2: Map keywords to tags
    tags_matched = map_keywords_to_tags(keywords, intent_index)

    # Step 3: Get ranked files
    if not RANKING_AVAILABLE or scorer is None:
        return jsonify({'error': 'Ranking not available'}), 503

    ranked = scorer.get_ranked_files(
        tags=tags_matched if tags_matched else None,
        limit=limit * 2  # Get extra for filtering
    )

    # Step 4: Filter by confidence threshold and extract snippets
    results = []
    for item in ranked:
        confidence = item.get('confidence', item['score'] / 100)
        if confidence < threshold:
            continue

        # Extract snippet
        snippet = extract_snippet(
            item['file'],
            keywords,
            snippet_lines
        )

        # Get file metadata
        local = manager.get_local()
        meta = local.files.get(item['file'], {})

        results.append({
            'path': item['file'],
            'confidence': round(confidence, 4),
            'score': {
                'composite': item['score'],
                'recency': item.get('recency', 0),
                'frequency': item.get('frequency', 0),
                'tag_affinity': sum(item.get('tags', {}).values()) / len(item.get('tags', {})) if item.get('tags') else 0
            },
            'snippet': snippet,
            'metadata': {
                'language': getattr(meta, 'language', 'unknown'),
                'last_modified': getattr(meta, 'mtime', 0),
                'size': getattr(meta, 'size', 0)
            }
        })

        if len(results) >= limit:
            break

    # Step 5: Build response
    avg_conf = sum(r['confidence'] for r in results) / len(results) if results else 0

    return jsonify({
        'intent': intent,
        'keywords': keywords,
        'tags_matched': tags_matched,
        'files': results,
        'aggregate': {
            'total_matches': len(ranked),
            'returned': len(results),
            'avg_confidence': round(avg_conf, 4),
            'cached': False  # Will be True when cache hits
        },
        'ms': round((time.time() - start) * 1000, 2)
    })
```

### Keyword Extraction (Simple Approach)

Based on research from [GeeksforGeeks](https://www.geeksforgeeks.org/nlp/keyword-extraction-methods-in-nlp/) and [Analytics Vidhya](https://www.analyticsvidhya.com/blog/2022/01/four-of-the-easiest-and-most-effective-methods-of-keyword-extraction-from-a-single-text-using-python/):

**Recommendation**: Start simple, no external dependencies.

```python
import re

# Common stopwords
STOPWORDS = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare',
    'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by', 'from', 'as',
    'into', 'through', 'during', 'before', 'after', 'above', 'below',
    'between', 'under', 'again', 'further', 'then', 'once', 'here',
    'there', 'when', 'where', 'why', 'how', 'all', 'each', 'few',
    'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not',
    'only', 'own', 'same', 'so', 'than', 'too', 'very', 'just',
    'and', 'but', 'if', 'or', 'because', 'until', 'while', 'this',
    'that', 'these', 'those', 'what', 'which', 'who', 'whom',
    'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him', 'her',
    'us', 'them', 'my', 'your', 'his', 'its', 'our', 'their',
    'fix', 'add', 'update', 'change', 'modify', 'implement', 'create',
    'make', 'get', 'set', 'find', 'look', 'check', 'help', 'want',
    'need', 'try', 'work', 'use', 'file', 'code', 'function', 'class'
}

def extract_keywords(text: str) -> List[str]:
    """
    Extract meaningful keywords from natural language intent.

    Simple approach: tokenize, lowercase, filter stopwords.
    Good enough for MVP, can upgrade to YAKE/RAKE in Phase 4.
    """
    # Tokenize: extract words
    tokens = re.findall(r'[a-zA-Z][a-zA-Z0-9_]*', text.lower())

    # Filter: remove stopwords, keep meaningful tokens
    keywords = [t for t in tokens if t not in STOPWORDS and len(t) > 2]

    # Dedupe while preserving order
    seen = set()
    unique = []
    for k in keywords:
        if k not in seen:
            seen.add(k)
            unique.append(k)

    return unique
```

**Future upgrade path** (Phase 4+): Replace with [YAKE](https://www.markovml.com/blog/yake-keyword-extraction) for better extraction:

```python
# Future: pip install yake
from yake import KeywordExtractor

def extract_keywords_yake(text: str, top_n: int = 5) -> List[str]:
    kw = KeywordExtractor(top=top_n, stopwords=STOPWORDS)
    keywords = kw.extract_keywords(text)
    return [kw for kw, score in keywords]
```

### Snippet Extraction

Reuse existing `/file` endpoint logic:

```python
def extract_snippet(file_path: str, keywords: List[str],
                    context_lines: int = 10) -> Optional[dict]:
    """
    Extract a code snippet containing keyword matches.

    Strategy:
    1. Read file content
    2. Find first line containing any keyword
    3. Extract context_lines around it
    4. Include highlight positions
    """
    local = manager.get_local()
    full_path = local.root / file_path

    if not full_path.exists():
        return None

    try:
        content = full_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')
    except Exception:
        return None

    # Find best matching line
    best_line = None
    best_score = 0
    highlights = []

    for i, line in enumerate(lines):
        line_lower = line.lower()
        score = sum(1 for kw in keywords if kw in line_lower)
        if score > best_score:
            best_score = score
            best_line = i
            # Record highlights
            highlights = []
            for kw in keywords:
                col = line_lower.find(kw)
                if col >= 0:
                    highlights.append({
                        'term': kw,
                        'line': i + 1,
                        'col': col
                    })

    if best_line is None:
        # No keyword match, return file start
        best_line = 0

    # Extract context
    half = context_lines // 2
    start = max(0, best_line - half)
    end = min(len(lines), best_line + half + 1)

    snippet_content = '\n'.join(lines[start:end])

    return {
        'start_line': start + 1,
        'end_line': end,
        'content': snippet_content,
        'highlights': highlights
    }
```

### Tag Mapping

```python
def map_keywords_to_tags(keywords: List[str],
                         intent_idx: IntentIndex) -> List[str]:
    """
    Map extracted keywords to existing tags.

    Strategy:
    1. Exact match: keyword == tag (without #)
    2. Partial match: keyword in tag or tag in keyword
    3. Return tags sorted by file count (popularity)
    """
    all_tags = intent_idx.all_tags()  # [(tag, count), ...]
    matched = []

    for tag, count in all_tags:
        tag_clean = tag.lstrip('#').lower()
        for kw in keywords:
            if kw == tag_clean or kw in tag_clean or tag_clean in kw:
                matched.append(tag_clean)
                break

    return matched[:10]  # Limit to top 10 tags
```

---

## P3-005: Caching Layer Design

### Research Questions Answered

#### Q1: What cache key strategy works best?

Based on [Redis semantic caching](https://redis.io/blog/what-is-semantic-caching/) and [Redis LangCache optimization](https://redis.io/blog/10-techniques-for-semantic-cache-optimization/):

**Options evaluated:**

| Strategy | Key Format | Pros | Cons |
|----------|------------|------|------|
| **Exact intent** | `context:{hash(intent)}` | Simple, fast | "fix auth" != "fix authentication" |
| **Normalized keywords** | `context:{sorted(keywords)}` | Catches rephrased queries | Loses intent nuance |
| **Semantic hash** | `context:{embedding_hash}` | Best matching | Requires embeddings (heavy) |

**Recommendation**: Start with **normalized keywords** (option 2).

Why:
- No embedding model dependency (keeps aOa lightweight)
- Catches common rephrases ("auth bug" == "bug auth")
- Simple to implement
- Can upgrade to semantic caching in Phase 4 if needed

#### Q2: How to handle partial matches?

Two-tier approach:

1. **Exact keyword match** (fast): Direct Redis lookup
2. **Subset match** (slower): Check if cached query's keywords are superset of current

```python
def get_cache_key(keywords: List[str]) -> str:
    """Generate cache key from sorted keywords."""
    normalized = sorted(set(kw.lower() for kw in keywords))
    return f"context:{':'.join(normalized)}"
```

#### Q3: What TTL duration?

Based on [adaptive TTL research](https://redis.io/blog/10-techniques-for-semantic-cache-optimization/):

| Data Type | Recommended TTL | Rationale |
|-----------|-----------------|-----------|
| Static queries | 24 hours | Codebase doesn't change often |
| Active development | 1 hour | Files change frequently |
| After file change | Invalidate | Stale snippets are worse than no cache |

**Recommendation**: Start with **1 hour TTL** (3600 seconds).

Why:
- Conservative for active development
- Balances freshness vs performance
- File watcher can invalidate on changes (Phase 4)

### Implementation

```python
# In redis_client.py - add cache methods

class RedisClient:
    # ... existing code ...

    PREFIX_CONTEXT_CACHE = "aoa:context_cache"

    def cache_context(self, keywords: List[str], result: dict,
                      ttl: int = 3600) -> bool:
        """
        Cache a context query result.

        Args:
            keywords: Extracted keywords (will be normalized)
            result: The full response to cache
            ttl: Time-to-live in seconds (default: 1 hour)
        """
        key = self._context_key(keywords)
        try:
            self.client.setex(key, ttl, json.dumps(result))
            return True
        except Exception:
            return False

    def get_cached_context(self, keywords: List[str]) -> Optional[dict]:
        """
        Get cached context result.

        Returns None if not cached or expired.
        """
        key = self._context_key(keywords)
        try:
            cached = self.client.get(key)
            if cached:
                result = json.loads(cached)
                result['aggregate']['cached'] = True
                return result
            return None
        except Exception:
            return None

    def _context_key(self, keywords: List[str]) -> str:
        """Generate normalized cache key."""
        normalized = sorted(set(kw.lower() for kw in keywords))
        return f"{self.PREFIX_CONTEXT_CACHE}:{':'.join(normalized)}"

    def invalidate_context_cache(self, file_path: str = None) -> int:
        """
        Invalidate context cache.

        Args:
            file_path: If provided, only invalidate caches containing this file
                       If None, invalidate all context caches

        Returns:
            Number of keys deleted
        """
        if file_path:
            # TODO: Track which files are in which cache entries
            # For now, invalidate all (conservative)
            pass

        keys = self.client.keys(f"{self.PREFIX_CONTEXT_CACHE}:*")
        if keys:
            return self.client.delete(*keys)
        return 0
```

### Updated /context Endpoint with Caching

```python
@app.route('/context', methods=['POST'])
def context_search():
    start = time.time()
    data = request.json or {}

    intent = data.get('intent', '')
    limit = int(data.get('limit', 5))
    snippet_lines = int(data.get('snippet_lines', 10))
    threshold = float(data.get('threshold', 0.3))
    skip_cache = data.get('skip_cache', False)

    if not intent:
        return jsonify({'error': 'intent required'}), 400

    # Step 1: Extract keywords
    keywords = extract_keywords(intent)

    if not keywords:
        return jsonify({
            'error': 'No keywords extracted from intent',
            'intent': intent,
            'keywords': []
        }), 400

    # Step 2: Check cache (unless skipped)
    if not skip_cache and scorer and scorer.redis:
        cached = scorer.redis.get_cached_context(keywords)
        if cached:
            cached['ms'] = round((time.time() - start) * 1000, 2)
            return jsonify(cached)

    # Step 3: Map keywords to tags
    tags_matched = map_keywords_to_tags(keywords, intent_index)

    # Step 4: Get ranked files
    if not RANKING_AVAILABLE or scorer is None:
        return jsonify({'error': 'Ranking not available'}), 503

    ranked = scorer.get_ranked_files(
        tags=tags_matched if tags_matched else None,
        limit=limit * 2
    )

    # Step 5: Filter and extract snippets
    results = []
    for item in ranked:
        confidence = item.get('confidence', item['score'] / 100)
        if confidence < threshold:
            continue

        snippet = extract_snippet(item['file'], keywords, snippet_lines)

        local = manager.get_local()
        meta = local.files.get(item['file'])

        results.append({
            'path': item['file'],
            'confidence': round(confidence, 4),
            'score': {
                'composite': item['score'],
                'recency': item.get('recency', 0),
                'frequency': item.get('frequency', 0),
                'tag_affinity': sum(item.get('tags', {}).values()) / max(1, len(item.get('tags', {})))
            },
            'snippet': snippet,
            'metadata': {
                'language': meta.language if meta else 'unknown',
                'last_modified': meta.mtime if meta else 0,
                'size': meta.size if meta else 0
            }
        })

        if len(results) >= limit:
            break

    avg_conf = sum(r['confidence'] for r in results) / len(results) if results else 0

    response = {
        'intent': intent,
        'keywords': keywords,
        'tags_matched': tags_matched,
        'files': results,
        'aggregate': {
            'total_matches': len(ranked),
            'returned': len(results),
            'avg_confidence': round(avg_conf, 4),
            'cached': False
        },
        'ms': round((time.time() - start) * 1000, 2)
    }

    # Step 6: Cache result
    if scorer and scorer.redis and results:
        scorer.redis.cache_context(keywords, response, ttl=3600)

    return jsonify(response)
```

---

## Confidence Assessment

### P3-001: /context Endpoint

**Before Research**:
- Endpoint design unclear
- Snippet extraction approach unknown
- Response schema undefined

**After Research**: **GREEN** - Ready to implement

- Clear request/response schema defined
- Snippet extraction reuses existing /file logic
- Keyword extraction is simple (no new dependencies)
- Tag mapping leverages existing intent_index

### P3-005: Caching Layer

**Before Research**:
- Cache key strategy unknown
- TTL duration unclear
- Partial matching approach undefined

**After Research**: **GREEN** - Ready to implement

- Normalized keyword key strategy chosen (simple, effective)
- 1 hour TTL with invalidation hooks
- Cache methods fit cleanly into existing RedisClient

---

## Implementation Plan

### Phase 3a: Core Endpoint (P3-001)

| Step | Description | Estimated Time |
|------|-------------|----------------|
| 1 | Add `extract_keywords()` to indexer.py | 15 min |
| 2 | Add `map_keywords_to_tags()` function | 15 min |
| 3 | Add `extract_snippet()` function | 20 min |
| 4 | Implement `/context` endpoint | 30 min |
| 5 | Add test cases | 20 min |

### Phase 3b: Caching (P3-005)

| Step | Description | Estimated Time |
|------|-------------|----------------|
| 1 | Add cache methods to RedisClient | 15 min |
| 2 | Integrate cache into /context endpoint | 10 min |
| 3 | Add cache stats to /rank/stats | 10 min |
| 4 | Test cache hit/miss scenarios | 15 min |

### Phase 3c: CLI (P3-002)

| Step | Description | Estimated Time |
|------|-------------|----------------|
| 1 | Add `aoa context` command to CLI | 20 min |
| 2 | Format output for terminal display | 15 min |

---

## Dependencies

| Component | Required By | Status |
|-----------|-------------|--------|
| `scorer.get_ranked_files()` | P3-001 | Exists (Phase 1) |
| `scorer.calculate_confidence()` | P3-001 | Needs P2-001 |
| `intent_index.all_tags()` | P3-001 | Exists |
| `RedisClient.setex/get` | P3-005 | Exists |
| File watcher | P3-005 (cache invalidation) | Exists, needs hook |

**Note**: P3-001 can proceed without P2-001's confidence calculation by using `score / 100` as a fallback. Full confidence calculation improves accuracy but isn't blocking.

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Keyword extraction too simple | Poor tag matching | Can upgrade to YAKE post-MVP |
| Cache misses frequent | No performance gain | Start with 1hr TTL, tune based on hit rate |
| Large snippets slow response | UX degradation | Limit snippet_lines, add async option |
| No tags match keywords | Empty results | Fall back to recency-only ranking |

---

## Future Enhancements (Phase 4+)

1. **Semantic caching** with embeddings via [RedisVL](https://docs.redisvl.com/en/0.4.1/user_guide/03_llmcache.html)
2. **YAKE keyword extraction** for better accuracy
3. **Multi-snippet per file** for large files
4. **Confidence calibration** based on actual usage feedback
5. **Context-aware caching (CESC)** per [Redis blog](https://redis.io/blog/building-a-context-enabled-semantic-cache-with-redis/)

---

## Sources

### API Design
- [GitHub Code Search API](https://docs.github.com/en/rest/search/search)
- [REST API Best Practices](https://www.vinaysahni.com/best-practices-for-a-pragmatic-restful-api)
- [Azure Cognitive Search Scoring](https://learn.microsoft.com/en-us/answers/questions/1687650/how-we-can-use-the-@search-score-and-@search-reran)
- [Perplexity Search API](https://www.datacamp.com/tutorial/perplexity-search-api-tutorial)

### Keyword Extraction
- [Keyword Extraction Methods - GeeksforGeeks](https://www.geeksforgeeks.org/nlp/keyword-extraction-methods-in-nlp/)
- [YAKE Keyword Analysis](https://www.markovml.com/blog/yake-keyword-extraction)
- [Four Keyword Extraction Methods - Analytics Vidhya](https://www.analyticsvidhya.com/blog/2022/01/four-of-the-easiest-and-most-effective-methods-of-keyword-extraction-from-a-single-text-using-python/)

### Redis Caching
- [Semantic Caching for LLMs - Redis](https://redis.io/blog/what-is-semantic-caching/)
- [10 Techniques for Semantic Cache Optimization](https://redis.io/blog/10-techniques-for-semantic-cache-optimization/)
- [RedisSemanticCache - LangChain](https://python.langchain.com/api_reference/redis/cache/langchain_redis.cache.RedisSemanticCache.html)
- [Context-Enabled Semantic Caching - Redis](https://redis.io/blog/building-a-context-enabled-semantic-cache-with-redis/)

---

## Summary

**P3-001 (/context endpoint)**:
- Request: `POST /context` with intent, limit, snippet_lines, threshold
- Response: Ranked files with snippets, confidence scores, metadata
- Keywords extracted via simple tokenization + stopword removal
- Tags matched via intent_index.all_tags()
- Snippets extracted using existing file reading logic

**P3-005 (Caching layer)**:
- Key strategy: Normalized sorted keywords
- TTL: 1 hour (3600 seconds)
- Invalidation: Manual or on file change (hook to file watcher)
- Implementation: Add to existing RedisClient

**Both tasks are now GREEN - ready for implementation.**
