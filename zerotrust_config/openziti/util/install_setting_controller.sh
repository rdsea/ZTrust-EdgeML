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
