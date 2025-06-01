#!/bin/bash

FILE_EXEC=$1

# install edge tunnel
# connect those services to ziti network
ZITI_NETWORK="ziti-deployment-sample_ziti"
SERVICES=(
  preprocessing-service
  ensemble
  efficientnetb0-service
  mobilenetv2-service
)

for service in "${SERVICES[@]}"; do
  echo "Connecting $service to $ZITI_NETWORK..."
  docker network connect "$ZITI_NETWORK" "$service"
  docker exec -it $service /bin/bash -c "/data_ziti/install-ziti-edge-tunnel.sh"
done

#
docker cp $FILE_EXEC ziti-controller:/persistent

docker exec -it ziti-controller /var/openziti/ziti-bin/ziti edge login -u admin -p admin

declare -a CONFIGS=(
  "client preprocessing-service 5010 edge"
  "preprocessing-service ensemble 5011 edge"
  "ensemble efficientnetb0-service 5012 edge"
  "ensemble mobilenetv2-service 5012 edge"
)

# registration and enroll
for config in "${CONFIGS[@]}"; do
  echo "  → docker exec -it ziti-controller ./ziti_docker_config_components.sh $config"
  docker exec -it ziti-controller ./ziti_docker_config_components.sh $config
done

docker cp ziti-controller:/persistent/persistent/artifacts .

# enroll
for service in "${SERVICES[@]}"; do
  echo "Enrolling $service to controller"
  docker exec -it $serrvice enroll --jwt /data_ziti/${service}.jwt --identity /data_ziti/${service}.json
done
