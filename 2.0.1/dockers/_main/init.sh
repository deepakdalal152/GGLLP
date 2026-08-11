#!/bin/bash
set -e

# --- Convert all .sh and .env files to Unix format ---
find . -type f \( -name "*.sh" -o -name ".env" \) -exec dos2unix {} \; >/dev/null 2>&1 || true

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$BASE_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ ERROR: $ENV_FILE not found!"
  exit 1
fi

# --- Load environment variables safely ---
while IFS='=' read -r key value; do
  # Skip comments, blanks, and DNS_ENTRIES block
  [[ -z "$key" || "$key" =~ ^# || "$key" == "DNS_ENTRIES" ]] && continue

  # Trim whitespace
  key=$(echo "$key" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  value=$(echo "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  # Remove any wrapping quotes
  value=$(echo "$value" | sed 's/^"//; s/"$//; s/^'\''//; s/'\''$//')

  # Export
  if [[ -n "$key" && -n "$value" ]]; then
    export "$key=$value"
  fi
done < "$ENV_FILE"

echo "───────────────────────────────────────────────"
echo " 🧩 Initializing full GGLLP infra"
echo " Base dir: $BASE_DIR"
echo " Network: $NETWORK_NAME"
echo " Host IP: $HOST_IP"
echo "───────────────────────────────────────────────"

# --- Create shared docker network if missing ---
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "→ Creating docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
else
  echo "→ Docker network '$NETWORK_NAME' already exists."
fi

# --- Deploy each stack in order ---
for s in $SERVICES; do
  STACK_DIR="$BASE_DIR/$s"
  if [ -d "$STACK_DIR" ] && [ -x "$STACK_DIR/init.sh" ]; then
    echo ""
    echo "───────────────────────────────────────────────"
    echo " ▶ Deploying: $s"
    echo "───────────────────────────────────────────────"
    (cd "$STACK_DIR" && ./init.sh)
  else
    echo ""
    echo "⚠️  Skipping $s: missing directory or init.sh"
  fi
done

echo ""
echo "───────────────────────────────────────────────"
echo " ✅ All stacks processed with actual IP"
echo " Access:"
echo "  • Pi-hole   → http://$HOST_IP:8081/admin/"
echo "  • Traefik   → http://$HOST_IP:8082/dashboard/"
echo "  • Authentik → http://$HOST_IP:9000/"
echo "  • Synapse → http://$HOST_IP:8008/"
echo "  • Kitsu → http://$HOST_IP:8800/"
echo "  • Ayon → http://$HOST_IP:5000/"
echo "  • Mattermost → http://$HOST_IP:8065/"
echo "  • Jumpserver → http://$HOST_IP:8080/"

echo "───────────────────────────────────────────────"
echo " ✅ All stacks processed with actual PI-HOLE"
echo "  • Authentik → http://ggllp.authentik.local/"
echo "───────────────────────────────────────────────"
