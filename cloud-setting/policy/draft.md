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

