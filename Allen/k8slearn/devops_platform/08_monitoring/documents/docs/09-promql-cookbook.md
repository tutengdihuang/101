# PromQL 查询手册

> 📊 常用 PromQL 查询示例集——复制即用

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
PromQL 语法复杂，每次都要现查文档
这个手册收集了最常用的查询，复制粘贴即可使用
```

**一句话精华**：
```
PromQL = 指标名 + 标签过滤 + 函数 + 运算符
```

---

## 二、PromQL 基础语法

### 2.1 基本结构

```promql
# 基本格式
metric_name{label1="value1", label2="value2"}

# 示例
node_cpu_seconds_total{mode="idle", instance="192.168.1.1:9100"}
```

### 2.2 标签匹配

| 操作符 | 含义 | 示例 |
|--------|------|------|
| `=` | 精确匹配 | `{job="prometheus"}` |
| `!=` | 不等于 | `{job!="prometheus"}` |
| `=~` | 正则匹配 | `{job=~"prom.*"}` |
| `!~` | 正则不匹配 | `{job!~"test.*"}` |

### 2.3 常用函数

| 函数 | 作用 | 示例 |
|------|------|------|
| `rate()` | 计算速率 | `rate(http_requests_total[5m])` |
| `increase()` | 计算增量 | `increase(http_requests_total[1h])` |
| `sum()` | 求和 | `sum(http_requests_total)` |
| `avg()` | 平均值 | `avg(node_load1)` |
| `max()` | 最大值 | `max(node_memory_MemTotal_bytes)` |
| `min()` | 最小值 | `min(node_memory_MemAvailable_bytes)` |
| `count()` | 计数 | `count(up)` |
| `topk()` | Top N | `topk(10, http_requests_total)` |
| `bottomk()` | Bottom N | `bottomk(10, http_requests_total)` |
| `absent()` | 检测缺失 | `absent(up{job="my-app"})` |

---

## 三、节点监控查询

### 3.1 CPU 相关

```promql
# CPU 使用率（所有节点）
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# CPU 使用率（单个节点）
100 - (avg(rate(node_cpu_seconds_total{mode="idle",instance="192.168.1.1:9100"}[5m])) * 100)

# CPU 各模式使用率
sum by(mode) (rate(node_cpu_seconds_total[5m])) * 100

# 系统负载
node_load1  # 1分钟
node_load5  # 5分钟
node_load15 # 15分钟

# 负载与 CPU 核数比值
node_load1 / count by(instance) (node_cpu_seconds_total{mode="idle"})
```

### 3.2 内存相关

```promql
# 内存使用率
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 内存使用量（GB）
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024 / 1024 / 1024

# 可用内存（GB）
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# 总内存（GB）
node_memory_MemTotal_bytes / 1024 / 1024 / 1024

# 缓存内存
node_memory_Cached_bytes / 1024 / 1024 / 1024

# Swap 使用率
(1 - node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes) * 100
```

### 3.3 磁盘相关

```promql
# 磁盘使用率（根分区）
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# 磁盘可用空间（GB）
node_filesystem_avail_bytes{mountpoint="/"} / 1024 / 1024 / 1024

# 磁盘总空间（GB）
node_filesystem_size_bytes{mountpoint="/"} / 1024 / 1024 / 1024

# 磁盘 IO 读取速率（MB/s）
rate(node_disk_read_bytes_total[5m]) / 1024 / 1024

# 磁盘 IO 写入速率（MB/s）
rate(node_disk_written_bytes_total[5m]) / 1024 / 1024

# 磁盘 IOPS
rate(node_disk_reads_completed_total[5m]) + rate(node_disk_writes_completed_total[5m])

# inode 使用率
(1 - node_filesystem_files_free / node_filesystem_files) * 100
```

### 3.4 网络相关

```promql
# 网络接收速率（MB/s）
rate(node_network_receive_bytes_total{device="eth0"}[5m]) / 1024 / 1024

# 网络发送速率（MB/s）
rate(node_network_transmit_bytes_total{device="eth0"}[5m]) / 1024 / 1024

# 网络总带宽（MB/s）
(rate(node_network_receive_bytes_total{device="eth0"}[5m]) + rate(node_network_transmit_bytes_total{device="eth0"}[5m])) / 1024 / 1024

# 网络错误率
rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m])

# 网络丢包率
rate(node_network_receive_drop_total[5m]) + rate(node_network_transmit_drop_total[5m])

