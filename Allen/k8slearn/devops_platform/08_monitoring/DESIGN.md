# 监控系统设计方案

> 🎯 为 DevOps 平台构建 Prometheus + Grafana 监控体系

---

## 一、设计目标

### 核心需求

1. **基础设施监控**：Node、Pod 资源使用情况
2. **DevOps 组件监控**：Tekton、ArgoCD、Harbor、Argo Rollouts
3. **业务应用监控**：service-test 微服务的 QPS、延迟、错误率
4. **可视化展示**：Grafana Dashboard
5. **告警通知**：异常时发送通知（可选）

### 设计原则

- **轻量化**：适合学习环境，资源占用小
- **开箱即用**：使用 Helm 一键部署
- **可扩展**：后续可添加更多监控目标

---

## 二、架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           监控系统架构                                    │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        数据采集层                                 │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │   │
│  │  │ Node Exporter│  │kube-state-   │  │ 应用 Metrics │           │   │
│  │  │ (节点指标)    │  │metrics       │  │ (业务指标)   │           │   │
│  │  │              │  │(K8s 对象状态) │  │              │           │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │   │
│  └─────────┼─────────────────┼─────────────────┼───────────────────┘   │
│            │                 │                 │                        │
│            └─────────────────┼─────────────────┘                        │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        数据存储层                                 │   │
│  │                                                                   │   │
│  │                    ┌──────────────┐                              │   │
│  │                    │  Prometheus  │                              │   │
│  │                    │  (时序数据库) │                              │   │
│  │                    └──────┬───────┘                              │   │
│  └───────────────────────────┼─────────────────────────────────────┘   │
│                              │                                          │
│            ┌─────────────────┼─────────────────┐                        │
│            ▼                 ▼                 ▼                        │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        展示/告警层                                │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │   │
│  │  │   Grafana    │  │ AlertManager │  │  Argo Rollouts│           │   │
│  │  │  (可视化)     │  │  (告警通知)   │  │  (自动分析)   │           │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 组件说明

| 组件 | 版本 | 作用 | 资源需求 |
|------|------|------|---------|
| Prometheus | 2.x | 指标采集和存储 | 512Mi-1Gi |
| Grafana | 10.x | 可视化展示 | 256Mi-512Mi |
| Node Exporter | 1.x | 节点指标采集 | 每节点 50Mi |
| kube-state-metrics | 2.x | K8s 对象状态 | 128Mi |
| AlertManager | 0.26.x | 告警管理（可选） | 128Mi |

---

## 三、部署方案

### 方案选择：kube-prometheus-stack

使用 Helm Chart `kube-prometheus-stack`，一键部署所有组件。

**优点**：
- 官方维护，稳定可靠
- 内置 K8s 监控 Dashboard
- 自动配置 ServiceMonitor
- 包含常用告警规则

### 命名空间规划

```
monitoring/
├── prometheus-server          # Prometheus 主服务
├── prometheus-node-exporter   # 节点指标采集（DaemonSet）
├── kube-state-metrics         # K8s 状态指标
├── grafana                    # 可视化
└── alertmanager               # 告警（可选）
```

### 服务暴露

| 服务 | NodePort | 用途 |
|------|----------|------|
| Grafana | 30300 | 监控面板 |
| Prometheus | 30090 | 指标查询（与 ArgoCD 错开） |
| AlertManager | 30093 | 告警管理（可选） |

---

## 四、监控目标

### 4.1 基础设施监控

**节点监控**：
- CPU 使用率
- 内存使用率
- 磁盘使用率
- 网络 I/O

**Pod 监控**：
- Pod 状态（Running/Pending/Failed）
- 容器重启次数
- 资源使用 vs 限制

### 4.2 DevOps 组件监控

| 组件 | 监控指标 | 采集方式 |
|------|---------|---------|
| **Tekton** | Pipeline 执行数、成功率、耗时 | ServiceMonitor |
| **ArgoCD** | 同步状态、应用健康度 | ServiceMonitor |
| **Harbor** | 镜像拉取量、存储使用 | ServiceMonitor |
| **Argo Rollouts** | 发布状态、回滚次数 | ServiceMonitor |

