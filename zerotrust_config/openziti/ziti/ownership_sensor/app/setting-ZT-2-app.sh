#!/bin/bash

docker compose -f docker-compose.yml down --volumes

docker compose -f ../ziti-deployment/docker-compose.yml down --volumes --remove-orphans

docker compose -f ../ziti-deployment/docker-compose.yml up -d

# add ipaddress of controller and router to /etc/hosts
# login local machine
ziti edge login localhost:1280 --yes --username admin --password admin

sudo rm -r /tmp/*.json

sudo rm -r /tmp/*.jwt

# login and enroll to /tmp/
./dung_create_id.sh

# docker compose -f docker-compose.yml up
# client not yet runs
# connect those services to ziti network

docker compose -f docker-compose.yml up -d

ZITI_NETWORK=$1
#ZITI_NETWORK="ziti-deployment_ziti"
SERVICES=(
  preprocessing-service
  ensemble
  efficientnetb0-service
  mobilenetv2-service
)

for service in "${SERVICES[@]}"; do
  echo "Connecting $service to $ZITI_NETWORK"
  cmd="docker network connect $ZITI_NETWORK $service"
  eval $cmd
done
