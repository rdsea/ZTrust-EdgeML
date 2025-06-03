#!/bin/bash
ziti edge create identity "object-detection-client" \
  --jwt-output-file /tmp/object-detection-client.jwt --role-attributes object-detection-client

ziti edge create identity "preprocessing" \
  --jwt-output-file /tmp/preprocessing.jwt --role-attributes preprocessing

ziti edge create identity "ensemble" \
  --jwt-output-file /tmp/ensemble.jwt --role-attributes ensemble

ziti edge create identity "mobilenetv2" \
  --jwt-output-file /tmp/mobilenetv2.jwt --role-attributes mobilenetv2

ziti edge create identity "efficientnetb0" \
  --jwt-output-file /tmp/efficientnetb0.jwt --role-attributes efficientnetb0

ziti edge enroll --jwt /tmp/object-detection-client.jwt --out /tmp/object-detection-client.json

ziti edge enroll --jwt /tmp/preprocessing.jwt --out /tmp/preprocessing.json

ziti edge enroll --jwt /tmp/ensemble.jwt --out /tmp/ensemble.json

ziti edge enroll --jwt /tmp/mobilenetv2.jwt --out /tmp/mobilenetv2.json

ziti edge enroll --jwt /tmp/efficientnetb0.jwt --out /tmp/efficientnetb0.json

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

# Client to preprocessing
ziti edge create config "client-intercept-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["preprocessing.ziti-controller.private"], "portRanges":[{"low":5010, "high":5010}]}'

ziti edge create config "preprocessing-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5010}'

ziti edge create service "preprocessing-service" \
  --configs client-intercept-config,preprocessing-host-config

ziti edge create service-policy "preprocessing-bind-policy" Bind \
  --service-roles '@preprocessing-service' --identity-roles '#preprocessing'

ziti edge create service-policy "preprocessing-dial-policy" Dial \
  --service-roles '@preprocessing-service' --identity-roles '#object-detection-client'

# Preprocessing to ensemble
ziti edge create config "preprocessing-intercept-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["ensemble.ziti-controller.private"], "portRanges":[{"low":5011, "high":5011}]}'

ziti edge create config "ensemble-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5011}'

ziti edge create service "ensemble-service" \
  --configs preprocessing-intercept-config,ensemble-host-config

ziti edge create service-policy "ensemble-bind-policy" Bind \
  --service-roles '@ensemble-service' --identity-roles '#ensemble'

ziti edge create service-policy "ensemble-dial-policy" Dial \
  --service-roles '@ensemble-service' --identity-roles '#preprocessing'

# Ensemble to mobilenetv2
ziti edge create config "ensemble-intercept-mobilenetv2-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["mobilenetv2.ziti-controller.private"], "portRanges":[{"low":5012, "high":5012}]}'

ziti edge create config "mobilenetv2-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5012}'

ziti edge create service "mobilenetv2-service" \
  --configs ensemble-intercept-mobilenetv2-config,mobilenetv2-host-config

ziti edge create service-policy "mobilenetv2-bind-policy" Bind \
  --service-roles '@mobilenetv2-service' --identity-roles '#mobilenetv2'

ziti edge create service-policy "mobilenetv2-dial-policy" Dial \
  --service-roles '@mobilenetv2-service' --identity-roles '#ensemble'

# Ensemble to efficientnetb0
ziti edge create config "ensemble-intercept-efficientnetb0-config" intercept.v1 \
  '{"protocols":["tcp"],"addresses":["efficientnetb0.ziti-controller.private"], "portRanges":[{"low":5012, "high":5012}]}'

ziti edge create config "efficientnetb0-host-config" host.v1 \
  '{"protocol":"tcp", "address":"localhost","port":5012}'

ziti edge create service "efficientnetb0-service" \
  --configs ensemble-intercept-efficientnetb0-config,efficientnetb0-host-config

ziti edge create service-policy "efficientnetb0-bind-policy" Bind \
  --service-roles '@efficientnetb0-service' --identity-roles '#efficientnetb0'

ziti edge create service-policy "efficientnetb0-dial-policy" Dial \
  --service-roles '@efficientnetb0-service' --identity-roles '#ensemble'

ziti edge create edge-router-policy "public-routers" \
  --edge-router-roles '#public-routers' --identity-roles '#all'

ziti edge create service-edge-router-policy "public-routers" \
  --edge-router-roles '#public-routers' --service-roles '#all'
