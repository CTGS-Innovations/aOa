# aOa Setup

Set up aOa backend services using Docker.

## Prerequisites

- Docker installed and running

## Quick Start (Pre-built Image)

Run this command to start aOa:

```bash
docker run -d --name aoa -p 8080:8080 -v "$(pwd)":/codebase aoa/aoa
```

## Build From Source (Optional)

If you prefer to build the image yourself:

```bash
git clone https://github.com/corey/aoa ~/.aoa-source
cd ~/.aoa-source
docker build -t aoa .
docker run -d --name aoa -p 8080:8080 -v "$(pwd)":/codebase aoa
```

## Verify Installation

After starting Docker, verify aOa is running:

```bash
curl http://localhost:8080/health
```

Or use the CLI:

```bash
aoa health
```

## Next Steps

Once setup is complete, restart Claude Code to activate the hooks and status line.

The following will be available:
- Status line showing prediction accuracy
- Automatic context prediction on each prompt
- `/aoa:health` to check service status
- `aoa search <term>` for fast code search
