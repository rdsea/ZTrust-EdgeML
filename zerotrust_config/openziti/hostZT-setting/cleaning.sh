#!/bin/bash

set -e

# Backup before modifying
cp /etc/hosts /etc/hosts.bak

# Remove entries
sed -i '/ctrl\.cloud\.hong3nguyen\.com/d' /etc/hosts

sed -i '/router\.cloud\.hong3nguyen\.com/d' /etc/hosts

sed -i '/router\.edge\.hong3nguyen\.com/d' /etc/hosts

echo "Removed OpenZiti DNS entries from /etc/hosts"

SERVICE="ziti-router.service"

if systemctl list-unit-files | grep -q "^$SERVICE"; then
  echo "$SERVICE unit file exists."

  # Now check if it is running
  if systemctl is-active "$SERVICE"; then
    echo "$SERVICE is running. Disabling, stopping, and cleaning it..."

    sudo systemctl disable --now "$SERVICE"
    sudo systemctl reset-failed "$SERVICE" || true
    sudo systemctl clean --what=state "$SERVICE" || true
    sudo apt-get purge -y openziti-router
    sudo apt autoremove -y

    echo "Done: $SERVICE has been disabled, reset, and cleaned."
  else
    echo "$SERVICE is NOT running. Skipping disable and purge."
  fi

else
  echo "Service unit file $SERVICE does not exist. Nothing to do."
fi

# Check if ziti-edge-tunnel is running
echo "Shutdown running ziti-edge-tunnel"
if pgrep -f ziti-edge-tunnel >/dev/null; then
  echo "ziti-edge-tunnel is running. Killing it now..."
  pkill -f ziti-edge-tunnel
  echo "ziti-edge-tunnel has been killed."
else
  echo "ziti-edge-tunnel is NOT running. Nothing to do."
fi
