#!/bin/bash
# HTTP Gateway 实验脚本

set -e

echo "=== 实验一：HTTP Gateway ==="

# 1. 创建命名空间
echo "1. 创建命名空间并启用 Sidecar 注入..."
kubectl create ns simple 2>/dev/null || true
kubectl label ns simple istio-injection=enabled --overwrite

# 2. 部署应用
echo "2. 部署应用..."
kubectl apply -f simple.yaml -n simple

# 3. 配置 Istio
echo "3. 配置 Gateway 和 VirtualService..."
kubectl apply -f istio-specs.yaml -n simple

# 4. 等待 Pod 就绪
echo "4. 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=simple -n simple --timeout=60s

# 5. 获取 Ingress IP
echo "5. 获取 Ingress 地址..."
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$INGRESS_IP" ]; then
    INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
    echo "NodePort 模式: $INGRESS_IP:$INGRESS_PORT"
else
    INGRESS_PORT=80
    echo "LoadBalancer 模式: $INGRESS_IP"
fi

# 6. 测试访问
echo ""
echo "=== 测试访问 ==="
echo "执行: curl -H \"Host: simple.cncamp.io\" $INGRESS_IP:$INGRESS_PORT/hello"
curl -H "Host: simple.cncamp.io" $INGRESS_IP:$INGRESS_PORT/hello -v 2>&1 | head -20

echo ""
echo "=== 实验完成 ==="
echo "清理命令: kubectl delete ns simple"
