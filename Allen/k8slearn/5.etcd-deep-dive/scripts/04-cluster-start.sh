#!/bin/bash
# etcd 集群启动脚本 (本地模拟 3 节点)
# 使用方法: ./04-cluster-start.sh [start|stop|status]

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 数据目录
DATA_DIR="/tmp/etcd-cluster"

# 节点配置
declare -A NODES
NODES[infra0]="2379:2380"
NODES[infra1]="2479:2481"
NODES[infra2]="2579:2582"

# 初始集群配置
INITIAL_CLUSTER="infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2481,infra2=http://127.0.0.1:2582"
CLUSTER_TOKEN="etcd-cluster-demo"

start_cluster() {
    info "创建数据目录..."
    mkdir -p $DATA_DIR/{infra0,infra1,infra2}
    
    info "启动 etcd 集群..."
    
    for node in infra0 infra1 infra2; do
        IFS=':' read -r client_port peer_port <<< "${NODES[$node]}"
        
        info "启动 $node (client: $client_port, peer: $peer_port)"
        
        nohup etcd --name $node \
            --data-dir=$DATA_DIR/$node \
            --listen-peer-urls http://127.0.0.1:$peer_port \
            --listen-client-urls http://127.0.0.1:$client_port \
            --advertise-client-urls http://127.0.0.1:$client_port \
            --initial-advertise-peer-urls http://127.0.0.1:$peer_port \
            --initial-cluster-token $CLUSTER_TOKEN \
            --initial-cluster $INITIAL_CLUSTER \
            --initial-cluster-state new \
            > /var/log/etcd-$node.log 2>&1 &
        
        echo $! > $DATA_DIR/$node.pid
        sleep 1
    done
    
    info "等待集群就绪..."
    sleep 3
    
    show_status
}

stop_cluster() {
    info "停止 etcd 集群..."
    
    for node in infra0 infra1 infra2; do
        if [ -f "$DATA_DIR/$node.pid" ]; then
            PID=$(cat $DATA_DIR/$node.pid)
            if kill -0 $PID 2>/dev/null; then
                info "停止 $node (PID: $PID)"
                kill $PID
            fi
            rm -f $DATA_DIR/$node.pid
        fi
    done
    
    # 确保所有 etcd 进程都停止
    pkill -f "etcd --name infra" 2>/dev/null || true
    
    info "集群已停止"
}

show_status() {
    info "集群状态:"
    
    ENDPOINTS="http://127.0.0.1:2379,http://127.0.0.1:2479,http://127.0.0.1:2579"
    
    echo ""
    etcdctl --endpoints=$ENDPOINTS member list -w table 2>/dev/null || error "无法连接到集群"
    echo ""
    etcdctl --endpoints=$ENDPOINTS endpoint status -w table 2>/dev/null || true
    echo ""
    etcdctl --endpoints=$ENDPOINTS endpoint health 2>/dev/null || true
}

clean_data() {
    warn "清理所有数据..."
    stop_cluster
    rm -rf $DATA_DIR
    rm -f /var/log/etcd-infra*.log
    info "清理完成"
}

test_cluster() {
    info "测试集群..."
    
    ENDPOINTS="http://127.0.0.1:2379"
    
    # 写入数据
    etcdctl --endpoints=$ENDPOINTS put /test/key "hello"
    
    # 从不同节点读取
    for port in 2379 2479 2579; do
        echo -n "从 127.0.0.1:$port 读取: "
        etcdctl --endpoints=http://127.0.0.1:$port get /test/key --print-value-only
    done
    
    # 清理
    etcdctl --endpoints=$ENDPOINTS del /test/key
    
    info "测试完成！数据在所有节点同步"
}

usage() {
    echo "使用方法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  start   - 启动 3 节点集群"
    echo "  stop    - 停止集群"
    echo "  status  - 查看集群状态"
    echo "  test    - 测试集群"
    echo "  clean   - 清理所有数据"
    echo "  restart - 重启集群"
}

case "${1:-}" in
    start)
        start_cluster
        ;;
    stop)
        stop_cluster
        ;;
    status)
        show_status
        ;;
    test)
        test_cluster
        ;;
    clean)
        clean_data
        ;;
    restart)
        stop_cluster
        sleep 2
        start_cluster
        ;;
    *)
        usage
        ;;
esac
