#!/bin/bash

# Set common variables
PKI_ROOT=/home/hong3nguyen/.config/ziti/environments/pki
DNS_NAME=ctrl.ziti.hong3nguyen.com
IP_ADDR=xxxx

rm -rf $PKI_ROOT/ca

# CA
ziti pki create ca $PKI_ROOT

ziti pki create server certs/web-identity \
  --pki-root $PKI_ROOT --ca-name ca \
  --dns $DNS_NAME --ip $IP_ADDR \
  --server-file web-identity

ziti pki create server certs/web-client-identity \
  --pki-root $PKI_ROOT --ca-name ca \
  --dns $DNS_NAME --ip $IP_ADDR \
  --server-file web-client-identity

ziti pki create server certs/ctrl-plane-identity \
  --pki-root $PKI_ROOT --ca-name ca \
  --dns $DNS_NAME --ip $IP_ADDR \
  --server-file ctrl-plane-identity

ziti pki create server certs/ctrl-plane-client-identity \
  --pki-root $PKI_ROOT --ca-name ca \
  --dns $DNS_NAME --ip $IP_ADDR \
  --server-file ctrl-plane-client-identity

ziti pki create server certs/edge-signer \
  --pki-root $PKI_ROOT --ca-name ca \
  --dns $DNS_NAME --ip $IP_ADDR \
  --server-file edge-signer

rm -r ~/Public/git/ZTrust-EdgeML/cloud-setting/policy/controller-certs/ca/*

cp -r $PKI_ROOT/ca ~/Public/git/ZTrust-EdgeML/cloud-setting/policy/controller-certs/

NAMESPACE="ziti-controller"
CERT_DIR="./ca"

# Format: <secret-name> <cert-name>
declare -A CERTS=(
  ["ziti-controller-minimal1-web-identity-secret"]="web-identity"
  ["ziti-controller-minimal1-web-client-identity-secret"]="web-client-identity"
  ["ziti-controller-minimal1-ctrl-plane-identity-secret"]="ctrl-plane-identity"
  ["ziti-controller-minimal1-ctrl-plane-client-identity-secret"]="ctrl-plane-client-identity"
  ["ziti-controller-minimal1-edge-signer-secret"]="edge-signer"
)

for SECRET in "${!CERTS[@]}"; do
  NAME="${CERTS[$SECRET]}"
  echo "Creating secret: $SECRET for $NAME..."

  kubectl create secret generic "$SECRET" \
    --from-file=tls.crt="$CERT_DIR/certs/${NAME}.chain.pem" \
    --from-file=tls.key="$CERT_DIR/keys/${NAME}.key" \
    --from-file=ca.crt="$CERT_DIR/certs/ca.cert" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
done

# for SECRET in "${!CERTS[@]}"; do
#   NAME="${CERTS[$SECRET]}"
#   echo "Creating secret: $SECRET for $NAME..."
#
#   # kubectl create secret tls "$SECRET" \
#   #   --namespace "$NAMESPACE" \
#   #   --cert="${CERT_DIR}/certs/${NAME}.cert" \
#   #   --key="${CERT_DIR}/keys/${NAME}.key" \
#   #   --dry-run=client -o yaml | kubectl apply -f -
#   #
#   kubectl create secret generic ziti-controller-minimal1-web-identity-secret \
#     --from-file=tls.crt=$CERT_PATH/certs/web-identity.chain.pem \
#     --from-file=tls.key=$CERT_PATH/keys/web-identity.key \
#     --from-file=ca.crt=$CERT_PATH/certs/ca.cert \
#     -n $NAMESPACE
#
# done

kubectl create configmap ziti-controller-minimal1-ctrl-plane-cas \
  --from-file=ctrl-plane-cas.crt=$CERT_DIR/certs/ca.cert \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment ziti-controller-minimal1 -n $NAMESPACE
