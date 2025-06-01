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

