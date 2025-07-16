#!/bin/bash

set -euo pipefail

# Source the common functions
# shellcheck source=common.sh.tmpl
source "../scripts/common.sh"

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
ZITI_ROUTER_ADVERTISED_ADDRESS=""

CURRENT_DIR="$(pwd)/hong3nguyen"

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Starting Sensor Setup"
  install_ziti_cli
  install_ziti_edge_tunnel
  add_ziti_dns_entries "$CLOUD_IP" "$EDGE_IP"

  # Create and enroll the Ziti identity
  json_file=$(create_and_enroll_identity "object-detection-client-$(cat /etc/hostname)" "object-detection-client,edge")

  # Run the tunnel in the background
  nohup ziti-edge-tunnel run -i "${json_file}" >/var/log/ziti-edge-tunnel.log 2>&1 &

  log "Sensor Setup Complete."
}

main "$@"