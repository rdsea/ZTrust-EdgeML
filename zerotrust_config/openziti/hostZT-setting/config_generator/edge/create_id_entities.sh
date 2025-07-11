#!/bin/bash

set -euo pipefail

# Source the common functions
# shellcheck source=common.sh.tmpl
source "../scripts/common.sh"

# ==============================================================================
# VARIABLES
# ==============================================================================

# Ziti CLI path
ZITI_CLI="/opt/openziti/bin/ziti"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Function to create Ziti service and policies ---
create_ziti_service() {
  local name="$1"
  local port="$2"
  local intercept_address="$3"
  local host_address="$4"
  local service_roles="$5"
  local bind_identity_roles="$6"
  local dial_identity_roles="$7"

  log "Creating Ziti service: $name"

  # Create intercept config
  "$ZITI_CLI" edge create config "${name}-intercept-config" intercept.v1 \
    "{\"protocols\":[\"tcp\"],\"addresses\":[\"${intercept_address}\"], \"portRanges\":[{\"low\":${port}, \"high\":${port}}]}"

  # Create host config
  "$ZITI_CLI" edge create config "${name}-host-config" host.v1 \
    "{\"protocol\":\"tcp\", \"address\":\"${host_address}\",\"port\":${port}}"

  # Create service
  "$ZITI_CLI" edge create service "${name}-service" \
    --configs "${name}-intercept-config,${name}-host-config" --role-attributes "$service_roles"

  # Create bind policy
  "$ZITI_CLI" edge create service-policy "${name}-bind-policy" Bind \
    --service-roles "@${name}-service" --identity-roles "$bind_identity_roles"

  # Create dial policy
  "$ZITI_CLI" edge create service-policy "${name}-dial-policy" Dial \
    --service-roles "@${name}-service" --identity-roles "$dial_identity_roles"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  log "Creating Ziti Identities, Services, and Policies"

  # Create identities and services for each application
  
  create_and_enroll_identity "object-detection-client-$(cat /etc/hostname)" "object-detection-client,edge"
  
  
  create_and_enroll_identity "preprocessing-$(cat /etc/hostname)" "preprocessing,edge"
  
  create_ziti_service \
    "preprocessing" \
    "5010" \
    "preprocessing.ziti-controller.private" \
    "localhost" \
    "preprocessing,edge" \
    "#preprocessing" \
    "#loadbalancer"
  
  
  create_and_enroll_identity "ensemble-$(cat /etc/hostname)" "ensemble,edge,cloud"
  
  create_ziti_service \
    "ensemble" \
    "5011" \
    "ensemble.ziti-controller.private" \
    "localhost" \
    "ensemble,edge,cloud" \
    "#ensemble" \
    "#preprocessing"
  
  
  create_and_enroll_identity "mobilenetv2-$(cat /etc/hostname)" "mobilenetv2,edge"
  
  create_ziti_service \
    "mobilenetv2" \
    "5012" \
    "mobilenetv2.ziti-controller.private" \
    "localhost" \
    "mobilenetv2,edge" \
    "#mobilenetv2" \
    "#ensemble"
  
  
  create_and_enroll_identity "efficientnetb0-$(cat /etc/hostname)" "efficientnetb0,edge"
  
  create_ziti_service \
    "efficientnetb0" \
    "5012" \
    "efficientnetb0.ziti-controller.private" \
    "localhost" \
    "efficientnetb0,edge" \
    "#efficientnetb0" \
    "#ensemble"
  
  
  create_and_enroll_identity "loadbalancer-$(cat /etc/hostname)" "loadbalancer"
  
  create_ziti_service \
    "loadbalancer" \
    "5009" \
    "loadbalancer.ziti-controller.private" \
    "localhost" \
    "loadbalancer" \
    "#loadbalancer" \
    "#object-detection-client"
  
  
  create_and_enroll_identity "message-queue-$(cat /etc/hostname)" "message-queue,cloud"
  
  create_ziti_service \
    "message-queue" \
    "5672" \
    "rabbitmq.ziti-controller.private" \
    "localhost" \
    "message-queue,cloud" \
    "#message-queue" \
    "#ensemble"
  
  
  create_and_enroll_identity "database-$(cat /etc/hostname)" "database,cloud"
  
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

  "$ZITI_CLI" edge create edge-router-policy allow.id.router_edge --edge-router-roles '#edge' --identity-roles '#edge'
  "$ZITI_CLI" edge create service-edge-router-policy allow.svc.router_edge --edge-router-roles '#edge' --service-roles '#edge'

  "$ZITI_CLI" edge create edge-router-policy allow.id.router_cloud --edge-router-roles '#cloud' --identity-roles '#cloud'
  "$ZITI_CLI" edge create service-edge-router-policy allow.svc.router_cloud --edge-router-roles '#cloud' --service-roles '#cloud'

  log "Ziti identity and service creation complete."
}

main "$@"