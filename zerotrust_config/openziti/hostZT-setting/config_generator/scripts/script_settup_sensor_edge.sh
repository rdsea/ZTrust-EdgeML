#!/bin/bash

set -euo pipefail

# ==============================================================================
# VARIABLES
# ==============================================================================

# --- Fetch values from Terraform outputs ---
# CTRL_IP=$(cd cloud && terraform output -raw controller_ip)
# CLOUD_ROUTER_IP=$(cd cloud && terraform output -raw controller_ip)
# MESSAGEQ_IP=$(cd cloud && terraform output -raw messageq_ip)
# JAEGER_IP=$(cd cloud && terraform output -raw database_ip)


ZITI_CONTROLLER_ROUTER_IP=$(cd ../cloud/ && terraform output -raw ziti_controller_router_ip)


CLOUD_MESSAGEQ_IP=$(cd ../cloud/ && terraform output -raw cloud_messageq_ip)


CLOUD_DB_IP=$(cd ../cloud/ && terraform output -raw cloud_db_ip)


JAEGER_IP=$(cd ../cloud/ && terraform output -raw jaeger_ip)



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
  shift 5

  log "Deploying to $target_ip"

  scp "$setup_script" "$ssh_user@$target_ip:~/hong3nguyen/"
  scp "cleaning.sh" "$ssh_user@$target_ip:~/hong3nguyen/"
  scp "common.sh" "$ssh_user@$target_ip:~/hong3nguyen/"

  # Now "$@" contains only the optional files
  if [[ "$#" -ge 1 ]]; then
    scp -r "$@" "$ssh_user@$target_ip:~/hong3nguyen/"
  else
    echo "No extra local files to copy."
  fi

  ssh "$ssh_user@$target_ip" "echo '$ssh_pass' | sudo -S bash ~/hong3nguyen/cleaning.sh"

  ssh "$ssh_user@$target_ip" \
    "echo '$ssh_pass' | sudo -E -S env $script_args bash ~/hong3nguyen/$(basename "$setup_script")"
}
# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  # --- Deploy to Edge Router ---
  
  deploy_script "130.233.195.219" "aaltosea" "aaltosea" \
    "../edge/setup_edge_router.sh" \
    "CLOUD_IP=$ZITI_CONTROLLER_ROUTER_IP SSH_USER=aaltosea" 
  

  # --- Deploy to Edge App ---
  
  deploy_script "130.233.195.222" "aaltosea" "aaltosea" \
    "../edge/setup_edge_app.sh" \
    "CLOUD_IP=$ZITI_CONTROLLER_ROUTER_IP JAEGER_IP=$JAEGER_IP SSH_USER=aaltosea" \
    "../edge/docker-compose.yml.tmpl" \
    "../../../../../applications/machine_learning/object_classification/src" \
    "../edge/create_id_entities.sh"
  

  # --- Deploy to Sensors ---
  
  deploy_script "130.233.195.199" "aaltosea" "aaltosea23" \
    "../sensor/setup_sensor.sh" \
    "CLOUD_IP=$ZITI_CONTROLLER_ROUTER_IP SSH_USER=aaltosea" \
    "../../../../../applications/machine_learning/object_classification/src/loadgen" \
    "../image"
  
  deploy_script "130.233.195.200" "aaltosea" "aaltosea23" \
    "../sensor/setup_sensor.sh" \
    "CLOUD_IP=$ZITI_CONTROLLER_ROUTER_IP SSH_USER=aaltosea" \
    "../../../../../applications/machine_learning/object_classification/src/loadgen" \
    "../image"
  

  log "Edge and Sensor deployment complete."
}

main "$@"