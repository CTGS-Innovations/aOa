# aOa Health Check

Check the status of aOa backend services.

## Check Services

Run this command to verify aOa is running:

```bash
curl -s http://localhost:8080/health | jq .
```

Or use the CLI:

```bash
aoa health
```

## Expected Output

When healthy:

```json
{
  "status": "ok",
  "services": {
    "gateway": "up",
    "index": "up",
    "status": "up"
  }
}
```

## Troubleshooting

If services are down:

```bash
# Check if container is running
docker ps | grep aoa

# View logs
docker logs aoa

# Restart
docker restart aoa
```

## Service Endpoints

| Endpoint | Purpose |
|----------|---------|
| `localhost:8080/health` | Health check |
| `localhost:8080/symbol?q=term` | Symbol search |
| `localhost:8080/multi?q=a+b+c` | Multi-term search |
| `localhost:8080/metrics` | Prediction metrics |
