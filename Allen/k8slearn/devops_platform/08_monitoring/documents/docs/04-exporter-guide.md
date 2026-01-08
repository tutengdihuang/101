# Exporter 详解

> 📊 指标采集的"翻译官"——把各种系统数据转换成 Prometheus 能理解的语言

## 一、秒懂定位（30秒版）

**这个知识解决什么问题**：
```
Prometheus 只认识一种"语言"（Prometheus 格式）
但 Linux、MySQL、Redis 等系统各说各的"方言"
Exporter 就是翻译官，把各种方言翻译成 Prometheus 能懂的语言
```

**一句话精华**：
```
Exporter = 指标采集器 + 格式转换器 + HTTP 服务器
```

**适合谁学**：需要扩展监控范围的运维/开发人员
**不适合谁**：只需要使用现有 Dashboard 的用户

---

## 二、核心框架（知识骨架）

**核心观点**：
```
没有 Exporter，Prometheus 就是个"聋子"
有了 Exporter，任何系统都能被监控
```

**关键概念速查表**：

| 概念 | 大白话解释 | 生活比喻 | 一句话记忆 |
|------|-----------|---------|-----------|
| Exporter | 指标采集器 | 翻译官 | 把系统数据翻译成 Prometheus 格式 |
| /metrics | 指标暴露端点 | 菜单 | 告诉 Prometheus "我有这些指标" |
| Scrape | 抓取 | 点菜 | Prometheus 定期来"点菜" |
| Target | 抓取目标 | 餐厅 | Prometheus 要去的"餐厅" |

**Exporter 工作流程**：
```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Target    │         │  Exporter   │         │  Prometheus │
│  (应用/系统) │ ───────▶│ (采集指标)   │ ◀───────│  (抓取指标)  │
└─────────────┘         └─────────────┘         └─────────────┘
                              │
                              ▼
                         /metrics
                         (HTTP 端点)
```

---

## 三、监控栈中的 Exporter

### 3.1 Node Exporter（节点监控）

**一句话是什么**：采集 Linux 服务器的硬件和操作系统指标

**生活化比喻**：
```
Node Exporter 就像服务器的"体检医生"
- 量体温（CPU 温度）
- 测血压（内存使用）
- 查心跳（磁盘 IO）
- 看血管（网络流量）
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

### 3.2 Kube-State-Metrics（K8s 状态监控）

**一句话是什么**：采集 Kubernetes 资源的状态信息

**生活化比喻**：
```
如果说 Node Exporter 是"体检医生"
那 Kube-State-Metrics 就是"人口普查员"
- 统计有多少 Pod（人口数量）
- 记录 Pod 状态（健康/生病）
- 追踪 Deployment 副本数（家庭成员）
```

**与 cAdvisor 的区别**：

| 对比项 | Kube-State-Metrics | cAdvisor |
|--------|-------------------|----------|
| 采集内容 | K8s 资源状态（元数据） | 容器资源使用（运行时） |
| 数据来源 | Kubernetes API | 容器运行时 |
| 示例指标 | Pod 数量、状态、标签 | CPU、内存、网络使用 |
| 比喻 | 户口本 | 体检报告 |

**主要指标**：

| 指标名称 | 说明 | 常用查询 |
|---------|------|---------|
| `kube_pod_status_phase` | Pod 状态 | `kube_pod_status_phase{phase="Running"}` |
| `kube_pod_container_status_restarts_total` | 容器重启次数 | `increase(kube_pod_container_status_restarts_total[1h])` |
| `kube_deployment_status_replicas_available` | 可用副本数 | `kube_deployment_status_replicas_available` |
| `kube_node_status_condition` | 节点状态 | `kube_node_status_condition{condition="Ready",status="true"}` |

**实用 PromQL**：

```promql
# 非 Running 状态的 Pod
kube_pod_status_phase{phase!="Running",phase!="Succeeded"} == 1

# 1小时内重启超过 3 次的 Pod
increase(kube_pod_container_status_restarts_total[1h]) > 3

# Deployment 副本不足
kube_deployment_status_replicas_available < kube_deployment_spec_replicas

