#!/bin/bash

sed 's/^::1/#&/' /etc/hosts >/tmp/hosts && cat /tmp/hosts >/etc/hosts

# ziti-edge-tunnel takeing sceret from opt
ziti-edge-tunnel run -i /opt/secret.json >/var/log/ziti-edge-tunnel.log 2>&1 &

# main application
./entrypoint.sh
