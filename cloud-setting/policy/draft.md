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

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
kubectl apply -f https://raw.githubusercontent.com/cert-manager/trust-manager/v0.7.0/deploy/crds/trust.cert-manager.io_bundles.yaml

helm install \
    --namespace ziti-controller ziti-controller-minimal1 \
    openziti/ziti-controller \
    --set cert-manager.enabled="true" --set trust-manager.enabled="true" \
        --set clientApi.advertisedHost="ziti-controller-minimal.example.com" \
        --set clientApi.advertisedPort="443"

## trust-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

kubectl get secret ziti-controller-minimal1-ctrl-plane-root-secret -n ziti-controller -o jsonpath='{.data.tls\.crt}' | base64 -d > ctrl-plane-cas.crt
kubectl create configmap ziti-controller-minimal1-ctrl-plane-cas --from-file=ctrl-plane-cas.crt=ctrl-plane-cas.crt -n ziti-controller
kubectl create configmap ziti-controller-minimal1-ctrl-plane-cas --from-file=ctrl-plane-cas.crt=root-secret-ca.crt -n ziti-controller

## login via ziti edge
kubectl port-forward -n ziti-controller pods/ziti-controller-minimal1-6ff58f69b7-88pvd 1280:1280

ziti edge login localhost:1280 \                                                                                                                                      ─╯
    --yes \
    --username admin \
    --password $(
        kubectl -n ziti-controller \
            get secrets ziti-controller-minimal1-admin-secret \
                -o go-template='{{index .data "admin-password" | base64decode }}'
        )


