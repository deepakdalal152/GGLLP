#!/bin/bash
set -e

#--- Load parent and local env files ---

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_ENV="$(dirname "$BASE_DIR")/.env"
LOCAL_ENV="$BASE_DIR/.env"

#Load parent env if exists

if [ -f "$PARENT_ENV" ]; then
echo "→ Loading parent env: $PARENT_ENV"
set -a
source "$PARENT_ENV"
set +a
fi

#Load local env if exists (overrides parent)

if [ -f "$LOCAL_ENV" ]; then
echo "→ Loading local env: $LOCAL_ENV"
set -a
source "$LOCAL_ENV"
set +a
fi

#Start the Docker containers in detached mode

sudo docker compose up -d
echo "→ Frappe services started — continuing setup..."

#--- Wait for Frappe backend ---

echo "→ Waiting for Frappe backend..."
sleep 10

#--- Frappe Bench Setup ---
#Check whether the site already exists

if sudo docker compose exec -T backend
test -d "/home/frappe/frappe-bench/sites/${SITE_NAME}"
then

echo "→ Site already exists, skipping creation."


else

echo "→ Creating new site..."

# Create new site
sudo docker compose exec -T backend \
    bench new-site "${SITE_NAME}" \
    --force \
    --mariadb-root-password "${MYSQL_ROOT_PASSWORD}" \
    --admin-password "${FRAPPE_ADMIN_PASSWORD}" \
    --no-mariadb-socket

# Install ERPNext app
sudo docker compose exec -T backend \
    bench --site "${SITE_NAME}" install-app erpnext

# # Install HRMS app
# sudo docker compose exec -T backend \
#     bench --site "${SITE_NAME}" install-app hrms

# Enable developer mode
sudo docker compose exec -T backend \
    bench --site "${SITE_NAME}" set-config developer_mode 1

# Enable scheduler
sudo docker compose exec -T backend \
    bench --site "${SITE_NAME}" enable-scheduler

# Clear cache
sudo docker compose exec -T backend \
    bench --site "${SITE_NAME}" clear-cache

# Set default site
sudo docker compose exec -T backend \
    bench use "${SITE_NAME}"


fi

echo "→ Frappe, ERPNext and HRMS setup complete."

#Show installed applications

sudo docker compose exec -T backend \
bench --site "${SITE_NAME}" list-apps

echo "→ Docker services are running."

#Do NOT run:
#bench start
#sudo Docker Compose manages the Frappe backend,
#frontend, websocket, workers and scheduler.