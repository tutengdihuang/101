#!/usr/bin/env bash
set -euo pipefail

MANIFEST_DIR="${MANIFEST_DIR:-/etc/kubernetes/manifests}"
BACKUP_PATH="${BACKUP_PATH:-$HOME/kube-apiserver.yaml.bak}"
SRC_MANIFEST="${SRC_MANIFEST:-/Volumes/mac_data/code/go_code/101/module6/authn-webhook/specs/kube-apiserver.yaml}"

# NOTE: This script needs to run on the control-plane node with sufficient permissions.

sudo cp "$MANIFEST_DIR/kube-apiserver.yaml" "$BACKUP_PATH"
sudo cp "$SRC_MANIFEST" "$MANIFEST_DIR/kube-apiserver.yaml"

echo "Switched kube-apiserver manifest to webhook auth version. Backup: $BACKUP_PATH"

