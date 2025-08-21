#!/bin/bash

# # Ziti configuration from variable_input.yml
# ZITI_HOME=""
# ZITI_CTRL_ADVERTISED_ADDRESS="ctrl.cloud.hong3nguyen.com"
# ZITI_CTRL_ADVERTISED_PORT=""
# ZITI_USER="admin"
# ZITI_PWD="admin"

# --- Log a message ---
log() {
  #echo ">>> $(date '+%Y-%m-%d %H:%M:%S') - $1"
  echo ">>> $(date '+%Y-%m-%d %H:%M:%S.%N') - $1"
}

# log() {
#   echo -e "\n====== $1 ======\n"
# }
# --- Install Ziti CLI ---
install_ziti_cli() {
  apt install curl gpg -y
  log "Installing Ziti CLI"
  if ! command -v ziti &>/dev/null; then
    source /etc/os-release
    curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti-router
    log "Ziti CLI installed."
  else
    log "Ziti CLI is already installed."

  fi
}

# --- Install Ziti Edge Tunnel ---
install_ziti_edge_tunnel() {
  log "Installing Ziti Edge Tunnel"
  if ! command -v ziti-edge-tunnel &>/dev/null; then
    curl -sSLf https://get.openziti.io/tun/package-repos.gpg |
      gpg --dearmor --output /usr/share/keyrings/openziti.gpg

    chmod -c +r /usr/share/keyrings/openziti.gpg

    echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable jammy main" |
      tee /etc/apt/sources.list.d/openziti.list >/dev/null

    apt update

    apt install -y ziti-edge-tunnel
    log "Ziti Edge Tunnel installed."
  else
    log "Ziti Edge Tunnel is already installed."
  fi

}

# # --- Add Ziti DNS entries to /etc/hosts ---
# add_ziti_dns_entries() {
#   log "Adding Ziti DNS entries to /etc/hosts"
#   cloud_ip="$1"
#
#   # Ensure the entries are not already present
#   if ! grep -q "ctrl.cloud.hong3nguyen.com" /etc/hosts; then
#     echo "$cloud_ip ctrl.cloud.hong3nguyen.com" | sudo tee -a /etc/hosts
#     echo "$cloud_ip router.cloud.hong3nguyen.com" | sudo tee -a /etc/hosts
#   fi
#
#   if ! grep -q "router.edge.hong3nguyen.com" /etc/hosts; then
#     echo "130.233.195.219 router.edge.hong3nguyen.com" | sudo tee -a /etc/hosts
#   fi
#
# }

# --- Create and enroll a Ziti identity ---
create_and_enroll_identity() {
  identity_name="$1"
  identity_roles="$2"
  machine_name="$3"
  path="$4"
  jwt_file="${path}/${identity_name}.jwt"
  json_file="${path}/${identity_name}.json"

  log "Creating and enrolling identity: $identity_name  $machine_name"

  if [[ -n "$machine_name" ]]; then
    full_identity="${identity_name}-${machine_name}"
  else
    full_identity="$identity_name"
  fi

  ziti edge login https://${ZITI_CTRL_ADVERTISED_ADDRESS}:${ZITI_CTRL_ADVERTISED_PORT} --yes -u ${ZITI_USER} -p ${ZITI_PWD}

  ziti edge create identity device "$full_identity" -a "$identity_roles" --jwt-output-file "$jwt_file"

  ziti edge enroll --jwt ${jwt_file} --out ${json_file}

}

# --- Function to create Ziti service and policies ---
create_ziti_service() {
  name="$1"
  port="$2"
  intercept_address="$3"
  host_address="$4"
  service_roles="$5"
  bind_identity_roles="$6"
  dial_identity_roles="$7"

  log "Creating Ziti service: $name"

  # Create intercept config
  "$ZITI_CLI" edge create config "${name}-intercept-config" intercept.v1 \
    "{\"protocols\":[\"tcp\"],\"addresses\":[\"${intercept_address}\"], \"portRanges\":[{\"low\":${port}, \"high\":${port}}]}"

  # Create host config
  "$ZITI_CLI" edge create config "${name}-host-config" host.v1 \
    "{\"protocol\":\"tcp\", \"address\":\"${host_address}\",\"port\":${port}}"

  # Create service
  "$ZITI_CLI" edge create service "${name}-service" \
    --configs "${name}-intercept-config,${name}-host-config" --role-attributes "$service_roles"

  # Create bind policy
  "$ZITI_CLI" edge create service-policy "${name}-bind-policy" Bind \
    --service-roles "@${name}-service" --identity-roles "$bind_identity_roles"

  # Create dial policy
  "$ZITI_CLI" edge create service-policy "${name}-dial-policy" Dial \
    --service-roles "@${name}-service" --identity-roles "$dial_identity_roles"
}

