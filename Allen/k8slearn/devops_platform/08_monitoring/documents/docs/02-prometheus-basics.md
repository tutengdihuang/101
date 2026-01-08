# Prometheus 基础

> 一句话概括：Prometheus 是监控界的"数据库"，专门存储和查询时序数据。

## 核心概念

| 概念 | 大白话解释 | 生活比喻 |
|------|-----------|---------|
| **时序数据** | 带时间戳的数据点 | 每天记录的体重 |
| **指标 (Metric)** | 被监控的数据项 | 体温、血压 |
| **标签 (Label)** | 指标的维度 | 左手血压、右手血压 |
| **PromQL** | 查询语言 | SQL 的监控版 |

---

## 一、数据模型

### 1.1 指标格式

Prometheus 的指标格式：

```
<metric_name>{<label_name>=<label_value>, ...} <value> [<timestamp>]
```

**示例**：
```
# 节点 CPU 使用时间
node_cpu_seconds_total{cpu="0", mode="idle"} 12345.67

# Pod 内存使用
container_memory_working_set_bytes{namespace="default", pod="nginx-xxx"} 104857600

# HTTP 请求数
http_requests_total{method="GET", status="200"} 1234
```

### 1.2 指标类型

Prometheus 支持 4 种指标类型：

| 类型 | 说明 | 示例 | 使用场景 |
|------|------|------|---------|
| **Counter** | 只增不减的计数器 | `http_requests_total` | 请求数、错误数 |
| **Gauge** | 可增可减的仪表盘 | `node_memory_MemAvailable_bytes` | 温度、内存使用 |
| **Histogram** | 直方图（分布统计） | `http_request_duration_seconds` | 请求延迟分布 |
| **Summary** | 摘要（分位数统计） | `go_gc_duration_seconds` | P50、P99 延迟 |

**生活比喻**：
```
Counter（计数器）：汽车里程表，只会增加
Gauge（仪表盘）：汽车速度表，可增可减
Histogram（直方图）：考试成绩分布，多少人 60-70 分、70-80 分
Summary（摘要）：考试成绩排名，前 50%、前 99% 的分数线
```

### 1.3 标签 (Labels)

标签用于区分同一指标的不同维度：

```
# 同一个指标，不同标签
node_cpu_seconds_total{cpu="0", mode="idle"}    # CPU 0 的空闲时间
node_cpu_seconds_total{cpu="0", mode="user"}    # CPU 0 的用户态时间
node_cpu_seconds_total{cpu="1", mode="idle"}    # CPU 1 的空闲时间
```

**标签最佳实践**：
- ✅ 使用有意义的标签名：`namespace`、`pod`、`container`
- ✅ 标签值要有限：避免使用 IP、用户 ID 等高基数标签
- ❌ 避免标签过多：每个标签组合都是一个时间序列

---

## 二、PromQL 基础

### 2.1 基本查询

```promql
# 查询指标（返回所有时间序列）
node_cpu_seconds_total

# 使用标签过滤
node_cpu_seconds_total{mode="idle"}

# 多个标签条件
node_cpu_seconds_total{mode="idle", cpu="0"}

# 正则匹配
node_cpu_seconds_total{mode=~"idle|user"}

# 排除匹配
node_cpu_seconds_total{mode!="idle"}
```

### 2.2 时间范围

```promql
# 查询过去 5 分钟的数据（返回范围向量）
node_cpu_seconds_total[5m]

# 查询 1 小时前的数据
node_cpu_seconds_total offset 1h

# 查询 1 小时前的 5 分钟数据
node_cpu_seconds_total[5m] offset 1h
```

### 2.3 常用函数

#### 速率计算

```promql
# rate(): 计算每秒平均增长率（推荐用于 Counter）
rate(node_cpu_seconds_total{mode="idle"}[5m])

# irate(): 计算瞬时增长率（更敏感，但波动大）
irate(node_cpu_seconds_total{mode="idle"}[5m])

# increase(): 计算增长量
increase(http_requests_total[1h])
```

**rate vs irate**：
```
rate()：平滑的平均值，适合告警和趋势分析
irate()：瞬时值，适合实时监控和调试
```

#### 聚合函数

```promql
# sum(): 求和
sum(node_memory_MemAvailable_bytes)

# avg(): 平均值
avg(node_cpu_seconds_total)

# max(): 最大值
max(container_memory_working_set_bytes)

# min(): 最小值
min(container_memory_working_set_bytes)

# count(): 计数
count(kube_pod_info)

# topk(): 前 N 个
topk(5, container_memory_working_set_bytes)

# bottomk(): 后 N 个
bottomk(5, container_memory_working_set_bytes)
```

#### 按标签分组

```promql
# 按 namespace 分组求和
sum by (namespace) (container_memory_working_set_bytes)

# 按 namespace 和 pod 分组
sum by (namespace, pod) (container_memory_working_set_bytes)

# 排除某些标签分组
sum without (instance) (node_cpu_seconds_total)
```

