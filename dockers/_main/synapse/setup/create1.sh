#!/bin/bash

# -----------------------------
# Configuration
# -----------------------------
CONTAINER_NAME="synapse_server"
SECRET_FILE="shared_secret.txt"
SERVER_URL="http://localhost:8008"
ADMIN_USERNAME="herot"          # must exist in admins.txt
ADMIN_PASSWORD="herot"       # match the password in admins.txt
# admins3:secure456
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
# Create users
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
# Create groups
# -----------------------------
create_groups() {
    FILE=$1
    while IFS= read -r group || [ -n "$group" ]; do
        echo "Creating group $group..."
        curl -s -X PUT \
             -H "Authorization: Bearer $SHARED_SECRET" \
             -H "Content-Type: application/json" \
             -d "{\"group_id\": \"$group\"}" \
             "$SERVER_URL/_synapse/admin/v1/groups/$group"
    done < "$FILE"
}

# -----------------------------
# Login admin user to get access token
# -----------------------------
get_admin_token() {
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"m.login.password\",\"user\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}" \
        "$SERVER_URL/_matrix/client/r0/login")

    ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
    if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
        echo "Failed to get admin access token"
        exit 1
    fi
}

# -----------------------------
# Create rooms
# -----------------------------
create_rooms() {
    FILE=$1
    while IFS= read -r room || [ -n "$room" ]; do
        # Remove extra whitespace/newlines
        room=$(echo "$room" | tr -d '\r\n ')

        # Skip empty room names
        [ -z "$room" ] && continue

        echo "Creating room $room..."
        curl -s -X POST \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg name "$room" '{room_alias_name: $name, visibility: "private"}')" \
            "$SERVER_URL/_matrix/client/r0/createRoom"
    done < "$FILE"
}

# -----------------------------
# Run the creation steps
# -----------------------------
# 1. Users
[ -f "users.txt" ] && create_users "users.txt" false
[ -f "admins.txt" ] && create_users "admins.txt" true
[ -f "rom.txt" ] && create_users "rom.txt" false

# 2. Groups
[ -f "groups.txt" ] && create_groups "groups.txt"

# 3. Admin login
get_admin_token

# 4. Rooms
[ -f "rooms.txt" ] && create_rooms "rooms.txt"

echo "All users, groups, and rooms have been created successfully!"
