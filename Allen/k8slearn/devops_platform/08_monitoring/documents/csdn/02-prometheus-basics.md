# Prometheus 从入门到精通：监控界的"瑞士军刀"

> 🎯 **一句话精华**：Prometheus 是监控界的"数据库"，专门存储和查询时序数据——它就像一个永不休息的记录员，把系统的每一个"心跳"都记录下来。

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
你想知道服务器过去一小时的 CPU 使用情况？
你想查询哪个 Pod 内存使用最高？
你想在 CPU 超过 80% 时收到告警？

Prometheus 就是帮你解决这些问题的"时间机器"！
```

**适合谁学**：DevOps 工程师、SRE、运维人员、后端开发
**不适合谁**：只想看 Dashboard 不想了解原理的用户

---

## 二、开场故事：为什么需要时序数据库？

> 想象你是一个健身教练，你需要记录学员的体重变化。
> 
> 如果用普通数据库：
> ```sql
> SELECT weight FROM users WHERE name = '小明';
> -- 结果：75kg（只有最新值）
> ```
> 
> 如果用时序数据库：
> ```
> 小明的体重：
> 1月1日: 80kg
> 1月8日: 78kg
> 1月15日: 76kg
> 1月22日: 75kg
> ```
> 
> 看出区别了吗？时序数据库不仅告诉你"现在是多少"，还能告诉你"过去是多少"、"变化趋势如何"！

**这就是 Prometheus 的价值：记录时间维度的数据，让你能够"穿越时空"查看历史！**

---

## 三、核心概念速查表

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| **时序数据** | 带时间戳的数据点 | 每天记录的体重 | 时间是第一维度 |
| **指标 (Metric)** | 被监控的数据项 | 体温、血压 | 你关心的数字 |
| **标签 (Label)** | 指标的维度 | 左手血压、右手血压 | 同一指标的不同"口味" |
| **PromQL** | 查询语言 | SQL 的监控版 | 问 Prometheus 问题的语言 |

---

## 四、数据模型详解

### 4.1 指标格式

Prometheus 的指标格式就像一个"带标签的数字"：

```
<指标名>{<标签1>=<值1>, <标签2>=<值2>, ...} <数值> [<时间戳>]
```

**生活化比喻**：
```
想象你在记录全班同学的考试成绩：

普通记录：张三 85分
Prometheus 记录：exam_score{name="张三", subject="数学", class="三年级一班"} 85

这样你就能查询：
- 张三的所有科目成绩
- 三年级一班的数学平均分
- 所有人的数学成绩排名
```

**实际示例**：
```promql
# 节点 CPU 使用时间
node_cpu_seconds_total{cpu="0", mode="idle"} 12345.67

# Pod 内存使用
container_memory_working_set_bytes{namespace="default", pod="nginx-xxx"} 104857600

# HTTP 请求数
http_requests_total{method="GET", status="200"} 1234
```

### 4.2 四种指标类型

Prometheus 支持 4 种指标类型，就像 4 种不同的"计量工具"：

| 类型 | 说明 | 生活比喻 | 示例 |
|------|------|---------|------|
| **Counter** | 只增不减的计数器 | 汽车里程表 | `http_requests_total` |
| **Gauge** | 可增可减的仪表盘 | 汽车速度表 | `node_memory_MemAvailable_bytes` |
| **Histogram** | 直方图（分布统计） | 考试成绩分布 | `http_request_duration_seconds` |
| **Summary** | 摘要（分位数统计） | 成绩排名百分位 | `go_gc_duration_seconds` |

**幽默解读**：
```
Counter（计数器）：
  就像你的年龄，只会增加不会减少（除非你是本杰明·巴顿 😄）
  
Gauge（仪表盘）：
  就像你的体重，今天多吃点就涨，明天多运动就降
  
Histogram（直方图）：
  就像考试成绩分布图，告诉你多少人 60-70 分、70-80 分
  
Summary（摘要）：
  就像考试排名，告诉你"前 50% 的分数线是多少"
