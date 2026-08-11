#!/bin/bash
set -e

# --- Load parent and local env files ---
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_ENV="$(dirname "$BASE_DIR")/.env"
LOCAL_ENV="$BASE_DIR/.env"

# Load parent env if exists
if [ -f "$PARENT_ENV" ]; then
  echo "→ Loading parent env: $PARENT_ENV"
  set -a
  source "$PARENT_ENV"
  set +a
fi

# Load local env if exists (overrides parent)
if [ -f "$LOCAL_ENV" ]; then
  echo "→ Loading local env: $LOCAL_ENV"
  set -a
  source "$LOCAL_ENV"
  set +a
fi

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$BASE_DIR/.env"
echo "→ Ensuring network $NETWORK_NAME exists..."
if ! docker network ls | grep -q "$NETWORK_NAME"; then docker network create "$NETWORK_NAME"; fi

echo "→ Writing custom.list..."
mkdir -p "$BASE_DIR/etc-pihole"
cat > "$BASE_DIR/custom.list" <<EOF
$(echo "$DNS_ENTRIES" | sed '/^\s*$/d')
EOF

echo "→ Starting Pi-hole..."
# docker compose pull
docker compose up -d

echo "→ Waiting for Pi-hole web UI to become available..."
until curl -s "http://$HOST_IP:8081/admin/" >/dev/null 2>&1; do
  sleep 2
  echo "  waiting..."
done

echo "→ Pi-hole is up. custom.list installed."
