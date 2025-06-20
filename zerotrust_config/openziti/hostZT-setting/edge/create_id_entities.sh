#!/bin/bash

ziti edge create identity "object-detection-client-$(cat /etc/hostname)" \
  --jwt-output-file /tmp/object-detection-client.jwt --role-attributes object-detection-client

ziti edge create identity "preprocessing-$(cat /etc/hostname)" \
  --jwt-output-file /tmp/preprocessing.jwt --role-attributes preprocessing

ziti edge create identity "ensemble-$(cat /etc/hostname)" \
  --jwt-output-file /tmp/ensemble.jwt --role-attributes ensemble

ziti edge create identity "mobilenetv2-$(cat /etc/hostname)" \
  --jwt-output-file /tmp/mobilenetv2.jwt --role-attributes mobilenetv2

ziti edge create identity "efficientnetb0"-$(cat /etc/hostname) \
  --jwt-output-file /tmp/efficientnetb0.jwt --role-attributes efficientnetb0

ziti edge enroll --jwt /tmp/object-detection-client.jwt --out /tmp/object-detection-client.json

ziti edge enroll --jwt /tmp/preprocessing.jwt --out /tmp/preprocessing.json

ziti edge enroll --jwt /tmp/ensemble.jwt --out /tmp/ensemble.json

ziti edge enroll --jwt /tmp/mobilenetv2.jwt --out /tmp/mobilenetv2.json

ziti edge enroll --jwt /tmp/efficientnetb0.jwt --out /tmp/efficientnetb0.json

### add loadbalancer jwt and json
# ziti edge create identity "loadbalancer" \
#   --jwt-output-file /tmp/loadbalancer.jwt --role-attributes loadbalancer
#
# ziti edge enroll --jwt /tmp/loadbalancer.jwt --out /tmp/loadbalancer.json

# kubectl create secret generic "preprocessing-sidecar-client-identity" \
#   --from-file=/tmp/preprocessing.json
#
# kubectl create secret generic "ensemble-sidecar-client-identity" \
#   --from-file=/tmp/ensemble.json
#
# kubectl create secret generic "mobilenetv2-sidecar-client-identity" \
#   --from-file=/tmp/mobilenetv2.json
#
# kubectl create secret generic "efficientnetb0-sidecar-client-identity" \
#   --from-file=/tmp/efficientnetb0.json

# ziti edge create config "client-intercept-config" intercept.v1 \
#   '{"protocols":["tcp"],"addresses":["preprocessing.ziti-controller.private"], "portRanges":[{"low":5010, "high":5010}]}'
#
# ziti edge create config "preprocessing-host-config" host.v1 \
#   '{"protocol":"tcp", "address":"localhost","port":5010}'
#
# ziti edge create service "preprocessing-service" \
#   --configs client-intercept-config,preprocessing-host-config
#
# ziti edge create service-policy "preprocessing-bind-policy" Bind \
#   --service-roles '@preprocessing-service' --identity-roles '#preprocessing'
#
# ziti edge create service-policy "preprocessing-dial-policy" Dial \
#   --service-roles '@preprocessing-service' --identity-roles '#object-detection-client'

# Client to loadbalancer
ziti edge create config "client-intercept-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["loadbalancer.ziti-controller.private"], "portRanges":[{"low":5009, "high":5009}]}'

ziti edge create config "loadbalancer-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5009}'

ziti edge create service "loadbalancer-service" \
  --configs client-intercept-config,loadbalancer-host-config

ziti edge create service-policy "loadbalancer-bind-policy" Bind \
  --service-roles '@loadbalancer-service' --identity-roles '#loadbalancer' #--identity-roles '#edge-only'

ziti edge create service-policy "loadbalancer-dial-policy" Dial \
  --service-roles '@loadbalancer-service' --identity-roles '#object-detection-client' #  --identity-roles '#edge-only'

# loadbalancer to preprocessing
ziti edge create config "loadbalancer-intercept-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["preprocessing.ziti-controller.private"], "portRanges":[{"low":5010, "high":5010}]}'

ziti edge create config "preprocessing-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5010}'

ziti edge create service "preprocessing-service" \
  --configs loadbalancer-intercept-config,preprocessing-host-config

ziti edge create service-policy "preprocessing-bind-policy" Bind \
  --service-roles '@preprocessing-service' --identity-roles '#preprocessing' #--identity-roles '#edge-only'

ziti edge create service-policy "preprocessing-dial-policy" Dial \
  --service-roles '@preprocessing-service' --identity-roles '#loadbalancer' #--identity-roles '#edge-only'

