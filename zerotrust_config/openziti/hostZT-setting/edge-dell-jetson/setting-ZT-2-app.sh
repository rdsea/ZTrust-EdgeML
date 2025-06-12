#!/bin/bash

docker compose -f docker-compose.yml down --volumes

ziti edge login https://ctrl.cloud.hong3nguyen.com:1280 --yes --username admin --password admin

sudo rm -r /tmp/*.json

sudo rm -r /tmp/*.jwt

# login and enroll to /tmp/
./dung_create_id.sh

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
