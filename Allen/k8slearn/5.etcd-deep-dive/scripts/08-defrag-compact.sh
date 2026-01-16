#!/bin/bash
# etcd 压缩和碎片整理脚本
# 使用方法: ./08-defrag-compact.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
step() { echo -e "\n${GREEN}=== $1 ===${NC}\n"; }

ENDPOINTS=${ETCD_ENDPOINTS:-"http://127.0.0.1:2379"}
ETCDCTL="etcdctl --endpoints=$ENDPOINTS"

main() {
    step "1. 当前状态"
    $ETCDCTL endpoint status -w table
    
    step "2. 写入测试数据"
    info "写入 500 个 key..."
    for i in $(seq 1 500); do
        $ETCDCTL put /test/key$i "value-$i-$(date +%s)" > /dev/null
    done
    info "写入完成"
    
    step "3. 写入后的状态"
    $ETCDCTL endpoint status -w table
    
    step "4. 删除测试数据"
    $ETCDCTL del --prefix /test/
    info "删除完成"
    
    step "5. 删除后的状态 (注意 DB SIZE 没变)"
    $ETCDCTL endpoint status -w table
    
    step "6. 获取当前 revision"
    REV=$($ETCDCTL endpoint status -w json | grep -oE '"revision":[0-9]+' | head -1 | grep -oE '[0-9]+')
    info "当前 revision: $REV"
    
    step "7. 压缩历史版本"
    info "压缩到 revision $REV..."
    $ETCDCTL compact $REV
    info "压缩完成"
    
    step "8. 碎片整理"
    $ETCDCTL defrag
    info "碎片整理完成"
    
    step "9. 最终状态 (DB SIZE 应该减小了)"
    $ETCDCTL endpoint status -w table
    
    step "10. 检查告警"
    ALARMS=$($ETCDCTL alarm list)
    if [ -z "$ALARMS" ]; then
        info "无告警"
    else
        warn "存在告警:"
        echo "$ALARMS"
        info "清除告警..."
        $ETCDCTL alarm disarm
    fi
    
    info "\n实验完成！"
}

main "$@"
