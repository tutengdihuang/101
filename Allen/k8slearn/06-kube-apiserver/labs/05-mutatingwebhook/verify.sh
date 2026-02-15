#!/bin/bash

set -e

REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"
NAMESPACE="istio-system"

echo "=========================================="
echo "Lab 05 - Mutating Webhook 验证"
echo "=========================================="

echo ""
echo "1. 检查 MutatingWebhookConfiguration"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get mutatingwebhookconfigurations || echo '没有找到 MutatingWebhookConfiguration'"

echo ""
echo "2. 检查 webhook 服务"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get deployment,svc,pods -n ${NAMESPACE} 2>/dev/null || echo '命名空间 ${NAMESPACE} 不存在或没有资源'"

echo ""
echo "3. 检查 webhook 服务日志"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "if KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n ${NAMESPACE} -l app=webhook-server &>/dev/null; then echo 'Webhook 服务日志 (最近 10 行):'; KUBECONFIG=/etc/kubernetes/admin.conf kubectl logs -n ${NAMESPACE} -l app=webhook-server --tail=10; else echo 'Webhook 服务 Pod 未找到'; fi"

echo ""
echo "4. 创建测试 Pod"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/test-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: nginx
    image: nginx:1.19
    ports:
    - containerPort: 80
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/test-pod.yaml"

echo ""
echo "5. 等待 Pod 创建"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl wait --for=condition=Ready pod/test-pod -n ${NAMESPACE} --timeout=30s || true"

echo ""
echo "6. 检查 Pod 容器列表"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "echo 'Pod 容器名称:' && KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod test-pod -n ${NAMESPACE} -o jsonpath='{.spec.containers[*].name}' && echo ''"

echo ""
echo "Pod 详细信息:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod test-pod -n ${NAMESPACE} -o yaml | grep -A 10 'containers:'"

echo ""
echo "7. 检查是否注入了 sidecar"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "CONTAINER_COUNT=\$(KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pod test-pod -n ${NAMESPACE} -o jsonpath='{.spec.containers[*].name}' | wc -w) && echo '容器数量: \${CONTAINER_COUNT}' && if [ \${CONTAINER_COUNT} -gt 1 ]; then echo '✓ Webhook 成功注入了 sidecar 容器'; else echo '✗ Webhook 未注入 sidecar 容器'; fi"

echo ""
echo "8. 查看 webhook 服务器日志"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "echo 'Webhook 服务器最近的日志:' && KUBECONFIG=/etc/kubernetes/admin.conf kubectl logs -n ${NAMESPACE} -l app=webhook-server --tail=20"

echo ""
echo "9. 清理测试 Pod"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete pod test-pod -n ${NAMESPACE} --ignore-not-found=true && rm -f /tmp/test-pod.yaml"

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
echo ""
echo "注意："
echo "- 如果 webhook 服务未部署，需要先运行 deploy.sh"
echo "- 如果没有看到 sidecar 注入，检查 webhook 配置和日志"
echo "- 可以通过修改 webhook 代码来自定义注入逻辑"