wait_for_deployment() {
  ns=$1
  deploy=$2
  echo "Waiting for deployment '$deploy' in namespace '$ns' to be ready..."

  success_msg="deployment \"$deploy\" successfully rolled out"
  timeout=180 # seconds
  interval=10 # seconds
  elapsed=0

  while true; do
    output=$(kubectl rollout status deployment/"$deploy" -n "$ns" --timeout=5s 2>&1 || true)

    if echo "$output" | grep -q "$success_msg"; then
      echo "$output"
      break
    else
      echo "Still waiting: $output"
    fi

    if [ "$elapsed" -ge "$timeout" ]; then
      echo "Timeout waiting for deployment $deploy in namespace $ns"
      exit 1
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
}

setup_localhost() {
  ip=$1
  advertise=$2

  echo "$ip $advertise"
  log "/etc/hosts"
  echo "sudo sed -i.bak \"/$advertise/ s/^/# /\" /etc/hosts"
  sudo sed -i.bak "/$advertise/ s/^/# /" /etc/hosts

  if [ -z "$ip" ]; then
    echo "External IP is not assigned yet. Exiting or waiting..."
    exit 1
  else
    echo "External IP found: $ip"
    echo "$ip $advertise" | sudo tee -a /etc/hosts
  fi
}

setup_router() {
  router_id=$1
  router_namespace=$2
  router_advertise=$3

  log "router"
  # get a router enrollment token from the controller's management API
  ziti edge create edge-router "$router_id" \
    --tunneler-enabled --jwt-output-file $router_id.jwt

  # subscribe to the openziti Helm repo
  if ! helm repo list | grep -q "^openziti"; then
    echo "Adding Helm repo 'openziti'..."
    helm repo add "openziti" "https://openziti.github.io/helm-charts/"
  else
    echo "Helm repo 'openziti' already exists. Skipping."
  fi

  # install the router chart with a public address

  if ! kubectl get namespace "$router_namespace" >/dev/null 2>&1; then
    echo "Creating namespace: $router_namespace"
    kubectl create namespace "$router_namespace"
  else
    echo "Namespace $router_namespace already exists."
  fi

  helm upgrade --install \
    "$router_id" \
    openziti/ziti-router \
    --namespace $router_namespace \
    --set-file enrollmentJwt=$router_id.jwt \
    --set ctrl.endpoint=$ctrl_advertise:443 \
    --set edge.advertisedHost=$router_advertise \
    --set clientApi.service.type=ClusterIP \
    --set clientApi.traefikTcpRoute.enabled=true

  #
  #--set edge.service.type=LoadBalancer \
  #

}

login_zt() {
  ctrl_advertise=$1
  ctrl_pass=$2

  ziti edge login "$ctrl_advertise:443" \
    --yes --username admin \
    --password "$ctrl_pass"

}

wait_for_ip_and_advertise() {
  ip_var_name=$1
  advertise_var_name=$2
  ip_command=$3
  advertise_value=$4

  MAX_RETRIES=20
  RETRY_INTERVAL=5
  RETRIES=0

  while true; do
    local ip_value
    #local advertise_value

    ip_value=$(eval "$ip_command")
    #advertise_value=$(eval "$advertise_command")

    if [[ -n "$ip_value" && -n "$advertise_value" ]]; then
      eval "$ip_var_name=\"$ip_value\""
      eval "$advertise_var_name=\"$advertise_value\""
      break
    fi

    echo "Waiting for $ip_var_name or $advertise_var_name to be available..."
    sleep "$RETRY_INTERVAL"
    RETRIES=$((RETRIES + 1))

    if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
      echo "Timeout waiting for $ip_var_name and $advertise_var_name"
      exit 1
    fi
  done
}

setup_jaeger() {
  # install opentelemetry-operator
  log "jaeger-setup"
  kubectl create ns observability
  kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
  # -n observability

  # Jaeger with in-momory storage
  kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: jaeger-inmemory-instance
  namespace: observability
spec:
  image: jaegertracing/jaeger:latest
  ports:
  - name: jaeger
    port: 16686
  config:
    service:
      extensions: [jaeger_storage, jaeger_query]
      pipelines:
        traces:
          receivers: [otlp]    
          exporters: [jaeger_storage_exporter]
    extensions:
      jaeger_query:
        storage:
          traces: memstore
      jaeger_storage:
        backends:
          memstore:
            memory:
              max_traces: 100000
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    exporters:
      jaeger_storage_exporter:
        trace_storage: memstore
EOF
}

