#!/bin/bash
# Sidecar 流量劫持原理实验脚本

set -e

echo "=== 实验四：Sidecar 流量劫持原理 ==="

# 1. 创建命名空间
echo "1. 创建命名空间..."
kubectl create ns sidecar 2>/dev/null || true
kubectl label ns sidecar istio-injection=enabled --overwrite

# 2. 部署应用
echo "2. 部署应用..."
kubectl apply -f nginx.yaml -n sidecar
kubectl apply -f toolbox.yaml -n sidecar

# 3. 等待 Pod 就绪
echo "3. 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=nginx -n sidecar --timeout=60s
kubectl wait --for=condition=ready pod -l app=toolbox -n sidecar --timeout=60s

# 获取 Pod 名称
TOOLBOX=$(kubectl get pod -l app=toolbox -n sidecar -o jsonpath='{.items[0].metadata.name}')
NGINX=$(kubectl get pod -l app=nginx -n sidecar -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "=== Pod 信息 ==="
echo "Toolbox: $TOOLBOX"
echo "Nginx: $NGINX"

# 4. 查看 Envoy 配置
echo ""
echo "=== 查看 Cluster（上游服务）==="
istioctl pc cluster -n sidecar $TOOLBOX | head -20

echo ""
echo "=== 查看 Listener（监听器）==="
istioctl pc listener -n sidecar $TOOLBOX | head -20

echo ""
echo "=== 查看 Route（路由）==="
istioctl pc route -n sidecar $TOOLBOX | head -20

echo ""
echo "=== 查看 Endpoint（端点）==="
istioctl pc endpoint -n sidecar $TOOLBOX | grep nginx

# 5. 测试访问
echo ""
echo "=== 测试访问 nginx ==="
kubectl exec -it $TOOLBOX -n sidecar -c toolbox -- curl -s nginx

# 6. 查看 Sidecar 日志
echo ""
echo "=== Sidecar 访问日志 ==="
kubectl logs $TOOLBOX -n sidecar -c istio-proxy --tail=5

echo ""
echo "=== 实验完成 ==="
echo ""
echo "更多命令："
echo "  # 查看 15001 端口 listener（出站入口）"
echo "  istioctl pc listener -n sidecar $TOOLBOX --port 15001 -o json"
echo ""
echo "  # 查看 80 端口 route"
echo "  istioctl pc route -n sidecar $TOOLBOX --name=80"
echo ""
echo "  # 查看 Sidecar 日志"
echo "  kubectl logs -f $TOOLBOX -n sidecar -c istio-proxy"
echo ""
echo "清理命令: kubectl delete ns sidecar"
