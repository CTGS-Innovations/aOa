# .aOa Directory

This directory contains aOa's configuration and persistent data.

## Files

| File | Purpose |
|------|---------|
| `config.json` | Main configuration |
| `whitelist.txt` | Allowed URLs (one per line) |
| `session.db` | SQLite session data (created on first run) |
| `index.db` | SQLite index cache (created on first run) |

## Configuration

Edit `config.json` to change settings:
- `gateway_port`: Port for aOa gateway (default: 8080)
- `max_repo_size_mb`: Max size for cloned repos (default: 500)
- `clone_timeout`: Timeout for git operations (default: 300s)
- `confidence_threshold`: Prefetch confidence threshold (default: 0.60)
- `learning_phase_minimum`: Tool calls before prefetch starts (default: 50)

## Whitelist

Edit `whitelist.txt` to add allowed URLs:
```
github.com
gitlab.com
bitbucket.org
git.company.com         # Your private git server
docs.internal.org       # Your internal docs
```

Only HTTPS URLs to these hosts will be allowed.

## Data Storage

- `session.db`: Intent history, session state (SQLite)
- `index.db`: Cached index data (SQLite)
- Redis: Hot-path data (in Docker volume, not here)

## Resetting

To reset all data:
```bash
rm -rf .aoa/session.db .aoa/index.db
docker compose down -v  # Also clears Redis
./install.sh            # Rebuild
```
