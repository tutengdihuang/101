# Design Document

## Overview

本设计文档描述如何扩展现有的 Prometheus + Grafana 监控系统，为 DevOps 平台的 Tekton CI 和 ArgoCD CD 组件配置监控采集，并创建统一的可视化 Dashboard。

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      DevOps 监控扩展架构                                  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     数据采集层 (ServiceMonitor)                   │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │   │
│  │  │   Tekton     │  │   ArgoCD     │  │   现有组件    │           │   │
│  │  │  Controller  │  │   Server     │  │ (Node/Pod)   │           │   │
│  │  │  :9090/metrics│  │ :8083/metrics│  │              │           │   │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │   │
│  │         │                 │                 │                    │   │
│  │  ┌──────▼───────┐  ┌──────▼───────┐        │                    │   │
│  │  │ tekton-      │  │ argocd-      │        │                    │   │
│  │  │ servicemonitor│  │ servicemonitor│        │                    │   │
│  │  └──────┬───────┘  └──────┬───────┘        │                    │   │
│  └─────────┼─────────────────┼────────────────┼────────────────────┘   │
│            │                 │                │                        │
│            └─────────────────┼────────────────┘                        │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        Prometheus                                │   │
│  │                    (monitoring namespace)                        │   │
│  └───────────────────────────┬─────────────────────────────────────┘   │
│                              │                                          │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         Grafana                                  │   │
│  │              ┌─────────────────────────────┐                    │   │
│  │              │   DevOps Overview Dashboard  │                    │   │
│  │              │  ┌─────────┐ ┌─────────┐    │                    │   │
│  │              │  │ Tekton  │ │ ArgoCD  │    │                    │   │
│  │              │  │ Metrics │ │ Metrics │    │                    │   │
│  │              │  └─────────┘ └─────────┘    │                    │   │
│  │              └─────────────────────────────┘                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Tekton ServiceMonitor

**目标**: 采集 Tekton Controller 暴露的 Prometheus 指标

**配置要点**:
- 命名空间: `tekton-pipelines`
- 端口: `9090` (metrics)
- 标签选择器: `app.kubernetes.io/component=controller`

**关键指标**:
| 指标名 | 类型 | 说明 |
|--------|------|------|
| `tekton_pipelines_controller_pipelinerun_duration_seconds` | Histogram | PipelineRun 执行时长 |
| `tekton_pipelines_controller_pipelinerun_count` | Counter | PipelineRun 总数 |
| `tekton_pipelines_controller_taskrun_duration_seconds` | Histogram | TaskRun 执行时长 |
| `tekton_pipelines_controller_running_pipelineruns_count` | Gauge | 正在运行的 PipelineRun 数量 |

### 2. ArgoCD ServiceMonitor

**目标**: 采集 ArgoCD Server 和 Application Controller 的指标

**配置要点**:
- 命名空间: `argocd`
- 端口: `8083` (metrics)
- 标签选择器: `app.kubernetes.io/name=argocd-server` 或 `app.kubernetes.io/name=argocd-application-controller`

**关键指标**:
| 指标名 | 类型 | 说明 |
|--------|------|------|
| `argocd_app_info` | Gauge | 应用信息（健康状态、同步状态） |
| `argocd_app_sync_total` | Counter | 同步操作总数 |
| `argocd_app_reconcile_duration_seconds` | Histogram | 同步耗时 |
| `argocd_cluster_info` | Gauge | 集群信息 |

### 3. DevOps Overview Dashboard

**Dashboard 布局**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DevOps Overview Dashboard                        │
├─────────────────────────────────────────────────────────────────────┤
│  Row 1: 概览统计                                                     │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐           │
│  │ Pipeline  │ │ Pipeline  │ │ App Sync  │ │ App Health│           │
│  │ Total     │ │ Success % │ │ Status    │ │ Status    │           │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘           │
├─────────────────────────────────────────────────────────────────────┤
│  Row 2: Tekton CI 指标                                               │
│  ┌─────────────────────────────┐ ┌─────────────────────────────┐   │
│  │ Pipeline 执行趋势 (时间序列) │ │ Pipeline 执行时长分布        │   │
│  └─────────────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│  Row 3: ArgoCD CD 指标                                               │
│  ┌─────────────────────────────┐ ┌─────────────────────────────┐   │
│  │ Application 同步状态        │ │ Application 健康状态         │   │
│  └─────────────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│  Row 4: 集群资源                                                     │
│  ┌─────────────────────────────┐ ┌─────────────────────────────┐   │
│  │ CPU 使用率                   │ │ 内存使用率                   │   │
│  └─────────────────────────────┘ └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Models

### ServiceMonitor CRD 结构

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <component>-servicemonitor
  namespace: monitoring
  labels:
    release: prometheus  # 必须匹配 Prometheus Operator 的 selector
spec:
  namespaceSelector:
    matchNames:
      - <target-namespace>
  selector:
    matchLabels:
      <label-key>: <label-value>
  endpoints:
    - port: <port-name>
      interval: 30s
      path: /metrics
```

### Grafana Dashboard JSON 结构

Dashboard 将使用 Grafana JSON 格式，包含:
- `panels`: 面板定义数组
- `templating`: 变量定义
- `time`: 默认时间范围
- `refresh`: 自动刷新间隔

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system.*

由于本功能主要是配置和集成工作，涉及的是 YAML 配置文件和 JSON Dashboard，不涉及复杂的业务逻辑代码，因此主要通过验证测试来确保正确性：

**Property 1: ServiceMonitor 配置有效性**
*For any* ServiceMonitor 配置，应用到集群后，Prometheus 应能发现并采集目标服务的指标
**Validates: Requirements 1.1, 2.1**

**Property 2: Dashboard 数据展示正确性**
*For any* 导入的 Dashboard，所有面板应能正确查询并展示 Prometheus 中的数据
**Validates: Requirements 3.4**

## Error Handling

| 错误场景 | 处理方式 |
|---------|---------|
| ServiceMonitor 无法发现目标 | 检查 label selector 和 namespace 配置 |
| Prometheus 无法采集指标 | 检查目标服务的 metrics 端口是否暴露 |
| Dashboard 无数据 | 检查 PromQL 查询语句和数据源配置 |
| 指标名称不存在 | 确认目标组件版本和指标暴露情况 |

## Testing Strategy

### 验证测试

1. **ServiceMonitor 验证**:
   - 检查 Prometheus Targets 页面是否显示新的采集目标
   - 验证指标是否能在 Prometheus 中查询到

2. **Dashboard 验证**:
   - 导入 Dashboard 后检查所有面板是否有数据
   - 验证时间范围切换是否正常

### 验证命令

```bash
# 检查 ServiceMonitor 是否创建
kubectl get servicemonitor -n monitoring

# 检查 Prometheus Targets
curl http://<MASTER_IP>:30909/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("tekton"))'

# 检查指标是否存在
curl http://<MASTER_IP>:30909/api/v1/query?query=tekton_pipelines_controller_pipelinerun_count
```
