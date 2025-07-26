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
ZITI_ROUTER_ADVERTISED_ADDRESS="router.edge.hong3nguyen.com"
ZITI_ROUTER_PORT="3022"

ROUTER_NAME="router_edge"
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

# --- Create and enroll the Edge Router ---
create_and_enroll_edge_router() {
  log "Creating and enrolling Edge Router: $ROUTER_NAME"
  local jwt_file="${CURRENT_DIR}/${ROUTER_NAME}.jwt"

  "${ZITI_HOME}/bin/ziti" edge login "https://${ZITI_CTRL_ADVERTISED_ADDRESS}:${ZITI_CTRL_ADVERTISED_PORT}" --yes -u "${ZITI_USER}" -p "${ZITI_PWD}"

  "${ZITI_HOME}/bin/ziti" edge create edge-router "${ROUTER_NAME}" \
    --jwt-output-file "${jwt_file}" \
    --tunneler-enabled

  cat <<EOF >"${ZITI_HOME}/etc/router/bootstrap.env"
ZITI_CTRL_ADVERTISED_ADDRESS='${ZITI_CTRL_ADVERTISED_ADDRESS}'
ZITI_CTRL_ADVERTISED_PORT='${ZITI_CTRL_ADVERTISED_PORT}'
ZITI_ROUTER_ADVERTISED_ADDRESS='${ZITI_ROUTER_ADVERTISED_ADDRESS}'
ZITI_ROUTER_PORT='${ZITI_ROUTER_PORT}'
ZITI_ENROLL_TOKEN='${jwt_file}'
ZITI_BOOTSTRAP_CONFIG_ARGS=''
EOF

  "${ZITI_HOME}/etc/router/bootstrap.bash"
  systemctl enable --now ziti-router.service

  "${ZITI_HOME}/bin/ziti" edge update edge-router "${ROUTER_NAME}" -a 'edge'
}

# --- Register and enroll Ziti tunnel for loadbalancer ---
register_loadbalancer_tunnel() {
  log "Registering and enrolling Ziti tunnel for loadbalancer"
  "${ZITI_HOME}/bin/ziti" edge create identity "loadbalancer" \
    --jwt-output-file /tmp/loadbalancer.jwt --role-attributes loadbalancer,edge

  "${ZITI_HOME}/bin/ziti" edge enroll --jwt /tmp/loadbalancer.jwt --out /tmp/loadbalancer.json

  nohup ziti-edge-tunnel run -i /tmp/loadbalancer.json >/var/log/ziti-edge-tunnel.log 2>&1 &
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Starting Edge Router Setup"
  install_ziti_components
  add_dns_entries
  create_and_enroll_edge_router
  register_loadbalancer_tunnel
  log "Edge Router Setup Complete."
}

main "$@"