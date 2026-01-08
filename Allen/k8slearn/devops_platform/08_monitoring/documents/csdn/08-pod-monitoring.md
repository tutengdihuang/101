# Pod 监控机制：深入理解容器监控原理

> 🎯 **一句话精华**：Pod 监控 = cAdvisor（容器资源）+ Kubelet（Pod 状态）+ Kube-State-Metrics（K8s 元数据）——三剑客联手，让 Pod 无处遁形！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Pod 是 K8s 的最小调度单位，了解 Pod 监控机制才能知道：
- 指标从哪里来？
- 为什么有些指标查不到？
- 如何正确设置资源限制？
- OOM 是怎么判断的？
```

**适合谁学**：想深入理解 Pod 监控原理的运维/开发人员
**不适合谁**：只需要看 Dashboard 的用户

---

## 二、Pod 监控架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kubernetes 节点                          │
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │    Pod 1    │    │    Pod 2    │    │    Pod 3    │         │
│  │  ┌───────┐  │    │  ┌───────┐  │    │  ┌───────┐  │         │
│  │  │Container│ │    │  │Container│ │    │  │Container│ │         │
│  │  └───────┘  │    │  └───────┘  │    │  └───────┘  │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│                            ▼                                    │
│                   ┌─────────────────┐                           │
│                   │    cAdvisor     │  ← 容器资源监控            │
│                   │  (内置于 Kubelet) │                          │
│                   └────────┬────────┘                           │
│                            │                                    │
│                            ▼                                    │
│                   ┌─────────────────┐                           │
│                   │     Kubelet     │  ← Pod 生命周期管理        │
│                   │   :10250/metrics │                          │
│                   └────────┬────────┘                           │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Monitoring 命名空间                         │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ Kube-State-     │    │   Prometheus    │                     │
│  │ Metrics         │───▶│   (抓取指标)    │                     │
│  │ (K8s 元数据)    │    │                 │                     │
│  └─────────────────┘    └─────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三、三大数据源对比

| 数据源 | 采集内容 | 指标前缀 | 比喻 |
|--------|---------|---------|------|
| cAdvisor | 容器资源使用（CPU/内存/网络） | `container_` | 体检报告（你现在怎么样） |
| Kubelet | Pod 运行状态、卷使用 | `kubelet_` | 管家日志（你在干什么） |
| Kube-State-Metrics | K8s 资源状态（元数据） | `kube_` | 户口本（你是谁） |

**生活化比喻**：
```
想象你是一个公司的 HR，要了解员工情况：

cAdvisor（体检报告）：
- 这个员工今天精神状态如何？
- 工作效率怎么样？
- 有没有加班？

Kubelet（管家日志）：
- 这个员工今天来上班了吗？
- 在哪个工位？
- 有没有请假？

Kube-State-Metrics（户口本）：
- 这个员工叫什么名字？
- 属于哪个部门？
- 工资是多少？
```

---

## 四、cAdvisor 详解

### 4.1 什么是 cAdvisor

**一句话是什么**：Google 开源的容器监控工具，内置在 Kubelet 中

**主要功能**：
- 自动发现节点上的所有容器
- 采集容器的 CPU、内存、磁盘、网络使用
- 提供历史数据（短期）

### 4.2 CPU 指标

| 指标名称 | 说明 | 单位 |
|---------|------|------|
| `container_cpu_usage_seconds_total` | CPU 使用时间（累计） | 秒 |
| `container_cpu_system_seconds_total` | 系统态 CPU 时间 | 秒 |
| `container_cpu_user_seconds_total` | 用户态 CPU 时间 | 秒 |
| `container_cpu_cfs_throttled_seconds_total` | CPU 被限流时间 | 秒 |

**常用查询**：

```promql
# 容器 CPU 使用率（核数）
rate(container_cpu_usage_seconds_total{container!=""}[5m])

# 容器 CPU 使用率（百分比，相对于 limit）
rate(container_cpu_usage_seconds_total{container!=""}[5m]) 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="cpu"} * 100

# CPU 被限流的比例（重要！）
rate(container_cpu_cfs_throttled_seconds_total[5m]) 
/ rate(container_cpu_usage_seconds_total[5m]) * 100
```

### 4.3 内存指标

| 指标名称 | 说明 | 单位 |
|---------|------|------|
| `container_memory_working_set_bytes` | 工作集内存（常用） | 字节 |
| `container_memory_usage_bytes` | 总内存使用 | 字节 |
| `container_memory_cache` | 缓存内存 | 字节 |
| `container_memory_rss` | 常驻内存 | 字节 |

**内存指标区别（重要！）**：

```
┌─────────────────────────────────────────────────────────────┐
│                    容器内存组成                              │
│                                                             │
│  container_memory_usage_bytes (总使用)                      │
│  ├── container_memory_rss (常驻内存，不可回收)              │
│  ├── container_memory_cache (缓存，可回收)                  │
│  └── container_memory_swap (交换内存)                       │
│                                                             │
│  container_memory_working_set_bytes                         │
│  = usage - inactive_file (活跃使用的内存)                   │
│  ← K8s OOM 判断使用这个指标！                               │
└─────────────────────────────────────────────────────────────┘
```

**常用查询**：

```promql
# 容器内存使用量
container_memory_working_set_bytes{container!=""}

# 容器内存使用率（相对于 limit）
container_memory_working_set_bytes{container!=""} 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="memory"} * 100

