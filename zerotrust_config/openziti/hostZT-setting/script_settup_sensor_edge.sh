#!/bin/bash

CTRL_IP=$(cd cloud-gcp && terraform output -raw controller_ip)

CLOUD_ROUTER_IP=$(cd cloud-gcp && terraform output -raw controller_ip)

MESSAGEQ_IP=$(cd cloud-gcp && terraform output -raw messageq_ip)

# Load .env
# EDGE_ROUTER_IP=""
# EDGE_APP_IP=""
# SENSOR_IP_1=""
# SENSOR_IP_2=""
# # Enable auto export
# PASS=""
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo ".env not found!"
  exit 1
fi

############ work with edge router
echo "############ work with edge router"

scp edge/setup_edge_router.sh aaltosea@$EDGE_ROUTER_IP:~/hong3nguyen
scp cleaning.sh aaltosea@$EDGE_ROUTER_IP:~/hong3nguyen

echo $PASS | ssh aaltosea@$EDGE_ROUTER_IP "echo '$PASS' | sudo -S bash ~/hong3nguyen/cleaning.sh"

echo $PASS | ssh aaltosea@$EDGE_ROUTER_IP \
  "echo '$PASS' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_ROUTER_IP} bash ~/hong3nguyen/setup_edge_router.sh"

############ work with edge app
echo "############ work with edge app"

scp edge/setup_edge_app.sh aaltosea@$EDGE_APP_IP:~/hong3nguyen
scp edge/docker-compose.template.yml aaltosea@$EDGE_APP_IP:~/hong3nguyen
scp edge/create_id_entities.sh aaltosea@$EDGE_APP_IP:~/hong3nguyen

scp cleaning.sh aaltosea@$EDGE_APP_IP:~/hong3nguyen

echo "aaltosea" | ssh -t aaltosea@$EDGE_APP_IP "sudo -S bash ~/hong3nguyen/cleaning.sh"

echo "aaltosea" | ssh -t aaltosea@$EDGE_APP_IP \
  "echo 'aaltosea' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_APP_IP} bash ~/hong3nguyen/setup_edge_app.sh"

############ work with SENSOR_IP_1
echo "############ work with $SENSOR_IP_1"

scp sensor/setup_sensor.sh aaltosea@$SENSOR_IP_1:~/hong3nguyen

scp -r ../../../applications/machine_learning/object_classification/src/loadgen/ aaltosea@$SENSOR_IP_1:~/hong3nguyen

scp cleaning.sh aaltosea@$SENSOR_IP_1:~/hong3nguyen

echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_1 "sudo -S bash ~/hong3nguyen/cleaning.sh"
echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_1 \
  "echo 'aaltosea' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_ROUTER_IP} bash ~/hong3nguyen/setup_sensor.sh"

############ work with SENSOR_IP_2
echo "############ work with $SENSOR_IP_2"
scp sensor/setup_sensor.sh aaltosea@$SENSOR_IP_2:~/hong3nguyen

scp cleaning.sh aaltosea@$SENSOR_IP_2:~/hong3nguyen

scp -r ../../../applications/machine_learning/object_classification/src/loadgen/ aaltosea@$SENSOR_IP_2:~/hong3nguyen

echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_2 "sudo -S bash ~/hong3nguyen/cleaning.sh"
echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_2 \
  "echo 'aaltosea' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_ROUTER_IP} bash ~/hong3nguyen/setup_sensor.sh"
