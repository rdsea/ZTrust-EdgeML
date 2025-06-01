#!/bin/bash

# ziti-edge-tunnel takeing sceret from opt
ziti-edge-tunnel run -i /opt/secret.json >/dev/null 2>&1 &

# main application
./run_server.sh
