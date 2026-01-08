# Exporter 详解：监控数据的"翻译官"

> 🎯 **一句话精华**：Exporter 就是把各种系统的"方言"翻译成 Prometheus 能听懂的"普通话"——没有它，Prometheus 就是个"聋子"！

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Prometheus 只认识一种"语言"（Prometheus 格式）
但 Linux、MySQL、Redis 等系统各说各的"方言"

Exporter 就是翻译官：
- Linux 说："我的 CPU 使用率是 45%"
- Exporter 翻译成：node_cpu_usage 0.45
- Prometheus："哦，我懂了！"
```

**适合谁学**：需要扩展监控范围的运维/开发人员
**不适合谁**：只使用现有 Dashboard 的用户

---

## 二、开场故事：联合国大会的翻译官

> 想象一下联合国大会的场景：
> 
> 🇺🇸 美国代表说英语
> 🇨🇳 中国代表说中文
> 🇫🇷 法国代表说法语
> 🇯🇵 日本代表说日语
> 
> 如果没有翻译官，大家根本无法交流！
> 
> 在监控世界里：
> 🖥️ Linux 服务器有自己的指标格式
> 🐬 MySQL 有自己的状态变量
> 🔴 Redis 有自己的 INFO 命令
> ☸️ Kubernetes 有自己的 API
> 
> Exporter 就是这些系统的"翻译官"，把它们的数据翻译成 Prometheus 能理解的格式！

---

## 三、核心概念速查表

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| Exporter | 指标采集器 | 翻译官 | 把系统数据翻译成 Prometheus 格式 |
| /metrics | 指标暴露端点 | 菜单 | 告诉 Prometheus "我有这些指标" |
| Scrape | 抓取 | 点菜 | Prometheus 定期来"点菜" |
| Target | 抓取目标 | 餐厅 | Prometheus 要去的"餐厅" |

---

## 四、Exporter 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                    Exporter 工作流程                             │
│                                                                  │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐│
│  │   Target    │         │  Exporter   │         │  Prometheus ││
│  │  (应用/系统) │ ───────▶│ (采集指标)   │ ◀───────│  (抓取指标)  ││
│  └─────────────┘         └─────────────┘         └─────────────┘│
│                                │                                 │
│                                ▼                                 │
│                           /metrics                               │
│                          (HTTP 端点)                             │
│                                                                  │
│  流程解读：                                                       │
│  1. Exporter 连接目标系统，采集原始数据                           │
│  2. Exporter 把数据转换成 Prometheus 格式                        │
│  3. Exporter 在 /metrics 端点暴露数据                            │
│  4. Prometheus 定期来 /metrics 抓取数据                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 五、常用 Exporter 详解

### 5.1 Node Exporter（节点监控）

**一句话是什么**：采集 Linux 服务器的硬件和操作系统指标

**生活化比喻**：
```
Node Exporter 就像服务器的"体检医生"：
- 量体温（CPU 温度）
- 测血压（内存使用）
- 查心跳（磁盘 IO）
- 看血管（网络流量）
- 检查骨骼（文件系统）
```

**部署方式**：DaemonSet（每个节点一个）

**主要指标**：

| 指标名称 | 说明 | 常用查询 |
|---------|------|---------|
| `node_cpu_seconds_total` | CPU 使用时间 | `rate(node_cpu_seconds_total{mode="idle"}[5m])` |
| `node_memory_MemAvailable_bytes` | 可用内存 | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes` |
| `node_filesystem_avail_bytes` | 磁盘可用空间 | `node_filesystem_avail_bytes{mountpoint="/"}` |
| `node_network_receive_bytes_total` | 网络接收字节 | `rate(node_network_receive_bytes_total[5m])` |
| `node_load1` | 1分钟负载 | `node_load1` |

**实用 PromQL**：

```promql
# CPU 使用率
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 内存使用率
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 磁盘使用率
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# 网络带宽（MB/s）
rate(node_network_receive_bytes_total{device="eth0"}[5m]) / 1024 / 1024
```

---

### 5.2 Kube-State-Metrics（K8s 状态监控）

**一句话是什么**：采集 Kubernetes 资源的状态信息

**生活化比喻**：
```
如果说 Node Exporter 是"体检医生"
那 Kube-State-Metrics 就是"人口普查员"：
- 统计有多少 Pod（人口数量）
- 记录 Pod 状态（健康/生病）
- 追踪 Deployment 副本数（家庭成员）
- 记录资源配额（户口本信息）
```

**与 cAdvisor 的区别**：

| 对比项 | Kube-State-Metrics | cAdvisor |
|--------|-------------------|----------|
| 采集内容 | K8s 资源状态（元数据） | 容器资源使用（运行时） |
| 数据来源 | Kubernetes API | 容器运行时 |
| 示例指标 | Pod 数量、状态、标签 | CPU、内存、网络使用 |
| 比喻 | 户口本（你是谁） | 体检报告（你怎么样） |

**主要指标**：

| 指标名称 | 说明 | 常用查询 |
|---------|------|---------|
| `kube_pod_status_phase` | Pod 状态 | `kube_pod_status_phase{phase="Running"}` |
| `kube_pod_container_status_restarts_total` | 容器重启次数 | `increase(...[1h])` |
| `kube_deployment_status_replicas_available` | 可用副本数 | 直接查询 |
| `kube_node_status_condition` | 节点状态 | `{condition="Ready",status="true"}` |

**实用 PromQL**：

