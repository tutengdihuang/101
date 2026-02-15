#!/bin/bash

set -e

REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"
NAMESPACE="default"

echo "=========================================="
echo "Lab 01 - Static Token 认证验证"
echo "=========================================="

echo ""
echo "1. 检查 kube-apiserver 静态 Pod 状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n kube-system -l component=kube-apiserver"

echo ""
echo "2. 检查 kube-apiserver 配置"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A 1 'token-auth-file' || echo '未找到 token-auth-file 配置'"

echo ""
echo "3. 检查静态 token 文件是否存在"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "ls -la /etc/kubernetes/auth/static-token 2>/dev/null || echo '静态 token 文件不存在'"

echo ""
echo "4. 检查静态 token 文件内容"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat /etc/kubernetes/auth/static-token 2>/dev/null || echo '无法读取 token 文件'"

echo ""
echo "5. 测试使用静态 token 访问 API"
echo "------------------------------------------"
TOKEN=$(sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "head -1 /etc/kubernetes/auth/static-token 2>/dev/null | cut -d',' -f1 || echo 'cncamp-token'")

echo "使用 Token: ${TOKEN:0:20}..."
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
TOKEN=$(head -1 /etc/kubernetes/auth/static-token 2>/dev/null | cut -d',' -f1)
if [ -n "$TOKEN" ]; then
    echo "使用静态 token 访问 /api/v1/namespaces/default:"
    curl -sS "https://10.0.3.231:6443/api/v1/namespaces/default" \
      -H "Authorization: Bearer $TOKEN" \
      -k | head -20
else
    echo "未找到有效的 token"
fi
ENDSSH

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
