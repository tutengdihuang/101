# etcd 基础操作 - 从零开始

> 先学会走，再学会跑

## etcd 是什么？

用最简单的话说：**etcd 就是一个分布式的 key-value 数据库**。

就像 Redis，但有几个关键区别：

| 特性 | etcd | Redis |
|------|------|-------|
| 一致性 | 强一致性（Raft） | 最终一致性 |
| 用途 | 配置存储、服务发现 | 缓存、消息队列 |
| 性能 | 写入较慢，读取快 | 读写都很快 |
| 数据安全 | 数据不丢失 | 可能丢失 |

**为什么 K8s 选择 etcd？** 因为 K8s 需要的是"绝对可靠"，而不是"极致性能"。

---

## 安装 etcd

### 方式一：Docker（推荐）

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

### 方式二：二进制安装

```bash
# 下载
ETCD_VER=v3.5.0
DOWNLOAD_URL=https://github.com/etcd-io/etcd/releases/download
curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd.tar.gz

# 解压安装
tar xzvf /tmp/etcd.tar.gz -C /tmp/
sudo cp /tmp/etcd-${ETCD_VER}-linux-amd64/etcd* /usr/local/bin/

# 验证
etcd --version
etcdctl version
```

### 方式三：本地启动（避免端口冲突）

如果本地已有 K8s 集群，etcd 可能占用了默认端口，使用自定义端口：

```bash
etcd --listen-client-urls 'http://localhost:12379' \
     --advertise-client-urls 'http://localhost:12379' \
     --listen-peer-urls 'http://localhost:12380' \
     --initial-advertise-peer-urls 'http://localhost:12380' \
     --initial-cluster 'default=http://localhost:12380'
```

---

## 基础操作

### 1. 写入数据（put）

```bash
# 写入单个键值对
etcdctl put name "张三"
etcdctl put age "25"
etcdctl put /config/database/host "192.168.1.100"
etcdctl put /config/database/port "3306"

# 验证
echo "写入成功"
```

**实验输出**：
```
OK
OK
OK
OK
写入成功
```

### 2. 读取数据（get）

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
name
张三

/config/database/host
192.168.1.100
/config/database/port
3306

/config/database/host
/config/database/port

{"header":{"cluster_id":...},"kvs":[{"key":"bmFtZQ==","create_revision":2,"mod_revision":2,"version":1,"value":"5byg5LiJ"}],"count":1}
```

### 3. 删除数据（del）

```bash
# 删除单个 key
etcdctl del name

# 删除带前缀的所有 key
etcdctl del --prefix /config/

# 验证
etcdctl get --prefix /
```

**实验输出**：
```
1
2
```

### 4. 监听变化（watch）

Watch 是 etcd 的杀手锏，K8s 的 Controller 就是靠它实现的。

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

## 版本与历史

etcd 的一个强大特性是**保留历史版本**。

### 理解 Revision

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

关键概念：
- **revision**：全局递增的版本号，每次写操作都会增加
- **create_revision**：key 创建时的 revision
- **mod_revision**：key 最后修改时的 revision
- **version**：key 被修改的次数

### 查询历史版本

```bash
# 查询 revision=2 时的值
etcdctl get /key --rev=2

# 查询 revision=3 时的值
etcdctl get /key --rev=3

# 从 revision=2 开始 watch
etcdctl watch --prefix / --rev=2
```

**实验输出**：
```
/key
val1

/key
val2

PUT
/key
val1
PUT
/key
val2
PUT
/key
val3
PUT
/key
val4
```

这就是 etcd 的"时光机"功能！

---

## 成员管理

查看 etcd 集群成员：

```bash
# 列出所有成员
etcdctl member list

# 以表格形式显示
etcdctl member list --write-out=table
```

**实验输出**：
```
+------------------+---------+---------+-----------------------+-----------------------+
|        ID        | STATUS  |  NAME   |      PEER ADDRS       |     CLIENT ADDRS      |
+------------------+---------+---------+-----------------------+-----------------------+
| 8e9e05c52164694d | started | default | http://localhost:2380 | http://localhost:2379 |
+------------------+---------+---------+-----------------------+-----------------------+
```

---

## 端点状态

```bash
# 查看端点状态
etcdctl endpoint status --write-out=table

# 查看端点健康状态
etcdctl endpoint health
```

**实验输出**：
```
+-----------------+------------------+---------+---------+-----------+-----------+
|    ENDPOINT     |        ID        | VERSION | DB SIZE | IS LEADER | RAFT TERM |
+-----------------+------------------+---------+---------+-----------+-----------+
| 127.0.0.1:2379  | 8e9e05c52164694d |  3.5.0  |   20 kB |      true |         2 |
+-----------------+------------------+---------+---------+-----------+-----------+

127.0.0.1:2379 is healthy: successfully committed proposal: took = 1.234ms
```

---

## 核心要点

1. **etcd 是分布式 KV 存储**：强一致性，适合存储配置和元数据
2. **基本操作**：put、get、del、watch
3. **版本控制**：每次写操作都有 revision，可以查询历史
4. **Watch 机制**：实时监听数据变化，K8s 的核心依赖

---

## 下一步

基础操作掌握了，接下来学习 etcd 的数据模型，理解 Lease（租约）机制。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[README](README.md)  
**下一篇**：[etcd 数据模型](02-data-model.md)