```promql
# 非 Running 状态的 Pod
kube_pod_status_phase{phase!="Running",phase!="Succeeded"} == 1

# 1小时内重启超过 3 次的 Pod（问题 Pod！）
increase(kube_pod_container_status_restarts_total[1h]) > 3

# Deployment 副本不足
kube_deployment_status_replicas_available < kube_deployment_spec_replicas

# 不健康的节点
kube_node_status_condition{condition="Ready",status="true"} == 0
```

---

### 5.3 cAdvisor（容器监控）

**一句话是什么**：采集容器的资源使用情况（内置在 Kubelet 中）

**主要指标**：

| 指标名称 | 说明 |
|---------|------|
| `container_cpu_usage_seconds_total` | 容器 CPU 使用 |
| `container_memory_working_set_bytes` | 容器内存使用 |
| `container_network_receive_bytes_total` | 容器网络接收 |
| `container_fs_usage_bytes` | 容器文件系统使用 |

**实用 PromQL**：

```promql
# 容器 CPU 使用率（核数）
rate(container_cpu_usage_seconds_total{container!=""}[5m])

# 容器内存使用量（MB）
container_memory_working_set_bytes{container!=""} / 1024 / 1024

# Top 10 内存使用的 Pod
topk(10, sum by(namespace,pod) (container_memory_working_set_bytes{container!=""}))
```

---

## 六、Exporter 分类总览

```
┌─────────────────────────────────────────────────────────────────┐
│                    Exporter 分类                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📦 官方 Exporter                                                │
│  ├── Node Exporter      → 节点硬件/OS 指标                       │
│  ├── Blackbox Exporter  → 黑盒探测（HTTP/TCP/ICMP）              │
│  └── Pushgateway        → 短期任务指标推送                        │
│                                                                  │
│  🔧 K8s 生态 Exporter                                            │
│  ├── Kube-State-Metrics → K8s 资源状态                           │
│  ├── cAdvisor (Kubelet) → 容器资源使用                           │
│  └── Kube-Proxy         → 网络代理指标                           │
│                                                                  │
│  🚀 应用内置 Exporter                                            │
│  ├── Tekton Controller  → Pipeline 执行指标                      │
│  ├── ArgoCD Controller  → GitOps 同步指标                        │
│  └── 自定义应用         → 业务指标                               │
│                                                                  │
│  🗄️ 数据库 Exporter                                              │
│  ├── MySQL Exporter     → MySQL 指标                             │
│  ├── Redis Exporter     → Redis 指标                             │
│  ├── PostgreSQL Exporter → PostgreSQL 指标                       │
│  └── MongoDB Exporter   → MongoDB 指标                           │
│                                                                  │
│  🌐 中间件 Exporter                                              │
│  ├── Nginx Exporter     → Nginx 指标                             │
│  ├── Kafka Exporter     → Kafka 指标                             │
│  └── RabbitMQ Exporter  → RabbitMQ 指标                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 七、如何添加新的 Exporter

### 7.1 基本步骤

```
1. 部署 Exporter（Deployment/DaemonSet）
2. 创建 Service（暴露 /metrics 端点）
3. 创建 ServiceMonitor（告诉 Prometheus 去抓取）
4. 验证（检查 Prometheus Targets）
```

### 7.2 ServiceMonitor 示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-servicemonitor
  namespace: monitoring
  labels:
    release: prometheus  # ⚠️ 必须有这个标签！
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

### 7.3 验证步骤

```bash
# 1. 检查 Exporter Pod 是否运行
kubectl get pods -n <namespace> -l <label>

# 2. 检查 Service 是否存在
kubectl get svc -n <namespace>

# 3. 测试 /metrics 端点
kubectl port-forward -n <namespace> svc/<service-name> 9090:9090
curl http://localhost:9090/metrics

# 4. 检查 Prometheus Targets
# 访问 Prometheus UI → Status → Targets
```

---

## 八、常见问题

### Q1: Exporter 和 ServiceMonitor 的关系？

```
Exporter 暴露 /metrics 端点（像餐厅挂出菜单）
     ↓
ServiceMonitor 告诉 Prometheus 去哪里抓取（像美食地图）
     ↓
Prometheus 根据 ServiceMonitor 配置抓取指标（像食客去吃饭）
```

### Q2: 为什么有些指标抓不到？

**检查清单**：
1. ✅ Exporter Pod 是否运行？
2. ✅ Service 是否正确指向 Exporter？
3. ✅ ServiceMonitor 标签是否匹配？
4. ✅ ServiceMonitor 是否有 `release: prometheus` 标签？

### Q3: 如何选择合适的 Exporter？

```
监控 Linux 服务器 → Node Exporter
监控 K8s 资源状态 → Kube-State-Metrics
监控容器资源使用 → cAdvisor（内置）
监控 MySQL → MySQL Exporter
监控 Redis → Redis Exporter
监控自定义应用 → 应用内置或自己开发
```

---

## 九、金句收藏

```
"没有 Exporter 的 Prometheus，就像没有眼睛的人——什么都看不见"

"选择 Exporter 就像选翻译：要选懂行的，不然翻译出来的东西没人看得懂"

"Exporter 是监控的第一道关卡，数据质量从这里开始"

"一个好的 Exporter，能让你少写 100 行 PromQL"
```

---

## 十、学习检查清单

- [ ] 理解 Exporter 的作用和工作原理
- [ ] 知道 Node Exporter 和 Kube-State-Metrics 的区别
- [ ] 能部署和配置 ServiceMonitor
- [ ] 能排查 Exporter 不工作的问题
- [ ] 知道如何选择合适的 Exporter

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-08
- 适用环境：kube-prometheus-stack

---

> 📝 **下一篇**：[ServiceMonitor 配置指南](05-servicemonitor-guide.md) - 学习如何添加监控目标
