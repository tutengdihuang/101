#!/bin/bash
# etcd Lease 租约实验脚本
# 使用方法: ./02-lease-demo.sh

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
step() { echo -e "\n${GREEN}=== $1 ===${NC}\n"; }

ENDPOINTS=${ETCD_ENDPOINTS:-"http://127.0.0.1:2379"}
ETCDCTL="etcdctl --endpoints=$ENDPOINTS"

main() {
    step "1. 创建 Lease (10秒)"
    LEASE_OUTPUT=$($ETCDCTL lease grant 10)
    echo "$LEASE_OUTPUT"
    
    # 提取 lease ID
    LEASE_ID=$(echo "$LEASE_OUTPUT" | grep -oE '[0-9a-f]{16}')
    info "Lease ID: $LEASE_ID"
    
    step "2. 使用 Lease 创建 key"
    $ETCDCTL put /service/web --lease=$LEASE_ID "192.168.1.100:8080"
    info "创建了带 Lease 的 key: /service/web"
    
    step "3. 查看 Lease 列表"
    $ETCDCTL lease list
    
    step "4. 查看 Lease 详情"
    $ETCDCTL lease timetolive $LEASE_ID
    
    step "5. 查看 key"
    $ETCDCTL get /service/web
    
    step "6. 等待 Lease 过期 (12秒)"
    info "等待中..."
    for i in {12..1}; do
        echo -ne "\r剩余 $i 秒..."
        sleep 1
    done
    echo ""
    
    step "7. 再次查看 key (应该已被删除)"
    RESULT=$($ETCDCTL get /service/web)
    if [ -z "$RESULT" ]; then
        info "key 已被自动删除 (Lease 过期)"
    else
        warn "key 仍然存在: $RESULT"
    fi
    
    step "8. 演示 Lease 续约"
    info "创建新的 Lease (5秒)"
    LEASE_OUTPUT=$($ETCDCTL lease grant 5)
    LEASE_ID=$(echo "$LEASE_OUTPUT" | grep -oE '[0-9a-f]{16}')
    
    $ETCDCTL put /heartbeat --lease=$LEASE_ID "alive"
    info "创建了 /heartbeat，Lease ID: $LEASE_ID"
    
    info "\n开始续约 (按 Ctrl+C 停止)..."
    info "续约期间，key 不会过期"
    
    # 后台续约
    $ETCDCTL lease keep-alive $LEASE_ID &
    KEEPALIVE_PID=$!
    
    sleep 10
    
    # 停止续约
    kill $KEEPALIVE_PID 2>/dev/null || true
    
    step "9. 停止续约后等待过期"
    info "停止续约，等待 6 秒..."
    sleep 6
    
    RESULT=$($ETCDCTL get /heartbeat)
    if [ -z "$RESULT" ]; then
        info "key 已被自动删除"
    else
        warn "key 仍然存在"
    fi
    
    step "10. 演示撤销 Lease"
    LEASE_OUTPUT=$($ETCDCTL lease grant 300)
    LEASE_ID=$(echo "$LEASE_OUTPUT" | grep -oE '[0-9a-f]{16}')
    
    $ETCDCTL put /temp/data --lease=$LEASE_ID "temporary"
    info "创建了 /temp/data，Lease 300秒"
    
    info "\n撤销 Lease..."
    $ETCDCTL lease revoke $LEASE_ID
    
    RESULT=$($ETCDCTL get /temp/data)
    if [ -z "$RESULT" ]; then
        info "key 已被删除 (Lease 被撤销)"
    fi
    
    info "\n实验完成！"
}

main "$@"
