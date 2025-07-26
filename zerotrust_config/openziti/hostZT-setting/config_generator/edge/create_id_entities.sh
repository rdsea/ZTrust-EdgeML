#!/bin/bash

set -euo pipefail

# Source the common functions
# shellcheck source=common.sh.tmpl
source "$(dirname "$0")/common.sh"
# ==============================================================================
# VARIABLES
# ==============================================================================

# Ziti CLI path
ZITI_CLI="/opt/openziti/bin/ziti"
SH_USER="$SSH_USER"


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Creating Ziti Identities, Services, and Policies"

  # Create identities and services for each application
  create_and_enroll_identity "preprocessing" "preprocessing,edge" "" "/home/${SSH_USER}/hong3nguyen"
  
  create_ziti_service \
    "preprocessing" \
    "5010" \
    "preprocessing.ziti-controller.private" \
    "localhost" \
    "preprocessing,edge" \
    "#preprocessing" \
    "#loadbalancer"
  create_and_enroll_identity "ensemble" "ensemble,edge,cloud" "" "/home/${SSH_USER}/hong3nguyen"
  
  create_ziti_service \
    "ensemble" \
    "5011" \
    "ensemble.ziti-controller.private" \
    "localhost" \
    "ensemble,edge,cloud" \
    "#ensemble" \
    "#preprocessing"
  create_and_enroll_identity "mobilenetv2" "mobilenetv2,edge" "" "/home/${SSH_USER}/hong3nguyen"
  
  create_ziti_service \
    "mobilenetv2" \
    "5012" \
    "mobilenetv2.ziti-controller.private" \
    "localhost" \
    "mobilenetv2,edge" \
    "#mobilenetv2" \
    "#ensemble"
  create_and_enroll_identity "efficientnetb0" "efficientnetb0,edge" "" "/home/${SSH_USER}/hong3nguyen"
  
  create_ziti_service \
    "efficientnetb0" \
    "5012" \
    "efficientnetb0.ziti-controller.private" \
    "localhost" \
    "efficientnetb0,edge" \
    "#efficientnetb0" \
    "#ensemble"
  create_ziti_service \
    "loadbalancer" \
    "5009" \
    "loadbalancer.ziti-controller.private" \
    "localhost" \
    "loadbalancer,edge" \
    "#loadbalancer" \
    "#object-detection-client"
  create_ziti_service \
    "message-queue" \
    "5672" \
    "rabbitmq.ziti-controller.private" \
    "localhost" \
    "message-queue,cloud" \
    "#message-queue" \
    "#ensemble"
  create_ziti_service \
    "database" \
    "27017" \
    "database.ziti-controller.private" \
    "localhost" \
    "database,cloud" \
    "#database" \
    "#message-queue"

  # Add specific policies that are not tied to a single application
  log "Creating general Ziti policies"

  
  "$ZITI_CLI" edge create edge-router-policy "public-routers" \
    --edge-router-roles '#public-routers' --identity-roles '#all'
  
  
  "$ZITI_CLI" edge create service-edge-router-policy "public-routers" \
    --edge-router-roles '#public-routers' --service-roles '#all'
  
  
  "$ZITI_CLI" edge create edge-router-policy "allow.id.router_edge" \
    --edge-router-roles '#edge' --identity-roles '#edge'
  
  
  "$ZITI_CLI" edge create service-edge-router-policy "allow.svc.router_edge" \
    --edge-router-roles '#edge' --service-roles '#edge'
  
  
  "$ZITI_CLI" edge create edge-router-policy "allow.id.router_cloud" \
    --edge-router-roles '#cloud' --identity-roles '#cloud'
  
  
  "$ZITI_CLI" edge create service-edge-router-policy "allow.svc.router_cloud" \
    --edge-router-roles '#cloud' --service-roles '#cloud'
  
  

  log "Ziti identity and service creation complete."
}

main "$@"