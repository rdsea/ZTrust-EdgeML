#!/bin/bash

CTRL_IP=$(cd cloud-gcp && terraform output -raw controller_ip)
CLOUD_ROUTER_IP=$(cd cloud-gcp && terraform output -raw controller_ip)

EDGE_ROUTER_IP="130.233.195.219"

EDGE_APP_IP="130.233.195.222"

SENSOR_IP_1="130.233.195.199"
SENSOR_IP_2="130.233.195.200"

############ work with edge router
scp edge/setup_edge_router.sh aaltosea@$EDGE_ROUTER_IP:~/hong3nguyen
scp cleaning.sh aaltosea@$EDGE_ROUTER_IP:~/hong3nguyen

echo "aaltosea" | ssh aaltosea@$EDGE_ROUTER_IP "sudo -S bash ~/hong3nguyen/cleaning.sh"

echo "aaltosea" | ssh aaltosea@$EDGE_ROUTER_IP \
  "echo 'aaltosea' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_ROUTER_IP} bash ~/hong3nguyen/setup_edge_router.sh"

############ work with edge app
scp edge/setup_edge_app.sh aaltosea@$EDGE_APP_IP:~/hong3nguyen
scp edge/docker-compose.template.yml aaltosea@$EDGE_APP_IP:~/hong3nguyen
scp edge/create_id_entities.sh aaltosea@$EDGE_APP_IP:~/hong3nguyen

scp cleaning.sh aaltosea@$EDGE_APP_IP:~/hong3nguyen

echo "aaltosea" | ssh -t aaltosea@$EDGE_APP_IP "sudo -S bash ~/hong3nguyen/cleaning.sh"

echo "aaltosea" | ssh -t aaltosea@$EDGE_APP_IP \
  "echo 'aaltosea' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_APP_IP} bash ~/hong3nguyen/setup_edge_app.sh"

############ work with SENSOR_IP_1
scp sensor/setup_sensor.sh aaltosea@$SENSOR_IP_1:~/hong3nguyen

scp cleaning.sh aaltosea@$SENSOR_IP_1:~/hong3nguyen

echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_1 "sudo -S bash ~/hong3nguyen/cleaning.sh"
echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_1 \
  "echo 'aaltosea' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_ROUTER_IP} bash ~/hong3nguyen/setup_sensor.sh"

############ work with SENSOR_IP_2
scp sensor/setup_sensor.sh aaltosea@$SENSOR_IP_2:~/hong3nguyen

scp cleaning.sh aaltosea@$SENSOR_IP_2:~/hong3nguyen

echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_2 "sudo -S bash ~/hong3nguyen/cleaning.sh"
echo "aaltosea23" | ssh -t aaltosea@$SENSOR_IP_2 \
  "echo 'aaltosea' | sudo -E -S env CLOUD_IP=${CTRL_IP} EDGE_IP=${EDGE_ROUTER_IP} bash ~/hong3nguyen/setup_sensor.sh"
