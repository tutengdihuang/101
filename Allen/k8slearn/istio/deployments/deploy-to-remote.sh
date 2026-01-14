#!/bin/bash

set -e

MASTER_IP="182.42.82.135"
PASSWORD="1Qaz2Wsx"
LOCAL_DEPLOY_DIR="/tmp/istio-deployments"
REMOTE_DEPLOY_DIR="/root/istio-deployments"

echo "========================================="
echo "Istio 远程部署脚本 v1.0"
echo "========================================="
echo ""

echo "步骤 1/5: 准备本地部署文件..."
if [ ! -d "${LOCAL_DEPLOY_DIR}" ]; then
    mkdir -p ${LOCAL_DEPLOY_DIR}
fi

DEPLOYMENTS_BASE="/Volumes/mac_data/code/go_code/101/Allen/k8slearn/istio/deployments"

echo "复制部署文件到本地临时目录..."
cp -r ${DEPLOYMENTS_BASE}/* ${LOCAL_DEPLOY_DIR}/

echo "✓ 本地部署文件已准备"

echo ""
echo "步骤 2/5: 上传部署文件到远程服务器..."
sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no -T root@${MASTER_IP} "mkdir -p ${REMOTE_DEPLOY_DIR}"

sshpass -p "${PASSWORD}" scp -o StrictHostKeyChecking=no -r ${LOCAL_DEPLOY_DIR}/* root@${MASTER_IP}:${REMOTE_DEPLOY_DIR}/

echo "✓ 部署文件已上传到 ${MASTER_IP}:${REMOTE_DEPLOY_DIR}"

echo ""
echo "步骤 3/5: 在远程服务器上安装 Istio..."
sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no -T root@${MASTER_IP} "cd ${REMOTE_DEPLOY_DIR}/install && ./install.sh"

echo ""
echo "步骤 4/5: 在远程服务器上部署 BookInfo..."
sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no -T root@${MASTER_IP} "cd ${REMOTE_DEPLOY_DIR}/examples/bookinfo && ./deploy-bookinfo.sh"

echo ""
echo "步骤 5/5: 在远程服务器上配置流量管理..."
sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=no -T root@${MASTER_IP} "cd ${REMOTE_DEPLOY_DIR}/examples/bookinfo && ./configure-traffic.sh"

echo ""
echo "========================================="
echo "Istio 远程部署完成！"
echo "========================================="
echo ""
echo "远程服务器信息:"
echo "  - IP: ${MASTER_IP}"
echo "  - 部署目录: ${REMOTE_DEPLOY_DIR}"
echo ""
echo "验证部署:"
echo "  ssh root@${MASTER_IP}"
echo "  cd ${REMOTE_DEPLOY_DIR}"
echo ""
echo "查看 Istio 状态:"
echo "  kubectl get pods -n istio-system"
echo ""
echo "查看 BookInfo 状态:"
echo "  kubectl get pods -n bookinfo"
echo ""
echo "卸载 Istio:"
echo "  ssh root@${MASTER_IP}"
echo "  cd ${REMOTE_DEPLOY_DIR}/install"
echo "  ./install.sh uninstall"
