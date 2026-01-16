#!/bin/bash
# 单节点 etcd Docker 启动脚本
# 使用方法: ./single-node.sh [start|stop|status|logs]

set -e

CONTAINER_NAME="etcd-demo"
IMAGE="registry.aliyuncs.com/google_containers/etcd:3.5.0-0"

start() {
    echo "启动单节点 etcd..."
    
    docker run -d \
        --name $CONTAINER_NAME \
        -p 2379:2379 \
        -p 2380:2380 \
        $IMAGE \
        /usr/local/bin/etcd \
        --advertise-client-urls http://0.0.0.0:2379 \
        --listen-client-urls http://0.0.0.0:2379
    
    echo "等待 etcd 启动..."
    sleep 3
    
    echo "验证连接..."
    docker exec $CONTAINER_NAME etcdctl endpoint health
    
    echo ""
    echo "etcd 已启动！"
    echo "连接方式:"
    echo "  docker exec -it $CONTAINER_NAME etcdctl <command>"
    echo "  etcdctl --endpoints=http://127.0.0.1:2379 <command>"
}

stop() {
    echo "停止 etcd..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    echo "已停止"
}

status() {
    if docker ps | grep -q $CONTAINER_NAME; then
        echo "etcd 正在运行"
        docker exec $CONTAINER_NAME etcdctl endpoint status -w table
    else
        echo "etcd 未运行"
    fi
}

logs() {
    docker logs -f $CONTAINER_NAME
}

case "${1:-start}" in
    start)
        stop 2>/dev/null || true
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "使用方法: $0 [start|stop|status|logs|restart]"
        ;;
esac
