# OmniRoute Deployment

This repository deploys [OmniRoute](https://github.com/diegosouzapw/OmniRoute), Redis, and Caddy with Docker Compose. The public application endpoint is `https://aiproxy.web-father.ir`.

| Service | Purpose | Reachability |
| --- | --- | --- |
| `omniroute` | Unified AI proxy & dashboard on port `20128` | Docker network via Caddy / loopback |
| `redis` | State caching & pub/sub for OmniRoute | Docker network (`redis:6379`) |
| `caddy` | TLS termination and public HTTPS reverse proxy | Host ports `80`, `443/tcp`, `443/udp` |

## Prerequisites

- A Linux VPS with an `amd64` or `arm64` CPU and outbound Internet access.
- Root access to run `setup.sh`.
- Docker and Docker Compose v2.
- DNS `A` record for `aiproxy.web-father.ir` pointing to the VPS. Allow inbound TCP `80` and `443` for Caddy and certificate issuance. Keep UDP `443` open for HTTP/3.

## Deployment

1. Clone or copy this repository to your VPS:

```bash
cd /path/to/omniroute-setup
sudo bash setup.sh
```

2. The script configures swap if needed, generates `.env` with secure secrets (`JWT_SECRET`, `INITIAL_PASSWORD`, `REQUIRE_API_KEY=true`), pulls images, and starts the stack.

3. Open `https://aiproxy.web-father.ir` once Caddy issues the SSL certificate.
   Log in with the credentials generated in `.env` (or printed in the setup output).

## Environment Variables

- `REQUIRE_API_KEY`: Set to `true` to require authentication for all `/v1` proxy requests.
- `NEXT_PUBLIC_BASE_URL`: Public HTTPS URL (`https://aiproxy.web-father.ir`).
- `JWT_SECRET`: Secret key for session cookies.
- `INITIAL_PASSWORD`: First-time admin dashboard password.
- `REDIS_URL`: `redis://redis:6379`.

## Operations

```bash
# View running status
docker compose ps

# View logs
docker compose logs -f omniroute
docker compose logs -f redis
docker compose logs -f caddy

# Resource usage
docker stats
```
