# etcd 集群部署 - 高可用之路

> 单点故障是生产环境的大忌

## 为什么需要集群？

单节点 etcd 的问题：
- 节点挂了，数据丢失
- 无法水平扩展
- 单点故障

etcd 集群的优势：
- **高可用**：容忍 (N-1)/2 个节点故障
- **数据安全**：多副本存储
- **读扩展**：读请求可以分散到多个节点

### 集群规模建议

| 节点数 | 容忍故障数 | 适用场景 |
|--------|-----------|---------|
| 1 | 0 | 开发测试 |
| 3 | 1 | 小型生产 |
| 5 | 2 | 大型生产 |
| 7 | 3 | 超大规模（不推荐，性能下降） |

**为什么是奇数？** Raft 共识算法需要多数派同意，奇数节点更高效。

---

## Raft 共识算法简介

etcd 使用 Raft 算法保证数据一致性。

### 三种角色

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Leader    │────▶│  Follower   │     │  Follower   │
│  (写入点)   │     │  (只读)     │     │  (只读)     │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   ▲                   ▲
       │                   │                   │
       └───────────────────┴───────────────────┘
                    复制日志
```

- **Leader**：处理所有写请求，复制到 Follower
- **Follower**：接收 Leader 的日志，可以处理读请求
- **Candidate**：选举期间的临时状态

### 写入流程

1. 客户端发送写请求到 Leader
2. Leader 将日志复制到多数 Follower
3. 多数确认后，Leader 提交日志
4. Leader 返回成功给客户端

---

## 实验：部署 3 节点集群

### 方式一：本地模拟（单机多端口）

```bash
# 创建数据目录
mkdir -p /tmp/etcd/{infra0,infra1,infra2}

# 启动节点 1
etcd --name infra0 \
  --data-dir=/tmp/etcd/infra0 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --listen-client-urls http://127.0.0.1:2379 \
  --advertise-client-urls http://127.0.0.1:2379 \
  --initial-advertise-peer-urls http://127.0.0.1:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-state new &

# 启动节点 2
etcd --name infra1 \
  --data-dir=/tmp/etcd/infra1 \
  --listen-peer-urls http://127.0.0.1:2381 \
  --listen-client-urls http://127.0.0.1:2479 \
  --advertise-client-urls http://127.0.0.1:2479 \
  --initial-advertise-peer-urls http://127.0.0.1:2381 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-state new &

# 启动节点 3
etcd --name infra2 \
  --data-dir=/tmp/etcd/infra2 \
  --listen-peer-urls http://127.0.0.1:2382 \
  --listen-client-urls http://127.0.0.1:2579 \
  --advertise-client-urls http://127.0.0.1:2579 \
  --initial-advertise-peer-urls http://127.0.0.1:2382 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382 \
  --initial-cluster-state new &
```

### 验证集群状态

```bash
# 查看成员列表
etcdctl --endpoints=http://127.0.0.1:2379 member list -w table

# 查看端点状态
etcdctl --endpoints=http://127.0.0.1:2379,http://127.0.0.1:2479,http://127.0.0.1:2579 \
  endpoint status -w table

# 查看健康状态
etcdctl --endpoints=http://127.0.0.1:2379,http://127.0.0.1:2479,http://127.0.0.1:2579 \
  endpoint health
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

+------------------------+------------------+---------+---------+-----------+-----------+
|        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER | RAFT TERM |
+------------------------+------------------+---------+---------+-----------+-----------+
| http://127.0.0.1:2379  | 8e9e05c52164694d |  3.5.0  |   20 kB |      true |         2 |
| http://127.0.0.1:2479  | 91bc3c398fb3c146 |  3.5.0  |   20 kB |     false |         2 |
| http://127.0.0.1:2579  | fd422379fda50e48 |  3.5.0  |   20 kB |     false |         2 |
+------------------------+------------------+---------+---------+-----------+-----------+
```

---

## 实验：故障转移

### 模拟 Leader 故障

```bash
# 找到 Leader
etcdctl --endpoints=http://127.0.0.1:2379,http://127.0.0.1:2479,http://127.0.0.1:2579 \
  endpoint status -w table | grep true

# 假设 infra0 是 Leader，杀掉它
pkill -f "etcd --name infra0"

# 等待几秒，查看新 Leader
sleep 5
etcdctl --endpoints=http://127.0.0.1:2479,http://127.0.0.1:2579 \
  endpoint status -w table
