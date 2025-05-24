# issues

- Error [need cert-manager and trust-manager](https://openziti.discourse.group/t/openziti-in-kubernetes-cluster/1877/2)


No certmanager or trustmanager running at all when following the k8s quickstart guide

Now I luckily began with this doc: Install OpenZiti Controller in Kubernetes | OpenZiti
Here is what I do to install cert/trustmanager and controller:


helm install  --namespace ziti-controller ziti-controller-minimal1 openziti/ziti-controller  \
  --set clientApi.advertisedHost="ziti-controller-minimal.example.com" \
  --set clientApi.advertisedPort="443" \
  --set cert-manager.enabled="true" --set trust-manager.enabled="true"
