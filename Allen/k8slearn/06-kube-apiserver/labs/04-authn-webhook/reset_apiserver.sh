#!/usr/bin/env bash
set -euo pipefail

MANIFEST_DIR="${MANIFEST_DIR:-/etc/kubernetes/manifests}"
BACKUP_PATH="${BACKUP_PATH:-$HOME/kube-apiserver.yaml.bak}"

sudo cp "$BACKUP_PATH" "$MANIFEST_DIR/kube-apiserver.yaml"

echo "Restored kube-apiserver manifest from backup: $BACKUP_PATH"

