# aOa - Angle O(1)f Attack

![The O(1) Advantage](images/hero.png)

> **5 angles. 1 attack.** Cut Claude Code costs by 2/3.

---

## The Problem You Know Too Well

Watch any AI coding session. This happens every time:

```
Claude: "Let me search for authentication..."
Claude: "Let me also check login..."
Claude: "I should look at session handling..."
Claude: "Let me read these 8 files..."
Claude: "Now I understand the pattern."
```

**6,600 tokens.** Just to find what was obvious to you from the start.

---

## What If It Didn't Have To?

```
You: "Fix the auth bug"
aOa: [Already loaded: auth.py, session.py, middleware.py]
Claude: "I see the issue. Line 47."
```

**150 tokens.** Same result.

aOa learns what you need and has it ready. The cost stays flat—whether you have 100 files or 100,000.

---

## The Five Angles

![Five angles, one attack](images/convergence.png)

aOa approaches every search from **5 angles**, converging on **1 attack**:

| Angle | What It Does |
|-------|--------------|
| **Symbol** | O(1) lookup across your entire codebase |
| **Intent** | Learns from every tool call, builds tag affinity |
| **Intel** | Searches external repos without polluting your results |
| **Signal** | Recency, frequency, filename matching, transitions |
| **Strike** | Prefetches files before you ask |

All five angles converge into **one confident answer**.

---

## Hit Rate

| Metric | Without aOa | With aOa | Savings |
|--------|-------------|----------|---------|
| Tool calls | 7 | 2 | 71% |
| Tokens | 8,500 | 1,150 | **86%** |
| Time | 2.6s | 54ms | 98% |

---

## Install

### 1. Add the Plugin

```bash
/plugin marketplace add CTGS-Innovations/aOa
/plugin install aoa@aoa-marketplace
```

### 2. Start Docker

```bash
# Pre-built (quick)
docker run -d -p 8080:8080 -v $(pwd):/codebase aoa/aoa

# Or build yourself (trust)
git clone https://github.com/CTGS-Innovations/aOa
docker build -t aoa .
docker run -d -p 8080:8080 -v $(pwd):/codebase aoa
```

### 3. Restart Claude Code

The plugin activates hooks and status line on restart.

---

## What You Get

Your status line evolves as aOa learns:

| Stage | Status Line |
|-------|-------------|
| Learning | `⚡ aOa ⚪ 5/30 │ 4.2ms • 12 results │ ctx:50k/200k │ Opus 4.5` |
| Learning | `⚡ aOa ⚪ 28/30 │ 3.1ms • 8 results │ ctx:80k/200k │ Opus 4.5` |
| Predicting | `⚡ aOa 🟡 45 │ 2.8ms • 5 results │ ctx:100k/200k │ Opus 4.5` |
| Predicting | `⚡ aOa 🟢 120 │ 3.5ms • 6 results │ ctx:120k/200k │ Opus 4.5` |
| Savings | `⚡ aOa 🟢 250 │ ↓12k ⚡30s saved │ ctx:80k/200k │ Opus 4.5` |
| Long-running | `⚡ aOa 🟢 1.2k │ ↓1.8M ⚡1h32m saved │ ctx:100k/200k │ Opus 4.5` |

**What the colors mean:**
- ⚪ Gray = Learning your patterns (0-30 intents)
- 🟡 Yellow = Predicting, improving
- 🟢 Green = Predictions are solid

**What you see:**
- Intent count always visible (system is working)
- Speed + results during learning phase
- Token & time savings once predictions start hitting

The more you use Claude, the smarter aOa gets. Every tool call teaches it your patterns.

---

## Why "aOa"?

**Angle O(1)f Attack**

- **O** = Big O notation. O(1) constant time. Same cost regardless of size.
- **Angle** = 5 approach methods (Symbol, Intent, Intel, Signal, Strike).
- **Attack** = The orchestration that combines all angles for accuracy.

---

## Trust

- Runs locally (Docker)
- No data leaves your machine
- Every prediction is explainable (`aoa why <file>`)
- Open source, MIT licensed

---

**The flat line wins.**