# 按命名空间汇总内存使用
sum by(namespace) (container_memory_working_set_bytes{container!=""})
```

---

## 五、Kube-State-Metrics 详解

### 5.1 什么是 Kube-State-Metrics

**一句话是什么**：采集 Kubernetes 资源的状态信息（元数据）

**与 cAdvisor 的区别**：
- cAdvisor：容器"正在用多少资源"（运行时数据）
- KSM：Pod"应该有多少资源"（配置数据）

### 5.2 Pod 状态指标

| 指标名称 | 说明 | 值 |
|---------|------|-----|
| `kube_pod_status_phase` | Pod 阶段 | Pending/Running/Succeeded/Failed/Unknown |
| `kube_pod_status_ready` | Pod 是否就绪 | 0/1 |
| `kube_pod_container_status_running` | 容器是否运行 | 0/1 |
| `kube_pod_container_status_waiting` | 容器是否等待 | 0/1 |
| `kube_pod_container_status_terminated` | 容器是否终止 | 0/1 |

**常用查询**：

```promql
# 非 Running 状态的 Pod
kube_pod_status_phase{phase!="Running",phase!="Succeeded"} == 1

# 未就绪的 Pod
kube_pod_status_ready{condition="true"} == 0

# 等待中的容器（按原因分组）
sum by(reason) (kube_pod_container_status_waiting_reason)
```

### 5.3 Pod 重启指标

| 指标名称 | 说明 |
|---------|------|
| `kube_pod_container_status_restarts_total` | 容器重启次数（累计） |
| `kube_pod_container_status_last_terminated_reason` | 上次终止原因 |

**常用查询**：

```promql
# 1 小时内重启次数
increase(kube_pod_container_status_restarts_total[1h])

# 重启超过 5 次的 Pod
increase(kube_pod_container_status_restarts_total[1h]) > 5

# OOM 终止的容器
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
```

---

## 六、资源限制与监控

### 6.1 资源配置

```yaml
resources:
  requests:
    cpu: 100m        # 请求 0.1 核
    memory: 128Mi    # 请求 128MB
  limits:
    cpu: 500m        # 限制 0.5 核
    memory: 256Mi    # 限制 256MB
```

### 6.2 资源单位

| 资源 | 单位 | 说明 |
|------|------|------|
| CPU | m (毫核) | 1000m = 1 核 |
| 内存 | Mi/Gi | 1Gi = 1024Mi |

### 6.3 监控资源使用

```promql
# CPU 使用率（相对于 request）
rate(container_cpu_usage_seconds_total{container!=""}[5m]) 
/ on(namespace,pod,container) 
kube_pod_container_resource_requests{resource="cpu"} * 100

# 内存使用率（相对于 limit）
container_memory_working_set_bytes{container!=""} 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="memory"} * 100

# 即将 OOM 的 Pod（内存使用超过 90%）
container_memory_working_set_bytes{container!=""} 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="memory"} > 0.9
```

---

## 七、常用 PromQL 查询

### 7.1 Pod 状态查询

```promql
# 所有 Pod 状态分布
sum by(phase) (kube_pod_status_phase)

# 特定命名空间的 Pod 状态
kube_pod_status_phase{namespace="default"}

# 非正常状态的 Pod
kube_pod_status_phase{phase=~"Pending|Failed|Unknown"} == 1
```

### 7.2 资源使用查询

```promql
# Top 10 CPU 使用的 Pod
topk(10, sum by(namespace,pod) (rate(container_cpu_usage_seconds_total{container!=""}[5m])))

# Top 10 内存使用的 Pod
topk(10, sum by(namespace,pod) (container_memory_working_set_bytes{container!=""}))

# 按命名空间汇总资源使用
sum by(namespace) (container_memory_working_set_bytes{container!=""})
```

### 7.3 问题 Pod 查询

```promql
# CrashLoopBackOff 的 Pod
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1

# OOM 的 Pod
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1

# 频繁重启的 Pod
increase(kube_pod_container_status_restarts_total[1h]) > 5
```

---

## 八、常见问题

### Q1: 为什么 container_memory_usage_bytes 和 working_set_bytes 不一样？

```
usage_bytes = rss + cache + swap
working_set_bytes = usage - inactive_file

K8s OOM 判断使用 working_set_bytes
因为 cache 是可以回收的，不应该算作"真正使用"
```

### Q2: 为什么有些 Pod 没有指标？

可能原因：
1. Pod 刚创建，还没被采集
2. Pod 已经终止
3. cAdvisor 采集延迟

### Q3: 如何判断 Pod 是否需要更多资源？

```promql
# CPU 经常被限流 → 需要更多 CPU
rate(container_cpu_cfs_throttled_seconds_total[5m]) > 0

# 内存接近 limit → 需要更多内存
container_memory_working_set_bytes / kube_pod_container_resource_limits{resource="memory"} > 0.8
```

---

## 九、金句收藏

```
"cAdvisor 告诉你容器'正在用多少'，KSM 告诉你容器'应该有多少'"

"OOM 看 working_set_bytes，不是 usage_bytes"

"没有 limit 的 Pod 就像没有刹车的汽车——迟早出事"

"CPU 被限流不会 OOM，但会变慢；内存超限会直接被杀"
```

---

## 十、学习检查清单

- [ ] 理解三大数据源的区别（cAdvisor、Kubelet、KSM）
- [ ] 理解 working_set_bytes 和 usage_bytes 的区别
- [ ] 能查询 Pod 的 CPU 和内存使用率
- [ ] 能找出问题 Pod（CrashLoopBackOff、OOM）
- [ ] 理解资源 request 和 limit 的作用

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- 适用环境：Kubernetes 1.25+

---

> 📝 **下一篇**：[PromQL 查询手册](09-promql-cookbook.md) - 常用查询示例集
