#!/bin/bash
# HTTPS Gateway 实验脚本

set -e

echo "=== 实验三：HTTPS Gateway ==="

# 1. 创建命名空间
echo "1. 创建命名空间..."
kubectl create ns securesvc 2>/dev/null || true
kubectl label ns securesvc istio-injection=enabled --overwrite

# 2. 部署应用
echo "2. 部署应用..."
kubectl apply -f httpserver.yaml -n securesvc

# 3. 创建 TLS 证书
echo "3. 创建 TLS 证书..."
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
  -subj '/O=cncamp Inc./CN=*.cncamp.io' \
  -keyout cncamp.io.key \
  -out cncamp.io.crt 2>/dev/null

# 删除旧的 Secret（如果存在）
kubectl delete secret cncamp-credential -n istio-system 2>/dev/null || true

# 创建新的 Secret
kubectl create -n istio-system secret tls cncamp-credential \
  --key=cncamp.io.key \
  --cert=cncamp.io.crt

# 4. 配置 HTTPS Gateway
echo "4. 配置 HTTPS Gateway..."
kubectl apply -f istio-specs.yaml -n securesvc

# 5. 等待 Pod 就绪
echo "5. 等待 Pod 就绪..."
kubectl wait --for=condition=ready pod -l app=httpserver -n securesvc --timeout=60s

# 6. 获取 Ingress IP
echo "6. 获取 Ingress 地址..."
INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$INGRESS_IP" ]; then
    INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
    echo "NodePort 模式: $INGRESS_IP:$INGRESS_PORT"
else
    INGRESS_PORT=443
    echo "LoadBalancer 模式: $INGRESS_IP"
fi

# 7. 测试 HTTPS 访问
echo ""
echo "=== 测试 HTTPS 访问 ==="
echo "执行: curl --resolve httpsserver.cncamp.io:$INGRESS_PORT:$INGRESS_IP https://httpsserver.cncamp.io:$INGRESS_PORT/healthz -v -k"
curl --resolve httpsserver.cncamp.io:$INGRESS_PORT:$INGRESS_IP \
  https://httpsserver.cncamp.io:$INGRESS_PORT/healthz -v -k 2>&1 | head -30

echo ""
echo "=== 实验完成 ==="
echo "清理命令:"
echo "  kubectl delete ns securesvc"
echo "  kubectl delete secret cncamp-credential -n istio-system"
echo "  rm cncamp.io.key cncamp.io.crt"
