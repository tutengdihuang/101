#!/usr/bin/env bash
set -euo pipefail

DEMO_DIR="${DEMO_DIR:-admission-controller-webhook-demo}"
NS="${NS:-webhook-demo}"

if [ ! -d "$DEMO_DIR" ]; then
  git clone https://github.com/cncamp/admission-controller-webhook-demo.git "$DEMO_DIR"
fi

cd "$DEMO_DIR"

./deploy.sh

echo "Waiting webhook-server ready..."
kubectl -n "$NS" rollout status deployment/webhook-server --timeout=180s

kubectl create -f examples/pod-with-defaults.yaml

echo "Pod containers:"
kubectl get pod pod-with-defaults -o jsonpath='{.spec.containers[*].name}' | cat

echo

echo "Done. You can run: kubectl get pod pod-with-defaults -o yaml"

