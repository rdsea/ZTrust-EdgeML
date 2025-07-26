#!/bin/bash

set -uo pipefail


ZITI_CONTROLLER_ROUTER_IP=$(cd ../cloud/ && terraform output -raw ziti_controller_router_ip)


CLOUD_MESSAGEQ_IP=$(cd ../cloud/ && terraform output -raw cloud_messageq_ip)


CLOUD_DB_IP=$(cd ../cloud/ && terraform output -raw cloud_db_ip)


JAEGER_IP=$(cd ../cloud/ && terraform output -raw jaeger_ip)


source "$(dirname "$0")/common.sh"
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

  ssh "$ssh_user@$target_ip" bash <<EOF
  echo "$ssh_pass" | sudo -S bash -c '
    echo "Shutdown running ziti-edge-tunnel"
    if pgrep -f ziti-edge-tunnel >/dev/null; then
      echo "ziti-edge-tunnel is running. Killing it now..."
      pkill -f ziti-edge-tunnel
      echo "ziti-edge-tunnel has been killed."
    else
      echo "ziti-edge-tunnel is NOT running. Nothing to do."
    fi
  '
EOF
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Killing ziti-edge-tunnel processes on all edge machines"

  # Kill on Edge Router
  
  kill_remote_ziti_tunnel "130.233.195.219" "aaltosea" "aaltosea"
  
  # Kill on Edge App
  
  kill_remote_ziti_tunnel "130.233.195.222" "aaltosea" "aaltosea"
  
  # Kill on Sensors
  
  kill_remote_ziti_tunnel "130.233.195.199" "aaltosea" "aaltosea23"
  
  kill_remote_ziti_tunnel "130.233.195.200" "aaltosea" "aaltosea23"
  

  log "Finished attempting to kill ziti-edge-tunnel processes."

  ssh "hong3nguyen@${ZITI_CONTROLLER_ROUTER_IP}" bash <<'EOF'
  log "Cleaning up Ziti resources..."

# ========== DELETE SERVICES AND CONFIGS ==========
  
    log "Deleting service and configs for: object-detection-client"
    ziti edge delete service-policy "object-detection-client-bind-policy" || true
    ziti edge delete service-policy "object-detection-client-dial-policy" || true
    ziti edge delete service "object-detection-client-service" || true
    ziti edge delete config "object-detection-client-intercept-config" || true
    ziti edge delete config "object-detection-client-host-config" || true
  
    log "Deleting service and configs for: preprocessing"
    ziti edge delete service-policy "preprocessing-bind-policy" || true
    ziti edge delete service-policy "preprocessing-dial-policy" || true
    ziti edge delete service "preprocessing-service" || true
    ziti edge delete config "preprocessing-intercept-config" || true
    ziti edge delete config "preprocessing-host-config" || true
  
    log "Deleting service and configs for: ensemble"
    ziti edge delete service-policy "ensemble-bind-policy" || true
    ziti edge delete service-policy "ensemble-dial-policy" || true
    ziti edge delete service "ensemble-service" || true
    ziti edge delete config "ensemble-intercept-config" || true
    ziti edge delete config "ensemble-host-config" || true
  
    log "Deleting service and configs for: mobilenetv2"
    ziti edge delete service-policy "mobilenetv2-bind-policy" || true
    ziti edge delete service-policy "mobilenetv2-dial-policy" || true
    ziti edge delete service "mobilenetv2-service" || true
    ziti edge delete config "mobilenetv2-intercept-config" || true
    ziti edge delete config "mobilenetv2-host-config" || true
  
    log "Deleting service and configs for: efficientnetb0"
    ziti edge delete service-policy "efficientnetb0-bind-policy" || true
    ziti edge delete service-policy "efficientnetb0-dial-policy" || true
    ziti edge delete service "efficientnetb0-service" || true
    ziti edge delete config "efficientnetb0-intercept-config" || true
    ziti edge delete config "efficientnetb0-host-config" || true
  
    log "Deleting service and configs for: loadbalancer"
    ziti edge delete service-policy "loadbalancer-bind-policy" || true
    ziti edge delete service-policy "loadbalancer-dial-policy" || true
    ziti edge delete service "loadbalancer-service" || true
    ziti edge delete config "loadbalancer-intercept-config" || true
    ziti edge delete config "loadbalancer-host-config" || true
  
    log "Deleting service and configs for: message-queue"
    ziti edge delete service-policy "message-queue-bind-policy" || true
    ziti edge delete service-policy "message-queue-dial-policy" || true
    ziti edge delete service "message-queue-service" || true
    ziti edge delete config "message-queue-intercept-config" || true
    ziti edge delete config "message-queue-host-config" || true
  
    log "Deleting service and configs for: database"
    ziti edge delete service-policy "database-bind-policy" || true
    ziti edge delete service-policy "database-dial-policy" || true
    ziti edge delete service "database-service" || true
    ziti edge delete config "database-intercept-config" || true
    ziti edge delete config "database-host-config" || true
  

# ========== DELETE IDENTITIES ==========

# ========== DELETE POLICIES ==========

  
    ziti edge delete edge-router-policy "public-routers" 
    
  
    ziti edge delete service-edge-router-policy "public-routers" 
    
  
    ziti edge delete edge-router-policy "allow.id.router_edge" 
    
  
    ziti edge delete service-edge-router-policy "allow.svc.router_edge" 
    
  
    ziti edge delete edge-router-policy "allow.id.router_cloud" 
    
  
    ziti edge delete service-edge-router-policy "allow.svc.router_cloud" 
    
  
EOF
}

main "$@"