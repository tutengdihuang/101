#!/bin/bash
# etcd 备份脚本
# 使用方法: ./05-backup.sh [backup_dir]

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 配置
BACKUP_DIR="${1:-/tmp/etcd-backup}"
ENDPOINTS=${ETCD_ENDPOINTS:-"http://127.0.0.1:2379"}
RETENTION_DAYS=7

# TLS 配置（如果需要）
# ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
# ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
# ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"

backup() {
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/etcd-$TIMESTAMP.db"
    
    info "开始备份..."
    info "Endpoints: $ENDPOINTS"
    info "备份文件: $BACKUP_FILE"
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 执行备份
    if [ -n "${ETCD_CACERT:-}" ]; then
        # TLS 模式
        etcdctl --endpoints="$ENDPOINTS" \
            --cacert="$ETCD_CACERT" \
            --cert="$ETCD_CERT" \
            --key="$ETCD_KEY" \
            snapshot save "$BACKUP_FILE"
    else
        # 非 TLS 模式
        etcdctl --endpoints="$ENDPOINTS" \
            snapshot save "$BACKUP_FILE"
    fi
    
    # 验证备份
    info "\n备份文件信息:"
    etcdctl snapshot status "$BACKUP_FILE" -w table
    
    # 显示文件大小
    ls -lh "$BACKUP_FILE"
    
    # 清理旧备份
    info "\n清理 $RETENTION_DAYS 天前的备份..."
    find "$BACKUP_DIR" -name "etcd-*.db" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # 显示现有备份
    info "\n现有备份文件:"
    ls -lht "$BACKUP_DIR"/etcd-*.db 2>/dev/null || info "无备份文件"
    
    info "\n备份完成: $BACKUP_FILE"
}

# K8s etcd 备份
backup_k8s() {
    info "备份 K8s etcd..."
    
    BACKUP_FILE="$BACKUP_DIR/k8s-etcd-$(date +%Y%m%d-%H%M%S).db"
    mkdir -p "$BACKUP_DIR"
    
    ETCDCTL_API=3 etcdctl \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        snapshot save "$BACKUP_FILE"
    
    info "备份完成: $BACKUP_FILE"
    etcdctl snapshot status "$BACKUP_FILE" -w table
}

usage() {
    echo "使用方法: $0 [选项] [backup_dir]"
    echo ""
    echo "选项:"
    echo "  (无)     - 备份普通 etcd"
    echo "  --k8s    - 备份 K8s etcd"
    echo ""
    echo "示例:"
    echo "  $0                      # 备份到 /tmp/etcd-backup"
    echo "  $0 /backup/etcd         # 备份到指定目录"
    echo "  $0 --k8s                # 备份 K8s etcd"
}

case "${1:-}" in
    --k8s)
        backup_k8s
        ;;
    --help|-h)
        usage
        ;;
    *)
        backup
        ;;
esac