```

### 4.3 标签的威力

标签是 Prometheus 的"超能力"，让你能从不同维度分析数据：

```promql
# 同一个指标，不同标签 = 不同的时间序列
node_cpu_seconds_total{cpu="0", mode="idle"}    # CPU 0 的空闲时间
node_cpu_seconds_total{cpu="0", mode="user"}    # CPU 0 的用户态时间
node_cpu_seconds_total{cpu="1", mode="idle"}    # CPU 1 的空闲时间
```

**标签最佳实践**：
- ✅ 使用有意义的标签名：`namespace`、`pod`、`container`
- ✅ 标签值要有限：避免使用 IP、用户 ID 等高基数标签
- ❌ 避免标签过多：每个标签组合都是一个时间序列，太多会爆炸！

---

## 五、PromQL 入门

### 5.1 基本查询

PromQL 就像是和 Prometheus 对话的语言：

```promql
# 最简单的查询：直接写指标名
node_cpu_seconds_total

# 加上标签过滤：只看空闲 CPU
node_cpu_seconds_total{mode="idle"}

# 多个标签条件：空闲的 CPU 0
node_cpu_seconds_total{mode="idle", cpu="0"}

# 正则匹配：空闲或用户态
node_cpu_seconds_total{mode=~"idle|user"}

# 排除匹配：除了空闲以外的
node_cpu_seconds_total{mode!="idle"}
```

### 5.2 时间范围查询

```promql
# 查询过去 5 分钟的数据（返回范围向量）
node_cpu_seconds_total[5m]

# 查询 1 小时前的数据
node_cpu_seconds_total offset 1h

# 查询 1 小时前的 5 分钟数据
node_cpu_seconds_total[5m] offset 1h
```

### 5.3 常用函数

#### 速率计算（最常用！）

```promql
# rate(): 计算每秒平均增长率（推荐用于 Counter）
rate(node_cpu_seconds_total{mode="idle"}[5m])

# irate(): 计算瞬时增长率（更敏感，但波动大）
irate(node_cpu_seconds_total{mode="idle"}[5m])

# increase(): 计算增长量
increase(http_requests_total[1h])
```

**rate vs irate 的区别**：
```
rate()：像看股票的周K线，平滑稳定，适合告警
irate()：像看股票的分时图，敏感波动，适合调试

建议：告警用 rate()，调试用 irate()
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

# topk(): 前 N 个（找出"罪魁祸首"）
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

---

## 六、实战查询示例

### 6.1 CPU 相关

```promql
# 节点 CPU 使用率（最常用！）
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 解读：
# 1. node_cpu_seconds_total{mode="idle"} - 获取空闲 CPU 时间
# 2. rate(...[5m]) - 计算 5 分钟内的每秒增长率
# 3. avg by (instance) - 按节点求平均
# 4. * 100 - 转换为百分比
# 5. 100 - ... - 用 100 减去空闲率 = 使用率
```

### 6.2 内存相关

```promql
# 节点内存使用率
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 解读：
# 1. node_memory_MemAvailable_bytes - 可用内存
# 2. node_memory_MemTotal_bytes - 总内存
# 3. 可用/总 = 可用率
# 4. 1 - 可用率 = 使用率
# 5. * 100 = 百分比
```

### 6.3 磁盘相关

```promql
# 节点磁盘使用率
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
```

### 6.4 Pod 状态

```promql
# 运行中的 Pod 数量
count(kube_pod_status_phase{phase="Running"})

# 按命名空间统计 Pod 数量
count by (namespace) (kube_pod_info)

# 重启次数超过 5 次的 Pod
kube_pod_container_status_restarts_total > 5

# CrashLoopBackOff 的 Pod（问题 Pod！）
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}
```

---

## 七、Prometheus 架构

### 7.1 核心组件

