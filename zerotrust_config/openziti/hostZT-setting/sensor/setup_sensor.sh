#!/bin/bash

set -e

# export CLOUD_IP=""
# export EDGE_IP=""

CURRENT_DIR=$(pwd)

echo "SENSOR --------------------"
apt install curl gpg -y
# Install dependencies
#
# Download Ziti binaries
if ! command -v ziti &>/dev/null; then
  echo "'ziti' CLI not found — installing..."
  curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-router
else
  echo "'ziti' CLI is already installed — skipping installation."
fi

# Check if ziti-edge-tunnel is installed
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
# -----------Generate edge router token and config (not enrolled yet) -----------
${ZITI_HOME}/bin/ziti edge login https://$ZITI_CTRL_ADVERTISED_ADDRESS:$ZITI_CTRL_ADVERTISED_PORT --yes -u $ZITI_USER -p $ZITI_PWD

ziti edge create identity "object-detection-client-$(cat /etc/hostname)" \
  --jwt-output-file /tmp/object-detection-client.jwt --role-attributes object-detection-client

ziti edge enroll --jwt /tmp/object-detection-client.jwt --out /tmp/object-detection-client.json

# ziti-edge-tunnel run -i /tmp/object-detection-client.json
nohup ziti-edge-tunnel run -i /tmp/object-detection-client.json >/var/log/ziti-edge-tunnel.log 2>&1 &