# TCP 连接数
node_netstat_Tcp_CurrEstab
```

---

## 四、Pod/容器监控查询

### 4.1 CPU 相关

```promql
# 容器 CPU 使用率（核数）
rate(container_cpu_usage_seconds_total{container!=""}[5m])

# 容器 CPU 使用率（相对于 limit）
rate(container_cpu_usage_seconds_total{container!=""}[5m]) 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="cpu"} * 100

# 容器 CPU 使用率（相对于 request）
rate(container_cpu_usage_seconds_total{container!=""}[5m]) 
/ on(namespace,pod,container) 
kube_pod_container_resource_requests{resource="cpu"} * 100

# CPU 被限流的时间比例
rate(container_cpu_cfs_throttled_seconds_total[5m]) 
/ rate(container_cpu_usage_seconds_total[5m]) * 100

# Top 10 CPU 使用的 Pod
topk(10, sum by(namespace,pod) (rate(container_cpu_usage_seconds_total{container!=""}[5m])))

# 按命名空间汇总 CPU 使用
sum by(namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
```

### 4.2 内存相关

```promql
# 容器内存使用量（MB）
container_memory_working_set_bytes{container!=""} / 1024 / 1024

# 容器内存使用率（相对于 limit）
container_memory_working_set_bytes{container!=""} 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="memory"} * 100

# 容器内存使用率（相对于 request）
container_memory_working_set_bytes{container!=""} 
/ on(namespace,pod,container) 
kube_pod_container_resource_requests{resource="memory"} * 100

# Top 10 内存使用的 Pod
topk(10, sum by(namespace,pod) (container_memory_working_set_bytes{container!=""}))

# 按命名空间汇总内存使用（GB）
sum by(namespace) (container_memory_working_set_bytes{container!=""}) / 1024 / 1024 / 1024

# 即将 OOM 的 Pod（内存使用超过 90%）
container_memory_working_set_bytes{container!=""} 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="memory"} > 0.9
```

### 4.3 网络相关

```promql
# 容器网络接收速率（KB/s）
rate(container_network_receive_bytes_total[5m]) / 1024

# 容器网络发送速率（KB/s）
rate(container_network_transmit_bytes_total[5m]) / 1024

# 按 Pod 汇总网络流量
sum by(namespace,pod) (rate(container_network_receive_bytes_total[5m]) + rate(container_network_transmit_bytes_total[5m]))
```

### 4.4 状态相关

```promql
# 所有 Pod 状态分布
sum by(phase) (kube_pod_status_phase)

# 非 Running 状态的 Pod
kube_pod_status_phase{phase!="Running",phase!="Succeeded"} == 1

# 未就绪的 Pod
kube_pod_status_ready{condition="true"} == 0

# CrashLoopBackOff 的 Pod
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1

# OOM 终止的 Pod
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1

# 1 小时内重启次数
increase(kube_pod_container_status_restarts_total[1h])

# 频繁重启的 Pod（1小时内超过 5 次）
increase(kube_pod_container_status_restarts_total[1h]) > 5

# Pod 运行时长（小时）
(time() - kube_pod_start_time) / 3600
```

---

## 五、Kubernetes 集群查询

### 5.1 节点状态

```promql
# 节点就绪状态
kube_node_status_condition{condition="Ready",status="true"}

# 不健康的节点
kube_node_status_condition{condition="Ready",status="true"} == 0

# 节点数量
count(kube_node_info)

# 节点资源容量
kube_node_status_capacity{resource="cpu"}
kube_node_status_capacity{resource="memory"}

# 节点可分配资源
kube_node_status_allocatable{resource="cpu"}
kube_node_status_allocatable{resource="memory"}
```

### 5.2 Deployment 状态

```promql
# Deployment 副本状态
kube_deployment_status_replicas_available
kube_deployment_status_replicas_unavailable
kube_deployment_spec_replicas

# 副本不足的 Deployment
kube_deployment_status_replicas_available < kube_deployment_spec_replicas

# Deployment 更新状态
kube_deployment_status_observed_generation != kube_deployment_metadata_generation
```

### 5.3 资源配额

```promql
# 命名空间资源使用
sum by(namespace) (kube_pod_container_resource_requests{resource="cpu"})
sum by(namespace) (kube_pod_container_resource_requests{resource="memory"})

# 没有设置 limit 的容器
kube_pod_container_info unless on(namespace,pod,container) kube_pod_container_resource_limits

# 资源配额使用率
kube_resourcequota{type="used"} / kube_resourcequota{type="hard"} * 100
```

---

## 六、CI/CD 监控查询

### 6.1 Tekton 相关

```promql
# Pipeline 执行次数（按状态）
sum by(status) (tekton_pipelinerun_count)

