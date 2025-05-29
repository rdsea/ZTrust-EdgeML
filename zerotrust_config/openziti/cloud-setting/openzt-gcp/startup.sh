#!/bin/bash

set -e

# Install dependencies
apt-get update -y
apt-get install -y curl unzip jq

# Download Ziti binaries
mkdir -p /opt/ziti/bin
cd /opt/ziti/bin
curl -sSLo ziti.tar.gz https://github.com/openziti/ziti/releases/latest/download/ziti-linux-amd64.tar.gz
tar -xzf ziti.tar.gz
chmod +x ziti*
#
# # Add to PATH
# export PATH=$PATH:/opt/ziti/bin
#
# # Create minimal PKI for demo
# mkdir -p /opt/ziti/pki
# cd /opt/ziti/pki
# ziti pki create my-pki
#
# # Initialize controller
# mkdir -p /opt/ziti/controller
# cd /opt/ziti/controller
# ziti controller create my-controller /opt/ziti/pki
#
# # Start controller
# nohup ziti controller run /opt/ziti/controller/ziti-controller.yaml >/opt/ziti/controller.log 2>&1 &
#
# # Wait for controller to come up
# sleep 10
#
# # Enroll router
# mkdir -p /opt/ziti/router
# cd /opt/ziti/router
# ziti edge router create my-router -o my-router.jwt -t edge
# ziti edge enroll my-router.jwt
#
# # Start router
# nohup ziti router run /opt/ziti/router/ziti-router.yaml >/opt/ziti/router.log 2>&1 &
