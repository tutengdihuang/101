#!/bin/bash

set -e

REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"
NAMESPACE="default"
TEST_USER="testuser"

echo "=========================================="
echo "Lab 03 - RBAC 授权验证"
echo "=========================================="

echo ""
echo "1. 检查现有 Role 和 ClusterRole"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get role,clusterrole -n ${NAMESPACE} | head -20"

echo ""
echo "2. 检查现有 RoleBinding 和 ClusterRoleBinding"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get rolebinding,clusterrolebinding -n ${NAMESPACE} | head -20"

echo ""
echo "3. 创建测试用户 Role"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/pod-reader-role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: ${NAMESPACE}
rules:
- apiGroups: [\"\"]
  resources: [\"pods\"]
  verbs: [\"get\", \"list\", \"watch\"]
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/pod-reader-role.yaml"

echo ""
echo "4. 创建 RoleBinding"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/rolebinding.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: ${NAMESPACE}
subjects:
- kind: User
  name: ${TEST_USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/rolebinding.yaml"

echo ""
echo "5. 验证用户权限 (使用 --as 参数)"
echo "------------------------------------------"
echo "测试用户 ${TEST_USER} 是否可以 list pods:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl auth can-i list pods --as=${TEST_USER} -n ${NAMESPACE}"

echo ""
echo "测试用户 ${TEST_USER} 是否可以 create pods:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl auth can-i create pods --as=${TEST_USER} -n ${NAMESPACE}"

echo ""
echo "测试用户 ${TEST_USER} 是否可以 delete pods:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl auth can-i delete pods --as=${TEST_USER} -n ${NAMESPACE}"

echo ""
echo "6. 测试不同权限场景"
echo "------------------------------------------"

echo "场景 1: 用户只有 get 权限"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/pod-get-only-role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-get-only
  namespace: ${NAMESPACE}
rules:
- apiGroups: [\"\"]
  resources: [\"pods\"]
  verbs: [\"get\"]
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/pod-get-only-role.yaml"

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/get-pods-binding.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: get-pods
  namespace: ${NAMESPACE}
subjects:
- kind: User
  name: ${TEST_USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-get-only
  apiGroup: rbac.authorization.k8s.io
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/get-pods-binding.yaml"

echo "用户 ${TEST_USER} 尝试 list pods (应该失败):"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n ${NAMESPACE} --as=${TEST_USER} 2>&1 || true"

echo ""
echo "7. 测试 ClusterRole 和 ClusterRoleBinding"
echo "------------------------------------------"
echo "创建 ClusterRole (跨 namespace 权限):"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/namespace-reader-clusterrole.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-reader
rules:
- apiGroups: [\"\"]
  resources: [\"namespaces\"]
  verbs: [\"get\", \"list\"]
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/namespace-reader-clusterrole.yaml"

echo "创建 ClusterRoleBinding:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat > /tmp/read-namespaces-binding.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-namespaces
subjects:
- kind: User
  name: ${TEST_USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-reader
  apiGroup: rbac.authorization.k8s.io
EOF
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f /tmp/read-namespaces-binding.yaml"

echo "测试用户 ${TEST_USER} 是否可以 list namespaces:"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl auth can-i list namespaces --as=${TEST_USER}"

echo ""
echo "8. 清理测试资源"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete role pod-reader pod-get-only -n ${NAMESPACE} --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete rolebinding read-pods get-pods -n ${NAMESPACE} --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete clusterrole namespace-reader --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete clusterrolebinding read-namespaces --ignore-not-found=true && rm -f /tmp/pod-reader-role.yaml /tmp/rolebinding.yaml /tmp/pod-get-only-role.yaml /tmp/get-pods-binding.yaml /tmp/namespace-reader-clusterrole.yaml /tmp/read-namespaces-binding.yaml && echo '清理完成'"

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
echo ""
echo "RBAC 关键点："
echo "- Role: 定义命名空间级别的权限"
echo "- ClusterRole: 定义集群级别的权限"
echo "- RoleBinding: 将 Role 绑定到用户/组/服务账户"
echo "- ClusterRoleBinding: 将 ClusterRole 绑定到用户/组/服务账户"
echo "- 使用 --as 参数可以模拟用户权限"
