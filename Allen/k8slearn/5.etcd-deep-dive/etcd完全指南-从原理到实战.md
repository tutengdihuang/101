# etcd 完全指南：从原理到实战（教与学专家版）

> 目标：让你 **学得快、教得好、记得住、用得上**。本篇先给 30 秒版“秒懂定位”，再给知识骨架，再进入工程细节（含一致性、读语义、watch/compaction、WAL/snapshot/backend、备份恢复、K8s 场景）。

---

## 一、秒懂定位（30 秒版）

**这个知识解决什么问题**：

etcd 解决的是：在分布式系统里，大家对“当前事实”必须达成一致（谁是 Leader、配置是什么、对象状态是什么），而且要能容灾、可追溯、可订阅变更。

**一句话精华**：

etcd = “带 Raft 的一致性账本 + 带 MVCC 的时光机 + 带 Watch 的事件总线（但不是 MQ）”。

**适合谁学**：

- 想把 Kubernetes 运维/排障做稳的人
- 需要做配置中心、服务发现、分布式锁的人

**不适合谁**：

- 把 etcd 当 Redis 缓存用、写大对象/高吞吐场景（会痛苦）

---

## 二、核心框架（知识骨架）

**核心观点**：

etcd 是一个提供 **可推理一致性语义** 的分布式 KV：写走 Leader 并需多数派提交；读分线性一致与本地串行化；数据按 MVCC 留历史；watch 基于 revision 推增量；空间回收必须 compact→defrag。

**关键概念速查表**：

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| Raft/Leader | 写请求要找“班长”盖章，且要过半同学同意 | 班级投票 | 多数派提交才算数 |
| Revision | 全局递增的“提交号” | 账本页码 | 每次提交 +1 |
| MVCC | 同一个 key 有多个历史版本 | Git 提交历史 | 能查旧版本，但会占空间 |
| Linearizable Read | 保证读到最新事实 | 查银行实时余额 | 慢但准 |
| Serializable Read | 从本地读，可能旧 | 看昨天缓存的余额 | 快但可能落后 |
| Watch | 订阅变更事件流 | 关注公众号推送 | 会断，需要续接 |
| Compact/Defrag | 丢历史/再整理文件 | 清理旧账+整理抽屉 | 先丢再整理 |

**知识地图**：

`一致性(raft) → 读语义 → MVCC/revision → watch → 存储(WAL/backend) → 运维(compact/defrag/备份) → K8s 场景`

---

## 三、深入浅出讲解（教学版）

**开场钩子**：

你以为 etcd 是“分布式版 Redis”？那你就像把“人民银行”当成“便利店收银台”——都管钱，但一个管的是**事实与秩序**，另一个管的是**效率与周转**。

### 【概念 1：Raft 与多数派】

**一句话是什么**：Raft 用“选 Leader + 复制日志 + 多数派提交”保证所有节点对写入顺序一致。

**生活化比喻**：

把写入想成“改班规”：必须班长先写进班规本，然后至少 2/3 同学确认签字，班规才生效。

**引经据典**：

“治大国若烹小鲜”——分布式系统不是猛火快炒，关键是火候稳定；etcd 的火候就是网络与磁盘 fsync。

**常见误区（幽默版）**：

“3 节点集群，挂 2 台也能写吧？”——这就像 3 人投票只剩 1 人还想通过决议：这不是民主，这是独裁。

**启发式问题**：
- 为什么 etcd 推荐 3/5/7，而不是 4/6？
- 写入延迟主要受什么影响：CPU、网络还是磁盘？为什么？

### 【概念 2：读语义（Linearizable vs Serializable）】

**一句话是什么**：同样是 get，etcd 允许你选择“最新但可能更慢”或“更快但可能旧”。

**生活化比喻**：

- Linearizable：去银行柜台查实时余额（慢但准）
- Serializable：看你手机里昨天同步的余额（快但可能落后）

**常见误区（幽默版）**：

“读肯定比写快”——你要是 insist 线性一致读，读也得“找班长确认一下”，不一定快到哪里去。

**启发式问题**：
- K8s 为什么更倾向强一致语义？
- 你自己的业务哪些读可以容忍旧值？

### 【概念 3：Watch 与 compaction】