# Preprocessing to ensemble
ziti edge create config "preprocessing-intercept-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["ensemble.ziti-controller.private"], "portRanges":[{"low":5011, "high":5011}]}'

ziti edge create config "ensemble-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5011}'

ziti edge create service "ensemble-service" \
  --configs preprocessing-intercept-config,ensemble-host-config

ziti edge create service-policy "ensemble-bind-policy" Bind \
  --service-roles '@ensemble-service' --identity-roles '#ensemble' #--identity-roles '#edge-only'

ziti edge create service-policy "ensemble-dial-policy" Dial \
  --service-roles '@ensemble-service' --identity-roles '#preprocessing' #  --identity-roles '#edge-only'

# Ensemble to mobilenetv2
ziti edge create config "ensemble-intercept-mobilenetv2-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["mobilenetv2.ziti-controller.private"], "portRanges":[{"low":5012, "high":5012}]}'

ziti edge create config "mobilenetv2-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5012}'

ziti edge create service "mobilenetv2-service" \
  --configs ensemble-intercept-mobilenetv2-config,mobilenetv2-host-config

ziti edge create service-policy "mobilenetv2-bind-policy" Bind \
  --service-roles '@mobilenetv2-service' --identity-roles '#mobilenetv2' #--identity-roles '#edge-only'

ziti edge create service-policy "mobilenetv2-dial-policy" Dial \
  --service-roles '@mobilenetv2-service' --identity-roles '#ensemble' # --identity-roles '#edge-only'

# Ensemble to efficientnetb0
ziti edge create config "ensemble-intercept-efficientnetb0-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["efficientnetb0.ziti-controller.private"], "portRanges":[{"low":5012, "high":5012}]}'

ziti edge create config "efficientnetb0-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5012}'

ziti edge create service "efficientnetb0-service" \
  --configs ensemble-intercept-efficientnetb0-config,efficientnetb0-host-config

ziti edge create service-policy "efficientnetb0-bind-policy" Bind \
  --service-roles '@efficientnetb0-service' --identity-roles '#efficientnetb0' #--identity-roles '#edge-only'

ziti edge create service-policy "efficientnetb0-dial-policy" Dial \
  --service-roles '@efficientnetb0-service' --identity-roles '#ensemble' #  --identity-roles '#edge-only'

# ensemble to messageQ
ziti edge create config "ensemble-intercept-message-queue-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["rabbitmq.ziti-controller.private"], "portRanges":[{"low":5672, "high":5672}]}'

ziti edge create config "message-queue-host-config" host.v1 \
  '{"protocol":"tcp", "address":"rabbitmq.ziti-controller.private","port":5672}'

ziti edge create service "message-queue-service" \
  --configs ensemble-intercept-message-queue-config,message-queue-host-config

ziti edge create service-policy "message-queue-bind-policy" Bind \
  --service-roles '@message-queue-service' --identity-roles '#message-queue' # --identity-roles '#cloud-only'

ziti edge create service-policy "ensemble-dial-policy-cloud" Dial \
  --service-roles '@ensemble-service' --identity-roles '#ensemble' # --identity-roles '#cloud-only'

# messageQ to database
ziti edge create config "message-queue-intercept-database-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["database.ziti-controller.private"], "portRanges":[{"low":27017, "high":27017}]}'

ziti edge create config "database-host-config" host.v1 \
  '{"protocol":"tcp", "address":"database.ziti-controller.private","port":27017}'

ziti edge create service "database-service" \
  --configs message-queue-intercept-database-config,database-host-config

ziti edge create service-policy "database-bind-policy" Bind \
  --service-roles '@database-service' --identity-roles '#database' #--identity-roles '#cloud-only'

ziti edge create service-policy "message-queue-dial-policy" Dial \
  --service-roles '@message-queue-service' --identity-roles '#message-queue' #--identity-roles '#cloud-only'

#### policy
# ziti edge create edge-router-policy "public-routers" \
#   --edge-router-roles '#public-routers' --identity-roles '#all'
#
# ziti edge create service-edge-router-policy "public-routers" \
#   --edge-router-roles '#public-routers' --service-roles '#all'
#   Public routers
# ziti edge create edge-router-policy "public-routers" \
#   --edge-router-roles '#public-routers' --identity-roles '#all'
#
# ziti edge create service-edge-router-policy "public-routers" \
#   --edge-router-roles '#public-routers' --service-roles '#all'
