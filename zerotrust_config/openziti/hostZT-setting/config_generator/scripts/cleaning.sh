#!/bin/bash

set -euo pipefail

# ==============================================================================
# VARIABLES
# ==============================================================================

# Ziti domain names from config
CTRL_DOMAIN="ctrl.cloud.hong3nguyen.com"
CLOUD_ROUTER_DOMAIN="router.cloud.hong3nguyen.com"
EDGE_ROUTER_DOMAIN="router.edge.hong3nguyen.com"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Helper function for logging ---
log() {
  echo "--- $1 ---"
}

# --- Remove Ziti DNS entries from /etc/hosts ---
clean_hosts_file() {
  log "Removing OpenZiti DNS entries from /etc/hosts"
  cp /etc/hosts /etc/hosts.bak
  sed -i "/${CTRL_DOMAIN}/d" /etc/hosts
  sed -i "/${CLOUD_ROUTER_DOMAIN}/d" /etc/hosts
  sed -i "/${EDGE_ROUTER_DOMAIN}/d" /etc/hosts
}

# --- Clean up Ziti Router service ---
clean_ziti_router_service() {
  log "Cleaning Ziti Router service"
  SERVICE="ziti-router.service"

  if systemctl list-unit-files | grep -q "^$SERVICE"; then
    log "$SERVICE unit file exists."
    if systemctl is-active "$SERVICE"; then
      log "$SERVICE is running. Disabling, stopping, and cleaning it..."
      sudo systemctl disable --now "$SERVICE"
      sudo systemctl reset-failed "$SERVICE" || true
      sudo systemctl clean --what=state "$SERVICE" || true
      sudo apt-get purge -y openziti-router
      sudo apt autoremove -y
      log "Done: $SERVICE has been disabled, reset, and cleaned."
    else
      log "$SERVICE is NOT running. Skipping disable and purge."
    fi
  else
    log "Service unit file $SERVICE does not exist. Nothing to do."
  fi
}

# --- Kill running ziti-edge-tunnel processes ---
kill_ziti_edge_tunnel() {
  log "Shutting down running ziti-edge-tunnel processes"
  if pgrep -f ziti-edge-tunnel >/dev/null; then
    log "ziti-edge-tunnel is running. Killing it now..."
    pkill -f ziti-edge-tunnel
    log "ziti-edge-tunnel has been killed."
  else
    log "ziti-edge-tunnel is NOT running. Nothing to do."
  fi
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  clean_hosts_file
  clean_ziti_router_service
  kill_ziti_edge_tunnel
  log "Cleaning script finished."
}

main "$@"