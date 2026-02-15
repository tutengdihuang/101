#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS_DIR="${SCRIPT_DIR}/labs"

echo "=========================================="
echo "Kubernetes API Server 实验验证"
echo "=========================================="
echo ""
echo "集群信息:"
echo "  Master: 182.42.82.135 (10.0.3.231)"
echo "  Worker 1: 182.42.80.121 (10.0.1.149)"
echo "  Worker 2: 182.42.95.71 (10.0.0.32)"
echo ""

read -p "是否验证所有实验？(y/n): " verify_all

if [ "$verify_all" = "y" ] || [ "$verify_all" = "Y" ]; then
    echo ""
    echo "开始验证所有实验..."
    echo ""
    
    echo "=========================================="
    echo "Lab 01 - Static Token 认证"
    echo "=========================================="
    chmod +x "${LABS_DIR}/01-static-token/verify.sh"
    "${LABS_DIR}/01-static-token/verify.sh"
    echo ""
    
    echo "=========================================="
    echo "Lab 02 - X509 客户端证书认证"
    echo "=========================================="
    chmod +x "${LABS_DIR}/02-x509-user/verify.sh"
    "${LABS_DIR}/02-x509-user/verify.sh"
    echo ""
    
    echo "=========================================="
    echo "Lab 03 - RBAC 授权"
    echo "=========================================="
    chmod +x "${LABS_DIR}/03-rbac/verify.sh"
    "${LABS_DIR}/03-rbac/verify.sh"
    echo ""
    
    echo "=========================================="
    echo "Lab 04 - Token Webhook 认证"
    echo "=========================================="
    chmod +x "${LABS_DIR}/04-authn-webhook/verify.sh"
    "${LABS_DIR}/04-authn-webhook/verify.sh"
    echo ""
    
    echo "=========================================="
    echo "Lab 05 - Mutating Webhook"
    echo "=========================================="
    chmod +x "${LABS_DIR}/05-mutatingwebhook/verify.sh"
    "${LABS_DIR}/05-mutatingwebhook/verify.sh"
    echo ""
    
    echo "=========================================="
    echo "Lab 06 - ResourceQuota"
    echo "=========================================="
    chmod +x "${LABS_DIR}/06-resourcequota/verify.sh"
    "${LABS_DIR}/06-resourcequota/verify.sh"
    echo ""
    
    echo "=========================================="
    echo "所有实验验证完成"
    echo "=========================================="
else
    echo ""
    echo "选择要验证的实验:"
    echo "  1) Lab 01 - Static Token 认证"
    echo "  2) Lab 02 - X509 客户端证书认证"
    echo "  3) Lab 03 - RBAC 授权"
    echo "  4) Lab 04 - Token Webhook 认证"
    echo "  5) Lab 05 - Mutating Webhook"
    echo "  6) Lab 06 - ResourceQuota"
    echo ""
    read -p "请输入实验编号 (1-6): " lab_num
    
    case $lab_num in
        1)
            echo ""
            echo "=========================================="
            echo "Lab 01 - Static Token 认证"
            echo "=========================================="
            chmod +x "${LABS_DIR}/01-static-token/verify.sh"
            "${LABS_DIR}/01-static-token/verify.sh"
            ;;
        2)
            echo ""
            echo "=========================================="
            echo "Lab 02 - X509 客户端证书认证"
            echo "=========================================="
            chmod +x "${LABS_DIR}/02-x509-user/verify.sh"
            "${LABS_DIR}/02-x509-user/verify.sh"
            ;;
        3)
            echo ""
            echo "=========================================="
            echo "Lab 03 - RBAC 授权"
            echo "=========================================="
            chmod +x "${LABS_DIR}/03-rbac/verify.sh"
            "${LABS_DIR}/03-rbac/verify.sh"
            ;;
        4)
            echo ""
            echo "=========================================="
            echo "Lab 04 - Token Webhook 认证"
            echo "=========================================="
            chmod +x "${LABS_DIR}/04-authn-webhook/verify.sh"
            "${LABS_DIR}/04-authn-webhook/verify.sh"
            ;;
        5)
            echo ""
            echo "=========================================="
            echo "Lab 05 - Mutating Webhook"
            echo "=========================================="
            chmod +x "${LABS_DIR}/05-mutatingwebhook/verify.sh"
            "${LABS_DIR}/05-mutatingwebhook/verify.sh"
            ;;
        6)
            echo ""
            echo "=========================================="
            echo "Lab 06 - ResourceQuota"
            echo "=========================================="
            chmod +x "${LABS_DIR}/06-resourcequota/verify.sh"
            "${LABS_DIR}/06-resourcequota/verify.sh"
            ;;
        *)
            echo "无效的选择"
            exit 1
            ;;
    esac
fi

echo ""
echo "=========================================="
echo "验证脚本使用说明"
echo "=========================================="
echo ""
echo "单独运行某个实验的验证:"
echo "  ./labs/01-static-token/verify.sh"
echo "  ./labs/02-x509-user/verify.sh"
echo "  ./labs/03-rbac/verify.sh"
echo "  ./labs/04-authn-webhook/verify.sh"
echo "  ./labs/05-mutatingwebhook/verify.sh"
echo "  ./labs/06-resourcequota/verify.sh"
echo ""
echo "注意事项:"
echo "- 验证脚本会连接到远程 Kubernetes 集群"
echo "- 某些实验需要先运行对应的 run.sh 或部署脚本"
echo "- 验证完成后会自动清理测试资源"
echo "- 如需保留测试资源，请修改验证脚本"
