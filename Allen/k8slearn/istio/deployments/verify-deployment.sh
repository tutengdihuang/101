#!/bin/bash

set -e

NAMESPACE="bookinfo"
REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"

echo "=========================================="
echo "Istio BookInfo 部署验证脚本"
echo "=========================================="

echo ""
echo "1. 检查 Istio 控制平面状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n istio-system"

echo ""
echo "2. 检查 BookInfo 应用状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n ${NAMESPACE}"

echo ""
echo "3. 检查服务状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get svc -n ${NAMESPACE}"

echo ""
echo "4. 检查 Istio 配置"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get gateway,virtualservice,destinationrule -n ${NAMESPACE}"

echo ""
echo "5. 检查 Gateway 端口"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name==\"http2\")].nodePort}'"

echo ""
echo "6. 测试应用访问"
echo "------------------------------------------"
echo "访问地址: http://10.0.3.231:31868/productpage"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "curl -s http://10.0.3.231:31868/productpage | head -10"

echo ""
echo "7. 验证 Sidecar 注入"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n ${NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{\" - \"}{.spec.containers[*].name}{\"\\n\"}{end}'"

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
