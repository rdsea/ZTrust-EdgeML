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
ZITI_CLOUD_ROUTER_ADVERTISED_ADDRESS="router.cloud.hong3nguyen.com"
ZITI_EDGE_ROUTER_ADVERTISED_ADDRESS="router.edge.hong3nguyen.com"

CURRENT_DIR="/home/hong3nguyen"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Helper function for logging ---
log() {
  echo "--- $1 ---"
}

# --- Install Ziti CLI ---
install_ziti_cli() {
  log "Installing Ziti CLI"
  if ! command -v ziti &>/dev/null; then
    curl -sS https://get.openziti.io/install.bash | bash -s openziti-router
  else
    log "'ziti' CLI is already installed — skipping installation."
  fi
}

# --- Add DNS entries for Ziti controllers/routers ---
add_dns_entries() {
  log "Adding Ziti DNS entries to /etc/hosts"
  echo "$CLOUD_IP $ZITI_CTRL_ADVERTISED_ADDRESS" >>/etc/hosts
  echo "$CLOUD_IP $ZITI_CLOUD_ROUTER_ADVERTISED_ADDRESS" >>/etc/hosts
  
  echo "$EDGE_IP $ZITI_EDGE_ROUTER_ADVERTISED_ADDRESS" >>/etc/hosts
  
}

# --- Prepare Docker Compose file ---
prepare_docker_compose() {
  log "Preparing Docker Compose file"
  # Ensure envsubst is available
  apt-get update -y && apt-get install -y gettext-base

  # Pass JAEGER_IP from the calling script (script_settup_sensor_edge.sh)
  export JAEGER_IP="$(cd ../cloud-gcp && terraform output -raw database_ip)"

  envsubst <"${CURRENT_DIR}/docker-compose.template.yml" >"${CURRENT_DIR}/docker-compose.yml"
  docker compose -f "${CURRENT_DIR}/docker-compose.yml" down --volumes || true
}

# --- Create and enroll Ziti identities ---
create_and_enroll_ziti_identities() {
  log "Creating and enrolling Ziti identities"
  "${ZITI_HOME}/bin/ziti" edge login "https://${ZITI_CTRL_ADVERTISED_ADDRESS}:${ZITI_CTRL_ADVERTISED_PORT}" --yes --username "${ZITI_USER}" --password "${ZITI_PWD}"

  rm -rf /tmp/*.json /tmp/*.jwt

  # Execute the templated create_id_entities.sh script
  "${CURRENT_DIR}/create_id_entities.sh"
}

# --- Start Docker Compose services ---
start_docker_compose_services() {
  log "Starting Docker Compose services"
  docker compose -f "${CURRENT_DIR}/docker-compose.yml" up -d
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Starting Edge Application Setup"
  install_ziti_cli
  add_dns_entries
  prepare_docker_compose
  create_and_enroll_ziti_identities
  start_docker_compose_services
  log "Edge Application Setup Complete."
}

main "$@"