# .aoa - Global aOa Configuration

This folder contains global aOa settings that apply to all projects.

## Files

| File | Purpose |
|------|---------|
| `config.json` | Global settings (port, thresholds, limits) |
| `whitelist.txt` | Allowed URLs for git cloning |

## Configuration (config.json)

```json
{
  "gateway_port": 8080,           // Port for aOa gateway
  "max_repo_size_mb": 500,        // Max size for cloned repos
  "clone_timeout": 300,           // Timeout for git operations (seconds)
  "confidence_threshold": 0.60,   // Min confidence for prefetch predictions
  "learning_phase_minimum": 50    // Tool calls before prefetch activates
}
```

### Settings Explained

| Setting | Default | Description |
|---------|---------|-------------|
| `gateway_port` | 8080 | HTTP port for the aOa gateway |
| `max_repo_size_mb` | 500 | Maximum repo size to clone (MB) |
| `clone_timeout` | 300 | Git clone timeout in seconds |
| `confidence_threshold` | 0.60 | Minimum prediction confidence (0-1) |
| `learning_phase_minimum` | 50 | Tool calls before predictions begin |

## Whitelist (whitelist.txt)

Add domains you want aOa to be able to clone from:

```
github.com
gitlab.com
bitbucket.org
git.your-company.com
```

Only HTTPS URLs to whitelisted domains are allowed.

## Per-Project Config

Each project has its own `.aoa/home.json` that points back here.
That file is created by `aoa init` and just contains paths - no settings.
