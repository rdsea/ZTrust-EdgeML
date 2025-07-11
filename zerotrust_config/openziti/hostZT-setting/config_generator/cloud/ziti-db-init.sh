#!/bin/bash

set -euo pipefail

# Source the common functions
# shellcheck source=common.sh.tmpl
source "../scripts/common.sh"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

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

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  install_mongodb
  configure_mongodb
  add_ziti_dns_entries "" ""
  install_ziti_edge_tunnel

  # Create and enroll the Ziti identity
  json_file=$(create_and_enroll_identity "database" "database,cloud")

  # Run the tunnel in the background
  nohup ziti-edge-tunnel run -i "${json_file}" >/var/log/ziti-edge-tunnel.log 2>&1 &

  log "Database setup complete."
}

main "$@"