#!/bin/bash

# add ipaddress of controller and router to /etc/hosts
# login local machine
ziti edge login localhost:1280 --yes --username admin --password admin

# login and enroll to /tmp/
./dung_create_id.sh

# docker compose -f docker-compose.yml up
# client not yet runs
# connect those services to ziti network

docker compose -f docker-compose.yml up -d

ZITI_NETWORK=$1
SERVICES=(
  preprocessing-service
  ensemble
  efficientnetb0-service
  mobilenetv2-service
  mobilenetv2-service
)

for service in "${SERVICES[@]}"; do
  echo "Connecting $service to $ZITI_NETWORK... and instsall ziti-edge-tunnel"
done
