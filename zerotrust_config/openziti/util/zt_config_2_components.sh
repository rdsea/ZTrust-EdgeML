#!/bin/bash

# Check if three arguments are passed
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <component1-name> <component2-name> <port> <location>"
  exit 1
fi

# Set variables from command-line arguments
COMPONENT1_NAME="$1"
COMPONENT2_NAME="$2"
COMPONENT_PORT="$3" # Port passed from command-line
SERVICE_NAME="${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.svc"
COMPONENT1_ROLE="${COMPONENT1_NAME}"
COMPONENT2_ROLE="${COMPONENT2_NAME}"

EDGE_CLOUD=$4

# Set the role based on EDGE_CLOUD value
if [ "$EDGE_CLOUD" == "edge" ]; then
  ROLE_TAG="edge-only"
elif [ "$EDGE_CLOUD" == "cloud" ]; then
  ROLE_TAG="cloud-only"
else
  echo "Unknown EDGE_CLOUD value: $EDGE_CLOUD. Must be 'edge' or 'cloud'."
  exit 1
fi

# Directory where JWTs will be stored (host-mounted from the Controller container)
ARTIFACT_DIR="./persistent/artifacts"

# Ensure artifact directory exists
mkdir -p "$ARTIFACT_DIR"

# Path to each JWT
COMPONENT1_JWT_PATH="${ARTIFACT_DIR}/${COMPONENT1_NAME}.jwt"
COMPONENT2_JWT_PATH="${ARTIFACT_DIR}/${COMPONENT2_NAME}.jwt"

# Initialize a flag to track if both identities already exist
both_identities_exist=true

# Function to handle identity creation and gracefully handle duplicate errors
create_identity() {
  local component_name="$1"
  local component_role="$2"
  local jwt_path="$3"

  if [ -f "$jwt_path" ]; then
    echo "$component_name JWT already exists. Skipping identity creation for $component_name."
  else
    echo "Creating identity for $component_name..."
    output=$(ziti edge create identity "$component_name" -a "$component_role" -o "$jwt_path" 2>&1)

    # Check if the output contains "duplicate value" error and handle it gracefully
    if [ $? -eq 0 ]; then
      echo "$component_name identity created successfully."
      both_identities_exist=false # One identity was just created, so set the flag to false
    elif echo "$output" | grep -q "duplicate value"; then
      echo "Identity $component_name already exists. Skipping creation."
    else
      echo "Error creating $component_name identity. Output: $output"
    fi
  fi
}

# Step 1: Create identity for COMPONENT1
create_identity "$COMPONENT1_NAME" "$COMPONENT1_ROLE" "$COMPONENT1_JWT_PATH"

# Step 2: Create identity for COMPONENT2
create_identity "$COMPONENT2_NAME" "$COMPONENT2_ROLE" "$COMPONENT2_JWT_PATH"

# Check if both identities already existed
if [ "$both_identities_exist" = true ]; then
  echo "Both identities already exist. Stopping script execution."
  exit 0
fi

# Step 3: Create intercept config for the COMPONENT1 to COMPONENT2 service
echo "Creating intercept config for $COMPONENT1_NAME to $COMPONENT2_NAME..."
ziti edge create config "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.intercept.v1" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["ziti.'"$COMPONENT2_NAME"'"], "portRanges":[{"low":'"$COMPONENT_PORT"', "high":'"$COMPONENT_PORT"'}]}'
if [ $? -eq 0 ]; then
  echo "Intercept config created successfully."
else
  echo "Error creating intercept config."
  exit 1
fi

# Step 4: Create host config for COMPONENT2 to bind to the service
echo "Creating host config for $COMPONENT2_NAME..."
ziti edge create config "${COMPONENT2_NAME}.host.v1" host.v1 \
  '{"protocol":"tcp", "address":"'"$COMPONENT2_NAME"'", "port":'"$COMPONENT_PORT"'}'
if [ $? -eq 0 ]; then
  echo "Host config for $COMPONENT2_NAME created successfully."
else
  echo "Error creating host config."
  exit 1
fi

# Step 5: Create the COMPONENT1 to COMPONENT2 service
echo "Creating service for $COMPONENT1_NAME to $COMPONENT2_NAME..."
ziti edge create service "$SERVICE_NAME" --configs "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.intercept.v1","${COMPONENT2_NAME}.host.v1"
if [ $? -eq 0 ]; then
  echo "Service created successfully."
else
  echo "Error creating service."
  exit 1
fi

# Step 6: Create the service-policy for COMPONENT1 to dial to COMPONENT2
echo "Creating service-policy for $COMPONENT1_NAME to dial $COMPONENT2_NAME..."

ziti edge create service-policy "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.dial" Dial \
  --service-roles "@$SERVICE_NAME" \
  --identity-roles "#$COMPONENT1_ROLE" \
  --identity-roles "#$ROLE_TAG"

if [ $? -eq 0 ]; then
  echo "Service-policy for Dial created successfully."
else
  echo "Error creating service-policy for Dial."
  exit 1
fi

# Step 7: Create the service-policy for COMPONENT2 to bind to the service
echo "Creating service-policy for $COMPONENT2_NAME to bind $COMPONENT1_NAME..."
component2_id=$(ziti edge list identities | grep $COMPONENT2_NAME | awk '{print $2}')

ziti edge create service-policy "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.bind" Bind \
  --service-roles "@$SERVICE_NAME" \
  --identity-roles "@${component2_id}" \
  --identity-roles "#$ROLE_TAG"
if [ $? -eq 0 ]; then
  echo "Service-policy for Bind created successfully."
else
  echo "Error creating service-policy for Bind."
  exit 1
fi

# # Step 6: Create the service-policy for COMPONENT1 to dial to COMPONENT2
# echo "Creating service-policy for $COMPONENT1_NAME to dial $COMPONENT2_NAME..."
#
# ziti edge create service-policy "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.dial" Dial \
#   --service-roles "@$SERVICE_NAME" --identity-roles "#$ROLE_TAG"
# if [ $? -eq 0 ]; then
#   echo "Service-policy for Dial created successfully."
# else
#   echo "Error creating service-policy for Dial."
#   exit 1
# fi
#
# # Step 7: Create the service-policy for COMPONENT2 to bind to the service
# echo "Creating service-policy for $COMPONENT2_NAME to bind $COMPONENT1_NAME..."
# component2_id=$(ziti edge list identities | grep $COMPONENT2_NAME | awk '{print $2}')
#
# ziti edge create service-policy "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.bind" Bind \
#   --service-roles "@$SERVICE_NAME" --identity-roles "#$ROLE_TAG"
# if [ $? -eq 0 ]; then
#   echo "Service-policy for Bind created successfully."
# else
#   echo "Error creating service-policy for Bind."
#   exit 1
# fi
#
echo "All configurations for $COMPONENT1_NAME to $COMPONENT2_NAME communication have been completed successfully."
