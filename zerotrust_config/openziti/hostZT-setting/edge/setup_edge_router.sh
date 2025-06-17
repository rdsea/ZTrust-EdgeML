#!/bin/bash

set -e

# export CLOUD_IP=""
# export EDGE_IP=""

CURRENT_DIR=$(pwd)/hong3nguyen

echo "EDGE ROUTER ----------------------------"
echo $CURRENT_DIR
# Install dependencies
#
# Download Ziti binaries
#curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-router
if ! command -v ziti &>/dev/null; then
  echo "'ziti' CLI not found — installing..."
  curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-router
else
  echo "'ziti' CLI is already installed — skipping installation."
fi

# Check if ziti-edge-tunnel is installed
apt install curl gpg -y
# curl -sSLf https://get.openziti.io/tun/package-repos.gpg | gpg --dearmor --output /usr/share/keyrings/openziti.gpg
# chmod -c +r /usr/share/keyrings/openziti.gpg
# echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable jammy main" | tee /etc/apt/sources.list.d/openziti.list >/dev/null
# apt update
# apt install -y ziti-edge-tunnel
if ! command -v ziti-edge-tunnel &>/dev/null; then
  echo "'ziti-edge-tunnel' not found — installing..."
  curl -sSLf https://get.openziti.io/tun/package-repos.gpg | gpg --batch --yes --dearmor --output /usr/share/keyrings/openziti.gpg
  chmod -c +r /usr/share/keyrings/openziti.gpg
  echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable jammy main" | tee /etc/apt/sources.list.d/openziti.list >/dev/null
  apt update
  apt install -y ziti-edge-tunnel
else
  echo "'ziti-edge-tunnel' is already installed — skipping installation."
fi

# ----------- Set variables -----------
export ZITI_HOME="/opt/openziti"
export ZITI_CTRL_ADVERTISED_ADDRESS="ctrl.cloud.hong3nguyen.com"
export ZITI_CTRL_ADVERTISED_PORT="1280"
export ZITI_USER="admin"
export ZITI_PWD="admin"
export ZITI_BOOTSTRAP_CONFIG_ARGS=""
export ZITI_ROUTER_ADVERTISED_ADDRESS="router.cloud.hong3nguyen.com"

# ----------- Add DNS entry for hostname resolution -----------
echo "$CLOUD_IP ctrl.cloud.hong3nguyen.com" >>/etc/hosts
echo "$CLOUD_IP router.cloud.hong3nguyen.com" >>/etc/hosts
echo "$EDGE_IP router.edge.hong3nguyen.com" >>/etc/hosts

export ROUTER_NAME="router_edge"

export JWT_FILE="${CURRENT_DIR}/$ROUTER_NAME.jwt"

# -----------Generate edge router token and config (not enrolled yet) -----------
${ZITI_HOME}/bin/ziti edge login https://$ZITI_CTRL_ADVERTISED_ADDRESS:$ZITI_CTRL_ADVERTISED_PORT --yes -u $ZITI_USER -p $ZITI_PWD

${ZITI_HOME}/bin/ziti edge create edge-router $ROUTER_NAME \
  --jwt-output-file "$JWT_FILE" \
  --tunneler-enabled

${ZITI_HOME}/bin/ziti edge update edge-router $ROUTER_NAME -a 'edge'

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

# ---------------register and enroll ZT tunnel for nginx ------------------
${ZITI_HOME}/bin/ziti edge create identity "loadbalancer" \
  --jwt-output-file /tmp/loadbalancer.jwt --role-attributes loadbalancer

${ZITI_HOME}/bin/ziti edge enroll --jwt /tmp/loadbalancer.jwt --out /tmp/loadbalancer.json

# ziti-edge-tunnel run -i /tmp/loadbalancer.json
#
nohup ziti-edge-tunnel run -i /tmp/loadbalancer.json >/var/log/ziti-edge-tunnel.log 2>&1 &

# edge router policy
${ZITI_HOME}/bin/ziti edge create edge-router-policy allow.edge --edge-router-roles '#edge' --identity-roles '#edge'

${ZITI_HOME}/bin/ziti edge create edge-router-policy edge-only-routing \
  --identity-roles "#edge-only" \
  --edge-router-roles "#edge"
