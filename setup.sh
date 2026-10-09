#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yaml"

DOMAIN="aiproxy.web-father.ir"

echo "======================================"
echo "  OmniRoute Deployment"
echo "======================================"
echo

# ---------------------------------------------------------
# Check requirements
# ---------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed."
    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | sh

    systemctl enable docker
    systemctl start docker
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: Docker Compose plugin is not available."
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: docker-compose.yaml was not found at:"
    echo "$COMPOSE_FILE"
    exit 1
fi

# ---------------------------------------------------------
# Configure swap
# ---------------------------------------------------------

CURRENT_SWAP="$(free -m | awk '/^Swap:/ {print $2}')"

if [ "${CURRENT_SWAP:-0}" -eq 0 ]; then

    echo "No swap detected."
    echo "Creating 1 GB swap..."

    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l 1G /swapfile
    else
        dd if=/dev/zero of=/swapfile bs=1M count=1024
    fi

    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    if ! grep -q "^/swapfile " /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # Avoid aggressively swapping normal application memory.
    cat >/etc/sysctl.d/99-omniroute.conf <<EOF
vm.swappiness=10
EOF

    sysctl -p /etc/sysctl.d/99-omniroute.conf >/dev/null

    echo "1 GB swap created."
else
    echo "Swap already exists (${CURRENT_SWAP} MB)."
fi

# ---------------------------------------------------------
# Generate environment variables
# ---------------------------------------------------------

if [ ! -f "$ENV_FILE" ]; then

    echo
    echo "Generating environment variables..."

    JWT_SECRET="$(openssl rand -hex 64)"
    INITIAL_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"

    cat >"$ENV_FILE" <<EOF
REQUIRE_API_KEY=true
NEXT_PUBLIC_BASE_URL=https://${DOMAIN}
JWT_SECRET=${JWT_SECRET}
INITIAL_PASSWORD=${INITIAL_PASSWORD}
EOF

    chmod 600 "$ENV_FILE"

    NEW_ENV_CREATED=true

    echo ".env created."
else
    echo
    echo ".env already exists."
    echo "Existing secrets will NOT be replaced."

    NEW_ENV_CREATED=false

    # Preserve every existing value; add only credentials missing from older deployments.
    if ! grep -q '^REQUIRE_API_KEY=' "$ENV_FILE"; then
        printf '\nREQUIRE_API_KEY=true\n' >>"$ENV_FILE"
    fi

    if ! grep -q '^NEXT_PUBLIC_BASE_URL=' "$ENV_FILE"; then
        printf 'NEXT_PUBLIC_BASE_URL=https://%s\n' "$DOMAIN" >>"$ENV_FILE"
    fi

    if ! grep -q '^JWT_SECRET=' "$ENV_FILE"; then
        printf 'JWT_SECRET=%s\n' "$(openssl rand -hex 64)" >>"$ENV_FILE"
    fi

    if ! grep -q '^INITIAL_PASSWORD=' "$ENV_FILE"; then
        printf 'INITIAL_PASSWORD=%s\n' "$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)" >>"$ENV_FILE"
    fi

    chmod 600 "$ENV_FILE"
fi

# ---------------------------------------------------------
# Start stack
# ---------------------------------------------------------

cd "$PROJECT_DIR"

echo
echo "Pulling Docker images..."
docker compose --env-file "$ENV_FILE" pull

echo
echo "Starting OmniRoute..."
docker compose --env-file "$ENV_FILE" up -d

echo
echo "======================================"
echo "  Deployment complete"
echo "======================================"
echo
echo "URL:"
echo "  https://${DOMAIN}"
echo

if [ "$NEW_ENV_CREATED" = true ]; then
    echo "Initial password:"
    echo
    echo "  ${INITIAL_PASSWORD}"
    echo
    echo "Save this password somewhere secure."
    echo
fi

echo "Container status:"
docker compose ps

echo
echo "Memory:"
free -h

echo
echo "Useful commands:"
echo
echo "  docker compose logs -f"
echo "  docker compose logs -f omniroute"
echo "  docker compose logs -f redis"
echo "  docker compose logs -f caddy"
echo "  docker stats"
echo
