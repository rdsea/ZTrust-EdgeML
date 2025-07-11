#!/bin/bash

set -euo pipefail

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# Source the common functions
# shellcheck source=common.sh.tmpl
source "../scripts/common.sh"
install_rabbitmq() {
  log "Installing RabbitMQ"
  apt-get update -y
  apt-get install -y curl gnupg apt-transport-https

  # Add RabbitMQ signing keys
  curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | gpg --dearmor > /usr/share/keyrings/com.rabbitmq.team.gpg
  curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | gpg --dearmor > /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg
  curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | gpg --dearmor > /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg

  # Add RabbitMQ apt repositories
  tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu jammy main
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu jammy main
EOF

  # Install Erlang and RabbitMQ
  apt-get update -y
  apt-get install -y erlang-base erlang-crypto erlang-inets erlang-mnesia erlang-os-mon erlang-public-key erlang-runtime-tools erlang-ssl erlang-syntax-tools erlang-tools rabbitmq-server --fix-missing
}

# --- Configure RabbitMQ ---
configure_rabbitmq() {
  log "Configuring RabbitMQ"
  mkdir -p /etc/rabbitmq

  tee /etc/rabbitmq/rabbitmq.conf >/dev/null <<EOF
listeners.tcp.default = 0.0.0.0:5672
management.listener.port = 15672
EOF

  tee /etc/rabbitmq/rabbitmq-env.conf >/dev/null <<EOF
RABBITMQ_NODE_PORT=5672
RABBITMQ_NODENAME=rabbitmq@localhost
EOF

  systemctl restart rabbitmq-server
}



# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
  install_rabbitmq
  configure_rabbitmq
  add_ziti_dns_entries "" ""
  install_ziti_edge_tunnel
  setup_application

  # Create and enroll the Ziti identity
  json_file=$(create_and_enroll_identity "message-queue" "message-queue,cloud")

  # Run the tunnel in the background
  nohup ziti-edge-tunnel run -i "${json_file}" >/var/log/ziti-edge-tunnel.log 2>&1 &

  log "Message Queue setup complete."
}

main "$@"