**一句话是什么**：watch 是“从某个 revision 起持续收增量”；但历史会被 compact，旧 revision 会被“铲平”，watch 会断。

**生活化比喻**：

watch 像追剧：你从第 120 集开始追；但平台把 1~150 集下架了（compact），你再从 120 集打开就会报错，只能重拉最新全集再接着追。

**常见误区（幽默版）**：

把 watch 当 MQ：这就像把“朋友圈通知”当“银行转账流水”——通知可以漏、可以断，重要信息得有补偿机制（list+watch 续接）。

---

## 四、精华提炼（去废话版）

**核心要点（只保留干货）**：

1. **写入路径**：必须走 Leader，多数派确认后提交；性能瓶颈多在 **WAL fsync + 网络**。
2. **读语义**：线性一致读更“真实”，串行化读更“快”；别再一句话说“读快写慢”。
3. **watch 可靠性**：watch 会断（网络/leader 切换/compact），正确姿势永远是 **list → watch → 断了再 list**。
4. **空间回收**：删除不会立刻变小；必须 **compact（丢历史）→ defrag（物理整理）**。
5. **K8s 场景**：不要直接改 `/registry`；备份用 snapshot；排障先看 health/status/leader。

**砍掉的废话**：
- “etcd 就是分布式 Redis”这类简单粗暴对比
- 只讲命令不讲边界（比如只讲 watch 不讲 compacted）

**必须记住的**：
- 多数派是硬边界；线性一致读与串行化读是两套语义；compact→defrag 顺序不能反。

---

## 五、行动清单（从 5 分钟到本周实战）

**立即可做（5 分钟内）**：
- [ ] 用 `etcdctl endpoint status -w table` 看一下 revision/leader
- [ ] 跑一个 `watch --prefix`，然后手动 `put/del` 看事件流

**本周实践**：
- [ ] 写一个“list + watch 自动续接”的小 demo（遇到 compacted 自动重新 list）
- [ ] 在测试环境演练一次 `snapshot save` + `snapshot restore`

**进阶挑战**：
- [ ] 做一次 NOSPACE 的故障演练：触发告警→compact→defrag→disarm
- [ ] 观察 wal fsync 延迟与写延迟的关系（metrics）

---

## 六、学习检查（自测题）

- [ ] 为什么 etcd 集群推荐 3/5 节点而不是 4？
- [ ] 线性一致读与串行化读的差异是什么？各适合什么场景？
- [ ] watch 报 `compacted` 时正确处理流程是什么？
- [ ] 为什么空间回收要先 compact 再 defrag？
- [ ] 解释 WAL / snapshot / backend 三者的分工。

---

## 七、金句收藏

**我的总结金句**：

“etcd 不怕你写慢，就怕你以为它该写快。”

“watch 不是消息队列，别让它背不该背的锅。”

“compact 是删历史，defrag 是整理房间：先扔旧物，再收拾地板。”

---

## 八、画龙点睛（收尾）

如果你只把 etcd 当成一个 KV，你最多学会 `put/get`；如果你把它当成一个“**一致性系统**”，你就能回答生产里最关键的问题：
- 为什么今天写入突然抖了？
- 为什么 controller 收不到事件？
- 为什么空间不降？
- 为什么恢复后集群看似活着但状态不推进？

**悬念预告**：下一篇可以把“API Server 的 storage layer + watch cache + etcd compaction”串起来，你会看到 K8s 为什么要这么设计。

---

## 九、延伸资源

- 官方文档：https://etcd.io/docs/
- Raft 可视化：建议找一个在线可视化工具跑一遍 leader 选举
- K8s 源码：apiserver watch cache / storage 接口（理解 list+watch）

---

## 十、版本信息

- 文档版本：v3.0（按 .kiro/steering 教学规范重写）
- 创建日期：2026-01-16
- 最后更新：2026-01-18
- 基于教学经验：30 年教学经验 + 20 年学习研究经验（steering 05/09/11）
- 适用对象：进阶/高级（偏工程与生产）

---

## 十一、质量检查（交付前自检）

**学习能力维度**：
- [x] 是否给出 80/20 的核心要点与“必须记住的”
- [x] 是否提供生活化比喻/类比解释抽象概念
- [x] 是否提供实践建议与行动清单
- [x] 是否提供自测题（学习检查）

