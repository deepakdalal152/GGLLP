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

# Start the Docker containers in detached mode
docker compose up -d
echo "→ Frappe services started — continuing setup..."

# --- Frappe Bench Setup ---
if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "→ Bench already exists, skipping init."
    cd frappe-bench
    bench start
else
    echo "→ Creating new bench..."
    export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"
    
    # Initialize new bench
    bench init --skip-redis-config-generation frappe-bench
    cd frappe-bench

    # Set up MariaDB and Redis container connections
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379

    # Remove redis and watch from Procfile (we’re using Docker Redis)
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile

    # Install ERPNext and HRMS apps
    bench get-app erpnext
    bench get-app hrms

    # Create new site and install HRMS app
    bench new-site hrms.localhost \
        --force \
        --mariadb-root-password ${MYSQL_ROOT_PASSWORD} \
        --admin-password ${FRAPPE_ADMIN_PASSWORD} \
        --no-mariadb-socket

    # Install HRMS app on the site
    bench --site hrms.localhost install-app hrms
    bench --site hrms.localhost set-config developer_mode 1
    bench --site hrms.localhost enable-scheduler
    bench --site hrms.localhost clear-cache
    bench use hrms.localhost
fi

# Start the bench (if not already running)
bench start
