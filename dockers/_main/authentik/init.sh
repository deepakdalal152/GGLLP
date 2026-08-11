#!/bin/bash
set -euo pipefail

# Init script for Authentik
# Usage: ./init.sh

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# helper to load env file into current shell and export variables
load_env_file() {
  local f="$1"
  if [ -f "$f" ]; then
    # strip CRLF and ignore comments, then export
    set -a
    # use a safe method to read key=val lines
    # allow empty values
    while IFS='=' read -r key val || [ -n "$key" ]; do
      # skip comment / blank lines
      [[ "$key" =~ ^\s*# ]] && continue
      [[ -z "$key" ]] && continue
      # remove surrounding quotes from val
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\' }"
      val="${val#\'}"
      export "$key"="$val"
    done < <(sed 's/\r$//' "$f")
    set +a
  fi
}

# Load parent top-level .env (if present) to allow inheritance
PARENT_ENV="$(cd "$BASE_DIR/.." && pwd)/.env"
if [ -f "$PARENT_ENV" ]; then
  echo "→ Loading parent env: $PARENT_ENV"
  load_env_file "$PARENT_ENV"
fi

# Load local .env (overrides parent)
LOCAL_ENV="$BASE_DIR/.env"
if [ -f "$LOCAL_ENV" ]; then
  echo "→ Loading local env: $LOCAL_ENV"
  load_env_file "$LOCAL_ENV"
else
  echo "→ No local .env found at $LOCAL_ENV — creating a template"
  cat > "$LOCAL_ENV" <<EOF
# Local Authentik env (generated template)
POSTGRES_DB=authentik
POSTGRES_USER=authentik
POSTGRES_PASSWORD=
AUTHENTIK_IMAGE=ghcr.io/goauthentik/server
AUTHENTIK_TAG=2025.8.0
AUTHENTIK_SECRET_KEY=
AUTHENTIK_ERROR_REPORTING__ENABLED=false
NETWORK_NAME=${NETWORK_NAME:-proxy}
HOST_IP=${HOST_IP:-127.0.0.1}
EOF
  load_env_file "$LOCAL_ENV"
fi

# Ensure NETWORK_NAME is set (fall back to 'proxy' if not)
NETWORK_NAME="${NETWORK_NAME:-proxy}"
echo "→ Using docker network: ${NETWORK_NAME}"

# Create docker network if missing
if ! docker network ls --format '{{.Name}}' | grep -qx "${NETWORK_NAME}"; then
  echo "→ Creating docker network: ${NETWORK_NAME}"
  docker network create "${NETWORK_NAME}"
else
  echo "→ Docker network ${NETWORK_NAME} already exists"
fi

# Generate POSTGRES_PASSWORD if empty
if [ -z "${POSTGRES_PASSWORD:-}" ]; then
  echo "→ No POSTGRES_PASSWORD set — generating a secure password"
  NEW_PG_PASS="$(openssl rand -base64 32 | tr -d '\n')"
  # write back to local .env (only if file writable)
  if [ -w "$LOCAL_ENV" ]; then
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${NEW_PG_PASS}|" "$LOCAL_ENV" || \
      echo "POSTGRES_PASSWORD=${NEW_PG_PASS}" >> "$LOCAL_ENV"
  fi
  export POSTGRES_PASSWORD="$NEW_PG_PASS"
fi

# Generate AUTHENTIK_SECRET_KEY if empty
if [ -z "${AUTHENTIK_SECRET_KEY:-}" ]; then
  echo "→ No AUTHENTIK_SECRET_KEY set — generating one"
  NEW_SECRET="$(openssl rand -hex 48)"
  if [ -w "$LOCAL_ENV" ]; then
    sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=${NEW_SECRET}|" "$LOCAL_ENV" || \
      echo "AUTHENTIK_SECRET_KEY=${NEW_SECRET}" >> "$LOCAL_ENV"
  fi
  export AUTHENTIK_SECRET_KEY="$NEW_SECRET"
fi

# Ensure directories exist and correct ownership for Postgres data
echo "→ Ensuring data directories exist and ownership"
mkdir -p "$BASE_DIR/postgres-data" "$BASE_DIR/redis-data" "$BASE_DIR/media"
# Postgres in container uses UID 999 on many images; try to chown to that if possible
if [ "$(id -u)" -ne 0 ]; then
  CHOWN_CMD="sudo chown -R 999:999 $BASE_DIR/postgres-data || true"
else
  CHOWN_CMD="chown -R 999:999 $BASE_DIR/postgres-data || true"
fi
echo "→ Running: $CHOWN_CMD"
eval "$CHOWN_CMD"

# Pull images (safe)
echo "→ Pulling images..."
# docker compose pull --quiet || true

# Start stack
echo "→ Starting Authentik stack (this may take a minute)..."
docker compose up -d

echo "→ Waiting for Postgres to become healthy..."
# wait for postgres service health (use docker inspect)
TRIES=0
MAX_TRIES=40
while true; do
  STATUS=$(docker inspect --format='{{json .State.Health.Status}}' authentik_postgres 2>/dev/null || echo "null")
  if echo "$STATUS" | grep -q "healthy"; then
    echo "→ Postgres healthy"
    break
  fi
  if echo "$STATUS" | grep -q "unhealthy"; then
    echo "→ Postgres unhealthy — check logs: docker logs authentik_postgres --tail 100"
    break
  fi
  TRIES=$((TRIES+1))
  if [ "$TRIES" -ge "$MAX_TRIES" ]; then
    echo "→ Timeout waiting for Postgres. Check: docker logs authentik_postgres --tail 100"
    break
  fi
  sleep 2
done

echo "→ Authentik start requested. Check logs:"
echo "  docker logs -f authentik_server"
echo ""
echo "Access Authentik initial setup when ready:"
echo "  http://ggllp.authentik.local/if/flow/initial-setup/"
