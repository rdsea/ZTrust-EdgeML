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
