#!/bin/bash

# -----------------------------
# Configuration
# -----------------------------
CONTAINER_NAME="synapse_server"
SECRET_FILE="shared_secret.txt"
SERVER_URL="http://localhost:8008"  # For Admin API

# -----------------------------
# Generate shared secret if missing
# -----------------------------
if [ ! -f "$SECRET_FILE" ]; then
    echo "Generating shared secret..."
    SHARED_SECRET=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
    echo "$SHARED_SECRET" > "$SECRET_FILE"
    echo "Saved shared secret to $SECRET_FILE"
else
    SHARED_SECRET=$(<"$SECRET_FILE")
    echo "Using existing shared secret from $SECRET_FILE"
fi

# -----------------------------
# Function to create users
# -----------------------------
create_users() {
    FILE=$1
    IS_ADMIN=$2
    while IFS=: read -r username password || [ -n "$username" ]; do
        echo "Creating user $username..."
        if [ "$IS_ADMIN" = true ]; then
            sudo docker exec "$CONTAINER_NAME" register_new_matrix_user \
                -u "$username" -p "$password" -k "$SHARED_SECRET" -a --exists-ok
        else
            sudo docker exec "$CONTAINER_NAME" register_new_matrix_user \
                -u "$username" -p "$password" -k "$SHARED_SECRET" --no-admin --exists-ok
        fi
    done < "$FILE"
}

# -----------------------------
# Function to create groups
# -----------------------------
create_groups() {
    FILE=$1
    while IFS= read -r group || [ -n "$group" ]; do
        echo "Creating group $group..."
        # Using shared secret as Bearer token (for automation; replace with admin token if needed)
        curl -s -X PUT \
             -H "Authorization: Bearer $SHARED_SECRET" \
             -H "Content-Type: application/json" \
             -d "{\"group_id\": \"$group\"}" \
             "$SERVER_URL/_synapse/admin/v1/groups/$group"
    done < "$FILE"
}

# -----------------------------
# Run user and group creation
# -----------------------------
# Create regular users
if [ -f "users.txt" ]; then
    create_users "users.txt" false
fi

# Create admin users
if [ -f "admins.txt" ]; then
    create_users "admins.txt" true
fi

# Create groups
if [ -f "groups.txt" ]; then
    create_groups "groups.txt"
fi

echo "All users and groups processed."
