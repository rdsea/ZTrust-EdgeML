#!/bin/bash

set -euo pipefail

# ==============================================================================
# VARIABLES
# ==============================================================================

# Passed as environment variables from the calling script
export CLOUD_IP="$CLOUD_IP"
export EDGE_IP="$EDGE_IP"

# Ziti configuration from variable_input.yml
ZITI_HOME="/opt/openziti"
ZITI_CTRL_ADVERTISED_ADDRESS="ctrl.cloud.hong3nguyen.com"
ZITI_CTRL_ADVERTISED_PORT="1280"
ZITI_USER="admin"
ZITI_PWD="admin"
ZITI_ROUTER_ADVERTISED_ADDRESS="router.cloud.hong3nguyen.com"

CURRENT_DIR="$(pwd)/hong3nguyen"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Helper function for logging ---
log() {
  echo "--- $1 ---"
}

# --- Install Ziti CLI and Edge Tunnel ---
install_ziti_components() {
  log "Installing Ziti CLI and Edge Tunnel"
  apt-get update -y
  apt-get install -y curl gnupg

  if ! command -v ziti &>/dev/null; then
    log "'ziti' CLI not found — installing..."
    curl -sS https://get.openziti.io/install.bash | bash -s openziti-router
  else
    log "'ziti' CLI is already installed — skipping installation."
  fi

  if ! command -v ziti-edge-tunnel &>/dev/null; then
    log "'ziti-edge-tunnel' not found — installing..."
    curl -sSLf https://get.openziti.io/tun/package-repos.gpg | gpg --batch --yes --dearmor --output /usr/share/keyrings/openziti.gpg
    chmod +r /usr/share/keyrings/openziti.gpg
    echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable jammy main" | tee /etc/apt/sources.list.d/openziti.list >/dev/null
    apt-get update
    apt-get install -y ziti-edge-tunnel
  else
    log "'ziti-edge-tunnel' is already installed — skipping installation."
  fi
}

# --- Add DNS entries for Ziti controllers/routers ---
add_dns_entries() {
  log "Adding Ziti DNS entries to /etc/hosts"
  echo "$CLOUD_IP ctrl.cloud.hong3nguyen.com" >>/etc/hosts
  echo "$CLOUD_IP router.cloud.hong3nguyen.com" >>/etc/hosts
  echo "$EDGE_IP router.edge.hong3nguyen.com" >>/etc/hosts
}

# --- Create and enroll Ziti identity for object-detection-client ---
create_object_detection_identity() {
  log "Creating and enrolling Ziti identity for object-detection-client"
  "${ZITI_HOME}/bin/ziti" edge login "https://${ZITI_CTRL_ADVERTISED_ADDRESS}:${ZITI_CTRL_ADVERTISED_PORT}" --yes -u "${ZITI_USER}" -p "${ZITI_PWD}"

  "${ZITI_HOME}/bin/ziti" edge create identity "object-detection-client-$(cat /etc/hostname)" \
    --jwt-output-file /tmp/object-detection-client.jwt --role-attributes object-detection-client,edge

  "${ZITI_HOME}/bin/ziti" edge enroll --jwt /tmp/object-detection-client.jwt --out /tmp/object-detection-client.json

  nohup ziti-edge-tunnel run -i /tmp/object-detection-client.json >/var/log/ziti-edge-tunnel.log 2>&1 &
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Starting Sensor Setup"
  install_ziti_components
  add_dns_entries
  create_object_detection_identity
  log "Sensor Setup Complete."
}

main "$@"