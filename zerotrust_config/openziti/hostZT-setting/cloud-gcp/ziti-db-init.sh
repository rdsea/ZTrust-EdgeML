#!/bin/bash

set -euo pipefail

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Helper function for logging ---
log() {
  echo "--- $1 ---"
}

# --- Install MongoDB ---
install_mongodb() {
  log "Installing MongoDB"
  apt-get update -y
  apt-get install -y gnupg curl

  curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-8.0.list
  apt-get update
  apt-get install -y mongodb-org
  systemctl enable --now mongod
}

# --- Configure MongoDB ---
configure_mongodb() {
  log "Configuring MongoDB"
  mkdir -p /home/hong3nguyen/data/db
  chown -R mongodb:mongodb /home/hong3nguyen/data/db

  tee /etc/mongod.conf >/dev/null <<EOF
net:
  bindIp: 0.0.0.0
  port: 27017
storage:
  dbPath: /home/hong3nguyen/data/db
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
EOF

  systemctl restart mongod

  # Create admin user
  log "Creating MongoDB admin user"
  mongosh <<EOF
use admin
db.createUser({
  user: "guest",
  pwd: "guest",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
})
EOF

  # Enable auth
  sed -i '/^#*security:/a\  authorization: enabled' /etc/mongod.conf
  systemctl restart mongod
}

# --- Configure local DNS for Ziti ---
configure_ziti_dns() {
  log "Configuring Ziti DNS"
  echo " ctrl.cloud.hong3nguyen.com" | tee -a /etc/hosts
  echo " router.cloud.hong3nguyen.com" | tee -a /etc/hosts
}

# --- Install the Ziti Edge Tunnel ---
install_ziti_tunnel() {
  log "Installing Ziti Edge Tunnel"
  curl -sSLf https://get.openziti.io/tun/package-repos.gpg | gpg --dearmor > /usr/share/keyrings/openziti.gpg
  chmod +r /usr/share/keyrings/openziti.gpg
  echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable jammy main" | tee /etc/apt/sources.list.d/openziti.list >/dev/null
  apt-get update
  apt-get install -y ziti-edge-tunnel
}

# --- Create and enroll the Ziti identity ---
create_ziti_identity() {
  log "Creating and enrolling Ziti identity"
  export ZITI_HOME="/opt/openziti"
  export ZITI_CTRL_ADVERTISED_ADDRESS="ctrl.cloud.hong3nguyen.com"
  export ZITI_CTRL_ADVERTISED_PORT="1280"
  export ZITI_USER="admin"
  export ZITI_PWD="admin"

  # Install Ziti CLI if not present
  if ! command -v ziti &>/dev/null; then
    log "Installing Ziti CLI"
    curl -sS https://get.openziti.io/install.bash | bash -s openziti-router
  fi

  # Log in and create the identity
  "$ZITI_HOME/bin/ziti" edge login "https://$ZITI_CTRL_ADVERTISED_ADDRESS:$ZITI_CTRL_ADVERTISED_PORT" --yes -u "$ZITI_USER" -p "$ZITI_PWD"

  "$ZITI_HOME/bin/ziti" edge create identity "database" \
    --jwt-output-file /tmp/database.jwt \
    --role-attributes "database,cloud"

  "$ZITI_HOME/bin/ziti" edge enroll --jwt /tmp/database.jwt --out /tmp/database.json

  # Run the tunnel in the background
  nohup ziti-edge-tunnel run -i /tmp/database.json >/var/log/ziti-edge-tunnel.log 2>&1 &
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  install_mongodb
  configure_mongodb
  configure_ziti_dns
  install_ziti_tunnel
  create_ziti_identity

  log "Database setup complete."
}

main "$@"