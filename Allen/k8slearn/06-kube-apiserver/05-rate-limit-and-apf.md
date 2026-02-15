# 05 - 限流与 APF（API Priority and Fairness）：保护 apiserver 不被打爆

> 目标：把“传统 inflight 限流为什么不够”讲清楚；把 APF 的核心对象讲清楚；最后给你一套可定位/可验证的排障路径。

## 训练营要点（提炼总结）

训练营在限流这一章给了两层框架：

1. **传统限流算法**（固定/滑动窗口、漏斗、令牌桶）——用于理解“限流为什么能保护系统”。
2. **apiserver 实现**：
   - 早期主要靠 inflight 并发限制（粗粒度）
   - 之后引入 **APF（Priority & Fairness）**，实现更细粒度的分类隔离与公平排队

## 1) 限流算法：你可以把它当成“排队规则”

### 固定窗口计数（Fixed Window）
- 在一个固定时间窗内计数
- 超过阈值拒绝
- 问题：窗口边界处可能“突刺”（边界抖动）

### 滑动窗口计数（Sliding Window）
- 将窗口拆成多个小窗
- 更平滑，边界突刺更少
- 代价：实现更复杂

### 漏斗（Leaky Bucket）
- 请求先进入漏斗
- 以恒定速率流出处理
- 超过容量就丢弃
- 特点：强制平滑（对突发不友好）

### 令牌桶（Token Bucket）
- 令牌以恒定速率生成
- 请求到来需消耗令牌
- 允许一定程度突发（桶里有存量）

**一句话记忆**：
- 漏斗：你只能按我规定的速度来
- 令牌桶：平时攒点“通行证”，突发时可以多过几辆车

## 2) apiserver 的粗粒度限流（inflight）

训练营给了两个关键参数：

- `--max-requests-inflight`：non-mutating 请求并发上限（读请求）
- `--max-mutating-requests-inflight`：mutating 请求并发上限（写请求）

这套机制的问题（训练营“传统限流局限性”总结）：
- **粒度粗**：不同用户/不同场景无法区分
- **单队列**：坏客户端可能占满队列，饿死正常请求
- **不公平**：好请求排到队尾
- **无优先级**：关键控制面请求也会被一起限流，导致故障难恢复

## 3) APF：把流量“分舱 + 分级 + 公平排队”

训练营给的 APF 核心一句话：

- **分类（FlowSchema）**：把请求按属性（用户、namespace、资源等）分组
- **优先级（PriorityLevelConfiguration）**：不同优先级隔离并发资源
- **队列与公平（QueueSet + fair queuing）**：同优先级内也避免某个 flow 饿死其他 flow

### 3.1 APF 的两个核心资源对象

#### PriorityLevelConfiguration（PL）
它代表“一个隔离等级”，关键字段：
- 并发份额（assured concurrency shares）
- 排队策略（queuing queues/queueLengthLimit/handSize）

训练营里给了典型 YAML 结构（这里不照抄，只保留语义）：
- `type: Limited` 表示该优先级有并发限制，超出会进入队列
- `queues` 表示队列数量
- `queueLengthLimit` 表示每个队列最大长度

#### FlowSchema（FS）
它负责“匹配请求并把请求分配到某个 PL”。核心字段：
- `matchingPrecedence`：匹配优先级（数值越小越优先）
- `rules`：匹配规则（subjects + resources + verbs…）
- `distinguisherMethod`：如何进一步划分 Flow（按用户/namespace/不区分）

**一句话记忆**：
- FS = 分类规则
- PL = 分级舱位 + 队列配置

### 3.2 同一个 PL 内的公平：为什么不会“一个坏控制器饿死其他控制器”

训练营提到的两个关键机制：

- **Flow Distinguisher**：把同一个 FlowSchema 下的请求进一步分为多个 Flow（比如按 user 或 namespace）
- **Shuffle Sharding**：每个 Flow 只会落到 QueueSet 的一小部分队列，降低相互干扰

这样即使一个客户端疯狂刷请求，它也只会污染部分队列，不会把整个优先级的队列全部堵死。

## 4) 默认优先级（训练营摘要）

训练营列出了默认的关键优先级类别（我按“作用”重述）：
- **system / leader-election**：保证 kubelet、领导选举等关键流量不被打挂
- **workload-high / workload-low**：控制器类请求分层
- **global-default**：普通用户 kubectl 流量
- **exempt**：极少数豁免流量（防止流控配置把 apiserver 完全锁死）

## 5) 调试与验证

训练营给了非常实用的调试入口（原样路径保留，便于你直接验证）：

```sh
kubectl get --raw /debug/api_priority_and_fairness/dump_priority_levels
kubectl get --raw /debug/api_priority_and_fairness/dump_queues
kubectl get --raw /debug/api_priority_and_fairness/dump_requests
```

**定位思路**：
- 看 priority_levels：哪个 PL 在拥塞？并发份额是否不足？
- 看 queues：是否某些队列长度异常？
- 看 requests：哪些请求在排队？来自哪个 FS/flow？

## 实践关联

本模块现有 labs 里，最直接会影响 apiserver 请求压力的点是：
- `labs/04-authn-webhook`：认证 webhook 外部依赖（不可用会导致认证链路抖动）
- `labs/05-mutatingwebhook`：准入 webhook 的延迟/超时会直接影响写请求

建议把“webhook 的 failurePolicy/timeoutSeconds”当作限流的一部分来考虑：
- webhook 太慢 = 等价于把 apiserver 的处理线程卡住
- failurePolicy=Fail + webhook 不可用 = 写请求直接失败

## 自测问题

1. inflight 限流为什么会导致“关键请求也一起被限流”，从而让系统更难恢复？
2. APF 的 FS 和 PL 分别解决了什么问题？
3. Shuffle Sharding 的目的是什么？

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18

---

**上一篇**：[04 准入控制](04-admission-control.md)  
**下一篇**：[06 高可用与运维](06-ha-and-ops.md)

