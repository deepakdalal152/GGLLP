#!/bin/bash


# -----------------------------
# Configuration
# -----------------------------
CONTAINER_NAME="synapse_server"
SECRET_FILE="shared_secret.txt"
SERVER_URL="http://localhost:8008"
ADMIN_USERNAME="admin"    # must exist in admins.txt
ADMIN_PASSWORD="admin"
# -----------------------------



sudo docker exec -it synapse_server register_new_matrix_user   http://localhost:8008 -c /data/homeserver.yaml   -u "$ADMIN_USERNAME" -p "$ADMIN_PASSWORD" --admin



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
        username=$(echo "$username" | tr -d ' ')
        password=$(echo "$password" | tr -d ' ')
        [ -z "$username" ] && continue

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
        group=$(echo "$group" | tr -d ' ')
        [ -z "$group" ] && continue

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
# Create rooms with specific users
# -----------------------------
create_rooms() {
    while IFS=: read -r room users || [ -n "$room" ]; do
        room=$(echo "$room" | tr -d ' ')
        users=$(echo "$users" | tr -d ' ')
        [ -z "$room" ] && continue

        echo "Creating room $room..."
        RESPONSE=$(curl -s -X POST \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"room_alias_name\": \"$room\", \"visibility\": \"private\"}" \
            "$SERVER_URL/_matrix/client/r0/createRoom")

        ROOM_ID=$(echo "$RESPONSE" | jq -r '.room_id')
        if [ -z "$ROOM_ID" ] || [ "$ROOM_ID" = "null" ]; then
            echo "Failed to create room $room"
            continue
        fi

        # Join specific users
        IFS=',' read -ra USER_ARRAY <<< "$users"
        for username in "${USER_ARRAY[@]}"; do
            username=$(echo "$username" | tr -d ' ')
            [ -z "$username" ] && continue

            echo "Adding user $username to room $room..."
            curl -s -X POST \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                "$SERVER_URL/_matrix/client/r0/join/$ROOM_ID?user_id=@$username:ggllp.synapse.local"
        done

    done < "rooms.txt"
}

# -----------------------------
# Run creation steps
# -----------------------------
[ -f "users.txt" ] && create_users "users.txt" false
# [ -f "admins.txt" ] && create_users "admins.txt" true
[ -f "groups.txt" ] && create_groups "groups.txt"

get_admin_token
[ -f "rooms.txt" ] && create_rooms

echo "All users, groups, and rooms have been created successfully!"
