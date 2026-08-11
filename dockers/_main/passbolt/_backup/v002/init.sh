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

echo "→ Starting Passbolt MariaDB..."
docker compose up -d passbolt_db

# --- Wait for DB ---
echo "→ Waiting for database to be ready..."
until docker compose exec passbolt_db mysqladmin ping \
      -u"${PASSBOLT_DB_USER}" -p"${PASSBOLT_DB_PASSWORD}" \
      --silent >/dev/null 2>&1; do
  sleep 2
  echo "  waiting for passbolt_db..."
done
echo "✅ Database ready."

# Ensure GPG + JWT volumes exist
echo "→ Ensuring GPG + JWT volumes exist..."
docker volume inspect passbolt_gpg >/dev/null 2>&1 || docker volume create passbolt_gpg
docker volume inspect passbolt_jwt >/dev/null 2>&1 || docker volume create passbolt_jwt

# Start Passbolt
echo "🚀 Starting Passbolt service..."
docker compose up -d passbolt

# --- Wait for container health ---
echo "→ Waiting for Passbolt to be healthy..."
while [ "$(docker inspect -f '{{.State.Health.Status}}' passbolt_server)" != "healthy" ]; do
  sleep 2
  echo "  waiting for passbolt_server..."
done
echo "✅ Passbolt healthy."

# Register initial admin user if they don't exist
echo "→ Checking if user already exists..."
if docker compose exec passbolt su -m -c \
  "/usr/share/php/passbolt/bin/cake passbolt show_user -u ${PASSBOLT_INIT_EMAIL}" \
  -s /bin/sh www-data | grep -q 'User found'; then
  echo "⚠️ User already exists — skipping registration."
else
  echo "→ Registering initial Passbolt user..."
  docker compose exec passbolt su -m -c \
    "/usr/share/php/passbolt/bin/cake passbolt register_user \
      -u ${PASSBOLT_INIT_EMAIL} \
      -f ${PASSBOLT_INIT_FIRST} \
      -l ${PASSBOLT_INIT_LAST} \
      -r ${PASSBOLT_INIT_ROLE} \
    -s /bin/sh www-data
fi

echo ""
echo "✅ Passbolt started successfully!"
echo "📜 View logs:   docker logs -f passbolt_server"
echo "🌐 Access URL:  ${PASSBOLT_URL}"
