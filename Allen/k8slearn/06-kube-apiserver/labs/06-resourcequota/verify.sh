#!/bin/bash

set -e

REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"
NAMESPACE="default"

echo "=========================================="
echo "Lab 06 - ResourceQuota 验证"
echo "=========================================="

echo ""
echo "1. 检查现有 ResourceQuota"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get resourcequota -n ${NAMESPACE} || echo '没有找到 ResourceQuota'"

echo ""
echo "2. 检查现有 ConfigMap 数量"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get configmap -n ${NAMESPACE} | wc -l"

echo ""
echo "2.1 清理现有 ConfigMap (为测试做准备)"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete configmap --all -n ${NAMESPACE} --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete resourcequota --all -n ${NAMESPACE} --ignore-not-found=true && sleep 2"

echo ""
echo "2.2 检查清理后的 ConfigMap 数量"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get configmap -n ${NAMESPACE} | wc -l"

echo ""
echo "3. 创建测试 ResourceQuota"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/quota.yaml <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: object-counts
  namespace: ${NAMESPACE}
spec:
  hard:
    configmaps: \"2\"
    pods: \"2\"
    services: \"1\"
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/quota.yaml"

echo ""
echo "4. 查看 ResourceQuota 状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl describe resourcequota object-counts -n ${NAMESPACE}"

echo ""
echo "5. 创建第一个 ConfigMap (应该成功)"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl create configmap cm-test-1 -n ${NAMESPACE} --from-literal=key1=value1 --dry-run=client -o yaml | kubectl apply -f -"

echo ""
echo "6. 查看 ResourceQuota 使用情况"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get resourcequota object-counts -n ${NAMESPACE} -o yaml | grep -A 10 'used:'"

echo ""
echo "7. 创建第二个 ConfigMap (应该失败)"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "if KUBECONFIG=/etc/kubernetes/admin.conf kubectl create configmap cm-test-2 -n ${NAMESPACE} --from-literal=key2=value2 --dry-run=client -o yaml | kubectl apply -f - 2>&1; then echo '第二个 ConfigMap 创建成功 (未预期)'; else echo '第二个 ConfigMap 创建失败 (符合预期)'; fi"

echo ""
echo "8. 测试 Pod 配额限制"
echo "------------------------------------------"
echo "创建第一个 Pod (应该成功):"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/test-pod-1.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-1
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: nginx
    image: nginx:1.19
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/test-pod-1.yaml"

echo ""
echo "创建第二个 Pod (应该成功):"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/test-pod-2.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-2
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: nginx
    image: nginx:1.19
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/test-pod-2.yaml"

echo ""
echo "创建第三个 Pod (应该失败):"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "if KUBECONFIG=/etc/kubernetes/admin.conf kubectl run test-pod-3 -n ${NAMESPACE} --image=nginx:1.19 --restart=Never 2>&1; then echo '第三个 Pod 创建成功 (未预期)'; else echo '第三个 Pod 创建失败 (符合预期)'; fi"

echo ""
echo "9. 查看 ResourceQuota 最终状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl describe resourcequota object-counts -n ${NAMESPACE}"

echo ""
echo "10. 测试 CPU/Memory 配额"
echo "------------------------------------------"
echo "创建 CPU/Memory 配额:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/compute-quota.yaml <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: ${NAMESPACE}
spec:
  hard:
    requests.cpu: \"1\"
    requests.memory: 1Gi
    limits.cpu: \"2\"
    limits.memory: 2Gi
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/compute-quota.yaml"

echo ""
echo "查看 CPU/Memory 配额状态:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl describe resourcequota compute-resources -n ${NAMESPACE}"

echo ""
echo "11. 清理测试资源"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete configmap cm-test-1 -n ${NAMESPACE} --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete pod test-pod-1 test-pod-2 -n ${NAMESPACE} --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete resourcequota object-counts compute-resources -n ${NAMESPACE} --ignore-not-found=true && rm -f /tmp/quota.yaml /tmp/test-pod-1.yaml /tmp/test-pod-2.yaml /tmp/compute-quota.yaml && echo '清理完成'"

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
echo ""
echo "ResourceQuota 关键点："
echo "- 限制 namespace 内的资源数量"
echo "- 限制 CPU/Memory 等计算资源"
echo "- 属于准入控制插件，在对象创建时检查"
echo "- 可以结合 LimitRange 使用"
