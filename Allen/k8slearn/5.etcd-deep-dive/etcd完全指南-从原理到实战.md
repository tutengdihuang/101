# etcd 完全指南：从原理到实战

> 一篇文章带你彻底搞懂 etcd，Kubernetes 的"记忆中枢"

## 前言

如果把 Kubernetes 比作一个人：
- API Server 是嘴巴（接收指令）
- Controller Manager 是手脚（执行动作）
- Scheduler 是大脑的决策区（调度决策）
- **etcd 是记忆中枢**（存储所有状态）

etcd 挂了，整个集群就"失忆"了。所以理解 etcd 对于运维 K8s 至关重要。

本文将从原理到实战，带你彻底搞懂 etcd。文章很长，建议收藏后慢慢看。

---

## 目录

1. [什么是 etcd？为什么 K8s 选择它？](#一什么是-etcd为什么-k8s-选择它)
2. [etcd 核心原理](#二etcd-核心原理)
3. [基础操作实战](#三基础操作实战)
4. [数据模型深度解析](#四数据模型深度解析)
5. [高可用集群部署](#五高可用集群部署)
6. [备份恢复实战](#六备份恢复实战)
7. [运维最佳实践](#七运维最佳实践)
8. [K8s 中的 etcd 操作](#八k8s-中的-etcd-操作)

---

## 一、什么是 etcd？为什么 K8s 选择它？

### 1.1 etcd 是什么？

用最简单的话说：**etcd 就是一个分布式的 key-value 数据库**。

就像 Redis，但有几个关键区别：

| 特性 | etcd | Redis |
|------|------|-------|
| 一致性 | 强一致性（Raft） | 最终一致性 |
| 用途 | 配置存储、服务发现 | 缓存、消息队列 |
| 性能 | 写入较慢，读取快 | 读写都很快 |
| 数据安全 | 数据不丢失 | 可能丢失 |

**为什么 K8s 选择 etcd？** 因为 K8s 需要的是"绝对可靠"，而不是"极致性能"。

想象一下：如果 K8s 存储的 Pod 信息丢失了，整个集群就乱套了。所以 K8s 宁可慢一点，也要保证数据不丢。

### 1.2 etcd 的核心特性

| 特性 | 说明 | 生活比喻 |
|------|------|---------|
| **强一致性** | 所有节点数据一致 | 银行账本，每个分行数据必须一致 |
| **高可用** | 多节点部署，容忍故障 | 多个备份硬盘 |
| **Watch 机制** | 监听数据变化 | 订阅通知 |
| **事务支持** | 原子操作 | 要么全成功，要么全失败 |
| **版本控制** | 保留历史版本 | Git 版本管理 |

### 1.3 etcd 在 K8s 中的角色

```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes 集群                         │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ API Server  │───▶│    etcd     │◀───│ API Server  │     │
│  └─────────────┘    │  (3 节点)   │    └─────────────┘     │
│         │           └─────────────┘           │             │
│         ▼                                     ▼             │
│  ┌─────────────┐                      ┌─────────────┐       │
│  │ Controller  │                      │  Scheduler  │       │
│  │  Manager    │                      │             │       │
│  └─────────────┘                      └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

etcd 存储了 K8s 的所有数据：
- Pod、Deployment、Service 等对象定义
- ConfigMap、Secret 配置
- 节点信息、命名空间
- RBAC 权限配置
- ...

**一句话总结**：etcd 是 K8s 的"数据库"，所有状态都存在这里。

---

## 二、etcd 核心原理

### 2.1 Raft 共识算法

etcd 使用 Raft 算法保证数据一致性。Raft 的核心思想是：**选一个 Leader，所有写操作都经过 Leader**。


**Raft 的三种角色**：

| 角色 | 说明 | 数量 |
|------|------|------|
| **Leader** | 领导者，处理所有写请求 | 1 个 |
| **Follower** | 跟随者，复制 Leader 的数据 | 多个 |
| **Candidate** | 候选人，选举时的临时状态 | 临时 |

**写操作流程**：

```
1. 客户端发送写请求到 Leader
2. Leader 将数据写入本地日志
3. Leader 将日志复制到所有 Follower
4. 超过半数节点确认后，Leader 提交数据
5. Leader 返回成功给客户端
```

**为什么需要"超过半数"？**

假设有 3 个节点，需要 2 个节点确认：
- 1 个节点挂了，还有 2 个，可以继续工作
- 2 个节点挂了，只剩 1 个，无法达到半数，停止服务

这就是为什么 etcd 集群通常是 **3 个或 5 个节点**：
- 3 节点：容忍 1 个故障
- 5 节点：容忍 2 个故障
- 7 节点：容忍 3 个故障（但性能下降）

### 2.2 MVCC：多版本并发控制

etcd 使用 MVCC（Multi-Version Concurrency Control）来管理数据。

**什么是 MVCC？**

想象一个 Git 仓库：
- 每次 commit 都有一个版本号
- 你可以查看任意历史版本
- 新的修改不会覆盖旧版本

etcd 也是这样：
- 每次写操作都会增加全局 **revision**
- 旧版本数据不会立即删除
- 可以查询任意历史版本

**关键概念**：

| 概念 | 说明 |
|------|------|
| **revision** | 全局递增的版本号，每次写操作都会增加 |
| **create_revision** | key 创建时的 revision |
| **mod_revision** | key 最后修改时的 revision |
| **version** | key 被修改的次数 |

### 2.3 Lease：租约机制

Lease 是 etcd 的"定时炸弹"——给 key 设置一个生存时间，到期自动删除。

**为什么需要 Lease？**

场景：服务注册与发现
- 服务启动时，向 etcd 注册自己
- 如果服务挂了，注册信息应该自动删除
- 否则其他服务会访问一个"死"服务

Lease 就是解决这个问题的：
- 服务注册时，创建一个 Lease
- 服务定期续约（keep-alive）
- 服务挂了，无法续约，Lease 过期，key 自动删除

### 2.4 Watch：监听机制

Watch 是 etcd 的杀手锏，K8s 的 Controller 就是靠它实现的。

**Watch 的工作原理**：

```
1. 客户端向 etcd 发起 Watch 请求
2. etcd 记录这个 Watch
3. 当数据变化时，etcd 主动推送给客户端
4. 客户端收到通知，执行相应操作
```

**K8s 如何使用 Watch？**

```
Controller 启动
    ↓
Watch /registry/pods/
    ↓
收到 Pod 创建事件
    ↓
调度 Pod 到节点
    ↓
更新 Pod 状态
    ↓
继续 Watch...
```

这就是 K8s "声明式" API 的秘密：你声明想要的状态，Controller 通过 Watch 监听变化，自动把实际状态调整到期望状态。

---

## 三、基础操作实战

### 3.1 安装 etcd

**方式一：Docker（推荐学习使用）**

```bash
# 启动 etcd 容器
docker run -d --name etcd-demo \
  -p 2379:2379 \
  -p 2380:2380 \
  registry.aliyuncs.com/google_containers/etcd:3.5.0-0 \
  /usr/local/bin/etcd \
  --advertise-client-urls http://0.0.0.0:2379 \
  --listen-client-urls http://0.0.0.0:2379

# 验证
docker exec etcd-demo etcdctl version
```

**实验输出**：
```
$ docker exec etcd-demo etcdctl version
etcdctl version: 3.5.0
API version: 3.5
```

**方式二：本地启动（避免端口冲突）**

如果本地已有 K8s 集群，etcd 可能占用了默认端口：

```bash
etcd --listen-client-urls 'http://localhost:12379' \
     --advertise-client-urls 'http://localhost:12379' \
     --listen-peer-urls 'http://localhost:12380' \
     --initial-advertise-peer-urls 'http://localhost:12380' \
     --initial-cluster 'default=http://localhost:12380'
```

### 3.2 基本操作

**写入数据（put）**：

```bash
# 进入容器
docker exec -it etcd-demo sh

# 写入数据
etcdctl put name "张三"
etcdctl put age "25"
etcdctl put /config/database/host "192.168.1.100"
etcdctl put /config/database/port "3306"
```

**实验输出**：
```
OK
OK
OK
OK
```

**读取数据（get）**：

```bash
# 读取单个 key
etcdctl get name

# 读取带前缀的所有 key
etcdctl get --prefix /config/

# 只显示 key，不显示 value
etcdctl get --prefix /config/ --keys-only

# 以 JSON 格式输出（包含元数据）
etcdctl get name -w=json
```

**实验输出**：
```
$ etcdctl get name
name
张三

$ etcdctl get --prefix /config/
/config/database/host
192.168.1.100
/config/database/port
3306

$ etcdctl get name -w=json
{"header":{"cluster_id":14841639068965178418,"member_id":10276657743932975437,"revision":5,"raft_term":2},"kvs":[{"key":"bmFtZQ==","create_revision":2,"mod_revision":2,"version":1,"value":"5byg5LiJ"}],"count":1}
```

**删除数据（del）**：

```bash
# 删除单个 key
etcdctl del name

# 删除带前缀的所有 key
etcdctl del --prefix /config/
```

**实验输出**：
```
1
2
```


**监听变化（watch）**：

```bash
# 终端 1：启动监听
etcdctl watch --prefix /

# 终端 2：写入数据
etcdctl put /app/status "running"
etcdctl put /app/status "stopped"
etcdctl del /app/status
```

**终端 1 输出**：
```
PUT
/app/status
running
PUT
/app/status
stopped
DELETE
/app/status
```

每次数据变化，Watch 都会收到通知。这就是 K8s 实现"声明式"的秘密！

---

## 四、数据模型深度解析

### 4.1 版本与历史

etcd 的一个强大特性是**保留历史版本**。

**实验：观察 revision 变化**

```bash
# 写入数据，观察 revision 变化
etcdctl put /key val1
etcdctl put /key val2
etcdctl put /key val3
etcdctl put /key val4

# 查看当前值和元数据
etcdctl get /key -w=json
```

**实验输出**（简化）：
```json
{
  "header": {"revision": 5},
  "kvs": [{
    "key": "/key",
    "create_revision": 2,
    "mod_revision": 5,
    "version": 4,
    "value": "val4"
  }]
}
```

**查询历史版本**：

```bash
# 查询 revision=2 时的值
etcdctl get /key --rev=2

# 查询 revision=3 时的值
etcdctl get /key --rev=3
```

**实验输出**：
```
$ etcdctl get /key --rev=2
/key
val1

$ etcdctl get /key --rev=3
/key
val2
```

这就是 etcd 的"时光机"功能！

### 4.2 Lease 租约实战

**创建 Lease**：

```bash
# 创建一个 30 秒的 Lease
etcdctl lease grant 30
```

**实验输出**：
```
lease 694d81a1c98f0a0b granted with TTL(30s)
```

**使用 Lease 创建 key**：

```bash
# 使用 Lease 创建 key（注意替换 lease ID）
etcdctl put /service/web --lease=694d81a1c98f0a0b "192.168.1.100:8080"

# 查看 key
etcdctl get /service/web

# 查看 Lease 详情
etcdctl lease timetolive 694d81a1c98f0a0b

# 等待 30 秒后再查看
sleep 35
etcdctl get /service/web
```

**实验输出**：
```
$ etcdctl get /service/web
/service/web
192.168.1.100:8080

$ etcdctl lease timetolive 694d81a1c98f0a0b
lease 694d81a1c98f0a0b granted with TTL(30s), remaining(25s)

（30秒后）
$ etcdctl get /service/web
（空，key 已被自动删除）
```

**Lease 续约**：

```bash
# 创建 Lease
etcdctl lease grant 10

# 绑定 key
etcdctl put /heartbeat --lease=<lease_id> "alive"

# 持续续约（会阻塞）
etcdctl lease keep-alive <lease_id>
```

**实验输出**：
```
lease 694d81a1c98f0a10 keepalived with TTL(10)
lease 694d81a1c98f0a10 keepalived with TTL(10)
lease 694d81a1c98f0a10 keepalived with TTL(10)
...
```

只要 keep-alive 在运行，Lease 就不会过期。

---

## 五、高可用集群部署

### 5.1 为什么需要集群？

单节点 etcd 有单点故障风险。生产环境必须部署集群。

**集群节点数选择**：

| 节点数 | 容忍故障数 | 适用场景 |
|--------|-----------|---------|
| 1 | 0 | 开发测试 |
| 3 | 1 | 小规模生产 |
| 5 | 2 | 大规模生产 |
| 7 | 3 | 超大规模（不推荐，性能下降） |

### 5.2 本地三节点集群

**生成 TLS 证书**（生产环境必须）：

```bash
# 安装 cfssl
apt install golang-cfssl

# 生成证书（简化版，生产环境请参考官方文档）
mkdir -p /tmp/etcd-certs
cd /tmp/etcd-certs

# 生成 CA
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "etcd": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "87600h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "etcd-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

**启动三节点集群**：

```bash
# 节点 1
etcd --name infra0 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --listen-client-urls http://127.0.0.1:2379 \
  --advertise-client-urls http://127.0.0.1:2379 \
  --initial-advertise-peer-urls http://127.0.0.1:2380 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster-state new &

# 节点 2
etcd --name infra1 \
  --listen-peer-urls http://127.0.0.1:2381 \
  --listen-client-urls http://127.0.0.1:2479 \
  --advertise-client-urls http://127.0.0.1:2479 \
  --initial-advertise-peer-urls http://127.0.0.1:2381 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster-state new &

# 节点 3
etcd --name infra2 \
  --listen-peer-urls http://127.0.0.1:2382 \
  --listen-client-urls http://127.0.0.1:2579 \
  --advertise-client-urls http://127.0.0.1:2579 \
  --initial-advertise-peer-urls http://127.0.0.1:2382 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster-state new &
```

**验证集群**：

```bash
etcdctl --endpoints=http://127.0.0.1:2379 member list -w table
```

**实验输出**：
```
+------------------+---------+--------+------------------------+------------------------+
|        ID        | STATUS  |  NAME  |       PEER ADDRS       |      CLIENT ADDRS      |
+------------------+---------+--------+------------------------+------------------------+
| 8e9e05c52164694d | started | infra0 | http://127.0.0.1:2380  | http://127.0.0.1:2379  |
| 91bc3c398fb3c146 | started | infra1 | http://127.0.0.1:2381  | http://127.0.0.1:2479  |
| fd422379fda50e48 | started | infra2 | http://127.0.0.1:2382  | http://127.0.0.1:2579  |
+------------------+---------+--------+------------------------+------------------------+
```

---

## 六、备份恢复实战

### 6.1 为什么要备份？

即使 etcd 集群是高可用的，也可能遇到：
- 误操作删除数据
- 软件 bug 导致数据损坏
- 整个集群故障（机房断电、网络分区）
- 需要迁移到新集群

**备份是最后的保险**。

### 6.2 创建备份

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

**带 TLS 的备份**（生产环境）：

```bash
etcdctl --endpoints https://127.0.0.1:2379 \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  snapshot save /backup/etcd-snapshot.db
```


### 6.3 完整的备份恢复流程

**步骤 1：准备测试数据**

```bash
# 写入测试数据
etcdctl put /app/config/db_host "192.168.1.100"
etcdctl put /app/config/db_port "3306"
etcdctl put /app/users/user1 "Alice"
etcdctl put /app/users/user2 "Bob"

# 验证数据
etcdctl get --prefix /app/
```

**步骤 2：创建备份**

```bash
mkdir -p /tmp/etcd-backup
etcdctl snapshot save /tmp/etcd-backup/snapshot.db
etcdctl snapshot status /tmp/etcd-backup/snapshot.db -w table
```

**步骤 3：模拟灾难**

```bash
# 删除所有数据
etcdctl del --prefix /app/

# 验证数据已删除
etcdctl get --prefix /app/
# （空）
```

**步骤 4：恢复数据**

```bash
# 停止 etcd
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
/app/users/user1
Alice
/app/users/user2
Bob
```

数据恢复成功！

### 6.4 集群恢复

对于多节点集群，每个节点都要恢复：

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

然后启动所有节点。

---

## 七、运维最佳实践

### 7.1 存储配额管理

etcd 默认存储配额是 2GB，超过后会拒绝写入。

**实验：写爆磁盘**

```bash
# 启动一个小配额的 etcd（16MB）
etcd --quota-backend-bytes=$((16*1024*1024)) &

# 持续写入直到超过配额
while [ 1 ]; do
  dd if=/dev/urandom bs=1024 count=1024 2>/dev/null | etcdctl put key || break
done
```

**实验输出**：
```
Error: etcdserver: mvcc: database space exceeded
```

**查看告警**：

```bash
etcdctl alarm list
```

**实验输出**：
```
memberID:8e9e05c52164694d alarm:NOSPACE
```

**解决空间不足**：

```bash
# 1. 获取当前 revision
rev=$(etcdctl endpoint status --write-out="json" | jq '.[0].Status.header.revision')

# 2. 压缩历史版本
etcdctl compact $rev

# 3. 碎片整理
etcdctl defrag

# 4. 清除告警
etcdctl alarm disarm

# 5. 验证
etcdctl endpoint status -w table
etcdctl alarm list
```

### 7.2 碎片整理（Defrag）

etcd 删除数据后，磁盘空间不会立即释放，需要碎片整理。

```bash
# 写入大量数据
for i in $(seq 1 1000); do
  etcdctl put /test/key$i "value$i"
done

# 查看数据库大小
etcdctl endpoint status -w table

# 删除数据
etcdctl del --prefix /test/

# 再次查看（大小没变）
etcdctl endpoint status -w table

# 碎片整理
etcdctl defrag

# 再次查看（大小减小了）
etcdctl endpoint status -w table
```

### 7.3 自动压缩

```bash
# 启动时配置自动压缩（保留 1 小时历史）
etcd --auto-compaction-retention=1h

# 或者保留最近 1000 个 revision
etcd --auto-compaction-retention=1000 --auto-compaction-mode=revision
```

### 7.4 监控指标

| 指标 | 说明 | 告警阈值 |
|------|------|---------|
| etcd_server_has_leader | 是否有 Leader | = 0 告警 |
| etcd_server_leader_changes_seen_total | Leader 切换次数 | 频繁切换告警 |
| etcd_disk_wal_fsync_duration_seconds | WAL 同步延迟 | > 100ms 告警 |
| etcd_mvcc_db_total_size_in_bytes | 数据库大小 | > 80% 配额告警 |

```bash
# 查看端点状态
etcdctl endpoint status -w table

# 查看健康状态
etcdctl endpoint health

# 查看 metrics
curl http://127.0.0.1:2379/metrics
```

---

## 八、K8s 中的 etcd 操作

### 8.1 连接 K8s etcd

```bash
# 进入 etcd Pod
kubectl exec -it etcd-<node-name> -n kube-system -- sh

# 设置别名
alias ectl='etcdctl --endpoints https://127.0.0.1:2379 \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key'

# 测试连接
ectl member list
```

### 8.2 探索 K8s 数据结构

```bash
# 查看所有 key
ectl get --prefix --keys-only /registry/
```

**K8s 数据存储结构**：

```
/registry/
├── pods/
│   ├── default/
│   └── kube-system/
├── deployments/
├── services/
│   ├── endpoints/
│   └── specs/
├── configmaps/
├── secrets/
├── namespaces/
└── ...
```

### 8.3 查看具体资源

```bash
# 查看 kube-dns Service
ectl get /registry/services/specs/kube-system/kube-dns

# 查看所有 Pod
ectl get --prefix --keys-only /registry/pods/
```

### 8.4 K8s etcd 备份脚本

```bash
#!/bin/bash
# k8s-etcd-backup.sh

BACKUP_DIR="/backup/etcd"
BACKUP_FILE="$BACKUP_DIR/k8s-etcd-$(date +%Y%m%d-%H%M%S).db"
RETENTION_DAYS=7

mkdir -p $BACKUP_DIR

ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save $BACKUP_FILE

etcdctl snapshot status $BACKUP_FILE -w table

# 删除旧备份
find $BACKUP_DIR -name "k8s-etcd-*.db" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_FILE"
```

添加到 crontab：

```bash
# 每天凌晨 2 点备份
0 2 * * * /usr/local/bin/k8s-etcd-backup.sh >> /var/log/etcd-backup.log 2>&1
```

### 8.5 安全注意事项

1. **不要直接修改 etcd 数据**：可能导致 K8s 状态不一致
2. **谨慎使用 delete**：删除数据可能导致集群故障
3. **定期备份**：etcd 数据是 K8s 的命脉
4. **限制访问**：etcd 应该只允许 API Server 访问

```bash
# ⚠️ 危险操作，仅用于学习，不要在生产环境执行！
ectl del --prefix /registry/pods/default/
```

---

## 九、常用命令速查

### 基本操作

```bash
etcdctl put <key> <value>              # 写入
etcdctl get <key>                      # 读取
etcdctl get --prefix <prefix>          # 前缀查询
etcdctl del <key>                      # 删除
etcdctl watch <key>                    # 监听
etcdctl watch --prefix <prefix>        # 前缀监听
```

### 版本查询

```bash
etcdctl get <key> --rev=<revision>     # 查询历史版本
etcdctl get <key> -w=json              # JSON 格式输出
```

### Lease 操作

```bash
etcdctl lease grant <ttl>              # 创建租约
etcdctl lease list                     # 列出租约
etcdctl lease timetolive <lease_id>    # 查看租约详情
etcdctl lease keep-alive <lease_id>    # 续约
etcdctl lease revoke <lease_id>        # 撤销租约
etcdctl put <key> --lease=<lease_id>   # 绑定租约
```

### 集群管理

```bash
etcdctl member list                    # 列出成员
etcdctl endpoint status                # 端点状态
etcdctl endpoint health                # 健康检查
```

### 备份恢复

```bash
etcdctl snapshot save <file>           # 创建快照
etcdctl snapshot status <file>         # 查看快照
etcdctl snapshot restore <file>        # 恢复快照
```

### 运维操作

```bash
etcdctl compact <revision>             # 压缩历史
etcdctl defrag                         # 碎片整理
etcdctl alarm list                     # 查看告警
etcdctl alarm disarm                   # 清除告警
```

---

## 十、总结

### 核心知识回顾

| 主题 | 核心内容 |
|------|---------|
| **原理** | Raft 共识、MVCC、Lease、Watch |
| **基础操作** | put/get/del/watch |
| **数据模型** | revision、version、历史查询 |
| **集群部署** | 3/5 节点、TLS 证书 |
| **备份恢复** | snapshot save/restore |
| **运维** | 压缩、碎片整理、告警 |
| **K8s** | /registry/ 数据结构 |

### 最佳实践

1. **生产环境必须部署集群**：至少 3 节点
2. **定期备份**：每天至少一次，异地存储
3. **监控告警**：关注 Leader 状态、磁盘空间、延迟
4. **定期压缩**：配置自动压缩，定期碎片整理
5. **使用 SSD**：etcd 对磁盘 I/O 敏感
6. **不要直接操作 K8s etcd**：通过 kubectl 操作

### 学习路径

```
[基础操作] → [数据模型] → [集群部署] → [备份恢复] → [运维实践] → [K8s etcd]
```

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-16
- etcd 版本：3.5.x
- 适用对象：K8s 运维人员、想深入理解 K8s 存储层的开发者

---

## 参考资料

- [etcd 官方文档](https://etcd.io/docs/v3.5/)
- [How etcd works with and without Kubernetes](https://learnk8s.io/etcd-kubernetes)
- 极客时间云原生训练营 - 模块 5

---

> 💡 **建议**：理论看完后，一定要动手做实验！可以参考 `scripts/` 目录下的实验脚本。
