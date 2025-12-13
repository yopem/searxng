# SearXNG Docker Setup

Simple single-container setup with SearXNG and Redis.

## Quick Start

```bash
# Build
podman build -t searxng .

# Run
podman run -d -p 8080:8080 --name searxng searxng

# Access
http://127.0.0.1:8080
```

## Examples

**Custom Port:**

```bash
podman run -d -p 3000:3000 -e SEARXNG_PORT=3000 --name searxng searxng
```

**External Redis:**

```bash
podman run -d -p 8080:8080 -e REDIS_URL=redis://host.containers.internal:6379/0 --name searxng searxng
```

**With .env file:**

```bash
podman run -d -p 8080:8080 --env-file .env --name searxng searxng
```

## Commands

```bash
# Build
podman build -t searxng .

# Run
podman run -d -p 8080:8080 --name searxng searxng

# Rebuild
podman build -t searxng . && podman rm -f searxng && podman run -d -p 8080:8080 --name searxng searxng
```

## Environment Variables

| Variable             | Default    | Description                               |
| -------------------- | ---------- | ----------------------------------------- |
| `SEARXNG_PORT`       | `8080`     | Port for web interface                    |
| `REDIS_URL`          | (auto)     | Redis URL. Leave empty for internal Redis |
| `SEARXNG_SECRET_KEY` | (optional) | Secret key                                |

## Redis Behavior

- No `REDIS_URL` → Uses internal Redis
- `REDIS_URL` set → Uses external Redis (internal disabled)

## License

MIT License - see [LICENSE.md](LICENSE.md)
