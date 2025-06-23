ziti edge create edge-router-policy all-ids-public-ers --identity-roles '#all' --edge-router-roles '#public'

ziti edge update edge-router public-edge-router -a 'public'

ziti edge create service-edge-router-policy router2 --service-roles '#all' --edge-router-roles '#all'


ziti edge create edge-router "routerEdge" --jwt-output-file routerEdge.jwt --tunneler-enabled

ziti edge create edge-router "routerCloud" --jwt-output-file routerCloud.jwt --tunneler-enabled

ziti edge update edge-router routerCloud  -a 'cloud'
ziti edge update edge-router routerEdge  -a 'edge'

ziti edge create edge-router-policy allow.edge --edge-router-roles '#edge' --identity-roles '#edge'

ziti edge create edge-router-policy allow.cloud --edge-router-roles '#cloud' --identity-roles '#cloud'


ziti edge create edge-router-policy cloud-only-routing \
  --identity-roles "#cloud-only" \
  --edge-router-roles "#cloud"

ziti edge create edge-router-policy edge-only-routing \
  --identity-roles "#edge-only" \
  --edge-router-roles "#edge"


# k8s setting
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.10.0

helm install \
    --namespace ziti-controller ziti-controller-minimal1 \
    openziti/ziti-controller \
    --set cert-manager.enabled="true" --set trust-manager.enabled="true" \
        --set clientApi.advertisedHost="34.88.73.136" \
        --set clientApi.advertisedPort="443"


helm install \
    --namespace ziti-controller ziti-controller-minimal1 \
    openziti/ziti-controller \
        --set clientApi.advertisedHost="ziti-controller-minimal.example.com" \
        --set clientApi.advertisedPort="443"
        --set service.type=LoadBalancer

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
kubectl apply -f https://raw.githubusercontent.com/cert-manager/trust-manager/v0.7.0/deploy/crds/trust.cert-manager.io_bundles.yaml

kubectl get secrets -n ziti-controller
kubectl get configmaps -n ziti-controller


## the current instruction does not provide trust setting.

After helm install the controller, we will have a LoadBalancer, then we need to create a domainname and match it with the external IP from the LoadBalancer

```bash
# Set common variables
PKI_ROOT=controller-ca
DNS_NAME=ctrl-ziti.hong3nguyen.fi
IP_ADDR=<IP from LoadBalancer>

# CA
ziti pki create ca $PKI_ROOT

# Create server certs for controller components
ziti pki create server certs/web-identity \
  --pki-root $PKI_ROOT --ca-file ca \
  --dns $DNS_NAME --ip $IP_ADDR

ziti pki create server certs/web-client-identity \
  --pki-root $PKI_ROOT --ca-file ca \
  --dns $DNS_NAME --ip $IP_ADDR

ziti pki create server certs/ctrl-plane-identity \
  --pki-root $PKI_ROOT --ca-file ca \
  --dns $DNS_NAME --ip $IP_ADDR

ziti pki create server certs/ctrl-plane-client-identity \
  --pki-root $PKI_ROOT --ca-file ca \
  --dns $DNS_NAME --ip $IP_ADDR

ziti pki create server certs/edge-signer \
  --pki-root $PKI_ROOT --ca-file ca \
  --dns $DNS_NAME --ip $IP_ADDR
```

kubectl -n ziti-controller get secrets
kubectl -n ziti-controller describe secret ziti-controller-minimal1-web-identity-secret

- setup /etc/hosts
```bash
127.0.0.1 ctrl-ziti.hong3nguyen.fi
```

ziti edge login ctrl-ziti.hong3nguyen.fi:1280 \
    --yes \
    --username admin \
    --password $(
        kubectl -n ziti-controller \
            get secrets ziti-controller-minimal1-admin-secret \
                -o go-template='{{index .data "admin-password" | base64decode }}'
        )
ziti edge login ctrl-ziti.hong3nguyen.fi:443 \
    --yes \
    --username admin \
    --password $(
        kubectl -n ziti-controller \
            get secrets ziti-controller-minimal1-admin-secret \
                -o go-template='{{index .data "admin-password" | base64decode }}'
        )

