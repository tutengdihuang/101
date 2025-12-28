#!/bin/bash
# Jenkins + Harbor 一键部署脚本
# 实际部署记录: 2025-12-26

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_IP="182.42.82.135"
WORKER1_IP="182.42.80.121"
WORKER2_IP="182.42.95.71"
SSH_PASS="Nihao321!"

echo "=========================================="
echo "=== Jenkins + Harbor CI/CD 部署脚本 ==="
echo "=========================================="

# 1. 创建命名空间
echo ""
echo "=== 步骤 1: 创建 devops 命名空间 ==="
kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f -

# 2. 在 Master 节点创建 Jenkins 数据目录
echo ""
echo "=== 步骤 2: 创建 Jenkins 数据目录 ==="
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${MASTER_IP} "mkdir -p /data/jenkins && chmod 777 /data/jenkins"

# 3. 部署 Jenkins RBAC
echo ""
echo "=== 步骤 3: 部署 Jenkins RBAC ==="
kubectl apply -f ${SCRIPT_DIR}/jenkins/jenkins-rbac.yaml

# 4. 部署 Jenkins PVC
echo ""
echo "=== 步骤 4: 部署 Jenkins PVC ==="
kubectl apply -f ${SCRIPT_DIR}/jenkins/jenkins-pvc.yaml

# 5. 部署 Jenkins StatefulSet
echo ""
echo "=== 步骤 5: 部署 Jenkins StatefulSet ==="
kubectl apply -f ${SCRIPT_DIR}/jenkins/jenkins-deployment.yaml

# 6. 部署 Jenkins Service
echo ""
echo "=== 步骤 6: 部署 Jenkins Service ==="
kubectl apply -f ${SCRIPT_DIR}/jenkins/jenkins-service.yaml

# 7. 等待 Jenkins 就绪
echo ""
echo "=== 步骤 7: 等待 Jenkins 就绪 ==="
kubectl wait --for=condition=ready pod -l app=jenkins -n devops --timeout=300s || {
    echo "Jenkins 启动中，请稍后检查..."
}

# 8. 检查 Helm 是否安装
echo ""
echo "=== 步骤 8: 检查 Helm ==="
if ! command -v helm &> /dev/null; then
    echo "安装 Helm..."
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${MASTER_IP} "
        wget https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz -O /tmp/helm.tar.gz
        tar -zxvf /tmp/helm.tar.gz -C /tmp
        mv /tmp/linux-amd64/helm /usr/local/bin/
    "
fi

# 9. 安装 Harbor
echo ""
echo "=== 步骤 9: 安装 Harbor ==="
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${MASTER_IP} "
    helm repo add harbor https://helm.goharbor.io || true
    helm repo update
"
# 复制 values 文件到 Master 节点
sshpass -p "${SSH_PASS}" scp -o StrictHostKeyChecking=no ${SCRIPT_DIR}/harbor/harbor-values.yaml root@${MASTER_IP}:/tmp/
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${MASTER_IP} "
    helm upgrade --install harbor harbor/harbor -n devops -f /tmp/harbor-values.yaml --timeout 10m
"

# 10. 在 Master 节点安装 Docker
echo ""
echo "=== 步骤 10: 在 Master 节点安装 Docker ==="
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${MASTER_IP} "
    apt-get update && apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
"

# 11. 配置 Docker 信任 Harbor
echo ""
echo "=== 步骤 11: 配置 Docker 信任 Harbor ==="
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${MASTER_IP} "
    mkdir -p /etc/docker
    echo '{\"insecure-registries\":[\"${MASTER_IP}:30002\"]}' > /etc/docker/daemon.json
    systemctl restart docker
"

# 12. 配置所有节点 containerd 信任 Harbor
echo ""
echo "=== 步骤 12: 配置 containerd 信任 Harbor ==="
for node in ${MASTER_IP} ${WORKER1_IP} ${WORKER2_IP}; do
    echo "配置节点: ${node}"
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no root@${node} "
        cat >> /etc/containerd/config.toml << 'EOF'
        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"${MASTER_IP}:30002\"]
          endpoint = [\"http://${MASTER_IP}:30002\"]
      [plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"${MASTER_IP}:30002\".tls]
        insecure_skip_verify = true
EOF
        systemctl restart containerd
    " || echo "节点 ${node} 配置失败，请手动配置"
done

# 13. 创建 Harbor 项目
echo ""
echo "=== 步骤 13: 创建 Harbor 项目 ==="
sleep 60  # 等待 Harbor 完全启动
curl -u admin:Harbor12345 -X POST "http://${MASTER_IP}:30002/api/v2.0/projects" \
    -H 'Content-Type: application/json' \
    -d '{"project_name": "service-test", "public": true}' || echo "项目可能已存在"

# 14. 显示状态
echo ""
echo "=========================================="
echo "=== 部署完成 ==="
echo "=========================================="
echo ""
kubectl get pods -n devops
echo ""
echo "Jenkins 访问地址: http://${MASTER_IP}:30080"
echo "Harbor 访问地址: http://${MASTER_IP}:30002"
echo ""
echo "获取 Jenkins 初始密码:"
echo "  kubectl exec -it jenkins-0 -n devops -- cat /var/jenkins_home/secrets/initialAdminPassword"
echo ""
echo "Harbor 默认账号: admin / Harbor12345"
echo ""
echo "=========================================="