# Pipeline 成功率
sum(tekton_pipelinerun_count{status="success"}) 
/ sum(tekton_pipelinerun_count) * 100

# Pipeline 执行时长（P95）
histogram_quantile(0.95, sum by(le) (rate(tekton_pipelinerun_duration_seconds_bucket[1h])))

# 失败的 Pipeline
tekton_pipelinerun_count{status="failed"} > 0
```

### 6.2 ArgoCD 相关

```promql
# 应用同步状态
argocd_app_info{sync_status="Synced"}
argocd_app_info{sync_status="OutOfSync"}

# 应用健康状态
argocd_app_health_status{health_status="Healthy"}
argocd_app_health_status{health_status="Degraded"}

# 未同步的应用
argocd_app_info{sync_status="OutOfSync"} == 1

# 不健康的应用
argocd_app_health_status{health_status!="Healthy"} == 1

# 同步次数
increase(argocd_app_sync_total[1h])
```

---

## 七、告警相关查询

```promql
# 当前触发的告警数量
count(ALERTS{alertstate="firing"})

# 按严重程度统计告警
count by(severity) (ALERTS{alertstate="firing"})

# 特定告警是否触发
ALERTS{alertname="NodeHighCPUUsage",alertstate="firing"}

# Pending 状态的告警
count(ALERTS{alertstate="pending"})
```

---

## 八、Prometheus 自身监控

```promql
# Prometheus 抓取目标状态
up

# 抓取失败的目标
up == 0

# 抓取延迟
scrape_duration_seconds

# 抓取的样本数
scrape_samples_scraped

# Prometheus 内存使用
process_resident_memory_bytes{job="prometheus"}

# Prometheus 存储的时间序列数
prometheus_tsdb_head_series

# 规则评估延迟
prometheus_rule_evaluation_duration_seconds
```

---

## 九、常用聚合操作

### 9.1 按标签聚合

```promql
# 按命名空间求和
sum by(namespace) (container_memory_working_set_bytes)

# 按节点求和
sum by(node) (container_memory_working_set_bytes)

# 按多个标签聚合
sum by(namespace,pod) (container_memory_working_set_bytes)

# 忽略某些标签聚合
sum without(pod,container) (container_memory_working_set_bytes)
```

### 9.2 时间范围操作

```promql
# 5 分钟速率
rate(http_requests_total[5m])

# 1 小时增量
increase(http_requests_total[1h])

# 5 分钟平均值
avg_over_time(node_load1[5m])

# 5 分钟最大值
max_over_time(node_load1[5m])

# 5 分钟最小值
min_over_time(node_load1[5m])
```

### 9.3 数学运算

```promql
# 百分比计算
(a / b) * 100

# 单位转换（字节转 GB）
metric_bytes / 1024 / 1024 / 1024

# 四舍五入
round(metric, 0.01)

# 绝对值
abs(metric)

# 对数
ln(metric)
log2(metric)
log10(metric)
```

---

## 十、实用技巧

### 10.1 标签操作

```promql
# 添加标签
label_replace(up, "new_label", "$1", "instance", "(.*):.*")

# 连接标签
label_join(up, "new_label", "-", "job", "instance")
```

### 10.2 向量匹配

```promql
# 一对一匹配
metric_a / on(label) metric_b

# 一对多匹配
metric_a / on(label) group_left metric_b

# 多对一匹配
metric_a / on(label) group_right metric_b

# 忽略标签匹配
metric_a / ignoring(label) metric_b
```

### 10.3 子查询

```promql
# 5 分钟内的最大速率
max_over_time(rate(http_requests_total[5m])[1h:1m])

# 1 小时内的平均 CPU 使用率
avg_over_time(
  (100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))
  [1h:5m]
)
```

---

## 十一、常见问题

### Q1: rate() 和 increase() 的区别？

```
rate(): 返回每秒的平均速率
increase(): 返回时间范围内的总增量

rate(http_requests_total[5m]) = 每秒请求数
increase(http_requests_total[5m]) = 5分钟内的总请求数
```

### Q2: 为什么查询结果是空的？

可能原因：
1. 指标名称拼写错误
2. 标签过滤条件太严格
3. 时间范围内没有数据
4. 目标没有被抓取

### Q3: 如何调试 PromQL？

```promql
# 先查看原始指标
metric_name

# 再添加标签过滤
metric_name{label="value"}

# 最后添加函数
rate(metric_name{label="value"}[5m])
```

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- Prometheus 版本：v3.2.1
