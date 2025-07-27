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

# nginx?
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

