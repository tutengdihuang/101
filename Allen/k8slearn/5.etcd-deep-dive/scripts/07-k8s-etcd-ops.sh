#!/bin/bash
# K8s etcd 操作脚本
# 使用方法: ./07-k8s-etcd-ops.sh [命令]

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
step() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# K8s etcd 配置
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"

# etcdctl 命令
ECTL="etcdctl --endpoints=$ETCD_ENDPOINTS --cacert=$ETCD_CACERT --cert=$ETCD_CERT --key=$ETCD_KEY"

check_access() {
    if [ ! -f "$ETCD_CACERT" ]; then
        error "无法访问 etcd 证书，请在 K8s master 节点上运行"
        error "或者进入 etcd Pod: kubectl exec -it etcd-<node> -n kube-system -- sh"
        exit 1
    fi
}

# 查看成员列表
member_list() {
    step "etcd 成员列表"
    $ECTL member list -w table
}

# 查看端点状态
endpoint_status() {
    step "端点状态"
    $ECTL endpoint status -w table
    echo ""
    $ECTL endpoint health
}

# 查看所有 key
list_keys() {
    step "K8s 数据结构 (前 50 个 key)"
    $ECTL get --prefix --keys-only / | head -50
    echo "..."
    info "使用 '$0 list-all' 查看所有 key"
}

# 查看所有 key（完整）
list_all_keys() {
    step "所有 K8s key"
    $ECTL get --prefix --keys-only /
}

# 查看特定资源
get_resource() {
    RESOURCE_TYPE="${1:-pods}"
    NAMESPACE="${2:-default}"
    
    step "查看 $NAMESPACE 命名空间的 $RESOURCE_TYPE"
    $ECTL get --prefix --keys-only /registry/$RESOURCE_TYPE/$NAMESPACE/
}

# 查看 Pod 列表
list_pods() {
    step "所有 Pod (etcd 视角)"
    $ECTL get --prefix --keys-only /registry/pods/
}

# 查看 Service 列表
list_services() {
    step "所有 Service (etcd 视角)"
    $ECTL get --prefix --keys-only /registry/services/
}

# 查看 ConfigMap 列表
list_configmaps() {
    step "所有 ConfigMap (etcd 视角)"
    $ECTL get --prefix --keys-only /registry/configmaps/
}

# 查看 Secret 列表
list_secrets() {
    step "所有 Secret (etcd 视角)"
    $ECTL get --prefix --keys-only /registry/secrets/
}

# 查看命名空间
list_namespaces() {
    step "所有命名空间 (etcd 视角)"
    $ECTL get --prefix --keys-only /registry/namespaces/
}

# 统计资源数量
count_resources() {
    step "资源统计"
    
    echo "Pods:        $($ECTL get --prefix --keys-only /registry/pods/ | wc -l)"
    echo "Services:    $($ECTL get --prefix --keys-only /registry/services/ | wc -l)"
    echo "ConfigMaps:  $($ECTL get --prefix --keys-only /registry/configmaps/ | wc -l)"
    echo "Secrets:     $($ECTL get --prefix --keys-only /registry/secrets/ | wc -l)"
    echo "Deployments: $($ECTL get --prefix --keys-only /registry/deployments/ | wc -l)"
    echo "Namespaces:  $($ECTL get --prefix --keys-only /registry/namespaces/ | wc -l)"
}

# 数据库大小
db_size() {
    step "数据库大小"
    $ECTL endpoint status -w table
}

# 压缩和碎片整理
compact_defrag() {
    step "压缩和碎片整理"
    
    # 获取当前 revision
    REV=$($ECTL endpoint status -w json | grep -oE '"revision":[0-9]+' | head -1 | grep -oE '[0-9]+')
    info "当前 revision: $REV"
    
    info "压缩到 revision $REV..."
    $ECTL compact $REV
    
    info "碎片整理..."
    $ECTL defrag
    
    info "完成！"
    $ECTL endpoint status -w table
}

# 查看告警
alarm_list() {
    step "告警列表"
    ALARMS=$($ECTL alarm list)
    if [ -z "$ALARMS" ]; then
        info "无告警"
    else
        echo "$ALARMS"
    fi
}

# 清除告警
alarm_disarm() {
    step "清除告警"
    $ECTL alarm disarm
    info "告警已清除"
}

usage() {
    echo "K8s etcd 操作脚本"
    echo ""
    echo "使用方法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  member-list      - 查看成员列表"
    echo "  status           - 查看端点状态"
    echo "  list-keys        - 查看 key 列表 (前 50 个)"
    echo "  list-all         - 查看所有 key"
    echo "  list-pods        - 查看所有 Pod"
    echo "  list-services    - 查看所有 Service"
    echo "  list-configmaps  - 查看所有 ConfigMap"
    echo "  list-secrets     - 查看所有 Secret"
    echo "  list-namespaces  - 查看所有命名空间"
    echo "  count            - 统计资源数量"
    echo "  db-size          - 查看数据库大小"
    echo "  compact          - 压缩和碎片整理"
    echo "  alarm-list       - 查看告警"
    echo "  alarm-disarm     - 清除告警"
    echo ""
    echo "示例:"
    echo "  $0 status"
    echo "  $0 list-pods"
    echo "  $0 count"
}

# 主函数
main() {
    check_access
    
    case "${1:-}" in
        member-list)
            member_list
            ;;
        status)
            endpoint_status
            ;;
        list-keys)
            list_keys
            ;;
        list-all)
            list_all_keys
            ;;
        list-pods)
            list_pods
            ;;
        list-services)
            list_services
            ;;
        list-configmaps)
            list_configmaps
            ;;
        list-secrets)
            list_secrets
            ;;
        list-namespaces)
            list_namespaces
            ;;
        count)
            count_resources
            ;;
        db-size)
            db_size
            ;;
        compact)
            compact_defrag
            ;;
        alarm-list)
            alarm_list
            ;;
        alarm-disarm)
            alarm_disarm
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
