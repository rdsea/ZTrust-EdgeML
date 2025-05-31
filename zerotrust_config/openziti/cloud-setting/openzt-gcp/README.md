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
    --namespace ziti-controller ziti-controller-minimal1 \
    openziti/ziti-controller \
    --create-namespace \
    --values controller-values.yml
```

## Ziti cli login

- Add the following to `/etc/hosts` of your client

```
<controller-client-external-ip> ziti-controller-minimal.example.com
```

- Login to the controller

```bash
ziti edge login ziti-controller-minimal1-client.ziti-controller.svc.cluster.local \
    --yes \
    --username admin \
    --password $(
        kubectl -n ziti-controller \
            get secrets ziti-controller-minimal1-admin-secret \
                -o go-template='{{index .data "admin-password" | base64decode }}'
        )
```

## Openziti router

```bash
ziti edge create edge-router "router1" \
  --tunneler-enabled --jwt-output-file /tmp/router1.jwt

helm upgrade --install \
  --namespace ziti-controller "ziti-router-123456789" \
  openziti/ziti-router \
    --set-file enrollmentJwt=/tmp/router1.jwt \
    --create-namespace \
    --values router-values.yml
```
