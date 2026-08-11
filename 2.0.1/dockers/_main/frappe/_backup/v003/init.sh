#!/bin/bash
set -euo pipefail

# ============================================================
# Frappe / ERPNext / HRMS Docker Setup
# ============================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

PARENT_ENV="$(dirname "$BASE_DIR")/.env"
LOCAL_ENV="$BASE_DIR/.env"

cd "$BASE_DIR"

# ============================================================
# Load environment
# ============================================================

if [ -f "$PARENT_ENV" ]; then
    echo "→ Loading parent env: $PARENT_ENV"
    set -a
    source "$PARENT_ENV"
    set +a
fi

if [ -f "$LOCAL_ENV" ]; then
    echo "→ Loading local env: $LOCAL_ENV"
    set -a
    source "$LOCAL_ENV"
    set +a
fi

# ============================================================
# Validate variables
# ============================================================

required_vars=(
    SITE_NAME
    MYSQL_ROOT_PASSWORD
    MYSQL_PASSWORD
    FRAPPE_ADMIN_PASSWORD
    NETWORK_NAME
    CUSTOM_IMAGE
    CUSTOM_TAG
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo
        echo "ERROR: Required variable '$var' is not set."
        echo
        exit 1
    fi
done

# ============================================================
# Check Docker
# ============================================================

if ! sudo docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not available."
    exit 1
fi

# ============================================================
# Check external Docker network
# ============================================================

if ! sudo docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "→ Creating Docker network: $NETWORK_NAME"
    sudo docker network create "$NETWORK_NAME"
else
    echo "→ Docker network exists: $NETWORK_NAME"
fi

# ============================================================
# Custom image
# Build ONLY if image does not already exist
# ============================================================

IMAGE="${CUSTOM_IMAGE}:${CUSTOM_TAG}"

echo
echo "============================================================"
echo "Checking custom Frappe / ERPNext / HRMS image"
echo "============================================================"

if sudo docker image inspect "$IMAGE" >/dev/null 2>&1; then

    echo "→ Custom image already exists:"
    echo "   $IMAGE"
    echo "→ Skipping Docker build."

else

    echo "→ Custom image not found:"
    echo "   $IMAGE"
    echo
    echo "→ Building custom image..."

    if [ ! -f "$BASE_DIR/Dockerfile" ]; then
        echo "ERROR: Dockerfile not found:"
        echo "  $BASE_DIR/Dockerfile"
        exit 1
    fi

    if [ ! -f "$BASE_DIR/apps.json" ]; then
        echo "ERROR: apps.json not found:"
        echo "  $BASE_DIR/apps.json"
        exit 1
    fi

    export DOCKER_BUILDKIT=1

    sudo docker build \
        --secret "id=apps_json,src=$BASE_DIR/apps.json" \
        --tag "$IMAGE" \
        --file "$BASE_DIR/Dockerfile" \
        "$BASE_DIR"

    echo
    echo "→ Custom image built successfully:"
    echo "   $IMAGE"

fi

# ============================================================
# Remove old orphan containers
# ============================================================

echo
echo "→ Removing old orphan containers..."

sudo docker compose down --remove-orphans

# ============================================================
# Start services
# ============================================================

echo
echo "============================================================"
echo "Starting Frappe services"
echo "============================================================"

sudo docker compose up -d

echo
echo "→ Docker services started."

# ============================================================
# Wait for backend container
# ============================================================

echo
echo "→ Waiting for backend container..."

for i in {1..60}; do

    STATUS="$(
        sudo docker inspect \
            --format '{{.State.Status}}' \
            frappe_backend 2>/dev/null || true
    )"

    if [ "$STATUS" = "running" ]; then
        echo "→ Backend container is running."
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo
        echo "ERROR: Backend container failed to start."
        echo

        sudo docker compose ps
        sudo docker compose logs --tail=100 backend

        exit 1
    fi

    echo "   Waiting for backend... ($i/60)"
    sleep 2

done

# ============================================================
# Wait for Bench
# ============================================================

echo
echo "→ Waiting for Frappe Bench..."

for i in {1..60}; do

    if sudo docker compose exec -T backend \
        bench version >/dev/null 2>&1; then

        echo "→ Bench is ready."
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo
        echo "ERROR: Bench did not become ready."
        echo

        sudo docker compose logs --tail=100 backend

        exit 1
    fi

    echo "   Waiting for Bench... ($i/60)"
    sleep 2

