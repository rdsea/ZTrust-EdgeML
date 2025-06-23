#!/bin/bash

if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo ".env not found!"
  exit 1
fi

# === Define the stop script ===
STOP_SCRIPT='
echo "Shutdown running ziti-edge-tunnel"
if pgrep -f ziti-edge-tunnel >/dev/null; then
  echo "ziti-edge-tunnel is running. Killing it now..."
  sudo pkill -f ziti-edge-tunnel
  echo "ziti-edge-tunnel has been killed."
else
  echo "ziti-edge-tunnel is NOT running. Nothing to do."
fi
'

# === Loop over IPs and run remotely ===
for ip in "$EDGE_ROUTER_IP" "$EDGE_APP_IP" "$SENSOR_IP_1" "$SENSOR_IP_2"; do
  echo "Running on $ip ..."
  echo $PASS | ssh aaltosea@"$ip" "echo '$PASS' | sudo -S bash $STOP_SCRIPT"
  #ssh aaltosea@"$ip" "$STOP_SCRIPT"
done
