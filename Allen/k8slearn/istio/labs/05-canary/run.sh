#!/bin/bash
# 金丝雀发布实验脚本

set -e

echo "=== 实验五：金丝雀发布 ==="

# 1. 创建命名空间
echo "1. 创建命名空间..."
kubectl create ns canary 2>/dev/null || true
kubectl label ns canary istio-injection=enabled --overwrite

# 2. 部署 v1 版本
echo "2. 部署 v1 版本..."
kubectl apply -f canary-v1.yaml -n canary
kubectl apply -f toolbox.yaml -n canary

# 3. 等待 Pod 就绪
echo "3. 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=canary -n canary --timeout=60s
kubectl wait --for=condition=ready pod -l app=toolbox -n canary --timeout=60s

# 4. 测试 v1
echo ""
echo "=== 测试 v1 版本 ==="
TOOLBOX=$(kubectl get pod -l app=toolbox -n canary -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello

# 5. 部署 v2 版本
echo ""
echo "4. 部署 v2 版本（金丝雀）..."
kubectl apply -f canary-v2.yaml -n canary
kubectl wait --for=condition=ready pod -l version=v2 -n canary --timeout=60s

# 6. 配置路由规则
echo "5. 配置金丝雀路由规则..."
kubectl apply -f istio-specs.yaml -n canary

sleep 3

# 7. 测试金丝雀
echo ""
echo "=== 测试金丝雀发布 ==="
echo "普通请求 → v1:"
kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello

echo ""
echo "带 Header 请求 → v2:"
kubectl exec -it $TOOLBOX -n canary -- curl -s canary/hello -H "user: jesse"

echo ""
echo "=== 实验完成 ==="
echo "清理命令: kubectl delete ns canary"
