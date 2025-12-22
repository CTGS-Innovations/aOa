# aOa Quickstart

## 5-Minute Setup

```bash
# 1. Clone
git clone https://github.com/you/aOa
cd aOa

# 2. Install (starts services)
./install.sh

# 3. Test it works
aoa health
```

## Your First Search

```bash
# Index your codebase
aoa init /path/to/your/project

# Search for a term
aoa search handleAuth

# Multi-term ranked search
aoa multi auth,login,session

# See what changed recently
aoa changes 1h

# List files
aoa files "*.py"
```

## Add a Knowledge Repo

```bash
# Clone and index Flask
aoa repo add flask https://github.com/pallets/flask

# Search in Flask
aoa repo flask search Blueprint

# List Flask files
aoa repo flask files "*.py"
```

## Intent Tracking (Automatic)

aOa learns as you work. After ~50 tool calls:

```bash
# See what you've been working on
aoa intent recent

# See all intent tags
aoa intent tags

# Files associated with a tag
aoa intent files authentication
```

## Transparency

```bash
# View network topology
curl localhost:8080/network

# Verify isolation (no internet access except proxy)
./scripts/verify-isolation.sh

# See all requests
curl localhost:8080/audit
```

## Benchmark

```bash
# Compare aOa vs grep
./scripts/benchmark.sh /path/to/your/code
```

## Configuration

Edit `.aoa/config.json` for settings.
Edit `.aoa/whitelist.txt` to add allowed URLs.

---

**That's it. You're running O(1) search.**
