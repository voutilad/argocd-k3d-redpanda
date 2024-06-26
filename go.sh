#!/bin/sh
set -e

K3D_CLUSTER="${K3D_CLUSTER:-argocd}"
DOMAIN="${DOMAIN:-customredpandadomain.local}"
AGENTS="${AGENTS:-3}"
SERVERS="${SERVERS:-1}"
MEM="${MEM:-4G}"
TOPIC="${TOPIC:-twitch_chat}"

### 0. Pre-requisites
for cmd in k3d helm kubectl; do
    if [ -z "$(which "${cmd}")" ]; then
        echo "!! Failed to find ${cmd} in path. Is it installed?"
        exit 1;
    else
        echo "> Using ${cmd} @ $(which ${cmd})"
    fi
done

### 1. We need a k3d cluster.
echo "> Looking for existing k3d cluster..."
if ! k3d cluster list "${K3D_CLUSTER}" 2>&1 > /dev/null; then
    echo ">> Creating a new ${SERVERS} node cluster..."
    k3d cluster create "${K3D_CLUSTER}" \
        --servers "${SERVERS}" --servers-memory "1.5G" \
	--agents "${AGENTS}" --agents-memory "${MEM}" \
        --registry-create rp-registry
else
    echo ">> Found! Making sure cluster is started..."
    k3d cluster start "${K3D_CLUSTER}" --wait 2>&1 > /dev/null
fi

### 2. Install ArgoCD
kubectl apply -f argocd-ns.yaml
kubectl apply -n argocd -f argocd.yaml

### 3. Pre-init the Redpanda namespace so we can make a secret
kubectl create ns redpanda

PASSPHRASE="$(./passphrase/generate.sh | tr -d '\n')"

echo ">> Creating Redpanda secret"

kubectl create secret generic redpanda-superuser -n redpanda \
    --from-file=superusers.txt=/dev/stdin << EOF
admin:${PASSPHRASE}:SCRAM-SHA-256
EOF