# PromQL 查询手册：从入门到精通的实战指南

> 🎯 **一句话精华**：PromQL = 指标名 + 标签过滤 + 函数 + 运算符——四大金刚组合，查询天下无敌！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
PromQL 语法复杂，每次都要现查文档？
这个手册收集了最常用的查询，复制粘贴即可使用！
从此告别"这个指标怎么查"的灵魂拷问
```

**适合谁学**：需要查询 Prometheus 指标的运维/开发人员
**不适合谁**：只看 Dashboard 不写查询的用户

---

## 二、PromQL 基础语法

### 2.1 基本结构

**生活化比喻**：
```
PromQL 就像点外卖：
- 指标名 = 店名（我要吃什么）
- 标签 = 筛选条件（要辣的、不要香菜）
- 函数 = 加工方式（打包、切块）
- 运算符 = 组合套餐（A+B、A/B）
```

**基本格式**：
```promql
# 基本格式
metric_name{label1="value1", label2="value2"}

# 示例：查询 idle 模式的 CPU 时间
node_cpu_seconds_total{mode="idle", instance="<node-ip>:9100"}
```

### 2.2 标签匹配

| 操作符 | 含义 | 示例 | 比喻 |
|--------|------|------|------|
| `=` | 精确匹配 | `{job="prometheus"}` | 我就要这个 |
| `!=` | 不等于 | `{job!="prometheus"}` | 除了这个都行 |
| `=~` | 正则匹配 | `{job=~"prom.*"}` | 名字像这样的 |
| `!~` | 正则不匹配 | `{job!~"test.*"}` | 名字不像这样的 |

### 2.3 常用函数速查表

| 函数 | 作用 | 示例 | 一句话记忆 |
|------|------|------|-----------|
| `rate()` | 计算速率 | `rate(http_requests_total[5m])` | 每秒多少个 |
| `increase()` | 计算增量 | `increase(http_requests_total[1h])` | 这段时间增加了多少 |
| `sum()` | 求和 | `sum(http_requests_total)` | 加起来多少 |
| `avg()` | 平均值 | `avg(node_load1)` | 平均多少 |
| `max()` | 最大值 | `max(node_memory_MemTotal_bytes)` | 最大的是谁 |
| `min()` | 最小值 | `min(node_memory_MemAvailable_bytes)` | 最小的是谁 |
| `count()` | 计数 | `count(up)` | 有多少个 |
| `topk()` | Top N | `topk(10, http_requests_total)` | 前 N 名 |
| `bottomk()` | Bottom N | `bottomk(10, http_requests_total)` | 后 N 名 |
| `absent()` | 检测缺失 | `absent(up{job="my-app"})` | 这个存在吗 |

---

## 三、节点监控查询

### 3.1 CPU 相关

```promql
# CPU 使用率（所有节点）
# 解读：100% 减去空闲比例 = 使用比例
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# CPU 使用率（单个节点）
100 - (avg(rate(node_cpu_seconds_total{mode="idle",instance="<node-ip>:9100"}[5m])) * 100)

# CPU 各模式使用率（看看 CPU 都在忙什么）
sum by(mode) (rate(node_cpu_seconds_total[5m])) * 100

# 系统负载（1/5/15 分钟）
node_load1   # 1分钟负载
node_load5   # 5分钟负载
node_load15  # 15分钟负载

# 负载与 CPU 核数比值（>1 说明过载）
node_load1 / count by(instance) (node_cpu_seconds_total{mode="idle"})
```

**金句**：
```
"CPU 使用率看 idle，负载看 load1"
"load1 > CPU核数 = 排队等待 = 该加机器了"
```

### 3.2 内存相关

```promql
# 内存使用率（最常用）
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 内存使用量（GB）
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024 / 1024 / 1024

# 可用内存（GB）
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# 总内存（GB）
node_memory_MemTotal_bytes / 1024 / 1024 / 1024

# 缓存内存（GB）
node_memory_Cached_bytes / 1024 / 1024 / 1024

# Swap 使用率（Swap 用多了说明内存不够）
(1 - node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes) * 100
```

**金句**：
```
"内存看 Available，不是 Free"
"Swap 用起来了 = 内存告急 = 该加内存了"
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

# 磁盘 IOPS（每秒读写次数）
rate(node_disk_reads_completed_total[5m]) + rate(node_disk_writes_completed_total[5m])

# inode 使用率（别忘了这个隐形杀手！）
(1 - node_filesystem_files_free / node_filesystem_files) * 100
```

**金句**：
```
"磁盘满了看空间，空间够了看 inode"
"inode 用完 = 文件创建失败 = 运维噩梦"
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

# 容器 CPU 使用率（相对于 limit，百分比）
rate(container_cpu_usage_seconds_total{container!=""}[5m]) 
/ on(namespace,pod,container) 
kube_pod_container_resource_limits{resource="cpu"} * 100

# 容器 CPU 使用率（相对于 request，百分比）
rate(container_cpu_usage_seconds_total{container!=""}[5m]) 
/ on(namespace,pod,container) 
kube_pod_container_resource_requests{resource="cpu"} * 100

# CPU 被限流的时间比例（重要！）
rate(container_cpu_cfs_throttled_seconds_total[5m]) 
/ rate(container_cpu_usage_seconds_total[5m]) * 100

# Top 10 CPU 使用的 Pod
topk(10, sum by(namespace,pod) (rate(container_cpu_usage_seconds_total{container!=""}[5m])))