#### 数学运算

```promql
# 加减乘除
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# 百分比计算
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# 比较运算
node_memory_MemAvailable_bytes < 1073741824  # 小于 1GB
```

---

## 三、常用查询示例

### 3.1 CPU 相关

```promql
# 节点 CPU 使用率
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 容器 CPU 使用率
sum by (namespace, pod) (rate(container_cpu_usage_seconds_total[5m])) * 100

# CPU 限流时间
rate(container_cpu_cfs_throttled_seconds_total[5m])
```

### 3.2 内存相关

```promql
# 节点内存使用率
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 容器内存使用量
container_memory_working_set_bytes{container!=""}

# 容器内存使用率（相对于 limit）
container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100
```

### 3.3 磁盘相关

```promql
# 节点磁盘使用率
(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100

# 磁盘 IO 速率
rate(node_disk_read_bytes_total[5m])
rate(node_disk_written_bytes_total[5m])
```

### 3.4 网络相关

```promql
# 网络接收速率
rate(node_network_receive_bytes_total[5m])

# 网络发送速率
rate(node_network_transmit_bytes_total[5m])

# 容器网络流量
rate(container_network_receive_bytes_total[5m])
```

### 3.5 Pod 状态

```promql
# 运行中的 Pod 数量
count(kube_pod_status_phase{phase="Running"})

# 按命名空间统计 Pod 数量
count by (namespace) (kube_pod_info)

# 重启次数
kube_pod_container_status_restarts_total

# CrashLoopBackOff 的 Pod
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}
```

---

## 四、Prometheus 架构

### 4.1 核心组件

```
┌─────────────────────────────────────────────────────────────────┐
│                      Prometheus Server                          │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Retrieval  │  │    TSDB     │  │  HTTP API   │             │
│  │  (抓取)     │  │  (存储)     │  │  (查询)     │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         │                │                │                     │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐             │
│  │ Service     │  │  本地磁盘   │  │  PromQL     │             │
│  │ Discovery   │  │  (7天数据)  │  │  Engine     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 数据抓取流程

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│ Exporter │ ──▶ │ ServiceMonitor│ ──▶ │Prometheus│
│ /metrics │     │ (发现规则)    │     │ (抓取)   │
└──────────┘     └──────────────┘     └──────────┘
```

### 4.3 配置文件结构

```yaml
# prometheus.yml 核心配置
global:
  scrape_interval: 30s      # 抓取间隔
  evaluation_interval: 30s  # 规则评估间隔

# 告警规则文件
rule_files:
  - /etc/prometheus/rules/*.yaml

# 抓取配置
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        regex: node-exporter
        action: keep

# AlertManager 配置
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

---

## 五、Prometheus Operator

### 5.1 什么是 Prometheus Operator

Prometheus Operator 通过 Kubernetes CRD 管理 Prometheus 资源：

| CRD | 作用 | 对应原生配置 |
|-----|------|-------------|
| `Prometheus` | 定义 Prometheus 实例 | prometheus.yml |
| `ServiceMonitor` | 定义抓取目标 | scrape_configs |
| `PodMonitor` | 定义 Pod 抓取 | scrape_configs |
| `PrometheusRule` | 定义告警规则 | rule_files |
| `AlertManager` | 定义 AlertManager | alertmanager.yml |

### 5.2 ServiceMonitor 示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
  labels:
    release: prometheus  # 必须！用于被 Prometheus 发现
spec:
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### 5.3 PrometheusRule 示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-alert-rules
  namespace: monitoring
  labels:
    release: prometheus  # 必须！
spec:
  groups:
    - name: my-rules
      rules:
        - alert: HighCPUUsage
          expr: |
            100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "CPU 使用率过高"
            description: "节点 {{ $labels.instance }} CPU 使用率超过 80%"
```

---

## 六、常见问题

### Q1: rate() 和 irate() 有什么区别？

```
rate()：计算时间范围内的平均增长率
- 更平滑，适合告警和趋势分析
- 示例：rate(http_requests_total[5m])

irate()：计算最后两个数据点的瞬时增长率
- 更敏感，适合实时监控
- 示例：irate(http_requests_total[5m])
```

### Q2: 为什么查询返回 "no data"？

常见原因：
1. 指标名称拼写错误
2. 标签过滤条件太严格
3. 时间范围内没有数据
4. Exporter 没有暴露该指标

### Q3: 如何查看所有可用指标？

```bash
# 访问 Prometheus UI
http://182.42.82.135:30909/graph

# 在查询框输入 {} 可以看到所有指标
# 或者访问 /api/v1/label/__name__/values
curl http://182.42.82.135:30909/api/v1/label/__name__/values
```

---

## 延伸阅读

- [09-PromQL 查询手册](09-promql-cookbook.md) - 更多查询示例
- [05-ServiceMonitor 配置](05-servicemonitor-guide.md) - 添加监控目标
- [07-告警规则编写](07-prometheusrule-guide.md) - 编写告警规则
