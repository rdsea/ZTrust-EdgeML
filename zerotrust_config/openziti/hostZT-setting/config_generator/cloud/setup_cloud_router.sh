#!/bin/bash


set -euo pipefail

# Source the common functions
# shellcheck source=common.sh.tmpl
source "$(dirname "$0")/common.sh"

# ==============================================================================
# VARIABLES
# ==============================================================================

# Passed as environment variables from the calling script
export CLOUD_IP="$CLOUD_IP"
export SSH_USER="$SSH_USER"

# Ziti configuration from variable_input.yml
ZITI_HOME="/opt/openziti"
ZITI_CTRL_ADVERTISED_ADDRESS="ctrl.cloud.hong3nguyen.com"
ZITI_CTRL_ADVERTISED_PORT="1280"
ZITI_USER="admin"
ZITI_PWD="admin"
ZITI_CLOUD_ROUTER_ADVERTISED_ADDRESS="router.cloud.hong3nguyen.com"

CURRENT_DIR="/home/${SSH_USER}/hong3nguyen"

ROUTER_NAME="cloud_router"
ZITI_EDGE_ROUTER_ADVERTISED_ADDRESS=""
ZITI_ROUTER_PORT=""


# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Create and enroll the Edge Router ---
create_and_enroll_edge_router() {
  log "Creating and enrolling Edge Router: $ROUTER_NAME"
  local jwt_file="${CURRENT_DIR}/${ROUTER_NAME}.jwt"

  ${ZITI_HOME}/bin/ziti edge login https://${ZITI_CTRL_ADVERTISED_ADDRESS}:${ZITI_CTRL_ADVERTISED_PORT} --yes -u ${ZITI_USER} -p ${ZITI_PWD}

  ${ZITI_HOME}/bin/ziti edge create edge-router ${ROUTER_NAME} \
    --jwt-output-file ${jwt_file} \
    --tunneler-enabled

  cat <<EOF >"${ZITI_HOME}/etc/router/bootstrap.env"
ZITI_CTRL_ADVERTISED_ADDRESS='${ZITI_CTRL_ADVERTISED_ADDRESS}'
ZITI_CTRL_ADVERTISED_PORT='${ZITI_CTRL_ADVERTISED_PORT}'
ZITI_ROUTER_ADVERTISED_ADDRESS='${ZITI_EDGE_ROUTER_ADVERTISED_ADDRESS}'
ZITI_ROUTER_PORT='${ZITI_ROUTER_PORT}'
ZITI_ENROLL_TOKEN='${jwt_file}'
ZITI_BOOTSTRAP_CONFIG_ARGS=''
EOF

  "${ZITI_HOME}/etc/router/bootstrap.bash"
  systemctl enable --now ziti-router.service

  "${ZITI_HOME}/bin/ziti" edge update edge-router "${ROUTER_NAME}" -a ''
}

# --- Register and enroll Ziti tunnel for loadbalancer ---
register_loadbalancer_tunnel() {
  log "Registering and enrolling Ziti tunnel for loadbalancer"
  create_and_enroll_identity "loadbalancer" "loadbalancer,edge" "" "/home/${SSH_USER}/hong3nguyen"

  nohup ziti-edge-tunnel run -i "/home/${SSH_USER}/hong3nguyen/loadbalancer.json" >/var/log/ziti-edge-tunnel.log 2>&1 &
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Starting Edge Router Setup"
  rm -rf $CURRENT_DIR/*.json $CURRENT_DIR/*.jwt

  install_ziti_cli
  install_ziti_edge_tunnel
  add_ziti_dns_entries "$CLOUD_IP"
  create_and_enroll_edge_router

  register_loadbalancer_tunnel
  log "Edge Router Setup Complete."
}

main "$@"
