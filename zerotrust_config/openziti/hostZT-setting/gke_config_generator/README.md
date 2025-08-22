# CSC cPouta

- login
> source a script from API Access → Download OpenStack RC File v4 from the csc.login

- check basic flavors and images and authentication
```bash
openstack token issue

openstack flavor list

openstack image list --long | grep -i ubuntu

# remove router name and internal network
openstack router remove subnet router-to-public zt-internal-subnet
```

#### Error from certificate
- error from certificate since the k3s setup with the internal IP
- edit the tls with the external IP

```bash
# on master node
# Manually edit /etc/systemd/system/k3s.service or k3s startup options to add:
sudo systemctl stop k3s
ExecStart=/usr/local/bin/k3s server --data-dir /var/lib/rancher/k3s --flannel-backend=none --disable-network-policy --tls-san <PUBLIC_IP>
# or
sudo systemctl edit k3s
# then add
  [Service]
  ExecStart=
  ExecStart=/usr/local/bin/k3s server --tls-san=<PUBLIC_IP>

# Or if you have /etc/rancher/k3s/config.yaml, add:
tls-san:
  - <PUBLIC_IP> 

# finally
sudo systemctl daemon-reload
sudo systemctl restart k3s
```

#### Error from resolve host k3s-master
```bash

sudo vim /etc/hosts
# add 
127.0.0.1   localhost k3s-master
```


# CSC rahti cannot work
- since it does not allow to config with operator

```bash
oc login --token=..................... --server=https://api.csc.fi:6443

oc new-project <project_name> --description "csc_project: <project_ID>"

oc delete project <project_name> # and all name-space

```

# check firewall setting
```bash
terraform import google_compute_firewall.allow_ssh           projects/aalto-t313-cs-e4640/global/firewalls/allow-ssh
terraform import google_compute_firewall.allow_ziti          projects/aalto-t313-cs-e4640/global/firewalls/allow-ziti
terraform import google_compute_firewall.allow_app           projects/aalto-t313-cs-e4640/global/firewalls/allow-app
terraform import google_compute_firewall.allow_metric        projects/aalto-t313-cs-e4640/global/firewalls/allow-metric

terraform import google_compute_firewall.allow_ssh_internal   projects/aalto-t313-cs-e4640/global/firewalls/allow-ssh-internal
terraform import google_compute_firewall.allow_ziti_internal  projects/aalto-t313-cs-e4640/global/firewalls/allow-ziti-internal
terraform import google_compute_firewall.allow_app_internal   projects/aalto-t313-cs-e4640/global/firewalls/allow-app-internal
terraform import google_compute_firewall.allow_metric_internal projects/aalto-t313-cs-e4640/global/firewalls/allow-metric-internal


```
# settup k8s

## Install cert-manager && Install trust-manager (separately)
```bash
helm repo add jetstack https://charts.jetstack.io

helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true

kubectl create namespace ziti
helm upgrade --install trust-manager jetstack/trust-manager \
    --namespace cert-manager \
    --set crds.keep=false \
    --set app.trust.namespace=ziti

```

## Install ziti-controller with embedded trust-manager disabled
```bash
helm install ziti-controller openziti/ziti-controller \
  --namespace ziti \
  --set cert-manager.enabled=false \
  --set trust-manager.enabled=false \
  --set clientApi.advertisedHost="ctrl.cloud.hong3nguyen.com"\
```

# nginx? (NO NEED)
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.extraArgs.enable-ssl-passthrough=true

```

## Login
```bash
# add ip (from kubectl loadbalancer) and advertisedHost to /etc/hosts
tee $(kubectl get svc ziti-controller-client -n ziti3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}') ctrl.cloud.hong3nguyen.com