sidecar_jaeger_edge() {
  jaeger_endpoint_ip=$1
  port=$2

  log "sidecar-jaeger-k3s"
  #   kubectl apply -f - <<EOF
  # apiVersion: opentelemetry.io/v1beta1
  # kind: OpenTelemetryCollector
  # metadata:
  #   name: sidecar-for-my-app
  # spec:
  #   mode: sidecar
  #   config:
  #     receivers:
  #       jaeger:
  #         protocols:
  #           thrift_compact: {}
  #     processors:
  #       batch:
  #         send_batch_size: 10000
  #         timeout: 5s
  #     exporters:
  #       otlp:
  #         endpoint: $jaeger_endpoint_ip
  #         tls:
  #           insecure: true  # Set to true if not using TLS
  #     service:
  #       pipelines:
  #         traces:
  #           receivers: [jaeger]
  #           exporters: [otlp]
  # EOF
  kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: sidecar-for-my-app
  namespace: observability
spec:
  mode: sidecar
  config:
    receivers:
      jaeger:
        protocols:
          thrift_compact: {}  # your app sends Jaeger spans via UDP 6831
    processors:
      batch:
        send_batch_size: 10000
        timeout: 1s
    exporters:
      otlp:
        endpoint: "$jaeger_endpoint_ip:$port" # grpc but does not work
        tls:
          insecure: true
      otlphttp:   # use otlphttp instead of otlp
        endpoint: "http://$jaeger_endpoint_ip" # http
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          receivers: [jaeger]
          processors: [batch]
          exporters: [otlphttp]
EOF

}

wait_for_nodes_ready() {
  timeout=300 # seconds
  interval=5
  elapsed=0

  echo "Waiting for all nodes to be Ready..."

  while true; do
    total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | awk '{if($2=="Ready") print $1}' | wc -l)

    if [ "$total_nodes" -gt 0 ] && [ "$total_nodes" -eq "$ready_nodes" ]; then
      echo "All nodes are Ready."
      break
    fi

    if [ "$elapsed" -ge "$timeout" ]; then
      echo "Timeout waiting for nodes to be Ready."
      kubectl get nodes
      exit 1
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
}

setup_kubectl() {
  user=$1
  host=$2
  ssh $user@$host "sudo cat /etc/rancher/k3s/k3s.yaml" >~/.kube/config

  sed -i "s|server: https://.*:6443|server: https://$host:6443|" ~/.kube/config
  #sed -i 's|server: https://.*:6443|server: https://$host:6443|' ~/.kube/config

}

# setup_dns() {
#   # DNS setting
#   # env PUB_CTRL_IP="$PUB_CTRL_IP" envsubst < gke_dns_configmap.yml | kubectl apply -f -
#   floating_ip="$1"
#   hostnames="$2" #"ctrl.cloud.hong3nguyen.com router.cloud.hong3nguyen.com"
#
#   # Get the existing ConfigMap as JSON
#   kubectl -n kube-system get configmap coredns -o json >coredns.json
#
#   # Update NodeHosts safely using jq
#   jq --arg ip "$floating_ip" --arg hosts "$hostnames" \
#     '.data.NodeHosts += "\n\($ip) \($hosts)"' coredns.json >coredns-patched.json
#
#   # Apply the patched ConfigMap
#   kubectl -n kube-system apply -f coredns-patched.json
#
#   # Restart CoreDNS pods
#   kubectl -n kube-system rollout restart deployment coredns
#
#   wait_for_deployment kube-system coredns
#
#   # CUSTOM_DNS_IP=$(kubectl get pod -n kube-system -l app=custom-dns-server -o jsonpath='{.items[0].status.podIP}')
#   # kubectl patch configmap kube-dns -n kube-system --type merge -p "{\"data\":{\"stubDomains\":\"{\\\"hong3nguyen.com\\\":[\\\"$CUSTOM_DNS_IP\\\"]}\"}}"
#   # kubectl delete pods -n kube-system -l k8s-app=kube-dns
#   # wait_for_deployment kube-system  custom-dns-server
#
# }

