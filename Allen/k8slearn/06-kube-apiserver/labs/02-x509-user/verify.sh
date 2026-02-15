#!/bin/bash

set -e

REMOTE_USER="root"
REMOTE_HOST="182.42.82.135"
REMOTE_PASSWORD="1Qaz2Wsx"
NAMESPACE="default"
USERNAME="testuser"

echo "=========================================="
echo "Lab 02 - X509 客户端证书认证验证"
echo "=========================================="

echo ""
echo "1. 检查现有 CSR"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get csr || echo '没有找到 CSR'"

echo ""
echo "2. 生成用户私钥"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cd /tmp && rm -f ${USERNAME}.key && openssl genrsa -out ${USERNAME}.key 2048 && echo '私钥生成成功'"

echo ""
echo "3. 生成 CSR 请求"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cd /tmp && openssl req -new -key ${USERNAME}.key -out ${USERNAME}.csr -subj '/CN=${USERNAME}/O=developers' && echo 'CSR 生成成功'"

echo ""
echo "4. 创建 Kubernetes CSR 对象"
echo "------------------------------------------"
CSR_BASE64=$(sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cat /tmp/${USERNAME}.csr | base64 | tr -d '\n'")

sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << ENDSSH
cat <<EOF | KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
ENDSSH

echo ""
echo "5. 检查 CSR 状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get csr ${USERNAME}"

echo ""
echo "6. 审批 CSR"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl certificate approve ${USERNAME}"

echo ""
echo "7. 检查 CSR 审批状态"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl get csr ${USERNAME} -o yaml"

echo ""
echo "8. 导出证书"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
cd /tmp
KUBECONFIG=/etc/kubernetes/admin.conf kubectl get csr ${USERNAME} -o jsonpath='{.status.certificate}' | base64 -d > ${USERNAME}.crt
echo "证书导出成功"
ls -la ${USERNAME}.crt
ENDSSH

echo ""
echo "9. 创建 RBAC Role"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl create role developer --verb=create --verb=get --verb=list --verb=update --verb=delete --resource=pods -n ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"

echo ""
echo "10. 创建 RoleBinding"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl create rolebinding developer-binding-${USERNAME} --role=developer --user=${USERNAME} -n ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"

echo ""
echo "11. 验证用户权限"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "cd /tmp && KUBECONFIG=/etc/kubernetes/admin.conf kubectl config set-credentials ${USERNAME} --client-key=${USERNAME}.key --client-certificate=${USERNAME}.crt --embed-certs=true && echo '使用 ${USERNAME} 用户列出 pods:' && KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -n ${NAMESPACE} --user ${USERNAME} || echo '权限验证失败'"

echo ""
echo "12. 清理测试资源"
echo "------------------------------------------"
sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete csr ${USERNAME} --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete rolebinding developer-binding-${USERNAME} -n ${NAMESPACE} --ignore-not-found=true && KUBECONFIG=/etc/kubernetes/admin.conf kubectl delete role developer -n ${NAMESPACE} --ignore-not-found=true && rm -f /tmp/${USERNAME}.key /tmp/${USERNAME}.csr /tmp/${USERNAME}.crt && echo '清理完成'"

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