**教学能力维度**：
- [x] 是否循序渐进：秒懂定位 → 骨架 → 深入讲解 → 实战行动
- [x] 是否预防常见误区（watch 当 MQ、compact/defrag 顺序等）
- [x] 是否提供可迁移的排障/工程心智模型

---

## 附录：工程深度正文（30 分钟版 / 深度版）

# etcd 完全指南（深度版）：从原理到工程实战

> 面向工程与生产的 etcd 指南：把一致性、存储引擎、watch、备份恢复、参数与 K8s 场景一次讲清楚。

## 前言：为什么你必须“像理解数据库一样”理解 etcd

如果把 Kubernetes 比作一个人：
- API Server 是嘴巴（接收指令）
- Controller Manager 是手脚（把期望状态变成现实）
- Scheduler 是大脑的调度决策区
- **etcd 是记忆与事实来源（Source of Truth）**

K8s 的所有对象（Pod/Deployment/Service/Secret/RBAC/…）最终都会落在 etcd。
一旦 etcd 失效，你会看到：
- API Server 读写失败
- Controller 无法收敛
- 集群“看起来还活着”，但状态无法推进

本文不是“命令堆砌”，而是把 etcd 当作一个 **一致性存储系统** 来讲：
- 它保证的到底是什么一致性？
- 写入为什么慢？读为什么有两种语义？
- watch 为什么是 K8s 的核心机制？为什么会断？
- compact/defrag/snapshot/WAL 的关系是什么？
- 生产上怎么选节点数、怎么配参数、怎么做备份恢复？

---

## 目录

