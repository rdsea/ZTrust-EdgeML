#!/bin/bash

set -e

export CLOUD_IP=""
export EDGE_IP=""

CURRENT_DIR=$(pwd)

# Download Ziti binaries
curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-router

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

# prepare docker-compose file
envsubst <docker-compose.template.yml >docker-compose.yml

docker compose -f docker-compose.yml down --volumes

${ZITI_HOME}/bin/ziti edge login https://${ZITI_CTRL_ADVERTISED_ADDRESS}:1280 --yes --username admin --password admin

sudo rm -f /tmp/*.json

sudo rm -f /tmp/*.jwt

# login and enroll to /tmp/
./create_id_entities.sh

docker compose -f docker-compose.yml up -d
