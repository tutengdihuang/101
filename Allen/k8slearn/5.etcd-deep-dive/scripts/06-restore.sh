#!/bin/bash
# etcd 恢复脚本
# 使用方法: ./06-restore.sh <snapshot_file> [data_dir]

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

SNAPSHOT_FILE="${1:-}"
DATA_DIR="${2:-/tmp/etcd-restored}"

if [ -z "$SNAPSHOT_FILE" ]; then
    echo "使用方法: $0 <snapshot_file> [data_dir]"
    echo ""
    echo "示例:"
    echo "  $0 /tmp/etcd-backup/etcd-20260115.db"
    echo "  $0 /tmp/etcd-backup/etcd-20260115.db /var/lib/etcd"
    exit 1
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
    error "快照文件不存在: $SNAPSHOT_FILE"
    exit 1
fi

restore_single() {
    info "恢复单节点 etcd..."
    info "快照文件: $SNAPSHOT_FILE"
    info "数据目录: $DATA_DIR"
    
    # 验证快照
    info "\n快照信息:"
    etcdctl snapshot status "$SNAPSHOT_FILE" -w table
    
    # 备份现有数据
    if [ -d "$DATA_DIR" ]; then
        BACKUP_DIR="${DATA_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "备份现有数据到: $BACKUP_DIR"
        mv "$DATA_DIR" "$BACKUP_DIR"
    fi
    
    # 恢复
    info "\n开始恢复..."
    etcdctl snapshot restore "$SNAPSHOT_FILE" \
        --data-dir="$DATA_DIR"
    
    info "\n恢复完成！"
    info "数据目录: $DATA_DIR"
    info ""
    info "启动 etcd:"
    info "  etcd --data-dir=$DATA_DIR"
}

restore_cluster() {
    info "恢复 3 节点集群..."
    
    CLUSTER_DIR="/tmp/etcd-cluster-restored"
    mkdir -p "$CLUSTER_DIR"
    
    INITIAL_CLUSTER="infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2481,infra2=http://127.0.0.1:2582"
    
    # 恢复每个节点
    for node in infra0 infra1 infra2; do
        case $node in
            infra0) PEER_URL="http://127.0.0.1:2380" ;;
            infra1) PEER_URL="http://127.0.0.1:2481" ;;
            infra2) PEER_URL="http://127.0.0.1:2582" ;;
        esac
        
        info "恢复 $node..."
        etcdctl snapshot restore "$SNAPSHOT_FILE" \
            --name "$node" \
            --data-dir="$CLUSTER_DIR/$node" \
            --initial-cluster "$INITIAL_CLUSTER" \
            --initial-cluster-token etcd-cluster-restored \
            --initial-advertise-peer-urls "$PEER_URL"
    done
    
    info "\n恢复完成！"
    info "数据目录: $CLUSTER_DIR"
    info ""
    info "启动集群请使用: ./04-cluster-start.sh start"
    info "（需要修改数据目录为 $CLUSTER_DIR）"
}

# K8s etcd 恢复
restore_k8s() {
    warn "恢复 K8s etcd 是危险操作！"
    warn "请确保已停止 kubelet 和 kube-apiserver"
    echo ""
    read -p "确认继续? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        info "取消恢复"
        exit 0
    fi
    
    K8S_DATA_DIR="/var/lib/etcd"
    
    # 备份现有数据
    if [ -d "$K8S_DATA_DIR" ]; then
        BACKUP_DIR="${K8S_DATA_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "备份现有数据到: $BACKUP_DIR"
        mv "$K8S_DATA_DIR" "$BACKUP_DIR"
    fi
    
    # 恢复
    info "恢复数据..."
    ETCDCTL_API=3 etcdctl snapshot restore "$SNAPSHOT_FILE" \
        --data-dir="$K8S_DATA_DIR" \
        --name=master \
        --initial-cluster=master=https://127.0.0.1:2380 \
        --initial-advertise-peer-urls=https://127.0.0.1:2380
    
    # 修复权限
    chown -R root:root "$K8S_DATA_DIR"
    
    info "\n恢复完成！"
    info "请启动 kubelet: systemctl start kubelet"
}

usage() {
    echo "使用方法: $0 [选项] <snapshot_file> [data_dir]"
    echo ""
    echo "选项:"
    echo "  (无)       - 恢复单节点"
    echo "  --cluster  - 恢复 3 节点集群"
    echo "  --k8s      - 恢复 K8s etcd"
    echo ""
    echo "示例:"
    echo "  $0 snapshot.db                    # 恢复单节点"
    echo "  $0 --cluster snapshot.db          # 恢复集群"
    echo "  $0 --k8s snapshot.db              # 恢复 K8s etcd"
}

case "${1:-}" in
    --cluster)
        SNAPSHOT_FILE="${2:-}"
        if [ -z "$SNAPSHOT_FILE" ]; then
            usage
            exit 1
        fi
        restore_cluster
        ;;
    --k8s)
        SNAPSHOT_FILE="${2:-}"
        if [ -z "$SNAPSHOT_FILE" ]; then
            usage
            exit 1
        fi
        restore_k8s
        ;;
    --help|-h)
        usage
        ;;
    *)
        restore_single
        ;;
esac
