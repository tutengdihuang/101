#!/bin/bash

set -e

NAMESPACE="bookinfo"

echo "========================================="
echo "BookInfo 流量管理配置脚本 v1.0"
echo "========================================="
echo ""

echo "步骤 1/4: 配置 Gateway（入口网关）..."
kubectl apply -f ../../gateways/bookinfo-gateway.yaml -n ${NAMESPACE}
echo "✓ Gateway 已配置"

echo ""
echo "步骤 2/4: 配置 VirtualService（流量路由）..."
kubectl apply -f ../../virtualservices/bookinfo-vs.yaml -n ${NAMESPACE}
echo "✓ VirtualService 已配置"

echo ""
echo "步骤 3/4: 配置 DestinationRule（目的地策略）..."
kubectl apply -f ../../destinationrules/bookinfo-dr.yaml -n ${NAMESPACE}
echo "✓ DestinationRule 已配置"

echo ""
echo "步骤 4/4: 验证配置..."

echo "检查 Gateway..."
kubectl get gateway -n ${NAMESPACE}

echo ""
echo "检查 VirtualService..."
kubectl get virtualservice -n ${NAMESPACE}

echo ""
echo "检查 DestinationRule..."
kubectl get destinationrule -n ${NAMESPACE}

echo ""
echo "========================================="
echo "流量管理配置完成！"
echo "========================================="
echo ""
echo "获取访问地址:"
INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

if [ -z "$INGRESS_HOST" ] || [ "$INGRESS_HOST" == "<pending>" ]; then
    echo "使用 NodePort 访问:"
    kubectl get svc istio-ingressgateway -n istio-system
else
    echo "访问地址: http://${INGRESS_HOST}:${INGRESS_PORT}/productpage"
fi

echo ""
echo "下一步操作:"
echo "1. 测试流量路由:"
echo "   for i in \$(seq 1 10); do curl -s http://<INGRESS_HOST>/productpage | grep -o '<title>.*</title>'; done"
echo ""
echo "2. 配置灰度发布（将流量导向不同版本）:"
echo "   ./configure-canary.sh"
echo ""
echo "3. 卸载配置:"
echo "   ./configure-traffic.sh uninstall"
