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

# Ensure docker network
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "→ Creating docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
fi

# Start Postgres first
echo "→ Starting Synapse Postgres..."
docker compose up -d synapse_db

# # Wait for Postgres to be ready
# echo "→ Waiting for Postgres to be ready..."
# until docker exec synapse_db pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; do
#   sleep 2
#   echo "  waiting for postgres..."
# done
# echo "✅ Postgres ready."


# sudo mkdir -p ./data
# sudo chown -R 991:991 ./data


# Generate Synapse configuration if missing
if [ ! -f "$BASE_DIR/data/homeserver.yaml" ]; then
  echo "🔧 Generating Synapse configuration..."
  mkdir -p "$BASE_DIR/data"

  SYNAPSE_IMAGE="matrixdotorg/synapse:latest"
  SYNAPSE_DATA_PATH="$BASE_DIR/data"

  sudo docker run -it --rm \
    --mount type=bind,src="$SYNAPSE_DATA_PATH",dst=/data \
    -e SYNAPSE_SERVER_NAME="${SYNAPSE_SERVER_NAME}" \
    -e SYNAPSE_REPORT_STATS="${SYNAPSE_REPORT_STATS}" \
    "$SYNAPSE_IMAGE" generate

  CONFIG_FILE="${SYNAPSE_DATA_PATH}/homeserver.yaml"

  if [ -f "$CONFIG_FILE" ]; then
    echo "🧩 Updating homeserver.yaml to use PostgreSQL..."
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak"

    cat <<EOF >> "${CONFIG_FILE}"

# --- PostgreSQL configuration override ---
database:
  name: psycopg2
  allow_unsafe_locale: true
  args:
    user: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    host: synapse_db
    database: ${POSTGRES_DB}
    cp_min: 5
    cp_max: 10
EOF

    echo "🔒 Fixing permissions for Synapse data directory..."
    sudo chown -R 991:991 "$SYNAPSE_DATA_PATH"
  fi
else
  echo "✅ Synapse configuration already exists — skipping generation."
fi

# Start Synapse
echo "🚀 Starting Synapse service..."
docker compose up -d synapse

echo ""
echo "✅ Synapse started successfully!"
echo "📜 View logs:   docker logs -f synapse_server"
echo "🌐 Access URL:  http://ggllp.synapse.local:8008"
