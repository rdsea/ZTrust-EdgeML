#!/bin/bash

set -euo pipefail

# ==============================================================================
# VARIABLES
# ==============================================================================

# --- Fetch values from Terraform outputs ---
CTRL_IP=$(cd cloud-gcp && terraform output -raw controller_ip)
CLOUD_ROUTER_IP=$(cd cloud-gcp && terraform output -raw controller_ip)
MESSAGEQ_IP=$(cd cloud-gcp && terraform output -raw messageq_ip)
JAEGER_IP=$(cd cloud-gcp && terraform output -raw database_ip)

# --- Load values from the YAML config ---
EDGE_SSH_USER="aaltosea"
EDGE_SSH_PASS="aaltosea"

EDGE_ROUTER_IP="192.168.1.100"
EDGE_APP_IP="192.168.1.101"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Helper function for logging ---
log() {
  echo "############ $1 ############"
}

# --- Generic function to deploy a script to a target machine ---
deploy_script() {
  local target_ip="$1"
  local ssh_user="$2"
  local ssh_pass="$3"
  local setup_script="$4"
  local script_args="$5"
  local local_files="$6"

  log "Deploying to $target_ip"

  # Copy necessary files
  scp "$setup_script" "$ssh_user@$target_ip:~/hong3nguyen/"
  scp "cleaning.sh" "$ssh_user@$target_ip:~/hong3nguyen/"
  if [[ -n "$local_files" ]]; then
    scp -r "$local_files" "$ssh_user@$target_ip:~/hong3nguyen/"
  fi

  # Run cleaning script
  ssh "$ssh_user@$target_ip" "echo '$ssh_pass' | sudo -S bash ~/hong3nguyen/cleaning.sh"

  # Run setup script
  ssh "$ssh_user@$target_ip" \
    "echo '$ssh_pass' | sudo -E -S env $script_args bash ~/hong3nguyen/$(basename "$setup_script")"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  
  # --- Deploy to Edge Router ---
  deploy_script "$EDGE_ROUTER_IP" "$EDGE_SSH_USER" "$EDGE_SSH_PASS" \
    "edge/setup_edge_router.sh" \
    "CLOUD_IP=$CTRL_IP EDGE_IP=$EDGE_ROUTER_IP" \
    ""
  

  # --- Deploy to Edge App ---
  deploy_script "$EDGE_APP_IP" "$EDGE_SSH_USER" "$EDGE_SSH_PASS" \
    "edge/setup_edge_app.sh" \
    "CLOUD_IP=$CTRL_IP EDGE_IP=$EDGE_ROUTER_IP" \
    "edge/docker-compose.template.yml edge/create_id_entities.sh"

  # --- Deploy to Sensors ---
  
  deploy_script "192.168.1.102" "$EDGE_SSH_USER" "aaltosea23" \
    "sensor/setup_sensor.sh" \
    "CLOUD_IP=$CTRL_IP EDGE_IP=$EDGE_ROUTER_IP" \
    "../../../../applications/machine_learning/object_classification/src/loadgen/"
  
  deploy_script "192.168.1.103" "$EDGE_SSH_USER" "aaltosea23" \
    "sensor/setup_sensor.sh" \
    "CLOUD_IP=$CTRL_IP EDGE_IP=$EDGE_ROUTER_IP" \
    "../../../../applications/machine_learning/object_classification/src/loadgen/"
  

  log "Edge and Sensor deployment complete."
}

main "$@"