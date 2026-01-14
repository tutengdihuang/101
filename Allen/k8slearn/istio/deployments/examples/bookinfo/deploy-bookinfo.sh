#!/bin/bash

set -e

NAMESPACE="bookinfo"

echo "========================================="
echo "BookInfo 示例部署脚本 v1.0"
echo "========================================="
echo ""

echo "步骤 1/4: 创建命名空间并启用 Sidecar 自动注入..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace ${NAMESPACE} istio-injection=enabled --overwrite
echo "✓ 命名空间 ${NAMESPACE} 已创建并启用自动注入"

echo ""
echo "步骤 2/4: 部署 BookInfo 应用..."

echo "部署 productpage 服务..."
kubectl apply -f productpage.yaml -n ${NAMESPACE}

echo "部署 details 服务..."
kubectl apply -f details.yaml -n ${NAMESPACE}

echo "部署 reviews 服务（v1, v2, v3）..."
kubectl apply -f reviews.yaml -n ${NAMESPACE}

echo "部署 ratings 服务..."
kubectl apply -f ratings.yaml -n ${NAMESPACE}

echo "✓ BookInfo 应用已部署"

echo ""
echo "步骤 3/4: 等待 Pod 就绪..."
kubectl wait --for=condition=ready --timeout=300s pod -l app=productpage -n ${NAMESPACE}
kubectl wait --for=condition=ready --timeout=300s pod -l app=details -n ${NAMESPACE}
kubectl wait --for=condition=ready --timeout=300s pod -l app=reviews -n ${NAMESPACE}
kubectl wait --for=condition=ready --timeout=300s pod -l app=ratings -n ${NAMESPACE}
echo "✓ 所有 Pod 已就绪"

echo ""
echo "步骤 4/4: 验证部署..."

echo "检查 Pod 状态（应该有 2 个容器：应用 + istio-proxy）..."
kubectl get pods -n ${NAMESPACE}

echo ""
echo "检查 Service..."
kubectl get svc -n ${NAMESPACE}

echo ""
echo "========================================="
echo "BookInfo 部署完成！"
echo "========================================="
echo ""
echo "下一步操作:"
echo "1. 配置 Gateway 和 VirtualService 以访问应用:"
echo "   cd ../../gateways"
echo "   kubectl apply -f bookinfo-gateway.yaml"
echo ""
echo "   cd ../../virtualservices"
echo "   kubectl apply -f bookinfo-vs.yaml"
echo ""
echo "2. 获取访问地址:"
echo "   kubectl get svc istio-ingressgateway -n istio-system"
echo ""
echo "3. 卸载 BookInfo:"
echo "   ./deploy-bookinfo.sh uninstall"
