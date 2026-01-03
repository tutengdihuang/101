#!/bin/bash
# Prometheus + Grafana 监控系统安装脚本

set -e

echo "=========================================="
echo "  Prometheus + Grafana 监控系统安装"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Helm 是否安装
check_helm() {
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}错误: Helm 未安装${NC}"
        echo "请先安装 Helm: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    echo -e "${GREEN}✓ Helm 已安装${NC}"
}

# 添加 Helm 仓库
add_repo() {
    echo ""
    echo ">>> 添加 Helm 仓库..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update
    echo -e "${GREEN}✓ Helm 仓库已添加${NC}"
}

# 创建命名空间
create_namespace() {
    echo ""
    echo ">>> 创建 monitoring 命名空间..."
    kubectl create namespace monitoring 2>/dev/null || echo "命名空间已存在"
    echo -e "${GREEN}✓ 命名空间已就绪${NC}"
}

# 安装 kube-prometheus-stack
install_prometheus() {
    echo ""
    echo ">>> 安装 kube-prometheus-stack..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VALUES_FILE="${SCRIPT_DIR}/values.yaml"
    
    if [ ! -f "$VALUES_FILE" ]; then
        echo -e "${RED}错误: values.yaml 文件不存在${NC}"
        exit 1
    fi
    
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        -n monitoring \
        -f "$VALUES_FILE" \
        --wait \
        --timeout 10m
    
    echo -e "${GREEN}✓ kube-prometheus-stack 安装完成${NC}"
}

# 等待 Pod 就绪
wait_for_pods() {
    echo ""
    echo ">>> 等待 Pod 就绪..."
    kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s
    echo -e "${GREEN}✓ 所有 Pod 已就绪${NC}"
}

# 显示访问信息
show_info() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}  安装完成！${NC}"
    echo "=========================================="
    echo ""
    echo "访问地址："
    echo "  Grafana:    http://<MASTER_IP>:30300"
    echo "  Prometheus: http://<MASTER_IP>:30909"
    echo ""
    echo "Grafana 登录信息："
    echo "  用户名: admin"
    echo "  密码:   admin123"
    echo ""
    echo "查看 Pod 状态："
    echo "  kubectl get pods -n monitoring"
    echo ""
}

# 主流程
main() {
    check_helm
    add_repo
    create_namespace
    install_prometheus
    wait_for_pods
    show_info
}

main "$@"
