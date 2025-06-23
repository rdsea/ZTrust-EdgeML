#!/bin/bash

# Usage check
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <component1-name> <component2-name> <port> <location(edge|cloud)>"
  exit 1
fi

COMPONENT1_NAME="$1"
COMPONENT2_NAME="$2"
COMPONENT_PORT="$3"
EDGE_CLOUD="$4" # edge or cloud

SERVICE_NAME="${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.svc"
COMPONENT1_ROLE="$COMPONENT1_NAME"
COMPONENT2_ROLE="$COMPONENT2_NAME"

# Validate EDGE_CLOUD and set location role tag
if [ "$EDGE_CLOUD" == "edge" ]; then
  LOCATION_ROLE="edge-only"
elif [ "$EDGE_CLOUD" == "cloud" ]; then
  LOCATION_ROLE="cloud-only"
else
  echo "Error: location must be 'edge' or 'cloud'"
  exit 1
fi

ARTIFACT_DIR="./persistent/artifacts"
mkdir -p "$ARTIFACT_DIR"

COMPONENT1_JWT_PATH="${ARTIFACT_DIR}/${COMPONENT1_NAME}.jwt"
COMPONENT2_JWT_PATH="${ARTIFACT_DIR}/${COMPONENT2_NAME}.jwt"

both_identities_exist=true

create_identity() {
  local name="$1"
  local role="$2"
  local jwt="$3"
  local loc_role="$4"

  if [ -f "$jwt" ]; then
    echo "JWT for $name exists, skipping identity creation."
  else
    echo "Creating identity for $name with roles: $role, $loc_role..."
    output=$(ziti edge create identity "$name" -a "$role" -a "$loc_role" -o "$jwt" 2>&1)
    if [ $? -eq 0 ]; then
      echo "Identity $name created."
      both_identities_exist=false
    elif echo "$output" | grep -q "duplicate value"; then
      echo "Identity $name already exists, skipping."
    else
      echo "Error creating identity $name: $output"
      exit 1
    fi
  fi
}

# Create identities
create_identity "$COMPONENT1_NAME" "$COMPONENT1_ROLE" "$COMPONENT1_JWT_PATH" "$LOCATION_ROLE"
create_identity "$COMPONENT2_NAME" "$COMPONENT2_ROLE" "$COMPONENT2_JWT_PATH" "$LOCATION_ROLE"

if [ "$both_identities_exist" = true ]; then
  echo "Both identities already exist, exiting."
  exit 0
fi

# Create configs
echo "Creating intercept config for $COMPONENT1_NAME to $COMPONENT2_NAME..."
ziti edge create config "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.intercept.v1" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["ziti.'"$COMPONENT2_NAME"'"],"portRanges":[{"low":'"$COMPONENT_PORT"',"high":'"$COMPONENT_PORT"'}]}'
if [ $? -ne 0 ]; then
  echo "Failed to create intercept config."
  exit 1
fi

echo "Creating host config for $COMPONENT2_NAME..."
ziti edge create config "${COMPONENT2_NAME}.host.v1" host.v1 \
  '{"protocol":"tcp","address":"'"$COMPONENT2_NAME"'","port":'"$COMPONENT_PORT"'}'
if [ $? -ne 0 ]; then
  echo "Failed to create host config."
  exit 1
fi

# Create service
echo "Creating service $SERVICE_NAME..."
ziti edge create service "$SERVICE_NAME" --configs "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.intercept.v1","${COMPONENT2_NAME}.host.v1"
if [ $? -ne 0 ]; then
  echo "Failed to create service."
  exit 1
fi

# Create service-policy for dial (COMPONENT1)
echo "Creating service-policy (dial) for $COMPONENT1_NAME..."
ziti edge create service-policy "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.dial" Dial \
  --service-roles "@$SERVICE_NAME" \
  --identity-roles "#$COMPONENT1_ROLE"
# --identity-roles "#$LOCATION_ROLE"
if [ $? -ne 0 ]; then
  echo "Failed to create dial service-policy."
  exit 1
fi

# Create service-policy for bind (COMPONENT2)
echo "Creating service-policy (bind) for $COMPONENT2_NAME..."
component2_id=$(ziti edge list identities | grep "$COMPONENT2_NAME" | awk '{print $2}')
if [ -z "$component2_id" ]; then
  echo "Failed to find identity ID for $COMPONENT2_NAME"
  exit 1
fi

ziti edge create service-policy "${COMPONENT1_NAME}-to-${COMPONENT2_NAME}.bind" Bind \
  --service-roles "@$SERVICE_NAME" \
  --identity-roles "@${component2_id}"
#--identity-roles "#$LOCATION_ROLE"
if [ $? -ne 0 ]; then
  echo "Failed to create bind service-policy."
  exit 1
fi

echo "All configurations for $COMPONENT1_NAME to $COMPONENT2_NAME in $EDGE_CLOUD location completed successfully."