1. [你需要的心智模型：etcd 是什么（以及它不是什么）](#1-你需要的心智模型etcd-是什么以及它不是什么)
2. [一致性与 Raft：写入路径与故障边界](#2-一致性与-raft写入路径与故障边界)
3. [读语义：Linearizable vs Serializable（别再笼统说“读快”）](#3-读语义linearizable-vs-serializable别再笼统说读快)
4. [数据模型：MVCC / revision / version / 事务（txn）](#4-数据模型mvcc--revision--version--事务txn)
5. [Lease 与 KeepAlive：服务注册、心跳与自动清理](#5-lease-与-keepalive服务注册心跳与自动清理)
6. [Watch：K8s 的事件驱动内核（以及 watch 断了怎么办）](#6-watchk8s-的事件驱动内核以及-watch-断了怎么办)
7. [存储引擎：WAL / Snapshot / Backend（BoltDB）与空间回收](#7-存储引擎wal--snapshot--backendboltdb与空间回收)
8. [集群部署：节点数、网络、磁盘、TLS 与常见坑](#8-集群部署节点数网络磁盘tls-与常见坑)
9. [备份与恢复：正确的快照、恢复与灾备演练](#9-备份与恢复正确的快照恢复与灾备演练)
10. [生产运维：告警、compact/defrag、关键参数与排障套路](#10-生产运维告警compactdefrag关键参数与排障套路)
11. [Kubernetes 场景：如何安全地接触 K8s etcd](#11-kubernetes-场景如何安全地接触-k8s-etcd)
12. [命令速查（只保留高频且不误导的）](#12-命令速查只保留高频且不误导的)

---

## 1. 你需要的心智模型：etcd 是什么（以及它不是什么）

### 1.1 etcd 是什么

一句话：**etcd 是一个提供线性一致性语义的分布式 KV 存储**（基于 Raft 复制日志）。

它通常用来存“系统元数据/配置/服务发现信息”，特点是：
- 写路径需要 quorum（多数派）确认
- 读有不同一致性等级
- 支持 MVCC（历史版本）
- 支持 watch（增量订阅）

### 1.2 etcd 不是什么

- etcd 不是缓存（它追求一致性和可靠性，不追求极致吞吐）
- etcd 不是 OLTP 数据库（不适合大对象、大量事务）
- etcd 不是消息队列（watch 不是 MQ，存在 compaction 等边界）

### 1.3 “etcd vs Redis”怎么说才严谨

很多文章用“Redis 最终一致 / etcd 强一致”来对比，这种说法过粗。
更准确的对比是：

| 维度 | etcd | Redis（典型主从/集群） |
|---|---|---|
| 核心目标 | **一致性 + 元数据可靠存储** | **低延迟 + 高吞吐** |
| 一致性模型 | Raft 多数派提交，支持 **线性一致读/写** | 一致性取决于拓扑与同步策略：异步复制可能读到旧值 |
| 读语义 | 线性一致 / 可串行化（本地）两种 | 通常读主/读从策略决定一致性 |
| 适配场景 | 配置中心、服务发现、K8s 存储 | 缓存、会话、计数、队列等 |

**结论**：K8s 选 etcd，不是因为它“快”，而是因为它提供了**可推理的一致性语义与故障边界**。

---

## 2. 一致性与 Raft：写入路径与故障边界

### 2.1 Raft 的核心（够用版）

etcd 集群中：
- 只有 1 个 Leader
- **所有写请求必须经由 Leader**
- Leader 将写请求追加到 Raft 日志（WAL），复制给 Followers
- **多数派（quorum）确认后提交（commit）**，写才算成功

写路径可以理解为：

```
client -> leader
leader: append log
leader -> followers: replicate log
quorum ack
leader: commit -> apply to backend
reply to client
```

### 2.2 为什么“多数派”是硬边界

以 3 节点为例：多数派是 2。
- 挂 1 个节点：还能达成 2/3，多数派存在，集群可写
- 挂 2 个节点：只能 1/3，多数派不存在，写入必须停止（避免脑裂）

因此生产常见节点数：
- 3 节点：容忍 1 故障（最常见）
- 5 节点：容忍 2 故障（更强容灾，但写延迟更高）

### 2.3 你应该记住的工程结论

- **写延迟 ≈ Leader 本地 fsync + 网络往返 + 多数派 fsync**
- 磁盘（尤其 WAL 的 fsync）是 etcd 性能与稳定性的关键
- 网络抖动会让 leader 选举更频繁，整体延迟抖动更大

---

## 3. 读语义：Linearizable vs Serializable（别再笼统说“读快”）

etcd 的读主要有两种一致性语义：

### 3.1 Linearizable Read（线性一致读）

- 读到的结果必须反映“所有已提交写”的全序
- 通常需要与 leader/quorum 协调（确保读不落后）
- 延迟更高，但语义最强

### 3.2 Serializable Read（可串行化/本地读）

- 可直接从本地状态机读取
- 延迟更低
- 可能读到旧数据（在 leader 切换、网络分区等情况下更明显）

**工程建议**：
- 你关心“读到的就是最新事实”：用线性一致读
- 你关心“低延迟的近似读取”且能容忍旧数据：可串行化读

K8s 场景下：
- API Server 对一致性有严格要求，通常会选择更强语义

---

## 4. 数据模型：MVCC / revision / version / 事务（txn）

### 4.1 MVCC 与 revision

etcd 的所有写入都会推进一个全局递增的 **revision**。

你可以把它想成“全局提交序号”：
- 每次事务提交，revision +1
- 每个 key 记录 create_revision、mod_revision、version

| 字段 | 含义 |
|---|---|
| revision | 集群全局提交号 |
| create_revision | key 第一次创建时的 revision |
| mod_revision | 最近一次修改 key 的 revision |
| version | 这个 key 被修改了多少次（逻辑版本） |

### 4.2 事务（Txn）

etcd 事务支持 CAS 风格的 compare/then/else，核心价值在于：
- 在强一致前提下实现“条件更新”
- 常用于分布式锁、leader 选举、幂等写入

示意：
- compare：某个 key 的 mod_revision 是否等于期望
- then：写入/删除
- else：返回当前值

---

## 5. Lease 与 KeepAlive：服务注册、心跳与自动清理

Lease 是 etcd 的“租约”，用来给 key 附加 TTL。
典型用法是服务发现：
- 服务启动：写入 `/services/xxx/instance-id` 并绑定 lease
- 服务存活：周期 keep-alive
- 服务异常退出：无法续约，lease 到期，key 自动删除

关键点：
- lease 过期删除是 etcd 的机制保证，不依赖业务程序主动清理
- keep-alive 如果抖动，可能导致实例被误删（需要合理 TTL/续约间隔）

---

## 6. Watch：K8s 的事件驱动内核（以及 watch 断了怎么办）

### 6.1 watch 为什么重要

K8s 的 Controller 不是“轮询数据库”，而是：
- list 一次拿到当前全量
- watch 从某个 resourceVersion（本质上对应 etcd revision）开始收增量

这样才能做到高效、实时的状态收敛。

### 6.2 watch 的三条硬边界

- **边界 1：watch 不是 MQ**
  watch 依赖 etcd 的历史版本保留。一旦历史被 compact，旧 revision 的 watch 会报错。

- **边界 2：compaction 会让旧 watch 断流**
  当你从一个很旧的 revision 开始 watch，会收到类似：
  `etcdserver: mvcc: required revision has been compacted`

- **边界 3：client 必须实现“list + watch 续接”**
  正确模式：
  1) list 获取全量并记录最新 revision
  2) watch 从该 revision 开始
  3) watch 断开/报 compacted：回到 1

### 6.3 etcdctl watch 示例

```bash
# 监听某个前缀
ETCDCTL_API=3 etcdctl watch --prefix /config/
```

---

## 7. 存储引擎：WAL / Snapshot / Backend（BoltDB）与空间回收

这一节是很多“入门文章”缺失的关键：**你理解了这一层，才知道 compact/defrag 为什么必须、为什么顺序不能反**。

### 7.1 三个核心部件

- **WAL（Write-Ahead Log）**
  Raft 日志落盘位置。写入路径上要 fsync，性能强依赖磁盘。

- **Snapshot（快照）**
  用于加速节点重启/追赶，避免重放无限长日志。

- **Backend（BoltDB）**
  etcd 的 MVCC 数据最终落在 backend（BoltDB）。

你可以把它理解为：
- WAL 负责“复制一致性与恢复”
- Backend 负责“当前状态与历史版本”

### 7.2 为什么删除数据后空间不会马上下降

BoltDB 的空间回收不是“实时”的：
- 你删除 key 只是产生新版本（tombstone），旧页可能仍占用空间
- 需要通过 **compaction** 丢弃旧版本
- 再通过 **defrag** 把 backend 文件重写/整理，才能真正释放空间

### 7.3 关键顺序：先 compact 再 defrag

- compact：告诉 etcd 丢弃某 revision 之前的历史版本
- defrag：对 backend 做物理整理，释放空间

如果只 defrag 不 compact：
- 旧版本仍存在，空间不会明显下降

---

## 8. 集群部署：节点数、网络、磁盘、TLS 与常见坑

### 8.1 节点数选择

- 3 节点是生产的基线（容忍 1 故障）
- 5 节点用于更强容灾（容忍 2 故障），但写延迟和资源成本更高

### 8.2 磁盘与网络

- 优先 SSD（WAL fsync 很敏感）
- 避免与高 IO 业务共盘
- 保证节点间网络稳定、延迟低

### 8.3 TLS：生产环境默认必须启用

生产连接 etcd 一般是 HTTPS + 双向 TLS。

**注意**：不同集群（kubeadm/发行版）证书文件名称与用途不同。
- server cert 不一定适合作为 client cert
- kubeadm 常见有 `healthcheck-client.crt` 等 client 用证书

本文后面会给出“如何在 K8s 中安全连接 etcd”的建议写法。

---

## 9. 备份与恢复：正确的快照、恢复与灾备演练

### 9.1 快照备份（最重要的一条）

etcd 的权威备份方式是：

```bash
ETCDCTL_API=3 etcdctl snapshot save snapshot.db
ETCDCTL_API=3 etcdctl snapshot status snapshot.db -w table
```

生产环境通常还需要带 TLS 参数。

### 9.2 恢复的工程要点

- 恢复本质是“用快照重建数据目录”，通常需要停服
- 多节点恢复需要正确指定 name/initial-cluster 等参数
- 做灾备演练时，一定要验证：
  - 集群可用
  - revision 推进正常
  - client/watch 行为正常

---

## 10. 生产运维：告警、compact/defrag、关键参数与排障套路

### 10.1 NOSPACE 告警与处理

当 backend 达到配额，写入会失败：

- 现象：`mvcc: database space exceeded`
- 告警：`NOSPACE`

处理步骤（正确顺序）：

1) 获取当前 revision
2) compact 到该 revision（或略小一点的 revision）
3) defrag
4) alarm disarm

### 10.2 自动压缩（auto-compaction）

生产建议开启自动压缩，避免历史无限增长。

```bash
# 保留 1 小时历史
--auto-compaction-retention=1h

# 或按 revision 保留最近 N 个版本
--auto-compaction-mode=revision
--auto-compaction-retention=1000
```

### 10.3 关键参数清单（只列工程上常讨论的）

| 参数 | 作用 | 工程含义 |
|---|---|---|
| --quota-backend-bytes | backend 配额 | 防止无限增长把盘打爆 |
| --auto-compaction-* | 自动压缩 | 控制历史版本保留 |
| --snapshot-count | 触发 snapshot 的写入次数 | 控制日志长度与恢复速度 |
| --heartbeat-interval / --election-timeout | Raft 心跳与选举 | 网络抖动时尤其敏感 |

### 10.4 排障套路（建议你背下来）

- member 是否齐全：`member list`
- endpoint 是否健康：`endpoint health`
- leader 是否频繁切换：看 metrics
- 写入是否被配额阻断：`alarm list`
- 盘 IO 是否抖动：关注 wal fsync 延迟

---

## 11. Kubernetes 场景：如何安全地接触 K8s etcd

### 11.1 不要“直接改 /registry”

你可以读、可以备份，但不要直接删除/写 /registry 下的 key。
K8s 状态机与缓存层（apiserver/controller）会因此产生不可预期的问题。

### 11.2 kubeadm 集群里如何进入 etcd

```bash
kubectl -n kube-system exec -it etcd-<node-name> -- sh
```

然后通常可以用容器内的证书连接本机 etcd。
**证书路径与用途以你集群实际为准**。

示例（仅示意，证书文件名需要按实际调整）：

```bash
export ETCDCTL_API=3
etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint health
```

---

## 12. 命令速查（只保留高频且不误导的）

### 12.1 基础 KV

```bash
ETCDCTL_API=3 etcdctl put <key> <value>
ETCDCTL_API=3 etcdctl get <key>
ETCDCTL_API=3 etcdctl get --prefix <prefix>
ETCDCTL_API=3 etcdctl del <key>
ETCDCTL_API=3 etcdctl del --prefix <prefix>
```

### 12.2 watch

```bash
ETCDCTL_API=3 etcdctl watch <key>
ETCDCTL_API=3 etcdctl watch --prefix <prefix>
```

### 12.3 集群健康与成员

```bash
ETCDCTL_API=3 etcdctl endpoint health
ETCDCTL_API=3 etcdctl endpoint status -w table
ETCDCTL_API=3 etcdctl member list -w table
```

### 12.4 压缩与碎片整理

```bash
# 获取 revision（示例：需要 jq）
rev=$(ETCDCTL_API=3 etcdctl endpoint status -w json | jq '.[0].Status.header.revision')

ETCDCTL_API=3 etcdctl compact $rev
ETCDCTL_API=3 etcdctl defrag
ETCDCTL_API=3 etcdctl alarm list
ETCDCTL_API=3 etcdctl alarm disarm
```

### 12.5 备份恢复

```bash
ETCDCTL_API=3 etcdctl snapshot save snapshot.db
ETCDCTL_API=3 etcdctl snapshot status snapshot.db -w table
ETCDCTL_API=3 etcdctl snapshot restore snapshot.db --data-dir=/path/to/dir
```

---

## 总结：你真正需要掌握的 10 句话

1. etcd 是一致性存储，不是缓存。
2. 写请求一定走 leader，多数派提交才算成功。
3. 读有两种语义：线性一致读更慢但更“真实”。
4. revision 是全局提交号，watch/list 本质围绕它运转。
5. watch 会因为 compaction 断流，必须实现 list+watch 续接。
6. WAL/snapshot/backend 三件套决定了性能、恢复与空间占用。
7. 空间回收必须 compact 后 defrag。
8. 3 节点是生产基线，SSD 与网络稳定性比“多给 CPU”更重要。
9. snapshot 是权威备份方式，恢复要演练。
10. 在 K8s 里不要直接改 /registry，只做备份与诊断。

---

**版本信息**：
- 文档版本：v2.0（深度重构）
- 创建日期：2026-01-16
- 更新日期：2026-01-18
- 适用对象：偏工程/偏生产（B）

---

## 参考资料

- etcd 官方文档：https://etcd.io/docs/
- Raft 可视化与论文解读
- Kubernetes 文档：API Server 存储与一致性