# 不健康的节点
kube_node_status_condition{condition="Ready",status="true"} == 0
```

---

### 3.3 Kubelet 内置指标

**一句话是什么**：Kubelet 自带的容器运行时指标（包含 cAdvisor）

**主要指标**：

| 指标名称 | 说明 | 来源 |
|---------|------|------|
| `container_cpu_usage_seconds_total` | 容器 CPU 使用 | cAdvisor |
| `container_memory_working_set_bytes` | 容器内存使用 | cAdvisor |
| `kubelet_running_pods` | 运行中的 Pod 数 | Kubelet |
| `kubelet_volume_stats_used_bytes` | 卷使用量 | Kubelet |

---

### 3.4 Tekton Exporter（CI/CD 监控）

**一句话是什么**：采集 Tekton Pipeline 的执行指标

**ServiceMonitor 配置**：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tekton-servicemonitor
  namespace: monitoring
  labels:
    release: prometheus  # 必须！
spec:
  namespaceSelector:
    matchNames:
      - tekton-pipelines
  selector:
    matchLabels:
      app.kubernetes.io/component: controller
      app.kubernetes.io/part-of: tekton-pipelines
  endpoints:
    - port: http-metrics
      interval: 30s
      path: /metrics
```

**主要指标**：

| 指标名称 | 说明 | 常用查询 |
|---------|------|---------|
| `tekton_pipelinerun_duration_seconds` | Pipeline 执行时长 | `histogram_quantile(0.95, ...)` |
| `tekton_pipelinerun_count` | Pipeline 执行次数 | `increase(tekton_pipelinerun_count[1h])` |
| `tekton_taskrun_duration_seconds` | Task 执行时长 | `histogram_quantile(0.95, ...)` |

---

### 3.5 ArgoCD Exporter（GitOps 监控）

**一句话是什么**：采集 ArgoCD 应用同步状态指标

**ServiceMonitor 配置**：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames:
      - argocd
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  endpoints:
    - port: "8082"
      interval: 30s
      path: /metrics
```

**主要指标**：

| 指标名称 | 说明 | 常用查询 |
|---------|------|---------|
| `argocd_app_info` | 应用信息 | `argocd_app_info{sync_status="OutOfSync"}` |
| `argocd_app_health_status` | 健康状态 | `argocd_app_health_status{health_status!="Healthy"}` |
| `argocd_app_sync_total` | 同步次数 | `increase(argocd_app_sync_total[1h])` |

---

## 四、Exporter 分类总结

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
│  └── PostgreSQL Exporter → PostgreSQL 指标                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 五、当前环境 Exporter 状态

访问 Prometheus Targets 页面查看：http://182.42.82.135:30909/targets

| Exporter | 状态 | 端口 | 命名空间 |
|----------|------|------|---------|
| Node Exporter | ✅ UP | 9100 | monitoring |
| Kube-State-Metrics | ✅ UP | 8080 | monitoring |
| Kubelet | ✅ UP | 10250 | kube-system |
| Tekton Controller | ✅ UP | 9090 | tekton-pipelines |
| ArgoCD Controller | ✅ UP | 8082 | argocd |

---

## 六、常见问题

### Q1: Exporter 和 ServiceMonitor 的关系？

```
Exporter 暴露 /metrics 端点
     ↓
ServiceMonitor 告诉 Prometheus 去哪里抓取
     ↓
Prometheus 根据 ServiceMonitor 配置抓取指标
```

### Q2: 为什么有些指标抓不到？

**检查清单**：
1. Exporter Pod 是否运行？
2. Service 是否正确指向 Exporter？
3. ServiceMonitor 标签是否匹配？
4. ServiceMonitor 是否有 `release: prometheus` 标签？

### Q3: 如何添加新的 Exporter？

参考操作指南：[添加监控目标](../guides/add-servicemonitor.md)

---

## 七、金句收藏

```
"没有 Exporter 的 Prometheus，就像没有眼睛的人——什么都看不见"

"选择 Exporter 就像选翻译：要选懂行的，不然翻译出来的东西没人看得懂"
```

---

## 八、延伸资源

- [Prometheus Exporters 官方列表](https://prometheus.io/docs/instrumenting/exporters/)
- [Node Exporter GitHub](https://github.com/prometheus/node_exporter)
- [Kube-State-Metrics GitHub](https://github.com/kubernetes/kube-state-metrics)

---

## 版本信息

- 文档版本：v1.0
- 更新日期：2026-01-05
- 适用环境：kube-prometheus-stack v72.6.2
