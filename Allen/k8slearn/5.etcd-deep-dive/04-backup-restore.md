# etcd 备份恢复 - 数据安全的最后防线

> 没有备份的数据，等于没有数据

## 为什么要备份？

即使 etcd 集群是高可用的，也可能遇到：
- 误操作删除数据
- 软件 bug 导致数据损坏
- 整个集群故障（机房断电、网络分区）
- 需要迁移到新集群

**备份是最后的保险**。

---

## 备份方式

### 方式一：Snapshot 备份（推荐）

```bash
# 创建快照
etcdctl snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db

# 查看快照信息
etcdctl snapshot status /backup/etcd-*.db -w table
```

**实验输出**：
```
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 3c3e8a7f |      100 |         50 |      25 kB |
+----------+----------+------------+------------+
```

### 方式二：带 TLS 的备份

生产环境通常启用 TLS：

```bash
etcdctl --endpoints https://127.0.0.1:2379 \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  snapshot save /backup/etcd-snapshot.db
```

---

## 实验：完整的备份恢复流程

### 步骤 1：准备测试数据

```bash
# 写入测试数据
etcdctl put /app/config/db_host "192.168.1.100"
etcdctl put /app/config/db_port "3306"
etcdctl put /app/config/db_user "admin"
etcdctl put /app/users/user1 "Alice"
etcdctl put /app/users/user2 "Bob"

# 验证数据
etcdctl get --prefix /app/
```

**实验输出**：
```
/app/config/db_host
192.168.1.100
/app/config/db_port
3306
/app/config/db_user
admin
/app/users/user1
Alice
/app/users/user2
Bob
```

### 步骤 2：创建备份

```bash
# 创建备份目录
mkdir -p /tmp/etcd-backup

# 创建快照
etcdctl snapshot save /tmp/etcd-backup/snapshot.db

# 验证快照
etcdctl snapshot status /tmp/etcd-backup/snapshot.db -w table
```

### 步骤 3：模拟灾难

```bash
# 删除所有数据
etcdctl del --prefix /app/

# 验证数据已删除
etcdctl get --prefix /app/
# （空）
```

### 步骤 4：恢复数据

```bash
# 停止 etcd（如果是服务）
# systemctl stop etcd

# 删除旧数据目录
rm -rf /tmp/etcd/default.etcd

# 从快照恢复
etcdctl snapshot restore /tmp/etcd-backup/snapshot.db \
  --data-dir=/tmp/etcd/restored

# 使用恢复的数据目录启动 etcd
etcd --data-dir=/tmp/etcd/restored &

# 验证数据
etcdctl get --prefix /app/
```

**实验输出**：
```
/app/config/db_host
192.168.1.100
/app/config/db_port
3306
/app/config/db_user
admin
/app/users/user1
Alice
/app/users/user2
Bob
```

数据恢复成功！

---

## 集群恢复

对于多节点集群，恢复稍微复杂一些。

### 步骤 1：在所有节点上恢复

```bash
# 节点 1
etcdctl snapshot restore /tmp/etcd-backup/snapshot.db \
  --name infra0 \
  --data-dir=/tmp/etcd/infra0 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://127.0.0.1:2380

# 节点 2
etcdctl snapshot restore /tmp/etcd-backup/snapshot.db \
  --name infra1 \
  --data-dir=/tmp/etcd/infra1 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://127.0.0.1:2381

# 节点 3
etcdctl snapshot restore /tmp/etcd-backup/snapshot.db \
  --name infra2 \
  --data-dir=/tmp/etcd/infra2 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://127.0.0.1:2382
```

### 步骤 2：启动所有节点

```bash
# 启动节点 1
etcd --name infra0 \
  --data-dir=/tmp/etcd/infra0 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --listen-client-urls http://127.0.0.1:2379 \
  --advertise-client-urls http://127.0.0.1:2379 &

# 启动节点 2
etcd --name infra1 \
  --data-dir=/tmp/etcd/infra1 \
  --listen-peer-urls http://127.0.0.1:2381 \
  --listen-client-urls http://127.0.0.1:2479 \
  --advertise-client-urls http://127.0.0.1:2479 &

# 启动节点 3
etcd --name infra2 \
  --data-dir=/tmp/etcd/infra2 \
  --listen-peer-urls http://127.0.0.1:2382 \
  --listen-client-urls http://127.0.0.1:2579 \
  --advertise-client-urls http://127.0.0.1:2579 &
```

### 步骤 3：验证集群

```bash
etcdctl --endpoints=http://127.0.0.1:2379 member list -w table
etcdctl --endpoints=http://127.0.0.1:2379 get --prefix /app/
```

---

## K8s 集群中的 etcd 备份

### 备份 K8s etcd

```bash
# 获取 etcd Pod 名称
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

# 在 etcd Pod 中执行备份
kubectl exec -n kube-system $ETCD_POD -- sh -c \
  "ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/snapshot.db"

# 复制到本地
kubectl cp kube-system/$ETCD_POD:/var/lib/etcd/snapshot.db ./etcd-backup.db
```

### 定时备份脚本

```bash
#!/bin/bash
# etcd-backup.sh

BACKUP_DIR="/backup/etcd"
BACKUP_FILE="$BACKUP_DIR/etcd-$(date +%Y%m%d-%H%M%S).db"
RETENTION_DAYS=7

# 创建备份目录
mkdir -p $BACKUP_DIR

# 执行备份
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save $BACKUP_FILE

# 验证备份
etcdctl snapshot status $BACKUP_FILE

# 删除旧备份
find $BACKUP_DIR -name "etcd-*.db" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_FILE"
```

添加到 crontab：

```bash
# 每天凌晨 2 点备份
0 2 * * * /usr/local/bin/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1
```

---

## 备份最佳实践

1. **定期备份**：至少每天一次
2. **异地存储**：备份文件存储到不同的机器/云存储
3. **验证备份**：定期测试恢复流程
4. **保留多个版本**：保留最近 7 天的备份
5. **监控备份**：备份失败时告警

---

## 核心要点

1. **备份命令**：`etcdctl snapshot save`
2. **恢复命令**：`etcdctl snapshot restore`
3. **集群恢复**：每个节点都要恢复，使用相同的快照
4. **定期备份**：生产环境必须有定时备份

---

## 下一步

备份恢复掌握了，接下来学习 etcd 的日常运维：监控、告警、碎片整理。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[etcd 集群部署](03-cluster-setup.md)  
**下一篇**：[etcd 运维实践](05-operations.md)
