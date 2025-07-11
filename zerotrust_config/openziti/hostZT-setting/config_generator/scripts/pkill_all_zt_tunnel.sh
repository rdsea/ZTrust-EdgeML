#!/bin/bash

set -euo pipefail

# ==============================================================================
# VARIABLES
# ==============================================================================

EDGE_SSH_USER="aaltosea"
EDGE_SSH_PASS="aaltosea"

EDGE_ROUTER_IP="192.168.1.100"
EDGE_APP_IP="192.168.1.101"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Helper function for logging ---
log() {
  echo "--- $1 ---"
}

# --- Function to kill ziti-edge-tunnel on a remote host ---
kill_remote_ziti_tunnel() {
  local target_ip="$1"
  local ssh_user="$2"
  local ssh_pass="$3"

  log "Attempting to kill ziti-edge-tunnel on $target_ip"

  ssh "$ssh_user@$target_ip" \
    "echo '$ssh_pass' | sudo -S bash -c '\
      echo \"Shutdown running ziti-edge-tunnel\" && \
      if pgrep -f ziti-edge-tunnel >/dev/null; then \
        echo \"ziti-edge-tunnel is running. Killing it now...\" && \
        sudo pkill -f ziti-edge-tunnel && \
        echo \"ziti-edge-tunnel has been killed.\" \
      else \
        echo \"ziti-edge-tunnel is NOT running. Nothing to do.\" \
      fi\
    "
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Killing ziti-edge-tunnel processes on all edge machines"

  # Kill on Edge Router
  kill_remote_ziti_tunnel "$EDGE_ROUTER_IP" "$EDGE_SSH_USER" "$EDGE_SSH_PASS"

  # Kill on Edge App
  kill_remote_ziti_tunnel "$EDGE_APP_IP" "$EDGE_SSH_USER" "$EDGE_SSH_PASS"

  # Kill on Sensors
  
  kill_remote_ziti_tunnel "192.168.1.102" "$EDGE_SSH_USER" "aaltosea23"
  
  kill_remote_ziti_tunnel "192.168.1.103" "$EDGE_SSH_USER" "aaltosea23"
  

  log "Finished attempting to kill ziti-edge-tunnel processes."
}

main "$@"