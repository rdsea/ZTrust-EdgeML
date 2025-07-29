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


# k3s setting
- ansible setting 
- inventory yml files to list IP 

## prepare suitors
- install uv/pip/pipx
- install ansible on local machine via (them)
- remember check the location ansbile installed (e.g. .local/bin/uv/ansible) to add to PATH
- prepare k3s_inventory.yml

```bash
ansible-playbook ..
```

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

# add openziti
helm --kubeconfig ~/.kube/config  repo add "openziti" "https://openziti.github.io/helm-charts/"

```
- login from password of ctrl

```bash
kubectl create namespace zt-cluster

# login
sudo ziti edge login https://ctrl.cloud.hong3nguyen.com:443 --yes -u admin -p 2Otm9VingoCCtI9J3D39lO1qkpPBnDoh

# register
sudo ziti edge create edge-router "edgerouter123" \
    --tunneler-enabled --jwt-output-file edgerouter123.jwt

# enroll
helm --kubeconfig ~/.kube/config upgrade --install \
  edgerouter123 \
  openziti/ziti-router \
  --namespace zt-cluster1 \
  --set-file enrollmentJwt=edgerouter123.jwt \
  --set ctrl.endpoint=ctrl.cloud.hong3nguyen.com:443 \
  --set edge.service.type=LoadBalancer \
  --set edge.advertisedHost=router123.edge.hong3nguyen.com

```