ziti edge login ctrl.cloud.hong3nguyen.com:443 --yes --username admin --password $(kubectl -n ziti3 get secrets ziti-controller-admin-secret -o go-template='{{index .data "admin-password" | base64decode }}')
```

## router setting 

## DNS setting
- take external_IP from controller and advertisedHost to gke_dns_configmap.yml.tmp
- update dns 
- take IP address of this custom-dns
```bash
kubectl get pod custom-dns-server-68c99c465d-5b24j -n kube-system -o jsonpath='{.status.podIP}'
```
- edit kube-dns

```bash
kubectl edit configmap kube-dns -n kube-system
# then change at below
apiVersion: v1
data:
  stubDomains: |
    {
      "hong3nguyen.com": [
        "10.64.2.10"
      ]
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2025-07-27T17:47:45Z"
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: kube-dns
  namespace: kube-system
  resourceVersion: "1753647547040015001"
  uid: 6eb25816-73c1-4a75-a54d-febaf2debbd6
```
- restart kube-dns
```bash
kubectl delete pods -n kube-system -l k8s-app=kube-dns

```
### Public

### Private
```bash
helm upgrade --install \
  "ziti-router-1" \
  openziti/ziti-router \
    --set-file enrollmentJwt=/tmp/router1.jwt \
    --set ctrl.endpoint=ctrl.ziti.example.com:443 \
    --set linkListeners.transport.enabled=false
```


# [k3s setting](https://github.com/rdsea/EdgeDeviceManagement/tree/main/scripts/k3s) -- from Anh-Dung
- ansible setting 
- inventory yml files to list IP 

## prepare suitors
- install uv/pip/pipx
- install ansible on local machine via (them)
- remember check the location ansbile installed (e.g. .local/bin/uv/ansible) to add to PATH
- prepare k3s_inventory.yml

> ansible-playbook k3s.orchestration.site -i k3s_inventory.yml

## remove the all k3s setting
```yaml
# k3s_teardown.yml
- name: Remove K3s from nodes
  hosts: all
  become: yes
  tasks:
    - name: Run k3s-uninstall.sh if present (server nodes)
      shell: |
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
          /usr/local/bin/k3s-uninstall.sh
        fi
      ignore_errors: yes

    - name: Run k3s-agent-uninstall.sh if present (agent nodes)
      shell: |
        if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
          /usr/local/bin/k3s-agent-uninstall.sh
        fi
      ignore_errors: yes

    - name: Remove leftover kube config
      file:
        path: /etc/rancher
        state: absent
```
> ansible-playbook k3s_teardown.yml -i k3s_inventory.yml

## clean all setting from each machine
```bash
sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
sudo rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /etc/systemd/system/k3s* /var/lib/cni /run/flannel
sudo systemctl daemon-reexec
```

## setup kubectl
- copy from the controller /etc/rancher/k3s/k3s.yaml to local one
```bash
scp aaltosea@<k3s-server-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/config- 
ssh aaltosea@<k3s-server-ip> "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
# (options) if the k3s
kubectl config use-context k3s-ansible
```
#### Errors:
```bash
E0729 15:04:37.911435 1374182 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://130.233.195.214:6443/api?timeout=32s\": dial tcp 130.233.195.214:6443: connect: connection refused"
```
- that means the firewall somewhrere prevents the connection, select another closer machine to work with that
- install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
```bash
# download
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
# install
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl.sha256"

# setup
mkdir -p ~/.kube/
ssh aaltosea@<k3s-server-ip> "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config

# install helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# Default Storage Provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# add openziti
helm --kubeconfig ~/.kube/config  repo add "openziti" "https://openziti.github.io/helm-charts/"

```
- login from password of ctrl

```bash
kubectl create namespace router-edge

# login
sudo ziti edge login https://ctrl.cloud.hong3nguyen.com:443 --yes -u admin -p  wfTIFItNRFhcmCx7bb52QR0ZnuiGThng

# register
sudo ziti edge create edge-router "edgerouter123" \
    --tunneler-enabled --jwt-output-file edgerouter123.jwt

# enroll
helm --kubeconfig ~/.kube/config upgrade --install \
  edgerouter123 \
  openziti/ziti-router \
  --namespace router-edge \
  --set-file enrollmentJwt=edgerouter123.jwt \
  --set ctrl.endpoint=ctrl.cloud.hong3nguyen.com:443 \
  --set edge.service.type=LoadBalancer \
  --set edge.advertisedHost=router123.edge.hong3nguyen.com

```
# Traefik (reverse proxy)

```bash
kubectl edit svc traefik -n kube-system

```
change from LoadBalancer to NodePort
- apply application
- add ingress configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: edgerouter-ingress
  namespace: router-edge
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: router.edge.hong3nguyen.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: edgerouter-edge
            port:
              number: 443
```
### NOTE: checking from this, instead of waiting for external_IP
>kubectl edit ingress "edge-router-ingress" -n "edge-router-namespace"
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"networking.k8s.io/v1","kind":"Ingress","metadata":{"annotations":{"kubernetes.io/ingress.class":"traefik"},"name":"edge-router-ingress","namespace":"edge-router-namespace"},"spec":{"rules":[{"host":"router.edge.hong3nguyen.com","http":{"paths":[{"backend":{"service":{"name":"edge-router-edge","port":{"number":443}}},"path":"/","pathType":"Prefix"}]}}]}}
    kubernetes.io/ingress.class: traefik
  creationTimestamp: "2025-08-05T15:58:21Z"
  generation: 1
  name: edge-router-ingress
  namespace: edge-router-namespace
  resourceVersion: "52251"
  uid: d6389258-911d-4028-96fe-3cab4838834a
