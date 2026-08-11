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


# Create the necessary directories with the -p flag to ensure parent directories are created
mkdir -p ./volumes/app/mattermost/{config,data,logs,plugins,client/plugins,bleve-indexes}

# Set the appropriate ownership (UID 2000 and GID 2000) for the directories
sudo chown -R 2000:2000 ./volumes/app/mattermost



echo "→ Starting Mattermost..."
# uses top-level network (create by init-all if needed)
# docker compose pull
docker compose up -d
echo "→ Mattermost started (dashboard: http://$HOST_IP:8082/dashboard/)"