done

# ============================================================
# Site path
# ============================================================

SITE_PATH="/home/frappe/frappe-bench/sites/${SITE_NAME}"

# ============================================================
# Create site
# ============================================================

if sudo docker compose exec -T backend \
    test -d "$SITE_PATH"; then

    echo
    echo "→ Site already exists: $SITE_NAME"

else

    echo
    echo "============================================================"
    echo "Creating site: $SITE_NAME"
    echo "============================================================"

    sudo docker compose exec -T backend \
        bench new-site \
        --mariadb-user-host-login-scope="%" \
        --db-root-password "$MYSQL_ROOT_PASSWORD" \
        --admin-password "$FRAPPE_ADMIN_PASSWORD" \
        "$SITE_NAME"

    echo "→ Site created successfully."

fi

# # ============================================================
# # Install ERPNext
# # ============================================================

# echo
# echo "→ Checking ERPNext..."

# if sudo docker compose exec -T backend \
#     bench --site "$SITE_NAME" list-apps 2>/dev/null \
#     | awk '{print $1}' \
#     | grep -qx "erpnext"; then

#     echo "→ ERPNext is already installed."

# else

#     echo "→ Installing ERPNext..."

#     sudo docker compose exec -T backend \
#         bench --site "$SITE_NAME" install-app erpnext

#     echo "→ ERPNext installed."

# fi

# ============================================================
# Install HRMS
# ============================================================

echo
echo "→ Checking HRMS..."

if sudo docker compose exec -T backend \
    test -d "/home/frappe/frappe-bench/apps/hrms"; then

    echo "→ HRMS application exists in the image."

    if sudo docker compose exec -T backend \
        bench --site "$SITE_NAME" list-apps 2>/dev/null \
        | awk '{print $1}' \
        | grep -qx "hrms"; then

        echo "→ HRMS is already installed."

    else

        echo "→ Installing HRMS..."

        sudo docker compose exec -T backend \
            bench --site "$SITE_NAME" install-app hrms

        echo "→ HRMS installed."

    fi

else

    echo
    echo "ERROR: HRMS is missing from the Docker image."
    echo
    echo "Check the Docker image:"
    echo
    echo "    sudo docker run --rm $IMAGE \\"
    echo "        bash -c 'ls -la apps/hrms'"
    echo

    exit 1

fi

# ============================================================
# Developer mode
# ============================================================

if [ "${FRAPPE_DEVELOPER_MODE:-0}" = "1" ]; then

    echo
    echo "→ Enabling developer mode..."

    sudo docker compose exec -T backend \
        bench --site "$SITE_NAME" set-config developer_mode 1

fi

# ============================================================
# Scheduler
# ============================================================

echo
echo "→ Enabling scheduler..."

sudo docker compose exec -T backend \
    bench --site "$SITE_NAME" enable-scheduler

# ============================================================
# Clear cache
# ============================================================

echo
echo "→ Clearing cache..."

sudo docker compose exec -T backend \
    bench --site "$SITE_NAME" clear-cache

# ============================================================
# Set default site
# ============================================================

echo
echo "→ Setting default site..."

sudo docker compose exec -T backend \
    bench use "$SITE_NAME"

# ============================================================
# Installed apps
# ============================================================

echo
echo "============================================================"
echo "Installed applications"
echo "============================================================"

sudo docker compose exec -T backend \
    bench --site "$SITE_NAME" list-apps

# ============================================================
# Docker status
# ============================================================

echo
echo "============================================================"
echo "Docker services"
echo "============================================================"

sudo docker compose ps

# ============================================================
# Final message
# ============================================================

echo
echo "============================================================"
echo "✓ Frappe setup complete"
echo "============================================================"

echo
echo "Site:"
echo "  $SITE_NAME"

echo
echo "Image:"
echo "  $IMAGE"

echo
echo "Applications:"
echo "  Frappe"
echo "  ERPNext"
echo "  HRMS"

echo
echo "Do NOT run:"
echo "  bench start"

echo
echo "Docker Compose manages:"
echo "  backend"
echo "  frontend"
echo "  websocket"
echo "  queue-short"
echo "  queue-long"
echo "  scheduler"

echo
echo "→ Setup finished successfully."
