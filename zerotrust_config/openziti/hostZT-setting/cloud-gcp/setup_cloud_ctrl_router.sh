#!/bin/bash

set -e

# Install dependencies
apt-get update -y
apt-get install -y curl unzip jq

# Download Ziti binaries
mkdir -p /opt/ziti/bin
cd /opt/ziti/bin

curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-controller

curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-router

curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-console

# ----------- Set variables -----------
export ZITI_HOME="/opt/openziti"
export ZITI_CTRL_ADVERTISED_ADDRESS="ctrl.cloud.hong3nguyen.com"
export ZITI_CTRL_ADVERTISED_PORT="1280"
export ZITI_USER="admin"
export ZITI_PWD="admin"
export ZITI_BOOTSTRAP_CONFIG_ARGS=""

# ----------- Create bootstrap.env -----------
cat <<EOF >${ZITI_HOME}/etc/controller/bootstrap.env
ZITI_CTRL_ADVERTISED_ADDRESS='$ZITI_CTRL_ADVERTISED_ADDRESS'
ZITI_CTRL_ADVERTISED_PORT='$ZITI_CTRL_ADVERTISED_PORT'
ZITI_USER='$ZITI_USER'
ZITI_PWD='$ZITI_PWD'
ZITI_BOOTSTRAP_CONFIG_ARGS=''
EOF

# ----------- Bootstrap and start controller -----------
${ZITI_HOME}/etc/controller/bootstrap.bash

systemctl enable --now ziti-controller.service

# -----------  wait for controller to come up -----------
sleep 10

# ----------- Add DNS entry for hostname resolution -----------
PUBLIC_IP=$(curl -s ifconfig.me || curl -s https://ipinfo.io/ip)

echo "$PUBLIC_IP ctrl.cloud.hong3nguyen.com" >>/etc/hosts

CURRENT_DIR=$(pwd)
export JWT_FILE="${CURRENT_DIR}/router_cloud.jwt"

# -----------Generate edge router token and config (not enrolled yet) -----------
${ZITI_HOME}/bin/ziti edge login https://$ZITI_CTRL_ADVERTISED_ADDRESS:$ZITI_CTRL_ADVERTISED_PORT --yes -u $ZITI_USER -p $ZITI_PWD

${ZITI_HOME}/bin/ziti edge create edge-router router_cloud \
  --jwt-output-file "$JWT_FILE" \
  --tunneler-enabled

# ----------- (Optional) Write router bootstrap.env -----------
cat <<EOF >${ZITI_HOME}/etc/router/bootstrap.env
ZITI_CTRL_ADVERTISED_ADDRESS='$ZITI_CTRL_ADVERTISED_ADDRESS'
ZITI_CTRL_ADVERTISED_PORT='$ZITI_CTRL_ADVERTISED_PORT'
ZITI_ROUTER_ADVERTISED_ADDRESS='router.cloud.hong3nguyen.com'
ZITI_ROUTER_PORT='3022'
ZITI_ENROLL_TOKEN='$JWT_FILE'
ZITI_BOOTSTRAP_CONFIG_ARGS=''
EOF

# enroll
${ZITI_HOME}/etc/router/bootstrap.bash

systemctl enable --now ziti-router.service

####################################
#    Ziti cloud setting
####################################

# ensemble to messageQ
ziti edge create config "ensemble" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["ensemble.ziti-controller.private"], "portRanges":[{"low":5672, "high":5672}]}'

ziti edge create config "message-queue" host.v1 \
  '{"protocol":"tcp", "address":"message-queue.ziti-controller.private","port":5672}'

ziti edge create service "message-queue-service" \
  --configs ensemble-intercept-message-queue-config,message-queue-host-config

ziti edge create service-policy "message-queue-bind-policy" Bind \
  --service-roles '@message-queue-service' --identity-roles '#message-queue' \
  --identity-roles '#cloud-only'

ziti edge create service-policy "ensemble-dial-policy" Dial \
  --service-roles '@ensemble-service' --identity-roles '#ensemble' \
  --identity-roles '#cloud-only'

# messageQ to database
ziti edge create config "message-queue" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["message-queue.ziti-controller.private"], "portRanges":[{"low":27017, "high":27017}]}'

ziti edge create config "database" host.v1 \
  '{"protocol":"tcp", "address":"database.ziti-controller.private","port":27017}'

ziti edge create service "database-service" \
  --configs message-queue-intercept-database-config,database-host-config

ziti edge create service-policy "database-bind-policy" Bind \
  --service-roles '@database-service' --identity-roles '#database' \
  --identity-roles '#cloud-only'

ziti edge create service-policy "message-queue-dial-policy" Dial \
  --service-roles '@message-queue-service' --identity-roles '#message-queue' \
  --identity-roles '#cloud-only'

# ziti edge create edge-router-policy "public-routers" \
#   --edge-router-roles '#public-routers' --identity-roles '#all'
#
# ziti edge create service-edge-router-policy "public-routers" \
#   --edge-router-roles '#public-routers' --service-roles '#all'

# policy router edge

#ziti edge update edge-router routerCloud  -a 'cloud'
# assigne atribute to the router
ziti edge update edge-router router_cloud -a 'cloud'

# edge router policy
ziti edge create edge-router-policy allow.cloud --edge-router-roles '#cloud' --identity-roles '#cloud'

ziti edge create edge-router-policy cloud-only-routing \
  --identity-roles "#cloud-only" \
  --edge-router-roles "#cloud"