```

**实验输出**：
```
+------------------------+------------------+---------+---------+-----------+-----------+
|        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER | RAFT TERM |
+------------------------+------------------+---------+---------+-----------+-----------+
| http://127.0.0.1:2479  | 91bc3c398fb3c146 |  3.5.0  |   20 kB |      true |         3 |
| http://127.0.0.1:2579  | fd422379fda50e48 |  3.5.0  |   20 kB |     false |         3 |
+------------------------+------------------+---------+---------+-----------+-----------+
```

新 Leader 自动选举出来了！RAFT TERM 增加了。

### 验证数据一致性

```bash
# 写入数据
etcdctl --endpoints=http://127.0.0.1:2479 put /test "hello"

# 从另一个节点读取
etcdctl --endpoints=http://127.0.0.1:2579 get /test
```

**实验输出**：
```
/test
hello
```

数据自动同步到所有节点。

---

## 方式二：Docker Compose 部署

创建 `docker-compose.yaml`：

```yaml
version: '3'
services:
  etcd1:
    image: registry.aliyuncs.com/google_containers/etcd:3.5.0-0
    container_name: etcd1
    command:
      - etcd
      - --name=etcd1
      - --data-dir=/etcd-data
      - --listen-client-urls=http://0.0.0.0:2379
      - --advertise-client-urls=http://etcd1:2379
      - --listen-peer-urls=http://0.0.0.0:2380
      - --initial-advertise-peer-urls=http://etcd1:2380
      - --initial-cluster=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
      - --initial-cluster-token=etcd-cluster
      - --initial-cluster-state=new
    ports:
      - "2379:2379"
    volumes:
      - etcd1-data:/etcd-data

  etcd2:
    image: registry.aliyuncs.com/google_containers/etcd:3.5.0-0
    container_name: etcd2
    command:
      - etcd
      - --name=etcd2
      - --data-dir=/etcd-data
      - --listen-client-urls=http://0.0.0.0:2379
      - --advertise-client-urls=http://etcd2:2379
      - --listen-peer-urls=http://0.0.0.0:2380
      - --initial-advertise-peer-urls=http://etcd2:2380
      - --initial-cluster=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
      - --initial-cluster-token=etcd-cluster
      - --initial-cluster-state=new
    ports:
      - "2479:2379"
    volumes:
      - etcd2-data:/etcd-data

  etcd3:
    image: registry.aliyuncs.com/google_containers/etcd:3.5.0-0
    container_name: etcd3
    command:
      - etcd
      - --name=etcd3
      - --data-dir=/etcd-data
      - --listen-client-urls=http://0.0.0.0:2379
      - --advertise-client-urls=http://etcd3:2379
      - --listen-peer-urls=http://0.0.0.0:2380
      - --initial-advertise-peer-urls=http://etcd3:2380
      - --initial-cluster=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
      - --initial-cluster-token=etcd-cluster
      - --initial-cluster-state=new
    ports:
      - "2579:2379"
    volumes:
      - etcd3-data:/etcd-data

volumes:
  etcd1-data:
  etcd2-data:
  etcd3-data:
```

```bash
# 启动集群
docker-compose up -d

# 验证
docker exec etcd1 etcdctl member list -w table
```

---

## 成员管理

### 添加新成员

```bash
# 在现有集群上添加成员
etcdctl --endpoints=http://127.0.0.1:2379 member add infra3 \
  --peer-urls=http://127.0.0.1:2383

# 启动新成员（注意 initial-cluster-state=existing）
etcd --name infra3 \
  --data-dir=/tmp/etcd/infra3 \
  --listen-peer-urls http://127.0.0.1:2383 \
  --listen-client-urls http://127.0.0.1:2679 \
  --advertise-client-urls http://127.0.0.1:2679 \
  --initial-advertise-peer-urls http://127.0.0.1:2383 \
  --initial-cluster infra0=http://127.0.0.1:2380,infra1=http://127.0.0.1:2381,infra2=http://127.0.0.1:2382,infra3=http://127.0.0.1:2383 \
  --initial-cluster-state existing &
```

### 移除成员

```bash
# 获取成员 ID
etcdctl --endpoints=http://127.0.0.1:2379 member list

# 移除成员
etcdctl --endpoints=http://127.0.0.1:2379 member remove <member_id>
```

---

## 核心要点

1. **集群规模**：生产环境推荐 3 或 5 节点
2. **Raft 共识**：Leader 处理写请求，复制到多数节点
3. **故障转移**：自动选举新 Leader
4. **成员管理**：可以动态添加/移除成员

---

## 下一步

集群部署好了，接下来学习如何备份和恢复数据。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[etcd 数据模型](02-data-model.md)  
**下一篇**：[etcd 备份恢复](04-backup-restore.md)
