# Pod 监控机制

> 🐳 深入理解 Kubernetes 如何监控容器的资源使用

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Pod 是 K8s 的最小调度单位，了解 Pod 监控机制
才能知道：
- 指标从哪里来
- 为什么有些指标查不到
- 如何正确设置资源限制
```

**一句话精华**：
```
Pod 监控 = cAdvisor（容器资源）+ Kubelet（Pod 状态）+ Kube-State-Metrics（K8s 元数据）
```

**适合谁学**：想深入理解 Pod 监控原理的运维/开发人员
**不适合谁**：只需要看 Dashboard 的用户

---

## 二、核心框架（知识骨架）

**Pod 监控架构**：

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

**三大数据源对比**：

| 数据源 | 采集内容 | 指标前缀 | 比喻 |
|--------|---------|---------|------|
| cAdvisor | 容器资源使用（CPU/内存/网络） | `container_` | 体检报告 |
| Kubelet | Pod 运行状态、卷使用 | `kubelet_` | 管家日志 |
| Kube-State-Metrics | K8s 资源状态（元数据） | `kube_` | 户口本 |

---

## 三、cAdvisor 详解

### 3.1 什么是 cAdvisor

**一句话是什么**：Google 开源的容器监控工具，内置在 Kubelet 中

**主要功能**：
- 自动发现节点上的所有容器
- 采集容器的 CPU、内存、磁盘、网络使用
- 提供历史数据（短期）

### 3.2 cAdvisor 主要指标

#### CPU 指标

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

# CPU 被限流的比例
rate(container_cpu_cfs_throttled_seconds_total[5m]) 
/ rate(container_cpu_usage_seconds_total[5m]) * 100
```

#### 内存指标

| 指标名称 | 说明 | 单位 |
|---------|------|------|
| `container_memory_working_set_bytes` | 工作集内存（常用） | 字节 |
| `container_memory_usage_bytes` | 总内存使用 | 字节 |
| `container_memory_cache` | 缓存内存 | 字节 |
| `container_memory_rss` | 常驻内存 | 字节 |

**内存指标区别**：

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

#### 网络指标

| 指标名称 | 说明 | 单位 |
|---------|------|------|
| `container_network_receive_bytes_total` | 接收字节数 | 字节 |
| `container_network_transmit_bytes_total` | 发送字节数 | 字节 |
| `container_network_receive_packets_total` | 接收包数 | 个 |
| `container_network_transmit_packets_total` | 发送包数 | 个 |

**常用查询**：

```promql
# 容器网络接收速率（MB/s）
rate(container_network_receive_bytes_total[5m]) / 1024 / 1024

# 容器网络发送速率（MB/s）
rate(container_network_transmit_bytes_total[5m]) / 1024 / 1024
```

---

## 四、Kube-State-Metrics 详解

### 4.1 什么是 Kube-State-Metrics

**一句话是什么**：采集 Kubernetes 资源的状态信息（元数据）

**与 cAdvisor 的区别**：
- cAdvisor：容器"正在用多少资源"（运行时数据）
- KSM：Pod"应该有多少资源"（配置数据）

### 4.2 主要指标

#### Pod 状态指标

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

#### Pod 重启指标

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

#### 资源配置指标

| 指标名称 | 说明 |
|---------|------|
| `kube_pod_container_resource_requests` | 资源请求值 |
| `kube_pod_container_resource_limits` | 资源限制值 |

**常用查询**：

```promql
# 容器 CPU 请求
kube_pod_container_resource_requests{resource="cpu"}

# 容器内存限制
kube_pod_container_resource_limits{resource="memory"}

# 没有设置 limit 的容器
kube_pod_container_info unless on(namespace,pod,container) kube_pod_container_resource_limits
```

---

## 五、健康检查机制

### 5.1 三种探针

| 探针类型 | 作用 | 失败后果 |
|---------|------|---------|
| Liveness Probe | 检测容器是否存活 | 重启容器 |
| Readiness Probe | 检测容器是否就绪 | 从 Service 移除 |
| Startup Probe | 检测容器是否启动完成 | 阻止其他探针 |

### 5.2 探针配置示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: my-app:latest
    
    # 存活探针
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30    # 启动后等待 30s
      periodSeconds: 10          # 每 10s 检查一次
      timeoutSeconds: 5          # 超时 5s
      failureThreshold: 3        # 连续失败 3 次才重启
    
    # 就绪探针
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 3
    
    # 启动探针（适用于启动慢的应用）
    startupProbe:
      httpGet:
        path: /startup
        port: 8080
      failureThreshold: 30       # 最多等待 30*10=300s
      periodSeconds: 10
```

### 5.3 探针类型

```yaml
# HTTP 探针
httpGet:
  path: /health
  port: 8080
  httpHeaders:
    - name: Custom-Header
      value: value

# TCP 探针
tcpSocket:
  port: 3306

# 命令探针
exec:
  command:
    - cat
    - /tmp/healthy
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

## 八、告警规则示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-alerting-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: pod.rules
      rules:
        # Pod 内存使用率过高
        - alert: PodMemoryUsageHigh
          expr: |
            container_memory_working_set_bytes{container!=""} 
            / on(namespace,pod,container) 
            kube_pod_container_resource_limits{resource="memory"} > 0.85
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod 内存使用率过高"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 内存使用率超过 85%"
        
        # Pod CPU 被限流
        - alert: PodCPUThrottling
          expr: |
            rate(container_cpu_cfs_throttled_seconds_total[5m]) 
            / rate(container_cpu_usage_seconds_total[5m]) > 0.25
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod CPU 被限流"
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} CPU 限流比例超过 25%"
```

---

## 九、常见问题

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

## 十、金句收藏

```
"cAdvisor 告诉你容器'正在用多少'，KSM 告诉你容器'应该有多少'"

"OOM 看 working_set_bytes，不是 usage_bytes"

"没有 limit 的 Pod 就像没有刹车的汽车——迟早出事"
```

---

## 十一、延伸资源

- [cAdvisor GitHub](https://github.com/google/cadvisor)
- [Kube-State-Metrics GitHub](https://github.com/kubernetes/kube-state-metrics)
- [Kubernetes 资源管理](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- 适用环境：Kubernetes 1.28+
