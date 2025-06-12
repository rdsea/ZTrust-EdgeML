#!/bin/bash

set -e

export PUBLIC_IP=""
CURRENT_DIR=$(pwd)

# Install dependencies
#
# Download Ziti binaries
curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-router

curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-console

# ----------- Set variables -----------
export ZITI_HOME="/opt/openziti"
export ZITI_CTRL_ADVERTISED_ADDRESS="ctrl.cloud.hong3nguyen.com"
export ZITI_CTRL_ADVERTISED_PORT="1280"
export ZITI_USER="admin"
export ZITI_PWD="admin"
export ZITI_BOOTSTRAP_CONFIG_ARGS=""

# ----------- Add DNS entry for hostname resolution -----------
echo "$PUBLIC_IP ctrl.cloud.hong3nguyen.com" >>/etc/hosts
echo "$PUBLIC_IP router.cloud.hong3nguyen.com" >>/etc/hosts

export JWT_FILE="${CURRENT_DIR}/router_edge.jwt"

# -----------Generate edge router token and config (not enrolled yet) -----------
${ZITI_HOME}/bin/ziti edge login https://$ZITI_CTRL_ADVERTISED_ADDRESS:$ZITI_CTRL_ADVERTISED_PORT --yes -u $ZITI_USER -p $ZITI_PWD

${ZITI_HOME}/bin/ziti edge create edge-router router_edge \
  --jwt-output-file "$JWT_FILE" \
  --tunneler-enabled

# ----------- (Optional) Write router bootstrap.env -----------
cat <<EOF >${ZITI_HOME}/etc/router/bootstrap.env
ZITI_CTRL_ADVERTISED_ADDRESS='$ZITI_CTRL_ADVERTISED_ADDRESS'
ZITI_CTRL_ADVERTISED_PORT='$ZITI_CTRL_ADVERTISED_PORT'
ZITI_ROUTER_ADVERTISED_ADDRESS='router.edge.hong3nguyen.com'
ZITI_ROUTER_PORT='3022'
ZITI_ENROLL_TOKEN='$JWT_FILE'
ZITI_BOOTSTRAP_CONFIG_ARGS=''
EOF

# enroll
${ZITI_HOME}/etc/router/bootstrap.bash
systemctl enable --now ziti-router.service
