# SearXNG Docker Setup

Simple single-container setup with SearXNG and Redis.

## Quick Start

```bash
# Build
docker build -t searxng:latest .

# Run
docker run -d -p 8080:8080 --name searxng searxng:latest

# Access
http://127.0.0.1:8080
```

## Note

Use `http://127.0.0.1:8080` instead of `http://localhost:8080` if localhost doesn't work (IPv6 issue).

## License

This project is licensed under the [MIT](LICENSE.md) license.
