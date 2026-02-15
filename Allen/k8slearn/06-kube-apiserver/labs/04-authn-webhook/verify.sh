#!/bin/bash

set -e

REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"
NAMESPACE="default"

echo "=========================================="
echo "Lab 04 - Token Webhook 认证验证"
echo "=========================================="

echo ""
echo "1. 检查 kube-apiserver 配置"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A 2 'authentication-token-webhook' || echo '未找到 authentication-token-webhook 配置'"

echo ""
echo "2. 检查 webhook 配置文件"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat /etc/config/webhook-config.json 2>/dev/null || echo 'webhook 配置文件不存在'"

echo ""
echo "3. 检查认证服务是否运行"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "ps aux | grep authn-webhook | grep -v grep || echo '认证服务未运行'"

echo ""
echo "4. 检查认证服务端口"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "netstat -tlnp | grep :3000 || echo '端口 3000 未监听'"

echo ""
echo "5. 测试 webhook 服务"
echo "------------------------------------------"
echo "测试 /authenticate 端点:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
curl -s http://localhost:3000/authenticate -X POST \
  -H 'Content-Type: application/json' \
  -d '{"apiVersion":"authentication.k8s.io/v1","kind":"TokenReview","spec":{"token":"test-token"}}' || echo "Webhook 服务无响应"
ENDSSH

echo ""
echo "6. 检查 kube-apiserver 日志中的认证信息"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
KUBECONFIG=/etc/kubernetes/admin.conf kubectl logs -n kube-system -l component=kube-apiserver --tail=20 | grep -i "webhook\|authentication" || echo "未找到相关日志"
ENDSSH

echo ""
echo "7. 检查 kubeconfig 中的用户配置"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat ~/.kube/config | grep -A 5 'name:.*webhook' || echo '未找到 webhook 用户配置'"

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
echo ""
echo "注意："
echo "- 如果 webhook 认证未启用，需要先运行 switch_apiserver_to_webhook.sh"
echo "- 如果认证服务未运行，需要先启动 authn-webhook 服务"
echo "- 验证步骤："
echo "  1. 启动认证服务"
echo "  2. 配置 webhook 文件"
echo "  3. 修改 kube-apiserver 配置"
echo "  4. 配置 kubeconfig 用户"
echo "  5. 使用 kubectl --user <username> 测试"