```
┌─────────────────────────────────────────────────────────────────┐
│                      Prometheus Server                          │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Retrieval  │  │    TSDB     │  │  HTTP API   │             │
│  │  (抓取模块) │  │  (存储引擎) │  │  (查询接口) │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         │                │                │                     │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐             │
│  │ Service     │  │  本地磁盘   │  │  PromQL     │             │
│  │ Discovery   │  │ (时序数据)  │  │  Engine     │             │
│  │ (服务发现)  │  │             │  │ (查询引擎)  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 数据抓取流程

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│ Exporter │ ──▶ │ ServiceMonitor│ ──▶ │Prometheus│
│ /metrics │     │ (发现规则)    │     │ (抓取)   │
└──────────┘     └──────────────┘     └──────────┘

流程解读：
1. Exporter 暴露 /metrics 端点（像餐厅挂出菜单）
2. ServiceMonitor 告诉 Prometheus 去哪里抓取（像美食地图）
3. Prometheus 定期去抓取指标（像食客定期去吃饭）
```

---

## 八、Prometheus Operator

### 8.1 什么是 Prometheus Operator？

传统方式：手动编辑 prometheus.yml 配置文件
Operator 方式：用 Kubernetes CRD 管理配置

**生活化比喻**：
```
传统方式：自己动手装修房子，改一个插座要拆墙
Operator 方式：请装修公司，说一声"我要加个插座"就行
```

### 8.2 核心 CRD

| CRD | 作用 | 对应原生配置 |
|-----|------|-------------|
| `Prometheus` | 定义 Prometheus 实例 | prometheus.yml |
| `ServiceMonitor` | 定义抓取目标 | scrape_configs |
| `PodMonitor` | 定义 Pod 抓取 | scrape_configs |
| `PrometheusRule` | 定义告警规则 | rule_files |
| `AlertManager` | 定义 AlertManager | alertmanager.yml |

### 8.3 ServiceMonitor 示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
  labels:
    release: prometheus  # ⚠️ 必须！用于被 Prometheus 发现
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

### 8.4 PrometheusRule 示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-alert-rules
  namespace: monitoring
  labels:
    release: prometheus  # ⚠️ 必须！
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

## 九、常见问题

### Q1: rate() 和 irate() 有什么区别？

```
rate()：计算时间范围内的平均增长率
- 更平滑，适合告警和趋势分析
- 示例：rate(http_requests_total[5m])

irate()：计算最后两个数据点的瞬时增长率
- 更敏感，适合实时监控
- 示例：irate(http_requests_total[5m])

记忆口诀：
rate 稳如老狗，irate 敏如兔子
告警用 rate，调试用 irate
```

### Q2: 为什么查询返回 "no data"？

常见原因：
1. 指标名称拼写错误（最常见！）
2. 标签过滤条件太严格
3. 时间范围内没有数据
4. Exporter 没有暴露该指标

排查步骤：
```promql
# 1. 先查看所有指标名
{__name__=~".*cpu.*"}

# 2. 再逐步添加过滤条件
node_cpu_seconds_total
node_cpu_seconds_total{mode="idle"}
node_cpu_seconds_total{mode="idle", instance="xxx"}
```

### Q3: 如何查看所有可用指标？

```bash
# 方法 1：访问 Prometheus UI
# http://<prometheus-ip>:<port>/graph
# 在查询框输入 {} 可以看到所有指标

# 方法 2：通过 API
curl http://<prometheus-ip>:<port>/api/v1/label/__name__/values
```

---

## 十、金句收藏

```
"Prometheus 就像一个永不休息的记录员，把系统的每一个心跳都记录下来"

"rate() 和 irate() 的区别：一个是看周K线，一个是看分时图"

"标签是 Prometheus 的超能力，但用多了会变成负担"

"写 PromQL 就像写 SQL，先跑通再优化"
```

---

## 十一、学习检查清单

- [ ] 理解时序数据的概念
- [ ] 掌握四种指标类型的区别
- [ ] 能写基本的 PromQL 查询
- [ ] 理解 rate() 和 irate() 的区别
- [ ] 能使用聚合函数（sum、avg、max）
- [ ] 理解 ServiceMonitor 的作用

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- Prometheus 版本：v2.x / v3.x

---

> 📝 **下一篇**：[Grafana 基础入门](03-grafana-basics.md) - 学习数据可视化
