#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-default}"

kubectl apply -f quota.yaml

kubectl create configmap cm-1 -n "$NS" --from-literal=k=v

set +e
kubectl create configmap cm-2 -n "$NS" --from-literal=k=v
rc=$?
set -e

if [ $rc -eq 0 ]; then
  echo "Unexpected: cm-2 created successfully. Quota may not be enforced." >&2
  exit 1
fi

echo "As expected: creating cm-2 failed due to ResourceQuota."

echo "Cleanup..."
kubectl delete configmap cm-1 -n "$NS" --ignore-not-found
kubectl delete -f quota.yaml

echo "Done."

