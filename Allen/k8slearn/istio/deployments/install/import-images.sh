#!/bin/bash

set -e

ISTIO_VERSION="1.20.0"
IMAGE_FILE="/tmp/istio-images-docker.tar.gz"

echo "========================================="
echo "Istio 镜像导入脚本 v1.0"
echo "========================================="
echo ""

if [ ! -f "${IMAGE_FILE}" ]; then
    echo "错误: 镜像文件 ${IMAGE_FILE} 不存在"
    echo "请先从 master 节点复制镜像文件到本节点"
    exit 1
fi

echo "步骤 1/2: 导入 Istio 镜像..."
gunzip -c ${IMAGE_FILE} | ctr -n k8s.io images import -
echo "✓ 镜像导入完成"

echo ""
echo "步骤 2/2: 验证镜像..."
echo "可用的 Istio 镜像:"
ctr -n k8s.io images ls | grep istio

echo ""
echo "========================================="
echo "镜像导入完成！"
echo "========================================="
