# Errors

- Controller failed to mount: my hypothesis is because the trust-manager init later than the controller so it can't mount the secret. Solution: restart the pod

```bash
kubectl rollout restart -n ziti-controller deployment ziti-controller-minimal1
```

## Nginx ingress controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx/

# install ingress-nginx
helm install \
  --namespace ingress-nginx --create-namespace --generate-name \
  ingress-nginx/ingress-nginx \
    --set controller.extraArgs.enable-ssl-passthrough=true
```

## Openziti controller

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
kubectl apply -f https://raw.githubusercontent.com/cert-manager/trust-manager/v0.7.0/deploy/crds/trust.cert-manager.io_bundles.yaml
helm install \
    --namespace ziti-controller ziti-controller \
    openziti/ziti-controller \
    --create-namespace \
    --values controller-values.yml

kubectl wait deployments "ziti-controller" \
   --namespace ziti-controller \
   --for condition=Available=True \
   --timeout=240s
```

- Update the DNS to resolve to the advertisedHost by adding (this adds DNS query forwarder for name like \*.example.com)

```
    example.com:53 {
       errors
       cache 30
       forward . 192.168.49.2
    }
```

```bash
kubectl edit configmap "coredns" \
   --namespace kube-system
```

## Ziti cli login

- Add the following to `/etc/hosts` of your client

```
<controller-client-external-ip> ziti-controller-managed.example.com
```

- Login to the controller

```bash
ziti edge login ziti-controller-managed.example.com \
    --yes \
    --username admin \
    --password $(
        kubectl -n ziti-controller \
            get secrets ziti-controller-admin-secret \
                -o go-template='{{index .data "admin-password" | base64decode }}'
        )
```

## Openziti router

```bash
ziti edge create edge-router "router1" \
  --role-attributes "public-routers" \
  --tunneler-enabled --jwt-output-file /tmp/router1.jwt

helm upgrade --install \
  "ziti-router-123456789" \
  openziti/ziti-router \
    --set-file enrollmentJwt=/tmp/router1.jwt \
    --values router-values.yml
```

## Get admin password

```bash
kubectl get secrets "ziti-controller-admin-secret" \
   --namespace ziti-controller \
   --output go-template='{{"\nINFO: Your console https://ziti-controller-managed.example.com/zac/ password for \"admin\" is: "}}{{index .data "admin-password" | base64decode }}{{"\n\n"}}'
```

## Create and enroll identity, configuration, service, and policies

```bash
./create_identity_services.sh
```

## Create tunnel for client

```bash
sudo ziti-edge-tunnel run -i  /tmp/object-detection-client.json
```
