#!/bin/bash
# Argo Rollouts 安装脚本

set -e

echo "=== 1. 创建 namespace ==="
kubectl apply -f 01-namespace.yaml

echo "=== 2. 安装 Argo Rollouts ==="
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "=== 3. 等待 Pod 就绪 ==="
kubectl wait --for=condition=Ready pods --all -n argo-rollouts --timeout=120s

echo "=== 4. 验证安装 ==="
kubectl get pods -n argo-rollouts

echo "=== 5. 安装 kubectl 插件（可选）==="
echo "如需安装 kubectl-argo-rollouts 插件，请执行："
echo "  curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64"
echo "  chmod +x kubectl-argo-rollouts-linux-amd64"
echo "  mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts"

echo ""
echo "✅ Argo Rollouts 安装完成！"