spec:
  rules:
  - host: router.edge.hong3nguyen.com
    http:
      paths:
      - backend:
          service:
            name: edge-router-edge
            port:
              number: 443
        path: /
        pathType: Prefix
status:
  loadBalancer:
    ingress:
    - ip: 130.233.195.211
    - ip: 130.233.195.214
```
> curl -k https://router.edge.hong3nguyen.com:30957

#### Example
- echo application
```yaml
# echo-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: test-echo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo
        args:
        - "-text=Hello from Traefik!"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: echo-service
  namespace: test-echo
spec:
  selector:
    app: echo
  ports:
  - port: 80
    targetPort: 5678

```
- kubectl apply 
```yaml
# echo-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo-ingress
  namespace: test-echo
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: echo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: echo-service
            port:
              number: 80

```
- kubectl apply
- test: 
```bash
curl -H "Host: echo.local" http://<IP of cluster workers>:30522

```



# metallb -- NOT work with the University

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
kubectl get pods -n metallb-system
kubectl apply -f k3s_metallb.local.yml
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
        - 130.233.195.218-130.233.195.218

```

# install cilium for metallb
install CLI

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

```
- instsall cilium
```bash
cilium install --version 1.18.0
```

# setup application on gke
mongodb and jaeger
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install mongodb bitnami/mongodb \
  --namespace mongodb --create-namespace \
  --set auth.rootPassword=changeme \
  --set auth.username=guest \
  --set auth.password=guest \
  --set auth.database=object-detection \
  --set mongodb.architecture=replicaSet \
  --set persistence.enabled=true \
  --set persistence.storageClass=standard \
  --set persistence.size=2Gi \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=256Mi \
  --set readinessProbe.initialDelaySeconds=30 \
  --set readinessProbe.periodSeconds=10 \
  --set readinessProbe.failureThreshold=6 \
  --set startupProbe.enabled=true \
  --set startupProbe.initialDelaySeconds=10 \
  --set startupProbe.periodSeconds=10 \
  --set startupProbe.failureThreshold=30 \
  --set podAnnotations.sidecar\\.opentelemetry\\.io/inject="true"

#kubectl patch pvc mongodb -n mongodb -p '{"spec":{"storageClassName":"local-path"}}'



kubectl port-forward svc/mongodb 27017:27017 -n mongodb

```
```bash
# output
MongoDB&reg; can be accessed on the following DNS name(s) and ports from within your cluster:
    mongodb.mongodb.svc.cluster.local
To get the root password run:
    export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace mongodb mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)
To get the password for "guest" run:
    export MONGODB_PASSWORD=$(kubectl get secret --namespace mongodb mongodb -o jsonpath="{.data.mongodb-passwords}" | base64 -d | awk -F',' '{print $1}')
To connect to your database, create a MongoDB&reg; client container:
    kubectl run --namespace mongodb mongodb-client --rm --tty -i --restart='Never' --env="MONGODB_ROOT_PASSWORD=$MONGODB_ROOT_PASSWORD" --image docker.io/bitnami/mongodb:8.0.12-debian-12-r0 --command -- bash
Then, run the following command:
    mongosh admin --host "mongodb" --authenticationDatabase admin -u $MONGODB_ROOT_USER -p $MONGODB_ROOT_PASSWORD
To connect to your database from outside the cluster execute the following commands:
    kubectl port-forward --namespace mongodb svc/mongodb 27017:27017 &
    mongosh --host 127.0.0.1 --authenticationDatabase admin -p $MONGODB_ROOT_PASSWORD

```