setup_dns() {
  floating_ip="$1"
  hostnames="$2" # e.g., "ctrl.cloud.hong3nguyen.com router.cloud.hong3nguyen.com"

  # Get the current NodeHosts
  nodehosts=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.NodeHosts}')

  # Check if the entry already exists
  if echo "$nodehosts" | grep -q -F "$floating_ip $hostnames"; then
    echo "DNS entry already exists: $floating_ip $hostnames"
    return
  fi

  echo "Adding DNS entry: $floating_ip $hostnames"

  # Patch the ConfigMap safely
  kubectl -n kube-system get configmap coredns -o json >coredns.json
  jq --arg ip "$floating_ip" --arg hosts "$hostnames" \
    '.data.NodeHosts += "\n\($ip) \($hosts)"' coredns.json >coredns-patched.json
  kubectl -n kube-system apply -f coredns-patched.json

  # Restart CoreDNS pods
  kubectl -n kube-system rollout restart deployment coredns

  wait_for_deployment kube-system coredns
}

# public router
setup_router_traefik() {
  router_id=$1
  advertised_address=$2
  namespace=$1-namespace

  setup_router $router_id $namespace $advertised_address

  kubectl patch pvc $router_id -n $namespace -p '{"spec":{"storageClassName":"local-path"}}'

  # Check if pod is running
  echo "Checking pod status..."

  sleep 5
  POD_STATUS=$(kubectl get pod -n $namespace -l app.kubernetes.io/name=ziti-router -o jsonpath="{.items[0].status.phase}" 2>/dev/null || echo "NotFound")

  if [[ "$POD_STATUS" != "Running" ]]; then
    echo "Pod is not running (status: $POD_STATUS). Deleting pod and waiting..."
    kubectl delete pod -n $namespace -l app.kubernetes.io/name=ziti-router --ignore-not-found

    # Wait for the new pod to be recreated and become Running
    echo "Waiting for pod to become Running..."
    for i in {1..30}; do
      sleep 5
      POD_STATUS=$(kubectl get pod -n $namespace -l app.kubernetes.io/name=ziti-router -o jsonpath="{.items[0].status.phase}" 2>/dev/null || echo "NotFound")
      if [[ "$POD_STATUS" == "Running" ]]; then
        echo "Pod is now Running."
        break
      fi
    done

    if [[ "$POD_STATUS" != "Running" ]]; then
      echo "Pod did not reach Running state in time."
      exit 1
    fi
  else
    echo "Pod is already Running."
  fi

  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $router_id-ingress
  namespace: $namespace
  # annotations:
  #   #ingressClassName: traefik
  #   kubernetes.io/ingress.class: traefik
spec:
  ingressClassName: traefik
  rules:
  - host: $advertised_address
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $router_id-cloud
            port:
              number: 443
EOF
}

# TODO: need to make this function to check if the cilium is already installed
setup_network() {
  TARGET_CILIUM_VERSION="1.18.0"

  if command -v cilium >/dev/null 2>&1 &&
    [ "$(cilium version --client | grep -oP 'cilium-cli/\K[0-9]+\.[0-9]+\.[0-9]+')" = "$TARGET_CILIUM_VERSION" ]; then
    echo "Cilium CLI $TARGET_CILIUM_VERSION already installed, skipping..."
  else
    echo " Installing Cilium CLI $TARGET_CILIUM_VERSION..."
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all \
      https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
  fi

  # Check if Cilium is installed in the cluster
  if kubectl -n kube-system get ds/cilium >/dev/null 2>&1; then
    echo "Cilium already installed in the cluster, skipping cilium install."
  else
    echo "Installing Cilium into the cluster..."
    cilium install --version "$TARGET_CILIUM_VERSION"
  fi

  wait_for_nodes_ready
}

setup_zitiCLI() {
  if ! command -v ziti &>/dev/null; then
    echo "ziti not found, installing..."
    curl -sS https://get.openziti.io/install.bash | sudo bash -s openziti
  else
    echo "ziti is already installed: $(command -v ziti)"
    ziti version
  fi
}

setup_helm() {
  if ! command -v helm &>/dev/null; then
    echo "Helm not found, installing..."
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg >/dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install -y helm
  else
    echo "Helm is already installed: $(command -v helm)"
    helm version
  fi
}

setup_trust() {
  setup_helm

  helm repo add jetstack https://charts.jetstack.io

  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true

  helm upgrade --install trust-manager jetstack/trust-manager \
    --namespace cert-manager
}
