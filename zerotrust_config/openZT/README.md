# application setting 

```bash

SERVICE=test-web
SERVER_ID=test-server
CLIENT_ID=test-client

# Create ID
ziti edge create identity $SERVER_ID -o ${SERVER_ID}.jwt
ziti edge create identity $CLIENT_ID -o ${CLIENT_ID}.jwt

# # Create intercept config
# ziti edge create config "test-intercept-config" intercept.v1 \
#   "{\"protocols\":[\"tcp\"],\"addresses\":[\"test.hong3nguyen.ziti\"], \"portRanges\":[{\"low\":8080, \"high\":8080}]}"
#
# # Create host config
# ziti edge create config "test-host-config" host.v1 \
#   "{\"protocol\":\"tcp\", \"address\":\"test.hong3nguyen\",\"port\":8080}"

# Create service
ziti edge create service "test-service" --role-attributes "test-service_roles"

# Create bind policy
ziti edge create service-policy "test-bind-policy" Bind \
  --service-roles "@test-service" --identity-roles "@test-server"

# Create dial policy
ziti edge create service-policy "test-dial-policy" Dial \
  --service-roles "@test-service" --identity-roles "@test-client"

ziti edge enroll  ${SERVER_ID}.jwt
ziti edge enroll  ${CLIENT_ID}.jwt

kubectl create secret generic ziti-server-identity --from-file=identity.json=test-server.json
kubectl create secret generic ziti-client-identity --from-file=identity.json=test-client.json

```


```yaml serverpod
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ziti-test-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ziti-test-server
  template:
    metadata:
      labels:
        app: ziti-test-server
    spec:
      containers:
      - name: app
        image: python:3.11
        command: ["python3", "-m", "http.server", "8080"]
        ports:
          - containerPort: 8080
      - name: ziti-sidecar
        image: openziti/ziti-edge-tunnel:latest
        args: ["run", "--identity", "/ziti/identity.json", "--bind", "test-web"]
        volumeMounts:
          - name: ziti-id
            mountPath: /ziti
      volumes:
        - name: ziti-id
          secret:
            secretName: ziti-server-identity

```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ziti-test-client
spec:
  containers:
  - name: ziti-sidecar
    image: openziti/ziti-edge-tunnel:latest
    args: ["run"]
    env:
      - name: ZITI_IDENTITY_BASENAME
        value: "identity.json"
    volumeMounts:
      - name: ziti-id
        mountPath: /ziti
  - name: client
    image: curlimages/curl:latest
    command:
      - sh
      - -c
      - |
        echo "Waiting for sidecar..." && sleep 10
        echo "Testing connection..." && curl -v http://test-web:8080
    volumeMounts:
      - name: ziti-id
        mountPath: /ziti
  volumes:
    - name: ziti-id
      secret:
        secretName: ziti-client-identity

```

- Error from sidecar authorization
  - Problem #1 — path mismatch:
The hosts plugin in CoreDNS reads a file inside the container, here /etc/coredns/NodeHosts.
But in Kubernetes, the ConfigMap is mounted as data inside the pod only if you create a volume and volumeMount.
If you didn’t mount NodeHosts into /etc/coredns/NodeHosts, CoreDNS doesn’t actually read the entries.
  - Problem #2 — sidecar DNSPolicy:



```bash

# client
ziti edge create identity sidecar-client \
  --jwt-output-file /tmp/sidecar-client.jwt --role-attributes testapi-clients

ziti edge enroll /tmp/sidecar-client.jwt

kubectl create secret generic "sidecar-client-identity" \
    --from-file=/tmp/sidecar-client.json

# server
ziti edge create identity sidecar-server \
  --jwt-output-file /tmp/sidecar-server.jwt \
  --role-attributes testapi-servers

ziti edge enroll /tmp/sidecar-server.jwt

kubectl create secret generic sidecar-server-identity \
  --from-file=/tmp/sidecar-server.json


ziti edge create service testapi.ziti
ziti edge create service-edge-router-policy testapi.ziti-routers --edge-router-roles '#all' --service-roles '@testapi.ziti'
ziti edge create service-policy testapi.ziti-bind Bind --identity-roles '#testapi-servers' --service-roles '@testapi.ziti'
ziti edge create service-policy testapi.ziti-dial Dial --identity-roles '#testapi-clients' --service-roles '@testapi.ziti'

```


```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ziti-tunnel-sidecar-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ziti-tunnel-sidecar-server
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: ziti-tunnel-sidecar-server
    spec:
      containers:
        - image: hashicorp/http-echo
          name: testapi
          args:
            - "-listen=:8080"
            - "-text=Ziti server is alive!"
        - image: openziti/ziti-tunnel
          name: ziti-tunnel
          args: ["tproxy"]
          env:
            - name: ZITI_IDENTITY_BASENAME
              value: sidecar-server # file in the mounted secret
          volumeMounts:
            - name: sidecar-server-identity
              mountPath: /netfoundry
              readOnly: true
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
      dnsPolicy: ClusterFirst
      dnsConfig:
        nameservers:
          - 10.43.0.10 # CoreDNS cluster service IP
          - 127.0.0.1
        searches:
          - cluster.local
      restartPolicy: Always
      volumes:
        - name: sidecar-server-identity
          secret:
            secretName: sidecar-server-identity

```

```yaml
# /tmp/sidecar-demo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ziti-tunnel-sidecar-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ziti-tunnel-sidecar-demo
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: ziti-tunnel-sidecar-demo
    spec:
      containers:
        #- image: curlimages/curl:latest #imega/jq #stedolan/jq
        - image: busybox:latest
          name: testclient
          command:
            - sh
            - -c
            - |
              while true; do
                set -x
                wget -q -O - --post-data="ziti=awesome" http://testapi.ziti/post
                echo
                set +x
                sleep 3
              done
        - image: openziti/ziti-tunnel
          name: ziti-tunnel
          args: ["tproxy"]
          env:
            - name: ZITI_IDENTITY_BASENAME
              value: sidecar-client # the filename in the volume is sidecar-client.json
          volumeMounts:
            - name: sidecar-client-identity
              mountPath: /netfoundry
              readOnly: true
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
      dnsPolicy: ClusterFirst
      dnsConfig:
        nameservers:
          - 127.0.0.1 # all containers in pod must try this nameserver first
          - 10.43.0.10 # change this to match the CoreDNS cluster service address you found in the first step
        searches:
          - cluster.local # you must supply all search domains when overriding cluster DNS
          - hong3nguyen.com
      restartPolicy: Always
      volumes:
        - name: sidecar-client-identity
          secret:
            secretName: sidecar-client-identity

```