## Jaeger setting

### Manual

### Jaeger Operater for automatic
- [Jaeger operator does not work at the moment](https://github.com/jaegertracing/jaeger-operator?tab=readme-ov-file#jaeger-v2-operator), it requires the [Opentelemetry](https://github.com/open-telemetry/opentelemetry-operator) 

```bash
# Install the cert-manager ALREADY HAD

# install the opentelemetry-operator
kubectl create ns observability
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml -n observability

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
```


```bash
# Jaeger with elasticsearch, need to setup elasticsearch first
helm repo add elastic https://helm.elastic.co
#helm install elasticsearch elastic/elasticsearch -n observability # domain elasticsearch-master.observability.svc.cluster.local
# turn off secure TLS from elasticsearch so then we can skip the security
# clean everything possible:
helm install elasticsearch elastic/elasticsearch -n observability -f values_elaticsearch.yml
kubectl get pvc -n observability
kubectl delete pvc -l app=elasticsearch -n observability
kubectl delete pvc -n observability -l app=elasticsearch-master
helm upgrade --install elasticsearch elastic/elasticsearch -n observability -f values_elasticsearch.yml

values_elasticsearch.yaml
replicas: 1

esConfig:
  elasticsearch.yml: |
    cluster.name: "observability-cluster"
    node.name: "elasticsearch-master"
    network.host: 0.0.0.0
    discovery.type: single-node
    xpack.security.enabled: false
    xpack.ml.enabled: false

resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 1Gi
    cpu: 500m

volumeClaimTemplate:
  accessModes: [ "ReadWriteOnce" ]
  resources:
    requests:
      storage: 1Gi

# Disable node roles not needed for a single-node setup
master:
  replicas: 1
data:
  replicas: 0
ingest:
  replicas: 0
coordinating:
  replicas: 0
----
replicas: 1

image:
  repository: docker.elastic.co/elasticsearch/elasticsearch
  tag: "8.13.0"

esconfig:
  elasticsearch.yml: |
    cluster.name: "observability-cluster"
    node.name: "elasticsearch-master"
    network.host: 0.0.0.0
    discovery.type: single-node
    xpack.ml.enabled: false
    xpack.security.enabled: false
    xpack.security.http.ssl.enabled: false
    xpack.security.transport.ssl.enabled: false
auth:
  enabled: false
tls:
  enabled: false
resources:
  requests:
    memory: 1Gi
    cpu: 500m
  limits:
    memory: 1Gi
    cpu: 1
volumeclaimtemplate:
  accessmodes: [ "readwriteonce" ]
  storageclassname: local-path  # <-- add this line
  resources:
    requests:
      storage: 1Gi
# single-node roles
master:
  replicas: 1
data:
  replicas: 0
ingest:
  replicas: 0
coordinating:
  replicas: 0

helm upgrade --install elasticsearch elastic/elasticsearch \
  -n observability -f values_elasticsearch.yaml
```

- setup tls for connect to elasticsearch
> kubectl get secret elasticsearch-master-certs -n observability -o jsonpath="{.data['ca\.crt']}" | base64 --decode > ca.crt
- get user/pass from elasticsearch
> kubectl get secret -n observability elasticsearch-master-credentials -o yaml
```bash
kubectl create secret generic jaeger-es-ca \
  --from-file=ca.crt=./ca.crt \
  -n observability
kubectl delete opentelemetrycollector jaeger-elasticsearch -n observability # to apply the new one
# this one does not work, need to use otel collector
kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-es-collector
  namespace: observability
spec:
  mode: deployment
  image: otel/opentelemetry-collector-contrib:latest
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      batch: {}

    exporters:
      elasticsearch:
        endpoints: ["http://elasticsearch-master.observability.svc.cluster.local:9200"]
        # if have username/password uncomment:
        # user: "elastic"
        # password: "securepass"
        # tls:
        #   ca_file: /etc/certs/ca.crt

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [elasticsearch]
EOF

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
```


```bash
kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: jaeger-elasticsearch
  namespace: observability
spec:
  image: jaegertracing/jaeger:latest
  ports:
    - name: jaeger
      port: 16686
  config:
    service:
      extensions: [jaeger_storage, jaeger_query, healthcheckv2]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [jaeger_storage_exporter]

    extensions:
      healthcheckv2:
        use_v2: true
        http:
          endpoint: 0.0.0.0:13133

      jaeger_query:
        storage:
          traces: es_storage
          metrics: es_storage
          traces_archive: es_archive

      jaeger_storage:
        backends:
          es_storage: &es_config
            elasticsearch:
              server_urls:
                - http://elasticsearch-master.observability.svc.cluster.local:9200
              # tls:
              #   ca_file: /etc/certs/ca.crt
              # options:
              #   username: "elastic"
              #   password: "securepass"
              indices:
                index_prefix: "jaeger-main"
          es_archive:
            elasticsearch:
              server_urls:
                - http://elasticsearch-master.observability.svc.cluster.local:9200
              # tls:
              #   ca_file: /etc/certs/ca.crt
              # options:
              #   username: "elastic"
              #   password: "securepass"
              indices:
                index_prefix: "jaeger-archive"

        metric_backends:
          es_storage: *es_config

    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      batch: {}

    exporters:
      jaeger_storage_exporter:
        trace_storage: es_storage

  volumeMounts:
    - name: es-ca
      mountPath: /etc/certs
      readOnly: true
  volumes:
    - name: es-ca
      secret:
        secretName: jaeger-es-ca
EOF
# setting sidecar in a cluster 
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
      jaeger:                   # sidecar listens for Jaeger spans
        protocols:
          thrift_compact: {}    # on UDP 6831 (default)
    processors:
      batch:                    # groups traces before sending
        send_batch_size: 10000
        timeout: 1s
    exporters:
      otlp:                     # sends traces onward over OTLP
        endpoint: "jaeger-inmemory-instance-collector.observability.svc.cluster.local:4318" # "jaeger-elasticsearch-collector.observability.svc.cluster.local:4317"
        tls:
          insecure: true         # plain HTTP
    service:
      pipelines:
        traces:
          receivers: [jaeger]   # input = Jaeger UDP spans
          processors: [batch]   # process
          exporters: [otlp]     # output = OTLP HTTP to central collector
EOF

# setting sidecar from another cluster to send trace to a jaeger in a cluster
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
        endpoint: "jaeger.hong3nguyen.com:4317" # grpc but does not work
        tls:
          insecure: true
      otlphttp:   # use otlphttp instead of otlp
        endpoint: "http://jaeger.hong3nguyen.com" # http
    service:
      pipelines:
        traces:
          receivers: [jaeger]
          processors: [batch]
          exporters: [otlphttp]
EOF

# apply for a single pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  namespace: observability
  annotations:
    sidecar.opentelemetry.io/inject: "true"
spec:
  containers:
  - name: myapp
    image: jaegertracing/vertx-create-span:operator-e2e-tests
    ports:
      - containerPort: 8080
        protocol: TCP
EOF

kubectl port-forward pod/myapp 8080:8080
curl http://localhost:8080/

# apply for deployment and statefulset
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
  annotations:
    sidecar.opentelemetry.io/inject: "true" # WRONG
spec:
  selector:
    matchLabels:
      app: my-app
  replicas: 1
  template:
    metadata:
      labels:
        app: my-app
      annotations:
        sidecar.opentelemetry.io/inject: "true" # CORRECT
    spec:
      containers:
      - name: myapp
        image: jaegertracing/vertx-create-span:operator-e2e-tests
        ports:
          - containerPort: 8080
            protocol: TCP
EOF

kubectl label namespace test sidecar.opentelemetry.io/inject=enabled
# to accesst via localhost:8080
kubectl port-forward deployment/jaeger-inmemory-instance-collector 8080:16686

```

- apply to helm installation like mongodb

```yaml
# values.yml
architecture: standalone

podAnnotations:
  sidecar.opentelemetry.io/inject: "true"

```

```bash

helm install my-mongodb bitnami/mongodb -f values.yaml --namespace default

```

- Need to send other OpenTelemetryCollector to jaeger collector
- loadlbancer for Jaeger in cloud
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: observability
spec:
  type: LoadBalancer
  selector:
    app: jaeger-inmemory-instance  # <- Ensure this label matches pod
  ports:
    - name: grpc
      port: 4317
      targetPort: 4317
    - name: http
      port: 4318
      targetPort: 4318
EOF
```

# setting sidecar for k3s
```bash
kubectl apply -f - <<EOF
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: sidecar-for-my-app
spec:
  mode: sidecar
  config:
    receivers:
      jaeger:
        protocols:
          thrift_compact: {}
    processors:
      batch:
        send_batch_size: 10000
        timeout: 5s
    exporters:
      otlp:
        endpoint: ${JAEGER_COLLECTOR_IP}
        tls:
          insecure: true  # Set to true if not using TLS
    service:
      pipelines:
        traces:
          receivers: [jaeger]
          exporters: [otlp]
EOF
```

- traefik configuration
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jaeger-ingress
  namespace: observability
spec:
  ingressClassName: traefik
  rules:
    - host: jaeger.hong3nguyen.com
      http:
        paths:
          - path: /v1/traces
            pathType: Prefix
            backend:
              service:
                name: jaeger-inmemory-instance-collector # jaeger-elasticsearch-collector
                port:
                  number: 4318  # HTTP port of OpenTelemetry Collector
          - path: /
            pathType: Prefix
            backend:
              service:
                name: jaeger-inmemory-instance-collector # jaeger-elasticsearch-collector
                port:
                  number: 16686
EOF

```
```elasticsearch.yml
replicas: 1

esconfig:
  elasticsearch.yml: |
    cluster.name: "observability-cluster"
    node.name: "elasticsearch-master"
    network.host: 0.0.0.0
    discovery.type: single-node
auth:
  enabled: false
tls:
  enabled: false
resources:
  requests:
    memory: 1Gi
    cpu: 500m
  limits:
    memory: 1Gi
    cpu: 1
volumeclaimtemplate:
  accessmodes: [ "readwriteonce" ]
  storageclassname: local-path  # <-- add this line
  resources:
    requests:
      storage: 1Gi
# single-node roles
master:
  replicas: 1
data:
  replicas: 0
ingest:
  replicas: 0
coordinating:
  replicas: 0

```

- take ca
> kubectl get secret elasticsearch-master-certs -n observability -o jsonpath="{.data['ca\.crt']}" | base64 --decode > ca.crt
- take user pass
> kubectl get secret -n observability elasticsearch-master-credentials -o yaml
 

```otel-to-jaeger-collector.yml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-to-jaeger
  namespace: observability
spec:
  mode: deployment
  image: otel/opentelemetry-collector-contrib:0.102.0
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      batch: {}
    exporters:
      otlp/jaeger:
        endpoint: jaeger-collector.observability.svc.cluster.local:4317
        tls:
          insecure: true   # set to false if you terminate TLS on Jaeger
      logging:
        loglevel: debug
    service:
      telemetry:
        metrics:
          address: "0.0.0.0:8889"
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [logging,otlp/jaeger]

```
```sidecar-for-my-app.yml
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
        endpoint: "otel-to-jaeger-collector.observability.svc.cluster.local:4317"
        tls:
          insecure: true
      otlphttp:   # use otlphttp instead of otlp
        endpoint: "http://otel-to-jaeger-collector.observability.svc.cluster.local:4318"
    service:
      pipelines:
        traces:
          receivers: [jaeger]
          processors: [batch]
          exporters: [otlp] # [otlphttp] if http

```

```jaeger-collector.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger-collector
  namespace: observability
spec:
  replicas: 1
  selector:
    matchLabels: { app: jaeger-collector }
  template:
    metadata:
      labels: { app: jaeger-collector }
    spec:
      containers:
      - name: collector
        image: jaegertracing/jaeger-collector:1.61.0
        args:
          - "--span-storage.type=elasticsearch"
          - "--es.server-urls=https://elasticsearch-master.observability.svc:9200"
          - "--es.tls.enabled=true"
          - "--es.tls.ca=/etc/certs/ca.crt"
          - "--es.username=elastic"
          - "--es.password=dYfXogEdKMdzWRJ0"
          # **Enable OTLP receiver**
          - "--collector.otlp.enabled=true"
          - "--collector.otlp.grpc.host-port=:4317"
          - "--log-level=debug"

        ports:
        - name: grpc
          containerPort: 14250
        - name: http
          containerPort: 14268
        volumeMounts:
        - name: es-ca
          mountPath: /etc/certs
          readOnly: true
      volumes:
      - name: es-ca
        secret:
          secretName: jaeger-es-ca
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-collector
  namespace: observability
spec:
  selector: { app: jaeger-collector }
  ports:
  - name: grpc
    port: 14250
    targetPort: grpc
  - name: http
    port: 14268
    targetPort: http
  - name: otlp-grpc
    port: 4317
    targetPort: 4317

```
```jaeger-query.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger-query
  namespace: observability
spec:
  replicas: 1
  selector:
    matchLabels: { app: jaeger-query }
  template:
    metadata:
      labels: { app: jaeger-query }
    spec:
      containers:
      - name: query
        image: jaegertracing/jaeger-query:1.61.0
        args:
          - "--span-storage.type=elasticsearch"
          - "--es.server-urls=https://elasticsearch-master.observability.svc:9200"
          # For TLS+auth:
          - "--es.tls.enabled=true"
          - "--es.tls.ca=/etc/certs/ca.crt"
          - "--es.username=elastic"
          - "--es.password=dYfXogEdKMdzWRJ0"
        ports:
        - name: http-query
          containerPort: 16686
        volumeMounts:
        - name: es-ca
          mountPath: /etc/certs
          readOnly: true
      volumes:
      - name: es-ca
        secret:
          secretName: jaeger-es-ca
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-query
  namespace: observability
spec:
  selector: { app: jaeger-query }
  ports:
  - name: http
    port: 16686
    targetPort: http-query

```



- avoid using otel-to-jaeger-collector and jaeger-collector together 
  - use jaeger-collector -- need a test

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger-collector
  namespace: observability
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger-collector
  template:
    metadata:
      labels:
        app: jaeger-collector
    spec:
      containers:
      - name: collector
        image: jaegertracing/jaeger-collector:1.61.0
        args:
          - "--span-storage.type=elasticsearch"
          - "--es.server-urls=https://elasticsearch-master.observability.svc:9200"
          - "--es.tls.enabled=true"
          - "--es.username=elastic"
          - "--es.password=dYfXogEdKMdzWRJ0"
          - "--es.tls.ca=/etc/certs/ca.crt"
          - "--collector.otlp.enabled=true"
          - "--collector.otlp.grpc.host-port=:4317"
          - "--collector.otlp.http.host-port=:4318"
          - "--log-level=debug"
        ports:
        - name: grpc
          containerPort: 4317
        - name: http
          containerPort: 4318
        volumeMounts:
        - name: es-ca
          mountPath: /etc/certs
          readOnly: true
      volumes:
      - name: es-ca
        secret:
          secretName: jaeger-es-ca

---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-simple-collector
  namespace: observability
spec:
  selector: { app: jaeger-simple-collector }
  ports:
  - name: grpc
    port: 14250
    targetPort: grpc
  - name: http
    port: 14268
    targetPort: http
  - name: otlp-grpc
    port: 4317
    targetPort: 4317
  - name: otlp-http
    port: 4318
    targetPort: 4318
```
