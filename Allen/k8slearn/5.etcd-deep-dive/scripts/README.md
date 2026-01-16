# etcd 实验脚本

## 脚本列表

| 脚本 | 说明 | 使用方法 |
|------|------|---------|
| 01-basic-ops.sh | 基础操作实验 | `./01-basic-ops.sh` |
| 02-lease-demo.sh | Lease 租约实验 | `./02-lease-demo.sh` |
| 03-watch-demo.sh | Watch 监听实验 | `./03-watch-demo.sh` |
| 04-cluster-start.sh | 集群管理 | `./04-cluster-start.sh start` |
| 05-backup.sh | 备份脚本 | `./05-backup.sh [backup_dir]` |
| 06-restore.sh | 恢复脚本 | `./06-restore.sh <snapshot>` |
| 07-k8s-etcd-ops.sh | K8s etcd 操作 | `./07-k8s-etcd-ops.sh status` |
| 08-defrag-compact.sh | 压缩碎片整理 | `./08-defrag-compact.sh` |

## 快速开始

### 1. 添加执行权限

```bash
chmod +x *.sh
```

### 2. 启动 etcd

```bash
# 方式一：Docker 单节点
cd ../docker
./single-node.sh start

# 方式二：Docker Compose 集群
cd ../docker
docker-compose up -d

# 方式三：本地集群
./04-cluster-start.sh start
```

### 3. 运行实验

```bash
# 基础操作
./01-basic-ops.sh

# Lease 实验
./02-lease-demo.sh

# Watch 实验
./03-watch-demo.sh
```

## 环境变量

可以通过环境变量配置 etcd 连接：

```bash
# 设置 endpoints
export ETCD_ENDPOINTS="http://127.0.0.1:2379"

# 运行脚本
./01-basic-ops.sh
```

## 集群管理

```bash
# 启动集群
./04-cluster-start.sh start

# 查看状态
./04-cluster-start.sh status

# 测试集群
./04-cluster-start.sh test

# 停止集群
./04-cluster-start.sh stop

# 清理数据
./04-cluster-start.sh clean
```

## 备份恢复

```bash
# 备份
./05-backup.sh /tmp/etcd-backup

# 恢复单节点
./06-restore.sh /tmp/etcd-backup/etcd-xxx.db

# 恢复集群
./06-restore.sh --cluster /tmp/etcd-backup/etcd-xxx.db
```

## K8s etcd 操作

需要在 K8s master 节点上运行：

```bash
# 查看状态
./07-k8s-etcd-ops.sh status

# 查看资源
./07-k8s-etcd-ops.sh list-pods
./07-k8s-etcd-ops.sh count

# 压缩碎片整理
./07-k8s-etcd-ops.sh compact
```

## 注意事项

1. 生产环境操作前请先备份
2. K8s etcd 操作需要 root 权限
3. 不要直接修改 K8s etcd 数据
