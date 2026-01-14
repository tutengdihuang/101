#!/bin/bash

set -e

ISTIO_VERSION="1.20.0"
ISTIO_DIR="/tmp/istio-${ISTIO_VERSION}"
NAMESPACE="istio-system"

echo "========================================="
echo "Istio 安装脚本 v1.0"
echo "========================================="
echo ""

if [ "$1" == "uninstall" ]; then
    echo "卸载 Istio..."
    if command -v istioctl &> /dev/null; then
        istioctl uninstall --purge -y
    fi
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
    echo "Istio 卸载完成"
    exit 0
fi

echo "步骤 1/5: 下载 Istio ${ISTIO_VERSION}..."
if [ ! -d "${ISTIO_DIR}" ]; then
    echo "检查本地 Istio 安装包..."
    if [ -f "/tmp/istio-${ISTIO_VERSION}-linux-amd64.tar.gz" ]; then
        echo "使用本地安装包..."
        cd /tmp
        tar -xzf istio-${ISTIO_VERSION}-linux-amd64.tar.gz
        echo "✓ Istio 解压完成"
    else
        echo "从 GitHub 下载 Istio..."
        cd /tmp
        curl -L --retry 3 --retry-delay 5 --connect-timeout 30 -o istio-${ISTIO_VERSION}-linux-amd64.tar.gz https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz
        tar -xzf istio-${ISTIO_VERSION}-linux-amd64.tar.gz
        rm -f istio-${ISTIO_VERSION}-linux-amd64.tar.gz
        echo "✓ Istio 下载完成"
    fi
else
    echo "✓ Istio 已存在，跳过下载"
fi

echo ""
echo "步骤 2/5: 添加 istioctl 到 PATH..."
export PATH=$PATH:${ISTIO_DIR}/bin

if ! command -v istioctl &> /dev/null; then
    echo "✗ istioctl 未找到，请手动添加到 PATH"
    echo "export PATH=\$PATH:${ISTIO_DIR}/bin"
    exit 1
fi
echo "✓ istioctl 已就绪"

echo ""
echo "步骤 3/5: 选择安装 Profile..."
echo "可用的 Profile:"
istioctl profile list
echo ""
echo "使用 demo profile（适合学习和演示）"

echo ""
echo "步骤 4/5: 安装 Istio 到 Kubernetes..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

istioctl install --set profile=demo -y

echo ""
echo "等待 Istio 组件就绪..."
kubectl wait --for=condition=available --timeout=300s deployment/istiod -n ${NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/istio-ingressgateway -n ${NAMESPACE}
echo "✓ Istio 组件已就绪"

echo ""
echo "步骤 5/5: 验证安装..."

echo "检查 Pod 状态..."
kubectl get pods -n ${NAMESPACE}

echo ""
echo "检查 Istio 版本..."
istioctl version

echo ""
echo "检查 Istio 配置..."
istioctl analyze --all-namespaces

echo ""
echo "========================================="
echo "Istio 安装完成！"
echo "========================================="
echo ""
echo "下一步操作:"
echo "1. 启用命名空间的 Sidecar 自动注入:"
echo "   kubectl label namespace <namespace> istio-injection=enabled"
echo ""
echo "2. 部署 BookInfo 示例应用:"
echo "   cd ../examples/bookinfo"
echo "   ./deploy-bookinfo.sh"
echo ""
echo "3. 卸载 Istio:"
echo "   ./install.sh uninstall"
