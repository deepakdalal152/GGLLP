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

# ensure network
if ! docker network ls | grep -q "$NETWORK_NAME"; then docker network create "$NETWORK_NAME"; fi

# start DB
echo "→ Starting synapse DB..."
docker compose up -d synapse_db

# wait for DB
echo "→ Waiting for Postgres to be ready..."
until docker exec synapse_db pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; do
  sleep 2
  echo "  waiting for postgres..."
done
echo "→ Postgres ready."

# generate synapse config if missing
if [ ! -d "$BASE_DIR/data" ] || [ -z "$(ls -A $BASE_DIR/data 2>/dev/null)" ]; then
  echo "→ Generating Synapse config (homeserver.yaml) in ./data ..."
  mkdir -p "$BASE_DIR/data"
  # generate using synapse container if available
  docker run --rm -v "$BASE_DIR/data":/data -e SYNAPSE_SERVER_NAME="${SYNAPSE_SERVER_NAME}" -e SYNAPSE_REPORT_STATS="${SYNAPSE_REPORT_STATS}" matrixdotorg/synapse:latest generate
  echo "→ Generated config; you may need to edit data/homeserver.yaml (database config) to point to Postgres, or let the container do it."
fi

echo "→ Starting synapse service..."
docker compose up -d synapse

echo "→ Synapse started (may take a moment for migrations). Check logs: docker logs -f synapse"
echo "→ Visit: http://ggllp.synapse.local/ (or matrix client pointed to this server)"