## work with router
- how to let router know the domain name ctrl.ziti.hong3nguyen.com in local k8s
  - Run a simple DNS server in your cluster (like custom dns server and then configurate the kube-dns points to that dns)

  - NOT WORK Alias hostname and IP for each pods need to know that domain
    - error with nslookup with ping or wget would be fine

```bash
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-hosts
  namespace: kube-system
data:
  hosts: |
    34.118.228.177 ctrl.ziti.hong3nguyen.com
    ::1 ctrl.ziti.hong3nguyen.com

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-dns-server
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: custom-dns-server
  template:
    metadata:
      labels:
        app: custom-dns-server
    spec:
      containers:
      - name: dnsmasq
        image: janeczku/go-dnsmasq:release-1.0.7
        args:
        - --listen=0.0.0.0:53
        - --default-resolver
        - --append-search-domains
        - --hostsfile=/etc/hosts.override
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        volumeMounts:
        - name: hosts
          mountPath: /etc/hosts.override
          subPath: hosts
      volumes:
      - name: hosts
        configMap:
          name: custom-hosts

---
apiVersion: v1
kind: Service
metadata:
  name: custom-dns-service
  namespace: kube-system
spec:
  selector:
    app: custom-dns-server
  ports:
  - port: 53
    targetPort: 53
    protocol: UDP
    name: dns-udp
  - port: 53
    targetPort: 53
    protocol: TCP
    name: dns-tcp

```
- take ip and add from cluster custom-dns-service to hong3.nguyen.com 

```yaml
apiVersion: v1
data:
  stubDomains: |
    {
      "hong3nguyen.com": [
        "34.118.238.7"
      ]
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2025-05-28T06:08:16Z"
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: kube-dns
  namespace: kube-system
  resourceVersion: "1748511447930607001"
  uid: 7ca0465a-14d1-4a7e-9b3c-a6e86977b94a

```

```bash
# get a router enrollment token from the controller's management API
ziti edge create edge-router "router1" \
  --tunneler-enabled --jwt-output-file /tmp/router1.jwt

# install the router chart with a public address
helm upgrade --install \
  "ziti-router-router1" \
  openziti/ziti-router \
    --set-file enrollmentJwt=/tmp/router1.jwt \
    --set ctrl.endpoint=ctrl.ziti.hong3nguyen.com:443 \
    --set edge.advertisedHost=router1.ziti.example.com \
```


#kubectl create configmap ziti-controller-minimal1-ctrl-plane-cas --from-literal=ca.crt="dummy" -n ziti-controller

kubectl get secret ziti-controller-minimal1-ctrl-plane-root-secret -n ziti-controller -o jsonpath='{.data.tls\.crt}' | base64 -d > ctrl-plane-cas.crt

kubectl create configmap ziti-controller-minimal1-ctrl-plane-cas --from-file=ctrl-plane-cas.crt=root-secret-ca.crt -n ziti-controller


kubectl get svc -n ziti-controller

## setting login
kubectl port-forward -n ziti-controller pods/ziti-controller-minimal1-6ff58f69b7-88pvd 1280:1280

 ziti edge login localhost:1280 \
    --yes \
    --username admin \
    --password $(
        kubectl -n ziti-controller \
            get secrets ziti-controller-minimal1-admin-secret \
                -o go-template='{{index .data "admin-password" | base64decode }}'
        )

## adding router has error with domain name ()

helm upgrade ziti-controller-minimal1 openziti/ziti-controller \
  -n ziti-controller \
  --set clientApi.advertisedHost=ziti-controller-minimal1-client.ziti-controller.svc.cluster.local \
  --set clientApi.advertisedPort=443

helm upgrade --install ziti-router-internal openziti/ziti-router \                                                                                                            ─╯
   --set-file enrollmentJwt=routerinternal.jwt --set ctrl.endpoint=ziti-controller.openziti.svc.cluster.local:443 \
    --set edge.advertisedHost=routerinternal.ziti.example.com

helm upgrade --install ziti-router-internal openziti/ziti-router \
   --set-file enrollmentJwt=routerinternal.jwt --set ctrl.endpoint==ziti-controller-minimal1-client.ziti-controller.svc.cluster.local:443  \
    --set edge.advertisedHost=routerinternal.ziti.example.com

