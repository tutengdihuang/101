#!/bin/bash
# Harbor 安装脚本

set -e

echo "=== Harbor 安装脚本 ==="

# 添加 Harbor Helm 仓库
echo "1. 添加 Harbor Helm 仓库..."
helm repo add harbor https://helm.goharbor.io
helm repo update

# 创建命名空间（如果不存在）
echo "2. 创建 devops 命名空间..."
kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f -

# 安装 Harbor
echo "3. 安装 Harbor..."
helm upgrade --install harbor harbor/harbor \
  -n devops \
  -f harbor-values.yaml \
  --wait \
  --timeout 10m

# 等待 Harbor 就绪
echo "4. 等待 Harbor 就绪..."
kubectl wait --for=condition=ready pod -l app=harbor -n devops --timeout=300s || true

# 显示状态
echo ""
echo "=== Harbor 安装完成 ==="
echo ""
kubectl get pods -n devops -l app=harbor
echo ""
echo "访问地址: http://182.42.82.135:30002"
echo "用户名: admin"
echo "密码: Harbor12345"
echo ""
echo "=== 配置 Docker 信任 Harbor ==="
echo "在所有 K8s 节点上执行:"
echo "  echo '{\"insecure-registries\":[\"182.42.82.135:30002\"]}' | sudo tee /etc/docker/daemon.json"
echo "  sudo systemctl restart docker"