# 按命名空间汇总 CPU 使用
sum by(namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
```

**金句**：
```
"CPU 被限流 = 应用变慢 = 该加 limit 了"
"throttled 比例高 = CPU 不够用"
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

**金句**：
```
"OOM 看 working_set_bytes，不是 usage_bytes"
"内存超 90% = OOM 倒计时"
```

### 4.3 Pod 状态相关

```promql
# 所有 Pod 状态分布
sum by(phase) (kube_pod_status_phase)

# 非 Running 状态的 Pod（问题 Pod）
kube_pod_status_phase{phase!="Running",phase!="Succeeded"} == 1

# 未就绪的 Pod
kube_pod_status_ready{condition="true"} == 0

# CrashLoopBackOff 的 Pod（崩溃循环）
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

# 副本不足的 Deployment（有问题！）
kube_deployment_status_replicas_available < kube_deployment_spec_replicas

# Deployment 更新状态（正在更新中）
kube_deployment_status_observed_generation != kube_deployment_metadata_generation
```

### 5.3 资源配额

```promql
# 命名空间 CPU 请求总量
sum by(namespace) (kube_pod_container_resource_requests{resource="cpu"})

# 命名空间内存请求总量
sum by(namespace) (kube_pod_container_resource_requests{resource="memory"})

# 没有设置 limit 的容器（危险！）
kube_pod_container_info unless on(namespace,pod,container) kube_pod_container_resource_limits

# 资源配额使用率
kube_resourcequota{type="used"} / kube_resourcequota{type="hard"} * 100
```

---

## 六、告警相关查询

```promql
# 当前触发的告警数量
count(ALERTS{alertstate="firing"})

# 按严重程度统计告警
count by(severity) (ALERTS{alertstate="firing"})

# 特定告警是否触发
ALERTS{alertname="NodeHighCPUUsage",alertstate="firing"}

# Pending 状态的告警（即将触发）
count(ALERTS{alertstate="pending"})
```

---

## 七、Prometheus 自身监控

```promql
# 抓取目标状态（1=正常，0=异常）
up

# 抓取失败的目标
up == 0

# 抓取延迟（秒）
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

## 八、常用聚合操作

### 8.1 按标签聚合

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

### 8.2 时间范围操作

```promql
# 5 分钟速率（每秒多少）
rate(http_requests_total[5m])

# 1 小时增量（这段时间增加了多少）
increase(http_requests_total[1h])

# 5 分钟平均值
avg_over_time(node_load1[5m])

# 5 分钟最大值
max_over_time(node_load1[5m])

# 5 分钟最小值
min_over_time(node_load1[5m])
```

### 8.3 数学运算

```promql
# 百分比计算
(a / b) * 100

# 单位转换（字节转 GB）
metric_bytes / 1024 / 1024 / 1024

# 四舍五入（保留两位小数）
round(metric, 0.01)

# 绝对值
abs(metric)
```

---

## 九、实用技巧

### 9.1 向量匹配

```promql
# 一对一匹配（两个指标按标签关联）
metric_a / on(label) metric_b

# 一对多匹配
metric_a / on(label) group_left metric_b

# 多对一匹配
metric_a / on(label) group_right metric_b

# 忽略标签匹配
metric_a / ignoring(label) metric_b
```

### 9.2 子查询

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

## 十、常见问题

### Q1: rate() 和 increase() 的区别？

```
rate(): 返回每秒的平均速率
increase(): 返回时间范围内的总增量

举个例子：
rate(http_requests_total[5m]) = 每秒请求数（如 100 req/s）
increase(http_requests_total[5m]) = 5分钟内的总请求数（如 30000 req）

关系：increase ≈ rate × 时间范围（秒）
```

### Q2: 为什么查询结果是空的？

可能原因：
1. 指标名称拼写错误
2. 标签过滤条件太严格
3. 时间范围内没有数据
4. 目标没有被抓取

**调试方法**：
```promql
# 先查看原始指标
metric_name

# 再添加标签过滤
metric_name{label="value"}

# 最后添加函数
rate(metric_name{label="value"}[5m])
```

### Q3: 为什么 rate() 返回空？

`rate()` 需要至少两个数据点才能计算，如果时间范围太短可能没有足够的数据点。

**解决方法**：增加时间范围，如 `[5m]` 改为 `[10m]`

---

## 十一、金句收藏

```
"PromQL 四大金刚：指标名、标签、函数、运算符"

"rate 看速率，increase 看增量"

"by 是保留，without 是排除"

"调试 PromQL：先裸查，再加标签，最后加函数"

"查不到数据？先检查指标名，再检查标签，最后检查时间范围"
```

---

## 十二、学习检查清单

- [ ] 理解 PromQL 基本结构（指标名 + 标签 + 函数）
- [ ] 掌握标签匹配操作符（=、!=、=~、!~）
- [ ] 会用 rate() 和 increase()
- [ ] 会用聚合函数（sum、avg、max、min）
- [ ] 会用 by 和 without 进行分组
- [ ] 能查询节点 CPU、内存、磁盘使用率
- [ ] 能查询 Pod 状态和资源使用

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- 适用环境：Prometheus 2.x / 3.x

---

> 📝 **系列导航**：
> - 上一篇：[Pod 监控机制](08-pod-monitoring.md)
> - 下一篇：[添加监控目标指南](guides/add-servicemonitor.md)
