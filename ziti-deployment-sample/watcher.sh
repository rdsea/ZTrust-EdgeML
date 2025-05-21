#!/bin/bash

ARTIFACT_DIR="./artifacts"

# Mapping: component_name → working directory inside the container
declare -A WORKING_DIRS=(
  ["web-server"]="/web-server"
  ["preprocessor"]="/proc-server"
  ["inference"]="/inference"
  ["rabbitmq"]="/"
  ["database"]="/"
)

# List of identity names that should NOT be copied (e.g., remote devices)
EXCLUDE_COMPONENTS=("client")

echo "Watching $ARTIFACT_DIR for new JWT files..."

inotifywait -m -e create --format "%f" "$ARTIFACT_DIR" | while read NEW_FILE; do
    if [[ "$NEW_FILE" == *.jwt ]]; then
        COMPONENT_NAME="${NEW_FILE%.jwt}"
        NEW_FILE_PATH="$ARTIFACT_DIR/$NEW_FILE"

        # Skip excluded components (e.g., iot-client)
        if [[ " ${EXCLUDE_COMPONENTS[*]} " =~ " ${COMPONENT_NAME} " ]]; then
            echo "Detected $NEW_FILE, but $COMPONENT_NAME is excluded (e.g., runs outside Docker). Skipping."
            continue
        fi

        # Check if component is in the mapping
        if [[ -n "${WORKING_DIRS[$COMPONENT_NAME]}" ]]; then
            # Fix ownership and permissions
            echo "Fixing ownership for $NEW_FILE..."
            sudo chown "$(id -u):$(id -g)" "$NEW_FILE_PATH"
            sudo chmod u+rw "$NEW_FILE_PATH"
            
            DEST_PATH="${WORKING_DIRS[$COMPONENT_NAME]}/$NEW_FILE"
            CONTAINER_ID=$(docker ps --filter "name=$COMPONENT_NAME" --format "{{.ID}}")

            if [ -z "$CONTAINER_ID" ]; then
                echo "Warning: No running container found for $COMPONENT_NAME. Skipping."
                continue
            fi

            echo "Copying $NEW_FILE to $COMPONENT_NAME container at $DEST_PATH"
            docker cp "$ARTIFACT_DIR/$NEW_FILE" "$CONTAINER_ID:$DEST_PATH"
            if [ $? -eq 0 ]; then
                echo "Successfully copied $NEW_FILE to $COMPONENT_NAME"
            else
                echo "Failed to copy $NEW_FILE to $COMPONENT_NAME"
            fi
        else
            echo "No working_dir mapping found for $COMPONENT_NAME. Skipping copy."
        fi
    fi
done
