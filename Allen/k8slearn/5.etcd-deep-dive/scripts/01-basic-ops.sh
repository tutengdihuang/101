#!/bin/bash
# etcd 基础操作实验脚本
# 使用方法: ./01-basic-ops.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印函数
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "\n${GREEN}=== $1 ===${NC}\n"; }

# 检查 etcdctl 是否可用
check_etcdctl() {
    if ! command -v etcdctl &> /dev/null; then
        error "etcdctl 未安装，请先安装 etcd"
        exit 1
    fi
    info "etcdctl 版本: $(etcdctl version | head -1)"
}

# 设置 endpoints（可以通过环境变量覆盖）
ENDPOINTS=${ETCD_ENDPOINTS:-"http://127.0.0.1:2379"}
ETCDCTL="etcdctl --endpoints=$ENDPOINTS"

# 主函数
main() {
    check_etcdctl
    
    step "1. 清理环境"
    $ETCDCTL del --prefix /demo/ || true
    info "清理完成"
    
    step "2. 写入数据 (put)"
    $ETCDCTL put /demo/name "张三"
    $ETCDCTL put /demo/age "25"
    $ETCDCTL put /demo/city "北京"
    $ETCDCTL put /demo/config/db_host "192.168.1.100"
    $ETCDCTL put /demo/config/db_port "3306"
    info "写入 5 个键值对"
    
    step "3. 读取数据 (get)"
    info "读取单个 key:"
    $ETCDCTL get /demo/name
    
    info "\n读取带前缀的所有 key:"
    $ETCDCTL get --prefix /demo/
    
    info "\n只显示 key:"
    $ETCDCTL get --prefix /demo/ --keys-only
    
    step "4. 查看元数据 (JSON 格式)"
    info "查看 /demo/name 的元数据:"
    $ETCDCTL get /demo/name -w=json | python3 -m json.tool 2>/dev/null || $ETCDCTL get /demo/name -w=json
    
    step "5. 版本历史"
    info "多次修改同一个 key:"
    $ETCDCTL put /demo/version "v1"
    $ETCDCTL put /demo/version "v2"
    $ETCDCTL put /demo/version "v3"
    
    info "\n当前值:"
    $ETCDCTL get /demo/version
    
    info "\n查看元数据 (注意 version 字段):"
    $ETCDCTL get /demo/version -w=json | python3 -m json.tool 2>/dev/null || $ETCDCTL get /demo/version -w=json
    
    step "6. 删除数据 (del)"
    info "删除单个 key:"
    $ETCDCTL del /demo/version
    
    info "\n删除带前缀的所有 key:"
    $ETCDCTL del --prefix /demo/config/
    
    info "\n剩余的 key:"
    $ETCDCTL get --prefix /demo/ --keys-only
    
    step "7. 成员列表"
    $ETCDCTL member list -w table
    
    step "8. 端点状态"
    $ETCDCTL endpoint status -w table
    $ETCDCTL endpoint health
    
    step "9. 清理实验数据"
    $ETCDCTL del --prefix /demo/
    info "实验完成！"
}

# 运行
main "$@"
