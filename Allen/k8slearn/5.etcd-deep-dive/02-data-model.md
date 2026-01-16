# etcd 数据模型 - 理解 MVCC 和 Lease

> 理解数据模型，才能用好 etcd

## MVCC：多版本并发控制

etcd 使用 MVCC（Multi-Version Concurrency Control）来管理数据。

### 什么是 MVCC？

想象一个 Git 仓库：
- 每次 commit 都有一个版本号
- 你可以查看任意历史版本
- 新的修改不会覆盖旧版本

etcd 也是这样：
- 每次写操作都会增加全局 revision
- 旧版本数据不会立即删除
- 可以查询任意历史版本

### 实验：观察 MVCC

```bash
# 清理环境
etcdctl del --prefix /

# 写入数据，观察 revision
etcdctl put /user/name "Alice"
etcdctl get /user/name -w=json | jq '.header.revision'

etcdctl put /user/age "25"
etcdctl get /user/age -w=json | jq '.header.revision'

etcdctl put /user/name "Bob"
etcdctl get /user/name -w=json | jq '.header.revision'
```

**实验输出**：
```
2
3
4
```

每次写操作，revision 都会增加。

```bash
# 查询历史版本
etcdctl get /user/name --rev=2
etcdctl get /user/name --rev=4
```

**实验输出**：
```
/user/name
Alice

/user/name
Bob
```

---

## Lease：租约机制

Lease 是 etcd 的"定时炸弹"——给 key 设置一个生存时间，到期自动删除。

### 为什么需要 Lease？

场景：服务注册与发现
- 服务启动时，向 etcd 注册自己
- 如果服务挂了，注册信息应该自动删除
- 否则其他服务会访问一个"死"服务

Lease 就是解决这个问题的：
- 服务注册时，创建一个 Lease
- 服务定期续约（keep-alive）
- 服务挂了，无法续约，Lease 过期，key 自动删除

### 实验：Lease 基本操作

```bash
# 创建一个 30 秒的 Lease
etcdctl lease grant 30
```

**实验输出**：
```
lease 694d81a1c98f0a0b granted with TTL(30s)
```

```bash
# 使用 Lease 创建 key（注意替换 lease ID）
etcdctl put /service/web --lease=694d81a1c98f0a0b "192.168.1.100:8080"

# 查看 key
etcdctl get /service/web

# 查看 Lease 列表
etcdctl lease list

# 查看 Lease 详情
etcdctl lease timetolive 694d81a1c98f0a0b

# 等待 30 秒后再查看
sleep 35
etcdctl get /service/web
```

**实验输出**：
```
/service/web
192.168.1.100:8080

found 1 leases
694d81a1c98f0a0b

lease 694d81a1c98f0a0b granted with TTL(30s), remaining(25s)

（30秒后）
（空，key 已被自动删除）
```

### 实验：Lease 续约

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

### 实验：撤销 Lease

```bash
# 创建 Lease 和 key
etcdctl lease grant 300
etcdctl put /temp/data --lease=<lease_id> "temporary"

# 查看
etcdctl get /temp/data

# 撤销 Lease（key 也会被删除）
etcdctl lease revoke <lease_id>

# 再查看
etcdctl get /temp/data
```

**实验输出**：
```
/temp/data
temporary

lease <lease_id> revoked

（空）
```

---

## Watch：监听机制

Watch 是 etcd 的核心特性，K8s 的 Controller 就是靠它实现的。

### 基本 Watch

```bash
# 终端 1：监听所有 key
etcdctl watch --prefix /

# 终端 2：操作数据
etcdctl put /app/config "v1"
etcdctl put /app/config "v2"
etcdctl del /app/config
```

**终端 1 输出**：
```
PUT
/app/config
v1
PUT
/app/config
v2
DELETE
/app/config
```

### 从历史版本开始 Watch

```bash
# 先写入一些数据
etcdctl put /log/1 "event1"
etcdctl put /log/2 "event2"
etcdctl put /log/3 "event3"

# 获取当前 revision
etcdctl get /log/1 -w=json | jq '.header.revision'
# 假设输出 5

# 从 revision=3 开始 watch（会收到历史事件）
etcdctl watch --prefix /log/ --rev=3
```

这个特性非常重要：即使 Watch 断开重连，也不会丢失事件！

---

## 事务操作

etcd 支持事务，可以实现"比较并交换"（CAS）操作。

### 实验：事务

```bash
# 初始化
etcdctl put /counter 0

# 事务：如果 /counter 的值是 "0"，则设置为 "1"
etcdctl txn --interactive
# 输入：
# compares:
# value("/counter") = "0"
# 
# success requests:
# put /counter 1
# 
# failure requests:
# get /counter

# 验证
etcdctl get /counter
```

**简化写法**：

```bash
# 如果 /lock 不存在，则创建
etcdctl txn -i <<EOF
create_revision("/lock") = "0"

put /lock "locked"

get /lock
EOF
```

---

## 数据压缩

etcd 保留历史版本会占用磁盘空间，需要定期压缩。

### 实验：压缩

```bash
# 查看当前 revision
etcdctl get / -w=json | jq '.header.revision'
# 假设输出 100

# 压缩到 revision 50（50 之前的历史版本会被删除）
etcdctl compact 50

# 尝试查询 revision 30 的数据
etcdctl get /key --rev=30
```

**实验输出**：
```
compacted revision 50

Error: etcdserver: mvcc: required revision has been compacted
```

压缩后，旧版本数据无法访问了。

---

## 核心要点

1. **MVCC**：
   - 每次写操作增加全局 revision
   - 可以查询任意历史版本
   - 需要定期压缩释放空间

2. **Lease**：
   - 给 key 设置 TTL
   - 需要定期续约（keep-alive）
   - 适合服务注册、分布式锁

3. **Watch**：
   - 实时监听数据变化
   - 可以从历史版本开始 watch
   - K8s Controller 的核心依赖

4. **事务**：
   - 支持 CAS 操作
   - 实现分布式锁

---

## 下一步

理解了数据模型，接下来学习如何部署高可用的 etcd 集群。

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-15

---

**上一篇**：[etcd 基础操作](01-etcd-basics.md)  
**下一篇**：[etcd 集群部署](03-cluster-setup.md)
