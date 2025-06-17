#!/bin/bash

set -e

# Backup before modifying
cp /etc/hosts /etc/hosts.bak

# Remove entries
sed -i '/ctrl\.cloud\.hong3nguyen\.com/d' /etc/hosts

sed -i '/router\.cloud\.hong3nguyen\.com/d' /etc/hosts

sed -i '/router\.edge\.hong3nguyen\.com/d' /etc/hosts

echo "Removed OpenZiti DNS entries from /etc/hosts"

echo "Shutdown running ziti-edge-tunnel"

SERVICE="ziti-router.service"
if systemctl list-unit-files | grep -q "^$SERVICE"; then
  echo "Found $SERVICE. Disabling, stopping, and cleaning it..."

  sudo systemctl disable --now "$SERVICE"
  sudo systemctl reset-failed "$SERVICE" || true
  sudo systemctl clean --what=state "$SERVICE" || true
  sudo apt-get purge -y openziti-router
  sudo apt autoremove -y

  echo "Done: $SERVICE has been disabled, reset, and cleaned."
else
  echo "Service $SERVICE does not exist. Nothing to do."
fi

# ziti-edge-tunnel pkill
pkill -f ziti-edge-tunnel

echo "Done: ziti-edge-tunnel has been disabled, reset, and cleaned."
