#!/bin/bash
# etcd Watch 监听实验脚本
# 使用方法: ./03-watch-demo.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
step() { echo -e "\n${GREEN}=== $1 ===${NC}\n"; }

ENDPOINTS=${ETCD_ENDPOINTS:-"http://127.0.0.1:2379"}
ETCDCTL="etcdctl --endpoints=$ENDPOINTS"

main() {
    step "Watch 实验说明"
    echo "这个实验需要两个终端："
    echo ""
    echo -e "${BLUE}终端 1 (Watch):${NC}"
    echo "  $ETCDCTL watch --prefix /app/"
    echo ""
    echo -e "${BLUE}终端 2 (操作):${NC}"
    echo "  $ETCDCTL put /app/config 'v1'"
    echo "  $ETCDCTL put /app/config 'v2'"
    echo "  $ETCDCTL del /app/config"
    echo ""
    
    read -p "按 Enter 开始自动演示，或按 Ctrl+C 手动操作..."
    
    step "1. 启动 Watch (后台)"
    info "启动 Watch 监听 /app/ 前缀..."
    
    # 后台启动 watch，输出到临时文件
    WATCH_OUTPUT=$(mktemp)
    $ETCDCTL watch --prefix /app/ > "$WATCH_OUTPUT" 2>&1 &
    WATCH_PID=$!
    
    sleep 1
    
    step "2. 执行写入操作"
    info "PUT /app/config = v1"
    $ETCDCTL put /app/config "v1"
    sleep 0.5
    
    info "PUT /app/config = v2"
    $ETCDCTL put /app/config "v2"
    sleep 0.5
    
    info "PUT /app/status = running"
    $ETCDCTL put /app/status "running"
    sleep 0.5
    
    info "DEL /app/config"
    $ETCDCTL del /app/config
    sleep 0.5
    
    step "3. 停止 Watch"
    kill $WATCH_PID 2>/dev/null || true
    sleep 1
    
    step "4. Watch 收到的事件"
    cat "$WATCH_OUTPUT"
    rm -f "$WATCH_OUTPUT"
    
    step "5. 从历史版本开始 Watch"
    info "先写入一些数据..."
    $ETCDCTL put /log/1 "event1"
    $ETCDCTL put /log/2 "event2"
    $ETCDCTL put /log/3 "event3"
    
    # 获取当前 revision
    CURRENT_REV=$($ETCDCTL get /log/1 -w=json | grep -oE '"revision":[0-9]+' | head -1 | grep -oE '[0-9]+')
    START_REV=$((CURRENT_REV - 2))
    
    info "当前 revision: $CURRENT_REV"
    info "从 revision $START_REV 开始 watch..."
    
    WATCH_OUTPUT=$(mktemp)
    timeout 2 $ETCDCTL watch --prefix /log/ --rev=$START_REV > "$WATCH_OUTPUT" 2>&1 || true
    
    info "\n收到的历史事件:"
    cat "$WATCH_OUTPUT"
    rm -f "$WATCH_OUTPUT"
    
    step "6. 清理"
    $ETCDCTL del --prefix /app/
    $ETCDCTL del --prefix /log/
    
    info "\n实验完成！"
    info "Watch 是 K8s Controller 的核心机制"
}

main "$@"
