# 06 - 高可用与运维：让 apiserver 在生产环境里“跑得久、扛得住”

> 目标：从“如何做 HA”到“如何压住负载、减少故障扩散”，给出一套能落地的原则与检查点。

## 训练营要点（提炼总结）

训练营在这一部分强调：

- kube-apiserver 本质是**无状态的 REST Server**，因此天然适合水平扩展
- 多副本 apiserver 需要在前面加负载均衡（LB）
- 集群规模增长会显著提高 apiserver 的 CPU/内存压力，需要提前做容量规划
- 合理使用：
  - 并发限制（inflight）
  - watch cache
  - 客户端长连接（ListWatch/Informer）
  - APF（优先级与公平）

## 1) 高可用架构：无状态 + LB

典型架构（简化）：

```
        +------------------+
        |   Load Balancer  |
        +--------+---------+
                 |
   +-------------+--------------+
   |                            |
+--v-----------+         +------v--------+
| kube-apiserver|         | kube-apiserver|
|   instance A  |         |  instance B   |
+--+-----------+         +------+--------+
   |                            |
   +-------------+--------------+
                 |
            +----v----+
            |  etcd   |
            +---------+
```

关键点：
- apiserver 无状态：扩缩容主要看 CPU/内存/连接数
- etcd 才是状态核心：etcd 的稳定性决定控制面稳定性
- LB 入口：对外部用户/客户端建议永远走 LB

## 2) 资源规划：不要把 apiserver 当“轻量服务”

训练营明确提醒：
- 节点数增长 → apiserver CPU/内存开销增长
- CPU 太少：处理变慢，排队变长
- 内存太少：pod 被 OOMKill，服务直接不可用

**经验化建议**：
- 控制面节点给 apiserver 预留“增长空间”，不要只按当前规模配置

## 3) 速率限制：保护 apiserver，也保护外部依赖

训练营提到：
- `--max-requests-inflight` / `--max-mutating-requests-inflight` 可以限制并行处理请求数
- 配太低：经常拒绝（客户端大量失败）
- 配太高：apiserver 可能因为占用过多内存被杀

更关键的一句话：
- **客户端收到拒绝后必须退避重试**，无间隔重试只会雪上加霜

此外训练营还提到一个“生产坑”：
- 外部认证（比如 Keystone）如果挂了/慢了，K8s 会不断重试，可能把认证系统压死，导致认证系统无法恢复

对应到你的实验：
- `labs/04-authn-webhook` 就是典型的“外部认证服务依赖”案例

## 4) watch cache：把热读从 etcd 前挪开

训练营提到：
- apiserver 默认会对对象做缓存
- `--watch-cache-sizes` 可以为热点资源配置更合适的缓存大小

理解方式：
- etcd 更适合做强一致存储
- apiserver cache 更适合做“读路径加速”，减少 etcd 压力

客户端最佳实践（训练营强调）：
- list 请求尽量带 `resourceVersion=0`，从 cache 读
- 避免不带 resourceVersion 导致“直打 etcd”

## 5) 客户端长连接：Informer 比轮询更“省命”

训练营给的建议非常实用：
- 大规模场景下，尽量用 ListWatch/Informer 监听变化
- 避免高频全量 list
- 同一应用里多个 informer 可以合并，减少长连接数

一句话：
- **轮询是“不断问你在不在”；watch 是“你变了告诉我”。**

## 6) 访问策略：外部走 LB，内部尽量走稳定入口

训练营的建议可以浓缩为：
- 外部用户/管理员：优先 LB
- LB 故障时：管理员再直连 apiserver IP 做应急

## 7) 与本仓库实践的对应关系

- 认证链路外部依赖：
  - [Lab 04 Token Webhook](labs/04-authn-webhook/README.md)

- 准入链路外部依赖（会卡写请求）：
  - [Lab 05 MutatingWebhook](labs/05-mutatingwebhook/README.md)

- 资源配额与多租户治理的一部分：
  - [Lab 06 ResourceQuota](labs/06-resourcequota/README.md)

## 自测问题

1. 为什么说 apiserver 无状态？无状态带来的 HA 优势是什么？
2. webhook（认证/准入）慢了会发生什么？为什么它会“放大”故障？
3. Informer/Watch 为什么能减少 apiserver 压力？

---

**版本信息**：
- 文档版本：v1.0
- 创建日期：2026-01-18

---

**上一篇**：[05 限流与 APF](05-rate-limit-and-apf.md)  
**返回目录**：[README](README.md)

