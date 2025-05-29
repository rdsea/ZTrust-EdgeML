# Errors

- Controller failed to mount: my hypothesis is because the trust-manager init later than the controller so it can't mount the secret. Solution: restart the pod

```bash
kubectl rollout restart -n ziti-controller deployment ziti-controller-minimal1
```
