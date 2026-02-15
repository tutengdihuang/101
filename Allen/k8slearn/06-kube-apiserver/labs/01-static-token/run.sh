#!/usr/bin/env bash
set -euo pipefail

API_SERVER="${API_SERVER:-https://192.168.34.2:6443}"
TOKEN="${TOKEN:-cncamp-token}"

curl -sS "$API_SERVER/api/v1/namespaces/default" \
  -H "Authorization: Bearer $TOKEN" \
  -k | cat