### 4.3 业务应用监控

**service-test 微服务**：
- 请求量（QPS）
- 响应时间（P50/P90/P99）
- 错误率
- 连接数

---

## 五、Grafana Dashboard 规划

### 预置 Dashboard

| Dashboard | 来源 | 用途 |
|-----------|------|------|
| Node Exporter Full | ID: 1860 | 节点详细监控 |
| Kubernetes Cluster | 内置 | K8s 集群概览 |
| Kubernetes Pods | 内置 | Pod 资源监控 |

### 自定义 Dashboard

| Dashboard | 内容 |
|-----------|------|
| DevOps Overview | Tekton + ArgoCD + Harbor 概览 |
| Service Test | 4 个微服务的业务指标 |

---

## 六、资源配置

### 轻量化配置（学习环境）

```yaml
prometheus:
  prometheusSpec:
    retention: 7d              # 数据保留 7 天
    resources:
      requests:
        memory: 512Mi
        cpu: 200m
      limits:
        memory: 1Gi
        cpu: 500m
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi    # 10G 存储

grafana:
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 300m

alertmanager:
  enabled: false               # 暂不启用告警
```

### 资源估算

| 组件 | CPU | 内存 | 存储 |
|------|-----|------|------|
| Prometheus | 200m-500m | 512Mi-1Gi | 10Gi |
| Grafana | 100m-300m | 256Mi-512Mi | - |
| Node Exporter (x3) | 50m x3 | 50Mi x3 | - |
| kube-state-metrics | 50m | 128Mi | - |
| **总计** | ~500m-1000m | ~1.2Gi-2Gi | 10Gi |

---

## 七、部署步骤

### 步骤概览

```
1. 添加 Helm 仓库
2. 创建 monitoring 命名空间
3. 准备 values.yaml 配置
4. Helm 安装 kube-prometheus-stack
5. 验证部署
6. 访问 Grafana
7. 导入自定义 Dashboard（可选）
```

### 详细步骤

**Step 1: 添加 Helm 仓库**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

**Step 2: 创建命名空间**
```bash
kubectl create namespace monitoring
```

**Step 3: 准备配置文件**
```yaml
# values.yaml - 见 install/values.yaml
```

**Step 4: 安装**
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f values.yaml
```

**Step 5: 验证**
```bash
kubectl get pods -n monitoring
```

**Step 6: 访问**
```
Grafana: http://<MASTER_IP>:30300
用户名: admin
密码: admin123
```

---

## 八、目录结构

```
08_monitoring/
├── README.md                    # 快速开始
├── DESIGN.md                    # 本设计文档
├── USER_GUIDE.md                # 用户指南
│
├── install/
│   ├── values.yaml              # Helm values 配置
│   └── install.sh               # 安装脚本
│
├── servicemonitors/
│   ├── tekton-servicemonitor.yaml
│   ├── argocd-servicemonitor.yaml
│   └── harbor-servicemonitor.yaml
│
└── dashboards/
    ├── devops-overview.json     # DevOps 概览
    └── service-test.json        # 业务监控
```

---

## 九、后续扩展

### 阶段 1：基础监控（本次）
- [x] Prometheus + Grafana 部署
- [x] 节点和 Pod 监控
- [x] 内置 Dashboard

### 阶段 2：DevOps 监控（可选）
- [ ] Tekton ServiceMonitor
- [ ] ArgoCD ServiceMonitor
- [ ] 自定义 Dashboard

### 阶段 3：告警通知（可选）
- [ ] 启用 AlertManager
- [ ] 配置告警规则
- [ ] 钉钉/Slack 通知

### 阶段 4：Argo Rollouts 集成（可选）
- [ ] 配置 AnalysisTemplate
- [ ] 基于 Prometheus 指标自动回滚

---

## 十、注意事项

1. **存储**：Prometheus 需要持久化存储，确保有可用的 StorageClass
2. **资源**：监控系统本身也消耗资源，注意集群容量
3. **网络**：确保 Prometheus 能访问各组件的 metrics 端点
4. **安全**：生产环境需要配置认证和 HTTPS

---

## 十一、参考资料

- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 官方文档](https://grafana.com/docs/)
