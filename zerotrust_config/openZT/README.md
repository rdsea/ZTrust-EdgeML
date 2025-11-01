# application setting 

- export ca to local
```bash
kubectl get secrets -n zt-ctrl

kubectl get secret ziti-controller-edge-root-secret -n zt-ctrl \
  -o jsonpath='{.data.tls\.crt}' | base64 --decode > controller-ca.pem


```
```bash
${SERVER_ID}.json | head -n 3 null
running OpenZiti Controller in Kubernetes via Helm with:
--set cert-manager.enabled=true
--set trust-manager.enabled=true

```

```bash

SERVICE=test-web
SERVER_ID=test-server
CLIENT_ID=test-client

# Create ID
ziti edge create identity $SERVER_ID -o ${SERVER_ID}.jwt
ziti edge create identity $CLIENT_ID -o ${CLIENT_ID}.jwt

ziti edge enroll ${SERVER_ID}.jwt --ca controller-ca.pem -o ${SERVER_ID}.json
ziti edge enroll ${CLIENT_ID}.jwt --ca controller-ca.pem -o ${CLIENT_ID}.json

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

kubectl create secret generic ziti-server-identity --from-file=identity.json=${SERVER_ID}.json
kubectl create secret generic ziti-client-identity --from-file=identity.json=${CLIENT_ID}.json

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


---

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


#ziti edge create service testapi.ziti --configs web-service-intercept-config,web-service-host-config
ziti edge create service testapi.ziti

# at local server
ziti edge create config testapi-host-config host.v1 '{"protocol":"tcp", "address":"127.0.0.1","port":8080}'

# client intercept
ziti edge create config testapi-intercept-config intercept.v1 '{"protocols":["tcp"],"addresses":["testapi.ziti"],"portRanges":[{"low":80, "high":80}]}'

ziti edge update service testapi.ziti --configs testapi-intercept-config,testapi-host-config

ziti edge create service web-api-service \
  --configs web-service-intercept-config,web-service-host-config
ziti edge create service-edge-router-policy testapi.ziti-routers --edge-router-roles '#all' --service-roles '@testapi.ziti'
ziti edge create service-policy testapi.ziti-bind Bind --identity-roles '#testapi-servers' --service-roles '@testapi.ziti'
ziti edge create service-policy testapi.ziti-dial Dial --identity-roles '#testapi-clients' --service-roles '@testapi.ziti'

# policy for routers
ziti edge create edge-router-policy sidecar-server-er-policy \
  --identity-roles '#testapi-servers' \
  --edge-router-roles '#all'

# Create edge router policy for client identity  
ziti edge create edge-router-policy sidecar-client-er-policy \
  --identity-roles '#testapi-clients' \
  --edge-router-roles '#all'

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
        - image: openziti/ziti-tunnel:1.5.7
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
        - image: openziti/ziti-tunnel:1.5.7
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


## Debug

> ziti edge list edge-routers --output-json | jq '.data[] | select(.name=="ziti-cloudrouter")'

```json
{
  "_links": {
    "edge-router-policies": {
      "href": "./edge-routers/cCvV5tKkY/edge-router-policies"
    },
    "self": {
      "href": "./edge-routers/cCvV5tKkY"
    }
  },
  "createdAt": "2025-10-30T13:47:58.088Z",
  "id": "cCvV5tKkY",
  "tags": {},
  "updatedAt": "2025-10-30T13:48:34.856Z",
  "appData": {},
  "cost": 0,
  "disabled": false,
  "hostname": "router.cloud.hong3nguyen.com",
  "isOnline": true,
  "name": "ziti-cloudrouter",
  "noTraversal": false,
  "supportedProtocols": {
    "tls": "tls://router.cloud.hong3nguyen.com:443"
  },
  "syncStatus": "SYNC_DONE",
  "certPem": "-----BEGIN CERTIFICATE-----\nMIIDzzCCA3WgAwIBAgIDBhTaMAoGCCqGSM49BAMCMCYxJDAiBgNVBAMTG3ppdGkt\nY29udHJvbGxlci1lZGdlLXNpZ25lcjAeFw0yNTEwMzAxMzQ3MzRaFw0yNjEwMzAx\nMzQ4MzRaMEsxCTAHBgNVBAYTADEJMAcGA1UECBMAMQkwBwYDVQQHEwAxCTAHBgNV\nBAoTADEJMAcGA1UECxMAMRIwEAYDVQQDEwljQ3ZWNXRLa1kwggIiMA0GCSqGSIb3\nDQEBAQUAA4ICDwAwggIKAoICAQCwwifU/aDPC0WZjaRqXwuxgEiWnKDVUKKOAEFO\nIuDNKi7PEX0NDtcFKJuSJw20E+fs9O/3wpAvFPQ+RoKFM7m70GOGfkn76MCjYOmR\nMmCfFomU96RbodGiEF523/kCOgY4y9SzSLC3pcyND0wLsdM49D0w44MJCq0WqD7S\nfVqEWT0/LeEuv74bxjGSwGWIAf/NyI/MIClqN9rG9lLYUElZboejzVYDrbaHUfk5\nm/XlPDKA6Y9eV8Ps44j+W6Uc2DKsg2p3PED+vAZI1AFgGKTGBETdI7G9ubbNO1hG\nIUHN3k0vKO7ApbpLFOACeVB2kfMklsEauASUhl8JvA/tc20B9l1y4kiCfq89twlO\nMLtWn1f6QiSmxx6YR+E1KHlYBMr7nSjWUGLywvfEchJiE0OUhVhtYydwZ53cYW8k\npXjR8/daI4RnuuoNu3/iJSy2jqHHjp0KXqYULbeTN4DkUICJGw7grrxa3FOPiUZ/\nveimqsgLpfvKxNOoDZL32d5fTVZJ08wll6cj4pVvaTKKer/By0pUDC3NPwH3nvY5\nfdP7XtYoKPVsRGwHuBp+t672ZUtc5TQhhK2E54J/sCkyCBUSNXd+RuJh4ouvziVz\ncUZdZAghYv0OL6np0fJP8rhVoCAMwfeouB/4ggr8EjaJ8WA6uxarVDfLkEQeZeS+\nX4WvnQIDAQABo4GhMIGeMA4GA1UdDwEB/wQEAwIEsDATBgNVHSUEDDAKBggrBgEF\nBQcDAjAfBgNVHSMEGDAWgBS6Agvvunk0N5WjqvpusrIpbPBVNjBWBgNVHREETzBN\ngglsb2NhbGhvc3SCHHJvdXRlci5jbG91ZC5ob25nM25ndXllbi5jb22CHHJvdXRl\nci5jbG91ZC5ob25nM25ndXllbi5jb22HBH8AAAEwCgYIKoZIzj0EAwIDSAAwRQIh\nAMdX4PmUSTjyYJM9EoVHk+lXzlto8fx2mZ49aWyuIUalAiBB9LqUwWrzyUmYxzPH\n5hPQsnbjDcivoEMwKnbD/ZYvBQ==\n-----END CERTIFICATE-----\n",
  "fingerprint": "c5bdca14032d18368f5282a905d7a57289fca586",
  "interfaces": [
    {
      "addresses": [
        "10.0.0.79/32",
        "fe80::c0de:50ff:fe23:e3cf/64"
      ],
      "hardwareAddress": "c2:de:50:23:e3:cf",
      "index": 26,
      "isBroadcast": true,
      "isLoopback": false,
      "isMulticast": true,
      "isRunning": true,
      "isUp": true,
      "mtu": 8950,
      "name": "eth0"
    },
    {
      "addresses": [
        "127.0.0.1/8",
        "::1/128"
      ],
      "hardwareAddress": "",
      "index": 1,
      "isBroadcast": false,
      "isLoopback": true,
      "isMulticast": false,
      "isRunning": true,
      "isUp": true,
      "mtu": 65536,
      "name": "lo"
    }
  ],
  "isTunnelerEnabled": true,
  "isVerified": true,
  "roleAttributes": null,
  "unverifiedCertPem": null,
  "unverifiedFingerprint": null,
  "versionInfo": {
    "arch": "amd64",
    "buildDate": "2025-07-25T17:21:06Z",
    "os": "linux",
    "revision": "207d28c6bdee",
    "version": "v1.6.6"
  }
}

```

- Error from traefikTCProute = true
```
What happens when traefikTcpRoute.enabled=true

Controller + Edge Routers are exposed via Traefik TCP routing.

Certificates for routers are auto-generated by trust-manager / Traefik, with CN/SAN like:
<random>.traefik.default

The sidecar connecting to router.cloud.hong3nguyen.com fails TLS because the hostname doesn’t match the cert.

Ziti Edge login works fine because the controller API itself has the correct advertised host certificate (ctrl.cloud.hong3nguyen.com) — the login endpoint is independent of the router certificates.

✅ Pros: CLI login works, controller reachable.
❌ Cons: Sidecars cannot connect to routers using your advertised hostname → TLS errors.
```

- Keep traefikTcpRoute.enabled=true.

Sidecars should connect via Ziti service names, not via router.cloud.hong3nguyen.com.

Ziti’s internal routing handles the rest; TLS hostname mismatch disappears because sidecars use the CN/SAN given by Traefik.

CLI login continues to work normally.

This is the standard Kubernetes approach.


- 
