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

####################################
#    Ziti cloud setting
####################################
# assigne atribute to the router
${ZITI_HOME}/bin/ziti edge update edge-router router_cloud -a 'cloud'

# edge router policy
${ZITI_HOME}/bin/ziti edge create edge-router-policy allow.cloud --edge-router-roles '#cloud' --identity-roles '#cloud'

${ZITI_HOME}/bin/ziti edge create edge-router-policy cloud-only-routing \
  --identity-roles "#cloud-only" \
  --edge-router-roles "#cloud"

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
